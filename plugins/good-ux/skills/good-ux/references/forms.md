# Forms

- **Disabled submit needs visible reasons.** Disable submit until required fields are valid, but mark required fields explicitly (e.g. "REQUIRED *"). A grayed-out button with no explanation is the failure mode.
- **Validate inline on blur**, not on submit. Show the error outline + helper text the moment the user leaves an invalid field, so they never submit, wait, and scroll back up to fix.
- **Live character counters** on any length-limited field ("15 / 40"), turning red when over limit.
- **Prefill what you know** for authenticated users (email, name).
- **Password rules as a live checklist**: show the requirements below the field and check them off as the user types — rules must be known before a failed submit, not after.
- **Accept any reasonable format and normalize**: phone numbers with dashes, spaces, dots, parentheses all accepted, normalized server-side. Depends on backend capability — apply when possible.

**Audit checks:** forms validating only on submit, disabled buttons without required-field markers, `maxLength` fields without counters, empty fields the session already knows values for, password inputs whose rules appear only in the rejection error, and input masks that reject valid-but-differently-formatted values.
