---
description: Fix or build a UI screen in TOSSA following its established rules
---

Ground rules for any TOSSA screen/card work (see CLAUDE.md, "NO TEXT EVER LEAVES ITS CONTAINER"
and the UI-pass entries):

1. **Any string whose length is DATA** (a venue/prop/trick/pattern/Encore/lesson name, a
   commafied number, a table-driven description) must go through `fit_text` (shortens+marks a
   trim), `draw_wrap_fit` (wraps into a box, stops at height, marks the last line), or `fit_size`
   (shrinks font size, never truncates). **Numbers and amounts always use `fit_size`, never
   `fit_text`** - an ellipsised number reads as a wrong number, not a long one. Fixed strings the
   layout was built around don't need this.
2. **One colour per card.** No `top_sheen`/fake-gradient second tone, no accent bar across the
   top - the border colour alone identifies the card kind now. Both were removed project-wide;
   don't reintroduce them on a new screen.
3. **Route panels through `soft_card`** (rounded corners, soft drop shadow, faint sheen) rather
   than a bare `draw_rect` - it's the one shared "this is a card" primitive every screen uses.
4. **A box interior must be lighter than what's behind it**, or it reads as a hole cut in the
   panel rather than a recess (this bit the theatre boxes and the tailor's niche).
5. **Selection/hover panels clamp only on the axis they must** - e.g. a hover detail panel clamps
   vertically but never horizontally back over the card it's describing.
6. **When two screens must show the same rows** (Settings/Settings-cards, Pause/Pause-cards,
   grid shop card/row shop card), edit both or don't edit either - see `/godot-review`'s item 3.

After changing a screen, capture it for real:
`scripts/run_scene.sh <the relevant --dev-flag>` to look at it interactively (muted), or add/run
the matching target in `scripts/screenshot.sh` for a committed-to-disk before/after. Don't claim
a UI fix is done from reading the code - this project's own history is full of "rendered the
wrong function and saw nothing move" mistakes (two copies of one card, edited the one that isn't
live).
