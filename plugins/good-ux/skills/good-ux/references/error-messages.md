# Error messages

## Content rules

- **Never show raw backend errors** — stack traces, database exceptions, internal IDs. Users can't interpret them, and leaking server internals is a security risk.
- **A good error message meets three criteria**: what happened, why it happened, what the user can do next. Replace "Something went wrong" with the shape of "Your payment didn't go through. Your card was declined. Please check your card details or try a different payment method." Users must know the state of their action (was money charged?) and the recovery path.
- **No silent failures.** A button that does nothing when clicked is the worst case — the user is completely uninformed. Every action must produce a visible state change or an explicit error.

## Placement rules

| Mechanism | Use for | Never for |
|---|---|---|
| Toast (auto-dismisses) | Transient, low-severity status — "Couldn't connect, retrying…" | Critical errors the user must not miss |
| Modal (blocks everything) | Hard blockers the user must resolve to proceed — failed payment, access denied. Must always include an action button ("Update your card", "Request access") | Anything non-blocking; use sparingly |
| Inline (next to the source) | Form field validation, button-action failures — red border + message below the field, or error text directly under the clicked button | — |

The closer the error is to the issue, the easier it is to notice — the user's gaze is already there.

**Audit checks:** `catch` blocks that swallow errors silently, generic "something went wrong" strings, error payloads rendered raw, critical failures routed to toasts, and modals without an action button.
