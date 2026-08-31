# Dark patterns — detectors

**Policy: every finding in this file is FLAG ONLY — never auto-fixed, `--fix` included.** Whether a retention screen or opt-out flow changes is a product decision. Context for severity: these patterns draw regulatory action and lawsuits — click-to-cancel rules exist in several jurisdictions (with geo-split enforcement, some companies literally serve different cancellation flows per state), and a major retailer paid billions to settle over a cancellation flow that took 4 pages, 6 clicks, and 15 options (engineers internally nicknamed it after a decade-long war). Flag them plainly.

## The underlying mechanism

Sign-up happens at **peak motivation** — the moment the user was convinced to pull out a card. Cancellation happens at their **lowest** motivation; it feels like a chore before it starts. Every pattern below does one thing: add enough friction to outlast willpower. That asymmetry is why "exit as easy as entry" is the master rule.

## Roach motel

Easy to get in, intentionally hard to get out. The spectrum:
- Stacked interception modals: "Are you sure?" (big **Keep My Plan**, small *Continue to Cancel*) → "Pause instead?" → "Confirm one more time" (**STAY WITH US**).
- The extreme: no online cancellation at all — download a form, print it, mail it or hand-deliver it.
- The reference standard: one-click sign-up ⇒ one-click cancel ("Cancel Subscription" → done, confirmation shown).

*Detect:* count steps/clicks/screens to subscribe vs. to cancel or delete an account; flag missing cancel routes, support-contact-only cancellation, and any chain of 2+ confirmation interstitials.

## Cancellation friction

- **Buried cancel:** the link four menus deep (Settings → Account → Purchases → Subscriptions → plan → cancel) or at the bottom of a settings page. Every extra step is a measured chance the user gives up — the drop-off math is the point. Correct: cancel visible at the top level of subscription/account settings.
- **Rigged visual hierarchy:** "Want to take a break instead?" with a large bright **Pause for 1 month** button and a tiny, unstyled, barely-clickable-looking "continue to cancel" text link. The pause trap has a second hook: **billing auto-resumes when the pause ends**, whether or not the user ever opens the app again. Correct: the cancel affordance gets readable contrast, clear clickability, and prominence equal to alternatives.
- **Endowment-effect screens:** "You have a 847 day history — do you really want to get rid of that?" (trophy icon included). People overvalue what's theirs — history, playlists, streaks — so putting the user's own data in front of them makes leaving feel like throwing something away. Correct: direct cancellation without loss-aversion interception.

## Retention-flow manipulation

- **Exit-survey routing:** the survey answer decides the next hurdle — "too expensive" → 50%-off modal; "not using it enough" → pause offer. Exit surveys *can* be genuine feedback collection; flag only when the answer alters or blocks the path to completing cancellation.
- **Escalating offers:** decline 2-months-free, get 50%-off, then a "FINAL OFFER". Two mechanisms: an offer creates a felt obligation to genuinely consider it (negotiation tactic), and short discount windows bet on the user forgetting to cancel when full price resumes.

## Confirmshaming

Decline options worded to shame: "No thanks, I hate saving money", "I am a monster, cancel anyway", "No, I'm willing to risk my flight", "No, I don't want free shipping". Why it works: people mindlessly apply social rules to computers (the same reflex that makes people thank a chatbot), so a judging button reads like a judging person; clicking "I hate saving money" conflicts with one's self-image, and giving in resolves the dissonance. Why it backfires: the moment the user *notices* the manipulation, guilt flips to reactance — "you're not guilting me into this" — and the resentment attaches to the brand. Watch also for upsell framing that pairs the shame-decline with fear copy ("you could miss a connection…") and "only $X" price anchoring.

Correct: a neutral "No thanks" / "Cancel subscription".

*Detect:* scan the microcopy of decline/opt-out buttons and modals in signup, checkout upsells (insurance, warranties), newsletter prompts, and cancellation flows for first-person shame phrasing and fear-of-loss decline labels.
