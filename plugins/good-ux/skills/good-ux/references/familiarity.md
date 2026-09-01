# UX laws — familiarity and complexity

Four laws that govern layout, navigation, and how much of the interface to show at once.

## Jakob's law — meet learned expectations

Users spend most of their time on *other* sites, so they expect yours to work like the ones they already know. The shopping cart is the canonical case: on desktop e-commerce it is always top-right — moving it bottom-right isn't innovation, it's friction on the one control that should have zero. The cost is small but real: that microsecond of "wait, where is it?" is pure waste. Predictable structure is the point — it frees the user to focus on what actually matters (ordering what they want) instead of re-learning the interface.

**Conventions are per-device and per-locale, not universal:**
- Desktop web: cart top-right in the header (with a slide-out drawer on click).
- Mobile: the cart moves to the **bottom tab bar** — thumbs live at the bottom of the screen, and top-right is among the hardest one-handed reaches.
- RTL locales: the whole layout mirrors — cart top-left on an Arabic storefront.

Building for a global audience means checking the pattern per device class and per market, not copying the desktop layout everywhere.

## Hick's law — decision time grows with choices

Time to decide increases with the number and complexity of options (picking from 24 jam jars vs 6; a 250-item menu vs a 4-item one). Applications:

- **One clear primary action per screen.** A search page with a single input beats a portal homepage where news cards, ads, and widgets all compete for attention — that's not richness, it's unnecessary competing choices.
- **Forms over ~7 fields: split into steps.** A long "Create Account" card listing every field at once becomes "1/3 Basic Info" with two fields, a progress bar, and a Next button. The field count is a rule of thumb, not a threshold — what matters is whether one screen asks for more than a person wants to face at once. Conversion gains from splitting long forms are reported as large, but the figures come from vendor case studies rather than controlled research; use the pattern, don't quote the numbers.
- **Navigation: few top-level categories + filters at the results level.** Replace a 15-link vertical menu of every subcategory with ~4 category cards, then filter chips ("Dresses", "Tops", "Jeans") on the listing page.
- **It's not about limiting capability — it's keeping visible options manageable.** A streaming service holds thousands of titles but shows a few curated rows, and most of what people watch comes from recommendations, not search.

## Progressive disclosure — show what's needed now

The GPS analogy: nobody wants all 35 turns listed before leaving the driveway — you want the next turn as you drive. Progressive disclosure means nothing is *removed*; features just aren't thrown at the user all at once.

- **Anti-pattern:** a mega-dropdown so long it scrolls, where a feature at the bottom effectively doesn't exist — eyes go to the top item and never find it (even the builder can forget what's down there).
- **Pattern:** a clean surface with contextual triggers — an AI panel that appears only when invoked; a `/` command menu that opens on demand, reminds the user what's possible, and filters live as they type (`/datab` → the database options).
- **The stated caveat:** don't hide your *most important* features so deep that people need a tutorial to find your app's value. Progressive disclosure applies to secondary depth, never to the primary action.

The design question to ask of any screen: *does everything visible here need to be shown at this moment?*

## Tesler's law — absorb complexity, don't forward it

Every system has irreducible complexity; the only choice is who suffers it — the builder or the user. The principle's origin includes a standard worth quoting in reviews: if a million users each waste a minute on a complexity an engineer could have solved in a week, the user is being penalized to make the engineer's job easier.

Recognizable absorptions: search autocomplete (the system guesses so you type less), a Skip Intro button (someone catalogued the intro timestamps of thousands of episodes so you press one button), one-tap payment with platform auth (no password, no card number entry). Real users are busy and distracted and take the easiest path — handling the hard part for them is what makes a product likable.

**Audit checks:** primary conventions in non-standard positions (cart, search, account menus); desktop layouts copied unchanged to mobile (actions out of thumb reach) or to RTL locales (unmirrored); long single-page forms (>7 fields, no steps); screens with several competing primary actions; exhaustive menus instead of categories + filters; mega-menus burying features below the fold; flows that forward complexity to the user — manual formatting, re-entering known data, multi-step auth where platform auth exists.
