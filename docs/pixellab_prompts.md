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

Subjects (Louis's own metaphors, unchanged since 2026-08-07 - do not reinterpret them).
**`btb`, `columns` and `tennis` WERE RE-ROLLED ON 2026-08-24 - see "Three trick cards,
re-rolled" at the foot of this file for the prompts actually shipped; the one-liners below are
the metaphors, not the current text.**
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

THE THREE HALVES ARE TRACKED, WHICH NOTHING ELSE UNDER `artifacts/` IS. That directory is
gitignored as disposable on the grounds that everything in it can be re-rolled from a prompt
recorded here - true of every venue painting, and false of this one, because the shipped bake is
one specific roll's composition carrying another specific roll's lamps. `half_lit.png` alone
rebuilds the bake; A and B rebuild `half_lit`. Same call as `Assets/Props/big_torch.png`: when a
generated picture is the irreplaceable SOURCE of a shipped asset, it is tracked.

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


## The gilt menu ornaments (`ui/rule_flourish`, `ui/corner_*`, `ui/crown`)

2026-08-24, Louis: everything has to look "sharp and pixellated", and the menus may be
"better looking ... but don't exaggerate". These three replace the last vector strokes in the
UI - `draw_ornament`'s diamond-on-a-line (twenty call sites), `draw_frame`'s corner ticks
(eight), and the save slot's crown - all of which were 1-3 screen-pixel `draw_line` calls, i.e.
HALF-BLOCK strokes at ART_PIXEL 2.

`create_image_pixflux`, `color_image_base64` = `Resources/palette/palette.png`, `no_background`,
1 generation each. `scripts/install_ornaments.py` reduces them.

    rule_flourish  256x24, lineless, flat shading, medium detail, seed 5
        a long horizontal decorative divider rule in antique gold, a thin straight line
        running the full width with a small pointed diamond lozenge at the dead centre and a
        tiny curl of acanthus scroll on each side of it, symmetric, elegant and sparse, on
        nothing, no background, no box, no panel, no text

    corner_scroll  40x40, selective outline, flat shading, low detail, seed 41
        one small ornamental corner scroll in antique gold, a single curling acanthus leaf
        volute that opens diagonally from the top left toward the bottom right, solid
        confident gold shapes with a lighter gold highlight, compact and chunky, no straight
        lines, no rules, no border, no frame, no box, no background, no text

    crown          40x32, selective outline, flat shading, low detail, seed 7
        a small gold crown seen straight on from the front, a plain band across the bottom
        with five sharp points rising from it and one round jewel at the centre of the band,
        solid chunky shapes, lit from the upper left, no head, no person, no cushion, no
        ground, no shadow

**GENERATE THE ORNAMENT, DRAW THE RULE.** The divider was first generated whole at 256px and
that is the wrong shape for the job: twenty callers ask for half-widths from 120 to 300, so
fitting one painting to each box resamples it by a different fraction every time. Only the
ornamented CENTRE is a sprite (cropped to columns 88..152); the plain gold runs out to the
caller's width in whole art pixels. The crop is centred on the RULE (source rows 11-12) rather
than on the ink, so a 2-art-pixel flank on the sprite's own centre line joins it invisibly.

**FILIGREE DOES NOT SURVIVE A REDUCTION**, and this is the general form of it. Reducing the
64x24 crop 2:1 was tried first: the scrollwork averaged into gold speckle around a lozenge,
because scrollwork IS small-detail-on-a-thin-field - the case `clean_ground.py`'s docstring
already warns is the picture rather than the noise. Author ornaments at 1:1 art density and
palette-snap them with no box filter at all.

**AN ORNAMENT DRAWN THROUGH A TINT MUST BE A LUMINANCE RATIO.** Three of `draw_ornament`'s
call sites are not gold (the unlock banner passes lavender, the demo wall card fades on `fin`,
the Purist legend a dimmer amber), so shipping the generation's own gold gives a lavender
ornament that is still brown. Measured on the first cut, the corner scroll read visibly
muddier than the plain rule drawn beside it at the identical colour. The crown is the
exception and states its own reason: it is drawn at ONE colour in ONE state, and its red
jewels are the whole difference between a crown and a gold sawtooth.

**AND A SHADED ORNAMENT NEEDS MORE ALPHA THAN A FLAT RULE.** A rule is one solid gold at the
caller's alpha; an ornament is a shaded object, so most of its area is a fraction of white
before the alpha halves it again. `draw_frame` asks for 0.5 and blits its scrolls at 1.7x
that - the same PRESENCE, not the same number.


## The eight gear icons and the two assist icons, re-rolled

2026-08-24. `create_image_pixflux`, 40x40, `no_background`, selective outline, low detail;
`scripts/install_gear_icons.py` / `install_assist_icons.py` reduce them 2:1 and band them.

**THE FIRST BATCH LOST, AND WHY IS THE REUSABLE PART. A TINTED ICON NEEDS A MID-TONE SUBJECT,
NOT A SILHOUETTE.** Asked for "a black silk top hat", "black gloves", "a crimson tailcoat" with
`flat shading`, the model paints exactly that - and the reducer normalises every icon to its
own brightest pixel, so a black object comes back as a flat white blob with no interior at all.
Five of eight were worse than what they replaced. The clause that fixed it names a pale
material AND both ends of the light:

    a pale dove-grey tailcoat ... lit brightly from the upper left so the left side is near
    white and the right side is a clearly darker grey, bold simple shape

with `basic shading` rather than `flat shading`. Re-rolled and shipped on that: **coat, vest,
assist watch, assist boot**, plus the **helmet** from the first batch (a hard cap with a can on
one side reads at 20px where the old smudge did not). The other five keep their older sources,
which already had the value structure.


## The Small Theatre backdrop, repainted (`bg/small_theatre`)

2026-08-24. It was the flattest painting in the game - a closed upstage curtain and a plank
floor, with no depth, no architecture and nothing to look at - on the third venue of six.

`create_image_pixen`, 640x360, `no_background: false`, highly detailed, view side. FIVE ROLLS,
and four of them failed in the two ways this file already documents:

  A  seed 3, "gilded pilasters at the far left and right, a brick back wall between them"
     -> the DIPTYCH: two arches with a pillar dead centre. Any symmetric architecture invites
        the split, exactly as the title screen's own notes say.
  B  seed 3, "one curtain leg down each edge, a painted backcloth between"
     -> beautiful, and a tied-back curtain leg dead centre with two moons.
  C  seed 17, adding "nothing at all stands in the centre of the picture"
     -> a curtain leg dead centre anyway. Forbidding it does not work; it never has.
  E  seed 64, the shipped prompt, different seed -> a big tree dead centre.

  D  seed 29 - SHIPPED. What separates it is the CAMERA, which is the fix
     `scripts/clear_spine.py`'s own notes prescribe: make the middle distance a flat surface
     and there is nowhere to hang anything.

    An old painted theatre backcloth hanging flat across a small stage, seen straight on.
    Across the very top of the frame runs a swagged pelmet of deep dark crimson velvet with
    dull gold fringe. Down the very LEFT EDGE, mostly cut off by the frame, hangs the dark
    edge of one crimson curtain, and the same at the very RIGHT EDGE. Everything between them
    is ONE SINGLE FLAT PAINTED CLOTH, one unbroken sheet of canvas filling the whole width,
    painted with a dim garden at night in deep indigo and dark umber: a big dark tree at the
    far left, another at the far right, a small pale crescent moon high in the upper left, and
    a low hedge of dim dark red roses running all the way along the bottom of the cloth. The
    middle of the cloth is quiet and empty. Below it the LOWER THIRD, from about four fifths
    of the way down to the bottom edge, is one wide continuous band of unpolished stage boards
    running edge to edge, dim dark umber and ochre, falling away into shadow toward the front.
    Dark and moody, low light, few colours, flat areas of solid colour. No curtain in the
    middle, no gathered curtain, no tie-back, no tassel, no gap, no opening, no doorway, no
    people, no furniture, no writing, no spotlight, no beam, no pool of light on the boards,
    no dithering, no speckle, no noise, no grain.

    -> 24 colours, gamut 0.019, floor 0.000, spine 0.834 on the source, mid-lum 0.20.

**"A PAINTED CLOTH" IS THE PROMPT THAT BUYS THE EMPTY CENTRE, and it is worth having the
words.** A backcloth is by definition one flat sheet, so the model has no depth to put an
object into; a "stage" or a "theatre" has wings, and wings get filled. The interest moves to
the two ends of the cloth (a tree at each edge, a moon in one corner) and along its bottom (a
rose hedge), which is where a scene painter puts it anyway.

**AND THE FLOOR BAND CAME BACK ON THE DOCUMENTED LINE.** The boards' back edge measures art y
289 against the shipped painting's own 289..360, so `stand` stays 0.85 and nothing downstream
moved. The room measures 32.7 behind the performer against the old painting's 32.9, so the
default veil 0.42 is still right - which is the re-measure `venue_data`'s own note demands
after any repaint, done rather than assumed.


## Two exteriors, repainted (`ui/ext_street_corner`, `ui/ext_the_midnight_show`)

2026-08-24. Both were legal under the exterior framing rule and empty of interest - a brick
wall with one lit window for a venue whose whole name is a PLACE, and a blank stone wall with a
small door for the bonus seventh house you only reach by winning. `create_image_pixen`,
640x360, `no_background: false`, highly detailed, view side.

    ext_street_corner  seed 12, shipped first roll
        A gaslit street corner at night, seen from across the road. Filling the LOWER TWO
        THIRDS of the picture and standing dead centre is the sharp corner of an old brick
        building where two narrow streets meet, one shuttered shopfront on each of its two
        faces, and one tall iron gas lamp on the pavement in front of it casting a warm amber
        pool onto wet cobbles. The UPPER THIRD of the picture is a plain deep indigo night
        sky, almost completely empty, with only the roofline crossing the very bottom of it.
        Dark and moody, low light, few colours, flat areas of solid colour, warm amber
        lamplight against deep indigo and dark umber. No people, no writing, no letters, no
        signs, no text, no lettering of any kind, no dithering, no speckle, no noise, no grain.

    -> 27 colours, gamut 0.008, mid-lum 0.149.

**THE EXTERIOR FRAMING RULE IS WHAT MAKES THE PROMPT.** "Filling the LOWER TWO THIRDS ... the
UPPER THIRD is a plain night sky, almost completely empty" is not scene-setting, it is the
establishing card's own layout said out loud: the title crosses the top centre and two panels
sit in the bottom corners. Say it and the hero arrives in the band that is left.

    ext_the_midnight_show  seed 12, roll 2 of 4, SHIFTED -150 (see below)
        A narrow unmarked doorway at the end of a dark alley, very late at night. Filling the
        LOWER TWO THIRDS of the picture and standing dead centre is a low arched door of dark
        studded wood set into a soot-black brick wall, with one small deep-red lamp burning on
        a bracket above it, a worn stone step in front of it, and a sliver of heavy dark velvet
        just visible through the door standing slightly ajar. The UPPER THIRD is more
        soot-black brick with a thin strip of deep indigo sky above the roofline. Dark and
        moody, very low light, few colours, flat areas of solid colour, one small pool of deep
        red light against near-black brick. No people, no writing, no letters, no signs, no
        text, no lettering of any kind, no dithering, no speckle, no noise, no grain.

    -> 23 colours, gamut 0.006, mid-lum 0.09.

**ITS DOOR IS ARITHMETIC, NOT A GENERATION.** Four rolls put the door at x 470, 460, 470 and
470 - including one whose prompt said "in the EXACT HORIZONTAL CENTRE of the picture, equally
far from the left edge and the right edge" and another that named the left and right thirds as
empty. Roll 1 also gave two doors and rolls 3-4 two lamps; the shipped roll is the ONE-door,
one-lamp one. `pixelise_paint.py` grew a recorded per-stem `SHIFT` (-150 art px here), which is
the same call `pixelise_menu.py --half-shift` already made: "re-rolling until a gather happens
to land on x=319 is spending a generation on arithmetic." **A wall of brick is the one subject
a horizontal roll is free on** - it wraps into more of itself, nothing is thrown away, and
measured on the finished asset the largest adjacent-column delta is the door's own edge at
x 295, not the frame edge. The shift lives in the script rather than in a hand-edited file
because `artifacts/` is disposable: the shipped asset must be rebuildable from the prompt above
plus that one line.


## The SLOTH difficulty card, re-rolled (`ui/difficulty_sloth`)

2026-08-24. The three mascots are shown SIDE BY SIDE on the first choice a new career makes,
so the set's shared treatment is the whole point - and the sloth was breaking it three ways at
once: a dim cone where the other two have a bright amber one, a near-black ground, and a small
gaunt figure beside a bear and an octopus that fill their cards.

`create_image_pixflux`, 104x128, `color_image_base64` = `Resources/palette/palette.png`,
`no_background: false`, selective outline, highly detailed. Three rolls, and each one moved
exactly the thing its prompt named, which is worth recording because it means the set's clause
is separable into parts you can fix one at a time:

  seed 3   "...centred under a wide vertical cone of warm amber spotlight and standing in a
            bright elliptical pool of warm light on a dark ground, filling the frame"
           -> bright pool and a charming sloth, and a PALE PEACH-PINK cone. The locked 48's
              warm mid-tones will drift to salmon unless the gold is named.
  seed 3   + "of deep golden amber spotlight on a very dark maroon ground ... no pink, no
              salmon, no pale peach"
           -> cone matched the set exactly, and the sloth came back SMALL. "Filling the frame"
              had been spent describing the light.
  seed 19  + "a LARGE ... sloth ... filling most of the frame from top to bottom"  SHIPPED
           -> 28 colours, 0 off-palette.

**NAME THE GOLD AND NAME THE SCALE SEPARATELY.** "Filling the frame" attaches to whatever the
sentence was last talking about; on a card whose subject is lit by a cone, that is the cone.

## Three trick cards, re-rolled (`btb`, `columns`, `tennis`)

2026-08-24, Louis: "Regenerate the columns card, and the tennis card (which should look more
realistic), and behind the back: which should actually hold something behind his back."

Same call as the deck above - `create_image_pixflux`, 104x128, `color_image_base64` =
`Resources/palette/palette.png`, `no_background: false` - plus `selective outline`,
`highly detailed`, `view: side`. The subjects are still Louis's own metaphors; only `btb` had
its POSE corrected, and that correction was the whole point of the re-roll.

**THE BEHIND-THE-BACK CARD WAS NOT DRAWING THE TRICK.** The shipped version had the ringmaster
seen from behind with his arm RAISED and the ball up beside his head - which is a man holding a
ball, on the card for the one trick whose entire identity is where the hand goes. Two rolls:

  seed 11  the documented clause + "one arm bent round BEHIND HIS BACK ... no ball in the air"
           -> a small figure in the lower third, facing FRONT, with a ball floating overhead.
              Both faults are in this file already: forbidding a thing summons it (the ball),
              and "filling the frame" attaches to whatever the sentence last described.
  seed 19  SHIPPED. Scale named on its own ("a LARGE circus ringmaster ... filling most of the
           frame from top to bottom, his shoulders nearly as wide as the picture"), the ball
           placed rather than forbidden ("the ball in his hand is the only ball in the
           picture"), and `direction: north` to hold him facing away.

**AND THE DECK'S GROUND IS NOW REPAIRED IN THE INSTALLER, NOT RE-ROLLED FOR.** `btb` came back
on a speckled bright crimson and `columns` on a flat mid-crimson, against a deck sitting
between (8,0,8) and (56,24,16). `install_cards.py` grew a `BG_FIX` table that flood-fills the
background from the frame edge to `DECK_BG` - see its own comment for why connectivity, not
colour, is what separates the speckles from the ringmaster's coat (they share a palette
entry). Rolling until a flat field lands on the right palette entry is the arithmetic
`pixelise_paint.py`'s SHIFT note already refuses to pay for.

    btb      a LARGE circus ringmaster in a bright crimson tailcoat and a black top hat, seen
             from directly BEHIND with his back turned to us, standing straight, filling most
             of the frame from top to bottom, his shoulders nearly as wide as the picture. One
             arm is bent round BEHIND HIS BACK so that his open hand rests at the small of his
             back at waist height, and resting in that open hand is one single large white
             juggling ball, big and bright against the crimson coat. The other arm hangs
             straight down at his side. The ball in his hand is the only ball in the picture.
             Lit warmly so the crimson coat and the white ball read bright, on a completely
             flat solid dark reddish brown background of one single colour, smooth and plain,
             no gradient, no texture, no noise, no speckle, no dithering, no spotlight, no
             beam, no ground, no cast shadow, no face, no front view
             (direction north, seed 19)  -> 27 colours, 0 off-palette, 9,719 px flattened.

    columns  an ancient greek temple front seen straight on, exactly three tall fluted stone
             columns standing side by side on a stepped stone base, each column with a carved
             capital, holding up a heavy stone entablature and a wide triangular pediment above
             them, warm honey coloured stone with deep shadow in the flutes and between the
             columns, centred and filling the frame from top to bottom, [the shared clause]
             (seed 11)  -> 14 colours, 0 off-palette, 4,373 px flattened. It draws FOUR columns
             rather than the three asked for, which is the classic tetrastyle front and what the
             old card had; the pattern's three lanes are not worth a re-roll over.

    tennis   one realistic vintage wooden tennis racket standing upright seen face on, a
             polished varnished golden brown wooden frame around a large oval head, a tight even
             grid of taut pale cream strings filling the head, a solid wooden throat wedge below
             the head, and a long straight handle below that wrapped in dark brown leather grip
             tape, centred and filling the frame from top to bottom, [the shared clause]
             (seed 11)  -> 17 colours, 0 off-palette, first roll, no repair needed (it landed on
             (56,24,16) by itself).

**"REALISTIC" IS A LIST OF PARTS, NOT AN ADJECTIVE.** The old racket was a tan loop with a
coarse mesh on a stick. What made the new one read as a racket is naming the four things a
racket HAS - frame, strings, throat, grip - and the material of each. The word "realistic" on
its own moves nothing.


## The four stat marks and two record emblems (`ui/stat_*`)

2026-08-24, Louis: "regenerate the stats menus with pixellab so that it looks better". The
talent sheet and Records and History were the last menus made of type alone. `install_stat_icons.py`
reduces these the same way the gear rack and the assist pair are reduced: 40x40 generated,
20x20 shipped, greyscale, six bands, tinted by the caller.

`create_image_pixflux`, 40x40, `no_background`, `selective outline`, `basic shading`,
`low detail`. **SPEED IS NOT HERE**: it is the assist BOOT, reused by the file.

    acc   a greyscale bullseye target seen face on filling the whole frame, drawn in ONLY pure
          white and pure black with no other tone: a thick pure white outer ring, a thick pure
          black ring inside it, a thick pure white ring inside that, and a solid pure black dot
          at the dead centre. Four straight pure white crosshair spokes stick out beyond the
          rim, one at the top, one at the bottom, one at each side, so the outline is a cross
          rather than a plain circle. Hard edges, bold simple flat shape, no arrow, no stand,
          no person, no ground, no shadow, no text, no grey, no colour
                                                     (seed 55, flat shading)  THREE ROLLS:
    str   one LARGE heavy circus strongman's weight seen from the side, filling the whole frame
          from edge to edge: a big solid round pale dove-grey ball body taking up the lower two
          thirds of the frame with a thick arched handle rising from the top of it, bold simple
          chunky shape with a fat outline ...                              (seed 7, view side)
    end   one LARGE glossy valentine heart seen face on, filling the whole frame from edge to
          edge, pale dove-grey, with a big bright near-white highlight on its upper left lobe,
          a mid grey body, and a clearly darker grey shaded crease down its lower right side,
          strong three tone shading ...                          (seed 23, medium shading)
    rec   a two handled trophy cup seen face on ...                        (seed 7)
    car   an open book lying flat seen from slightly above, a pale dove-grey ledger with two
          facing pages and a visible spine down the middle ...              (seed 7)

**A FLAT SILHOUETTE IS A FAILED ICON, AND THE REDUCER SAYS SO IN ONE NUMBER.** The install
script prints the grey-level count of every finished sprite, and that is the whole test: the
first heart came back at **1 grey level** - a pale object with no interior shading, which after
normalise-to-own-brightest is a solid blob. Naming a highlight, a body tone AND a shaded crease
took it to 5. The same number caught the first `str`: a dumbbell at **89 of 400 pixels**, which
is a correct picture of a thing too thin to read at this size (the bar is one pixel). A
kettlebell says "weight" in one chunky silhouette and measures 143.

**AND THE SUBJECT HAS TO SURVIVE THE SIZE, NOT JUST THE PALETTE.** This is the same finding as
the gear rack's "a tinted icon needs a mid-tone subject" one stage further on: mid-tone gets you
interior shading, and a compact silhouette gets you a readable shape. Both, or the mark is a
smudge in a disc.

**THE TARGET TOOK THREE ROLLS AND EACH FAILURE IS A DIFFERENT RULE.**

  seed 7   "a pale dove-grey disc with three concentric rings ... lit brightly from the upper
           left" -> 4 grey levels, and in the game a FLAT PALE DISC. The rings are one art pixel
           each at 20px; interior detail does not survive this size, whatever its contrast.
  seed 31  "FOUR strongly contrasting concentric rings ... near-white / dark charcoal /
           near-white / dark charcoal" -> the model drew a proper archery target, in RED, BLUE
           and GOLD. **A coloured generation cannot be judged by its colour contrast when the
           pipeline throws colour away**: red and blue sit within a few levels of each other in
           luminance, so four contrasting rings arrived as one grey.
  seed 55  SHIPPED. Pure black and white named as the only tones, AND four crosshair spokes
           sticking out through the rim - which is the fix `day_limiter_mark` already records for
           this exact pair of objects at this exact size: **change the OUTLINE, not the middle.**
           A bullseye and a stopwatch are both "a circle with something small inside"; one grows
           spokes and the other a crown, and that much survives being small.
