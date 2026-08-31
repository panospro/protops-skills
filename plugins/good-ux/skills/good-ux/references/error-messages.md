# Error messages

AI code generators are notably bad at error states by default — they build the happy path. These rules are what to check for and what to ask for.

## Content rules

- **Never render raw backend errors.** A modal showing `userID: 34fd3d4dfjnke`, `STORAGE_QUOTA_EXCEEDED`, and trace IDs fails twice: a regular person can't interpret it, and it leaks backend implementation details — a security exposure.
- **"Something went wrong" is also wrong.** After a payment click it leaves the user not knowing whether they were charged — the exact uncertainty an error message exists to remove.
- **A good error message does three things**: says *what happened*, *why*, and *what to do next*. The canonical shape: "Your payment didn't go through. Your card was declined. Please check your card details or try a different payment method."
- **No silent failures.** A submit button that does nothing — no state change, no message — is the worst error state ("did that even work?"), and it's what AI tools generate by default when a failure path isn't requested. Every action produces a visible state change or an explicit error.

## Placement — toast vs modal vs inline

| Mechanism | Behavior | Use for | Never for |
|---|---|---|---|
| Toast | Pops at top/bottom, auto-dismisses in seconds | Transient low-severity status: "Couldn't connect — retrying…" | Anything critical. The test: *if the user looks away and misses this, are they okay?* If not, no toast. |
| Modal | Takes the center, blocks everything until answered | Hard blockers only — the user cannot proceed without resolving it. Failed payment → "Your payment couldn't be processed" + **Update your card** button. No access → **Request access** button. If you block the user, you owe them a way forward. | Non-blocking issues. Use sparingly. |
| Inline | Appears next to the thing that failed | The default — most errors belong here. Invalid field: red border + message directly beneath ("That username is already taken."). Failed button action: "Couldn't save, try again" directly under the clicked button. | — |

The governing rule: **the closer the error is to the issue, the better** — the user's eyes are already there.

**Audit checks:** `catch` blocks that swallow errors silently, generic "something went wrong" strings, raw error payloads/stack traces rendered to the UI, critical failures routed to toasts, modals without an action button, and field validation errors displayed far from the field.
