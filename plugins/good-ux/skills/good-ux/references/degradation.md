# Graceful degradation

- **Sections fail alone.** Never block the whole page behind one full-screen loader, and never let one failed component crash or blank the page. Each section owns its data fetching, loading state, and error state; a failed section shows an isolated error + retry inside its own container while everything else stays usable. Data arrives from different backend services at different speeds — the page shouldn't be hostage to its slowest or most fragile source.
- **Cached-first rendering.** Show cached content immediately, fetch fresh data in the background, swap seamlessly (the way a social feed renders instantly on launch). Users keep browsing and never notice the load.

In React terms these map to per-section error boundaries / suspense boundaries and stale-while-revalidate caching (SWR, React Query defaults) — but recommend whatever mechanism the repo already uses.

**Audit checks:** a single top-level loader gating a multi-fetch page, one fetch failure unmounting or blanking sibling content, full-page error screens for partial failures, refetch-on-focus configured to blank the screen instead of showing stale data.
