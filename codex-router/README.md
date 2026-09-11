# codex-router

A global model-routing setup for [Codex CLI](https://developers.openai.com/codex). Requires
≥ 0.149 (the `[agents]` table and subagent hooks); developed against 0.149 and 0.154.
Runs everyday work on the mid tier, escalates to the top tier only on evidence, and spends its
effort on removing duplicated work rather than on picking models cleverly.

Independent of the Claude Code plugins in `plugins/` — this directory installs into `~/.codex`.

## Install

```sh
git clone https://github.com/panospro/protops-skills
cd protops-skills/codex-router
./install.sh --dry-run     # see exactly what would change
./install.sh
```

Then, once per machine:

```
codex        →  /hooks     # review and trust the SubagentStart/SubagentStop entries
```

Hook trust is hashed per definition and stored locally, so no file copy can skip it. Until it is
done, `~/.codex/logs/routing.jsonl` stays empty — routing still works, you just lose the log.

Revert at any time with `./install.sh --uninstall`. The first install records your pre-router
`config.toml`, `AGENTS.md` and `hooks.json` in `~/.codex/.router-backup-pristine/`; uninstall
restores exactly that, and later installs never overwrite it.

## What it does

| tier | model | when |
|---|---|---|
| root | `gpt-5.6-terra` / medium | everything, by default |
| escalation | `gpt-5.6-sol` / high | only on evidence of being stuck, as the `deep` role |
| cheap | `gpt-5.6-luna` / medium | manual: `codex -p luna` |

```
 you ──▶ codex (Terra/medium)
          │
          │  reads with ONE fat command, not four thin ones
          │  prefers a tool that answers outright: rg / for-cat / node -e
          │  takes check commands from the repo's own AGENTS.md — never hunts for them
          │  searches the repo before reaching for any plugin or connector
          │
          ├─ does the work itself                      ◄── the normal path
          ├─ independent parallel slice ──▶ worker (Terra/medium)
          └─ EVIDENCE of being stuck:
               two failed attempts on one hypothesis · an unexplained failing check ·
               read the code and still cannot name the cause · a design call with
               real trade-offs
                  │
                  ├─ prints  [ROUTE] SOL — <reason>
                  ├─▶ deep (Sol/high, fork_turns:"all" → inherits full context)
                  └─ then stops touching that problem until deep returns
          │
          └─ GATE: run the repo's declared checks, report output verbatim
```

Subject matter is never an escalation trigger. Security, concurrency and data integrity raise
the bar for *verification*, not for delegation.

## Files installed

```
~/.codex/AGENTS.md                  global policy (~4 KB, loaded into every call)
~/.codex/agents/deep.toml           Sol/high  — diagnoses what the root could not
~/.codex/agents/worker.toml         Terra/med — an independent parallel slice
~/.codex/sol.config.toml            codex -p sol
~/.codex/luna.config.toml           codex -p luna
~/.codex/hooks.json                 SubagentStart/Stop → routing.jsonl
~/.codex/hooks/log-subagent.py      the logger (stdlib python3 only)
~/.codex/cost-report.py             per-session tokens/cost/plan-% with children nested
~/.codex/config.toml                MERGED — only the keys in config.snippet.toml
```

`install.sh` sets only `model`, `model_reasoning_effort` and the `[agents]` table. Your
`[projects.*]`, `[mcp_servers.*]`, `[features.*]` and everything else are left untouched, and a
second run is a no-op.

## Per-repo companion

Add this to each repo's own `AGENTS.md`. It removes the orientation commands that otherwise start
every session:

```md
## Checks
npm run typecheck
npm test
```

Codex reads global `~/.codex/AGENTS.md`, then the repo root, then nested directories — closer
files win on conflict, 32 KiB combined cap.

## Measuring it

```sh
python3 ~/.codex/cost-report.py --days 7
python3 ~/.codex/cost-report.py --by-model
cat ~/.codex/logs/routing.jsonl
```

The `5h%` column is real plan consumption (blank if the window reset mid-session). The `~cost`
column is API list prices used as a *relative* tier comparison — on a ChatGPT plan it is not
billing.

## Measured results

Two tasks, identical wording, same correct answers, one run each:

```
                                 tokens      ~cost
top tier for everything         209,967     $0.269
naive router (subagents)      1,040,962     $0.279    +4%
after removing duplication      134,335     $0.115   -57%
final (tool-first)               97,438     $0.105   -61%
```

The subagent layer contributed nothing on its own (+4%). The gain came from three things:

1. **No duplicated work.** The first version had the root keep solving a problem it had already
   escalated, and explorers whose findings refilled the root's context anyway.
2. **No self-orientation.** Roughly half of every session's shell commands were rediscovering
   `package.json` / `Makefile` / CI. A `Checks` block in the repo ends that.
3. **Tools over agents.** Every model call costs a fixed ~17.6k tokens, so call count dominates.
   Answering with `rg` or a short script beats delegating to an agent that reads files.

A dedicated read-only explorer role was built, measured and **dropped**: 4–6× the tokens for no
accuracy gain over the root using `rg` and small scripts. Its per-call floor cost is why the
policy file is kept short.

## Design notes

- A thread cannot change its own model — no such tool exists. Escalation therefore means
  spawning a role pinned to a higher tier, which is why `deep` exists at all.
- `fork_turns: "all"` gives the spawned role the parent's full context. A model pinned in the
  role file survives that fork even though the docs say full-history forks reject overrides;
  never pass `model` at spawn time. Undocumented, so watch the log: a `deep` row showing
  `gpt-5.6-terra` means the pin stopped working.
- `max_depth` is V1-only and ignored for these models, so recursion depth relies on the
  `Never spawn agents.` line in each role file. `max_concurrent_threads_per_session = 3` is a
  hard runtime cap and the real blast-radius limit.
- `codex exec` blocks on a non-TTY stdin — append `< /dev/null` when scripting it.
- Per-thread truth lives in `~/.codex/state_5.sqlite`, table `threads` (`model`,
  `reasoning_effort`, `agent_role`), with parentage in `thread_spawn_edges`. Trust that over
  any model's self-report.

## Caveats

- Measurements are synthetic fixtures, one run each. Treat −61% as a direction, not a promise.
- `codex debug models` must list `gpt-5.6-terra`/`-sol`/`-luna` for your account; `install.sh`
  warns if not.
- The repo-before-connector rule was added on two observations and has not been exercised since.
```
