# Destructive and irreversible actions

The dark-patterns file governs how hard it is to *leave*; this one governs how easy it is to *lose something*. Both failure directions are real: friction on a reversible action is annoying, but no friction on an irreversible one is data loss. Match the guard to the blast radius.

## Choose the guard by consequence

| Action | Guard |
|---|---|
| Reversible, small (archive a row, remove an item from a cart, mark read) | No dialog. Do it immediately and offer **Undo** in a toast (~5–10s is a reasonable default; longer for anything the user might only notice after scrolling away). Interrupting for a confirmation the user will always accept trains them to click through dialogs. |
| Reversible with effort (delete a document that lands in a trash/bin) | No dialog, or a lightweight one. Say where it went ("Moved to Trash") and how long it stays. |
| Irreversible, bounded (permanently delete one file, revoke a session) | A confirmation dialog naming the specific object and the consequence. |
| Irreversible, high blast radius (delete a workspace, drop a database, cancel a paid plan mid-term, bulk-delete N items) | Type-to-confirm: the user types the resource name (or "DELETE") to enable the button, plus an explicit summary of what is destroyed and what cannot be recovered. |

**Undo beats confirm wherever it is technically possible.** A confirmation dialog costs every user a click to protect against a rare mistake; undo costs nothing until the mistake happens. Confirmations are for when undo genuinely cannot exist.

## Writing the confirmation

- **Name the object and the consequence, not the abstraction.** "Delete `invoices-2026.csv` permanently? This cannot be undone." beats "Are you sure?" — a dialog whose text could apply to anything teaches the user to ignore dialogs.
- **State scope for bulk actions.** "Delete 47 selected orders" — the count is the safety mechanism. Include what cascades: child records, shared links, teammates who lose access.
- **The button says the verb, not "OK".** "Delete permanently" / "Cancel plan" as the action label; the escape route is "Cancel" or "Keep". A user scanning only the buttons must be able to tell which one destroys.
- **Style the destructive action as destructive** (danger color, never the calm default) — but keep it a real, obvious button. Making it *hard to find* is the dark pattern in reverse; making it *visibly consequential* is correct.
- **Never make the destructive action the default focus** of the dialog, and never let Enter alone trigger it.

## After the fact

- **Confirm the deletion happened** — this is the success-state rule applied to removals: the row disappears *and* a toast says what was deleted, with Undo if available. Silent removal leaves the user wondering whether they deleted the right thing.
- **Deletion that takes time gets progress**, not a frozen dialog (see loading-states thresholds); deletion that fails gets a real error explaining what state the data is in now.
- **Don't destroy on navigate.** Unsaved changes in a form or editor warrant a guard when the user navigates away or closes the tab (`beforeunload` or a router prompt) — or, better, autosave and drop the prompt entirely.

**Audit checks:** delete/remove/revoke/reset handlers with no confirmation and no undo path; irreversible operations guarded only by a generic "Are you sure?"; bulk operations that don't state the count or scope; account/workspace deletion without type-to-confirm; destructive buttons styled as the primary/default action or autofocused; deletions with no post-action confirmation; forms and editors that discard unsaved input on navigation without warning or autosave.
