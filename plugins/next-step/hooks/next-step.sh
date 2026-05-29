#!/usr/bin/env bash
# UserPromptSubmit hook. Stdout is injected into the user prompt.
# Tells Claude to end every response with a Next: line.

cat <<'INSTRUCTION'
End every response with: **Next:** `/exact-slash-command with arguments` — [brief description]
The command must be copy-pasteable (e.g., "/me:check-consistency staged").
Skip the next-action line if the response IS a slash command execution (skill handles its own flow).
INSTRUCTION
