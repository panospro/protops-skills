# Accessibility

The loading, error, empty, and success states this skill checks elsewhere are invisible to a large share of users unless they are also announced, focusable, and legible. A spinner that only spins, an error that only turns a border red, and a toast that only fades in are silent to a screen reader and unreachable without a mouse.

## Keyboard and focus

- **Everything interactive is reachable and operable by keyboard.** The common breakage: a `<div>` or `<span>` with an `onClick`, no `tabindex`, no `role`, no key handler. A real `<button>` or `<a href>` gets focus, Enter/Space, and screen-reader semantics for free — reach for the native element before recreating it.
- **Focus must be visible.** `outline: none` with no replacement is the single most common accessibility regression in generated CSS. If the default ring clashes with the design, replace it (`:focus-visible` with a custom ring), never delete it.
- **Focus is managed across state changes.** When a modal opens, focus moves into it and is trapped until it closes; on close, focus returns to the element that opened it. When a route changes in a single-page app, focus moves to the new view's heading — otherwise keyboard and screen-reader users stay parked on the old page.
- **Escape closes what blocks.** Any modal, drawer, or popover that blocks interaction closes on Escape and returns focus. Nothing may trap the keyboard with no way out.
- **Focus order follows visual order.** Positive `tabindex` values (`tabindex="2"`) break this; the only sane values are `0` and `-1`.

## Announcing async state

This is the accessibility half of the loading, error, and success rules elsewhere in this skill.

- **Status and errors are announced.** Wrap the region that receives async messages in `aria-live="polite"` (status, success, loading complete) or `aria-live="assertive"` / `role="alert"` (errors that interrupt). Insert the text into an element that already exists in the DOM — a live region added at the same moment as its content often doesn't announce.
- **Loading state is exposed, not just drawn.** `aria-busy="true"` on the region being loaded, and `aria-label` or visually hidden text on a spinner ("Loading orders"). A bare animated SVG says nothing.
- **Disabled submit buttons need an accessible reason.** The forms rule ("mark why it's disabled") has a screen-reader equivalent: `aria-describedby` pointing at the requirement text, and errors tied to their fields with `aria-describedby` plus `aria-invalid="true"`.

## Forms and labels

- **Every input has a programmatic label** — a `<label for>` or `aria-label`. Placeholder text is not a label: it disappears on input, is usually too low-contrast, and is not reliably announced.
- **Error identification is textual.** A red border alone fails; there must be a text message associated with the field.
- **Never signal by color alone** — required fields, validity, chart series, and status pills all need a second channel: text, icon, or pattern.
- **Group related controls.** Radio and checkbox sets belong in a `<fieldset>` with a `<legend>`; without it a screen reader announces the option but not the question.

## Visual

- **Contrast minimums** — these are floors, not defaults to tune: 4.5:1 for body text, 3:1 for large text (≥24px, or ≥19px bold), 3:1 for UI component boundaries and meaningful graphics (input borders, focus rings, icon buttons). The ratios compare the two colors' relative luminance, so they hold on any screen or resolution; only font size shifts which threshold applies. The usual offenders in generated UI: grey placeholder text, disabled-state labels, and "subtle" secondary buttons.
- **Text resizes and reflows:** the layout survives 200% zoom and a 320px-wide viewport without horizontal scrolling or clipped content. Fixed pixel heights on text containers are the usual cause of failure.
- **Respect reduced motion.** This constrains this skill's own recommendations — shimmer sweeps, skeleton animation, celebratory confetti, and slide transitions all belong behind `@media (prefers-reduced-motion: reduce)` with a static fallback. Nothing flashes more than three times per second, which is a seizure risk.

## Semantic structure

The markup that assistive tech navigates by. None of it is visible, all of it is what makes a page usable without sight or a mouse.

- **Every image declares whether it means anything.** `alt` is text nobody sees: a screen reader speaks it, and the browser displays it if the image fails to load. Three cases. An image carrying information gets a description of *the information* (`alt="Revenue grew 40% in Q4"`, not `alt="chart"`). A purely decorative image gets `alt=""` — empty but present, which tells the reader to skip it; with no `alt` at all, some readers fall back to announcing the file name. An image that *is* the control (an icon-only button) needs the name on the control: `<button aria-label="Delete invoice">` — otherwise it announces as just "button" and the user cannot tell what it does.
- **Headings are a real hierarchy.** Screen reader users skim by jumping heading to heading, the way you'd read a table of contents, so levels must describe structure — one `<h1>` per view, no skipped levels, and the tag chosen for its place in the outline rather than its font size.
- **Landmarks and a skip link.** `<main>`, `<nav>`, `<header>` are landmarks: they let a screen reader jump straight to the main content instead of walking the nav on every page. Keyboard users without a screen reader have no such jump, so add a "skip to content" link — visually hidden until focused.
- **Language is bound to the active locale, not hardcoded.** `lang` tells the screen reader which pronunciation engine to use; English text read by a Greek engine (or the reverse) comes out as noise. In an internationalized app this is a live value, not a constant: `<html lang={locale}>` in the root layout, or `document.documentElement.lang = locale` when the user switches. Flip `dir="rtl"` for RTL locales at the same point — the mirrored-layout rule in `familiarity.md` depends on it. If a page mixes languages, mark the exception inline (`<span lang="en">`). A project with i18n and a hardcoded `lang="en"` is a finding, not a pass.

## Timing

- **Nothing critical vanishes on a timer.** Auto-dismissing toasts must be adjustable, extendable, or duplicated somewhere persistent — which reinforces the placement rule that critical errors never live in a toast alone.

**Audit checks:** `onClick` on non-interactive elements; `outline: none` or `outline: 0` without a `:focus-visible` replacement; modals without focus trap, Escape, or focus restore; single-page route changes with no focus move; async error and success regions with no `aria-live` or `role="alert"`; spinners with no accessible text; inputs whose only label is a placeholder; `aria-invalid` / `aria-describedby` missing on invalid fields; validity or status conveyed by color alone; contrast below thresholds on placeholder, disabled, and secondary text; animation with no `prefers-reduced-motion` branch; `<img>` without `alt`; icon-only buttons without `aria-label`; skipped heading levels; missing `<main>` or skip link; positive `tabindex`; hardcoded `lang` in an app that switches locales, or a missing `dir` flip for RTL locales.
