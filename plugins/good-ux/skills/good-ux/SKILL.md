---
name: good-ux
description: Audit and fix frontend UX defects — missing loading/error/empty/success states, error placement, form behavior, graceful degradation, accessibility, destructive-action guards, and dark patterns. Use when asked to audit, review, or improve the UX, UI, or accessibility of frontend code, and when writing or reworking UI components that fetch, submit, list, or delete data. Not for backend work, styling-only tweaks, or general design discussion.
---

# good-ux

Frontend UX auditor and build-time guide. AI generation tools design the happy path and forget the loading, empty, error, and success states real users hit constantly. This skill closes that gap.

## Modes

| Mode | Trigger | Scope |
|---|---|---|
| **Scan** | `scan` (optionally a path) | Whole repo / given directory |
| **Diff** | `diff` (default) | Uncommitted changes or current branch vs default branch |
| **Guide** | automatic — no command | The UI component being written right now |

**Fix policy** (Scan and Diff): produce a numbered findings report first and apply nothing. Wait for the user to approve specific findings ("fix 1, 3, 5" or "fix all"), then apply only those. With `--fix`, apply all auto-fixable findings immediately without the approval gate. Two categories are **never auto-fixed**, `--fix` included — they are reported as flags for a human decision:
- Dark-pattern findings (product decisions, not lint fixes)
- Rules marked `suggest-only` in references (aesthetic or ethics-adjacent claims)

## Guide mode — build-time checklist

Guide mode is deliberately cheap: **do not read the reference files here.** They exist for audits; pulling them into a build session spends context on rules you already have below. The checklist is sufficient for writing new UI — read a reference only if the user asks why a rule exists or pushes back on one.

When writing or reworking a component that fetches, submits, lists, or deletes:

- **Four states before done:** loading, success, error, empty. Missing states are the default failure of generated UI.
- **Loading indicator by situation:** skeleton for a page/large section, determinate progress bar when duration is measurable, inline spinner for a button or small component, optimistic update for instant low-stakes actions. Show nothing under 1s; past 10s use a progress bar or step indicator, never a looped spinner.
- **Errors:** say what happened, why, and what to do next. Never render raw backend errors. Never let an action fail silently. Place inline next to the source; modal only for hard blockers (and always with an action button); toast only for transient, non-critical status.
- **Success:** anything transactional gets an explicit confirmation state, and the submit path is guarded against double-clicks.
- **Empty:** say why it's empty and give the next action; zero search results offer a correction, not a dead end.
- **Degradation:** each section owns its fetch, loading, and error state — no full-page loader gating a multi-fetch page, no one failure blanking the rest.
- **Forms:** validate on blur, mark required fields, live counters on limited fields, prefill known values, live password checklist, accept any sane format, and set `autocomplete` plus the right input `type`.
- **Destructive actions:** prefer undo over confirmation; irreversible actions name the object and consequence; high-blast-radius ones need type-to-confirm. Never autofocus or default-style the destructive button.
- **Accessibility:** native interactive elements, visible focus, focus trapped in modals and restored on close, `aria-live` for async messages, real labels (not placeholders), sufficient contrast, and animation behind `prefers-reduced-motion`.
- **Familiarity:** conventional placement for conventional controls, one primary action per screen, split forms over ~7 fields into steps.
- **Never emit a dark pattern** — no buried cancel, rigged button hierarchy, or shaming decline copy.

Mention which rules shaped the component; there is no report in this mode.

## Procedure (Scan and Diff)

1. **Inventory the UI surfaces** in scope, using the project's actual stack (fetch/axios/react-query/SWR/RTK Query, form libs, router):
   - Async data fetches (queries, loaders, `useEffect` fetches)
   - Mutations and submits (POST/PUT/DELETE actions, form handlers)
   - Forms and inputs
   - Lists / collections / search results (anything that can be empty)
   - Long-running operations (uploads, exports, generation jobs)
   - Multi-source pages (dashboards, feeds — several independent fetches on one screen)
   - Destructive actions (delete, remove, revoke, reset, bulk operations)
   - Account and subscription flows (signup, cancel, delete account, unsubscribe, opt-outs)
   - Navigation and layout shells (headers, carts, menus, tab bars)
   - Overlays and focus-moving UI (modals, drawers, popovers, client-side route changes)
2. **Read only the references whose surfaces actually appear** (map below). On a narrow diff that is usually one or two files; reading all of them is wasted context.
3. **Report** using the format below. Every finding names the rule it violates.
4. **Apply** approved findings only. When fixing, reuse the repo's existing UI primitives (its own Skeleton/Spinner/Toast/Modal components and design tokens). Never introduce a parallel component or new design system; if no primitive exists, say so in the finding and propose the smallest new component consistent with existing styling.

**Prefer the project's own values over the numbers in these references.** If the repo defines design tokens, a type/spacing scale, an accessibility lint config (`eslint-plugin-jsx-a11y`, axe), or i18n locale config, audit against those — the figures in the references are defaults for projects that have none. One exception: the accessibility minimums (contrast ratios, flash rate) are floors rather than defaults. A project may set a stricter bar; a project setting a looser one is itself the finding.

## Surface → reference map

| Surface found in code | Read |
|---|---|
| Async fetch, page/section load | `references/loading-states.md`, `references/degradation.md` |
| Mutation, submit, button action | `references/loading-states.md`, `references/error-messages.md`, `references/success-states.md` |
| Form or input | `references/forms.md`, `references/error-messages.md` |
| List, collection, search results | `references/empty-states.md` |
| Long operation (upload, export, job) | `references/loading-states.md` (timing thresholds, progress-bar mechanics) |
| Multi-fetch page (dashboard, feed) | `references/degradation.md` |
| Delete, remove, revoke, reset, bulk action | `references/destructive-actions.md` |
| Signup/cancel/delete/unsubscribe flow, opt-out microcopy | `references/dark-patterns.md` |
| Navigation, layout, menus, long forms, cart, RTL/i18n | `references/familiarity.md` |
| Interactive markup, modals, focus, contrast, animation | `references/accessibility.md` |

`accessibility.md` is cross-cutting rather than surface-specific — it is the announced-and-focusable half of the state rules above. Read it on any scan, and on a diff whenever the change touches interactive markup, styling, or form fields.

## Report format

```
# UX audit — <scope>

## Findings
1. [loading-states] src/pages/Orders.tsx:42 — fetch renders nothing while pending
   Rule: section loads get a skeleton matching the incoming layout
   Fix: render <OrderListSkeleton /> (existing primitive) while isLoading
2. [dark-patterns][FLAG ONLY] src/pages/Account.tsx:12 — no cancel-subscription route exists
   Rule: exit must be as easy as entry
   Fix: product decision; not auto-fixable
...

## Summary
N findings: X auto-fixable, Y flag-only. Reply with the numbers to fix, "fix all", or rerun with --fix.
```

Severity is implied by ordering: broken feedback loops (silent failures, missing error/success states) first, then missing states, then polish.
