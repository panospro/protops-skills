# Graceful degradation

A page looks like one thing, but almost nothing on it comes from the same place — profile from one service, feed from another, charts from a third, each arriving at its own speed. The delivery analogy: order from three restaurants and one no-shows — you don't throw away the food that arrived. Apps should eat what showed up.

- **Every section owns its data, its loading state, and its errors.** The profile section fetches its own data; the feed fetches its own. A failed section shows its own error and its own **Retry** button *inside its own container*; the other sections stay fully usable. The two anti-patterns: a full-page loader that gates everything on the slowest source, and a full-page "Oops! Something went wrong" because one component failed. The correct picture under partial failure: one card marked "Failed / Retry", three cards intact. A video page can buffer the player while the sidebar recommendations are already rendered and clickable.
- **Cached-first rendering.** Show cached content immediately (a feed's photos from a couple of hours ago), fetch fresh data in the background, swap it in seamlessly. The user has been scrolling the whole time and never notices the trick.
- **Design for the partial state up front.** When planning a page, decide explicitly what it looks like when some sections work and others don't, and how to make that seamless — this is a design-time decision, not an error-handling afterthought.

In React terms these map to per-section error/suspense boundaries and stale-while-revalidate caching (SWR, React Query defaults) — but implement with whatever mechanism the repo already uses.

**Audit checks:** a single top-level loader gating a multi-fetch page, one fetch failure unmounting or blanking sibling content, full-page error screens for partial failures, retry affordances that reload the whole page instead of the failed section, refetch-on-focus configured to blank the screen instead of showing stale data.
