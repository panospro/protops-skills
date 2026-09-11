#!/usr/bin/env python3
"""Per-session token and cost report for Codex sessions.

Reads Codex's own state DB and rollout files. Subagent threads are nested under
the root that spawned them, so a root plus its explorers reads as one session.

Usage:
  python3 ~/.codex/cost-report.py            # last 15 sessions
  python3 ~/.codex/cost-report.py -n 40      # last 40
  python3 ~/.codex/cost-report.py --days 7   # sessions from the last 7 days
  python3 ~/.codex/cost-report.py --by-model # totals only
"""
import argparse
import datetime
import json
import os
import sqlite3
import sys

CODEX_HOME = os.environ.get("CODEX_HOME", os.path.expanduser("~/.codex"))

# API list prices per 1M tokens, used as a RELATIVE cost proxy so tiers can be
# compared on one axis. ChatGPT-plan sessions bill against plan credits, not
# these dollars — treat the $ column as "relative burn", not an invoice.
# Cached input is charged at 10% of input.
PRICES = {
    "gpt-6-astra":   (10.00, 50.00),
    "gpt-5.6-sol":   (4.00, 20.00),
    "gpt-5.6-terra": (2.00, 12.00),
    "gpt-5.6-luna":  (0.20, 1.20),
    "gpt-5.5":       (2.00, 12.00),
}


def money(model, inp, cached, out):
    if model not in PRICES:
        return None
    pin, pout = PRICES[model]
    fresh = max(inp - cached, 0)
    return (fresh * pin + cached * pin * 0.10 + out * pout) / 1_000_000


def parse_rollout(path):
    """Returns (usage dict, plan-% delta for the 5h window, turn count)."""
    usage = {"input": 0, "cached": 0, "cache_write": 0, "output": 0, "reasoning": 0, "total": 0}
    pcts, turns = [], 0
    if not path or not os.path.exists(path):
        return usage, None, 0
    try:
        fh = open(path, encoding="utf-8")
    except OSError:
        return usage, None, 0
    with fh:
        for line in fh:
            try:
                payload = json.loads(line).get("payload") or {}
            except Exception:
                continue
            if payload.get("type") != "token_count":
                continue
            turns += 1
            total = ((payload.get("info") or {}).get("total_token_usage")) or {}
            # total_token_usage is cumulative, so the last record wins.
            usage = {
                "input": total.get("input_tokens", 0),
                "cached": total.get("cached_input_tokens", 0),
                "cache_write": total.get("cache_write_input_tokens", 0),
                "output": total.get("output_tokens", 0),
                "reasoning": total.get("reasoning_output_tokens", 0),
                "total": total.get("total_tokens", 0),
            }
            primary = ((payload.get("rate_limits") or {}).get("primary")) or {}
            if primary.get("used_percent") is not None:
                pcts.append(primary["used_percent"])
    # A window reset mid-session makes the delta meaningless; report nothing then.
    delta = None
    if len(pcts) >= 2:
        delta = pcts[-1] - pcts[0]
        if delta < 0:
            delta = None
    return usage, delta, turns


def parent_of(source):
    """Subagent threads carry their parent id inside the JSON `source` column."""
    if not source or not source.startswith("{"):
        return None
    try:
        spawn = json.loads(source)["subagent"]["thread_spawn"]
    except Exception:
        return None
    return spawn.get("parent_thread_id")


def load(days, limit):
    db = os.path.join(CODEX_HOME, "state_5.sqlite")
    if not os.path.exists(db):
        sys.exit(f"no state db at {db}")
    con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
    q = ("select id, model, reasoning_effort, agent_role, agent_nickname, tokens_used,"
         " rollout_path, created_at, cwd, source from threads")
    args = []
    if days:
        q += " where created_at > ?"
        args.append(int(datetime.datetime.now().timestamp()) - days * 86400)
    q += " order by created_at desc"

    rows = []
    for r in con.execute(q, args):
        usage, delta, turns = parse_rollout(r[6])
        rows.append({
            "id": r[0], "model": r[1] or "?", "effort": r[2] or "-", "role": r[3],
            "nick": r[4], "tokens_used": r[5] or 0, "created": r[7], "cwd": r[8] or "",
            "parent": parent_of(r[9]), "usage": usage, "pct": delta, "turns": turns,
        })

    roots = [x for x in rows if not x["parent"]]
    kids = {}
    for x in rows:
        if x["parent"]:
            kids.setdefault(x["parent"], []).append(x)
    if limit:
        roots = roots[:limit]
    return roots, kids, rows


def fmt(n):
    if n >= 1_000_000:
        return f"{n / 1_000_000:.1f}M"
    if n >= 1_000:
        return f"{n / 1_000:.0f}k"
    return str(n)


def line(x, indent=""):
    u = x["usage"]
    cost = money(x["model"], u["input"], u["cached"], u["output"])
    when = datetime.datetime.fromtimestamp(x["created"]).strftime("%m-%d %H:%M")
    role = f" {x['role']}" if x["role"] else ""
    pct = f"{x['pct']:>5.0f}%" if x["pct"] is not None else "    -"
    dollars = f"${cost:>7.3f}" if cost is not None else "      ?"
    print(f"{indent}{when}  {x['model'][:13]:<14}{x['effort'][:6]:<7}{role:<10}"
          f"{fmt(u['input']):>7}in {fmt(u['cached']):>6}ca {fmt(u['output']):>6}out "
          f"{x['turns']:>3}t {pct} {dollars}  {os.path.basename(x['cwd'])}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("-n", type=int, default=15, help="number of sessions")
    ap.add_argument("--days", type=int, help="only sessions from the last N days")
    ap.add_argument("--by-model", action="store_true", help="totals only")
    a = ap.parse_args()

    roots, kids, every = load(a.days, None if a.days else a.n)

    if not a.by_model:
        print(f"{'when':<14}{'model':<14}{'effort':<7}{'role':<10}"
              f"{'input':>9} {'cached':>9} {'output':>9}  turns   5h%   ~cost  dir")
        print("-" * 118)
        for r in roots:
            line(r)
            for k in kids.get(r["id"], []):
                line(k, indent="  └ ")

    shown = {r["id"] for r in roots} | {k["id"] for r in roots for k in kids.get(r["id"], [])}
    scope = [x for x in every if x["id"] in shown] if not a.days else every

    print()
    print(f"{'by model':<16}{'sessions':>9}{'input':>11}{'cached':>10}{'output':>10}{'~cost':>10}")
    print("-" * 66)
    agg = {}
    for x in scope:
        m = agg.setdefault(x["model"], {"n": 0, "i": 0, "c": 0, "o": 0, "$": 0.0, "priced": x["model"] in PRICES})
        m["n"] += 1
        m["i"] += x["usage"]["input"]
        m["c"] += x["usage"]["cached"]
        m["o"] += x["usage"]["output"]
        m["$"] += money(x["model"], x["usage"]["input"], x["usage"]["cached"], x["usage"]["output"]) or 0
    for name, m in sorted(agg.items(), key=lambda kv: -kv[1]["$"]):
        cost = "$%.2f" % m["$"] if m["priced"] else "unpriced"
        print(f"{name[:15]:<16}{m['n']:>9}{fmt(m['i']):>11}{fmt(m['c']):>10}{fmt(m['o']):>10}{cost:>10}")

    byrole = {}
    for x in scope:
        key = x["role"] or "root"
        r = byrole.setdefault(key, {"n": 0, "$": 0.0})
        r["n"] += 1
        r["$"] += money(x["model"], x["usage"]["input"], x["usage"]["cached"], x["usage"]["output"]) or 0
    if len(byrole) > 1:
        print()
        print(f"{'by role':<16}{'threads':>9}{'~cost':>10}{'share':>8}")
        print("-" * 44)
        grand = sum(r["$"] for r in byrole.values()) or 1
        for name, r in sorted(byrole.items(), key=lambda kv: -kv[1]["$"]):
            print(f"{name:<16}{r['n']:>9}{'$%.2f' % r['$']:>10}{r['$'] / grand * 100:>7.0f}%")

    print()
    print("~cost = API list prices as a RELATIVE tier comparison, not plan billing.")
    print("5h%   = plan consumed during that session (blank if the window reset mid-session).")


if __name__ == "__main__":
    main()
