---
name: good-ux
description: Frontend UX auditor and build-time guide, covering the states AI-generated UI usually skips — loading (skeleton vs spinner vs progress bar, with timing thresholds), error content and placement (toast vs modal vs inline), success confirmation, empty states, form behavior, graceful degradation when one section fails, accessibility (keyboard, focus, live regions, contrast, alt text, reduced motion), destructive-action guards and undo, familiarity and complexity laws, and dark-pattern detection. LOAD IMMEDIATELY when the user asks to audit, review, check, polish, or improve the UX, UI, or accessibility of frontend code, when they mention missing loading/error/empty/success states, or when they invoke the good-ux command. OFFER FIRST, DO NOT LOAD, when the user is building or reworking UI that fetches, submits, lists, or deletes data without mentioning UX — complete what they actually asked for, then ask in one line whether to apply good-ux to it, and load only if they accept. Offer at most once per session, and never offer again after a decline. Do not trigger at all for backend work, styling-only tweaks, debugging existing UI behavior, or general design discussion.
---

# good-ux

Frontend UX auditor and build-time guide. AI generation tools design the happy path and forget the loading, empty, error, and success states real users hit constantly. This skill closes that gap.

The rules live in `references/`. This file holds the workflow only — it deliberately does not restate rules, so there is never a second copy to drift out of date. Whatever the mode, the rules come from the reference files.

## Modes

| Mode | Trigger | Scope |
|---|---|---|
| **Scan** | `scan` (optionally a path) | Whole repo / given directory |
| **Diff** | `diff` (default) | Uncommitted changes or current branch vs default branch |
| **Guide** | the user accepted an offer to apply it while building | The UI component being written right now |

Guide is never entered unprompted: when UI work appears and the user has not asked for a UX pass, finish their request first, offer in one line, and enter Guide only on acceptance. One offer per session; a decline ends offering for that session.

## Routing — which references to read

Identify the UI surfaces in scope, then read **every** reference file those surfaces map to. This is a lookup, not a judgment call: if the surface is present, read the file. Do not skip a file to save context, and do not audit a surface from memory.

| Surface in code | Read |
|---|---|
| Async fetch, page/section load | `references/loading-states.md`, `references/degradation.md` |
| Mutation, submit, button action | `references/loading-states.md`, `references/error-messages.md`, `references/success-states.md` |
| Form or input | `references/forms.md`, `references/error-messages.md` |
| List, collection, search results | `references/empty-states.md` |
| Long operation (upload, export, job) | `references/loading-states.md` |
| Multi-fetch page (dashboard, feed) | `references/degradation.md` |
| Delete, remove, revoke, reset, bulk action | `references/destructive-actions.md` |
| Signup/cancel/delete/unsubscribe flow, opt-out microcopy | `references/dark-patterns.md` |
| Navigation, layout, menus, long forms, cart, RTL/i18n | `references/familiarity.md` |
| Any interactive markup, modal, focus change, form field, image, or animation | `references/accessibility.md` |

The accessibility file is cross-cutting rather than surface-specific — it is the announced-and-focusable half of the state rules above. In practice any UI change in scope means reading it.

## Guide mode

Entered only after the user accepts an offer. Read the reference files for the surfaces being built — usually one or two, plus `accessibility.md` — and write or rework the component to satisfy them. Cost stays bounded because you are building one thing, not auditing a repo.

There is no report in this mode. Apply the rules as you write, and say which ones shaped the component.

## Scan and Diff

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
2. **Read every reference** the routing table maps those surfaces to.
3. **Check each surface against every rule** in the files you read, and **report** in the format below.
4. **Apply** approved findings only.

**Fix policy:** report first and apply nothing until the user approves specific findings ("fix 1, 3, 5" or "fix all"). With `--fix`, apply all auto-fixable findings immediately without the approval gate. Two categories are **never auto-fixed**, `--fix` included — they are reported as flags for a human decision:
- Dark-pattern findings (product decisions, not lint fixes)
- Rules marked `suggest-only` in the references (aesthetic or ethics-adjacent claims)

**When fixing,** reuse the repo's existing UI primitives (its own Skeleton/Spinner/Toast/Modal components and design tokens). Never introduce a parallel component or new design system; if no primitive exists, say so in the finding and propose the smallest new component consistent with existing styling.

**Prefer the project's own values over the numbers in the references.** If the repo defines design tokens, a type/spacing scale, an accessibility lint config (`eslint-plugin-jsx-a11y`, axe), or i18n locale config, audit against those — the figures in the references are defaults for projects that have none. One exception: the accessibility minimums (contrast ratios, flash rate) are floors rather than defaults. A project may set a stricter bar; a project setting a looser one is itself the finding.

## Report format

Findings are numbered in one continuous sequence across all groups, so "fix 3, 7" is unambiguous. Two lines each: what is wrong, then the fix after an arrow. Do not add a "Rule:" line — the tag already names the category, and the reasoning is available on request.

```
# UX audit — src/components/FeedbackWidget.jsx
16 findings · 14 fixable · 2 need a design call

## Breaks the interaction loop
1. [a11y] :334 Stars are `<div onClick>` — no keyboard access, and submit is gated on rating, so the feature is mouse-only.
   → radiogroup of native `<button>`s in a fieldset (pattern: InlineFeedback.jsx:161)
2. [error] :254 Download button always enabled but returns silently when there is nothing to write.
   → disable when count is 0, try/catch the blob write, surface failure in the existing error region

## Contrast floors
7. [a11y] :425 Disabled submit — #FFF on #E0E6E1 = 1.27:1 against a 4.5:1 floor.
   → needs a token pair chosen  [design call]

## Polish
14. [familiarity] :433 `title="Submit feedback"` hardcoded English in a Greek-default widget.
   → translate or drop

Holding up: double-submit guard, in-flight label swap, inline error placement.

Reply with numbers to fix · "all" · "why 3" for the reasoning · or rerun with --fix
```

Rules for keeping it readable:
- **One line for the problem, one for the fix.** Push the justification out of the report; offer `why N` instead.
- **Path once in the header** when the scope is a single file, then bare `:line` per finding. Multi-file scans keep the path per finding.
- **Counts at the top**, not the bottom — the reader sees the scale before deciding to read on.
- **Mark, don't explain, the special cases**: `[design call]` when a token or product choice is needed first, `[FLAG ONLY]` for dark patterns and `suggest-only` rules that are never auto-fixed.
- **Group by severity** with the groups in this order: breaks the interaction loop, missing states, contrast floors, polish. Omit any group that is empty.
- **Close with one "Holding up" line** naming what is already correct — a short list, not a paragraph.

## Adding rules

Add them to the reference file for their topic, in that file's existing style (rule, why it matters, what it looks like in code). If a rule introduces a genuinely new surface, add a row to the routing table above. Never restate a rule in this file.
