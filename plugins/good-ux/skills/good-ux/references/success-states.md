# Success states

- **Transactional actions need explicit success feedback.** Clicking "Confirm Booking" with no visual change leaves the user asking "Did it charge me?". Payments, bookings, and submissions must transition to a clear confirmation state (loading indicator → success screen/notice). Uncertainty after money moves is the worst outcome.
- **Match feedback weight to action weight.** Not every task earns a modal or confetti: for routine actions the cleanest confirmation is the action visibly completing — a card sliding into "Done", an inline checkmark filling. Full-screen celebration for minor actions is noise.

**Audit checks:** mutations that resolve without any visible state change, payment/submission flows with no dedicated success state, and (inverse) heavyweight modals confirming trivial actions.
