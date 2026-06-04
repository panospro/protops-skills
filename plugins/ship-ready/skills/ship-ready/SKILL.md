---
name: ship-ready
description: Pre-commit / pre-distribution audit + guided cleanup. By default scans your UNCOMMITTED CHANGES (staged + unstaged + untracked) for sensitive data, personal identifiers, references to gitignored paths, workflow/AI-tool leakage, generated-file slop, dead code, and doc-slop; `--full` scans the whole repo for a pre-share sweep. Folder-agnostic — nothing assumes seeds/ or docs/. Stops at a fix-plan checklist you select from, then applies only the chosen fixes and hands over git/rm commands. Complements `me:check-consistency` (pattern/style drift) and `me:safe-commit` (secret gate). Use when the user types `/me:ship-ready`, or says "audit my changes before commit", "check this diff for sensitive data / leaks", "is this clean to push", "prep this repo to share/open-source", "de-slop", "what should I not commit". On-demand only — never auto-runs.
---

# ship-ready

Audits a **target set** for things that shouldn't be shared, shows a **fix-plan you choose from**, then applies only what you pick and hands you the git/rm commands. Default target is **all your uncommitted changes** (staged + unstaged + untracked) — the everyday case; `--full` widens to the whole repo for a pre-distribution sweep. Folder-agnostic: detection is by content/markers/heuristics, never by assuming `seeds/`, `docs/`, etc.

## Invocation

```
/me:ship-ready                 # default: ALL uncommitted changes (staged + unstaged + untracked)
/me:ship-ready staged          # only staged (git diff --cached)
/me:ship-ready branch          # changed vs origin/main (or main)
/me:ship-ready range A..B      # changed in a range
/me:ship-ready --full          # whole repo — pre-distribution / first-share sweep
/me:ship-ready audit           # read-only: report + plan, no selection prompt
/me:ship-ready --audience public   # preset PII gate (internal | public | unsure)
/me:ship-ready pii gitignore   # run only named modules (subset of the 7)
```

Module names: `audit-core` (1, incl. sensitive-data), `dead-code` (2), `gitignore` (3), `pii` (4), `gen-hygiene` (5), `docs` (6), `triage` (7).

## Core principles

- **Read-only until you approve.** The pipeline halts at the fix-plan (P2). Nothing is mutated before your selection.
- **Git and deletions are never executed by the skill.** It emits copy-paste `git add` / `git rm --cached` / `rm` blocks for the user to run. In-file content edits are applied directly on approval — **including appending patterns to `.gitignore`** (create it if absent; append only if the pattern isn't already present); only git ops and file deletion are handed over as commands. (Honors the user's standing rule: never run git or `rm`, even when asked.)
- **Judgment calls are gated, not guessed** — audience (PII), ship-vs-gitignore, which docs die, minimal-vs-thorough dead-code. Everything unambiguous is offered as a safe auto-fix.
- **Verify after fixing** — re-run affected detectors, run typecheck/build/tests if present, confirm no new dangling refs.
- **Folder-agnostic & idempotent.** Detection is by content/markers/heuristics; safe to re-run.

## Pipeline

```
P0 SCOPE (pick target by mode) ─► P1 AUDIT (7 lenses, read-only) ─► P2 REPORT + FIX-PLAN ──■ STOP
                                                                                            │
                                                                       (your selection + gate answers)
                                                                                            ▼
                          P5 COMMIT-TRIAGE ◄─ P4 VERIFY ◄─ P3 FIX (selected IDs only, ordered)
```

### P0 — Scope & baseline
1. Confirm it's a git repo; else stop.
2. **Pick the target set by mode** (`scripts/scan-target.sh <mode>` prints it and runs the cheap checks):
   - `changes` (default): staged ∪ unstaged ∪ untracked — everything uncommitted right now.
   - `staged`: only `git diff --cached`.
   - `branch` / `range A..B`: files changed vs a base.
   - `full`: `git ls-files` ∪ untracked-not-ignored — the whole repo (pre-distribution).
   Exclude lockfiles from content scans. In diff modes, scope is the **changed files** (and ideally the changed hunks).
3. Read `.gitignore`; detect language(s), generated-file markers, and any doc/data files **by characteristics**, not fixed folders.
4. **Audience gate (ask once):** `internal` / `public` / `unsure` → sets PII severity (internal → Info/keep; public → Blocker/scrub). Skip if `--audience` given.

### P1 — Audit (7 lenses, read-only)
Patterns live in `references/check-catalog.md`. Per finding: stable **ID**, severity (🔴/🟡/🔵), module, `file:line`, concrete proposed fix, risk tag, and whether it's a safe auto-fix / gated decision / destructive (command-only).

| # | Module | Detects (folder-agnostic) |
|---|---|---|
| 1 | **audit-core** | **sensitive data anywhere in the target** — secrets/API keys/tokens/private keys, hardcoded home paths, PII shapes (emails, IBANs, national-ID/long-digit IDs, DOBs); personal identifiers (OS username, owner name, employee codes, workspace names); workflow/AI-tool leakage (skill names, slash commands, `Cap N`/phase tags, `Claude`/`anthropic`, ISO `Generated:` stamps); comment-voice (first-person, `Note:`, translator commentary, dangling `see <file>` refs); **hardcoded domain literals in live logic** (a business id / magic value in a comparison or `case` — e.g. `=== '9000000428'` — that should be a constant/config/state-flag) |
| 2 | **dead-code** | unreferenced exports/functions/classes, unreachable branches, commented-out code blocks, orphaned files; **and** dead config — env vars declared (`.env*` / config) but never read + the code reachable only through them. Confirm "uncalled" by grepping the symbol before proposing removal |
| 3 | **gitignore** | (a) committed files **referencing** gitignored paths (dangling on clone — skips common build/dep tokens); (b) target files that **should** be ignored but aren't (secrets, generated outputs, local-only, large/binary) |
| 4 | **pii** | data files in the target that carry real-looking PII (structured records — JSON/CSV/SQL/YAML — with names, IDs, emails, etc.) → proposes a **consistent synthetic mapping**. A file qualifies by *what's in it*, wherever it lives — the folder name is irrelevant. Prose/code with incidental PII is just flagged by audit-core. |
| 5 | **gen-hygiene** | generated/translated files (by header markers, not folder): absolute-path provenance, ISO `Generated:` stamps, unsubstituted template placeholders (e.g. `[ClassName]`, `<%= %>`, `__NAME__` — **not** `{{var}}`, which is legit in Postman/Handlebars/Jinja), stale "stub / for later implementation" headers on implemented code |
| 6 | **docs** | every `.md`/`.mdx`/`.txt` in the target is a doc candidate (any folder) → classify keep / distill / delete. A filename/content heuristic (`*-report*`, `*-v\d`, `plan`, `status`, `notes`, `TODO`, `session-*`, `scratch`, `wip`, `draft`; iterative logs / checklists) flags the likely-slop ones |
| 7 | **triage** | classify the post-fix target into ship / gitignore / delete / regenerate (runs in P5) |

Cheap deterministic checks run via `scripts/scan-target.sh`; semantic ones (dead-code reachability, PII judgement, doc-slop content, "is this audit field populated vs all-null") require reading the candidates the greps surface — never assume from a path.

**Self-audit caveat:** when the target set includes ship-ready's own pattern-definition files (`SKILL.md`, `references/check-catalog.md`, `scripts/scan-target.sh`), the cheap scan matches its **own** detector strings and documented examples (the home-path regex, the `/me:` invocation lines, the placeholder/stub samples). These are self-references, not findings — confirm by reading, exclude them from the report, and never "fix" a detector's own pattern. Real leaks *outside* these pattern strings still count.

**Published-identity exemption:** the repo owner's handle (OS username / `git config user.name`) appearing **only** in publication-attribution fields — `author.name`, `repository`/`homepage` URLs in `.claude-plugin/marketplace.json`, `.claude-plugin/plugin.json`, or a plugin's own `plugin.json` — is the deliberate publish identity. Auto-classify it `keep`; don't surface it as a judgment call. It's still a finding if the same handle leaks into source / comments / data, or if the *private* git work identity (real name, work email) appears anywhere.

### P2 — Report + fix-plan → **STOP**

**Clean-run fast path:** if the semantic pass confirms **0 real findings** (after discounting self-references and other false positives), skip the report file and the full table — emit a compact verdict, skip the selection/fix/verify stages (nothing to fix), and go straight to **P5 commit-triage** (which still proposes commit messages):
```
ship-ready: <mode> (<N> files) — CLEAN. 0 real findings.
<k> matches discounted (<reason, e.g. self-reference>). <j> judgment call(s): <id> → <default>?
```
Write `.claude/ship-ready-report.md` only when there are real findings, or when invoked as `--full` / `audit`.

Otherwise, write the full report to `.claude/ship-ready-report.md`. **Writing it is always two steps: (1) `Read .claude/ship-ready-report.md` first — it usually exists from a prior run; if it doesn't, ignore the read error; (2) then `Write` the regenerated report. NEVER call `Write` on the report without a `Read` of that exact path earlier in the same turn** — the file tool rejects overwriting a file it hasn't read this session, and a prior run almost always left one there. Then print **only the fix-plan checklist** below and HALT — the table is the inline surface, so don't re-print the report's prose/identity sections inline:

```
ID   SEV  MODULE        WHERE                         PROBLEM → PROPOSED FIX                       RISK    DEFAULT
B1   🔴   audit-core    config.ts:40                  API key literal → env var / placeholder      none    ✓ fix
W1   🟡   gitignore     src/x.ts:5 → ../private/      dangling ref → self-contained comment         low     ✓ fix
W2   🟡   audit-core    src (×6) first-person         neutral comment voice                         none    ✓ fix
D1   🔵   pii           fixtures/users.json           real emails/IDs → synthetic map (audience)    med     ? ask
D2   🔵   docs          NOTES-v3.md, plan.md          delete slop docs                              ⚠ del   ? ask
D3   🔵   dead-code     2 env vars + 1 unused export  remove vars only / vars + code                low     ? ask
```
Legend: **✓** safe in-file edit · **?** gated decision · **⚠** destructive → emitted as a command the user runs. If invoked as `audit`, stop here (report only).

### P2.5 — Selection gate (you pick; two layers)
1. **Decision forks** (`?` rows) → `AskUserQuestion` multi-select, one batch: audience; PII (`scrub all`/`IDs only`/`keep` + approve the mapping); docs (which keep/distill/delete); dead-code (`vars only`/`vars+code`/`leave`); ship-vs-gitignore per file.
2. **Bulk + granular** by reply: `accept all` · `safe only` · `blockers only` · `pick: B1,W1,D2` · `skip: W2` · `abort`.

Then a **confirm preview** (`APPLY in-file: … / EMIT as commands: … / DEFER: …  Proceed? [yes/adjust]`). Only on `yes` → P3, touching only the selected IDs.

### P3 — Fix (selected IDs only, dependency-ordered)
```
1. pii            apply synthetic map to data files; VERIFY TYPE-PRESERVED (a value→value
                  map must never turn a number/non-null into null — re-read a sample)
2. audit-core     + gen-hygiene safe fixes: scrub secrets→placeholder, strip leakage/abs-paths/ISO
                  stamps/placeholders/stale headers, neutralize comment voice
3. docs           author kept/distilled docs FRESH from the code (self-contained); emit `rm` for deletes
4. ref-decouple   rewrite comments pointing at now-deleted/ignored files into self-contained sentences
5. dead-code      remove unreferenced code + dead vars/config (if chosen); build must stay green
6. gitignore      APPLY the `.gitignore` addition directly (in-file edit: append the pattern,
                  create `.gitignore` if absent, skip if already present); emit only
                  `git rm --cached` for any tracked-but-now-ignored file
```
`✓ selected` → in-file edit. `⚠ selected` → command block (not executed). `deferred` → untouched, recorded with `skip:<id>`.

### P4 — Verify
Re-run affected detectors over the target → expect 0 residual. Run `typecheck`/`build`/`test` if present (report exit status; never claim done without it). Re-scan for **new** dangling refs from deletions/decoupling. Report before/after counts.

### P5 — Commit-triage (handoff) — per-file verdict, grouped by folder
Read the current git state (`git status --porcelain`) of every changed/untracked path and give each ONE verdict, printed **grouped by folder** with a one-line reason:

- **commit** — clean, safe to stage + commit now.
- **hold** — leave unstaged: debug/WIP/incomplete/experimental, or carries a deferred finding.
- **gitignore** — local-only / generated / secret-bearing → don't commit.
- **delete** — slop / dead / superseded.

```
src/
  commit     app.ts, routes/customerRoutes.ts     clean
  hold       sandbox/data-generator.ts            carries a deferred D1 (pii) finding
docs/
  delete     NOTES-v3.md, plan.md                 slop (approved)
  commit     architecture.md                      freshly distilled
postman/
  gitignore  env.qa.json                          carries a key
```

When the triage yields a clean, non-empty **commit** set (ready to ship), propose **3–5** candidate messages **derived from this run's diff — never canned**, scaled to the change: **~3** for a focused single-concern set, **up to 5** only when it spans multiple concerns/files. Recipe: read the staged change set, pick the dominant change `type`, then offer a spread — an umbrella subject covering the whole set, a narrower one on the primary file/feature, and alternatives framed under other valid prefixes. **Keep each message compact and direct** — one `type: subject` line stating *what changed*: conventional prefix (`feat` / `fix` / `chore` / `docs` / `refactor` / `build` / `test` / `style` / `perf`), imperative mood, lowercase subject, ≤ ~72 chars, no trailing period, **no multi-paragraph body, no ~100-word essay**. The shapes below are **templates — substitute real content from the diff, never emit them literally**:
```
1. <type>: <whole change set, compact>
2. <type>: <narrower — the primary file/feature>
3. <other valid type>: <same change framed differently>
   (add a 4th/5th only if the set spans further concerns worth a distinct framing)
```
The `.gitignore` patterns were already applied in P3 as an in-file edit, so `.gitignore` shows up as a file to stage — not a command. Then emit the matching command block (the user runs it; nothing executed):
```bash
git add <commit paths>                                 # include the .gitignore ship-ready edited in P3
git restore --staged <hold paths currently staged>     # move WIP out of this commit
git rm --cached <tracked-but-now-ignored>
rm <delete paths>
git commit -m "<one of the 5 above>"
```
Suggest `/me:safe-commit` as the final secret/identity gate before committing.

## Outputs
- `.claude/ship-ready-report.md` — findings + fix-plan + applied/emitted/deferred. Advise adding it to `.gitignore`.
- In-file edits for approved `✓` IDs (including `.gitignore` additions); one command block for all `⚠` actions (git ops + deletions).

## Safety
Read-only by default; the only pre-approval writes are the report + `.claude/`. Never runs `git`/`rm`/destructive shell — emits commands. Re-reads files before editing (respects parallel edits). `abort` leaves the tree as found.

## Relationship to other skills
- **`me:check-consistency`** — pattern/style drift on a diff. Overlaps on comment-voice (intentional); ship-ready adds the distribution lenses (sensitive data, personal identifiers, gitignore-dangling, gen-hygiene, dead-config, pii, doc-slop, triage) and the select-then-fix gate.
- **`me:safe-commit`** — secret/identity gate; ship-ready ends by pointing at it.
