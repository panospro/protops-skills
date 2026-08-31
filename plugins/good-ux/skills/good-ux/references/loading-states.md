# Loading states

## The four core states

Every screen has four states to design: loading, success, error, and empty. Users who see none of them don't think "slow" — they think "broken". A blank screen with no feedback loses users within 2–3 seconds. Loaders done well are invisible: users don't consciously notice them, they just wait longer without realizing it. Loaders done badly (or missing) are what users notice.

## Which loading indicator — decision tree

| Situation | Indicator | Why |
|---|---|---|
| Entire page or large content section loading | Skeleton screen mimicking the final layout | Tells the user "the layout is here, the data is coming" — the brain starts processing structure before content arrives. This is why feeds (social, video) skeleton-load their card grids. |
| Known/estimable duration: upload, download, install, compression | Determinate progress bar with progress + time remaining | The user needs to know how far along they are. A spinner on a file upload reads as *stuck*. |
| Small contained action: a clicked button, one component refreshing | Inline spinner inside the button/component | A skeleton makes no sense at that scale; the spinner says "working on it" exactly where the user is looking. |
| Low-stakes instant micro-action (like, favorite, toggle) | Optimistic UI — no loader at all | Update immediately (the heart turns red on tap without waiting for the server), roll back with a notice if the request later fails. Feels instant by design. |

Optimistic UI requires a client-side rollback path and a failure notification; determinate progress bars require actually measuring progress. Verify both exist before recommending these patterns.

## Duration thresholds

| Expected wait | Show | Why |
|---|---|---|
| < 1 second | Nothing — just show the result | One second isn't enough to play a full animation loop; a flashing spinner registers as "something weird happened" and makes the app feel *slower*. |
| 2–5 seconds | Plain spinner | Fine on its own in this window. |
| ~5–6 seconds | Spinner + static text ("Loading…", "Saving…") | Past 5s a bare spinner starts to feel broken; static text buys roughly one more second of patience. |
| up to ~10 seconds | Spinner + changing text ("connecting to your account…", "working on it…", "almost there…") | Users wait significantly longer when they perceive ongoing action — even when the messages don't map to real stages. |
| > 10 seconds | Progress bar or step-by-step indicator — never a looped spinner | Past 10s, looped animations flip: they actively increase frustration instead of easing it. |

On failure, surface the error the moment it's known. Never let someone stare at a spinner for 20 seconds only to get "sorry, that didn't work".

## Skeleton screens — doing them right

People polarize on skeletons, and the dislike has a mechanism: skeletons tend to appear when the connection is bad, so brains learn "grey boxes = slow". To land on the good side of the research:

- **Animate them.** Static grey boxes don't produce the perceived-speed benefit.
- **Shimmer wave, not pulsing fade** — sweeping **left to right**, slow and steady, not fast. That specific combination is what tests as faster; other variants test as the *slowest* option.
- **A skeleton is a promise of layout.** If the real content renders in a different arrangement than the boxes showed, everything jumps — a broken promise that actively annoys users. Match the skeleton's dimensions and alignment to the incoming components.
- **Skeletons suit waits under ~3 seconds** — they convey zero information about duration. On longer loads, switch to an explicit indicator with text ("Just a moment…"). Caveat: detecting a slow load and swapping indicators is genuinely fiddly to build, which is why most apps don't — but leaving users staring at a skeleton for 10+ seconds is the failure mode that made people hate them.

## Progress bars — honesty mechanics

A progress bar does two different jobs: **measuring the past** (what's confirmed done) and **guessing the future**. Understanding this prevents "fixing" correct behavior and catches fake behavior:

- **Chunked transfers** (uploads/downloads): completed chunks are measured; time remaining = chunks left ÷ current arrival rate. That's why an estimate can say 43 minutes, then 2, then jump to 50 when the network slows — it's honest recalculation, not a bug.
- **Stage-weighted pipelines** (export: process frames → mix audio → compress): a developer assigns each stage a rough weight (say 30%), so the bar sits still during a stage and jumps at the boundary (20% → 50%). Expected behavior for discrete tasks.
- **The bar only moves if the server reports progress back.** No telemetry → whatever the bar shows is simulated. During audits, check whether a determinate bar is actually wired to progress events; a purely animated "progress" bar is a fake-progress finding.

## "Just make it fast" is half the job

Optimize everything, and it still might not matter: the user is on hotel Wi-Fi or two bars in the subway, or your payment provider is degraded today. "Just make it fast" assumes a fast device, strong signal, and other companies' servers cooperating — you control none of those. Without feedback in those moments, the user doesn't think "slow", they think "this page is not working". You don't build loaders *instead of* speed; you make things fast **and** plan for the moments you can't control.

## Labor illusion — `suggest-only`

Showing effort during a wait increases trust: users who watched a travel site visibly search each airline rated the same results higher than users who got them instantly; tax software deliberately shows "double-checking every possible tax break" for a near-instant backend check, because an instant result would feel untrustworthy. (In gaming the same trick builds anticipation instead — spinning reels on an already-decided outcome.) Most loading is genuinely real work — this only concerns *added* theater. Deliberately slowing an interface is a product/ethics decision adjacent to dark patterns: surface as a suggestion only, never auto-apply.
