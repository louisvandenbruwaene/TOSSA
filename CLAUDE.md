# TOSSA

A skill-based juggling game with a light performer-career sim around it. Godot 4.7, 2D, GDScript,
one self-contained file (`Game.gd`, ~28k lines), mostly code-rendered audio. Aimed at a polished
$10 Steam release.

This is the pixel-art game formerly called PIXELTOSSA. It took the TOSSA name back on 2026-08-15;
the old code-drawn version now lives read-only under `legacy/tossa-vector/`. Runtime save filenames
deliberately retain the `pixeltossa_` prefix so the two games cannot overwrite one another. TOSSA
replaces most pictures with sprites on a locked palette while keeping procedural fallbacks behind
the art-manifest seam described below.

## Recovery and change discipline

The documented pre-Codex baseline is the annotated git tag `tossa-pre-codex-2026-08-16`. It is a
known-good, clean state: restore it on a new branch with
`git switch -c recovery/tossa-pre-codex tossa-pre-codex-2026-08-16`. Do not reset a working tree
with uncommitted work.

Codex work lives on `codex/improvements` and follows three rules:

- one player-visible fix or improvement per commit;
- the commit message says what changed and why, and this file records any new standing rule;
- validate before every commit (`make quick-validate` normally, `make validate` for simulation,
  rendering, input, or persistence changes).

This makes any individual change removable with `git revert <commit>` without unwinding unrelated
work. `git log --oneline tossa-pre-codex-2026-08-16..codex/improvements` is the Codex change list.

Codex improvements:

- **The stat sheet is a set of short roads, not four career-length rulers:** each panel keeps
  its established layout but fills only toward the next useful goal. Accuracy points toward
  the next Accuracy-gated move, Strength toward the next object set, Endurance advances in
  ten-point bands, and Speed advances one whole percent of slow motion at a time.
- **New-career tutorial persistence:** the initial `"balls"` lesson marker is saved before the
  lesson starts. Closing the game during onboarding must never reopen that slot past the tutorial.
- **Actionable validation failures:** `scripts/validate.sh` removes temporary logs after a pass but
  preserves them after a failure and prints their path. A failing check must not erase its evidence.
- **SLOTH has a gentler economy and clock:** it starts with 200 flowers and contributes a permanent
  20% base slowdown through `slow_target()`. A Purist Speed bind forces all slow motion to zero,
  including difficulty, pies, and earned bursts.
- **The mandatory lesson proves juggling, not button tallying:** its final three-ball free-play
  gate only counts catches that leave another prop airborne. It also verifies one held-height throw,
  introduces timing grades and core movement controls, then tours both HUD rails in the first show.
- **First-show onboarding survives restarts:** `post_lesson_show` and `show_guide_seen` are save keys.
  A quit before that booked show resumes it; a quit after reading its HUD tour does not replay it.
- **Tutorial controls arrive with their systems:** basics teaches hands, timing, held height, the exact
  paused two-ball rhythm, the mirrored three-ball rhythm (`J F D J K F D J K F D J K` for a
  right-dominant player), the paused empty-hands cascade, restart and
  menu. Prop/count/pattern/trick lessons introduce O, 1/2, P, and Space/C only when those features
  unlock. The post-show hub tour introduces Tab, the shop, progression scaling, and optional shortcuts
  across four short pages. The goal-stem demo holds its finished yellow bloom for one full second.
- **Tutorial actions stop at teachable moments:** a held high toss must be released and caught, then
  waits for Enter; guided throws pause with the preceding ball near its apex and guided catches pause
  just before arrival. **A LESSON MAY NOT STOP THE WORLD MID-SENTENCE OR MID-RELEASE (2026-08-19,
  Louis: the tutorials "pause at the wrong time, they should only pause when an input is
  expected ... make sure they don't pause when the balls have only just left the hand").** Three
  rules, all measured with the new `--tutlog`, which prints every freeze with each airborne prop's
  age and time-to-landing (a stopped world is the one state a screenshot cannot judge):
  ALL 26 of the basics lesson's freezes opened while the line was still typing at
  TUT_SPEECH_CPS - `tut_hold_update` has gated on `tut_speech_done` since 2026-08-08 and the
  basics' own `do` beats never got it; a plain throw beat now waits for its line, while a PEAK
  and a CATCH beat are exempt because both are timed on a prop already flying (an apex arrives 42
  ticks after a launch and a line takes 150+), and `tut_snap_speech` finishes the line for them.
  After the fix: 30 freezes, none mid-sentence, lesson completing in 32s of the harness's 60.
  **AND THE RELEASE HALF OF IT IS FIXED IN THE DRAWING, NOT BY REFUSING TO PAUSE** - see the
  note above `tut_quiet_fx`. A gate that held freezes out of the release window worked and
  desynchronised the scripted hand order: delaying one beat 36 ticks let the CATCH GUARD fire
  inside the gap, the autoplayer caught into a hand the advanced style needs empty, and the
  lesson stalled at 46 of 59 steps. **A scripted lesson is a sequence; anything that moves a
  beat can let another mechanism take it out of order** - which is CLAUDE.md's own warning about
  hand-written choreography arriving from a direction nobody had thought of. Free-practice tallies clamp and remain banked at their target. During basics,
  Esc offers Resume, Restart Step, and Quit Game; it never offers End Session/day hub, so quitting is
  allowed but skipping mandatory onboarding is not.
- **Unlock lessons are selective and share one juggling grammar:** buying a new prop does not queue
  another tutorial, and higher counts do not repeatedly re-teach the same controls. Four balls is the
  sole count milestone. It and pattern lessons put every object up, then guide catch-and-throw on each
  arrival for two complete cycles; old queued prop/count lessons are filtered when saves load.
- **First-performance HUD tour is progressive:** it walks stage, stamina, score flower, crowd,
  routine, then stopping. The multiplier readout was removed; the flower stays hidden until its page
  and its completed bloom is yellow. Tutorial key names use yellow bracket styling consistently.
- **Difficulty and run type belong to the save file:** only a newly created slot asks for difficulty
  and then Normal Career / Sprint. Existing slots launch directly, Settings cannot change difficulty,
  and a Sprint slot keeps only its immutable identity while each timed attempt remains disposable.
- **The controls screen is a complete two-device reference:** keyboard and gamepad live in parallel
  cards and remain readable regardless of which one has focus. Fixed gamepad hand controls are shown
  alongside the two remappable actions; secondary keyboard controls use keycaps rather than prose.
- **Fifty Perfects reward a drop-free run, not a deleted chain:** Good and Late catches preserve the
  tally; a drop or a new run clears it. The fiftieth Perfect grants 15 seconds of thick time and starts
  the next tally at zero. `scripts/TossaRewards.gd` carries the tested progress rule.
- **Perfect and Amazing are mutually exclusive catch grades:** an eligible frame-perfect catch says
  `AMAZING!`; every other Perfect says `PERFECT`. Neither carries a black popup plate, and the score
  rail no longer repeats the amount currently at risk.
- **Round-prop title art has one silhouette treatment:** ball and ring card/stage sources are generated
  from the same banded model with a dark edge instead of a pale rim. Re-run `make_round_props.py`, then
  `pixelise_mark.py` after round-prop changes. The title A uses slightly larger, lower-reaching clubs.
- **The title renders its prop mark live at menu size:** the stale `wordmark_168` bake remains available
  to smaller secondary lockups, but the title itself uses the shared ball/ring/club sources so an asset
  improvement cannot silently disappear behind an old bake. This includes the two A-crossbar balls;
  they go through `prop_big/ball`, exactly like both S letters, rather than `cap_ball`.
- **Sprint records are deterministic without touching career saves:** the route owns a fixed seed,
  freezes its clock at failure or the World Arena clear, and stores only the fastest completed route
  in `tossa_sprint_best.json`. Playback is cyan accepted-input cues; it never drives the live juggler.
- **A venue taste is a stated, deterministic patience reward:** each rival's establishing-card line
  names the exact behavior its crowd rewards. It may warm the room slightly but never changes flight
  physics, catch odds, or score. Pattern briefs must be ownership-gated so an impossible one cannot roll.
- **Knife, torch, and chainsaw drops require recovery:** they end the act immediately and empty stamina,
  forcing food or sleep. Their presentation stays non-graphic and Reduced Motion removes the pulse.
  Flowers are not also confiscated; one consequence is enough.
- **Save migrations have fixture-backed pure helpers:** migration logic belongs in
  `scripts/TossaSaveSchema.gd`; `Game.gd` owns file IO and applies the translated values.
- **A LESSON PAUSE HAS TO MOVE THE WORLD BETWEEN BEATS (2026-08-20,** Louis: after the pause
  for the catch "there should be a pause for throwing, right now the ball is still in the air,
  it should be in the hand for that pause"). A `do` beat clears the instant its key lands and
  the next step's freeze was gated on `tut_speech_done()`, which the catch guard SNAPS to
  finished the moment it stops the world - so a catch and the throw after it resolved inside
  ONE frozen tick. `--tutlog`: steps 47-50 all opened at tick 3177, 51-54 all at 3247, and the
  empty-hands opening launched two props in the same tick. **A THROW BEAT NOW NEEDS THE PROP IN
  THE HAND AND `TUT_SETTLE` (24 ticks) OF REAL MOTION**, and the aura asks the same question in
  the same order the freeze does rather than always handing itself to the guard's falling prop.
  **AND A PROP ALREADY COMING DOWN OUTRANKS EVERY GATE** - the first cut simply delayed the beat
  and walked straight back into the trap above `tut_quiet_fx` (guard takes the freeze,
  autoplayer catches into a hand the advanced style needs empty, lesson stalls at 45 of 59).
  The guard would freeze at that instant anyway and it can only ask for a CATCH, so the
  script's own throw has to win there.
  **AND THE OLDER LESSONS' OWN BEAT NEEDED THE SAME THING, ONE RANK DOWN (2026-08-20,** Louis,
  on the trick lessons: "the throw pause ... shows the ball still in the air, when it should be
  in the hand and also follow the hands motion ... the ball should have been caught and then
  paused and then animated to throw"). An ADVANCED `tut_hold` beat carries BOTH asks - catch at
  rank 1, throw at rank 2 - and `tut_hold_mark` only released the world once the LAST was
  banked, so the two resolved in one frozen tick: the prop teleported from 14 ticks up its arc
  to the hand's outermost catch reach and the arm never closed on it. `tut_rank_ready` gives the
  ranks the gap the beats already had. **THE GUARD ESCAPE IS WHAT MAKES IT SAFE AND WHAT SCOPES
  IT**: a prop already inside the catch window cancels the gap, so BEGINNER's "J then K" (whose
  prop is still flying after the throw) is byte-for-byte unchanged, high counts cut the gap
  short by themselves, and nothing can ever land unguarded. Measured on `trick_btb`: one beat
  line at t536 becomes a catch at t536 and a throw at t560, same 819-tick completion.
- **A lesson's opening throw belongs to the STRONG HAND (2026-08-20,** Louis: "the tutorials
  should always use the dominant to start throwing"). Every lesson already meant to -
  `tut_setup_step` seeds `tut_last_throw` to the weak hand so `tut_feed_hand` starts at the
  strong one - and nothing enforced it, because the only thing that can refuse a press is a
  beat WITH THE WORLD FROZEN and the opening runs before the first beat opens. `tut_open_hand`
  governs that window only and stands aside for an open beat, a basics `do` step and free play.
  The gate is in `do_throw`, at the choke point: the demo metronome bypasses `on_throw_press`,
  so a gate up there is one the harness could never verify.
- **EVERY SKILL IN THE BASICS IS TAUGHT TWICE - GUIDED, THEN HANDED BACK (2026-08-24,** Louis:
  the tutorial should "work very smoothly and explain all concepts at a reasonable pace"). The
  lesson's shape is a `do` run that walks the player through a skill beat by beat, then a `free`
  beat that gives it back to them, and the two halves are what make a skill stick. Auditing it
  against that shape found the pace faults, not the mechanics - the lesson has walked end to end
  under `--demo --tutorial balls --tutcheck --tutlog` since the August freeze work:
  - **the empty-hands cascade had no second half.** Thirteen stopped-world presses on the
    hardest thing the lesson teaches, a summary line, and it was over. It has a practice beat
    now, and that beat is gated on **throws, not catches**, because it is the last beat of
    mandatory onboarding and the worst place in the game to strand a beginner: `tut_throws`
    only climbs within a step, so the gate cannot reset, while `style` still rides along so a
    slip back into the beginner exchange is named out loud (`tut_on_catch`).
  - **the two-ball table ran the same six beats twice.** Beats 9-14 were byte-for-byte 1-6, on
    the easiest load, ahead of a free beat already asking for six throws and six catches. Eight
    beats is the whole exchange and the run still ends on the side it started.
  - **the last two beats both taught R.** A `say` naming R and Escape, then a `read` naming R
    again - while the key row along the bottom has spelled out both since the first frame.
  Net: 58 steps to 52, one of them new practice. **A CLOSING BEAT MUST ASK FOR ITS OWN DEAL.**
  The two `say` lines that used to close carried `balls: 0`, so the table emptied as a side
  effect and the last line always dealt clean; with a practice beat above it on the same count
  the closing line flowed on with three props falling and the catch guard stopped the world
  three times mid-sentence to save them (`--tutlog`: t3320, t3322, t3323). `fresh` states the
  rule the old emptied table only happened to satisfy. **And a tally row that asks for nothing
  is not a goal** - the free-practice card drew both rows unconditionally, so a single-target
  beat showed "catches  0 / 0" in the completed green; rows are built from the targets that
  exist and the card is sized to what it draws.
- **A FROZEN FRAME HAS AN OWNER, AND THE AURA AND THE KEYS BOTH DESCRIBE IT (2026-08-24,**
  Louis, on the two- and three-ball runs: the text and the awaited input are right, but "the
  pauses (the moments) and which ball is highlighted is wrong ... the wrong popup button
  appears"). Three separate things said the same wrong thing, and all three came from the same
  place - `_physics_process` tries the script's own `do` beat ONE BRANCH ABOVE the catch guard,
  so a throw beat wins the freeze the instant a prop enters the guard window, and nothing else
  was asking who had won.
  - **the moment.** A throw beat's three gates cannot all be met in the exchange: `TUT_SETTLE`
    holds it 24 ticks, a short line takes ~50 more at `TUT_SPEECH_CPS`, and the next arrival is
    only 36 ticks behind the catch that opened the beat. The speech gate therefore never
    delivered a throw pause at all - the guard escape fired every time and `tut_snap_speech`
    finished the line anyway. So the throw was asked for AT the next catch's instant and that
    catch then opened in the same frozen tick: two asks, one frame, nothing moving between.
    `tut_throw_crowded` gives a throw with something coming down the same exemption a peak and
    a catch beat already have, and it opens on `settled`. **This can only move a beat EARLIER**,
    which is why it cannot walk back into the trap above `tut_quiet_fx`. Throw beats opening on
    the guard: 11 of 21 to 2.
  - **the keys.** The catch prompt's guard exception asked whether a prop was LANDING rather
    than whether the guard OWNED the freeze, while `do_goal` is set for every `do` beat either
    way - so a throw beat lit a catch key too, and at three props both keys landed on the same
    palm. It now asks `tut_focus_ball`'s question, in the same order.
  - **the two remaining guard-owned throws are the empty-hands opening** and must stay: the
    third throw genuinely coincides with the first prop landing, and moving the peak gate above
    the guard escape is the documented stall.
  - **the circle was a THIRD answer, and the loudest one (2026-08-24,** Louis: a beat "says:
    throw the ball (which should be circled), but then it circles the ball that will be caught
    right after this step"). The mark he means is not the aura at all - it is `draw_targets`'
    LANDING RING, five pixels of white-hot gold and the timing cue the whole game is played
    off, drawn for any prop within 46 ticks of landing. During a guided exchange that is always
    the NEXT prop in, so a throw beat lit its hand's key, glowed the prop in that hand, and then
    circled a different prop entirely. **A 0.22-alpha aura cannot argue with that ring**, so the
    ring was the answer to "which ball" and it was deriving its own. It goes through
    `tut_focus_ball` now, but only while `tut_helped()` - a `free` beat is real play with a real
    drop, and nothing outside a lesson changes. On a throw beat the subject is IN A HAND, so no
    landing ring is drawn at all, which is correct: a prop being thrown has no landing to mark.
    That also makes `--tutlog`'s `aura` field predict the ring exactly, which is how it is
    checked - across the basics, every throw beat's subject is in a hand and every catch beat's
    is the incoming prop.
  **AND `--tutlog` NOW PRINTS `aura` AND `guard`**, because none of this was measurable before.
  A screenshot cannot judge a freeze, and `--tutorial balls N` cannot stand in for one either:
  setup deals a static table, so the airborne state a real playthrough has at that beat never
  exists and every mid-sequence capture is of a position the lesson never reaches.
- **Tonight's limiters are POST-WIN content (2026-08-20,** Louis), gated on `won` like The
  Midnight Show and the Purist Legend chase, and shown as **two struck-out marks under the
  stage name** rather than a panel of rows. `MARK_BAND_H` is a constant so the perform card
  never changes height for them; the record and the Reputation gate (`x / y`) sit right-aligned
  in the same band and the next-skill hint is gone. The two marks must differ OUTSIDE the ring
  (a bullseye and a stopwatch at 16px are the same mark twice - the reason the old panel had no
  icons at all), and they may not reuse `day_icon`'s pair, which draw their red bar always
  because there the bar meant "limiter" rather than "booked". `--binds` keeps its capture path
  through run-local `_binds_dev`, never a forced `won`, because that flag writes to the save.
- **THE ENDING IS THE TITLE SCREEN'S ROOM, AFTER THE SHOW (2026-08-24,** Louis: "just use the
  same screen as the title screen, but now with flowers and overlayed with thanks for playing -
  remove the golden border and the 3 juggling balls"). `draw_credits` used to paint its own
  house (`ui/victory`) and consequently had to re-argue three decisions the title screen had
  already settled, and lost all three: a `draw_frame` rectangle inside a picture that already has
  a proscenium; a `draw_spotlight_cone` (legal over `ui/victory`, which paints a lit chandelier
  above the apex, and illegal over the menu bake, whose velvet runs clean off the top edge -
  `menu_backdrop` brings `menu_house_light` instead); and a `draw_read_column` scrim that only
  existed because the victory boards are lit from inside. **A screen that borrows a room borrows
  its rules**, which is most of the argument for borrowing it. The thanks moved off the roll and
  onto the held card - it used to scroll past and then be repeated by the card a moment later.
  - **A FRACTION THAT NAMES A LINE IS NOT A FRACTION THAT NAMES A SURFACE.** The flowers were
    first scattered from `MENU_FLOOR` (0.80) to the bottom of the screen, which sounds like "the
    floor" and is the LIP - the line a menu row's feet stand on - so the whole tribute landed in
    the front row's seats. Scanned row by row, `ui/menu_backdrop`'s boards are art y 266..307 of
    360 with the footlight bulbs at 296..299, and `CREDITS_BOARDS_BACK/LIP` are those numbers.
    The scatter stops well short of the bulbs because a flower is drawn from its centre and
    carries a stem, so a band ending at the lamps hangs blooms over them.
  - **An even random `t` across a receding surface piles up upstage**, because it is even in
    SCREEN rows and the near half of the floor owns more of them; `sqrt` weights it downstage.
    All four flower tiers are drawn in variety (Louis: "a variety of flowers and bouquets") -
    the first cut was six-in-ten single stems, so three of the four designs were off screen.
  - **`--credits <ticks>` seeds `cine_tick`** so the held final card can be photographed at all.
    The roll is ~100s and the card assembles only after it, so the last thing the game ever
    shows had no capture target and nobody had looked at it.
- **Flight and collision audits share pure geometry:** parabolic position/velocity and edge
  clearance live in `scripts/TossaGeometry.gd`, with contract tests. The live wrappers retain
  domain names; the audit must not grow a second copy of the clearance formula.

## PIXEL ART (read this before touching anything visual)

**Four decisions are locked. Do not relitigate them.**

1. **Density: 640x360, `ART_PIXEL = 2`.** One art pixel is drawn as a 2x2 screen block, no
   resampling, over the unchanged 1280x720 coordinate space. NOT 320x180: measured `--pixel`
   captures show the juggler reads beautifully there but every HUD label turns to mush (a 13px
   label becomes 3px), and this game is text-heavy.
   **THE ONE EXCEPTION IS THE STAGE PROPS, added 2026-08-15** (Louis: they "still look very bad
   and pixellated"). Every `prop/*` sprite is authored at DOUBLE density and blitted through a
   manifest `scale` of 0.5, so one source pixel lands on exactly one screen pixel. This is not a
   relitigation of the density: the prop's size on screen is unchanged to within a pixel, and
   0.5 x ART_PIXEL 2 = 1 keeps the whole-number rule that the lock exists to protect. It buys
   detail nothing else could - a club had 224 authored pixels to spend on a crimson body, two
   gold bands and a bone handle, and now has 896. See `derive_stage_props.py`'s `STAGE_H`.
2. **Text stays at SCREEN density**, which follows from 1. Words are rendered at 1280x720, not on
   the art grid. This is why a screen full of UI never measures as "fully converted" (see
   `scripts/check_pixel_grid.py`) and that is correct, not a defect.
3. **Style matches TOSSA.** The palette is extracted from `Game.gd` and locked to 48 colours in
   `Resources/palette/` (including a .gpl Aseprite loads). Selective or no outlines, restrained
   shading, no thick black 16-bit outlines.
4. **Grid-snap the geometry, sprite the pictures.** Panels and bars stay procedural but are
   rasterised on the art grid. Light that answers the player stays procedural for the same
   reason it always did - a streak still warms and lifts the floor pool, so that pool can never
   be baked into a backdrop.
   **THE SPOTLIGHT CONE ITSELF IS DELETED (2026-08-15)**, and the rule it leaves behind is
   worth more than the cone was. Louis: "none of the stages should have a cone light, because
   where would that even come from?" Nothing in a backyard, on a street corner or in a circus
   tent casts a hard triangular beam down the middle of the frame, and both arenas are already
   lit by the floodlight arrays painted into their own backdrops. **Light must name a source the
   picture actually contains.** That applies to a drawn cone exactly as it always applied to a
   baked one; the drawn version simply made the same mistake one stage later in the pipeline.
   The Circus keeps its ring of light because that ring is PAINTED ON ITS FLOOR - sawdust
   catching the lanterns overhead, not a beam hanging in the air.
   **THE RULE WAS APPLIED TO THE VENUES AND NOT TO THE SCREENS AROUND THEM; IT IS NOW
   EVERYWHERE (2026-08-15).** Three sourceless beams survived the sweep, on the screens a
   player sees most: the TITLE screen still called `draw_spotlight_cone` over a curtain that
   runs clean off the top edge of `ui/menu_backdrop` (a beam out of the ceiling of a room with
   no ceiling in it - `menu_house_light` replaces it with an up-wash off the footlights that
   ARE painted in the bake, plus a slightly stronger halo behind the wordmark); the TAILOR's
   mirror kept a hard `draw_colored_polygon` triangle that the skills preview had already
   dropped on 2026-08-13, in a dressing room with an unbroken card above him. The remaining
   `draw_spotlight_cone` call sites are STORE CAPSULE art, where a dramatic beam is the
   point and no room is being described - **and one live screen, the victory roll, which
   passes the rule rather than escaping it** (checked 2026-08-19; this line used to claim
   "all", which was simply wrong and would have got the cone deleted by someone trusting
   it). `ui/victory` paints a gilt chandelier with four burning candles at the top centre,
   directly above the cone's apex, so the beam names a source the picture contains. It also
   runs at strength 0.08 against the title screen's old 0.30. **Check the painting before
   deleting a beam: the rule is about a source, not about the shape.**
   **A SOFT BEAM OVER A STRIPED SURFACE DOES NOT STAY ONE BEAM**, and this is the general trap
   worth remembering: a low-alpha wedge laid over vertical folds is brightened by the fold
   pattern underneath, so lit cloth reads as beam and a dark fold down the middle reads as the
   gap between two of them. Measured on a title capture, ONE cone with a single apex looked
   like a crossed pair of follow-spots. Nothing was doubled anywhere in the code.
   **AND NEITHER DOES THE VEIL STOP AT HIS FEET** (2026-08-15, Louis: "there is a too obvious
   cutoff below the characters feet: like dark above and light right under it"). `draw_backdrop`
   ran its push-back wash from the top of the frame to `fy` and then simply ended, so the row
   above the standing line carried the venue's full veil and the row below carried none - a
   hard step in ONE row, across the whole width, a few pixels under the performer. Measured on
   a Circus capture: (125,100,82) to (185,165,145). It reads as the floor being a separate
   brighter object pasted under him, which is the "vector stage" look that deleting the podium
   was supposed to end. The veil now CONTINUES at the value it already reached and decays to
   nothing over the next 72px, so no level above the line moves and no new brightness target is
   invented. Grading it DOWN toward the floor instead removes the step by brightening the set
   immediately behind the performer, which is the one place the veil earns its keep.
   **AND A LIGHT POOL FADES IN AS WELL AS OUT.** `draw_stage_light`'s floor wash started at
   full strength at `fy - 10` with nothing above it, which is a hard step from zero in one
   row. Invisible at six houses because their glow is a warm amber within a few points of the
   boards; at the Midnight Show, whose glow is a deliberate mint `Color(0.40, 0.92, 0.62)`
   over brown floorboards, it drew a horizontal line across the whole stage with warm wood
   above it and cold wood below - measured, (77,54,51) to (80,74,64) between adjacent rows.
   **A saturated venue colour is the test case for every soft-edged wash in this file.**
   The grid rasterisers, all one draw_rect per art row: `fill_disc_pix` / `draw_ring_pix` /
   `draw_glow_pix` (circles), `draw_capsule_pix` (limbs), `draw_arc_pix` + `draw_spoke_pix`
   (the crowd dial's bands, ticks and needle), `draw_card_pix` (every rounded panel and bar -
   `soft_card` alone is forty-odd call sites, which makes it the highest-leverage pixel fix in
   the file). Inside a `draw_set_transform` unit space - the card illustrations, the wordmark -
   a screen-space snap means nothing: snap the transform's ORIGIN, publish `_cap_px` =
   `ART_PIXEL / k`, and use `cap_disc` / `cap_ell` / `cap_seg`.

**THE ONE MODE NOBODY HAD EVER PHOTOGRAPHED (2026-08-21), AND IT IS THE ONE HE PLAYS IN.**
`--shot` deliberately skips `apply_fullscreen()` so a capture stays at the windowed design
size, "so screenshots are comparable and a dev capture never seizes the display". Both halves
of that are right and the consequence was not: `pixeltossa_settings.cfg` says
`fullscreen=true`, so every one of the 52 screens in the sweep was a picture of a mode Louis
never sees, and the mode he does see had no capture path at all.

macOS reports that framebuffer as **2560x1606** (the menu-bar strip is excluded from a Godot
`WINDOW_MODE_FULLSCREEN`). Under the old `window/stretch/aspect="expand"` the viewport becomes
the window's own shape at the smaller ratio - `min(2560/1280, 1606/720)` = 2.0, so
**1280x803**. That number is already in this file, in `stage_center`'s note, where it was met
from the other side: "measured at 1280x803 the props flew to a line 11px below his hands". The
hand line was fixed by reading it off the painting. Nothing fixed the painting.

**803 IS ODD, AND THE ART GRID CANNOT TILE AN ODD NUMBER.** Every venue backdrop is 640x360 and
goes through `art_blit_rect`, which STRETCHES to its box: 1280 wide is an exact 2x, 803 tall is
2.231x, so 83 of the painting's 360 source rows are drawn three screen pixels tall and the
other 277 are drawn two. Measured on the Circus at tick 700: **5.17% off-grid at 1280x720,
26.59% at 1280x803**, and the damage is purely vertical - 41% of block ROWS broken against 3.6%
of block columns. The canopy's two-pixel dither, which is the whole texture of that painting,
comes apart into noise.

The fix is `aspect="keep"` plus `scale_mode="integer"`: the viewport is ALWAYS the 1280x720
design size and the window scales it by a whole number. Measured after: 5.17% at 1280x803,
5.22% at 900x600, 5.25% at 1280x720 - the shape of the window stopped mattering, which is the
actual property worth having. On this display fullscreen lands on exactly 2.0, so an art pixel
is exactly 4x4 device pixels. **The cost is stated rather than hidden: bars** (83 device px top
and bottom here, in the near-black plum clear colour, about 5% of the height each) **and a
1920x1080 screen now scales by 1 rather than 1.5**, because 1.5 would put the SCREEN-DENSITY
text of decision 2 on half pixels. If that trade is ever revisited, revisit it as a player
setting, not by loosening the lock.

Three things follow and all three are load-bearing:
- **A minimum window size is what integer scaling asks for in return.** Its floor is 1x, so a
  window below 1280x720 no longer shrinks the frame - it CROPS it, and what it crops is the
  outside edge of every screen. Measured at 900x600: viewport still 1280x720, scale still 1.0,
  corners gone. `_ready` sets `window_set_min_size` from `ART_W * ART_PIXEL`, derived, never a
  second copy of project.godot's two numbers.
- **`--capsule` IS EXEMPT AND MUST STAY EXEMPT.** It is the one run that WANTS a wrong-shaped
  window: `render_store.sh` renders six store slots at six aspect ratios and relies on the
  window size becoming the viewport, because the key art lays itself out from
  `k = min(s.x / 1280, s.y / 720)`. A locked viewport hands every slot the same 16:9 frame and
  `sips` then squashes it to the target - distortion, which that script's own header calls the
  one thing a capsule must not have. Three of its six slots (1848x696, 840x1006, 1920x620) are
  also smaller than the design size on one axis, so they need the minimum lifted too. The
  capsule screen draws vector key art and no pixel-grid chrome, so it has nothing to lose.
- **The general lesson is the one this file keeps relearning, arriving from a new direction.**
  A screen with no capture target is a screen nobody has looked at - and this time it was not a
  screen, it was a WINDOW SHAPE. `validate.sh` step 7b now runs a capture at 1280x803 and
  asserts the frame still comes back 1280x720, because a settings line is exactly the kind of
  thing that gets changed back with no picture to contradict it.
- **TO SEE THE PRESENTATION AT ALL, GRAB THE DISPLAY, NOT THE VIEWPORT.** `--shot` reads
  `get_viewport().get_texture()`, which is the 1280x720 frame - it cannot show the bars, the
  scale, or whether the upscale is clean, because none of those exist yet at that point in the
  pipeline. `screencapture -x -C out.png` after launching WITHOUT `--shot` (so the remembered
  fullscreen applies) is the only way, and the numbers it gives are worth the trouble: the
  game area measured exactly 2560x1440 inside bars of 141 and 83, and 141 - 83 = 58 is the
  NOTCH strip, not a centring error - `WINDOW_MODE_FULLSCREEN` and
  `WINDOW_MODE_EXCLUSIVE_FULLSCREEN` both report a 2560x1606 window here, so the window's own
  bars are equal and there is nothing to fix. **Measure the frame with 4x4 device blocks, not
  2x2**: at scale 2 one art pixel is 4x4 device pixels and a screen-density glyph pixel is
  2x2, so a 4x4 sweep reads HIGHER than the windowed 2x2 number (9.69% against 7.45% on the
  title) and that gap is decision 2 showing up in the measurement, not a defect.

**THE GOAL STEM'S PAINTING KEEPS TIME WITH THE GOAL LADDER, AND THE MANIFEST IS WHERE THEY
MEET (2026-08-19).** The growth cycle is 76 frames built in THREE STRETCHES, one per goal - a
leafless sprout growing a stalk and two leaves and opening ONE side flower; the SECOND side
flower; then the top bud and its bloom - and `_GROW.beats` publishes the frame index each goal
lands on, so `stem_grow_key` maps the meter's fill onto the painting piecewise instead of
dividing. **A flat index cannot hold that promise**, because the stretches are deliberately
different lengths (a sprout has more to show than a second flower does). Measured on the cycle
this replaced: the two subgoal flowers opened at fills 0.17 and 0.19 and the remaining four
fifths of the meter was one long bud - because all four of its interpolations OVERSHOT (told to
grow a seedling into a one-flowered plant, the model grows the whole plant to full height by
frame 9 and snaps back at 16), so `drop_overshoot` threw away 23 of 65 frames and every one of
them came out of the two stretches where the flowers grow.
Three things follow from that and are worth keeping:
- **A pinned last frame is a hint, not a contract.** Keep only the frames still ON the way to a
  target and take the target from the keyframe file, never from the frame that claims to be it.
- **Derive the keyframes an interpolation cannot be prompted into.** `plant_seed0` (the seedling
  with its leaf masked off) and `plant_k0b` (the plant with its flower and shoot cleared) are cut
  out of frames the model drew, which is the same rule K1/K2/K3 were already built on.
- **The second subgoal is the first one MIRRORED** (`mirror_flower`, delta only, about the stalk
  with a measured 3px/2px offset onto K2's painted flower). Its own generation came back as eight
  identical frames, a pop, and eight more - a static middle third - and the two side flowers ARE
  the same event twice, so they should look like it.

**A DRAWING CAN HAVE TWO JOBS AT TWO RESOLUTIONS, AND THE GRID IS NOT ALWAYS THE ANSWER**
(2026-08-19, `draw_flower`). One function draws the flower as an OBJECT - the bloom on the goal
stem, the flowers the crowd throws - and as a GLYPH: the currency mark inline with text at
eleven call sites, since the flower mark IS the currency unit. Converting the glyph to the art
grid measured **10.0% -> 3.7% off-grid, exactly as intended, and looked worse**: at r 6.5..9 a
petal is a 3.6 x 2.4 SCREEN-pixel ellipse, so on a 2px grid five of them round outward into one
blob and the mark becomes a berry with a yellow middle. That is not a defect in the rasteriser,
it is the mark being **smaller than the grid can describe** - and decision 2 above already
covers things that small. The mark is set at text size, on a text baseline, and reads as a
symbol; it follows text. So the flower rasterisers take a `grid` argument (the pattern
`fill_disc_pix` already had for previews) and `draw_coin_mark` passes 1.0. **Measure the number
AND look at the picture; a better number is not the goal.**
**AND WHEN A SHAPE IS TOO SMALL FOR THE GRID, THE HONEST FIX IS A BIGGER BOX, NOT A SOFTER
RASTERISER.** The goal stem lost the same argument and won it the other way: its plant lived in
a 34 x 148 slot with a 10px bud, 20 x 9 leaves and 11px subgoal heads - 5 x 8, 10 x 4 and 5 ART
pixels, where an ellipse rounds into a rounded RECTANGLE and a leaf comes out a green brick.
Nothing about the drawing was wrong; there were not enough pixels in the box for a flower to
exist in. The takings column beside it moved into the CROWD card - where it belonged anyway,
since a pile of flowers is the crowd's answer and the mood word was already documented as being
coloured in the dial's own bands - and the plant took the width. Four times the area, same
shapes, and it reads as a plant that grows.
**A LEAF IS A POINTED LENS AND A PETAL IS AN ELLIPSE, and both only start mattering on the
grid.** `fill_ellipse_pix` solves a rotated ellipse per art row instead of approximating it with
a nine-point polygon and then scanline-filling that - two approximations where one will do - and
guarantees any row the shape genuinely covers at least one art pixel, because `fill_poly_pix`
rounds a sub-pixel span DOWN to nothing (right for a flame's soot fringe, fatal for a petal).
**THE CELEBRATION HAS A CEILING AND IT IS THE CARD ABOVE.** The bloom is meant to overflow its
own box, but at full overflow it reached 57px above the stalk's tip and buried the act header -
venue name, THE ACT, and the goal dots, all gone behind a golden flower at the moment they
matter most. The stalk's box is INSET down the card so a full bloom lands just inside the card's
own top edge, and the shed-petal ring (which orbits wider than the bloom) is what actually sets
that ceiling.

**A SCRIM DARKENS A PICTURE; AN OUTLINE FOLLOWS THE LETTERS** (2026-08-19, and this is the
third time the same argument has been lost). Every screen that puts text over a PAINTING
rather than over a panel has reached for a band of darkness first - the establishing card's
marquee scrim, its bottom gradient, the victory roll's `draw_read_column` - and every one of
them fails in the same place: where the painting is lit from INSIDE. The Circus's tent
doorway is a bright arch ringed with bulbs in the lower third, exactly where the goals block
sits; the victory painting's boards carry footlights along the lip and thrown bouquets
catching them, exactly where the roll's opening lines cross. A uniform darkening cannot win
against light that is part of the picture, and turning it up far enough to try is how the
"windows of info" got there in the first place - which Louis then had deleted ("i want the
image only"). `draw_text_shout`'s 8-way outline costs nine draw_string calls, needs no
rectangle, and works wherever the text happens to be - which on a scrolling roll is every
part of the picture in turn. `draw_fit_string` and `draw_wrap_fit` take an opt-in `shout`
for the same reason. **Reach for the outline first and the scrim only for a whole block.**

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
- **A FULL-FRAME PICTURE IS ONE GENERATION NOW - THE MIRROR IS RETIRED** (2026-08-13). The old
  recipe was "generate one 320x360 half and mirror it", because `create_image_pixflux` caps a side
  at 400px. `create_image_pixen` takes **768 per side** within a 512x512 AREA budget, and
  640x360 = 230400 fits. That retired three compromises at once: the visible bilateral seam down
  the middle of five venues, the prompt contortion it forced ("the far LEFT SIDE only, nothing in
  the centre"), and the rule that asymmetric outdoor venues could not be generated at all. All
  seven backdrops and all seven exteriors are single paintings; `scripts/pixelise_paint.py`
  reduces them and `scripts/fetch_paint.sh` downloads them.
  **THE TITLE SCREEN IS THE ONE EXEMPTION, AND IT WAS LOST WHEN THE MIRROR WAS RETIRED**
  (2026-08-19, Louis: the title "is not centered: the edges of the curtain are missing and
  the bows aren't symmetric"). The retirement above is about the seven VENUES, whose problem
  was a focal seam down the middle; `ui/menu_backdrop`'s middle is deliberately an empty
  stage, which is the exemption `pixelise_menu.py`'s own `--from-half` block was written for.
  Regenerating it full-frame silently dropped that. Measured on the 2026-08-13 painting:
  **46.9% of pixels differed from their own mirror by more than 20 levels**, the swag gathers
  sat at x 26/122/253/355/565 - spans of 96, 131, 102, then a 210-wide swag drooping 20px
  lower than its neighbours - and each frame edge cut a different fraction of a different
  swag. **A proscenium is architecture, so its asymmetry is not character, it is an error**,
  and no amount of re-rolling gets a model to draw evenly spaced swags. `--mirror` on any
  source is the fix and the bake is now made with it.
  **AND THE AXIS IS NOT A FREE CHOICE: IT MUST LAND ON A SWAG'S LOW POINT.** The mirror meets
  itself carrying the source's slope at that column, so an axis on a rising arc joins the two
  halves into a sharp inverted-V spike. Louis's words point at the outer edges, so the obvious
  window is the one that lands a gather on x=0 and x=640 - and measured, that puts the axis on
  a rising arc and draws a spike dead centre, while the plain left half lands on the bottom of
  the 253..387 swag and joins invisibly. **Symmetric and smooth beat symmetric and
  edge-aligned**, and the outer swags stay part-cut on both sides, which is what a valance
  running behind a proscenium actually does.
  **THE AXIS IS NOW A DIAL, NOT A HOPE** (2026-08-20): `pixelise_menu.py --half-shift N` slides
  the half before mirroring, so a chosen column lands on the axis instead of whichever one the
  generator left at the edge. Shifting right crops plain stage and pads from column 0 - the dark
  outer edge of the curtain running off frame - which costs nothing. Re-rolling until a gather
  happens to land on x=319 is spending a generation on arithmetic.
- **THE TITLE HAS SIDE CURTAINS (2026-08-20, Louis: "regenerate the title card: i want side
  curtains").** One 320x360 pixflux LEFT HALF (forced palette, 36 colours, nothing off it),
  `--half-shift 13`, mirrored: measured **0.0% of pixels differ from their own mirror**, against
  46.9% for the full-frame painting this route replaced. The three rolls and the exact prompt are
  in `docs/pixellab_prompts.md`; two things generalise. **Saying where the picture ENDS makes it
  end there**: a bounded "to the right of that curtain the stage is OPEN and EMPTY" invited a
  matching right-hand leg and mirrored into the DIPTYCH, and an emphatic "the stage RUNS OFF THE
  RIGHT EDGE and does not end" got a curtain there anyway with two baked spotlight cones for
  company. The roll that worked mentioned the right edge once, quietly. **And the FOOTLIGHTS are
  load-bearing on this screen, not decoration**: `menu_house_light` deleted the title's cone and
  replaced it with a wash rising off them, allowed precisely because "they are real lamps in the
  picture", so a half without lamps puts the game back into the fault the cone was deleted for.
  `scripts/add_footlights.py` stamps them across from the roll that drew them properly - by
  difference from the donor's own board tone, so what moves is the lamp and not a rectangle of
  someone else's boards - and lays the row out **from the mirror axis outward**, because a pitch
  measured from the left edge leaves the centre gap wrong by up to a full pitch, dead centre,
  where the eye already is.
- **Pixen cannot force a palette, so the reducer does it** in Oklab with serpentine
  Floyd-Steinberg. **Judge whether a painting will survive that by the TAIL, not the mean**: a
  good picture and a badly broken one measured 0.028 against 0.034 mean distance, a 1.2x spread
  for a difference that is glaring, because the damage is localised. The fraction of pixels
  further than 0.05 separated them 2.9% to 26.9%. It is an ADVISORY that over-flags cold-lit
  venues (dispersed floodlights diffuse fine; a contiguous out-of-gamut sky does not) - it means
  "go and look at this one", and the fix is always the prompt, never the reducer. **The locked 48
  is a WARM theatre palette**: it has no mid-luminance teal, so ask for deep indigo skies.
- **A REDUCED TINTABLE SPRITE MUST BE BANDED, OR IT IS A BLUR (2026-08-24, Louis: everything
  has to look "sharp and pixellated").** Every gear and assist icon is a generation box-reduced
  2:1 onto a 20x20 canvas, and a box reduction is an AVERAGE - so what shipped was a continuous
  luminance ramp: measured, **84 distinct grey levels inside a 20x20 boot** and 56 inside a
  glove. At that size a ramp has nowhere to be smooth; every level is one or two pixels, so the
  icon reads as a blurred photograph of an object rather than a drawing of one.
  `install_gear_icons.py` / `install_assist_icons.py` quantise to `BANDS = 6`, which is the
  decision `make_round_props.py` already made one stage earlier ("quantised to bands, so a band
  boundary lands on an exact pixel edge"). 4-6 levels per icon after, same silhouettes.
  **AND THE SUBJECT HAS TO BE A MID-TONE, NOT A SILHOUETTE.** Re-rolling those sources, "a black
  silk top hat" and "black gloves" came back exactly as asked - and the reducer normalises every
  icon to its OWN brightest pixel, so a black object becomes a flat white blob with no interior.
  Five of eight first-batch rolls were worse than what they replaced. Name a pale material and
  both ends of the light ("pale dove-grey ... near white on the left, a clearly darker grey on
  the right") with `basic shading`, not `flat shading`.
  **AND THE GREY-LEVEL COUNT THE SCRIPT PRINTS IS THE TEST, NOT A STATISTIC (2026-08-24, adding
  `ui/stat_*` for the two stats screens).** A finished icon with **1 grey level** is a flat
  silhouette - the mid-tone rule above, failed - and the first heart came back exactly that. Naming
  a highlight, a body tone AND a shaded crease took it to 5. The same readout catches the OTHER
  failure, which is about size rather than value: a dumbbell measured **89 of 400 pixels** and was
  a correct picture of a thing too thin to read at 20px (its bar is one pixel); a kettlebell says
  "weight" in one chunky silhouette at 143. **A tinted mark needs a mid-tone subject AND a compact
  one** - both, or it is a smudge in a disc.
  **AND AT 20PX ONLY THE SILHOUETTE SURVIVES; INTERIOR DETAIL DOES NOT.** The accuracy mark took
  three rolls to learn it. A plain archery target with concentric rings reduced to a flat pale disc
  and read as a ball beside a heart and a boot - its rings are one art pixel each. Asking for
  stronger ring CONTRAST failed the same way for a second reason worth knowing: **a coloured
  generation cannot be judged by its colour contrast when the pipeline throws colour away.** The
  model drew a proper red/blue/gold archery target, and red and blue land within a few levels of
  each other in luminance, so all four rings arrived as one grey. What worked is the fix
  `day_limiter_mark`'s own note already records for the same two objects at the same size: **change
  the OUTLINE, not the middle.** Four crosshair spokes sticking out through the rim make a cross
  rather than a circle, and a cross survives at any size.
  **THE DISC IS SIZED TO THE MARK, NOT THE OTHER WAY ROUND.** These blit at exactly 20 screen px
  (manifest `scale` 0.5 x ART_PIXEL 2) and no other size is available without resampling off the
  grid, so a 34px disc leaves seven pixels of empty ring all round and the mark reads as something
  small dropped in a hole. And `art_blit` MULTIPLIES: a mid-tone tint spends the sprite's value
  range twice (the file is already a ratio floored at 0.26), which is why the two GILT emblems on
  Records and History never had the problem and the four coloured stat marks did. Lerp the tint 45%
  toward white and the mark keeps its hue and gets its highlights back. `install_stat_icons.py` supplies paths and names to
  `install_assist_icons.py`'s own reduction rather than copying it, so the two families cannot
  drift.
- **THE MENUS' GILT IS GENERATED NOW, AND THE RULE IS DRAWN (2026-08-24, Louis: use "better
  looking menus instead of the basic ones ... but don't exaggerate").** `draw_ornament` (twenty
  call sites) and `draw_frame` (eight) were the last vector strokes in the UI - `draw_line` at
  1, 2 and 3 screen px, i.e. HALF-BLOCK strokes at ART_PIXEL 2, on the thinnest objects on
  screen, which is exactly where a half pixel is the whole line. `ui/rule_flourish` and
  `ui/corner_{tl,tr,bl,br}` ride the seam with the old vectors as the fallback, and `rule_pix`
  is the one place a straight gold run is drawn. Three things generalise:
  - **GENERATE THE ORNAMENT, DRAW THE RULE.** One 256px divider fitted to twenty different
    half-widths is twenty different fractional resamples. Only the ornamented CENTRE is a
    sprite; the plain gold runs out to the caller's width in whole blocks, and the crop is
    centred on the RULE (source rows 11-12) so the flank joins it invisibly.
  - **FILIGREE DOES NOT SURVIVE A REDUCTION.** Reducing the crop 2:1 was tried first and gave
    gold speckle around a lozenge - scrollwork IS small-detail-on-a-thin-field, the case
    `clean_ground.py` already warns is the picture rather than the noise. Author at 1:1 art
    density and palette-snap with no box filter.
  - **AN ORNAMENT DRAWN THROUGH A TINT IS A LUMINANCE RATIO**, because three call sites are not
    gold (lavender on the unlock banner, a fading amber on the demo wall card). `ui/crown` is
    the stated exception: one colour, one state, and its red jewels are the whole difference
    between a crown and a gold sawtooth. **And a shaded ornament needs more alpha than a flat
    rule** - `draw_frame` asks 0.5 and blits its scrolls at 1.7x that, the same PRESENCE rather
    than the same number.
  `art_span` is new and deliberately narrow: it answers "how big would this blit be" ONLY for
  the two callers that must lay out around a sprite. Everything else states its box and lets
  `art_blit_size` fit the texture to it, which is what keeps layout out of the art's hands.
- **"A PAINTED CLOTH" IS THE PROMPT THAT BUYS AN EMPTY CENTRE (2026-08-24,** repainting
  `bg/small_theatre`, which was a closed curtain and a plank floor - the flattest picture in the
  game, on the third venue of six). Five rolls: gilded pilasters gave the documented DIPTYCH, and
  three separate rolls put a curtain leg or a tree dead centre INCLUDING one that said "nothing at
  all stands in the centre of the picture". Forbidding it does not work; it never has. What worked
  is the camera fix `clear_spine.py` already prescribes, stated as a noun: a BACKCLOTH is by
  definition one flat sheet, so there is no depth to put an object into, and the interest moves to
  the two ends of the cloth and along its bottom - which is where a scene painter puts it anyway.
  Source gamut 0.019, floor 0.000, spine 0.834. **The floor band came back on the documented line
  (art y 289 against the old 289..360), so `stand` stays 0.85 and the room measures 32.7 behind
  the performer against 32.9 before** - so the veil re-measure `venue_data` demands after a repaint
  was done rather than assumed, and 0.42 is still right.
  **AND A MEASUREMENT IS ONLY AS GOOD AS ITS BOX.** The moon in that painting was "measured" at
  150.7 against a prop's 131.3 and dimmed for it; the sample box had a BALL in its corner. The
  moon was 100 all along, comfortably under the props' 150-235, and the dim was reverted. Sample
  a backdrop where nothing is flying, or the thing you are measuring against is inside the reading.
- **THE PAINTING IS THE FLOOR, AND EVERY ROOM PUTS IT SOMEWHERE ELSE** (2026-08-14, Louis:
  "he's often floating or not standing on the right place or there is no floor at all"). The
  standing line is per-venue DATA - `venue_data`'s `stand`, read by `stage_floor_y`, which
  every single thing on the stage now hangs off (hand line, shoulders, shadow, light lip,
  footlights, where a dropped prop lands). Three things this cost, each paid for:
  - **A painted floor is a BAND in perspective, not a line, and he stands INSIDE it.** The
    session before measured "the strongest horizontal edge" and put his feet on it - that is
    the floor's BACK edge, where it meets the wall, so he stood on the Circus's ring wall, on
    the World Arena's perimeter wall and on the Small Theatre's curtain hem with the whole
    floor unused in front of him.
  - **Move the man, not the picture.** `recentre_ext.py --lift` slid each painting up to meet
    him; it is RETIRED. A lift throws away rows off the top, invents rows at the bottom, and is
    silently lost the next time a backdrop is regenerated - two of the seven were regenerated
    the following day. One float per venue is reversible and re-measurable in a second.
  - **The Backyard and the Midnight Show had no floor at all** and were regenerated: the old
    Backyard was a close-up of a house wall and the Midnight Show was drapes and tables above
    pure black, both of them legal under the old prompt rule that the bottom 20% was covered.
- **Three framing rules a backdrop prompt must carry**, all measured off `draw_backdrop`: the
  bottom third IS a real standable floor running edge to edge (this REPLACES "the bottom 20% is
  covered by the stage floor, so nothing essential lives there", which is what produced the two
  floorless venues); its back edge wants to be up around art y 260-290 so `stand` can land
  partway down it; and the performer stands dead centre, so the centre column wants to be
  empty. An EXTERIOR has its own: the establishing card puts its title across the top centre
  and two panels in the bottom corners, so the hero fills the lower two thirds.
- **`stand` IS NOT A FREE PARAMETER: THE THROW ARC SETS A MINIMUM FLOOR DEPTH** (2026-08-15,
  `scripts/reband_backdrop.py`). The architecture says a painting puts its floor where it likes
  and `stand` follows, and that is true about the picture and false about the game. The hand
  line hangs off the standing line, so raising him raises every throw with him. A full-hold 1.4
  throw peaks `BASE_AIR * 1.4 * ARC_PER_AIR` = 253px above the hand. Measured on the Midnight
  Show repaint, whose stage band ended at art y 250 and so wanted `stand` 0.645: that apex went
  from screen y 85 (on screen at 0.83) to **y -48**, and a High Toss to y -121. Holding the
  throw key is not an edge case and the player has to TRACK a prop to catch it. **Reband the
  painting to fit the game, not the other way round.** `reband_backdrop.py` rescales a
  painting's horizontal bands: stretch is free on VERTICAL detail (hung drapes along their
  folds), mild on HORIZONTAL detail (floorboards, which perspective foreshortens anyway), and
  forbidden on OBJECTS - move foreground furniture at 1:1 and crop it at the frame edge
  instead, because a chair squashed to 0.55 is a chair that is wrong.
- **A VENUE'S `veil` BELONGS TO ITS PAINTING, SO A REPAINT HAS TO RE-MEASURE IT.** The Midnight
  Show's 0.10 looked like a design choice and was a fact about the old art: drapes and tables
  over near-black, which the standard 0.42 erased. The 2026-08-15 repaint had a warm oak stage,
  and 0.10 left it at luminance 85 against the old set's 45 and the Circus's 64 - making the
  darkest room in the game the brightest, which cancels the reason the room exists (a vanishing
  suit and a phosphor vest have nothing to vanish into on lit boards, so the Glow Kit stops
  being worth wearing). It is the one number in `venue_data` that is about the art rather than
  the design. 0.40 put it back at ~62.
  **...EXCEPT AT THE MIDNIGHT SHOW, WHERE IT IS NOW INERT, AND THAT IS WORTH KNOWING BEFORE
  SOMEONE TUNES IT (2026-08-20).** `full_dark_stage()` lays a near-black rect over the FINISHED
  backdrop at alpha **0.72**, and the Midnight Show is permanently inside it - so that room is
  darkened twice and the second pass dominates. Measured on the 2026-08-20 repaint, sweeping
  the veil across 0.40 / 0.30 / 0.20 / 0.12 moved the room behind the performer by **0.5 of a
  level out of 255** (6.4 to 6.9). The veil is not what makes this house dark and cannot be
  what fixes it.
  **AND THE 0.72 HAS TO STAY, because the prop levels now depend on it.** With
  `DARK_DIM_AIR` at 0.09 a flying ball reads about 15, so the room has to sit near 6 for it to
  separate at all. Raising the house to where its own drapes and gold hem are comfortably
  visible (12-16) would erase the props instead - the two numbers are one setting seen from
  two ends, and the room being near-black is what buys the prop its 2.5x.
- **A BACKDROP MAY HAVE A CENTRE PROBLEM `spine_busyness` CANNOT SEE.** It measures how much
  more TEXTURED the spine band is than the rest, and read 1.15 - inside the normal range - for
  a Midnight Show whose middle held a supper table and two seated diners the performer stood
  on top of. A table painted in the drapes' own tones is no busier than drapes. **What makes
  something wrong behind the performer is that it is an OBJECT, not that it is noisy**, and no
  texture statistic sees that. Look at the centre column; do not trust the number.
  `scripts/clear_spine.py` clones empty room over it when a re-roll will not behave, and its
  donor test is semantic (no chair-red, no candle-bright) rather than statistical - a donor
  picked on deviation alone brought a chair into the middle of the room without its table.
- **THE MODEL WRITES FAKE HANDWRITING ON A PLAIN FLOOR.** Asked for texture on a large flat
  surface it paints illegible cursive across it - two independent Backyard rolls, and saying
  "no writing, no letters" only traded it for a tree dead centre. Invisible in a 640x360
  thumbnail, unmistakable at 2x. `scripts/clean_ground.py` removes it (median filter, flatness
  measured on the MEDIAN so the writing cannot hide the test from itself), and it is a repair
  you reach for after looking, **never a sweep**: on a cobbled street or a mown pitch that same
  small-detail-on-a-smooth-field IS the picture, and it would scrub 12-19% of it.
- **A BACKDROP'S FLOOR NEEDS ITS OWN GAMUT READING** (2026-08-19, re-rolling three venues).
  The floor is one large evenly lit area of one continuous tone and the biggest surface in the
  picture, so a tone that sits between palette entries has no least-wrong neighbour and error
  diffusion sprays a regular 2px CHECKERBOARD across the thing the performer is standing on -
  invisible in a 640x360 thumbnail, unmistakable at 2x. **The whole-frame number hides it**, the
  same way the mean hid the teal sky: two rolls scoring an unremarkable 0.066 and 0.144 overall
  measured 0.087 and 0.198 over `img[280:]` alone. `pixelise_paint.py` now prints `floor` beside
  `gamut` and `spine`. The fix is at the prompt and has two halves - the anti-dither clause
  ("few colours, flat areas of solid colour, no dithering, no speckle, no noise") AND the tone
  ("dim ochre brown and dark umber, falling away into shadow toward the front"), which took the
  Circus's sawdust to 0.003. Steer the texture alone and a bright polished wood floor still
  scores 0.198; over-steer the tone and you get a flat grey hall that no number complains about
  and nobody wants to look at.
- **PUT THE FURNITURE SOMEWHERE, DO NOT ONLY FORBID IT** (2026-08-19). "No tent pole, no mast, no
  post, no column" produced a rigging pole six pixels wide at art x 317, ending exactly at the
  performer's hairline. Naming where a thing SHOULD go works where forbidding it does not (crowd
  "on the far left and the far right" landed first time, every time), but asking for the poles at
  the edges just moved one to x 290 and made it thicker. What cleared the centre was changing the
  CAMERA so the middle distance is a flat surface - a plain drawn curtain running across it. A
  flat surface has nowhere to hang anything. **And do not try to paint the pole out**: both of
  `clear_spine.py`'s repairs were tried and both are worse than the fault - a cloned donor strip
  duplicates the light-string bulbs inside it, and the new `--rows` ramp smears every stripe
  boundary it crosses. `clear_spine.py` grew `--mirror-first` (a donor is only geometrically
  valid on a picture with perspective if it is the reflection of what it replaces) and `--rows`
  (a thin object over a smooth field needs no donor, just a ramp across it, over the rows it
  actually shows in) - both are right for the cases named in their own docstrings and neither is
  right for a striped tent.
- **Props are derived**: `--propref <name>` renders one prop isolated at x6 through the real
  drawing code, and `scripts/pixelise_prop.py` reduces it (premultiply before filtering, hard
  alpha threshold, Oklab palette snap). What comes out is the game's real silhouette, not a
  model's idea of a juggling club.
- **A PROP MAY NOT SNAP INTO THE PALETTE'S COOL CORNER** (2026-08-15, `scripts/install_prop_cards.py`
  and mirrored in `derive_stage_props.py`). The locked 48 is a warm palette whose DARKEST
  entries are cool - `#1f1a2e` is an indigo sitting one Oklab step from `#241a14`, and there is
  no warm mid-dark neutral grey at all. That is right for the backdrops (the Backyard, Street
  Corner and World Arena skies are 15-19% indigo) and wrong for anything small: every generated
  object has a dark rim, and a near-black rim's nearest entry is that indigo. Measured, the
  chainsaw was **33% indigo plus 4% lavender** and the torch body **52% indigo** - the whole
  outline, on a sprite whose rim is a third of its area, which is why the chainsaw read as
  purple in flight and the torch as a cold grey stick. `warm_palette()` drops any entry where
  blue OR green leads red by more than 6 (35 of 48 survive) before the nearest-colour search.
  **Both halves of that test are load-bearing**: excluding only blue sent the same rim pixels
  to `#283028`/`#141a17` instead and the knife's blade groove came out TEAL - a lateral move,
  and one this game notices twice over. The `--warm` restriction belongs in every prop-side
  snap and in NO backdrop-side one.
- **`prop_big/*` IS THE SOURCE AND THE TORCH'S FLAME IS PART OF IT.** `big_torch.png` is the
  canonical card; `strip_torch_flame` finds the fire by colour, writes `big_torch_body.png`, and
  MEASURES the hole to publish `_TORCH`. Writing the body file directly is worse than useless -
  the next derive silently regenerates it from the old card and the repaint vanishes with no
  error. **`_TORCH` must be copied from `Assets/Props/torch_flame.json` into
  `Resources/art_manifest.json` by hand after any torch re-derive**; nothing syncs them, and a
  stale block draws the flame off the end of the handle.
- **The model will not paint an unlit torch** - three prompts saying unlit / no flame / no fire,
  all three burning. Same family as the fake handwriting. That turns out to be fine (see above),
  but it also paints a cloth wick the strip cannot catch, and at 11px across that wick reads as
  a small owl's face sitting on the pole. `install_prop_cards.py`'s `drop=(lo, hi)` splices the
  band out and closes the picture over it.
- **`strip_torch_flame` IS PIXEL-WISE, AND THE FLAME MEASUREMENT IS A FOOTPRINT, NOT A PLUME**
  (2026-08-15). Both were forced by the shipped torch design - a club-shaped body, a thin brass
  band, then a small BLACK CYLINDER with the fire burning around it (Louis's spec). Two things
  break on that shape: a ROW-WISE strip that takes whole majority-fire rows stops dead at the
  top of the cylinder (a dark 8px wick beside 6px of fire is only 25-43% warm), leaving the
  flanking fire baked into the sprite under the live one - the exact thing the function exists
  to prevent. And fire is TWO colours: the orange test misses the white-hot core (255,240,204),
  which survived as white specks stuck to the wick. So fire is found by colour anywhere in a
  band contiguous from the top, orphans left floating are swept, and the tests are `r>200 &
  r>b+100` OR near-white - tighter than the row rule needed, because a pixel-wise rule has to
  separate flame from the brass band and the crimson body. **And `half_width` is capped at
  `height/4`**: the measurement is how far the painted fire reaches sideways, which on a
  wrap-around design is the width of the WRAP, while the game draws one tapering plume of that
  width. Uncapped it came back 29x10, an aspect of 2.9 against the vector reference's 5.0, and
  the shop card showed an orange kite.
- **THE KNIFE AND THE CHAINSAW ARE A `props` VARIANT SET** (2026-08-15, Louis: "give some other
  options ... but keep the current designs for when i want to switch back"). Three options -
  `default` (plain throwing knife, crimson-and-gold saw), `reserve` (what shipped before),
  `ornate` (gilded knife, antique saw) - on the F9 panel and on `--variant props:<key>`. The
  previous art lives on as `Assets/Props/*_reserve.png`, because "switch back" has to survive a
  regeneration, and `derive_stage_props.py --suffix _reserve` reduces a variant through the
  SAME path (premultiply, alpha cut, warm snap, serration, `STAGE_H`) so a variant is a
  different look and never a different object.
  **WHICH ONE IS DEFAULT WAS DECIDED AT STAGE SIZE, NOT ON THE CARD.** On the 36x88 card the
  gilded knife is much the prettier picture; reduced to the 14x62 the player actually sees in
  the air, its curved blade reads as a smear and its ornate guard as six pixels of unrelated
  gold, while the plain one keeps a bold blade, a solid collar and a legible grip. **A prop is
  judged at the size it is thrown, not the size it is sold** - the same lesson as the club's
  three-pixel handle.
- **THE CLUB AND THE TORCH CARRY THE KNIFE'S HANDLE - ITS PIXELS, NOT A LIKENESS OF THEM**
  (2026-08-15, `scripts/reshape_shaft_props.py`). Louis, over three passes: "use the handle of
  the knive for the torch and club", then "the handles are way too thick", then "the knive
  handle is great and the torch and club handle need that same love". **This overrides the
  earlier "white handle for the club"** - one handle for three props cannot also be per-prop
  colours, and asked to choose he chose the knife's. `handle_rows()` lifts rows 50..84 of
  `big_knife.png` as RGB; the club is a straight transplant (verified pixel-identical, offset
  5px) and the torch is those rows stretched, so neither can leave the palette the knife is
  already in.
  **THE INTERMEDIATE PASS IS THE INSTRUCTIVE ONE, AND IT IS WHY THE RULE IS "COPY IT".** Told
  the handles were too thick, it measured them - club collar 12/14/14/12, grip 8, pommel
  10/10/10/8/4, identical to the knife to the pixel - concluded the complaint was about VALUE
  (a pale grip advances and reads fat), and shipped the knife's contrast through a bone ramp.
  The reasoning was right and the result was still wrong, because a cream grip beside a leather
  one is a different object however well its contrast is calibrated. **When the ask is "the
  exact same thing", a better-calibrated derivation is not a smaller version of the answer; it
  is a different answer.** Only the torch was ever genuinely fatter (collar 18, cone 15->9).
  **A SYMMETRIC ROUNDING CANNOT MAKE A SMOOTH TAPER.** The torch's cone runs 8px at the foot to
  12 at the shoulder ("let the diameter grow 50% over the entire length ... make sure this
  looks like a smooth line"). Rounding a half-width about a centre moves BOTH edges on the same
  row, by symmetry, whatever phase the centre has - measured, that gave 12px for nine rows,
  11px for ONE, then 10px for twenty-five: a stack of cylinders. Round the TOTAL width (a
  linear ramp rounded gives even runs) and hand each extra pixel to a different side, and the
  silhouette grows one pixel at a time, alternating: 13-row runs, left stepping at rows 60/86
  and right at 47/73.
  **A TILE MUST BE THE UNIT THE PATTERN IS BUILT ON.** The torch's handle is 53 rows and the
  knife's is 35, so the grip repeats - and repeating rows 55..79 whole leaves a twelve-row
  plain stretch across the seam in a grip whose wraps come every six. Tile the six-row unit
  instead (four plain rows, a two-row dark wrap): lead 54..61, unit 62..67 five times, tail
  74..79, plus 4 collar and 5 cap = 53 exactly, no seam. The wrap bands are the load-bearing
  feature - they still read as "wrapped" at the 14px the stage sprite gets, where a smooth
  cylinder is just a stick.
  **Nearest-neighbour sampling is right here and was wrong before.** Stretching to a width that
  changes every row repeats different source columns on adjacent rows and shreds the bands into
  blobs, which is why the previous pass interpolated. The width is now piecewise CONSTANT for
  thirteen rows at a stretch, so every row in a run maps identically. Interpolating would
  instead invent colours between palette entries, which a locked palette cannot take.
  The collar and cap keep their excess over the grip in ABSOLUTE pixels (+4/+6/+6/+4 and
  +2/+2/+2/0/-4), not as a ratio: scaled proportionally the collar would be 21px over a 12px
  cone, and a ring wider than everything it joins reads as a TRAY with a wick standing on it
  (learned once already at 18px over a 16px wick). Absolute excess also makes the torch's foot
  the knife's pommel to the pixel, since the cone is 8 there.
  The torch's geometry came from a REFERENCE Louis supplied (`torch_image.html`, a saved image
  search for the Henrys nite flight torch): a juggling torch's coloured section is only modestly
  wider than its shaft - a sleeve on a tube, not a teardrop - and there is a bright metal collar
  between that sleeve and the wick.
  **AND ITS HEAD IS A GENERATION, ITS SHAFT IS NOT** (2026-08-15, Louis: "ask pixellab to just
  create a juggling torch"). Eleven were generated and **none of them survived the pipeline**,
  which is the "judged at the size it is thrown" rule paying for itself a third time: as
  illustrations several beat the shipped torch, as props all eleven were worse. Bare "a juggling
  torch" reads to the model as a THEME rather than an object - one candidate came back a whole
  juggler, another a bonfire hung with baubles. The three that were real torches each broke at
  stage size: a cream wick bundle survived `strip_torch_flame` as a crown of gold spikes (the
  owl again), one flame measured 49px on a 78px sprite and ate half the prop, and two drew fire
  as a HOLLOW OUTLINE so the strip found 1px and baked the flame in under the live one.
  **WHAT SHIPPED IS `pro0` VERBATIM** (Louis: "i want EXACTLY pro0 ... take the same handle as
  in the png, not the one overlaid on top of it which is the same as the knives"). Its own
  shaft, its own ferrule, its own wick; `TORCH_HEAD_SRC` names the painting and the previous
  designs are kept as `big_torch_s11.png` / `torch_s11.png` and at commit `3930e10`.
  **TWO PASSES REPLACED THE GENERATED SHAFT AND ONLY THE FIRST ONE NEEDED TO.** The rule "a
  generated shaft never survives the reduction" was learned on s11, whose pole is 5px and
  reduces to 4 - thinner than the knife's blade. pro0's shaft is already 8, the knife grip's
  own width, so the rule does not bite on it. **A rule learned from one example needs its
  precondition written down with it** ("check the shaft's width"), or it gets applied to the
  next painting on authority rather than on measurement.
  **A BOUND WICK IS THE SAME COLOUR AS FIRE, AND THAT IS WHY THE OWL KEPT COMING BACK.**
  `strip_torch_flame` used to find fire by threshold - `r > 200` plus 100 points of red over
  blue - and pro0's wick cream `#f2cc8c` and tan `#d8a068` both pass it, so the band ran down
  through the wick and the strip ate it: card base_row 41 instead of 33, row 33 down from 13
  pixels to 4. Darkening the wick's top three rows fixed the CARD and not the stage sprite,
  because **the two sizes are measured INDEPENDENTLY and the 86->78 reduction averages each
  output row from more than one input row** - cream bled up out of the fourth row, the band
  re-formed, and the stage strip cleared the highlights anyway. A colour excluded by a
  threshold cannot be excluded at one scale only.
  **THE FIX IS THAT A LOCKED PALETTE LETS FIRE BE NAMED, NOT DESCRIBED.** Both sizes snap to
  the same 48 entries, so the strip now tests exact membership of the flame's four (plus the
  two near-whites of its core) instead of a threshold. That is strictly stronger than what it
  replaces - it already rejects the brass band and the crimson body the threshold was widened
  to exclude - and it cannot be fooled by a warm object simply being bright.
  Its precondition is that the fire is a clean region of those entries, which pro0's is not:
  it outlines its flame in the same near-blacks as its shaft's edge, and no colour test can
  separate "the line around the flame" from "the line down the handle". **Position can** -
  above the wick every pixel is fire or fire's outline, and across the wick the fire is
  everything OUTSIDE the wick's central run - so `build_torch` folds that outline into the
  flame's own deepest orange before the strip ever runs. Nothing a player sees changes; the
  whole region is deleted before anything is drawn.
  **The wordmark has to be rebaked after any of this**, since its A is two clubs and its T a
  knife, and `mark_prop` blits `prop_big/*` rather than drawing them.
- **LONGER IS NOT BIGGER, AND THE DERIVATION IS WHAT KEEPS THEM APART** (2026-08-15, Louis: "make
  the juggling club just a tiny bit longer on both the handle and the upper part"). The stage
  width comes from the card's ASPECT at a fixed `STAGE_H`, so the card's height and `STAGE_H`
  have to move together: 23x77 at 64 and 23x88 at 73 both derive to 19 wide. Bump only
  `STAGE_H` and the club is squashed; bump only the card and it is fatter. The previous pair is
  kept on disk as `big_club_short.png` / `club_short.png` (Louis: "save the original tho"), and
  `build_club()` READS the short card rather than the live one - reading its own output would
  be idempotent exactly once and lengthen the club again on every run after that, the same trap
  `STAGE_H` is a written-down table to avoid.
  **A PIVOT IS A FRACTION, SO CHANGING A PROP'S LENGTH MOVES IT.** `prop/club`'s pivot went
  0.558 -> 0.545, which is not a tuning number: it is the same FEATURE, a quarter of the way
  into the handle's collar, re-expressed against a longer sprite. Leave it and the club spins
  about a point that is no longer its balance.
  **The two halves grow by different mechanisms because they are different things.** The handle
  grows by exactly one six-row wrap period - the smallest step that keeps the knife's rhythm,
  and the only step that does. The body is a painting, so it is stretched by duplicating rows,
  and only BELOW its two gold bands: each band is one pixel tall, and a resample that lands on
  one turns a pinstripe into a stripe. Copy the dome and the bands verbatim; stretch only the
  plain taper under them, where a duplicated row cannot be seen.
- **THE FLAME BAND IS FOUND BY ONE TEST AND CLEARED BY TWO.** (The specific collision below is
  gone now that the grip is leather and owns no near-whites, but the rule stands: the strip is
  the only thing standing between a repaint and a baked flame under the live one.) Once the
  props shared a bone grip, `#fff0cc` was both the flame's white-hot core and the grip's lit
  column - the same
  palette entry, so no colour test can separate them. Position can: `orange` alone defines the
  band (and must reject the crimson sleeve, whose own highlight `#cc383d` sailed through a
  bare `r>200 & r>b+100` and dragged the band 42 rows down a 78-row sprite), then near-white is
  cleared only INSIDE that band, where it can only be fire. **And debris is swept by SIZE, not
  by support**: the first version deleted everything in the band not connected downward, which
  is exactly what a fire burning all the way around a wick disconnects - the stage torch came
  back with its top 26 rows empty and the flame drawn over nothing. A soot fringe is 1-3
  pixels; the charred wick is a block of fifty.
- **A REPAINT AND A RE-SNAP MUST NEVER TARGET THE SAME FILE.** `install_prop_cards.py` builds
  both into one dict keyed by filename and the re-snap loop runs second, so the moment the
  knife and chainsaw gained repaints their stale `RESNAP` entries read the OLD file off disk
  and silently overwrote the new art with it - the report said "repaint knife -> ink 14x82"
  and the file on disk came out 18x79, the old design, with every line claiming success. The
  exclusion is derived from `REPAINTS` now rather than trusting two lists to be edited together.
- **THE PERFORMER IS THE SHOWMAN**, a PixelLab-generated ringmaster - Louis reversed the
  never-generate rule on 2026-08-06 and then picked him over the traced figure and two other
  designs. He lives in the base manifest (`Assets/Characters/showman/`) with landmark geometry
  in `_FIGURE` and his arm bank in `_ARMS`. The traced figure survives only as the seam's
  procedural fallback, which is what makes the manifest architecture work and is not a look
  anyone chooses.
- **THE ANIMATION IS INDEXED BY THE HANDS, NOT BY A CLOCK.** This is the whole reconciliation
  between painted animation and physics: a loop on a timer drifts against the player's throws
  within seconds, because the PLAYER decides when a throw happens. `fig_arm_pick` reads the
  sim's own `hpos` and looks up the arm whose reach is nearest, so there is no phase to keep
  in sync. **`draw_arm` is not called at all while a bank is live.**
- **THE PERFORMER IS A BODY AND TWO ARMS, NOT A STRIP OF WHOLE FRAMES** (2026-08-07). Whole-body
  frames could only ever be right about ONE hand - a cascade's hands are in ANTIPHASE while a
  generated strip is symmetric - so whichever hand lost the argument had its prop drawn ~35px
  out in open air. `scripts/build_arm_bank.py` takes every generated frame apart into a body
  that never moves and two arm layers that do (`scripts/armlib.py`), and the game picks each
  arm from its own hand. Sixteen source frames stop being sixteen poses and become sixteen
  squared, and the banks POOL ACROSS GENERATIONS, so the reach table is dense (27 entries over
  30..61 art px) rather than seven frames bunched at one reach.
  - **THE LIVE GENERATOR IS `scripts/build_arm_rig.py`, NOT `build_arm_bank.py`** (rewritten
    2026-08-12). The pooled-generations pipeline below is history: the bank now comes from ONE
    source frame (`showman/source.png`), cut along the arm's own measured medial line into two
    rigid bones that are rotated per pose by a two-bone IK solve. Same output schema, so
    `fig_arm_pick` never knew. The three rules that keep it honest, each one paid for by a
    version that shipped broken:
    - **THE CORRIDOR THAT CLAIMS THE ARM MUST MATCH THE LIMB'S MEASURED THICKNESS** (12 art px
      here, so `ARM_HALF_W` is 6-7.5 along the bone). The version this replaced had grown its
      radius 6 -> 13 -> 16 chasing a "residual coat wedge" at the shoulder, and at 16 it was
      cutting out a wedge of CHEST: rotating that shredded the shoulders and left a measured
      23 art px hole of background between torso and sleeve. The leftover it was chasing is the
      coat's puffed epaulette, which is torso, is supposed to stay behind, and is load-bearing -
      it caps the joint at every angle, which is why `SHOULDER_INSET` pins the shoulder UNDER
      it rather than on the silhouette edge. **Widening the corridor to swallow a leftover runs
      the fix backwards.**
    - **BOTH BONES ROTATE.** Freezing the upper arm at a rest angle leaves the hand on a circle
      about a fixed elbow - reach 22..52 art px, where `inner_pos`/`outer_pos` alone want 27..50
      and the columns lanes want wider. Louis's "keep the shoulder fixed" is about the JOINT not
      sliding around the body, which a two-bone solve honours: the shoulder POSITION is pinned,
      only the angles move. Sweep is now 20..55 art px.
    - **THE END EFFECTOR IS THE HAND BLOB.** Solve to the fitted axis's end instead and the real
      hand swings around it as the forearm turns - 11.1 art px of spread in the published `py`,
      against a `FIG_PALM_MAX` guard of 7. Drive the IK from the skin blob.
    - **A FRAME-AT-A-TIME CHECK CANNOT SEE A BAD ANIMATION, AND THIS IS THE LESSON OF THE WHOLE
      SAGA.** The bank is a table the game steps along as the hand moves, so ADJACENT ENTRIES ARE
      ANIMATION FRAMES. The first two-bone version chose its elbow branch with a world-space
      score, and the winner of that score FLIPPED at reach 38 - dead in the middle of the range
      the game uses - so the elbow teleported 30 art px and the upper arm swung 246 degrees
      between two neighbouring entries. Every entry passed `check_connected`, every entry looked
      right on its own, and Louis's verdict on the result was "the motion is completely
      unnatural". `check_smooth` measures the worst STEP (a pop) and the total TRAVEL (a
      windmill) along the sweep; both have shipped broken. **The branch must be a fixed property
      of the side (`sign * (-uy, ux)`), never a comparison that something can win.**
    - **THE HAND CARRY DIPS; IT DOES NOT LIFT** (and this is worth stating because Louis once
      asked for the opposite in as many words - "make sure that the hands come back above the
      path they took to go inwards"). Lifting the inward hand brings it CLOSER to its own
      shoulder, folds the chain tighter and swings the upper arm HARDER: lift 4 = 81 deg of
      swing, flat = 77, dip = far less. A cascade's hands really do carry down and in.
    - **THE DIP AND THE HAND-LINE DROP ARE ONE SETTING IN TWO PARTS** (`HAND_CARRY_DIP` +
      `HAND_DROP_FRAC`, mirrored in Game.gd by `HAND_IN_DIP`). Both push the hand away from the
      joint and the arm is a fixed 40 art px, so tuning either alone overshoots: drop 0.62 with
      dip 20 puts the inner hand 45 px out, the solve clamps, and half the sweep comes back a
      DEAD STRAIGHT STICK - a worse read than the right angle it was fixing. **What the pair is
      really for is holding the hand a NEAR-CONSTANT distance from its own shoulder across the
      carry**; do that and the arm swings as one nearly rigid unit, which gives the slight even
      bend and the smallest elbow travel at the same time. Measured at drop 0.62: dip 10 = bend
      wandering 123..159 deg / elbow 9.8 px; **dip 13 = bend a steady 142..147 / elbow 13.9 px /
      shoulder 39.8 deg (chosen)**; dip 16 clamps straight over the inner third. For scale, the
      version Louis rejected ran elbow travel 43 px and shoulder swing 137 deg.
    - **THE ELBOW POINTS OUTBOARD** (`sign * (uy, -ux)`), away from the ribs. The other branch
      tucks it in behind the forearm and reads as an angular chicken wing at this size. A/B'd on
      the figure, not reasoned about.
    - **RAISING THE JOINT OFF THE MEDIAL AXIS DOES NOT STRAIGHTEN THE ARM**, though it looks like
      it must. Both bones are cut BETWEEN the joint and the hand, so moving the joint lengthens
      the arm by as much as it adds distance, and Pythagoras means the length wins: rise 0 -> 119
      deg, rise 10 -> 114, while connectivity collapsed 3.7% -> 45% as the corridor started
      eating coat above the real arm.
    - **THE SOURCE POSE HAS A HOLE IN EACH ARMPIT AND IT MUST BE PAINTED** (`seal_sockets`,
      ~40 px). The generator drew the arms straight out sideways, which leaves a genuine V of
      BACKGROUND under each arm - measured, transparent source pixels at x 54..57, y 44..47. The
      horizontal arm hid it; swing the arm down to juggle and it opens between coat and sleeve,
      which is Louis's "the shoulders aren't connected to the arms". Every cut-out rig has to
      paint what its source pose hid: a local morphological CLOSE around the joint, coloured from
      the nearest existing body pixel so the fabric is the coat's own, windowed so it can never
      reshape the silhouette anywhere else.
    - **A PROBE THAT STARTS INSIDE THE TORSO PROVES NOTHING.** check_connected originally walked
      from the joint, which is pinned INSIDE the coat, so it crossed opaque fabric the whole way
      and reported 0.0% while the armpit gaped. It starts at the socket rim now.
    - **`hand_py` IS THE CATCH LINE, NOT A MEDIAN OVER THE SWEEP.** `stage_center` places the
      whole figure so that row lands on the game's hand line, and that line is `outer_pos` - the
      level one. Now that the carry dips 20 art px, a median would sit half a dip low, drawing
      the man 10 art px down at exactly the moment a catch is judged.
  - **An arm layer is the LIMB THE HAND IS ON, and nothing else** (2026-08-08). Two earlier
    rules are both wrong and both are recorded because each looks right. "The whole half of the
    arm band" puts half a TORSO in every layer, and since the two arms are chosen
    independently the man wears one frame's lapel on the left and another's on the right.
    "Only the pixels that DIFFER from the body" is right in principle and was implemented with
    a BYTEWISE test - and the body is a median, so a coat pixel one palette step off counted as
    arm: 61% of every layer was still torso, and the shirt, bow tie and frogging changed as his
    hands moved. That is what Louis saw as "the left and right side don't match". The test is
    perceptual now (`DIFF_MIN`, Oklab), the layer is grown from the HAND, thinned by a 2x2
    erosion so the coat's piping cannot ride along at the shoulder, and dropped entirely if it
    does not reach the shoulder (`SHOULDER_SLACK`) - a forearm floating in open air is worse
    than no arm.
  - **A PALM IS A HAND, NOT AN EXTREMITY** (2026-08-08, and this one poisoned three other
    numbers). `armlib.palms` called a palm "the moving pixel furthest from the centreline",
    which is the hand only while the arm is straight; fold the elbow and it is the ELBOW.
    Measured over 624 candidates: a median of 25 art px - FIFTY screen px - from the real hand.
    `armlib.hands` finds the outermost blob of his own SKIN instead, which cannot be an elbow.
    Everything hangs off this: held props, the catch glow, the charge gauge, the tutorial keys.
    - **It is why `HAND_IN_LIFT` was 42 and is now 0.** That lift was added to raise the game's
      inner hand slot to a palm the fitter believed sat 63.5% up the figure. Measured from the
      hands: 47.8% at inner reach, 48-53% across the whole 0..44 range. There was no lift in
      the painting to meet, and every held object was drawn 42px above the hand holding it.
    - **`skin_colours` is the face MINUS the costume.** Every colour above the neck is 22
      entries covering hair, outline, collar and lapels; a mask built from that lights up
      3,210 px of torso as one blob and no hand can be found inside it. Subtracting everything
      painted below the arm band leaves the skin ramp, filtered by `SKIN_MIN_SHARE`.
  - **(SUPERSEDED 2026-08-12 - the hand line DIPS now, see `HAND_IN_DIP` above. The reasoning
    below is still why a bank may not invent a hand height the game does not share.)**
    **The bank's hand line is FLAT, because the GAME's is.** `outer_pos` sits at
    `stage_center().y` at every reach. Letting the far buckets follow the art (a ramp to +0.20
    by reach 66) describes the poses honestly and is still wrong: `fig_hand_pos`'s
    `FIG_PALM_MAX` guard then refuses those palms, the prop snaps back to the simulated hand,
    and the player sees a raised arm with its ball low and left - which reads as a severed
    forearm. **An empty bucket is strictly better than a lying one.**
  - **The height of the palms is the check that matters, and reach cannot see it.** Every
    generation before 2026-08-07 painted them 55-77% up the figure where the game's hand line
    is 50.5%, so props were drawn up to 40px below the painted hands in every run. Ask for
    "hands kept LOW at hip height, never above the belt" and expect to re-roll. **The model
    will not paint tucked hands at hip height** - five attempts, every phrasing; it raises them
    to the waist, because that is what a person does.
  - **PALM ORIENTATION IS SCORED (`flat` = the hand blob's width/height), AND THE INNER SLOT
    STILL HAS NONE.** A juggler's hand is turned up at both ends of its travel, to receive at
    the catch and to release at the throw (Louis, 2026-08-08). `pick` now prefers the flattest
    hand that passes the height gate, and the OUTER slot is served: reach 45-49 comes back at
    flat 1.14-1.50. The inner slot is not, and it is not a tuning problem - **measured, 0 of 47
    candidates at reach 24-31 exceed flat 1.00**, across all 19 generations. Widening the
    height gate cannot help because none of them are palm-up at any height. It needs a NEW
    generation aimed at an upturned, cupped hand at hip height, and note that `animate_image`
    takes the still as inline base64 (~14.6k chars at 176x176), which the MCP docs warn is the
    size clients truncate at - so budget a retry for transport, not just for the pose.
  - **`fig_hand_pos` is where a prop is drawn; `hpos` is where the catch is decided.** Held
    props, the catch glow, the charge gauge and the tutorial keys all follow the painted palm.
    `--handlog` prints the residual every tick and is the only honest check: it was 27-65
    screen px (the guard rejecting every frame) before 2026-08-08 and is 0.2-5 px now.
  - **THE BANK'S INDEX LIVES IN THE MANIFEST, NOT BESIDE THE ATLAS.** `Game.gd` reads
    `art_manifest.json`'s `_ARMS` block; the `juggle_arms.json` written next to the PNG is a
    build artefact nothing loads. `build_arm_bank.py --write` writes BOTH, and it must - the
    atlas was once rebuilt to a 57px cell while `_ARMS` still described 64px and 28 entries,
    so every UV sub-rect cut the new atlas at old coordinates. That draws a sleeve with no
    shoulder floating beside the performer, and it looks like a bug in the art.
  - **The body's FACE comes from one frame, not from the median.** The median is right inside
    the arm band and a demolition above it: averaging a twenty-pixel head that the generator
    jitters by a pixel smears the hair over the brow and deletes both eyes. `body_of` takes
    the rows above the band whole from the frame whose head best matches the voted silhouette.
    `head_box` publishes his face's rectangle so `draw_fig_head` can cut a portrait from it -
    the tutorial's speaker is the man on stage, not the traced juggler.
  - **A painted performer owns the hand line.** He is a fixed-size sprite and the stage is laid
    out in fractions of the viewport, and the project stretches with aspect "expand" - so at any
    window that is not 16:9 the boards move and he does not. `stage_center` reads the bank's
    own `hand_py`; measured at 1280x803 that closed an 11px gap that grew with the window.
  - **The hands must be painted in the colours of his FACE.** Layers snapped independently to
    the 48 colours came back with GOLD hands at some reaches and skin at others - which in play
    is his hands changing colour as he reaches out. Distance thresholds do not separate skin
    from the coat's frogging; set membership against the face's own colours does.
- **Two sizes per prop, ONE design.** `prop_big/*` is the shop card (PixelLab, blitted at zoom 1)
  and is the SOURCE: `prop/*` is derived from it by `scripts/derive_stage_props.py` (round props by
  `make_round_props.py --stage`, from the same analytic model that draws their cards), and the title
  wordmark bakes off it too via `mark_prop`. Before 2026-08-06 these were three unrelated pieces of
  art and a player met three different clubs. **A prop's LENGTH is fixed** by `prop_scale` and the
  collision geometry, so a derivation keeps the stage sprite's pixel height and only the width
  follows the card. **Measure the card's INK, not its canvas** - by canvas the club looked 2.6x too
  fat and by ink it was 6->7 art px. **The stage sizes are a written-down table (`STAGE_H`), not a
  measurement of the sprite already on disk** - reading the file's own height is idempotent exactly
  once and doubles the prop on every run after that, which is how the doubling above was applied.

**Hard-won gotchas, each one paid for:**

- **The pixel font is only crisp at MULTIPLES OF 4.** Measured by rendering a 9..34 sweep in
  Godot, because PIL disagreed with the engine and would have given the wrong answer. TOSSA's
  most-used sizes were 13 and 15, two of the worst, which is why the talent tree read "ZZ POINTS
  TO SPEND". `ps()` quantises at every text call site and `validate.sh` check 8 fails the build if
  a new one skips it.
- **THE SCREEN SHAKE WAS THE ONE THING STILL MOVING AT SUB-PIXEL SPEED (2026-08-20).** It set
  the canvas `position` to a continuous `randf_range`, so for the ten-odd frames after every
  drop the WHOLE FRAME sat at a fractional offset and every sprite in the game - props,
  performer, HUD - was resampled off its own grid. Measured with `check_pixel_grid` on the
  `stage_booed` target, whose act drops constantly: **73-95% of the frame off-grid**, against
  5% for the same screen at rest, and the worst number any screen in this game has produced by
  a factor of seven. `art_snap` on the offset takes it back to 5-8%.
  **It hid because a still only catches it if the shake is running in that frame** - two of the
  three sweeps in one session measured the same target at 5% and the third at 94.5%. A number
  that swings that far between identical runs is not noise, it is a state the capture is
  sometimes in and sometimes not; go and find which. And the fix is free in both directions:
  the shake starts at 5.0 and decays 0.82, so whole-art-pixel offsets give {-4,-2,0,2,4}
  falling to zero - a staccato rattle in chunky blocks, which is what a drop should feel like.
- **Godot serves a CACHED import, not your PNG.** Editing a sprite on disk changes nothing in the
  game until `make reimport`, so an art fix looks like it did nothing. Two byte-identical captures
  before and after a change is the tell.
  **AND THE ONLY PROOF AN ART CHANGE LANDED IS A CAPTURE OF THE SCREEN THAT DRAWS IT (2026-08-25).**
  Three trick cards were regenerated, installed, contact-sheeted from `Assets/UI/cards/`, committed
  and pushed - and the running game drew the twelve-day-old cached import the whole time, because
  no `make reimport` ran and the only card ever photographed in situ was the one card that had not
  changed. Louis's verdict was "i don't see any difference". **A contact sheet built from the files
  on disk proves the FILES; it cannot prove the game.** New files are worse, not better: they have
  no import at all, so the seam silently falls back to the procedural drawing, which for
  `ui/stat_*` looked close enough to the sprite to pass a screenshot. Reimport, then capture the
  screen, then commit - and the `.png.import` sidecars a first import writes are part of the
  commit, exactly like every other Assets file's.
- **`scripts/artguard.py` protects hand edits.** A SHA ledger in `Assets/.generated.json`; any
  generator skips a file whose hash differs from what it last wrote, or that it has no record of
  at all. `--force` overwrites, `--relock` re-baselines.
- **Prop pivots are NOT centres** (a club tumbles about 55.8% down its sprite), and prop scales are
  fractional, so prop sprites must be pinned to exact integer screen-pixels per art pixel.
- **A BAKE IS ONLY AS SMOOTH AS ITS SOURCE.** `draw_gradient_v` paints about twenty strips -
  invisible on screen, hard stripes once snapped to 48 colours, and the first venue-exterior
  bake came back looking like a deckchair. No reducer setting can undo a band that is already
  in its input; the reference-render branch in `draw_gradient_v` gives one strip per art pixel.
- **Ordered dither and error diffusion are not interchangeable.** Bayer mixes the two NEAREST
  palette entries by their distance ratio, which is right when they are a hair apart (the title
  proscenium, one slow near-black wash) and wrong when the true colour is far from both (a dusk
  sky crossing the palette's sparsest region), where it plateaus. `pixelise_ext.py` uses
  serpentine Floyd-Steinberg with the error CLAMPED - unclamped it speckles a blue sky red,
  because the palette has no purples and the whole residual lands on one neighbour.
- **A fractional scale is the one thing pixel art cannot survive, and animations hide them.**
  The establishing card's 1.00-to-1.07 push-in had to go when the exterior became a sprite. A
  whole-art-pixel slide is lossless but needs the picture drawn oversize, and `art_blit_rect`
  stretches a sprite to its box - so drawing it 16px wide of 1280 resamples it by 1.0125 and
  gives the same problem back in a subtler form.
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

## Current state (as of 2026-08-16)

- **Input:** per-hand THROW/CATCH, Space=trick, C=switch trick, P=pattern, O=object, 1/2=step
  count, B=Speed assist, T=slow-motion assist, R=restart (practice), S=shop, Tab=sheet, Esc=menu,
  Enter=finish/cash in. Gamepad layout
  and remapping: see `Game.gd`'s input section, unchanged shape since 2026-07-18.
- **Throw:** tap=lowest/snappiest, holding lifts continuously toward 1.4 (1.8 held High Toss).
  Strength is a hard wall now (`PROP_STR_UNIT` x count) - no under-Strength throw exists.
- **Catch:** Perfect always secures; Good/Late are a rising-with-Accuracy, falling-with-height
  chance (90%/70% at Accuracy 100, no gear, no extra height). Accuracy 101-150 = Focus (stamina);
  151-200 buys 5 catch frames.
- **THE HAND LEAVES WITH THE PROP IT THREW (2026-08-19).** `HAND_FOLLOW` blends the hand's target
  out of the release point (`throw_from`, the prop's own `from_pos`) over 14 ticks. It was
  implicitly zero: HAND_SMOOTH 0.22 puts a hand 63% of the way to its next slot four ticks after
  a release while the prop is 5% along an 84-tick flight, so for a tenth of a second after every
  throw the arm is already somewhere else. **It REPLACES the old 22px upward kick rather than
  joining it**, and that is the measured part: a lift is the one thing this figure cannot do,
  because the painted arm bank is a curve of (reach -> dip) and a hand 22px off that curve has no
  pose in it. `--handlog` at three balls: follow-through WITH the kick left the painted palm past
  `FIG_PALM_MAX` on 13% of frames at a mean 5.4px; without it, 0% and 2.5px, against a 2.9px
  baseline with no follow-through at all. Every pattern at 3 and 5 measures 0% / 1.5-3.1px.
- **Difficulty (added 2026-08-16):** SLOTH / BEAR / OCTOPUS, picked once on a brand new career
  (`ST_DIFFICULTY`, between the slot screen and the basics tutorial - three PixelLab mascot
  cards) and changeable any time after from Settings. A single shared seam each:
  `difficulty_frame_delta()` (added into `frame_bonus()`, so it slides Perfect/Good/Late
  together exactly like a stat or a prop does) and `difficulty_catch_bonus()` (added into
  `catch_chance()`). SLOTH (+8 frames, +20% off-Perfect) beats even a fully maxed BEAR build's
  own ceiling on an UNSKILLED juggler with no gear - verified with `--diffcheck`, which prints
  every difficulty's windows and chances at both stat extremes. SLOTH also starts with 200 flowers
  and a 20% base slowdown (removed by Purist like other bought assistance). OCTOPUS (-4 frames,
  -15%) starts with an empty purse instead of `START_GOLD`; starting balls never change.
  `--diffnewgame <name>` (pair
  with `--debug` so it never touches a real save) prints what `reset_new_game()` actually hands
  out at a given difficulty.
- **Scoring (rebalanced 2026-08-19):** `SUM over streaks i of x_i * (o*p*s + 1)^n_i`, all times
  `F`, the act's ONE trick factor. Three factors that cannot compound into each other: the streak
  is LINEAR, the object COUNT is the only exponent, and tricks MULTIPLY.
  **The outer power of `(T + 1)` is gone and it had to go rather than be tuned.** It raised the
  whole sum - streak included - to one-plus-the-number-of-distinct-tricks, and the product over
  tricks repeated `x` once per trick, so a streak carried a total exponent of `T*(T+1)`: two
  tricks made it a sixth power, three a twelfth. Measured on the live constants, twenty Perfect
  catches with three balls at the BACKYARD scored 480 trickless, 1.38e6 with one trick, and
  **1.26e34 with three - seven orders of magnitude above the Midnight Show's own final goal**,
  reached in the opening venue by pressing Space. Every rung above the first was unreachable and
  irrelevant at once. No constant could fix that; the damage was in the shape of the exponent.
  `F = PROD over tricks j of t_j ^ (TRICK_GAIN * (1 + log10(1 + m_j)))`, capped at
  `TRICK_FACTOR_CAP`. **Both numbers are set by the ladder, not by taste**: the cap is 4.0
  because the narrowest step between two houses is 4.39x (Backyard 1,920 to Street 8,433), so a
  flourish is worth about two of an act's three goal steps and never a venue - taking more
  objects up stays the only way up. The gain is 0.6 so the cap is a backstop rather than the
  balance (one Spin 1.7x, ten 2.3x, all three tricks ten times each 3.3x; at gain 1.0 an extreme
  act reached 13.9x and the cap would have been doing all the work).
  `seg_per_catch` (the HUD rail) was a THIRD formula - `s` in the exponent and missing from the
  base, i.e. the shape abandoned on 2026-07-30 - and is now exact, because one more weighted
  catch adds exactly `(o*p*s+1)^n * F`.
  A drop banks the segment. Goals require all three of score, the venue clock
  (`GOAL_MIN_S_LOW/HIGH`), and 75% of the target catch credit in one drop-free run.
  `TossaBalance.gd` owns the tested ladder AND the trick factor, so the contract test holds the
  two against each other: Backyard final 1,920 at the expected build, rising to about 1.02E25 at
  the Midnight Show, unchanged by the rewrite (goal_for and a trickless act share one
  expression). `SCORE_CEIL` (1e300) keeps everything off `INF`; `score_text` switches to
  E-notation past a million.
- **Starting stamina covers the opening house:** capacity is `200 + 8×Endurance`, still ending at
  1,000 at Endurance 100. A perfect three-ball act can survive the Backyard's 30-second final clock;
  old saves retain their stamina percentage when migrating from the former `100 + 9×` curve.
- **Props:** balls/rings/clubs/knives/torches/eggs/chainsaw. Cost to throw = `PROP_STR_UNIT` x
  count (one rule); `PROP_SIG` is a score EXPONENT; `pwin` shifts all three catch bands together.
- **Patterns:** Cascade, Columns, Half Shower, Shower, Reverse Cascade, Tennis. Arms reach exactly
  two points (`inner_pos`/`outer_pos`) with no exceptions - Mills Mess would need this to change,
  which is why it's an architecture change, not "one more pattern."
- **A LANDING NEVER SITS ON A LAUNCH, AND THAT RULE HAS TO BE WRITTEN AS A RULE (2026-08-19).**
  The Shower's feed was fixed on 2026-07-28 by hard-coding `land_slot = HAND_INNER` for that one
  pattern, and the **Half Shower had the identical fault for three weeks**: its weave side lands
  in the HIGH hand, and the high hand launches from OUTER in both showers, so an arriving prop
  and a departing one occupied one point. Measured with `--collcheck` at five clubs, min
  clearance **-1.3px with the two props on the identical pixel**, one at p=1.00 and one at
  p=0.00 - a catch and a throw sharing a slot; the same signature at three and six, and only
  seven happened to miss it. Asking `over_top_land_slot` for the RECEIVING hand's complement
  states the rule once and answers for both patterns. Half Shower now measures +43 to +51 px of
  hitbox clearance and a POSITIVE drawn gap at every count, so **the old note that Half Shower
  "is DOCUMENTED to run near-zero/negative by geometry" is no longer true of it** - only Columns
  and Tennis still do, and those are lane spacing, which is a different thing. Deliberately not
  applied to Tennis: its `throw_slot` depends on which hand holds the marked prop right now, and
  a landing decided at throw time must not read a value that can change before it arrives.
- **COLUMNS LANES ARE BOUNDED BY THE PAINTED ARM, not by the stance (2026-08-19, Louis: "fix the
  hands for columns").** Two separate faults, both making the same picture - a prop and a catch
  ring floating over the coat with the sleeve left behind:
  1. `COL_LANE_IN` was 44 screen px against an arm bank that covers reach 26..51 ART px, i.e.
     52..102 screen. **Every columns lane was inside the bank's floor**, so `fig_arm_pick`
     returned the innermost arm it had and `fig_hand_pos`'s `FIG_PALM_MAX` guard then rejected
     that arm's palm. `col_lane_in()` reads the bank at runtime now; the constant is only the
     no-bank fallback.
  2. The odd count's spare prop ran up the MIDDLE LINE, asking for reach 0. **A two-bone arm
     with a pinned shoulder cannot reach its own root** (its minimum is `|l1-l2|`, about 13 art
     px), so no regeneration and no constant fixes that - it is geometry. The spare is an
     ordinary column on the DOMINANT hand's inner edge now (`columns_lane_count`), and the
     "either hand may scoop it" exception went with it: the off hand catching it stood under a
     column on the far side of the body, and `fig_arm_pick` reads reach as `|x - centre|` and
     cannot see the sign, so the painted arm went one way while its hand went the other.
  3. `hand_carry_y` - a columns hand took `inner_pos`'s full dip at EVERY lane, while its lane's
     props launched and landed on the flat catch line. So a held prop was drawn 26px above its
     own hand, and the bank (whose dip runs 27 screen px at reach 26 down to 0 at reach 51) was
     disagreed with by up to 26px at the outer lanes. The hand, the prop and the painting share
     one carry now.
  Measured with `--handlog` at five balls: the guard rejected **70% of columns frames at a mean
  residual of 109 screen px** before, and **7% at a mean of 3.8** after - better than cascade's
  own 8% / 4.3. `--collcheck` hitbox clearance stays positive at every count; the paintable band
  is narrower than the old one, so lanes are 16-24px apart at seven objects rather than 28, and
  the DRAWN gap goes negative from five up, exactly as Tennis does (Half Shower used to be the
  third one named here, and its negatives turned out to be the landing-slot bug below, not
  spacing - measured 2026-08-19).
- **Tricks:** Behind the Back, High Toss (toggles), Spin (live, no cooldown, full catch/throw
  lockout while spinning - a cost paid in airtime, not a timer). Cascade-only except High Toss
  and Spin, since every other pattern is a fixed geometry a shaping trick would contradict...
  **EXCEPT BEHIND THE BACK IN A SHOWER OR A HALF SHOWER (2026-08-19, Louis: "half shower and
  shower should be able to toggle behind the back with the high throwing hand throwing them
  behind the back and the other hand not - low throws just in front").** This is not a hole in
  the cascade-only rule, it is the one shape the rule does not describe: a shower already HAS
  two roads, so the flourish does not have to touch every throw - only the `dominant_hand`'s
  high road loops behind (`btb_hand`), and the low feed stays exactly the pass it was.
  `--collcheck` at 3/5/7 clubs: hitbox clearance 24.6 / 20.0 / 14.9 px, positive at every count
  and BETTER than the trickless Half Shower's own -1.3 at five (a pre-existing overlap, not
  caused by this). `_coll_pair` names the shaping trick (`t=btb`) now, because an audit where a
  toggle silently failed to switch on reads identically to one where it worked.
- **ONLY COMBINATIONS THE GAME CAN DRAW ARE PLAYABLE (2026-08-19, Louis: "make sure that only
  animated patterns (valid patterns and tricks combos) are playable").** `trick_pattern_ok` is the
  single authority, shared by the trick key, the pattern key and the HUD - the cascade-only gate
  used to live inside `on_trick` and nowhere else, so it only ever asked "may I switch this ON
  right now", and a toggle switched on in a Cascade **survived a P to Columns** (`start_run` clears
  a toggle the player has not unlocked, and no other kind) and scored its multiplier off an
  animation that does not exist. `cycle_pattern` and `start_run` now drop a flourish the new
  pattern cannot carry, and say so. High Toss x Shower joins the refusals: it was allowed with
  "expect clashes" printed under it, which is the game watching props pass through each other and
  describing it. `trick_pattern_warning` is deleted - there is nothing left to warn about.
- **THE THREE GOALS ARE EVEN THIRDS, AND THE METER IS LINEAR AGAIN (2026-08-19, Louis: "the
  subgoals should be linearly spread: one at 1/3, 2/3 and 3/3 of the final goal - the last one
  being the big flower of course").** `GOAL_STEPS` is `[1/3, 2/3, 1]` (was `[0.50, 0.72, 1.0]`,
  which put the first goal half way up the act and crowded the other two into the top quarter),
  and `goal_bar_pos` no longer raises the fill to `GOAL_BAR_GAMMA`. **That constant was
  calibrated on 2026-07-26 against a score whose STREAK sat in the exponent**; the 2026-08-19
  rebalance made the streak linear, so score is linear in weighted catches and the concave remap
  was warping a bar that no longer needed it (at goal 1 it read 0.51). One more weighted catch
  now advances the stem by the same amount wherever it is - which is what `seg_per_catch`
  already promises on the rail beside it. `TossaBalance`'s ladder tests are untouched: only
  goal indices 0 and 1 moved, and the final goal is still 1.0.
- **The act:** one continuous run per venue, three goals (+ante multiplier, capped 1.25^n→6x).
  Cash in anytime past goal 1; a collapse strips back to the last goal banked. One optional Encore
  challenge may color the act (never at the Backyard).
- **Skills are a face-down deck**, dealt (not auto-unlocked) at the same pacing walls as before;
  `owned_skills`/`gifted` is what you own, `skill_gate_cleared` is what you've earned a card for.
- **Economy:** The flower mark is the currency unit in player-facing UI; never spell out a currency
  name or abbreviate it. The crowd throws
  them live during a good run; tomatoes are the failure-currency (stamina only, capped kept).
- **Glow props are green material, not lamps:** charged objects use a clean phosphor-green portrait or
  silhouette with no surrounding aura. Only a charged torch's animated flame turns electric blue.
- **Day loop:** TONIGHT (perform/practice/daily) / REST (meal/inn/pie) / PREPARE
  (shop/skills/stats) drawers. Tailor, its wardrobe art/data, and energy-drink save data remain
  dormant for a later redesign; hats, glasses, and the Energy Helmet must not draw or grant buffs.
- **Venues:** Backyard→Street→Theatre→Circus→Championship→World Arena (the win, `TOP_VENUE`)→
  Midnight Show (bonus 7th, gated on having won + Reputation 6000). Midnight is permanently
  near-black: scenery and performer stay barely visible while charged props read at full strength,
  and an uncharged prop is barely visible in the HAND and almost gone in the AIR (see the two
  dark levels below). The optional Blackout Encore is the same rule, and still cannot roll before
  Championship or without three glow props - 0.09 of the light is not a substitute for owning the
  answer.
- **THE TWO FOOT CARDS ARE ONE STRIP, AND A KEY GOES ON THE CARD IT BELONGS TO (2026-08-19,
  Louis: "now there is SPACE: not in halfshower, but if it's not possible to do the trick, you
  should simply not put that at all, because right now it doesn't all fit inside the window" and
  "change pattern should be inside the pattern window on the bottom left").** Both cards are
  `FOOT_CARD_H` tall on shared baselines: title, a readout, a hints row. `change pattern` and
  `change prop` moved to the ROUTINE card, which had no hints row at all - the trick card was
  carrying three hints in a 330px box that measured 344, so the first keycap started outside the
  panel and the last label finished outside it. **A REFUSAL IS NOT A HINT**: `point_trick_at_pattern`
  keeps the loaded trick on something Space can actually fire, and if a pattern can carry no
  unlocked flourish at all the card says so in one line and offers no keys. The trick card's new
  middle line is the act's live trick factor, which until now only appeared on the results card,
  after it had finished mattering. The routine card's keys DIM (`draw_hints_row`'s new alpha)
  rather than vanishing once `mode == MODE_PERFORM and started`, which is the same gate the keys
  themselves answer to. **Anything on these cards is measured against `s.y - 18`**, not against
  the row above it: a 22px keycap at the old baseline hung 14px below the card's own bottom edge,
  and the previous 70px card did the same by 2px, which is small enough to have shipped unnoticed.
- **THE CROWD DIAL HAS A PAINTED RIM AND A DRAWN EVERYTHING-ELSE (2026-08-25, Louis: "also
  regenerate a prettier happiness meter with pixellab").** `ui/gauge_face` is a thin gold bezel
  arc and nothing more; the four coloured zones, the ticks, the needle, the peak pin and the hub
  are still drawn, because every one of them changes state. **Paint what does not move.**
  Two things are worth keeping from getting there. **The generator is good at a chunky ring of
  lit metal and bad at a large flat dark surface** - a roll that drew the whole instrument
  (bezel, face, scale, ticks, boss, and a needle it was told not to draw) gave a face carrying
  its own baked shading and a brass that went muddy through the palette snap, and measured worse
  than the primitives it replaced. And **the painting owns the RIM, not the SCALE**: wiring the
  game's zones into the groove that roll had painted put the coloured arc at 60-81% of the
  radius where the drawn instrument had it at 74-90%, so the thing a player reads mid-set came
  out smaller inside a prettier ring. `_GAUGE` therefore publishes two numbers - where the metal
  starts and how far it reaches - and Game.gd decides its own scale. Same hand-copy hazard as
  `_TORCH`: nothing syncs `scripts/install_gauge.py`'s printed block into the manifest.
- **AND SO IS THE GILT DIVIDER - DO NOT ADD ANOTHER (2026-08-25, Louis, on the last one left,
  under the title: "there is still a golden symbol on the title screen just below tossa.
  (remember to never use those again)").** `draw_ornament` had eighteen live call sites: a rule
  with a centre flourish under the title of almost every screen in the game, plus three spacer
  rows in the credits roll. **A title does not need underlining, and a divider between two things
  the layout has already separated is decoration answering a question nobody asked** - space,
  alignment and the screen's own painting do that work, and a gold squiggle on top of them is a
  fourth voice repeating it. The credits keep the vertical advances their divider rows carried, so
  the roll's spacing is unchanged and only the flourish is gone.
  `draw_capsule_art` keeps this one too, for the poster reason above, and that single caller is
  what keeps `ui/rule_flourish` from being orphaned.
- **THE GILT FRAME IS STORE ART, NOT A MENU (2026-08-25, Louis: "the golden border around the
  screen is still there and it looks bad").** `draw_frame` ringed seven live screens - the day hub,
  settings, slots, the difficulty and play-mode cards, the controls sheet, Records and History - and
  on every one it is a rectangle drawn ON TOP of a painting that already frames the screen: the
  hub's venue exterior, the menu bake's own proscenium. **The picture supplies the frame.** A gold
  box over it reads as a sticker on a photograph, which is the same fault the hub's header ornament
  was deleted for one day earlier. The one caller left is `draw_capsule_art`, where a dramatic gilt
  border IS the job - it is a poster, it has no room of its own, and nobody plays through it. The
  `ui/corner_*` sprites stay live through that one caller, so nothing is orphaned.
- **THE DAY HUB'S HEADER IS THE DAY NUMBER AND NOTHING ELSE (2026-08-24, Louis: "remove the
  golden border and the golden symbol ... and also get rid of those sentences, i don't like those
  extras").** A phase label (daylight / night / deep night), the gilt divider under it and a line
  naming stamina as the day's limit stood over the venue painting, and all three said something the
  screen was already saying better: the hub DARKENS as the segments burn, the stamina card carries
  its own bar, its own numbers and its own "worn out" line, and every action stamina blocks prints
  the reason on the row the cursor is standing on. `seg_name()` went with them - it had exactly one
  caller. **Furniture that repeats a picture is not redundancy the player forgives, it is a caption
  on a photograph.**
- **A LESSON SWEEPS THE BOARDS, AND THAT IS A SECOND ENTRY POINT NOBODY HAD NOTICED (2026-08-24,
  Louis: "in practice tutorials: there are flowers on the ground when there shouldn't be").**
  `begin_tutorial` does not go through `start_run` - a lesson deals its own table - so the six
  things `start_run` clears about the FLOOR (thrown props, the tomato stains, the four baked-pile
  fields) survived into it, and a player who took a lesson after a good night stood in their own
  ovation. It was invisible from the throwing side because `throw_step` already refuses to throw
  anything while `tut_active`: the flowers were never thrown there, they were simply never swept
  up. `clear_boards()` is that block as a function, called from both. **Two places start a stage;
  a reset that lives inside only one of them is a list waiting to go stale.**
- **A PREVIEW'S TURN IS SOLVED FROM ITS OWN CHOREOGRAPHY, NEVER PINNED TO A CLOCK BESIDE IT
  (2026-08-24, Louis: the Skills screen's "spin animation card looks bad: throw three balls very
  high so that you have time to spin around").** The Spin preview ran a 1.6 cascade and laid a
  1.3-second turn over it on `fposmod(t * 0.34, 1.0)` - a cycle unrelated to the throws - so the
  figure turned THROUGH its own catches, which is the one thing a Spin cannot do (it locks both
  hands for its whole 44 ticks). The throw is 2.4 now, which is what buys the time, and
  `pv_free_window` finds the longest stretch of the loop in which every prop is airborne by taking
  the CARRY legs (a carry leg IS the prop in the hand) and shifting each by its own prop's offset -
  six intervals for a three-prop cascade, so it is a sort and a walk, not a sweep. Raising or
  lowering the throw now moves the turn with it. **Two things worth keeping**: with evenly spread
  props every free window is the same length, so a strict `>` is what makes the turn happen ONCE
  per loop rather than at every tie; and the resting state outside the window must be `turn = 0`,
  not 1 - a full turn ends facing front so both draw the same picture, but `turn > 0` is what
  `draw_mini_juggler` reads to decide whether to lay its sweep streaks over him and swap his body
  for a rotation frame, so held at 1 he is a man standing still inside a permanent blur.
- **Records/pay/rep:** per-venue assisted + Purist boards; pay scales with surviving score; rep
  swings on goals reached.
- **THE TWO LIMITERS ARE BOOKED SEPARATELY, IN THE HUB, ON THEIR OWN ROWS (2026-08-19, Louis:
  "the limiters (accuracy and slowmo) should be toggleable in the choosing menu, below the stage
  toggle - moving down, then hitting enter to select or deselect").** BIND ACCURACY and BIND SLOW
  MOTION sit directly under PERFORM in the TONIGHT drawer, each an Enter toggle with its own
  BOUND/off readout; `P` still flips both at once as a shortcut. They live in `purist_picks`
  slots 0 and 3 - the legacy four-slot save shape - and `set_binds` is the ONLY writer, so
  `purist` stays derived and means what it always meant: BOTH bound. Strength and Endurance are
  never stripped, and a slow-motion bind disables every slow-mo source (stat, difficulty, pie,
  bursts). The economy was already priced for a single bind (`resolve_act` pays
  `1 + 0.4 * n / 2`); what did not exist was any way for a player to book one. **The PURIST
  RECORD BOARD still asks for both** - half a booking is not a Purist act - so the perform card,
  the establishing card and the live HUD each name which limiters are on rather than saying
  "PURIST" for three different states. `--binds acc|spd|both|off` pins them for a capture.
  **THE PAIR IS A SIDEWAYS CHOICE, NOT TWO STOPS ON THE WAY DOWN (2026-08-24, Louis: "left and
  right when selecting either of them should switch between them (not moving up and down, which
  should change between choosing a stage and selecting accuracy or slowmo)").** They are DRAWN as
  two marks side by side, so the axis that moves between them has to be the axis they are laid out
  on; walked vertically, a two-item setting cost as many presses as two whole errands and Down from
  PERFORM took three to reach PRACTICE. `day_walk` collapses the band to ONE stop - both rows stay
  in the list, in order, so `day_activate`, the drawn panel and `--binds` are untouched and only
  the walk changed. Left/Right on PERFORM still moves the venue; the footer hint says which of the
  two jobs the arrows are doing, because a hint naming the other row's job is an instruction that
  does not work where it is printed.
- **THE TWO ASSIST SWITCHES AND THE UNAIDED CLEAR (2026-08-19, Louis: "two small icons (a boot for
  speed, and a stopwatch for slowmo) ... when both are off and you beat the final goal of the
  stage, you get a reward").** Every slow-motion source falls into exactly one of two buckets and
  the icons ARE the buckets: the **BOOT** is the Speed stat (permanent, invested, worn) and the
  **STOPWATCH** is everything temporary (the difficulty base, Uncle Dan's Pie, the Amazing! and
  fifty-Perfect bursts). `B` and `T`, legal any time, persisted in settings, always on the stage
  card whether on or off because they are CONTROLS and not a status. A lesson refuses them - a
  tutorial step pins its own pace, so they would appear to do nothing.
  The reward is the **UNAIDED clear**: hit a venue's FINAL goal with neither assist having run at
  any point (`act_assisted`, judged where the world is actually slowed - reading the switches at
  the goal would sell the mark for one keypress) and the room throws a volley of gold roses and
  bouquets (real money: the pile IS the purse), the venue keeps a permanent UNAIDED mark shown on
  its record chase, and the FIRST clear at each house pays one stat point and 300 Reputation. Seven
  stat points exist in a career and none of them is farmable, because the mark is what gates them.
  `--assists on|off` pins both for one run so the state can be photographed, and deliberately never
  writes back to the SHARED settings file.
  **...AND THE TWO ICONS ARE OFF THE PLAY HUD (2026-08-24, Louis: "about the accuracy and slowmo
  while you are on stage: remove those symbols, they are chosen before hand").** The argument for
  putting them there - a control the player cannot see is a control they do not know they have -
  was answered by the day hub: what you give up for the night is BOOKED there, on the row that
  names the stage, under two struck-through marks that stay struck all evening. Two marks on stage
  that look exactly like the two marks in the hub, doing a different and smaller job, read as the
  booking following you onto the boards. **When two systems end up wearing the same picture, the
  one the player MEETS FIRST owns it.** `B` and `T` still work and still persist; `draw_assist_row`
  and `assist_icon` are deleted, and `unaided_now()` is now read only by the reward. The boot
  sprite outlived them - it is the SPEED stat's mark on the talent sheet, by the file, on Louis's
  own reasoning for choosing it ("a boot is a thing you WEAR").

- **A DARK HOUSE HAS TWO LIGHT LEVELS AND THEY ARE THE HAND AND THE AIR (2026-08-20, Louis:
  "i want dark challenges and the midnight show the props have to be barely visible in the hands
  and in the air they become almost completely invisible - even less light to see them").**
  `DARK_DIM_HAND` (0.26) and `DARK_DIM_AIR` (0.09), through the `dim` argument on
  `draw_prop_rich`, which rides the sprite TINT and so darkens the finished object for free.
  Measured against a Midnight Show room of RGB (7,6,7): a held ball reads (59,32,14), about 8x
  the room and plainly an object; the same ball in flight reads (21,16,7), about 2.5x - enough to
  confirm a prop you already know the position of and nowhere near enough to track one you do
  not. **One number could not do both jobs**: the 0.34 this replaced made a flying prop
  comfortable to track, which costs the dark house the reason it is dark, and still left a held
  one a guess. The comet trail takes the same argument, so at the air level it is arithmetically
  nothing (its own alphas top out at 0.20) - which is the honest result, not a special case.
  **THE DIVISION BETWEEN THE TWO DARK HOUSES IS GONE WITH IT.** `dark_props_hidden()` lived for
  one day and made Blackout erase a prop outright while the Midnight Show dimmed it. The
  reasoning (one is accepted, one is merely arrived at) was sound and the line was in the wrong
  place: the interesting difference is not between the two ROOMS but between a prop you are
  holding and a prop in the air. Nothing asks which dark house it is standing in any more.
  A FALLEN prop takes the HAND level, and that one is argued rather than derived: it is
  technically falling, but it is not something to catch, it is something to go and find, and it
  fades after three seconds anyway. (`draw_falling` drew at FULL brightness in a dark room until
  2026-08-19, which made a mistake the best-lit object in the house.)
- **A CHARGED PROP IS THE PROP, NOT A DRAWING OF ONE (2026-08-19, Louis: "the glow in the dark
  objects render completely wrong").** `glow_silhouette` painted the phosphor shape with
  `draw_circle` and hand-written polygons that predate the art seam, so the one object a player
  has to read on the darkest stage in the game was an antialiased vector disc stepping at one
  screen pixel beside a coat stepping at two - measured (109,145,97), a dull olive smudge.
  `art_glow_mask` DERIVES the silhouette from the prop's own sprite (every opaque pixel to white,
  hard threshold, cached in the bank beside its source and rebuilt free on an F9 variant swap) and
  blits it through the normal path with the phosphor as its tint. Pixel-exact, same pivot, same
  zoom, and it can never disagree with the lit shape again because it IS the lit shape. The old
  branches stay as the procedural fallback. Two things went with it: the alpha (0.85 x a flicker
  bottoming at 0.85, over a room measured at RGB (7,8,9) - phosphor EMITS, so it holds near-full
  alpha now and the flicker only breathes), and the dark torch's fire, which was still placed from
  `TORCH_WICK` while the lit one has been placed from the painting's own measurements since the
  torch became a sprite. Nobody could see that while the dark handle was a vector line.
- **S IS THE FINAL GOAL, NOT A QUALITY SCORE (2026-08-19, Louis: "S score should only be for the
  final goal, not a failed performance").** `run_grade`'s three inputs - cleanliness, peak crowd,
  best streak - are all about HOW the act was played and none of them about whether it worked, so
  a short flawless opening that then fell apart could stamp the top grade on a card whose own
  header two lines above read "1 of 3 goals". The ladder still measures craft; the top rung now
  additionally requires `goals_hit >= NUM_GOALS`. Everything below S is untouched.
- **THE INJURY RULE IS OFF (2026-08-19, Louis: "disable the lose all stamina when hit by a
  dangerous object for now, it's irritating").** One constant, `INJURY_ENDS_ACT`, read by
  `injury_prop_kind`. Every other piece stays wired up and reachable - `injury_prop`, the three
  `*_injury` collapse reasons and their fail cards, the red drop flash - so turning it back on (or
  giving it a gentler cost than "all of it") is one line plus a decision. **`validate.sh`'s step 3d
  moved with it** and now asserts the opposite: a chainsaw drop must NOT end the act on injury.
  Test the behaviour, not the machinery, or the suite stays green describing a game that is gone.
- **THE TWO LIMITERS ARE A PANEL INSIDE THE PERFORM CARD (2026-08-19, Louis: "binding accuracy and
  slowmo should be a small subwindow of the perform window, not separate ones").** Walking to them
  as their own cards worked and cost too much: full-height cards with icon discs and 17pt titles
  gave two SETTINGS the same weight as PERFORM and PRACTICE, so a drawer of three things to do
  read as a list of five. `inset` is a DRAWING flag and nothing else - the rows stay in
  `day_actions()`, in order, so the cursor still walks onto them, Enter still toggles through
  `day_activate`, the footer still says "toggle" and `--binds` still captures. `day_card_height`
  gives them zero height (and the layout loop no gap), and the perform card reserves the panel at
  the FOOT of its own box. Two smaller things make it read as one window rather than three:
  **`open` is not `selected`** (the perform card stays grown while the cursor is inside its panel,
  or the venue name and the record to beat vanish at the moment you are setting that act up), and
  the card stays lit while the cursor is inside it. `day_perform_focus()` is retired: it existed to
  keep Left/Right on the stage picker from inside the panel, and the panel now owns that axis
  itself (see the sideways-choice rule above). `day_row_id` answers "what is the cursor on" for
  input, drawing and the footer alike, so the three can never disagree.

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
Columns/Tennis are DOCUMENTED to run near-zero/negative by geometry from about five objects up,
not a bug; **Half Shower no longer is** - see the landing-slot rule above, which is what its
negatives always were); `--ladder`
prints every venue's expected build/pacing from the live constants; `--fps` prints the perf probe
(trust `draws/s` over `engine fps` unless the window has focus - see `docs/coding_guidelines.md`).
`--tutlog` prints every moment a LESSON STOPS THE WORLD - which of the three mechanisms did it,
whether the line has finished, and how old every airborne prop is. **A freeze looks identical to
a running frame in a screenshot**, so "the tutorials pause at the wrong time" had no evidence
anybody could gather; a before/after of that log is what the 2026-08-19 pause fixes were measured
on. Note `--demo`'s metronome satisfies most beats before a gate can open one, so the counts are
a lower bound on what a human sees.
**TWO FLAGS EXIST BECAUSE THE SCREEN THEY SHOW CANNOT OTHERWISE BE PHOTOGRAPHED** (2026-08-19),
and that is the general lesson, not a detail about either of them: **a screen with no capture
target is a screen nobody has looked at since the art density changed**, and both of these were
still smooth vector drawing long after everything around them became sprites.
`--vign <id> [t]` holds one of the five day-hub vignettes (eat/inn/pie/egg/tomato) at a FIXED
phase - they play for 0.8-1.8s in the middle of a hub action and then the ledger moves, so no
capture could land on one, and an unfrozen phase photographs a different moment every run. Its
effect can never land, so a capture cannot spend ten flowers.
`--tutlog` also prints the hand order of a beat's asks and which hand is dominant: a basics
`do` step names its hand in its goal, but an older lesson's beat is DERIVED from the sim and
named it nowhere a log or a screenshot could reach.
`--binds acc|spd|both|off` books tonight's limiters for a capture (and opens the post-win
marks for that run): the two hub rows need a cursor
and an Enter, which no capture can press, so their BOUND state had no capture path at all. Unlike
`--assists` it DOES write back, because a booking belongs to the save.
`--assists on|off` pins BOTH assist switches for one run: the two dark icons and the UNAIDED row
need two keypresses inside a live act, which no capture can make, and the flag never writes its
pin back to the shared settings file.
`--dom left|right` pins the STRONG HAND for one run, on the same never-write-back contract. Every
pattern with a high road is mirrored by that setting - Shower, Half Shower, Tennis's weave,
Columns' spare lane - and so is every line of text that names a hand, so half of those pictures
had no capture path at all and a left-handed player was being shown (and told) the mirror image
of their own act.
`--touchcheck` audits **"the props always touch the hands"** and prints four numbers: the worst
gap between a prop's release point and the hand that released it, the worst gap between a landing
point and the hand that took it, that same catch measured against where the hand was HEADED
(`catch aim`, which excuses a hand still travelling and indicts one aimed elsewhere), and the
worst of both seams inside a Skills preview. It counts how many seams exceeded 10px as well as
the worst one, because a repeating fault and a one-off need different fixes. Drive it with
`--demo --pattern <id> --balls N` for the stage and `--skills <n>` for a preview; the preview half
needs a WINDOWED run (headless never calls `_draw`, and the flag says so rather than printing
zeroes). It found four real faults on the day it was written, including one - Tennis asking
`stack(h).has(...)` about a prop it was not about to throw - that no screenshot could have shown.
`--stem <frac> [over]` pins the goal stem's fill: the meter is score against a venue's FINAL
goal, so a bloom needs a whole winning act to photograph and the subgoal flowers appear at fills
a demo run may never sit on. Overflow only exists at full fill.
Both have `screenshot.sh` targets now, with the phase/fill written into the target - a frame
captured at an unpinned phase is not comparable run to run.

`godot --check-only` is a fast filter, not a reliable one (has missed a real parse error before) -
always also run a real windowed/headless pass and grep for `SCRIPT ERROR`/`Parse Error`.
Always `--audio-driver Dummy` for any run Louis isn't actively playing.

## Music / audio

Louis's own Suno tracks, free-tier renders, **NON-COMMERCIAL** - must be re-rendered under a paid
Suno month and swapped before release. SFX synthesized at startup (`gen_sfx`), catch sounds
quality-led, tonal stingers only, no ambient crowd bed.

## Release blockers (reviewed 2026-08-16)

1. Music licensing (above).
2. No demo export preset yet. Release and portable debug presets exist for macOS, Windows and
   Linux; a scoped demo preset still needs feature tag `demo` and an end-to-end export check.
3. macOS signing/notarization not yet configured.

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
- **A PROP LEAVES FROM THE HAND, NOT FROM THE HAND'S TARGET** (2026-08-20). `do_throw` sets
  `b.from_pos` to the pattern's launch SLOT and then overwrites it with `hpos[h]` for every throw
  that is not a Columns lane or a Behind the Back. The slot is the design - the roads, and
  `over_top_land_slot`'s launch-never-on-a-landing guarantee, are laid out from it - but a hand is
  smoothed toward its slot and a throw pressed before it arrives used to teleport the prop up to
  46px to meet it (measured on the Half Shower, whose high hand catches at INNER and launches from
  OUTER). On the metronome the change costs nothing at all: `--collcheck` is byte-identical before
  and after. Under `--latecatch 5` a rushed pattern now visibly degrades, which is what rushing is.
- **A PREVIEW MAY NOT CARRY ITS OWN COPY OF THE SIM'S NUMBERS.** The Skills panel's constants
  (`PV_*`) are all derived - `PV_OUTER` from `HAND_OUT_DX`, `PV_ARC` from `ARC_PER_AIR * BASE_AIR`,
  every road height from the sim's own minimum fraction, every Columns lane from `columns_x` at
  `PV_COUNT` objects. They used to be hand-copied decimals and three of them had gone stale
  silently: the lane spacing still described the pre-2026-08-19 layout with a column on the dead
  centre line, and the Shower's feed still described an airtime that had been cut to a sixth.
  **If a preview needs a number the sim has, take the sim's - and if the sim cannot answer for a
  hypothetical (three objects, when the run has seven), give its function a parameter rather than
  a second copy.**
- **A LONG CAPTURE SESSION POISONS THE DEMO SAVE, AND VALIDATE THEN FAILS LIKE A REGRESSION
  (2026-08-24).** `--demo` writes to `pixeltossa_demo.cfg`, so an afternoon of `--demo --booking`
  captures - including the deliberately awful ones, `--boo` and `--eggbreak` - leaves that save
  somewhere the harness's own acts cannot recover from. Step 3a came back
  `collapsed=true reason=crowd score=0 tomatoes=10` and read exactly like a code fault; the same
  command on a clean worktree of the previous commit passed, and then the SAME command on the
  working tree passed too, byte-identical (score 10,196, 8,995 ticks). **The tell is that the two
  trees share one userdata directory**, so a worktree A/B only exonerates the code if you re-run
  the suspect tree afterwards - one pass each, in that order, or the second run is just reading
  what the first one wrote. Run `make quick-validate` from a demo save that has not just been
  driven into the ground, or restore it first.
- **NO DEV-FLAG RUN MAY WRITE A REAL CAREER SLOT**, and the guard is `dev_unattended()`, not a
  hand-written `_demo or _shot` pair. It also keeps a headless audit from auto-pausing on focus
  loss. Anything that skips the title screen sets `_dev_boot` and is covered automatically; the
  flags named in the predicate are the ones that can ALSO run with the menu up. Both halves are
  needed, and the cost of missing one is not small: a bare `--handlog`, and a
  `--touchcheck --skills` run during the 2026-08-20 work, each wrote their scratch progress
  straight over career slot 0. **Back up `~/Library/Application Support/Godot/app_userdata/TOSSA/`
  before running any new harness** - that is what made the second one recoverable.
