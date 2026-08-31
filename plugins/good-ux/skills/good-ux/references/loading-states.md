# Loading states

## The four core states

Every app screen needs four states designed: loading, success, error, and empty. Users notice a missing state and assume the system is broken. This is the root check: for every screen in scope, all four states must exist.

## Which loading indicator — decision tree

| Situation | Indicator |
|---|---|
| Entire page or large content section loading | Skeleton screen mimicking the final layout |
| Known/estimable duration: upload, download, install, compression | Determinate progress bar with progress + time remaining |
| Small contained action: button click, single-component refresh | Inline spinner inside the button/component |
| Low-stakes instant micro-action (like, favorite, toggle) | Optimistic UI — update immediately, roll back on failure |

Reasoning: skeletons tell the user the layout exists and data is coming — the brain processes structure before content arrives. Spinners on long measurable operations look frozen; users need to know how far along they are.

Optimistic UI requires a client-side rollback path and a failure notification; determinate progress bars require the backend/client to actually measure progress. Verify both exist before recommending these patterns.

## Duration thresholds

| Expected wait | Show |
|---|---|
| < 1 second | Nothing — just show the result |
| 2–5 seconds | Plain spinner |
| 5–6 seconds | Spinner + static text |
| up to 10 seconds | Spinner + changing text ("connecting…", "almost there…") |
| > 10 seconds | Progress bar or step-by-step indicator — never a looped spinner |

A sub-second spinner reads as glitching and makes the app feel slower. Changing text keeps users tolerant because they perceive ongoing action. On failure, show the error immediately — never let a spinner run to an eventual error.

## Skeleton screens — refinements

- Skeletons are perceived as faster **only** with an active, steady left-to-right shimmer — static grey boxes and pulsing fades don't produce the effect.
- The skeleton must match the incoming layout's dimensions and alignment; it is a visual promise, and a mismatch reads as a jarring layout shift.
- Skeletons suit loads **under ~3 seconds**; on longer loads switch to an explicit indicator with text ("Just a moment…"), because a skeleton conveys nothing about wait time and prolonged display reads as a bad connection. Caveat: detecting slow loads and switching adds engineering complexity.

## Progress bars — honesty mechanics

- Remaining-time estimates legitimately jump around: past progress is measured, the future is estimated against fluctuating transfer rates — recalculate from live rates rather than smoothing over reality.
- Stage-weighted pipelines (process → mix → compress) pause at a boundary and jump to the next weight when a discrete task completes; expected behavior, not a bug.
- Real progress requires backend-to-frontend telemetry (chunks/tasks completed); without it any determinate bar is simulated. During audits, check whether a determinate bar is actually wired to telemetry; if not, it's a fake-progress finding.

## Speed first, loaders always

You don't build loaders *instead of* making something fast — you make things fast *and* plan for the moments you cannot control (weak networks, third-party latency). A loader never excuses avoidable slowness.

## Labor illusion — `suggest-only`

Deliberate delays with operational transparency ("Searching United…", "Checking every tax break") raise perceived effort, trust, and result valuation. Many loading screens reflect real latency, not artifice. Deliberately slowing an interface is a product/ethics decision adjacent to dark patterns — surface as a suggestion only, never auto-apply.

## Loader quality

Loaders must feel intuitive and subtle. Missing feedback makes users assume the system is broken; good feedback makes waits feel shorter.
