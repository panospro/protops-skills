---
name: good-ux
description: Audit and improve frontend UX against a curated rule set — loading states (skeleton vs spinner vs progress bar vs optimistic UI, with timing thresholds), error message content and placement (toast vs modal vs inline), form behavior, empty states, success feedback, graceful degradation, familiarity and complexity laws (Jakob, Hick, progressive disclosure, Tesler), and dark-pattern detection. Three modes — scan (whole-repo audit), diff (current changes only), guide (applied while writing new UI). Use whenever the user asks to audit, review, polish, or improve the UX or UI of frontend code, mentions loading/error/empty/success states, spinners, skeletons, toasts, forms, or wants an AI-generated frontend checked for UX quality. Also consult proactively whenever building or modifying frontend components that fetch data, submit forms, render lists, or run async actions — even if the user never says "UX", because AI-generated frontends typically ship only the happy path.
---

# good-ux

Frontend UX auditor and build-time guide. AI generation tools design the happy path and forget the loading, empty, error, and success states real users hit constantly. This skill closes that gap.

## Modes

| Mode | Trigger | Scope |
|---|---|---|
| **Scan** | `scan` (optionally a path) | Whole repo / given directory |
| **Diff** | `diff` (default) | Uncommitted changes or current branch vs default branch |
| **Guide** | automatic — no command | The UI code being written right now |

All three modes apply the **full rule set** (loading, errors, forms, empty states, success states, degradation, familiarity/complexity laws, dark patterns).

**Fix policy:** Scan and Diff produce a numbered findings report first and apply nothing. Wait for the user to approve specific findings ("fix 1, 3, 5" or "fix all"), then apply only those. With `--fix`, apply all auto-fixable findings immediately without the approval gate. Two categories are **never auto-fixed**, `--fix` included — they are reported as flags for a human decision:
- Dark-pattern findings (product decisions, not lint fixes)
- Rules marked `suggest-only` in references (aesthetic or ethics-adjacent claims)

## Procedure (Scan and Diff)

1. **Inventory the UI surfaces** in scope. Search for these, using the project's actual stack (fetch/axios/react-query/SWR/RTK Query, form libs, router):
   - Async data fetches (queries, loaders, `useEffect` fetches)
   - Mutations and submits (POST/PUT/DELETE actions, form handlers)
   - Forms and inputs
   - Lists / collections / search results (anything that can be empty)
   - Long-running operations (uploads, exports, generation jobs)
   - Multi-source pages (dashboards, feeds — several independent fetches on one screen)
   - Account and subscription flows (signup, cancel, delete account, unsubscribe, opt-outs)
   - Navigation and layout shells (headers, carts, menus, tab bars)
2. **Check each surface** against the matching reference file (map below). Read only the reference files whose surfaces actually appear in scope.
3. **Report** using the format below. Every finding names the rule it violates.
4. **Apply** approved findings only. When fixing, reuse the repo's existing UI primitives (its own Skeleton/Spinner/Toast/Modal components and design tokens). Never introduce a parallel component or new design system; if no primitive exists, say so in the finding and propose the smallest new component consistent with existing styling.

## Surface → reference map

| Surface found in code | Read |
|---|---|
| Async fetch, page/section load | `references/loading-states.md`, `references/degradation.md` |
| Mutation, submit, button action | `references/loading-states.md`, `references/error-messages.md`, `references/success-states.md` |
| Form or input | `references/forms.md`, `references/error-messages.md` |
| List, collection, search results | `references/empty-states.md` |
| Long operation (upload, export, job) | `references/loading-states.md` (timing thresholds, progress-bar mechanics) |
| Multi-fetch page (dashboard, feed) | `references/degradation.md` |
| Signup/cancel/delete/unsubscribe flow, opt-out microcopy | `references/dark-patterns.md` |
| Navigation, layout, menus, long forms, cart, RTL/i18n | `references/familiarity.md` |

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

Severity is implied by ordering: broken feedback loops (silent failures, missing error/success states) first, then missing states, then polish. In Guide mode there is no report — apply the rules directly while writing the component and mention which rules shaped it.

## Guide mode contract

When writing any new screen or component that fetches, submits, or lists data: design all four core states — loading, success, error, empty — before considering it done. Pick the loading indicator from the decision tree in `references/loading-states.md`, place errors per `references/error-messages.md`, give transactional actions explicit success feedback per `references/success-states.md`, and never emit an opt-out or cancellation flow with dark-pattern traits.
