# Dark patterns — detectors

**Policy: every finding in this file is FLAG ONLY — never auto-fixed, `--fix` included.** Whether a retention screen or opt-out flow changes is a product decision. These patterns cause user resentment, regulatory scrutiny, and legal penalties.

## Roach motel

Effortless to join, intentionally hard to leave: stacked modal barriers ("Are you sure?" → "Pause instead?" → "Confirm one more time") instead of single-click cancellation. Extreme forms: requiring physical mail or in-person requests to cancel a digital subscription.

*Detect:* count steps to subscribe vs. steps to cancel/delete-account; flag missing cancel routes, support-contact-only cancellation, and chains of 2+ confirmation interstitials.

## Cancellation friction

- **Buried cancel**: the option hidden several menu levels deep (Settings → Account → Purchases → Subscriptions). User motivation is lowest at cancellation, so every extra step raises abandonment. Correct: cancel visible at the top level of account/subscription settings.
- **Rigged visual hierarchy**: a large bright "Pause Subscription" button over a tiny, low-contrast "continue to cancel" text link. Correct: the cancel affordance gets readable contrast, clear clickability, and prominence equal to the alternatives.
- **Endowment-effect screens**: "You have a 847 day history — do you really want to get rid of that?". Loss-aversion interception; correct is direct cancellation without it.

## Retention-flow manipulation

- **Exit-survey routing**: survey answers dynamically route to tailored hurdles ("too expensive" → discount modal; "not using it" → pause modal). Exit surveys can be genuine feedback collection — flag only when the answer changes or blocks the path to completing cancellation.
- **Escalating offers**: 2-months-free → 50%-off pop-up chains, betting the user forgets to cancel when full pricing resumes.

## Confirmshaming

Decline options phrased to shame: "No thanks, I hate saving money", "I am a monster, cancel anyway", "No, I'm willing to risk my flight". Recognized confirmshaming turns guilt into psychological reactance and brand resentment. Correct: a neutral "No thanks" / "Cancel subscription".

*Detect:* scan microcopy of decline/opt-out buttons and modals in signup, checkout upsell, newsletter, and cancellation flows for first-person shame phrasing.
