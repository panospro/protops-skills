---
name: check-consistency
description: Review a git diff against (1) inferred repo patterns and (2) universal best practices. Flags inconsistencies and lazy/over-engineered code before commit. Complements linters (which check syntax/style) and /safe-commit (which checks secrets and commit hygiene). Use when the user types `/me:check-consistency`, `consistency check my changes`, `review my diff`, `check this before I commit`, or similar. On-demand only — does not auto-run.
---

# me:check-consistency

Review layer that flags two things in a git diff:

1. **Repo-pattern consistency** — deviations from the conventions this codebase already follows.
2. **Generic best-practice violations** — lazy, hardcoded, or over-engineered code regardless of repo.

Not a linter, not a security scanner — complements both. Produces a severity-coded report; user decides what to act on.

## Invocation

```
/me:check-consistency                 # default: staged changes
/me:check-consistency staged          # same as default
/me:check-consistency last-commit     # HEAD~1..HEAD
/me:check-consistency branch          # current branch vs origin/main (or main)
/me:check-consistency range <ref>..<ref>
/me:check-consistency re-infer        # re-run inference, overwrite .claude/repo-patterns.proposed.md
/me:check-consistency show-patterns   # print current approved patterns, no diff
```

## Flow

```
/me:check-consistency
        │
        ▼
  ┌─────────────────────────────────────────────────────┐
  │  Patterns state?                                    │
  │  • repo-patterns.md present     → Approved          │
  │  • only .proposed.md present    → Draft pending     │
  │  • neither                      → First run         │
  └───────┬─────────────────┬─────────────────┬─────────┘
          │                 │                 │
     Approved          Draft pending      First run
          │                 │                 │
          ▼                 ▼                 ▼
  Generic + repo-    Generic checks     Infer patterns,
  specific checks    only; remind       present inline,
                     user to approve    also run generic
                     draft              checks, offer to
                                        save draft
```

## Step 1 — detect target diff

Based on arg:

- `staged` (default): `git diff --staged`
- `last-commit`: `git diff HEAD~1 HEAD`
- `branch`: `git diff $(git merge-base HEAD origin/main)..HEAD` (fallback to `main` if no `origin/main`)
- `range <a>..<b>`: `git diff <a>..<b>`

Also compute the list of files touched and their contents AFTER the change (needed for context on pattern checks — a diff alone can lie about what a file looks like now). Use `git show` on each touched file at the target ref.

If the diff is empty, report "no changes to review" and stop.

## Step 2 — load or infer patterns

Three possible states:

| State | Files present | Action |
|---|---|---|
| Approved | `.claude/repo-patterns.md` exists and is non-empty | Read it. Go to Step 3. |
| Draft pending | `.claude/repo-patterns.proposed.md` exists, `.claude/repo-patterns.md` does not | Remind user to review and approve the proposed file. **Run generic checks only**; skip all repo-specific checks for this run. |
| First run | Neither file exists | Run inference, present the proposed patterns inline, stop. Write `.claude/repo-patterns.proposed.md` only if the user asks. |

### First run (Draft mode — nothing enforced until approved)

1. **Detect primary languages** by file-extension frequency (skip `node_modules`, `dist`, `build`, `bin`, `obj`, `.git`, `__pycache__`, `venv`, `.venv`, `target`).
2. **List the file tree first.** Run `git ls-files` (or `tree -L 4` with the skip list) and use that listing to pick which files to read. Do not "scan 500 files" — the tree is enough to plan sampling.
3. **Select up to ~30 files** that cover the categories in the detailed method below (entry points / composition roots, shared modules, leaf modules, tests, packaging manifest, each separate sub-project). **Prioritise files changed in the last 90 days** — `git log --since="90 days ago" --name-only --pretty=format: | sort -u` — so current conventions outweigh legacy technical debt.
4. **Extract patterns** (see "Pattern inference — how to discover patterns empirically" below).
5. **Present the inferred patterns inline** — show all inferred rules as plain, readable Markdown (no HTML comments, no per-rule markers) directly in the response. Do NOT write any file by default. Only write `.claude/repo-patterns.proposed.md` if the user explicitly asks you to save them.
6. **Also run generic checks (3a) on the current diff in this same run.** First-run users should get immediate value — generic findings don't depend on approved patterns, so surface them alongside the inline patterns. Do not run repo-specific (3b) checks yet.
7. **Tell the user, at the end of the report:** "Inferred patterns shown above. Tell me which ones to keep (or say 'accept all') and I'll write `.claude/repo-patterns.md` to activate them; say 'save draft' if you'd rather review them in `.claude/repo-patterns.proposed.md` first. Re-run `/me:check-consistency` after activating to enable repo-specific checks." Generic findings from this run are already in the report above.

Do not run repo-specific diff checks while patterns are still in draft. Generic checks (3a) still run in the Draft-pending state.

## Step 3 — run checks

Two buckets. Run both, collect findings.

### Execution model — file-by-file, then aggregate

Do NOT feed the whole diff to a single check pass on large PRs — the signal gets lost in context-window fog. Instead:

1. For each touched file in the diff, isolate its hunks and its post-change contents.
2. Run the full check set (3a + 3b where applicable) against that single file in isolation.
3. Collect findings per file into a shared list.
4. After every file has been checked, run cross-file checks only (structural companions, large-diff spread, layer/dependency rules that need multi-file evidence) across the aggregated set.
5. Then produce the report from the combined findings.

The only checks that need the full diff at once are the ones explicitly marked cross-file (e.g. G8 "large diff across unrelated concerns", G11 "missing companion file", layer/dependency rules from 3b). Every other check runs per-file.

### 3a. Generic checks (repo-agnostic)

Scope: this table is deliberately narrow. Checks that a linter or regex can do deterministically (log statements, commented-out code, unused imports, dead-code inference) are NOT included here — they belong in the user's lint/AST tooling. Only run checks that require cross-file or semantic reasoning.

| # | Check | How it works | Default severity |
|---|---|---|---|
| G1 | **New dependency added (heuristic)** | Detect changes in any packaging manifest (`package.json` / `pyproject.toml` / `*.csproj` / `requirements.txt` / `go.mod` / `Cargo.toml` / `Gemfile` / etc.). For each added entry, report it with context on how many diff lines reference it. **Do not attempt to estimate "replacement LOC"** — just surface the addition for human review. | Info |
| G2 | **Hardcoded secret-like value** | Regex for long hex/base64 strings, `apikey=`/`password=`/`token=`/bearer patterns, private-key headers. | Blocker |
| G3 | **Magic value when named constant exists** | For each new number/string literal in the diff (excluding trivial values like `0`, `1`, `""`, common HTTP codes), search existing repo for a named constant with the same value. **Only flag if the existing constant is semantically related** — the constant's name, the surrounding identifier, or the file path must share a keyword with the new usage (e.g. flag `timeout = 60` against `DEFAULT_TIMEOUT = 60`; do NOT flag it against `MAX_RETRIES = 60`). If no semantically related constant exists, skip — a value collision alone is not a violation. | Warning |
| G5 | **TODO / FIXME without context** | New TODOs without an issue tag, author, or explanation on the same line/comment. | Info |
| G8 | **Large diff across unrelated concerns** | Diff touches >10 files across >3 top-level directories with no shared keyword in file paths. | Info |
| G9 | **Binary or large file added** | Any non-text file, or text file >500 KB. | Warning |
| G10 | **Comment hygiene — notebook-style / sloppy comments** | See sub-checks G10a–G10h below. Comments are documentation for the next developer, not notes from the author to a reviewer. Flag any of the patterns. | Warning |

#### G10 sub-checks — comment hygiene

Run these on every new or modified comment line in the diff (`//`, `#`, `/* */`, `<!-- -->`, docstring blocks, XML doc comments). Skip when the line is inside a string literal or a generated-file region (heuristic: file's first line says "auto-generated", "do not edit", etc.).

| Sub-check | Pattern | Severity | Notes |
|---|---|---|---|
| G10a | **Hardcoded user paths in comments** | Regex: `/home/[a-z]+/`, `/mnt/c/Users/[^/]+/`, `/Users/[^/]+/`, `C:\\Users\\[^\\]+\\`. Also match comments referencing *another project on the same machine* (e.g. `// Source: /home/me/projects/other-repo/...`). | Blocker | Same family as `/safe-commit`'s hardcoded-path block, but it also catches refs buried inside comments rather than code. |
| G10b | **`Note:` / `note:` footnote prefixes** | Comment starts with `Note:` / `// Note:` / ` * Note:` / `# Note:`. | Warning | Footnote-style — if the fact is worth writing, write the sentence without the prefix. |
| G10c | **First-person pronouns in comments** | Comment contains a first-person pronoun used as the subject: `\b(we|our|us|I|I'm|I'll|let's|let us)\b` *not* inside a quoted string. Skip technical idioms like "we" appearing inside a quoted error message. | Warning | Comments are for the next developer; neutral / descriptive voice. |
| G10d | **Date-stamped work-note tags** | Patterns like `parity test 2026-04-24`, `F1 fix`, `F2 fix 2026-…`, `Fix 3:`, `Cap 5`, `CAP 1`, `added in sprint 7`, `verified via postman parity test`. Heuristic regex: any comment with `\b(F\d+ fix\|Fix \d+:\|Cap \d+\|CAP \d+\|parity test \d{4}-\d{2}-\d{2})\b`. | Warning | The fact survives in git blame and PR descriptions; comments rot when they reference moments. |
| G10e | **AI / skill / workflow references in comments** | Comment contains `\/[a-z-]+:[a-z-]+\b` (skill name), `/create-sandbox`, `claude code`, `anthropic`, `Generated: 20\d\d-`, `SKELETON:`, `AGENT:`, `matches skill limitation`, `regenerate via /…`. | Warning | Internal-process leakage; has no meaning to a reader of the repo. |
| G10f | **Translator's commentary on ported code** | Comment contains `mirrors the (C#\|Java\|Python\|Go\|TypeScript) (impl\|original)`, `matches the (C#\|Java\|Python\|Go\|TypeScript) (impl\|behavior\|version)`, or `\bthe (C#\|Java\|Python\|Go\|TypeScript) (impl\|original) (returns\|does\|uses)`. | Warning | The translation source is implicit from the file structure; readers care about the current code. |
| G10g | **Hedge / apology phrasing** | Comment contains `\b(for now\|we'll need to (revisit\|come back)\|isn't (verified\|tested) (yet\|))\b`, `not 100% sure but`, `I think this is right but`, `will fix later`. | Info | Uncertainty belongs in PR descriptions and follow-up tickets, not in comments. |
| G10h | **Dangling cross-references to non-existent files** | Comment references a file path (e.g. `see notes.md`, `cf. TODO.md`, `// Source: <path>`) where the referenced path **does not exist in the repo**. Resolve relative refs against the comment's file. | Warning | Comments that point at files which were never committed are pure rot. |
| G10i | **Long JSDoc / docstring on non-exported / internal function** | JSDoc-style block (`/** … */` or `""" … """`) of ≥ 3 narrative-prose lines (not `@param`/`@returns` tags) attached to a function or method that is NOT exported / public / part of a documented API surface. Heuristic: the symbol has no `export` modifier (TS/JS), no `public` modifier (C#/Java) where the language has one, or is prefixed with `_` (Python). | Info | Per the user's global CLAUDE.md: short, well-named internal functions don't need JSDoc. |

Explicitly out of scope (use your linter / AST tooling instead): `console.log`/`print`/`debugger` statements, commented-out code, unused imports, dead-code reachability analysis.

**G10 is an exception to the "no pure-regex checks" rule above.** Comment-hygiene patterns are deterministic, run cheaply, and catch a class of slop that no linter targets today. They are kept here (rather than offloaded to a linter) because they require the *diff* as context — they only fire on comments the current change introduces or modifies.

### 3b. Repo-specific checks (from `.claude/repo-patterns.md`)

The patterns file does NOT follow a fixed template. Each repo has whatever sections emerged when the patterns were inferred. Work with whatever's there.

**Before running any repo-specific check**, do three quick gates:

1. **Emptiness gate.** If `repo-patterns.md` contains no high/medium-confidence sections (or the only content is a marker like `status: no-consistent-patterns-detected`), report once: "No consistent patterns detected for this repo — repo-specific checks skipped." Skip 3b entirely.
2. **Conflict gate.** For each dimension (naming, layering, error handling, etc.) check whether two sections in the file document mutually exclusive conventions both at ≥medium confidence. If they do, mark that dimension as `inconsistent` and do NOT enforce it — flag the repo conflict once in the report instead.
3. **Approval gate.** If the skill is running on a proposed/draft patterns file, skip 3b entirely (handled in Step 2 state table).

For every remaining section with confidence `high` or `medium`, apply this universal check:
- Is there anything in the diff that deviates from the documented convention?
- If yes → flag it, cite the section header from the patterns file as the pattern key, show an existing example that follows the convention as reference.
- If the section says "Forbidden: X" / "Never: X" / "Only in <path>: X" — treat those as explicit rules.

**Semantic sub-check families** the inference step should try to populate, because they're worth checking when supported by evidence (but never invent them without evidence):

- **Layer / dependency rules.** If the inference step produced a dependency map (e.g. `frontend must not import from backend`, `db layer must not import ui`, `core must not import infra`), flag any import in the diff that crosses the forbidden boundary.
- **Abstraction drift.** If the repo has a dominant error/effect abstraction (`Result<_, _>`, `Either`, `Effect`, `Option`, custom `Outcome`, typed error hierarchy), flag any new code in the diff that bypasses it with raw `try/catch`, `panic!`, unchecked `.unwrap()`, raw `throw new Error`, etc.
- **Deprecation / migration drift.** If the repo contains markers like `@deprecated`, `DEPRECATED:`, `TODO: migrate to <X>`, `use <X> instead`, or a patterns-file section that names an old-and-new pair (e.g. "Use `NewFoo`; `OldFoo` is being phased out"), flag any new code in the diff that adds a new usage of the deprecated symbol/import/path while a replacement is documented. Cite both the deprecation marker and the replacement in the finding.
- **Structural completeness.** Patterns are not just line-level. If the patterns file documents an expected file-structure convention (e.g. "every `*.service.ts` has a matching `*.service.test.ts`", "every migration has a paired `down` file", "every route handler has a request-schema file"), flag any new file in the diff that violates the structural pairing. Evidence for these conventions comes from consistent sibling pairs observed during inference — if you saw the pairing in ≥2 areas, it qualifies as a repo-wide structural rule.

**Do not invent checks that aren't in the patterns file.** If the patterns file doesn't mention a dimension, don't look for violations on that dimension.

**Respect exceptions.** If a `file:line` or `path-glob` appears in the "Exceptions" section of `repo-patterns.md`, skip flagging that pattern on that location.

**Respect dismiss tags.** If the commit message (WIP or last commit) contains `ignore-pattern: <pattern-key>` or `cc-skip: <pattern-key>`, skip that pattern for this run.

### 3c. Confidence, precision, and contextual severity

- Only fire a repo-specific check if pattern confidence is `high` or `medium`. Skip `low`-confidence patterns (high false-positive risk).
- **Contextual severity — base severity modified by location.** Do not treat all deviations equally:
  - Deviation in a production / core path (paths the repo treats as its main source — infer from the architecture map in Step 2) → keep or raise to **Blocker**.
  - Deviation in `examples/`, `samples/`, `demos/`, `playground/`, `sandbox/`, `scripts/`, `tools/`, ad-hoc throwaway folders → downgrade to **Info**.
  - Deviation in tests → keep at base severity unless the rule is clearly production-only (e.g. "no raw try/catch" shouldn't fire on a test that asserts a thrown exception).
- When in doubt, **don't fire**. A noisy tool gets ignored.

## Step 4 — produce report

Present the report **inline in the response** by default — do NOT write any file. Only write `.claude/last-me:check-consistency.md` if the user explicitly asks for the report to be saved. Use this structure (inline or saved):

```markdown
# Consistency Check — {ISO date}

**Target:** `<git command used>`
**Files touched:** N
**Checks run:** {generic count} generic + {repo count} repo-specific
**Patterns file age:** {days since repo-patterns.md was last updated}

---

## 🔴 Blockers (N)

{Only if any. Empty section allowed.}

### [check-id] Short title
- **File:** path:line
- **Issue:** one-sentence description
- **Evidence:** quoted diff snippet or explanation
- **Suggestion:** concrete fix
- **Dismiss:** how to skip this warning

---

## 🟡 Warnings (N)

{Same structure per item.}

---

## 🔵 Info (N)

{Same structure per item. Keep short.}

---

## Summary

- Total findings: N (X blockers, Y warnings, Z info)
- Recommendation: {commit as-is / fix blockers first / review warnings before commit}
```

Then summarise to the user with the counts + the top 3–5 items (NOT the full report). Keep user-facing output tight — a one-screen summary at most. Offer to print the full report or save it to `.claude/last-me:check-consistency.md` if they want the detail.

## Pattern inference

Evidence-only. No invented categories. Produce a set of inferred patterns reflecting what this repo actually does — presented inline by default, written to `.claude/repo-patterns.proposed.md` only on explicit user request. The format below applies whether the patterns are shown inline or saved.

### Phase 1 — Archetype & Anchor Mapping

**Step 1. Detect language + archetype.** Identify primary language(s) by file-extension frequency (skip `node_modules`, `dist`, `build`, `bin`, `obj`, `.git`, `__pycache__`, `venv`, `.venv`, `target`). Then classify archetype from root manifests, entry points, and top-level folder names. Record as `archetype:` in frontmatter. If undetermined from evidence, write `archetype: unknown` — do not guess.

| Archetype | Detection signals | Lens: what to look for |
|---|---|---|
| Service / API | `routers/`, `controllers/`, `middleware/`; FastAPI/Express/ASP.NET/gRPC deps | Request contracts, middleware chains, auth guards, HTTP status conventions |
| AI / LLM / Data | `torch`, `transformers`, `langchain`, `dbt`, `airflow`; `pipeline/`, `eval/` | Pipeline stages, prompt/eval split, dataset I/O, resource lifecycle |
| Library / SDK | Publishable manifest with `src/` layout and exported `index.*` | Public API surface, export hygiene, type stability, dep-bloat |
| Frontend / UI | React/Vue/Svelte/mobile deps; `components/`, `pages/`, `stores/` | Component composition, state side-effects, prop contracts |
| CLI / tool | `argparse`, `cobra`, `clap`; `cmd/`, `bin/` layout | Argument conventions, exit-code discipline, stdout/stderr separation |
| Mixed | Multiple manifests with independent `src/` trees | Apply per-sub-project lens independently |

**Step 2. Map areas.** Walk the top-level structure. Every distinct child folder + any sub-project (own packaging manifest) = one area. Label each area from evidence only — no guessing. This area map is the contract: every identified area MUST be sampled.

**Step 3. Sample — Anchor-and-Leaf, capped at ~30 files.**

| Category | Selection rule | Hard constraint |
|---|---|---|
| Entry point | File the runtime starts from | 1 per app / sub-project |
| Anchors | High in-degree files (imported by many, imports few): base classes, abstract interfaces, shared schemas, middleware registries, DI containers | Must pair with ≥2 Leaves |
| Leaves | Concrete implementors of each Anchor, from different directories | 2–3 per Anchor |
| Tests | Test files | ≥2 if tests exist |
| Manifests | Packaging / config files | 1 per sub-project |

**Hard constraint:** Never sample an Anchor without ≥2 Leaves from different directories, and vice versa. Anchor-only patterns = dead code. Leaf-only patterns = ad-hoc. Neither qualifies.

**Recency hard-gate:** Prefer files changed in the last 90 days (`git log --since="90 days ago" --name-only --pretty=format: | sort -u`). Files older than 90 days = Legacy / Tech Debt. Never promote a stale-only pattern to high/medium confidence.

### Phase 2 — 4-Dimension Extraction

For every archetype, document all four dimensions. Missing dimension = `status: not-observed`. Never omit silently.

| Dimension | What to look for | If found | If absent |
|---|---|---|---|
| **Boundaries** | Import restrictions between areas ("services never call controllers", "agents only access DB via `tools/`") | Forbidden-import rule with `path:line` evidence | `status: not-observed` |
| **Outcomes** | Success/failure signaling: `Result`, `Either`, typed exceptions, `(data, error)` tuples, `None` on failure, HTTP-status conventions | Document abstraction; list bypass patterns as Forbidden | `status: not-observed` |
| **Wiring** | Module init pattern: DI container, factory, singleton registry, FastAPI `Depends`, constructor injection, module-scoped globals | Document dominant pattern | `status: not-observed` |
| **Vocabulary** | Load-bearing name suffixes/prefixes with consistent semantics (`_handler`, `_schema`, `UseCase`, `Repository`) | List suffixes + their observed meanings | `status: not-observed` |

**Cross-Pollination Rule.** A pattern qualifies only if it exists in ≥1 Anchor AND ≥2 Leaf files in different directories. Patterns confined to one directory must carry `Applies in: <glob>` — no exceptions. Patterns that fail cross-pollination are discarded or scoped, not promoted.

**Confidence:**

| Level | Criteria |
|---|---|
| High | ≥5 cross-pollinated examples, ≥1 recent (last 90 days), zero or rare deviations |
| Medium | Dominant, cross-pollinated, ≥1 recent example, some exceptions |
| Low / omit | Single-folder, stale-only, or inconsistent — omit, or scope with `Applies in:` |
| Inconsistent | Two mutually exclusive conventions both at medium+ → `status: inconsistent`, not enforced |

**Required fields on every pattern rule:**

| Field | Content |
|---|---|
| `Provenance:` | `framework-imposed (<framework>)` or `local-convention` |
| `Structural match:` | Anchor→leaf relationship in prose (e.g. "Abstract `BaseAgent` at `agents/base.py:12` implemented by 7 classes in `agents/*.py`") |
| `Evidence:` | ≥3 `path:line` references, ≥1 from last 90 days |
| `Recency verification:` | Most-recent supporting file + its last-changed date |

### Phase 3 — Debt & Scope Filters

Apply after extraction, before writing the file.

| Filter | Constraint |
|---|---|
| **Recency hard-gate** | All supporting examples >90 days old → mark `status: legacy`, do not enforce |
| **Cross-pollination gate** | Pattern exists in only one area → add `Applies in: <glob>` or discard |
| **Negative space** | Pattern is frequent but marked `@deprecated` / `TODO: migrate to` / `DEPRECATED:` / `legacy` / `// will be removed` → write to `## Forbidden / migrating away` section only, never as active convention |

### Output rules

Present the inferred patterns inline by default. Render all rules as plain, readable Markdown — no HTML comments, no per-rule markers. The `status: proposed` frontmatter is the only indicator that nothing is enforced yet. Write them to `.claude/repo-patterns.proposed.md` only if the user asks to save the draft. When the user approves rules (by telling Claude which to keep), Claude writes `.claude/repo-patterns.md` with the approved set.

**Headers:** `## <Concern> — <convention referencing actual file/symbol from this repo>`. No bare nouns (`## logging`, `## naming`). Every header must be derivable from observed evidence in this codebase only.

**Self-check before writing:**
1. Every area from Step 2 has ≥1 pattern section citing evidence from it. If an area is missing: resample or write "no enforceable pattern here."
2. If every evidence link points to one folder: sampling was too narrow — redo Phase 1 Step 3.
3. No high/medium pattern found in any dimension → write `## No consistent patterns detected` with a one-line explanation. Do not invent rules.
4. Sub-projects (separate manifests): each gets its own section set or is explicitly noted as out-of-scope.

### Skeleton

```markdown
---
repo: <name>
archetype: <service | ai-pipeline | library | frontend | cli | mixed | unknown>
inferred: <YYYY-MM-DD>
confidence_overall: high | mixed | low
status: proposed
---

# Repo Patterns — <repo name>

> Archetype: <...>. Review the rules below — tell me which to keep (or "accept all") and I'll write `repo-patterns.md` to activate them.

## <Concern — convention referencing actual symbol/path from this repo>

- **Provenance:** framework-imposed (<framework>) | local-convention
- **Structural match:** <anchor→leaf relationship in prose>
- **Evidence:** path:line (×3+, ≥1 from last 90 days)
- **Recency verification:** <most-recent file> — <date>
- **Confidence:** high | medium | inconsistent
- **Applies in:** <glob>  ← required for single-area patterns
- **Forbidden / Never:** <bypass patterns to flag>

## [Boundary Contract] — <rule | status: not-observed>
## [Outcome Abstraction] — <rule | status: not-observed>
## [Dependency Wiring] — <rule | status: not-observed>
## [Semantic Vocabulary] — <list | status: not-observed>

## Forbidden / migrating away

- **Pattern:** <deprecated symbol/path>
- **Status:** being phased out — no new usages
- **Replacement:** <new pattern>
- **Evidence of deprecation:** path:line

## Exceptions (user-maintained)

## Custom patterns (user-added)
```

### Anti-patterns

- All evidence links point to one folder → sampling too narrow, redo Phase 1
- Sections invented without evidence → delete
- Section names imported from other repos or prior sessions → invalid
- Bare single-word headers (`## logging`, `## naming`) → rewrite with repo-native vocabulary
- Framework terminology applied without evidence → use plain observational language

## Edge cases to handle

- **Patterns file missing fields** — treat missing section as "no pattern documented, skip check".
- **Multi-language monorepo** — languages can differ per folder. Treat each folder with its own packaging manifest as an independent area. Each gets its own section set or is noted as out-of-scope.
- **Test files** — detect by path (`/test/`, `/__tests__/`, `.test.`, `.spec.`, `test_`, `_test.`). A repo-specific rule only fires on tests if the rule is clearly production-AND-test (e.g. naming convention); production-only rules (e.g. "no raw try/catch in business logic") should not fire on tests that intentionally assert error behaviour.
- **Throwaway folders** — `examples/`, `samples/`, `demos/`, `playground/`, `sandbox/`, `scripts/`, `tools/` → deviations get the contextual downgrade from 3c (Warning → Info, Blocker → Warning).
- **Commit message dismissals** — `cc-skip: <check-id-or-section-slug>` at the end of the commit message skips those checks for that commit. IDs are either generic check IDs (e.g. `g2`) or a short slug of a `repo-patterns.md` section header.
- **Diff spans renames** — use `git diff --find-renames` so a file move isn't flagged as "new file violating naming convention" if the rename is consistent.

## Output discipline

- Never list more than 20 findings in the report. If more, list top 20 by severity + count + "N more items…".
- User-facing summary: ≤15 lines. Counts + top 3 items + pointer to full report.
- If NO findings: say so in one line. "Consistency check passed: N files, 0 findings."
- Never recommend a fix you can't apply automatically unless asked. Just point out the issue.

## Safety

- Read-only by default. Never auto-edit files to "fix" findings. **Never create any file unless the user explicitly asks** — the report and inferred patterns are presented inline by default.
- Files this skill may write, and only on explicit user request: `.claude/repo-patterns.proposed.md` (when the user asks to save the draft, or runs `re-infer`), `.claude/repo-patterns.md` (when the user approves rules), and `.claude/last-me:check-consistency.md` (when the user asks to save the report). Never write `.claude/repo-patterns.md` without the user approving the rules.
- `re-infer` is an explicit request to refresh the draft — it may overwrite `.proposed.md`, but never the approved `.md`. If the user wants to refresh approved rules, they hand-merge from the new draft.
- Only create `.claude/` when you are about to write one of the files above at the user's request.

## Failure modes

- **Can't run git** — report "not a git repo" and stop.
- **Git command fails** — print the error, don't silently continue.
- **Patterns file malformed** — tell the user, ask for `re-infer` or manual fix. Don't proceed with half-parsed patterns.
- **No diff target** — tell the user (e.g. nothing staged, no second ref).
- **Draft pending (`.proposed.md` exists, `.md` does not)** — run generic checks only; remind user to approve the draft at the end of the report.

## Relationship to other skills

- **`/safe-commit`** — runs first, blocks on secrets. This skill runs after, reviews quality. Some overlap on secret detection (intentional — belt + braces).
- **Linters (ESLint, Prettier, Roslyn, etc.)** — run independently via the user's tooling. This skill doesn't duplicate lint rules.
- **`/simplify`** — fix-oriented. `/me:check-consistency` is review-oriented. User might run `/me:check-consistency` first to find issues, then `/simplify` to fix.

## Versioning

Each run of `/me:check-consistency` stamps the report with:
- Timestamp
- Git commit SHA of HEAD
- Target diff description
- Age of `repo-patterns.md`

If patterns file is >90 days old, warn the user: "patterns last inferred N days ago — consider `/me:check-consistency re-infer`".
