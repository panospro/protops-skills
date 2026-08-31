# Empty states

The empty state is often the *first* thing a new user sees — they sign up, land on the dashboard, and it's blank. Builders under-design it because features are more interesting; users experience it as the first impression. The standard: a good empty state **tells the user why it's empty, shows them what to do next, and doesn't feel broken.**

- **Every empty section gets an action.** "You have no projects" alone strands the user. Add the explanation and the call-to-action: "+ Create new project". Apply per-section: any part of the app without content yet should say what the section is for and how to start using it — never just render blank.
- **First-run onboarding checklist.** On an initial-setup dashboard, a step-by-step, lightly gamified setup flow ("Set up your workspace — 1 of 5 complete, 20%") turns the empty screen into momentum.
- **Zero search results must keep the user moving.** "No results" is a dead end. For `prple shoes`: "No results for 'prple shoes'. Did you mean **purple shoes**?" — with the suggestion as a clickable link straight into the corrected results.
- **Celebrate achieved-empty** — `suggest-only`. When empty is the goal (inbox zero, cleared queue), make hitting zero feel like an achievement: a streak counter ("6 DAY STREAK"), a pleasant illustration users look forward to seeing. Mixed usability/aesthetic claim: propose it, never auto-apply.

**Audit checks:** list/collection renders with no explicit empty branch (blank screen when `items.length === 0`), empty branches that state emptiness without an action, search/filter results with dead-end zero states, first-run dashboards with no onboarding path.
