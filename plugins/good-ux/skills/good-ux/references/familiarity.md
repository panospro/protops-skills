# UX laws — familiarity and complexity

## Jakob's law — meet learned expectations

Users spend most of their time on *other* sites, so they expect yours to work like the ones they already know. Standard controls belong in standardized locations — the shopping cart top-right in a desktop header; non-standard placement (floating bottom-right, top-left) creates hesitation. Predictability frees users to focus on their actual task.

Conventions shift with device and culture: on mobile the cart belongs in the bottom tab bar (thumb reach); on RTL interfaces the layout mirrors (cart top-left). Applies especially to e-commerce and global/multilingual products.

## Hick's law — fewer visible choices, faster decisions

- One clear primary action per screen (a single search input beats a homepage of competing widgets).
- Forms with more than ~7 fields: split into a multi-step wizard ("1/3 Basic Info", progress bar, Next) — long single-page forms measurably hurt conversion.
- Navigation: a few top-level categories plus filters on the results page, instead of exhaustive menus listing every subcategory.

## Progressive disclosure — show what's needed now

Show users what they need right now instead of every feature at once. A mega-dropdown of dozens of tools means features at the bottom are never seen. The positive pattern: hide tools behind contextual triggers (a `/` slash-command menu that filters as you type). **Exception:** never bury primary or essential features so deep that users need a tutorial to find them.

## Tesler's law — absorb complexity, don't forward it

Every system has irreducible complexity; someone has to deal with it, and it should be the builder, not the user. Examples: search autocomplete, a Skip Intro button, one-tap payment with platform auth. Engineering effort spent once saves millions of user-moments.

**Audit checks:** primary conventions in non-standard positions (cart, search, account menus), long single-page forms (>7 fields, no steps), screens with multiple competing primary actions, mega-menus hiding features below the fold, flows that forward raw complexity to the user (manual formatting, repeated data entry, multi-step auth where platform auth exists), unmirrored RTL layouts, out-of-thumb-reach mobile actions.
