# TOSSA

A skill-based juggling game with a light performer-career sim around it. Godot 4.7, 2D, GDScript,
one self-contained file (`Game.gd`, ~23k lines), code-only art, mostly code-rendered audio. Aimed
at a polished $10 Steam release.

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
