# Forms

Nobody likes filling out forms; these six behaviors reduce the frustration. All are cheap to implement and all are commonly missing from generated code.

1. **Gate submit, but explain the gate.** Keep the submit button disabled until required fields are valid — and mark required fields visibly (e.g. a red "REQUIRED *" beside the empty field). A grayed-out button with no explanation is *more* frustrating than no gating at all: the user is left guessing why they can't submit.
2. **Validate inline, on blur.** The moment someone leaves an email field containing `hello@company`, show the red outline + "Please enter a valid email address" beneath it. The failure mode this prevents: fill everything → submit → wait for the round-trip → scroll back up hunting for the broken field.
3. **Live character counters** on length-limited fields — "15 / 40" ticking up as they type, flipping red with an "Over limit" state ("59 / 40") when exceeded. Never let someone write a paragraph and *then* learn they must delete half of it.
4. **Prefill what you already know.** Logged-in users don't retype their email — populate it (with a validation checkmark) and let them move on.
5. **Password rules as a live checklist.** Show the requirements under the field ("8+ characters", "One uppercase letter", "One number", "One special character") and flip each from red exclamation to green check as it's satisfied. Rules revealed only by a failed submit are a design failure.
6. **Be forgiving with formats.** A phone field should accept `5551234567`, `(555) 123-4567`, `555 123 4567`, `555-123-4567`, and `555.123.4567` alike, normalizing server-side. Applies wherever the backend can normalize — rejecting valid data over cosmetic formatting is friction with no benefit.

**Audit checks:** validation firing only on submit, disabled submit without required-field markers, `maxLength` fields with no counter, known-user data left blank, password rules that appear only in the rejection error, input masks/regexes that reject valid-but-differently-formatted values.
