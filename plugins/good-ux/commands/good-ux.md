---
description: Frontend UX audit — scan the repo or diff the current change. Checks loading/error/empty/success states, forms, degradation, accessibility, destructive-action guards, familiarity laws, and dark patterns. Reports findings first; fixes on approval (--fix applies immediately).
---

Run the `good-ux` skill. Default mode is `diff` (current uncommitted changes); pass `scan` for a whole-repo audit (optionally followed by a path), or `--fix` on either mode to apply auto-fixable findings without the approval gate. Guide mode has no command — the skill offers it when it notices relevant UI work, and enters it only if you accept.

Arguments: $ARGUMENTS
