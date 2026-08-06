# PIXELTOSSA

A skill-based juggling game with a light performer-career sim around it. Godot 4.7, 2D, GDScript,
one self-contained file (`Game.gd`, ~24k lines), mostly code-rendered audio. Aimed at a polished
$10 Steam release.

**This repo is the PIXEL-ART FORK of TOSSA, cut loose 2026-08-05 as its own game** with its own
name, saves, launchers and exports. TOSSA's art is drawn entirely in code; PIXELTOSSA replaces the
pictures with sprites on a locked palette and keeps the gameplay identical. Everything below that
is not in the PIXEL ART section is inherited from TOSSA and still true.

## PIXEL ART (read this before touching anything visual)

**Four decisions are locked. Do not relitigate them.**

1. **Density: 640x360, `ART_PIXEL = 2`.** One art pixel is drawn as a 2x2 screen block, no
   resampling, over the unchanged 1280x720 coordinate space. NOT 320x180: measured `--pixel`
   captures show the juggler reads beautifully there but every HUD label turns to mush (a 13px
   label becomes 3px), and this game is text-heavy.
2. **Text stays at SCREEN density**, which follows from 1. Words are rendered at 1280x720, not on
   the art grid. This is why a screen full of UI never measures as "fully converted" (see
   `scripts/check_pixel_grid.py`) and that is correct, not a defect.
3. **Style matches TOSSA.** The palette is extracted from `Game.gd` and locked to 48 colours in
   `Resources/palette/` (including a .gpl Aseprite loads). Selective or no outlines, restrained
   shading, no thick black 16-bit outlines.
4. **Grid-snap the geometry, sprite the pictures.** Panels, bars and the spotlight cone stay
   procedural. The spotlight must keep narrowing and warming as a streak builds, so it can never
   be baked into a backdrop.

**THE SEAM IS THE WHOLE ARCHITECTURE.** `Game.gd` never names a PNG. `art_blit` /
`art_blit_size` / `art_blit_rect` / `art_blit_regions` take a key like `prop/club`, and
`Resources/art_manifest.json` ALONE decides sprite versus procedural. Delete a line from the
manifest and that element goes back to being drawn. `--procart` forces everything procedural for
an A/B, `--artreport` lists every key the running session actually reached.

**DESIGN VARIANTS RIDE THAT SEAM, AND COST ALMOST NO CODE.** A variant is a SECOND manifest
overlaid on the first (`Resources/art_variants/<set>.<option>.json`): same keys, different PNGs.
`art_boot` reads the base and then each chosen overlay, so no drawing code knows a variant exists.
Two sets are on the F9 panel under THE LOOK - `character` and `lighting` (a code-side grade
rather than art). Option 0 is always the shipped default and needs no files, so a release build
reads exactly one manifest.
`--variant <set>:<option>` picks one for a single run WITHOUT touching the settings file, which is
how `screenshot.sh` captures every look without changing Louis's own choice. A look that wins
ships by being copied into the base manifest, the same rule the F9 booleans follow.

**ONE FIGURE RENDERER, EVERYWHERE.** `draw_figure_body` draws the performer from the trousers to
the hat for every screen; `fig_ys` owns the eight-head canon; `draw_arm` and `draw_mitt` are shared
too. This is not tidiness - `draw_mini_juggler` used to carry its own copy of the whole body, and
that copy was never moved onto the sprite seam, so the tailor's mirror and the skills preview
showed a smooth vector man beside a pixel-art stage. **A preview may not pick its own figure
height**: `fig_scale_H` snaps a wanted size to a whole (or exact half) multiple of the stage
figure, because a region sprite fitted to a box 1.148x its authored size draws some rows two
screen pixels tall and some three. Callers that place hands themselves must snap through
`fig_preview_k` first, or the body scales and the arms do not.

**DERIVE, DO NOT GENERATE, ANYTHING SMALL OR ANYTHING WITH A CHARACTER IN IT.**

- **PixelLab's floor is 1024 pixels of AREA.** At this density that rules it out for every stage
  prop (a ball is 11x11, the chainsaw 21x48 = 1008) and for hands and small icons. It is the right
  tool for backdrops and for large UI.
- **Props are derived**: `--propref <name>` renders one prop isolated at x6 through the real
  drawing code, and `scripts/pixelise_prop.py` reduces it (premultiply before filtering, hard
  alpha threshold, Oklab palette snap). What comes out is the game's real silhouette, not a
  model's idea of a juggling club.
- **THE PERFORMER IS THE SHOWMAN**, a PixelLab-generated ringmaster - Louis reversed the
  never-generate rule on 2026-08-06 and then picked him over the traced figure and two other
  designs. He lives in the base manifest (`Assets/Characters/showman/`) with landmark geometry
  in `_FIGURE` and two juggling strips in `_ANIM`. The traced figure survives only as the seam's
  procedural fallback, which is what makes the manifest architecture work and is not a look
  anyone chooses.
- **THE ANIMATION IS INDEXED BY THE HANDS, NOT BY A CLOCK.** This is the whole reconciliation
  between painted animation and physics: a loop on a timer drifts against the player's throws
  within seconds, because the PLAYER decides when a throw happens. `fig_anim_pick` reads the
  sim's own `hpos` and looks up the frame whose hands are nearest, so there is no phase to keep
  in sync. `scripts/fit_juggle_anim.py` measures every frame and writes the sorted table.
  **The FURTHEST hand decides**, not the average - a generated strip is symmetric while a
  cascade's hands are antiphase, and averaging parks the figure mid-sweep so every catch lands
  35px outside the palm. **The strip is chosen by the PATTERN** (columns has its own) and only
  the frame within it by reach; searching both strips as one pool flips between two different
  body poses on adjacent ticks. **`draw_arm` is not called at all while a strip is live.**
- **Two sizes per prop, ONE design.** `prop_big/*` is the shop card (PixelLab, blitted at zoom 1)
  and is the SOURCE: `prop/*` is derived from it by `scripts/derive_stage_props.py` (round props by
  `make_round_props.py --stage`, from the same analytic model that draws their cards), and the title
  wordmark bakes off it too via `mark_prop`. Before 2026-08-06 these were three unrelated pieces of
  art and a player met three different clubs. **A prop's LENGTH is fixed** by `prop_scale` and the
  collision geometry, so a derivation keeps the stage sprite's pixel height and only the width
  follows the card. **Measure the card's INK, not its canvas** - by canvas the club looked 2.6x too
  fat and by ink it was 6->7 art px.

**Hard-won gotchas, each one paid for:**

- **The pixel font is only crisp at MULTIPLES OF 4.** Measured by rendering a 9..34 sweep in
  Godot, because PIL disagreed with the engine and would have given the wrong answer. TOSSA's
  most-used sizes were 13 and 15, two of the worst, which is why the talent tree read "ZZ POINTS
  TO SPEND". `ps()` quantises at every text call site and `validate.sh` check 8 fails the build if
  a new one skips it.
- **Godot serves a CACHED import, not your PNG.** Editing a sprite on disk changes nothing in the
  game until `make reimport`, so an art fix looks like it did nothing. Two byte-identical captures
  before and after a change is the tell.
- **`scripts/artguard.py` protects hand edits.** A SHA ledger in `Assets/.generated.json`; any
  generator skips a file whose hash differs from what it last wrote, or that it has no record of
  at all. `--force` overwrites, `--relock` re-baselines.
- **Prop pivots are NOT centres** (a club tumbles about 55.8% down its sprite), and prop scales are
  fractional, so prop sprites must be pinned to exact integer screen-pixels per art pixel.
- **Tinted props are authored GREYSCALE** (`ball`, `egg`, `ring` only) because the game multiplies
  them by a colour and a multiply can only darken. They need `GREY_FLOOR = 0.45` or their rim
  pixels multiply down to near-black and read as holes in the silhouette.
- **A TINTED SPRITE MUST STORE A RATIO, NOT A BRIGHTNESS**, and that is a bug you can look
  straight at without seeing. The hands were traced from a render in which they were already
  skin-coloured, so `hand_open` was a flat mask at 0.45 luminance; multiplied by skin (0.87, 0.63,
  0.43) the performer's bare hands came out near (0.39, 0.28, 0.19) - two lumps of wood on the
  ends of his sleeves, on every screen. The lit side of anything the game tints has to reach pure
  white. `scripts/shade_char_hands.py` fixes them by fitting a SPHERE, not a distance-transform
  dome: at twelve pixels the interior of a dome is one flat plateau three pixels in, so all the
  shading ends up in a one-pixel rim and the palm comes back uniformly white.
- **Generators put round props on a PLINTH** even when told not to, and it is fused to the
  silhouette so a width-threshold filter misses it. `scripts/trim_plinth.py` detects it properly
  (convexity break plus a luminance drop) and explains why the obvious rule fails.
- **`costume_palette()` changes five colours per venue**, so the torso, arms and legs stay
  procedural on purpose: one sprite freezes the outfit and one tint cannot carry five colours.
  The body is per-region sprites multiplied by the live costume colour.
- **zsh: an unquoted `$var` holding two flags passes as ONE argument.** Use `${=f}`.

**Full narrative history (every dated session, every rejected attempt, every measured number)
lives in `CLAUDE_HISTORY.md`, archived 2026-07-31.** This file is trimmed to current-state facts
and standing rules. Grep the archive when you need the reasoning or evidence behind a specific
constant; don't re-read it by default.

**When this file passes ~60k characters again: move its oldest dated sections into
CLAUDE_HISTORY.md (append, don't overwrite) and re-trim to current state. Don't wait for Claude
Code's 150k-char load warning to force the issue.**

**THE NAME**: the game is **TOSSA** (was IACTO, was JUGGLE), living in exactly two constants -
`GAME_TITLE` and `TITLE_MARK`. `migrate_old_saves()` copies (never moves) old-named saves forward
on first run; delete it only once no old build could plausibly still exist anywhere.

## The three pillars (never trade these away)

1. **Skill first.** Stats govern access/comfort (which props and counts are practical, how
   forgiving catches are). Player skill governs excellence (score, records, high counts). Stats
   must never auto-play the timing floor.
2. **Juggling is real.** At least one prop in the air at all times (`juggling_catch` enforces
   this everywhere). One gravity, one closed-form parabola (`flight_pos`) everything derives from.
3. **The first impression is calm.** Warm theatrical stage, chill music, smooth UI. Dopamine is in
   the catch/drop sounds, streaks, tricks and unlocks - never in flash.

Any new idea gets tested against these three before anything else; see CLAUDE_HISTORY.md's "idea
review" for the accept/reject examples and why.

## Current state (as of 2026-07-30)

- **Input:** per-hand THROW/CATCH, Space=trick, C=switch trick, P=pattern, O=object, 1/2=step
  count, R=restart (practice), S=shop, Tab=sheet, Esc=menu, Enter=finish/cash in. Gamepad layout
  and remapping: see `Game.gd`'s input section, unchanged shape since 2026-07-18.
- **Throw:** tap=lowest/snappiest, holding lifts continuously toward 1.4 (1.8 held High Toss).
  Strength is a hard wall now (`PROP_STR_UNIT` x count) - no under-Strength throw exists.
- **Catch:** Perfect always secures; Good/Late are a rising-with-Accuracy, falling-with-height
  chance (90%/70% at Accuracy 100, no gear, no extra height). Accuracy 101-150 = Focus (stamina);
  151-200 buys 5 catch frames.
- **Scoring:** exponential, Balatro-shaped. A *run* is the stretch since the last drop; it
  accumulates linearly and a landed trick multiplies the WHOLE run (`p^x`). A drop banks the run
  and resets to x1. `chain_mult` saturates (`1 + 3*c/(c+40)`, →x4, never capped-feeling on
  screen). Goals are gated on BOTH a number and a minimum time (`GOAL_MIN_S_LOW/HIGH`) so an
  exponential build can't finish a house in four seconds. `safe_pow`/`SCORE_CEIL` (1e300) keep
  everything off `INF`; `score_text` switches to E-notation past a million. Toggle tricks pay
  per-catch (shape every throw); live tricks (Spin) pay per-press - never conflate the two.
- **Props:** balls/rings/clubs/knives/torches/eggs/chainsaw. Cost to throw = `PROP_STR_UNIT` x
  count (one rule); `PROP_SIG` is a score EXPONENT; `pwin` shifts all three catch bands together.
- **Patterns:** Cascade, Columns, Half Shower, Shower, Reverse Cascade, Tennis. Arms reach exactly
  two points (`inner_pos`/`outer_pos`) with no exceptions - Mills Mess would need this to change,
  which is why it's an architecture change, not "one more pattern."
- **Tricks:** Behind the Back, High Toss (toggles), Spin (live, no cooldown, full catch/throw
  lockout while spinning - a cost paid in airtime, not a timer). Cascade-only except High Toss
  and Spin, since every other pattern is a fixed geometry a shaping trick would contradict.
- **The act:** one continuous run per venue, three goals (+ante multiplier, capped 1.25^n→6x).
  Cash in anytime past goal 1; a collapse strips back to the last goal banked. One optional Encore
  challenge may color the act (never at the Backyard).
- **Skills are a face-down deck**, dealt (not auto-unlocked) at the same pacing walls as before;
  `owned_skills`/`gifted` is what you own, `skill_gate_cleared` is what you've earned a card for.
- **Economy:** FLOWERS are the currency (visual + word, no "gold"/"f" anywhere). The crowd throws
  them live during a good run; tomatoes are the failure-currency (stamina only, capped kept).
- **Day loop:** TONIGHT (perform/practice/daily) / REST (meal/inn/pie/energy drinks) / PREPARE
  (shop/tailor/skills) drawers. Tailor is a real loadout - wearing gates a per-house bonus,
  8 pieces x 7 cuts, one piece per category enforced on load.
- **Venues:** Backyard→Street→Theatre→Circus→Championship→World Arena (the win, `TOP_VENUE`)→
  Midnight Show (bonus 7th, gated on having won + Reputation 6000).
- **Records/pay/rep:** per-venue assisted + Purist boards; pay scales with surviving score; rep
  swings on goals reached.

## Hard rules (see `docs/coding_guidelines.md` for the full checklist)

The distilled rulebook (text rendering, drawing, performance, persistence, testing) now lives in
`docs/coding_guidelines.md` so it doesn't drift from this file. Read it before touching drawing
code, save format, or anything performance-sensitive. The one rule worth repeating here because
it's cost real time twice: **never run a DOTALL (`re.S`) regex to cut a range out of Game.gd** -
it has deleted 16,099 lines once already by matching to the last occurrence of the end string in
the whole file, not the nearest one.

## Verification workflow

`scripts/validate.sh` (see repo README) wraps the dev-flag harness below into one command. Key
flags if you need to drive the game directly: bare `--` is REQUIRED before dev args (without it
they're invisible and the game hangs at the menu - looks like a bug, isn't). `--demo` autoplays;
`--booking`/`--daily` run a real act to resolution; `--collcheck --latecatch N` audits mid-air
clearance (prints `min clearance` = hitbox gate, `min drawn gap` = visual, informational only -
Half Shower/Tennis are DOCUMENTED to run near-zero/negative by geometry, not a bug); `--ladder`
prints every venue's expected build/pacing from the live constants; `--fps` prints the perf probe
(trust `draws/s` over `engine fps` unless the window has focus - see `docs/coding_guidelines.md`).
`godot --check-only` is a fast filter, not a reliable one (has missed a real parse error before) -
always also run a real windowed/headless pass and grep for `SCRIPT ERROR`/`Parse Error`.
Always `--audio-driver Dummy` for any run Louis isn't actively playing.

## Music / audio

Louis's own Suno tracks, free-tier renders, **NON-COMMERCIAL** - must be re-rendered under a paid
Suno month and swapped before release. SFX synthesized at startup (`gen_sfx`), catch sounds
quality-led, tonal stingers only, no ambient crowd bed.

## Release blockers (from AUDIT_2026-07-26.md)

1. Music licensing (above).
2. No demo export preset yet - Louis needs to add it in the editor (Project > Export > Add,
   feature tag `demo`); a blind hand-edit of `export_presets.cfg` risks silently malforming it.
3. macOS signing/notarization not yet configured.
4. A few legibility passes (controls screen, in-stage timing callouts) - see the archive for specifics.

## Still open (backlog, not yet built or not yet verified - see CLAUDE_HISTORY.md for full detail on each)

- PROP CATEGORIES + shop rebuilt around them (Louis's own top pick from the idea review).
- Per-venue audience taste, a named rival per venue, more Encores, 2-3 more venues.
- Verify the Daily Challenge end-to-end (built, unconfirmed on a real calendar day).
- Ghost replays (sim is deterministic at fixed 120Hz - the hard part other games lack).
- Ante ladder's top houses (World Arena, Midnight Show) are calibrated by arithmetic only,
  never measured by a human - check first with a controller if balance feels off up there.
- Ideas explicitly REJECTED (don't re-propose without new information): anything that perturbs a
  flight path the player can't read, an auto-catch assistant, zero-g/second physics models, a joke
  prop category, stacking rings, a full roguelike/prestige reset. See archive for the full list
  and the three-pillar reasoning each one failed.

## Gotchas that keep biting

- The `/Applications/TOSSA.app` launcher is a wrapper with a hard-coded path OUTSIDE the repo -
  run `./install_apps.sh` after moving/renaming the project folder, or it silently breaks (bounces
  once in the Dock, no error anywhere).
- Godot user args need bare `--`; in zsh, an unquoted `$var` holding `--day work` passes as ONE
  argument and the flag silently does nothing.
- Numbers a player reads go through `commafy`/`fit_size` - never hand-written into a description.
- `cine_tick` runs at 120/s: halve intuitive sin rates.
- The shutdown "ObjectDB leaked"/"resources still in use" noise is benign (live music streams at
  quit) - only worry if the count grows with run length.
- The juggler figure's stance/proportions are settled: never reshape as a side effect of a fix.
- **`--shot` lies when the window is not focused.** `get_viewport().get_texture().get_image()`
  hands back the last *presented* frame, which on an unfocused window can be seconds stale - so
  a capture looks like the game is stuck on an old screen when it is not. Launch, then
  `osascript -e 'tell application "System Events" to set frontmost of (first process whose name
  contains "Godot") to true'` a few seconds in. `--shotat` counts PHYSICS frames (120/s), and a
  tutorial freeze burns them without advancing `tick`, so it is not a clock.
- **Parse-check what is COMMITTED, not the working tree.** `178cbd9` shipped a Game.gd that
  referenced three constants declared only in an uncommitted line; `godot --check-only` on the
  working tree passed and a clone of the tip would not load at all. `git clone --depth 1
  file:///path && godot --headless --check-only --script Game.gd` is the check that catches it.
- **Cascade only crosses at an ODD count** (`do_throw`'s `cross`), and the basics lesson
  overrides that for its two-ball step. Any tutorial choreography written by hand has to know
  which of the two it is standing in, or the scripted hand order goes wrong from the second
  exchange - and it goes wrong invisibly, because the catch guard quietly covers for it.
