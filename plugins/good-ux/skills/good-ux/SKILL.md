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

Open with a short read of the component as a whole, then three lines per finding. The line breaks are mandatory — a finding whose fix trails after an arrow inside the same wrapping paragraph is unreadable no matter how few words it uses.

```
# UX audit — src/features/signup/SignupForm.tsx
12 findings · 10 fixable · 2 need a design call

The happy path is solid: the submit is guarded against double-clicks, the in-flight label
is the right weight, and validation errors sit next to the fields they belong to. Two
themes account for most of what follows. First, none of this form works without a mouse —
the custom select, the failure message, and the confirmation are all invisible to keyboard
and screen-reader users, so signup effectively does not exist for them. Second, the
disabled and secondary styles were never checked against a background, leaving several
labels below the readable minimum.

## 🔴 Breaks the interaction loop

**1. [line 118](src/features/signup/SignupForm.tsx#L118) — The country picker is a div; keyboard users cannot choose one**
Fix → native select, or a listbox with arrow-key handling *(pattern: [Dropdown.tsx:44](src/components/Dropdown.tsx#L44))*
Why → submit is blocked until a country is set, so this one gap makes the whole form unusable without a mouse

**2. [line 203](src/features/signup/SignupForm.tsx#L203) — Submit failure is silent for screen readers**
Fix → role="alert" on the error container *(pattern: [Alert.tsx:22](src/components/Alert.tsx#L22))*
Why → the button just re-enables, so a non-sighted user cannot tell whether the account was created or the request failed

## 🟠 Missing states

**5. [line 96](src/features/signup/SignupForm.tsx#L96) — The email field has no label, only a placeholder**
Fix → visible label above the field, keep the placeholder as an example
Why → the placeholder is the only thing naming the field, and it disappears on the first keystroke

## 🟡 Contrast floors

**8. [line 241](src/features/signup/SignupForm.tsx#L241) — Disabled submit is 1.3:1, needs 4.5:1** ⚠️ design call
Fix → pick a token pair for the disabled state
Why → the label is illegible in exactly the state where the user is trying to work out why they cannot submit

## 🔵 Polish

**11. [line 250](src/features/signup/SignupForm.tsx#L250) — Tooltip text is hardcoded English in a localized app**
Fix → move it into the translation files, or drop the tooltip
Why → it is the only untranslated string on the screen, so it reads as a bug rather than a default

✅ Holding up: double-submit guard, in-flight label swap, inline error placement

Reply: numbers to fix · all · why 3 · --fix
```

The opening read, in three or four sentences: name what already works, then the one or two themes that explain most of the findings. Themes are patterns ("nothing works without a mouse", "the dark theme is half-wired"), not a summary of the list that follows. This is what tells the reader whether they are looking at a component that needs polish or one that needs rework.

Hard constraints on each finding:

- **Line 1 is a headline: a clickable location, then one clause under about 12 words.** Link a single-file scan as `[line 334](path/to/File.jsx#L334)`; a multi-file scan as `[File.jsx:334](path/to/File.jsx#L334)` so the file is visible without scrolling up. A bare `:334` is not acceptable — it is neither clickable nor self-explanatory.
- **State the user-visible consequence, not the mechanism.** "Stars are divs; keyboard users cannot rate at all" beats "no tabIndex, no role, no key handler".
- **Line 2 starts with `Fix →` on its own line.** Never continue the sentence from line 1, and never put the fix behind an arrow mid-paragraph.
- **Line 3 starts with `Why →` and argues for this change in this code.** What breaks for a real user if it stays, or what the fix buys beyond compliance. Never restate the generic rule — "errors should be announced" is worthless; "the button just re-enables, so the user cannot tell whether it sent" is the point. If the honest why is only "the rule says so", the finding is probably not worth reporting.
- **Write it in plain language.** Spell out anything a competent developer who does not follow accessibility or UX discourse would have to look up: write accessibility, not a11y; screen reader, not AT; say "the four states a screen needs — loading, success, error, empty" rather than "the feedback states". Real package and attribute names (eslint-plugin-jsx-a11y, aria-live) stay as they are, since those are things you type.
- **No backticks except real identifiers** you would type into a search box. Prose mentions of attributes (tabIndex, role, aria-label) stay plain — a line speckled with code spans has no shape to scan.
- **One reference to an existing repo pattern**, linked the same way, when one exists. Not two, not a list.
- **Markers at the end of line 1**: `⚠️ design call` when a token or product decision comes first, `🚩 flag only` for dark patterns and `suggest-only` rules that are never auto-fixed.
- **No category tag.** The group heading already says what kind of problem this is.

Structure around the findings:

- Counts on line 2, then the opening read, then the groups in this order, each with its emoji so severity is visible at a glance: `🔴 Breaks the interaction loop`, `🟠 Missing states`, `🟡 Contrast floors`, `🔵 Polish`. Omit empty groups.
- Numbering runs continuously across groups so "fix 3, 7" is unambiguous.
- Close with one `✅ Holding up:` line naming what is already correct.
- Emoji appear only on group headings, the two markers, and that closing line. Never inside a finding's text.
- `why N` on request goes deeper than line 3 — the mechanism, the rule behind it, and what a correct implementation looks like.

## Adding rules

Add them to the reference file for their topic, in that file's existing style (rule, why it matters, what it looks like in code). If a rule introduces a genuinely new surface, add a row to the routing table above. Never restate a rule in this file.
