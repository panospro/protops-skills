---
description: Pre-commit / pre-distribution audit + guided cleanup of the lines your changes add (or the whole repo with --full) — secrets, personal identifiers, internal hosts + private denylist, provenance comments, debug leftovers, dangling gitignored refs, workflow/AI leakage, generated-file slop, dead config/code, PII. Stops with a fix-plan you select from before anything changes.
---

Run the `ship-ready` skill — its audit + guided-cleanup pipeline. Default target is the added lines of all uncommitted changes (staged ∪ unstaged ∪ untracked); `--whole-files` reads every line of the changed files, `--full` the whole repo; the arguments below set mode / scope / flags.

Arguments: $ARGUMENTS
