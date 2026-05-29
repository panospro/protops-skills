---
name: standup
description: Generate a daily standup summary from git activity. On-demand only — triggers when the user types `/me:standup`, asks for a standup, or says "what did I do yesterday". Reads git log for the user's commits over a window (default: last 24h on current branch's repo) and produces a 3-bullet Slack-style summary — Yesterday / Today / Blockers. Supports `--all` to scan multiple repos under `~/repos/`.
---

# me:standup

Daily standup generator. Reads git for what the user actually did, writes a short Slack-style summary.

## Invocation

```
/me:standup                         # current repo, last 24h (skip weekends)
/me:standup --since "2 days ago"    # custom window
/me:standup --all                   # scan every git repo under ~/repos/
/me:standup --repos <path>          # scan every git repo under <path>
```

## Flow

1. **Detect identity.** `git config user.email` in the target repo. If unset, ask the user once and stop (don't guess).
2. **Detect window.** Default: `--since="1 day ago"`. On Mondays, widen to `--since="3 days ago"` automatically so Friday's work is included.
3. **Select repos.**
   - Default: current working directory if it's a git repo.
   - `--all`: every directory under `~/repos/` that contains a `.git` folder. Skip directories where the user has no commits in the window.
   - `--repos <path>`: same as `--all` but rooted at `<path>`.
4. **Pull commits.** For each repo run:
   ```
   git log --author="<email>" --since="<window>" --all --no-merges \
     --pretty=format:"%h|%ad|%s" --date=short --name-only
   ```
5. **Check uncommitted work.** Run `git status --porcelain` and `git diff --stat` to surface in-progress items for the "Today" section.
6. **Group and summarize.** Per repo: cluster commits by theme (not by time). Collapse related commits into one bullet. Use the imperative past tense ("fixed", "added", "refactored"). Aim for 3–5 bullets total across all repos.

## Output format

```
*Standup — <YYYY-MM-DD>*

*Yesterday*
• <repo>: <what you did, 1 line>
• <repo>: <what you did, 1 line>

*Today*
• <in-progress bullet from uncommitted work, or ask user>

*Blockers*
• <none / ask user>
```

Rules for bullets:
- Strip ticket IDs unless the user's commit messages are heavily ticket-scoped (then keep them).
- Never list commit hashes in the output — this is for humans, not git archaeology.
- If nothing was committed in the window, say so plainly: "No commits in <window>" — then show uncommitted work if any.
- Keep each bullet ≤ 90 chars.

## Today & Blockers

- **Today:** seed from uncommitted work (`git status`, `git diff --stat`). If nothing is in progress, ask the user in one sentence: "What are you working on today?" and wait.
- **Blockers:** always ask the user once: "Any blockers?" Do not invent blockers from the git log.

## Output discipline

- The final output must be copy-paste-ready for Slack. No preamble, no "here's your standup", no trailing summary. Just the formatted block.
- If multiple repos, group Yesterday bullets by repo. If only one repo, drop the `<repo>:` prefix.
- Never include file paths, only human-readable descriptions of what changed.

## Edge cases

- **Not a git repo and no `--all`:** stop, say "not in a git repo — try `/me:standup --all` to scan ~/repos/".
- **No `~/repos/` dir:** if `--all` is used and `~/repos/` doesn't exist, ask where the user keeps their repos.
- **No commits anywhere:** output the block with "Yesterday: nothing committed" and move on to Today/Blockers.
- **Window crosses a merge:** `--no-merges` is on; fine.
- **Rebased / amended commits:** `--author` + `--since` are authoritative. Don't try to reconstruct pre-rebase history.
