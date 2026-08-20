# PixelLab prompts, recorded

WHY THIS FILE EXISTS. The prompts that made every generated asset in this repo were typed
into the MCP tool and thrown away, so a re-roll of any card, backdrop or exterior started
from scratch and re-derived the art direction by guesswork. Two sessions have now paid for
that. Keep this in step with the art: a prompt is as much a source file as a script is.

## The eight trick-card illustrations (`artifacts/carddeck/*.png` -> `Assets/UI/cards/`)

`create_image_pixflux`, 104x128, `color_image_base64` = `Resources/palette/palette.png`
(284 chars of base64 - inline it freely), `no_background: false`. 1 generation each.

THE SHARED CLAUSE IS WHAT MAKES THEM A SET, and it changed on 2026-08-13. It used to be
"centred under a wide vertical cone of warm amber spotlight, in an elliptical pool of
light" - which did unify them, and which Louis then rejected in as many words: "the cards
of the tricks might do with a bit less lighting: just the image not the light from above".
He was right. The cone was the loudest object on all eight; on `high` it WAS the card, with
a tiny silhouetted figure at the bottom of it, and `btb` was a black cut-out of the showman
against a wall of orange.

The clause that replaced it unifies by GROUND instead of by light:

    ... centred and filling the frame, lit warmly from the front so its own colours read,
    on a completely flat solid dark reddish brown background of one single colour,
    no gradient, no cone of light, no spotlight, no beam, no floor, no ground,
    no cast shadow

Two things learned re-rolling it:
  - "flat solid ... background" alone is not enough for a first pass. Dropping only the
    cone got `btb` and `high` back with a crimson TRAPEZOID behind the subject - the same
    shape, repainted as scenery. The negatives have to name the shape (cone, beam, spotlight)
    AND the surface (floor, ground, cast shadow), or half the set invents a ground plane and
    the other half floats.
  - "flat solid" once came back as a NOISE TEXTURE (`high`, a speckled red field with a
    doubled hand). "smooth plain dark brown background, no texture, no noise, no speckle"
    fixed it in one.

Subjects (Louis's own metaphors, unchanged since 2026-08-07 - do not reinterpret them):
  btb         a circus ringmaster in a crimson tailcoat and black top hat seen from behind,
              one arm curled behind his back tossing a small ball
  cascade     a tall narrow waterfall of warm amber water pouring over warm reddish brown
              rocks  (STEER IT WARM: asked plainly it comes back a cold navy cave, which is
              the exact uniformity break the 2026-08-13 regeneration existed to remove)
  columns     an ancient greek temple front with tall fluted columns and a triangular pediment
  halfshower  a single fluffy yellow duckling standing in profile
  high        one single white juggling ball high in the air at the top of the frame, and
              below it one open upturned bare hand with the palm up and fingers spread
  shower      a mallard duck standing in profile
  spin        a ballerina spinning on one pointed toe in a full white tutu, arms overhead
  tennis      a wooden tennis racket standing upright with a strung oval head

## The title backdrop (`ui/menu_backdrop`)

`create_image_pixen`, 640x360, 1 generation. Pixen cannot force a palette - the reducer
does, so JUDGE IT BY `gamut_fit` BEFORE SHIPPING (see pixelise_paint.py).

THE NOUN IS THE PROBLEM, TWICE OVER. "Proscenium" gets a centre pillar every time (four
attempts, 2026-08-13 morning); the answer was to ask for a CLOSED CURTAIN instead. Asking
for a pulled-back shot with "auditorium side walls at the far left and right" then produced
the DIPTYCH the same day - two arched stages with a gold rule down the middle, i.e. the
model tiling a symmetric architectural frame. Any symmetric arch invites the split.

What works for a zoom-out is to pull back with CONTENT rather than architecture: keep the
single unbroken curtain, and put the house in the near foreground.

    A closed stage curtain of very deep dark crimson velvet, almost maroon and black in its
    folds, dimly lit, with even vertical folds filling the upper two thirds of the frame,
    and a swagged pelmet with dull gold fringe across the very top. Below it are dim wooden
    stage boards and a row of small warm footlights. Along the bottom edge, in near-black
    silhouette in the foreground, are the tops and backs of several rows of empty theatre
    seats receding away from the viewer. The curtain is closed, one single unbroken sheet of
    fabric, deep shadow between every fold. Dark and moody, low light, few colours.
    No opening, no gather, no arch, no archway, no pillar, no column, no post, no divider,
    no second stage.

    -> 20 colours, gamut 0.000, mid-lum 0.11.

AND THE BRIGHTNESS CLAUSE IS LOAD-BEARING, not flavour. The same composition asked for
without "very deep dark ... almost maroon and black ... dimly lit ... few colours" scored
**gamut 0.145** and its whole curtain came back as a dense dither checkerboard - the reds
sat between palette entries and error diffusion sprayed the entire field. Steering the reds
deeper took it to 0.000 in one re-roll. Same lesson as the teal sky: the fix is the prompt.

## The title backdrop, rebuilt with SIDE CURTAINS (`ui/menu_backdrop`)

2026-08-20, Louis: "regenerate the title card: i want side curtains". The closed-curtain
version above is superseded; its own notes on brightness and on the noun still hold.

`create_image_pixflux`, **320x360, one LEFT HALF, mirrored** - not pixen full-frame. Pixflux
takes `color_image_base64`, so the locked 48 is forced at generation rather than snapped
afterwards (the half came back with 36 colours and nothing off-palette), and the mirror is what
makes a proscenium symmetric. Measured on the shipped bake: **0.0% of pixels differ from their
own mirror**, against 46.9% for the 2026-08-13 full-frame painting.

THE SHIPPED HALF IS ROLL A, and the three rolls are worth keeping because each failed
differently and only one of the failures was the prompt's fault:

  A  right composition - ONE curtain leg down the left, valance across the top, open stage
     running off the right edge - but a bare lit lip with no lamps on it.
  B  beautiful evenly-spaced footlight bulbs and flat boards, and a complete little proscenium
     with a curtain leg on BOTH of its own edges. Mirrored, that is the DIPTYCH this file
     already warns about: two stages side by side with a seam down the middle.
  C  a curtain at the RIGHT edge, which mirrors into one dead centre, complete with a
     duplicated tassel pair - plus two baked spotlight cones and two elliptical light pools on
     the boards, in a prompt that forbade both.

The clause that separates A from B and C is about where the picture ENDS, and both attempts to
say it explicitly made things worse: B's bounded "to the right of that curtain the stage is
OPEN and EMPTY" invited a matching right-hand leg, and C's emphatic "the stage RUNS OFF THE
RIGHT EDGE and does not end" got a curtain there anyway. **A said it once, quietly, and it
worked** - which is the same finding as the venue backdrops' "put the furniture somewhere":

    ... To the right of the curtain the stage is OPEN and EMPTY: a plain dark back wall in
    deep shadow catching a little warm light from below, dim wooden stage boards, and a row
    of small warm footlights along the front lip. ... The RIGHT-HAND EDGE of the picture is
    nothing but empty dark stage and plain back wall - no curtain, no object, no light, no
    detail of any kind.

**THE FOOTLIGHTS ARE NOT DECORATION ON THIS SCREEN.** `menu_house_light` deleted the title's
spotlight cone on 2026-08-15 and replaced it with a wash rising off the footlights, allowed
precisely because "they are real lamps in the picture". A half with no lamps puts the game back
into the fault the cone was deleted for. A asked for "a row of small warm footlights" and got a
lit lip; B asked for "small round glowing footlight bulbs, evenly spaced, each a warm amber dot
with a little pool of light" and got real lamps - and a diptych with them.

So the lamps were MOVED rather than re-rolled for: `scripts/add_footlights.py` cuts one bulb out
of B by difference from B's own board tone (a rectangular patch would carry B's flat boards over
A's lit wing-spill and cut a stripe) and stamps the row onto A. Same generator, same canvas, same
forced palette, so nothing about it is a repaint. **The pitch is laid out from the MIRROR AXIS
outward**, not from the left edge: a lamp at column c has a twin at 639-c, so a row spaced from
the left leaves the centre gap wrong by up to a full pitch - the one irregularity in an even row,
dead centre, where the eye already is.

AND THE AXIS ITSELF IS CHOSEN, which `--half-shift` is for. The pelmet's gathers landed at x 112,
160, 240 and 306, so the frame edge at 319 sat 13px past the last one on a falling arc - which
mirrors into a shallow inverted V exactly as the title's own notes predict. `--half-shift 13`
slides the gather onto the axis, where the slope is zero and the two halves join flat.

## Three venue backdrops, re-rolled (`bg/the_circus`, `bg/championship`, `bg/world_arena`)

`create_image_pixen`, 640x360, `no_background: false`, 1 generation each. 2026-08-19, Louis:
"re render the circus, championship and world arena stages (not their previews, only when
juggling the background)". These were the three OLDEST paintings in the game - all from
2026-08-14, before the floor-band framing rules were written - and it showed: the Circus was
a wall of near-identical crowd faces with no big-top in it, the Championship a murky dome,
the World Arena a grey speckled mush.

THE FRAMING CLAUSES ARE THE ONES ALREADY DOCUMENTED (see `scripts/pixelise_paint.py`): a
continuous standable floor across the bottom third, an empty centre column, no baked light,
no writing. What follows is what re-rolling these three ADDED to that.

**PUT THE FURNITURE SOMEWHERE, DO NOT ONLY FORBID IT.** "No tent pole, no mast, no post, no
column" got a rigging pole at art x 317 - six pixels wide, dead centre, ending exactly at the
performer's hairline so it read as growing out of his head. Naming where a thing SHOULD go
works where forbidding it does not: "two banks of seating on the far left and the far right"
put the crowd at the sides first time, every time. Asking for the poles at the edges (roll 2)
moved one to x 290 and made it thicker. What finally cleared the centre was changing the
CAMERA so the middle distance is a flat surface - "the tent wall drops away to a plain dark
red draped curtain running right across the middle distance, unbroken". A flat surface has
nowhere to hang anything.

**AND DO NOT TRY TO PAINT THE POLE OUT.** Both repairs in `clear_spine.py` were tried on it
and both are worse than the fault: a cloned donor strip duplicates the light-string bulbs it
contains (a pair of twin bulbs side by side is more obviously wrong than a pole), and the
`--rows` ramp smears every stripe boundary it crosses. A striped tent roof is neither smooth
nor donor-friendly. Re-roll the camera.

**THE FLOOR IS WHERE THE PALETTE SNAP BREAKS, AND THE WHOLE-FRAME GAMUT NUMBER HIDES IT.**
A big evenly-lit floor is one large area of one continuous tone, so if that tone sits between
palette entries, error diffusion sprays a regular 2px CHECKERBOARD across the biggest surface
in the picture - invisible in a 640x360 thumbnail, unmistakable at 2x, and it is the surface
the performer is standing on. Measured, on rolls that scored a perfectly acceptable 0.066 and
0.144 overall: `gamut_fit(img[280:360])` alone read 0.087 and 0.198. **Measure the floor band
on its own** - one line, and it is the only number that caught this.

The fix is the usual one, at the prompt, and it has two halves:

    ... in dim ochre brown and dark umber, falling away into shadow toward the front ...
    Dark and moody, low light, few colours, flat areas of solid colour,
    no dithering, no speckle, no noise, no grain

Steering the Circus's sawdust dark and warm took its floor band from 0.003 (whole frame
0.005). **Steer the TONE, not just the texture**: the same anti-dither clause with a "polished
wooden floor" went to 0.198, because bright saturated wood has nowhere to land in a palette
whose warm mid-tones are all muted. And do not over-steer either - a Championship asked for a
"dark slate blue-grey" mat came back flat, grey and dramatically dead, which no number
measures. The shipped Championship is the FIRST roll, at 0.087: its residual is dispersed
across floorboard grain rather than pooled in one wash, which is the case the advisory's own
note says diffuses fine, and at 1x under the veil it reads as a lightly grained wooden floor.


## The Midnight Show backdrop, repainted (`bg/the_midnight_show`)

`create_image_pixen`, 640x360, 2 generations. 2026-08-20, unprompted: it was the only painting
in the game the reducer still flagged (`gamut 0.165  <-- LOOK AT IT`), and the reason was one
choice - **its drapes were mint green.** The locked 48 is a warm theatre palette with no
mid-luminance teal at all, which is the same trap the Backyard's teal dusk sky fell into, so the
biggest surface in the picture had nowhere to land and error diffusion sprayed the whole thing.
Its stage was also a pale honey oak, i.e. the brightest floor in the game in the one room whose
entire purpose is being dark.

The repaint asks for the room the venue actually is: deep indigo drapes almost black in their
folds, dark umber boards, and the supper tables with their candles cropped along the bottom
edge. **0.165 -> 0.013, floor 0.048, and 0.0% green.**

TWO ROLLS, and the second was about the FLOOR BAND rather than the colour. Roll 1 got the colour
right first time and put its boards in a 22px strip - `stand` 0.811 lands the feet at art y 292,
so there was nothing to stand on. Naming the band as a fraction of the frame is what fixed it:
"the whole LOWER HALF, from half way down the picture to near the bottom edge, is a wide deep
band of dark stage boards", with the tables demoted to "the last narrow strip along the very
bottom edge, cropped by the frame". Roll 1 also drew a tied-back curtain leg just left of centre
and two soft round glows on the drape; naming those in the negatives ("no gathered curtain, no
tie-back ... no round glow or wash of light on the curtain") cleared both.

**DO NOT JUDGE THIS ONE BY THE PLAYED SCREEN.** `full_dark_stage()` puts a near-black wash at
alpha 0.72 over the finished backdrop, so most of this painting is invisible in play and the
improvement is almost entirely in the source. That is still worth having - the flagged dither is
gone, the palette fit is honest, and the picture underneath is correct if the wash is ever
tuned - but expect the capture to look much like the old one.
