---
name: next-step
description: Documents the next-step hook. Installs a UserPromptSubmit hook that injects a `**Next:**` directive on every user prompt so Claude ends each response with a single copy-pasteable slash command. No slash command of its own — it's pure hook behavior. Disable by uninstalling the plugin.
---

# next-step

A tiny UserPromptSubmit hook that asks Claude to end every response with:

```
**Next:** `/some-command with args` — [brief description]
```

## Why

Reading a long response and then having to invent the next command yourself wastes attention. A `**Next:**` line at the bottom keeps continuity. This plugin is the *lightweight* version of that behavior — extracted from mk-flow's much bigger `intent-inject.sh` (259 lines of intent classification, rules engine, drift-check, etc.).

## Files

- `hooks/next-step.sh` — the hook body. Prints 3 lines on stdout, which Claude Code injects into the user prompt.
- `hooks/hooks.json` — registers the hook on `UserPromptSubmit`.

## Customising the injected text

Edit `hooks/next-step.sh`. The text between the heredoc markers is exactly what Claude sees. Keep it terse — every byte is in your context window every prompt.

## Coexistence with mk-flow

If you have Miltos's `mk-flow` plugin installed, BOTH this and mk-flow inject a `**Next:**` directive (mk-flow's includes much more — intent routing, rules, etc.). Pick one:

- Want only this: `claude plugin uninstall mk-flow@mk-cc-resources`
- Want only mk-flow: `claude plugin uninstall next-step@protops-skills`
- Want both: harmless, just slightly redundant tokens per prompt.
