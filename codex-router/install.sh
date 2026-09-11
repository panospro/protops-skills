#!/usr/bin/env bash
# Installs the Codex model-routing setup into CODEX_HOME (default ~/.codex).
#
#   ./install.sh              install / update
#   ./install.sh --dry-run    show what would change, touch nothing
#   ./install.sh --uninstall  restore the state recorded before the first install
#
# Merges only the keys in config.snippet.toml into config.toml. Existing
# [projects.*], [mcp_servers.*] and every other section are preserved.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME_DIR="${CODEX_HOME:-$HOME/.codex}"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$HOME_DIR/.router-backup-$STAMP"
PRISTINE="$HOME_DIR/.router-backup-pristine"   # first install only; what --uninstall restores
DRY=0
MODE=install

for a in "$@"; do
  case "$a" in
    --dry-run) DRY=1 ;;
    --uninstall) MODE=uninstall ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    *) echo "unknown flag: $a" >&2; exit 2 ;;
  esac
done

say() { printf '%s\n' "$*"; }
act() { if [ "$DRY" = 1 ]; then say "  would: $*"; else eval "$@"; fi; }

# ---------------------------------------------------------------- preflight
command -v codex >/dev/null || { echo "codex not on PATH" >&2; exit 1; }
command -v python3 >/dev/null || { echo "python3 required (config merge + hook logger)" >&2; exit 1; }

VER="$(codex --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)"
say "codex $VER  |  CODEX_HOME=$HOME_DIR"
python3 - "$VER" <<'PY' || echo "  WARNING: needs codex >= 0.149 (agents table, subagent hooks); continuing anyway"
import sys
v=[int(x) for x in (sys.argv[1] or "0.0.0").split(".")]
sys.exit(0 if v >= [0,149,0] else 1)
PY

MODELS="$(codex debug models 2>/dev/null || true)"
for m in gpt-5.6-terra gpt-5.6-sol gpt-5.6-luna; do
  case "$MODELS" in
    *"$m"*) : ;;
    *) echo "  WARNING: $m not in this account's model catalog — the role pinned to it will fail" ;;
  esac
done

# ---------------------------------------------------------------- uninstall
if [ "$MODE" = uninstall ]; then
  [ -d "$PRISTINE" ] || { echo "no pre-router backup at $PRISTINE — nothing to restore" >&2; exit 1; }
  say "restoring pre-router state from $(basename "$PRISTINE")"
  for f in config.toml AGENTS.md hooks.json; do
    if [ -f "$PRISTINE/$f" ]; then
      act "cp '$PRISTINE/$f' '$HOME_DIR/$f'"; say "  restored $f"
    else
      act "rm -f '$HOME_DIR/$f'";           say "  removed $f (did not exist before install)"
    fi
  done
  act "rm -f '$HOME_DIR/agents/deep.toml' '$HOME_DIR/agents/worker.toml'"
  act "rm -f '$HOME_DIR/sol.config.toml' '$HOME_DIR/luna.config.toml'"
  act "rm -f '$HOME_DIR/hooks/log-subagent.py'"
  say "done. installed role files and profiles removed; backed-up files restored."
  exit 0
fi

# ---------------------------------------------------------------- backup
say "backup -> $BACKUP"
act "mkdir -p '$BACKUP'"
for f in config.toml AGENTS.md hooks.json; do
  [ -f "$HOME_DIR/$f" ] && act "cp '$HOME_DIR/$f' '$BACKUP/$f'"
done
if [ ! -d "$PRISTINE" ]; then
  say "first install — recording pre-router state in $(basename "$PRISTINE")"
  act "mkdir -p '$PRISTINE'"
  for f in config.toml AGENTS.md hooks.json; do
    [ -f "$HOME_DIR/$f" ] && act "cp '$HOME_DIR/$f' '$PRISTINE/$f'"
  done
else
  say "pre-router state already recorded — leaving $(basename "$PRISTINE") untouched"
fi

# ---------------------------------------------------------------- config merge
say "merging config.snippet.toml into config.toml"
python3 - "$HOME_DIR/config.toml" "$SRC/config.snippet.toml" "$DRY" <<'PY'
import re, sys, pathlib

target, snippet, dry = sys.argv[1], sys.argv[2], sys.argv[3] == "1"
cur = pathlib.Path(target).read_text(encoding="utf-8") if pathlib.Path(target).exists() else ""
snip = pathlib.Path(snippet).read_text(encoding="utf-8")

def parse(text):
    """-> (top-level key/value pairs, {table: {k: v}}) ignoring comments."""
    top, tables, table = {}, {}, None
    for line in text.splitlines():
        s = line.strip()
        if not s or s.startswith("#"):
            continue
        m = re.match(r"^\[([^\]]+)\]$", s)
        if m:
            table = m.group(1)
            tables.setdefault(table, {})
            continue
        m = re.match(r"^([A-Za-z0-9_.\-]+)\s*=\s*(.+)$", s)
        if m:
            (tables[table] if table else top)[m.group(1)] = m.group(2).strip()
    return top, tables

want_top, want_tables = parse(snip)
changes = []

# top-level keys: replace in place, else append before the first table header
for k, v in want_top.items():
    pat = re.compile(rf"^{re.escape(k)}\s*=.*$", re.M)
    if pat.search(cur):
        old = pat.search(cur).group(0)
        if old.split("=", 1)[1].strip() != v:
            cur = pat.sub(f"{k} = {v}", cur, count=1)
            changes.append(f"{k}: {old.split('=',1)[1].strip()} -> {v}")
    else:
        first = re.search(r"^\[", cur, re.M)
        ins = f"{k} = {v}\n"
        cur = (cur[:first.start()] + ins + cur[first.start():]) if first else cur + ins
        changes.append(f"{k}: (added) {v}")

# tables: create if missing, otherwise set only the named keys
for tbl, kvs in want_tables.items():
    hdr = re.compile(rf"^\[{re.escape(tbl)}\]\s*$", re.M)
    if not hdr.search(cur):
        body = "".join(f"{k} = {v}\n" for k, v in kvs.items())
        cur = cur.rstrip("\n") + f"\n\n[{tbl}]\n{body}"
        changes.append(f"[{tbl}]: (added) {', '.join(kvs)}")
        continue
    start = hdr.search(cur).end()
    nxt = re.search(r"^\[", cur[start:], re.M)
    end = start + (nxt.start() if nxt else len(cur) - start)
    block = cur[start:end]
    for k, v in kvs.items():
        kp = re.compile(rf"^{re.escape(k)}\s*=.*$", re.M)
        if kp.search(block):
            old = kp.search(block).group(0)
            if old.split("=", 1)[1].strip() != v:
                block = kp.sub(f"{k} = {v}", block, count=1)
                changes.append(f"[{tbl}].{k}: {old.split('=',1)[1].strip()} -> {v}")
        else:
            block = block.rstrip("\n") + f"\n{k} = {v}\n"
            changes.append(f"[{tbl}].{k}: (added) {v}")
    cur = cur[:start] + block + cur[end:]

_, kept = parse(cur)
preserved = [t for t in kept if t.startswith(("projects.", "mcp_servers.", "features."))]
for c in changes or ["(nothing to change)"]:
    print(f"  {c}")
print(f"  preserved sections: {len(preserved)}")
if not dry:
    pathlib.Path(target).write_text(cur, encoding="utf-8")
PY

# ---------------------------------------------------------------- files
say "installing policy, roles, profiles, hooks, tooling"
act "mkdir -p '$HOME_DIR/agents' '$HOME_DIR/hooks' '$HOME_DIR/logs'"
act "cp '$SRC/AGENTS.md' '$HOME_DIR/AGENTS.md'"
act "cp '$SRC/agents/deep.toml' '$SRC/agents/worker.toml' '$HOME_DIR/agents/'"
act "cp '$SRC/profiles/sol.config.toml' '$SRC/profiles/luna.config.toml' '$HOME_DIR/'"
act "cp '$SRC/hooks/hooks.json' '$HOME_DIR/hooks.json'"
act "cp '$SRC/hooks/log-subagent.py' '$HOME_DIR/hooks/log-subagent.py'"
act "cp '$SRC/cost-report.py' '$HOME_DIR/cost-report.py'"
act "chmod +x '$HOME_DIR/hooks/log-subagent.py' '$HOME_DIR/cost-report.py'"

# ---------------------------------------------------------------- verify
if [ "$DRY" = 0 ]; then
  say "verifying config"
  # 1. TOML syntax — independent of auth and network.
  python3 - "$HOME_DIR/config.toml" <<'PYV' || { say "  INVALID TOML — restore with: ./install.sh --uninstall"; exit 1; }
import sys, pathlib
try:
    import tomllib
except ModuleNotFoundError:
    sys.stderr.write("  (python < 3.11: skipping TOML parse)\n"); sys.exit(0)
tomllib.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
print("  TOML OK")
PYV
  # 2. Ask codex itself, but do not confuse an auth failure with a config failure.
  ERR="$(codex exec --ephemeral --strict-config --skip-git-repo-check -s read-only \
         "Reply with only: OK" </dev/null 2>&1 >/dev/null || true)"
  if [ -z "$ERR" ]; then
    say "  codex accepted the config"
  elif printf '%s' "$ERR" | grep -qiE "login|auth|credential|sign in|not authenticated"; then
    say "  not signed in on this machine — config syntax is fine; run: codex login"
  elif printf '%s' "$ERR" | grep -qiE "config|toml|unknown field|invalid"; then
    say "  CONFIG REJECTED by codex:"; printf '%s\n' "$ERR" | head -5 | sed 's/^/    /'
    say "  restore with: ./install.sh --uninstall"; exit 1
  else
    say "  codex check inconclusive (not a config error):"; printf '%s\n' "$ERR" | head -3 | sed 's/^/    /'
  fi
fi

cat <<EOF

installed. one manual step remains:

  codex        then  /hooks     -> review and trust the SubagentStart/SubagentStop entries

Hook trust is hashed per definition and stored per machine, so no copy can skip it.
Until it is done, ~/.codex/logs/routing.jsonl stays empty.

  codex                default root: gpt-5.6-terra / medium
  codex -p sol         gpt-5.6-sol / medium
  codex -p luna        gpt-5.6-luna / medium
  python3 $HOME_DIR/cost-report.py --days 7

revert:  ./install.sh --uninstall     (restores $BACKUP)
EOF
