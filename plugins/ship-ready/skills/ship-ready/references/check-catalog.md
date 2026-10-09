# ship-ready — check catalog

Per-module detectors. Cheap deterministic ones are regex over the **target set** (run via `scripts/scan-target.sh <mode>` or `grep`); semantic ones require reading the candidate files. The target is **the added lines of all uncommitted changes by default** (staged ∪ unstaged ∪ untracked), every line of the changed files with `--whole-files`, or every line of the whole publish set with `--full` (see `scan-target.sh`). Exclude lockfiles from content scans. All detection is **folder-agnostic** — by content / markers / heuristics, never by assuming `seeds/` or `docs/`.

Path sets used by the scan: **docs** = `.md/.mdx/.txt/.rst` anywhere; **test** = a non-doc file under `tests/`, `__tests__/`, `spec/`, `fixtures/`, `mocks/`, `sandbox/`, `e2e/`, `examples/`, or named `*.test.*` / `*.spec.*`; **src** = code that is neither.

Severity is contextual: a hit in a core/source path is higher than the same hit in `examples/`, `scripts/`, `sandbox/`, `fixtures/`. PII severity is set by the **audience** gate (internal → Info; public → Blocker).

---

## Module 1 — audit-core

### 1a. Secrets (Blocker)
Reuse the `me:safe-commit` catalog. High-confidence patterns: AWS `AKIA[0-9A-Z]{16}`; GitHub `gh[pousr]_[A-Za-z0-9_]{36,}`, `github_pat_`; GitLab `glpat-`; Slack `xox[baprs]-`; Stripe `sk_live_`/`rk_live_`; Google `AIza[0-9A-Za-z_\-]{35}`; private-key headers `-----BEGIN (RSA |EC |OPENSSH |PGP )?PRIVATE KEY`; DB URLs with creds `(mongodb|postgres|mysql|redis|amqp)://[^:]+:[^@]+@`; generic `(api[_-]?key|secret|password|token)\s*[=:]\s*['"][^'"]{8,}['"]`; bearer `['"]Bearer\s+[A-Za-z0-9._\-]+['"]`.
**Env-style assignments:** `KEY=value` in `.env`/config files, **unquoted and any case** (`API-KEY=…`, `db_password=…`), are caught by a separate **case-insensitive** branch (`scan-target.sh`, passing `-i` to `scan`) that requires a ≥12-char value and filters common placeholders (`example`, `changeme`, `your_…`, `<…>`, `${…}`, `dummy`, `redacted`). The quoted-only generic regex above misses these on its own — this is the gap that let an unquoted `.env` secret through the secret scanner (it was only stopped by the filename heuristic in module 3b).

**Limitation:** bare UUIDs/high-entropy strings in prose (e.g. an API key written as `value `\``ccc4…`\``) won't match a key=value regex — scan documentation/markdown for known-credential shapes too, and read any file that *describes* auth.

**Masking:** the scan prints secret hits with each value cut to its first 4 characters and its length (`sk_l…(32)`). Keep that form in the report and the fix-plan; the full value is read from the file only when the fix needs it, and is never copied anywhere.

### 1b. Hardcoded home/user paths (Blocker)
`/(home|Users)/[a-zA-Z][a-zA-Z0-9._-]+/`, `/mnt/c/Users/[^/]+`, `[A-Za-z]:[\\/]{1,2}Users[\\/]{1,2}[a-zA-Z]`, and any `/tmp/.../<encoded-project-path>` agent-transcript path. Includes paths inside comments (e.g. `// Source: /home/me/...`).

### 1c. Personal identifiers (Blocker→public / Warning→internal)
- OS username: detect the repo owner's username (`git config user.name`/`user.email` local part, and the literal home-dir segment) and grep for it across the set. The scan labels these checks by their source (`owner name (git user.name)`) and never prints the values; the report does the same.
  - **Published-identity exemption:** if the owner handle appears **only** in plugin-manifest attribution fields (`author.name`, `repository`/`homepage` in `.claude-plugin/*.json` or a plugin's `plugin.json`), it's the intended publish identity → `keep`, not a judgment call. Still flag it in source / comments / data; always flag the *private* git work identity (real name, work email).
- Real names: grep for the `git config user.name` tokens; also workspace/team names (`<Name>'s Workspace`).
- Emails: `[A-Za-z0-9._-]+@[A-Za-z0-9.-]+\.(gr|com|net|org)` (filter `example.com`, `@types/`, schema URLs).
- Employee codes / maker IDs: project-specific shape (e.g. `\bE[0-9]{5}\b`). Confirm shape by sampling before flagging en masse.

### 1d. Workflow / AI-tool leakage (Warning)
- Skill / slash-command refs: `/[a-z-]+:[a-z-]+`, `/create-sandbox`, `create-sandbox`, named build-phase tags `\bCap [0-9]+`, `SKELETON:`, `AGENT:`, "matches skill limitation", "regenerate via /…".
- AI refs: `\b(claude code|anthropic|claude\.ai)\b` (allow legitimate `~/.claude/...` config paths and CLAUDE.md itself).
- ISO generation stamps: `Generated:\s*20\d\d-\d\d-\d\dT` (drop the timestamp; keep the "auto-generated / regenerate from X" line).

### 1e. Comment voice (Warning / Info) — only on comment lines
- First-person: comment containing `\b(we|our|us|let's|we'll|we're|I'll|I'm)\b` (skip quoted error strings, `i.e.`, `e.g.`).
- `Note:` prefix: comment starting `(//|#|\*)\s*[Nn]ote:`.
- Translator commentary: `mirrors the (C#|Java|Python|Go|TypeScript) (impl|original)`, `matches the C# (version|behavior)`, `the C# (impl|original) (returns|does)`.
- Dangling cross-ref: comment references `<file>.md`/`<path>` that is **not in the publish set** (resolve relative to the comment's file). This overlaps module 3a.
- Long narrative JSDoc on a non-exported/internal symbol (Info): `/** … */` ≥3 prose lines on a symbol with no `export`/`public` modifier.

### 1f. Hardcoded domain literal in logic (Warning)
A specific business/domain identifier or magic value embedded in **live logic** — most often a long numeric id in a comparison or switch (`=== '9000000428'`, `== "123456"`, `case '900…':`) — that special-cases one record/tenant/env instead of being driven by config, state, or a named constant. Cheap grep: a quoted ≥6-digit literal on the right of `==`/`===`/`!=`/`!==`, or after `case`. **Semantic confirm by reading**: is it a real domain value (customer/account/tenant code, magic threshold) hard-branching behavior? Source/core paths are higher severity than tests/fixtures (a literal in a test body is *data*, not a smell — skip it). Gated fix (not a blind auto-fix): extract to a named constant, to config, or — for record-specific behavior — drive it from seed/state (a flag on the record) so no code branches on a literal id. Overlaps `me:check-consistency`; ship-ready flags it because shipping a one-off hardcoded id is a maintainability + leak risk.

### 1g. Provenance / hearsay (Warning; docs: review)
A comment, test title, assertion message or doc that says **where a fact came from** — who said it, when, in which run — instead of what the code does and why. Examples: `// The owner (2026-09-22): "we show the document…"`, `// confirmed with the owner on the call`, `test("found in the live run: …")`, `assert.ok(x, "seen on QA during the sweep")`, `(captured in QA)`.
- Cheap grep (case-insensitive): owner + ruling/said/wants/asked/decided/words, owner within a few words of an ISO date, `(owner, …)`, `confirmed|agreed|checked with the owner|user|team|client`, `as discussed|agreed`, `per the chat|ticket|call|meeting|thread`, `the user told|asked|wants|said`, `live run`, `qa run`, `in this|the last session`, `seen|observed|captured … on|in QA|prod|staging|UAT|live`, `found in QA|the live …`, `the QA sweep`, `told me|us`.
- Where: comment lines and test titles in src; every line of test files (assertion messages count); every line of docs.
- **Work-note dates and tags** (Info): an ISO date, `F1 fix`, `Fix 3:` or `added in sprint 7` on a comment line or test title. The date often marks provenance the phrase list misses ("The owner's assumption under test (2026-10-07)").
- **Semantic confirm:** describing the *system's* contract stays ("the upstream returns the row in QA's shape"); the *act of observing* goes ("saw it on QA"). In docs, a decision record may name the decider **by role** ("(owner, 2026-10-07)"); session narrative ("re-checked this session", "verbatim in the inbox") goes.
- Fix: rewrite as an impersonal statement of the behaviour and its reason; the source belongs in the commit message or PR description.

### 1h. Internal infrastructure + private denylist (Blocker / Warning)
- **Private / raw IPs** (Blocker): `10.x`, `172.16–31.x`, `192.168.x`, and any IP literal in a URL (`http://203.0.113.7/…`). Loopback (`127.0.0.1`, `0.0.0.0`) is left to module 8.
- **Cloud / internal hostnames** (Warning): `*.azurewebsites.net`, `*.vault.azure.net`, `*.azurecr.io`, `*.core.windows.net`, `*.amazonaws.com`, `*.run.app`, `*.svc.cluster.local`, and `//host.internal|intranet|corp|lan|local`. In an internal-audience repo, deployment config naming its own hosts is usually intended → Info; in a public one → Blocker.
- **Private denylist** (Blocker): the terms only the user knows are sensitive — a confidential project's name or host, internal hostnames and IPs, login/employee codes, subscription and resource-group names. They live in **one file outside every repo**: `$SHIP_READY_DENYLIST`, default `~/.claude/ship-ready-denylist.txt`. Format, one entry per line:
  ```
  # comment
  some-internal-host.example        fixed text, case-insensitive
  re:\bE[0-9]{5}\b                  extended regex, case-insensitive
  DEMO-USER- @src                   flagged only outside test/fixture/sandbox paths
  ```
  The scan warns (Blocker) when the denylist file itself sits inside the scanned repo unignored — committing it would publish every term. Report a hit as `denylist entry <n> at <file:line>`; never write the term into the report, the fix-plan, a commit message, or a code comment. Never add denylist terms to the skill or to any repo file.

---

## Module 2 — dead-code

General dead code **and** dead config. All SEMANTIC — confirm a symbol is unreferenced by grepping it **repo-wide** (not just the diff) before proposing removal. Treat exported/public API cautiously (may have external callers) and watch for dynamic dispatch (string-keyed calls, DI, reflection, route tables).

**General dead code:**
1. Unreferenced exports/functions/classes/constants — grep the symbol name; 0 non-definition references → candidate.
2. Orphaned files — a module imported by nothing.
3. Unreachable branches / commented-out code blocks.
4. Registered-but-unused endpoints/routes — domain-dependent; flag, don't auto-remove.

**Dead config (subcase):**
5. Collect declared env vars (`.env.example` / `.env.*`, `process.env.X` / `os.environ[...]`, config getters). For each, grep for reads — **0 reads → dead var.**
6. "Read but no effect" — a var read into a config field with **no consumer** (grep the field/getter), e.g. a returned config field nothing reads, or a value validated but never applied. Confirm by grepping the field, not just the env name.
7. Distinguish **required** (no default, asserted at boot) / **optional-with-default** / **dead**. Never remove a required var.

Fix tiers: `vars only` (edit `.env*` + docs) vs `vars + code` (also delete the dead symbol/getter/endpoint/file). Always re-typecheck/build after a `vars + code` removal.

---

## Module 3 — gitignore-doctor (bidirectional)

### 3a. Committed files referencing gitignored paths (Warning — dangling on clone)
For each gitignored dir/file (parse `.gitignore`, confirm with `git check-ignore <path>`), grep the target for references to it — both the path form (`<ignored-dir>/…`) and **bare filenames** that live under an ignored dir. Skip universally-ignored build/dep tokens (`node_modules`, `dist`, `build`, `coverage`, `.env`, glob entries) to avoid noise. Each surviving reference dangles for anyone who clones. Fix = make the comment/doc self-contained, OR un-ignore the referenced file.
**Bare-filename trap:** a path-prefixed grep misses `see foo.md` when `foo.md` lives under an ignored dir. Also grep for `[A-Za-z0-9_-]+\.(md|json|txt)\b` and resolve each against the target + `git check-ignore`.

### 3b. Files that should be ignored but aren't (Warning/Blocker)
Tracked or untracked-not-ignored files that look local-only or generated:
- secrets/env: `*.env` (except `.env.example`), `env.*.json` carrying keys.
- generated outputs: report files a gitignored tool writes (e.g. `*-report.json`), build output, coverage.
- PII data dumps, captured responses.
- large/binary: non-text, or text > 500 KB (flag for awareness, not auto).
Fix = append the pattern to `.gitignore` (applied directly as an in-file edit — create the file if absent, skip if already present) + `git rm --cached <path>` if already tracked (emitted as a command).

---

## Module 4 — pii

Scope: **structured test-data / fixtures in the target, identified by content+shape, not by a `seeds/` path.** A file qualifies when it's data (JSON/CSV/SQL/YAML/seed-like) with repeated record structures AND carries PII shapes. Prose/code with incidental PII is handled by audit-core (flag only), not scrubbed here.

1. Detect real-looking PII: full names (incl. non-Latin scripts), national/tax IDs (locale-specific — SSN / AFM / AMKA / NINO and similar fixed-length digit strings), employee/customer/account codes, emails, DOBs (`\d{4}-\d{2}-\d{2}`), phone numbers, IBANs.
2. Propose a **consistent synthetic mapping** — each distinct real value maps to one fake value, reused everywhere it appears so cross-references stay intact. Generated fakes must preserve type and shape: string→string, digits→digits, and the same length/format where the field is validated (IDs, codes, dates). Never map a value to a different type.
3. Apply via a recursive walk that replaces keys+values+substrings. **CRITICAL type check:** after scrubbing, re-read a sample — a value→value mapper that falls through to an implicit `return None`/null for unhandled types will silently null every number. Verify counts and types are unchanged except for the intended replacements.
4. Audience gate: internal → optional (often "safe within org"); public → mandatory scrub.

---

## Module 5 — gen-hygiene (generated/translated files only)

Identify generated files by header markers ("auto-generated", "DO NOT EDIT", "translated from", "regenerate from") or known generator output paths. Then:
- Absolute-path provenance: `^// Source: /…` per-symbol comments → strip the abs prefix (relativize) or drop. If the relative target is itself gitignored, dropping is cleaner.
- ISO `Generated:` timestamp in the header → drop (git tracks write time).
- Unsubstituted template placeholders left in output → real generator bug. High-signal forms: `\[Controller\]`, `<%= … %>`, `__PLACEHOLDER__`. NOTE: `{{var}}` is **legitimate** in Postman collections / Handlebars / Jinja — never blanket-grep it; only treat `{{…}}` as a leftover placeholder after reading the file and confirming it's a generated *source* file. Flag and offer to strip the per-symbol boilerplate block.
- Stale lifecycle headers: "stub", "for later implementation", "not yet implemented" on a symbol that is now fully implemented (count method bodies / lines). Rewrite to an accurate header.
- **Template-vs-output decision:** when the slop comes from the generator, note that the real fix is the generator template; offer to clean the current output AND flag the generator.

When stripping repetitive boilerplate blocks (e.g. N identical per-method JSDoc): confirm the block is uniform first (count occurrences vs anchors), preserve any block that also carries real prose, and re-typecheck after.

---

## Module 6 — docs (distiller)

Scope: **every** `.md`/`.mdx`/`.txt` in the target is a doc candidate, in **any folder** (do not assume a `docs/` folder). The filename heuristic (`*-report*`, `*-v\d`, `plan`, `status`, `notes`, `TODO`, `session-*`, `scratch`, `wip`, `draft`) + content signals (iterative logs, checklists, session reports) just flag the likely-slop ones. Classify each:
- **delete (slop):** iterative/versioned working logs (`*-report.md`, `*-v2..vN.md`, parity logs), build plans with checkboxes, status/TODO logs, session notes, anything superseded by code + a clean doc.
- **distill:** a doc with durable content buried in cruft → author a fresh, clean version (architecture, decisions) from the actual code as fact-source; self-contained, no dangling cross-refs, no session tags / source footers / sibling-repo paths.
- **keep:** already-clean durable reference (README, clean architecture/decisions).
Author fresh docs by reading the code + existing docs *for facts only* — do not carry over the old prose. Never delete a doc the user's README/CLAUDE.md still references without flagging the now-stale reference. Deletions are emitted as `rm` commands.

---

## Module 7 — triage (runs in P5, post-fix) — per-file verdict, grouped by folder

Read `git status --porcelain` and give every changed/untracked path ONE verdict, then print **grouped by folder** with a one-line reason:
- **commit** — clean, safe to stage + commit now (no findings, or all its findings fixed).
- **hold** — leave unstaged: debug/WIP/incomplete/experimental edits, or a path still carrying a **deferred** finding.
- **gitignore** — local-only / generated output / secret-bearing → don't commit (`.gitignore` add + `git rm --cached` if tracked).
- **delete** — approved slop / dead / superseded → `rm`.

Mapping: staged file with no open finding → **commit**; a path with a deferred (unselected) finding → **hold**; untracked generated/secret/local artifact → **gitignore**; approved-for-deletion → **delete**. Emit the per-folder table; when the **commit** set is clean and non-empty, propose **3–5** compact commit-message candidates in `type: subject` form (conventional prefix, ≤~72-char subject, no body) derived from the diff — ~3 for a focused single-concern set, up to 5 only when it spans multiple concerns — for the user to pick. `.gitignore` additions are already applied in-file (P3), so they're staged, not commanded. THEN one consolidated command block (`git add` / `git restore --staged` / `git rm --cached` / `rm` / `git commit -m`) — nothing executed, the user runs it. Suggest `/me:safe-commit` as the final gate.

---

## Module 8 — debug leftovers

Things that are fine on a laptop and wrong in production. Cheap grep, then read the hit: a CLI or script that prints on purpose keeps its `console.log`.

| Check | Pattern | Where | Severity |
|---|---|---|---|
| Debug output / breakpoints | `console.(log\|debug\|trace\|dir\|table)(`, a `debugger` statement, `breakpoint()`, `pdb.set_trace(`, `import pdb`, `binding.pry`, `byebug`, `var_dump(` | src | Warning |
| Focused tests | `it/test/describe/context/suite.only(`, `fit(`, `fdescribe(`, `only: true` — every other test in the suite stops running | code | Blocker |
| Local / dev endpoints | `localhost:<port>`, `127.0.0.1:<port>`, `0.0.0.0:<port>` | src | Warning |
| TLS verification off | `NODE_TLS_REJECT_UNAUTHORIZED=0`, `rejectUnauthorized: false`, `strictSSL=false`, `verify=False`, `InsecureSkipVerify: true`, `curl -k/--insecure`, `GIT_SSL_NO_VERIFY` | everything but tests | Blocker |
| Dev switch defaulting on | an env-style name containing `SKIP_AUTH`, `DISABLE_AUTH`, `NO_AUTH`, `BYPASS_AUTH`, `INSECURE`, `ALLOW_ALL`, `DEV_MODE`, `DEBUG`, `SANDBOX`, `MOCK`, `FAKE` set or defaulted (`=`, `:`, `??`, `\|\|`) to `true/1/yes/on` | everything but tests | Warning |
| Non-test code importing test code | `from` / `require(` / `import(` of a path through `tests/`, `__tests__/`, `__mocks__/`, `mocks/`, `fixtures/`, `sandbox/` | src | Warning |

Project-specific sandbox markers (seeded ids such as `DEMO-USER-…`, a mock-only header) belong in the private denylist with the `@src` suffix (§1h), so they are flagged in production code and allowed in tests.

Semantic confirm: a dev default is fine when production config always overrides it and the override is required at boot; it is a finding when an unset variable silently lands on the dev behaviour. Fix: remove the leftover, or move the default into dev-only config (`.env.example`, a dev script) and make production fail fast when the variable is missing.
