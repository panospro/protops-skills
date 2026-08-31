# Success states

The screen people take for granted when it's there and immediately notice when it's not. Every completed action — a button press, a like, a payment — needs feedback that it *worked*.

- **Transactional actions need an explicit success state.** The canonical failure: a $450 flight booking where clicking "Confirm Booking" changes nothing on screen. The user's inner monologue — "Did it go through? Did it charge me? Should I press it again?" — is the worst feeling an interface can produce, and a repeat press can double-charge. The correct sequence: button → "Processing…" with a spinner → a dedicated confirmation state (green checkmark, the key details, "You're all set to fly!"). Money moving without visible confirmation is always a finding.
- **Match feedback weight to action weight.** Some moments deserve a full celebration page (finishing a major task, a first milestone) — used sparingly. Routine actions need only small, intuitive signs: a card dragged to "Done" *staying there* is its own confirmation; an inline checkmark filling is enough. Sometimes the cleanest confirmation is the action itself visibly completing — no popup required. Confetti on trivial actions is noise that devalues real milestones.

**Audit checks:** mutations that resolve with no visible state change, payment/booking/submission flows lacking a dedicated success state, double-submit possible because the button never reflects completion, and (inverse) heavyweight modals celebrating trivial actions.
