extends Node2D
## IACTO ("I ACT o", the o a juggling ball - formerly JUGGLE). Core mechanic, Prototype 1.1.
##
## This rebuilds the throwaway spike into the real v0.2 catch-and-throw model
## (GDD Sections 2 and 9). The question it must answer: with catch and throw
## split across four inputs, strict catches, hold-for-height throws, the
## throw-under-traffic rule, and inward-hand no-crossing choreography, is the
## deeper input still fun and readable? No meta layer yet (that is Prototype 2+).
##
## Inputs (all remappable later): left catch D, left throw F, right catch K,
## right throw J, trick Space. Both inputs of a hand must be good: a bad catch
## loses the ball, a throw is only punished when traffic is incoming to that hand.
##
## The sim runs entirely on the fixed 120 Hz physics tick so it stays
## deterministic, which the production build needs for replays and fair boards.
##
## TABLE OF CONTENTS (2026-07-18: one file, still - see CLAUDE.md's "one file
## until it hurts" - but every section below is a #region/#endregion block, so
## the editor can fold each one closed. Godot's script editor and VSCode both
## show these as a collapsible outline; click the fold arrow in the gutter, or
## search for a heading below to jump straight to it.
##   TUNABLES & GAME STATE              - every const/var: tuning knobs first
##   STARTUP                            - font setup, _ready
##   MAIN LOOP & INPUT ROUTING          - _physics_process, _input, pad<->key
##   PAUSE & PERFORMANCE FLOW           - pause menu, finish/begin a performance
##   ACT GOALS & ENCORES                - the three goals, challenge deck math
##   DAY HUB LOGIC                      - enter_day, the reward director, meals
##   SHEET / SHOP / SKILLS INPUT        - key handlers for those three screens
##   LIVE PROP / PATTERN / COUNT SWITCHING - mid-performance O / P / number keys
##   TUTORIAL SYSTEM                    - the whole guided-lesson engine
##   DAY-HUB PURCHASES (PIE / GLASSES)  - the two non-prop shop items
##   MAIN MENU / SLOTS / SETTINGS INPUT - key handlers for those three screens
##   SAVE SLOTS                         - start/reset/delete a save slot
##   SETTINGS PERSISTENCE & CONTROLS REMAP - options file, key + pad rebinding
##   LOW-LEVEL INPUT POLLING (KEYBOARD + PAD) - the 120Hz catch/throw edge logic
##   HAND GEOMETRY & BALL SLOTTING      - where hands and balls sit, per pattern
##   ROUND START, CATCHING, GOALS       - start_run, on_catch, check_goals
##   THROWING                           - do_throw and its press/release edges
##   UNLOCK REQUIREMENTS & PATTERN/TRICK TABLES - who needs what to unlock what
##   TRICKS: SPIN / CYCLE / REWARD      - the live trick, C-cycle, trick payouts
##   XP, LEVELING & UNLOCK ANNOUNCEMENTS - add_xp, lesson queueing, banners
##   ROUND RESOLUTION & CATCH/CHANCE MATH - on_round_end, catch_chance and kin
##   VENUES & PROPS                     - venue lookup, prop stats/hitbox/scale
##   STATS INVESTMENT & SAVE/LOAD       - spend points, ConfigFile save/load
##   SIM TICK: DROPS, COLLAPSE, FLIGHT  - drop_ball, update_sim, flight_pos
##   STAGE BACKDROP DRAWING             - the venue backdrop and crowd
##   JUGGLER FIGURE DRAWING             - the performer's body, arms, face
##   PROP DRAWING                       - balls/rings/clubs/knives/torches
##   HUD HELPERS & KEY-HINT LABELS      - the k_* remap-aware button labels
##   RESULTS CARD, PAUSE MENU, TRICK/ROUTINE HUD - end-of-act and play overlays
##   CHARACTER SHEET SCREEN             - the stats/investment panel
##   SHOP SCREEN                        - the Balatro-style purchase grid
##   SKILLS SCREEN                      - the trick/pattern reference list
##   DAY HUB SCREEN                     - the eat/sleep/perform/practice hub
##   MAIN MENU SCREEN                   - the title screen
##   SLOTS / SETTINGS / GAME-OVER / MISC SCREENS
##   AUDIO SYNTHESIS (SFX)              - every sound is generated code, not a file
##   ESTABLISHING CARD & CREDITS        - the pre-act venue card, end credits
##   SHARED VISUAL HELPERS              - gradients, vignette, ornaments, logo
##   PARTICLE EFFECTS & POPUPS          - sparks, egg shards, floating text
##   VENUE EXTERIOR ART (CUTSCENES)     - the six venues' establishing exteriors
##   DEV: AUTOPLAYER & SCREENSHOT CAPTURE - --demo, --collcheck, --shot etc.

#region TUNABLES & GAME STATE
# --- catch timing (ticks; 120 per second) -------------------------------------
const W_PERFECT := 7      # within ~58 ms of arrival
const W_GOOD := 10        # ~83 ms (tightened 30% from 15: Good must be earned)
const W_LATE := 28        # ~233 ms, still a catch but sloppy
const COMMIT := 52        # a CATCH press with a ball this near but outside the
						  # allowed window fumbles it (drop). Beyond this = whiff.
const MISS_GRACE := 20    # an uncaught ball drops this many ticks past arrival

# Off-Perfect catches are a CHANCE, not a hard window. A ball within the Good or
# Late timing band secures with a probability that rises with Accuracy and falls
# with throw height; Perfect timing always secures. So low Accuracy still lands
# plenty of catches, just less reliably, and Accuracy buys reliability.
const ACC_FULL := 55.0            # Accuracy at which off-Perfect catches are reliable
const GOOD_BASE := 0.50           # base chance to secure a Good-timed catch
const LATE_BASE := 0.30           # base chance to secure a Late-timed catch
const ACC_CATCH_BONUS := 0.30     # added to the chance at full Accuracy. Capped so a
								  # bare-handed Good catch tops out at 80%, not 100%:
								  # only Glasses' flat bonus below can reach 100%.
const MIN_CATCH_P := 0.06         # a wild ball is never quite hopeless
const STRENGTH_CATCH := 0.05      # per weight-step, how much Strength eases (or, when
								  # under-strength, hurts) the catch of a HEAVY prop
const STRENGTH_LOFT := 0.4        # at double a heavy prop's required Strength, up to
								  # this much extra height per held tick (times weight)

# --- throw height by hold (variable 0..1.4) -----------------------------------
# A tap throws the LOWEST, snappiest height (BASE_AIR airtime); holding THROW lifts
# it continuously toward the top. Height is a normalized 0..1.4 factor: higher buys
# airtime (thins traffic) but is harder to catch. This is the quick, responsive feel
# Louis preferred. The tier-based model is preserved on branch `tier-throw-model`.
const BASE_AIR := 84       # airtime (ticks) for an instant tap-throw (snappy)
const HOLD_MAX := 44       # holding THROW past this adds no more height
const HOLD_GAIN := 1.9     # airtime ticks added per tick the THROW is held
const ARC_PER_AIR := 2.15  # arc peak (px) per airtime tick; balls crest above the head

# how much height hurts a catch, and the under-Strength penalties (ideas.rtf rule)
const HEIGHT_CATCH_PENALTY := 0.35  # subtracted from the off-Perfect chance at max height
const DEFICIT_HEIGHT := 0.5         # a full Strength deficit halves the HELD (extra) height
const DEFICIT_BASE := 0.4           # a full Strength deficit drags the TAP floor down this much,
									# so a too-heavy prop goes lower even on a plain throw
const DEFICIT_INACC := 1.1          # a full Strength deficit roughly doubles inaccuracy
const DEFICIT_FLOOR := 0.85         # under-strength: minimum inaccuracy "as if" this much height,
									# so even a low throw of a too-heavy prop is unsteady

# --- inaccuracy scale (the risk half of the risk/reward) ----------------------
const DRIFT_MAX := 26.0   # px lateral landing drift at max height
const JITTER_MAX := 5     # ticks of arrival uncertainty at max height

# --- game flow: the app boots to a menu, not straight into a run ---------------
const ST_MENU := 0        # title / main menu
const ST_SLOTS := 1       # pick a save file
const ST_SETTINGS := 2    # options
# (value 3 was the story cutscene state, cut with the narrative)
const ST_PLAY := 4        # the juggling itself
const ST_ESTABLISH := 5   # the stage card: the venue exterior and its record before a set
const ST_CREDITS := 6     # the victory screen shown once the top stage is conquered
const ST_DAY := 7         # the day hub: a juggler's life between performances
const ST_STATS := 8       # the career ledger: every record and lifetime number
const ST_REMAP := 9       # the controls screen: rebind the six action keys
const ST_GAMEOVER := 10   # the road's end: too tired to earn, too poor for a bed
const ST_TUTDONE := 11    # the small congrats card after the basics lesson: the
						   # starting kit, a breath, THEN the day hub (Louis: no
						   # hard cut from the lesson straight into a menu)
const ST_CAPSULE := 12    # dev only (--capsule): pure key-art, no UI chrome, for
						   # exporting Steam capsule/store images - see draw_capsule

# --- the day loop (GDD 4.5): light texture and stakes, never a chore -----------
# A day holds three action segments. Performing or practicing spends one, eating
# and shopping are quick, sleeping ends the day. Stamina persists across the day
# and only sleep restores it, so the existing fatigue rules finally have a rhythm.
# Skill-first guardrail: none of this touches the catch or throw timing floor.
const SEG_PER_DAY := 3
const EAT_COST := 10       # a hot meal: gold out, stamina back, strength slowly up
const EAT_STAM := 0.35     # a meal restores this FRACTION of max Stamina (scales with
						   # Endurance, so it stays a meaningful top-up at 100 or at 1000)
const MEALS_PER_STR := 3   # every third meal feeds +1 Strength (GDD: eating fuels it)
const INN_COST := 30       # a proper bed: full stamina on waking. It wants FULL
						   # payment now (Louis): a juggler who cannot afford the
						   # bed and cannot stand to busk has reached the end of
						   # the road, and the game says so honestly (game over)
const TIRED_FLOOR := 12.0  # below this stamina you cannot work, only sleep
const VENUE_PAY := 0.35    # each venue tier pays this much more than the last
const BUSK_FLOOR := 8      # a broke juggler always earns at least this from the hat
const BROKE_GOLD := 20     # the busking floor applies below this purse
const NUM_SLOTS := 3

# --- progression / stats meta (GDD Section 4; skill-first guardrails hold) -----
const SAVE_PATH_DEBUG := "user://iacto_debug.cfg"  # debug build: separate progress
const SAVE_PATH_DEMO := "user://iacto_demo.cfg"     # --demo/--shot autoplay: never a real career save
const SETTINGS_PATH := "user://iacto_settings.cfg" # global options, shared by slots
const POINTS_PER_LEVEL := 3
const ACC_MIN_FACTOR := 0.35  # inaccuracy floor at Accuracy 100: never zero, so a
							  # max-height throw always still demands a real catch
const STAM_DRAIN_CATCH := 0.4
# (throws price by the prop's flat "stam" rate in PROPS now, not a global const)
const STAM_LOW := 0.25        # below this fraction of max, fatigue lowers Accuracy
const STAM_MIN_MULT := 0.5    # Accuracy multiplier at empty stamina (GDD 4.7)

# --- reputation: the career-climb currency (GDD 4.4). Scales PAY, never score
# or catching, so it stays on the comfort axis and never touches the skill floor.
const REP_PAY_DIV := 400.0    # pay multiplier = 1 + reputation / REP_PAY_DIV
const REP_SWING := 60         # reputation gained by a great set, lost by a poor one
const PURIST_BONUS := 1.4     # Purist pay and reputation both get this multiplier: a
							   # Purist set is objectively harder to run clean (catch
							   # chance capped as if Accuracy were 5), so without a real
							   # reward there was no reason to ever book one over an
							   # assisted set. High risk should mean high reward.
const START_GOLD := 100       # a fresh juggler starts with a small purse (ideas.rtf)

# --- Focus: Accuracy trained past 100 (GDD "Focus"). The overflow eases the
# grind without touching the timing floor: stage 1 lowers stamina cost, and once
# that bottoms out, stage 2 widens the Perfect window a little. Both are capped.
const ACC_CAP := 250              # Accuracy trains to 250, so Focus reaches 150
const STR_CAP := 200              # Strength and Endurance climb to 200 now (Louis: the
const END_CAP := 200              # late game runs deep) - same per-point effects, just
								  # a longer road; the 8-11 ball gates live up here
const MASTERY_GOLD := 250         # once EVERY stat is capped, each level-up point turns
								  # to gold instead: the crowd pays for mastery itself
const FOCUS_STAM_FLOOR := 0.25    # stamina-cost multiplier once Focus hits 100
const FOCUS_WINDOW_PER := 10.0    # +1 Perfect tick per this much Focus above 100
const FOCUS_WINDOW_MAX := 6       # hard cap on the widening (skill-first guardrail)

const LEFT := 0
const RIGHT := 1
const CASCADE := 0
const FOUNTAIN := 1
const COLUMNS := 2
const HALFSHOWER := 3
const SHOWER := 4
const RCASC := 5
const WFALL := 6
const TENNIS := 7
# --- patterns as learnable content (GDD economy: harder base pays more, so one
# tamed routine is never optimal). P cycles the unlocked patterns in training.
# "mult" scales every catch's score, the reward for the pattern's base difficulty.
# EXACTLY ONE pattern is active at a time (Louis): Reverse Cascade, Waterfall and
# Tennis live HERE now, not as Space toggles, so switching patterns always switches
# the whole routine and Columns can never run "on top of" anything.
# Unlocks are spread across the CAREER, not the first evenings (Louis): each entry
# may ask for a level, a stat, and a stage. All present keys must be met -
# see skill_req_met / skill_req_text. Indices 0..4 are frozen (pattern_sel saves).
const PATTERNS := [
	{"id": "cascade",    "name": "Cascade",     "lvl": 1, "mult": 1.0,
	 "desc": "The weave. Every throw crosses to the other hand."},
	{"id": "fountain",   "name": "Fountain",    "lvl": 1, "mult": 1.1,
	 "desc": "Each hand juggles its own circle. Even counts feel natural."},
	{"id": "columns",    "name": "Columns",     "lvl": 4, "acc": 8, "mult": 1.15,
	 "desc": "Straight up and down in fixed lanes; an odd count opens a middle lane too. Clean or nothing."},
	{"id": "halfshower", "name": "Half Shower", "lvl": 8, "acc": 12, "ven": 1, "mult": 1.25,
	 "desc": "The right hand throws over the top, the left keeps the weave."},
	{"id": "shower",     "name": "Shower",      "lvl": 1, "ven": 3, "mult": 1.4,
	 "desc": "The full circle. Right throws high, left feeds fast and low."},
	{"id": "rcasc",      "name": "Reverse Cascade", "lvl": 1, "ven": 4, "mult": 1.45,
	 "desc": "BOTH hands throw over the top, the weave runs backward."},
	{"id": "wfall",      "name": "Waterfall",   "lvl": 11, "str": 14, "ven": 2, "mult": 1.3,
	 "desc": "The right hand keeps throwing over the top while the left flows low beneath it."},
	{"id": "tennis",     "name": "Tennis",      "lvl": 1, "ven": 5, "mult": 1.5,
	 "desc": "One marked ball sails over the top, back and forth across the weave."},
]
# UNLOCK DESIGN (Louis): every skill sits behind a wall of difficulty, hard work or
# talent - never behind raw XP alone. Each NEW STAGE guarantees exactly one arrival
# reward, gated on the venue and nothing else (Street: Behind the Back. Theatre: Spin.
# Circus: Shower. Championship: Reverse Cascade. World Arena: Tennis), so moving up
# always pays. The rest carry composite stat/level walls and fill the stretches
# BETWEEN stages; when even those run dry for too long, the pity director in
# enter_day gifts the nearest one (see pity_grant).
const SHOWER_FEED := 0.5      # the feed pass's airtime as a fraction of a tap
const SHOWER_MIN := 0.55      # the high hand's minimum height fraction in a shower
const HALFSHOWER_MIN := 0.5   # the over-the-top side's minimum height fraction (0.35
							   # left its arc only ~34px above the weave where they
							   # cross; 0.5 keeps clear air between the two roads)
const OVER_TOP_MIN := 0.5     # generic over-the-top minimum height fraction (Overthrow,
							   # Reverse Cascade, Tennis's marked ball)
const WATERFALL_HIGH := 0.6   # Waterfall's over-the-top hand: minimum height fraction,
							   # clearly higher than the generic over-the-top throws
const WATERFALL_LOW := 0.15   # Waterfall's other hand: MAXIMUM height fraction, so it
							   # visibly flows low under the over-the-top side rather
							   # than drifting up to meet it (Louis: they read almost
							   # the same height without a forced ceiling here)
const COLUMNS_SYNC := 0.65    # how strongly a Columns throw is pulled toward the
							   # lanes' running height (0 = pure hold-timing, 1 = locked)
# --- object load (ideas.rtf comments): more balls in the air and heavier props
# both raise the score multiplier, ON TOP OF the pattern's own "mult" above, so
# climbing to five clubs or three torches always outpays grinding an easy three-
# ball routine forever, however long the streak. See object_mult().
const OBJ_BALL_BONUS := 0.12    # per ball above MIN_BALLS
const OBJ_WEIGHT_BONUS := 0.15  # per weight step above a ball/egg's weight of 1
const STATE_FLIGHT := 0
const STATE_HAND := 1
const MODE_TRAIN := 0     # practice: no crowd, no pay, lighter energy cost
const MODE_PERFORM := 1   # on stage: Applause meter, energy cost, and pay
const MIN_BALLS := 3
const MAX_BALLS_HARD := 15   # the late game runs deep (2026-07-18: raised from 11 -
							 # Louis wanted more room once throws stopped ballooning
							 # past the intended height cap): 8-15 objects live in the
							 # raised Strength band (100..200), for masters only. 15
							 # itself lands exactly at STR_CAP - the ultimate object
							 # count is also the "you've maxed Strength" milestone.

# --- props / objects (GDD 2.7, 4.6; ideas.rtf object table) -------------------
# Each prop has a weight (heavier = more stamina and more inaccuracy) and a
# Required Strength for clean throws. Under that strength, throws land lower and
# wilder (the ideas.rtf rule). Required Strength is the ideas.rtf table shifted
# down 10 so balls stay comfortable at the game's starting Strength. Cost is what
# the shop charges. "spins" props tumble in flight for spectacle.
const PROP_BALLS := 0
const PROP_EGGS := 1
const PROP_RINGS := 2
const PROP_CLUBS := 3
const PROP_KNIVES := 4
const PROP_TORCHES := 5
const PROPS := [
	# balls are REAL STOCK too (Louis: they don't appear out of thin air): a fresh
	# juggler starts with three, and the fourth ball onward is bought like any prop
	{"name": "Balls",   "weight": 1, "req": 0,  "cost": 20,   "stam": 1, "spins": false},
	{"name": "Eggs",    "weight": 1, "req": 0,  "cost": 1,    "stam": 2, "spins": false},
	{"name": "Rings",   "weight": 2, "req": 12, "cost": 200,  "stam": 3, "spins": false},
	{"name": "Clubs",   "weight": 3, "req": 22, "cost": 500,  "stam": 4, "spins": true},
	{"name": "Knives",  "weight": 4, "req": 34, "cost": 1000, "stam": 5, "spins": true},
	{"name": "Torches", "weight": 5, "req": 48, "cost": 2000, "stam": 6, "spins": true},
]
# "stam" is a throw's FLAT stamina price (Louis): every throw costs at least 1,
# heavier props cost their own rate, and Focus shaves one point per 20 Focus,
# never below 1. See do_throw - the old percent-of-a-percent drain is gone.
const WEIGHT_STAM := 0.25    # each weight step adds this fraction of stamina cost

# --- shop: spend gold on props and gear ---------------------------------------
const GLASSES_COST := 8000     # the only route to a 100%/80% catch ceiling: priced
								# as the capstone purchase it now functionally is,
								# not a minor bonus on an already-full curve
const GLASSES_CATCH_BONUS := 0.20  # ideas.rtf: glasses raise the catch chance

# the Glow-in-the-Dark Kit (2026-07-18, late-game gold sink - Louis: nothing left
# to spend an "immense" late purse on): a cosmetic that is also a genuine mercy on
# Blackout, so it is worth the price rather than a pure vanity flex. Priced well
# past Glasses (the previous capstone) - a build with real gold to spare late is
# exactly who this is for.
const GLOW_KIT_COST := 60000

# input map (physical keycodes; a real remap layer comes with the options menu)
# the six remappable actions (physical keycodes, persisted in the settings
# file). Defaults are the classic DFJK spread plus Space and C. The Controls
# screen (Settings > Controls) rebinds them; a clash SWAPS the two bindings so
# no action can ever be left keyless.
var K_LC := KEY_D
var K_LT := KEY_F
var K_RC := KEY_K
var K_RT := KEY_J
var K_TRICK := KEY_SPACE
var K_CYCLE := KEY_C
const REMAP_ACTS := [
	["lc", "Left hand  CATCH"], ["lt", "Left hand  THROW"],
	["rc", "Right hand  CATCH"], ["rt", "Right hand  THROW"],
	["trick", "TRICK  (the one-shot powerup)"], ["cycle", "SWITCH TRICK"],
]

# gamepad face buttons (2026-07-18, per Louis): bumpers throw and triggers catch
# always - those are hardware-natural (fingers already rest there) and stay fixed,
# never remapped. TRICK and SWITCH TRICK are the two actions a face button actually
# performs live in the sim, so those two ARE remappable, same Controls screen as
# the keyboard six. Escape/Enter/Tab stay on fixed, swapped face buttons (below in
# _pad_to_key) since keyboard Esc/Enter/Tab aren't remappable either.
var PAD_TRICK := JOY_BUTTON_X    # was Y; swapped with Tab's old X slot
var PAD_CYCLE := JOY_BUTTON_LEFT_STICK   # previously had NO pad button at all
const PAD_ACTS := [
	["trick", "TRICK  (the one-shot powerup)"], ["cycle", "SWITCH TRICK"],
]

# hand animation. Every hand rests at exactly one of three fixed points - never a
# predicted, in-between spot - and moves to a DIFFERENT one only in direct response
# to a throw or catch (Louis): no drifting ahead of the ball to meet it.
const HAND_SMOOTH := 0.22  # per-tick lerp of hand toward its target position
const HAND_OUTER := 0        # the catch point, standard
const HAND_INNER := 1        # the throw point, standard; also the catch point for
							  # anything riding the over-the-top road, and BOTH points
							  # for Columns (one rest slot, so the hand does not tremor)

# --- tricks (GDD Section 3): FLOURISHES fired with the TRICK key (Space), laid
# OVER whatever pattern is running. C selects which trick Space is loaded with
# (the selection persists). Anything that reshapes the whole routine (Columns,
# Waterfall, Reverse Cascade, Tennis) is a PATTERN now, not a trick (Louis: one
# pattern at a time, always switch-off-able with P). THREE grammars remain:
# "toggle" switches ON with one press and OFF with the next, smoothly reshaping
# every throw in between (High Toss, Behind the Back) - for a single flourish
# you switch on, throw, and switch off; "arm" is the one-shot powerup (Overthrow
# only), one press empowers exactly the next throw; "live" acts on the balls
# already airborne (Spin). Each landed shaped catch pays its bonus, so a trick
# is a skill choice, never a free bonus. A running toggle SURVIVES an R restart
# in training, so a trick can be drilled run after run. Unlocks are spread over
# the career like the patterns' (lvl / str / acc / ven keys, all must be met).
const TR_HIGH := 0
const TR_BTB := 1
const TR_SPIN := 2
const TR_OVER := 3
const TRICKS := [
	{"id": "high", "name": "High Toss",        "kind": "toggle", "lvl": 3, "min_air": 0, "bonus": 90,  "shout": "HIGH TOSS!",
	 "desc": "Toggle: every throw flies sky high - hold the throw and it climbs clean out of the frame. For a single toss, switch on, throw, switch off."},
	{"id": "btb",  "name": "Behind the Back",  "kind": "toggle", "lvl": 1, "ven": 1, "min_air": 0, "bonus": 60,  "shout": "BEHIND THE BACK!",
	 "desc": "Toggle: every throw loops behind the back. Style the crowd loves, if you keep landing it."},
	{"id": "spin", "name": "Spin",             "kind": "live",   "lvl": 1, "ven": 2, "min_air": 1, "bonus": 0,   "shout": "SPIN!",
	 "desc": "Spin the moment a ball is in the air. Catches score double, you catch blind."},
	{"id": "over", "name": "Overthrow",        "kind": "arm",    "lvl": 6, "str": 10, "min_air": 0, "bonus": 120, "shout": "OVERTHROW!",
	 "desc": "Power one throw up and OVER the top of the pattern."},
]
const SPIN_TICKS := 44             # how long a Spin lasts (about a third of a second)
const TRICK_COOLDOWN := 96         # ticks before a LIVE trick can fire again
# (per-trick score bonuses live in the TRICKS table's "bonus" field)

# --- slow motion (ideas.rtf): every source adds its share, stacking linearly.
# The Speed stat is permanent and capped, the Pie is a bought minute, the
# Amazing! frame-perfect catch and a run of ten straight Perfects are earned
# bursts. Slow motion stretches the catch windows in REAL time, which is what
# makes five clubs and seven torches humanly possible.
# NERFED 2026-07-16 (Louis): slow motion was too easy to stack. The Speed stat
# now costs 8 points per 1% (200 points to reach the full 25%), the Pie and the
# earned bursts each give 15% instead of 25%, the bursts run shorter, and the
# TOTAL slow is capped at 50% - above that the 120Hz sim visibly steps ("jitters
# on balls"), and 50% is the intended ceiling for a five-object load anyway.
const SPEED_CAP := 200         # the Speed stat's permanent ceiling (points, not percent:
								# 8 points per 1% slow motion, so the cap is still 25%)
const PIE_COST := 1000         # a slice lasts the WHOLE DAY, until you sleep
const PIE_SLOW := 0.15         # the slice's share of slow motion (was a quarter)
const BURST_SLOW := 0.15       # each earned burst's share (Amazing!, the chain)
const SLOW_TOTAL_CAP := 0.5    # the stack's hard ceiling, jitter-free and earned
const AMAZING_FRAMES := 360    # the frame-perfect reward burst (three seconds)
const CHAIN_NEED := 50         # perfect catches in a row to earn a slow window
const CHAIN_FRAMES := 1800     # ...which then lasts fifteen seconds, then re-earn
const SLOW_RAMP := 0.0025      # slow motion ramps LINEARLY in and out per frame
							   # (a hard step made the player miss, Louis; slowed
							   # further so both easing in and out give real
							   # reaction time instead of a sudden gear change)
const SLOW_MIN_BALLS := 3      # under three props the crowd holds no breath:
							   # no chain or Amazing! farming with two balls
# --- lessons (Louis): a lesson is taught in thick time, so a beginner can SEE the arc
# and the window. It starts nearly frozen and speeds up as the lesson goes on, so the
# last step is close to real speed and the player is never dumped from a slow world
# straight into a fast one. A step may override this floor with its own "slow" key.
const TUT_SLOW_START := 0.5    # the first step of a lesson: half speed (the
								# slow-stack cap, so lessons stay jitter-free too)
const TUT_SLOW_END := 0.20     # the last step: nearly real time
const TUT_FLOW_HOLD := 10      # ticks a GUIDED step lingers on its win before flowing to
								# the next one - long enough to register "yes, that", short
								# enough that the next key's prompt is up before the ball
								# it refers to is halfway down
# the BASICS lesson's adaptive pace (Louis): slow motion is EARNED away, not scripted.
# The lesson opens at the game's own 50% cap and every run of clean catches steps the
# world faster down this ladder; a drop steps it back up, so a struggling player gets
# their thick time back instead of drowning. The lesson only ends with ten catches of
# a true three-ball cascade at the ladder's floor: genuine full speed.
const TUT_PACES: Array[float] = [0.5, 0.25, 0.15, 0.0]
const TUT_PACE_STREAK := 4     # clean catches in a row that earn the next notch down
const PROMPT_LEAD := 90        # ticks before a catch that its key prompt begins to glow
							   # and brighten (at 62% slow that is about two real seconds)
const SPIN_CATCH_MULT := 2.0       # every catch during a Spin scores double
const SPIN_ACC_PENALTY := 0.28     # a Spin lowers the off-Perfect catch chance (juggling blind)

# --- THE ACT (Phase 2, reworked per Louis) -------------------------------------
# A performance is ONE continuous act at one venue - never phases, never a fresh
# deal partway through. The act carries three GOALS (first, second, final - each a
# taller number), a crowd whose patience DRAINS (the applause meter as a clock),
# and a hard DROP LIMIT. From the moment the FIRST goal falls you may CASH IN at
# any time - press the finish key, or simply catch every ball and hold them (the
# air empties, the act is over, the bow is implied) - and the results card pays
# what the whole act scored. Pushing for the next goal instead is the gamble: a
# COLLAPSE (crowd walks, drops, or empty stamina) strips the score back to the
# last goal actually reached. One optional CHALLENGE condition (the ENCORES deck)
# may colour the whole act - one condition for the whole act, never a different
# one per phase (Louis) - and the Backyard never rolls one, so the first stage
# stays a pure lesson in juggling.
const NUM_GOALS := 3
# the first goal per venue. The whole phase lives or dies on these numbers, so
# they were set against the --calib autoplayer sweep, not guessed: a flawless three-
# ball cascade clears the Backyard's first goal and falls well short of the Championship.
# The 7th entry (The Midnight Show, 2026-07-18) is a first guess extrapolating the
# same growth trend, NOT yet calib-verified like the rest - it is genuinely new,
# post-game content with no strong-player data behind it yet.
const VENUE_BASE := [8000, 20000, 55000, 85000, 100000, 140000, 200000]
const GOAL_STEP := [1.0, 1.9, 3.2]    # first, second, final goal: each a taller bar
const ANTE_STEP := 0.15               # each complete act at a venue raises its bar 15%
# the crowd's patience bleeds this much per tick, per venue (120 ticks a second). At
# the Backyard a still juggler loses the room in ~24s; at the World Arena in ~8. Every
# Perfect catch pays ~0.05 back, so keeping the crowd is a matter of keeping juggling.
# The 7th entry continues the established +0.00012-per-venue step exactly.
const APPL_DECAY := [0.00034, 0.00044, 0.00056, 0.00068, 0.00080, 0.00092, 0.00104]
const DROP_LIMIT := 3                 # three drops and the crowd turns (a challenge may lower it)
const APPL_THROW_HEIGHT := 0.012      # a big throw excites the crowd: patience back, scaled by height
# the crowd's patience economy, now that it is a CLOCK rather than decoration. The
# per-catch gains are deliberately smaller than a set's decay bleed, so steady low play
# is a slow drain the crowd bleeds out of - reaching the target is a race, and spectacle
# (height, tricks) is what buys the time to win it. Tuned against the --calib autoplayer.
const APPL_PERFECT := 0.014
const APPL_GOOD := 0.007
const APPL_LATE := -0.020
const APPL_WHIFF := -0.040
const APPL_SPIN := 0.010
const BOOK_PAY_PER_SCORE := 0.0015    # gold per point banked across the booking (score already
									  # scales with the venue, so this needs no separate venue term)
# The Encore deck: each is a single named twist on the third set, and each is a couple
# of lines because it toggles a constant or a draw call that already exists. Several
# were designed months ago as "cosmetic" or "optional" (the glow-in-the-dark prop is
# Blackout, the Purist toggle is The Purist's Night, Hard Mode's clacks are Close
# Quarters): boss blinds that finally have somewhere to live.
const ENCORES := [
	{"id": "hecklers",  "name": "The Hecklers",       "desc": "The crowd is impatient. Their attention drains twice as fast."},
	{"id": "fright",    "name": "Stage Fright",       "desc": "The lights are in your eyes. No landing markers."},
	{"id": "draft",     "name": "The Draft",          "desc": "A wind through the room. Every throw drifts wider."},
	{"id": "blackout",  "name": "Blackout",           "desc": "The lights are cut on the way down: every prop vanishes past its apex. Only a torch's flame burns through."},
	{"id": "cold",      "name": "Cold Hands",         "desc": "The Perfect window is two ticks tighter."},
	{"id": "long",      "name": "The Long Set",       "desc": "The final goal is doubled, but the crowd is patient. An endurance test."},
	{"id": "understudy","name": "The Understudy",     "desc": "One drop and it is over."},
	{"id": "purist",    "name": "The Purist's Night", "desc": "No gear, no stats, no help. Only your hands."},
	{"id": "fire",      "name": "For the Danger",     "desc": "This crowd came for danger. Only clubs, knives and torches score."},
	{"id": "tight",     "name": "Close Quarters",     "desc": "The stage is cramped. Props that clip mid-air turn treacherous."},
]


class Ball:
	var state := STATE_FLIGHT
	var to_hand := LEFT
	var from_pos := Vector2.ZERO
	var to_pos := Vector2.ZERO
	var launch_tick := 0
	var land_tick := 0
	var arc := 120.0
	var height := 0.0         # normalized throw height 0..~1.4; higher lowers catch odds
	var color := Color.WHITE
	var kind := 0             # which prop (index into PROPS); sets look and weight
	var spin_dir := 1.0       # tumble direction for spinning props (clubs/knives/torches)
	var trick := -1           # which trick shaped this throw (TR_HIGH/TR_BTB), or -1 for a plain throw
	var over_top := false     # an over-the-top lob: scooped from INNER, lofted wide to OUTER
	var lane_x := -1.0        # Columns: the x of this ball's own vertical column, so two
							  # balls in one hand never stack on the same line (-1 = unset)
	var bumped := false       # hard mode: this ball clacked another mid-air; only a
							  # half-Perfect-window catch can still save it
	var trail := PackedVector2Array()  # recent flight points; longer and cooler with height


var tick := 0
var pattern := CASCADE
var pattern_sel := CASCADE  # the chosen pattern (persisted); start_run snaps it to what is unlocked
var pattern_once := -1    # a practice booked from the Skills screen runs THIS pattern for
						  # that session only - the player's own P choice (pattern_sel) is
						  # untouched, so trying a pattern never silently re-books the act
var num_balls := 3
var mode := MODE_TRAIN
var balls: Array[Ball] = []

# per-hand held stacks. A hand carries one ball in normal play; at the start of
# a 3-ball run one hand holds two (the standard two-in-one-hand opening), so a
# small stack is the honest representation. Throwing pops one off.
var _stack_l: Array[Ball] = []
var _stack_r: Array[Ball] = []

# per-hand THROW charge (height = how long THROW is held)
var charging := [false, false]
var charge_start := [0, 0]

# per-hand animation state
var hpos := [Vector2.ZERO, Vector2.ZERO]  # smoothed current hand position
var hclose := [0.0, 0.0]                  # 0 open (ready), 1 closed (holding)
# an EMPTY hand's fixed waiting point (HAND_OUTER/HAND_INNER). Set exactly once
# per incoming ball, the instant it is thrown (see do_throw), and held there
# untouched until the catch resolves - it never creeps toward a predicted landing.
var hand_catch_rest := [HAND_OUTER, HAND_OUTER]
var catch_flash := [-999, -999]
var throw_kick := [-999, -999]            # tick of last throw, for the reach-up
var last_drop_tick := -999               # for the juggler's wince expression

var applause := 0.7
var peak_applause := 0.7  # the crowd's high point this run, for the reputation swing
var score := 0
var streak := 0
var best_streak := 0
var dropped := 0
var caught := 0
var running := false      # true once the player makes the first throw
var started := false
var popups: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()

# --- the booking's live state (Phase 2). A booking is three sets at one venue; most
# of this is per-booking and deliberately NOT saved (a booking is short, and losing
# it on quit is a fair, far simpler price than mid-booking resume). Only `ante`
# persists, since it is the standing difficulty the venue remembers.
var booking_active := false   # true from begin_performance until the act resolves
var goals_hit := 0            # goals reached so far THIS act (monotonic; 1+ arms the cash-in)
var set_collapsed := false    # the act ended by collapse (score strips to the last goal)
var exhausted := false        # the collapse was caused by empty stamina: on return to the day,
							  # steer the player straight to EAT / SLEEP (Louis)
# WHY the set ended, in one word, set at the moment it happens and never guessed at
# afterwards (Louis: a player must always know why they failed - and be told the ONE
# real reason, not handed a list of the three things that could have gone wrong).
# "" while a set is live or when it was cleared; otherwise "crowd" (the room emptied),
# "spent" (no stamina left), "drops" (the drop limit), or "bow" (walked off under the
# target on purpose). fail_text() turns it into words. Reset per SET, so the reason the
# card shows is the one that actually ended the night.
var fail_reason := ""
var encore := -1              # index into ENCORES for this booking's third set, or -1
var ante: Array[int] = [0, 0, 0, 0, 0, 0, 0]   # complete acts per venue: the standing raised bar

# progression / stats (persisted per save slot, see save_file())
var accuracy := 5         # lands throws closer; low Accuracy forces Perfect catches
var strength := 6         # quicker high throws; gates ball count and hard tricks
var endurance := 0        # raises max Stamina (100 base + 9 each, to 1000); gates heavy props later
var speed := 0            # the Speed stat: every 4 points slows the world 1% (cap 100 = 25%)
var pie_count := 0        # Uncle Dan's Pies in the pantry (bought in the shop)
var pie_active := false   # a pie eaten in the hub works until you SLEEP
var amazing_until := -999999   # real-frame deadline of the Amazing! burst
var chain_until := -999999     # real-frame deadline of the fifty-Perfect window
var perfect_chain := 0    # consecutive PERFECT catches toward the next window
var _slow_cur := 0.0      # the LIVE slow amount, easing linearly toward target
var _tick_acc := 1.0      # fractional sim-tick accumulator while slowed
var _frames := 0          # real frames in play (the slow-mo timers run on this)
var money := START_GOLD   # earned by performing (not training)
var reputation := 0       # rises with great sets, falls with poor ones; scales pay
var prop_type := PROP_BALLS  # the object being juggled this run
# how many of each prop you own (balls are free and unlimited, see have()). You buy
# props by quantity in the shop, and to juggle N of a prop you must own N. Eggs are
# consumed permanently when dropped; durable props are not.
var prop_count: Array[int] = [0, 0, 0, 0, 0, 0]
var has_glasses := false  # bought gear: raises the catch chance
var has_glow_kit := false # bought gear: props keep a faint glow through Blackout
var level := 1
var xp := 0               # xp accumulated inside the current level
var points := 0           # unspent stat points
var stamina := 100.0      # within-run resource; empty = you cannot catch, so mind it
var stamina_max := 100.0  # 100 base + 9 per Endurance point, to 1000 at Endurance 100
var run_xp := 0           # xp earned in the current run, for the results screen
var last_pay := 0         # gold earned from the last finished performance
var last_rep_delta := 0   # reputation change from the last performance, for the results screen
var run_venue := 0        # which venue this run was performed at (records key off this)
var best_scores: Array[int] = [0, 0, 0, 0, 0, 0, 0]  # best performance score per venue tier
# --- the Purist ladder (GDD "Purist boards"): a performance booked as PURIST
# strips every stat comfort from the catch maths (Accuracy read as a fresh
# juggler's, no glasses, no Focus window, no Strength steadying), so its records
# are pure skill. Separate per-venue bests, toggled per booking in the day hub.
var purist := false
var best_scores_purist: Array[int] = [0, 0, 0, 0, 0, 0, 0]
# --- the career ledger (persisted per slot): lifetime numbers behind the record
# boards, shown on the RECORDS AND HISTORY screen reached from Settings
var career := {"perfs": 0, "practices": 0, "catches": 0, "drops": 0,
	"best_streak": 0, "gold_earned": 0, "tricks": 0, "days": 1, "best_score": 0,
	"mastery": 0}   # level-up points turned to gold after every stat capped
var results_open := false # the end-of-performance results panel is showing
var results_record := false  # this performance beat the venue's record
var paused := false       # the in-play pause menu is up (freezes the sim)
var pause_sel := 0        # cursor in the pause menu
var round_scored := false
# --- tricks: which trick Space is loaded with (cycled with C, persists), whether
# Space has primed a one-shot, the live-Spin timer, and the run's trick tally.
var trick_sel := -1       # the selected trick (index into TRICKS), or -1 before any unlock
var trick_primed := false # Space pressed: the very next throw becomes the selected arm trick
var toggle_on := -1       # the flourish toggle currently running (TR_HIGH / TR_BTB), or -1
var toggle_scored := false   # this activation has already counted toward tricks_landed
var tennis_ball: Ball = null # the marked ball that sails over the top while Tennis runs
var col_air_ref := -1.0  # Columns: running reference airtime, so lanes bounce in sync
var col_mid_ball: Ball = null # Columns (odd counts): the one ball fed across the middle
var trick_ready := -999   # tick a LIVE trick may fire again (cooldown)
var spin_until := -999    # tick the current Spin ends; catches until then score double
var spin_scored := false  # this Spin has already been credited as landed
var tricks_landed := 0    # tricks landed cleanly this run, for the results screen
var trick_score := 0      # score earned from tricks this run
var trick_msg := ""       # brief on-stage feedback ("High Toss armed", "SPIN")
var trick_msg_tick := -999
var trick_unlock := -1    # a newly unlocked trick to announce with a banner, or -1
var trick_unlock_tick := -999
var sheet_open := false
var shop_open := false
# the card CURSOR on the sheet and the shop (Louis: select with arrows / sticks / dpad,
# so a pad player can spend points and buy props). The number keys remain the fast path
# on a keyboard; arrows move the gold highlight and Enter (pad A) acts on it.
var sheet_sel := 0        # 0..3 across the four stat cards
var shop_sel := 0         # 0..5 the prop cards, 6 glasses, 7 the pie, 8 the Glow Kit
var skills_open := false   # the Skills reference: every trick and pattern, and how to use it
var skills_sel := 0        # which entry the Skills reference has expanded
var debug_mode := false   # debug build: free stat editing in the character sheet
const SHEET_REPEAT_DELAY := 0.32   # debug: hold a stat key this long before it auto-repeats
const SHEET_REPEAT_RATE := 0.04    # debug: then step the stat this often while held
var _repeat_key := 0      # the debug stat-adjust key currently held for auto-repeat, 0 = none
var _repeat_t := 0.0      # time accumulator for the held-key repeat
var _prev_running := false

# game-flow state
var game_state := ST_MENU
const STATE_FADE_FRAMES := 14   # ~120ms at 120Hz: every screen fades in on arrival,
								 # detected generically (see _physics_process) so no
								 # individual `game_state = ST_X` site needs to know
var _fade_prev_state := -1      # -1 so even the FIRST screen (the boot menu) fades in
var _state_fade_t := 0          # ticks since the last game_state change
var menu_sel := 0         # cursor index in whichever menu is open
var save_slot := 0        # which save file is active
var remap_sel := 0        # cursor on the controls screen (keyboard column)
var remap_wait := false   # true while the controls screen listens for the next key
var remap_col := 0        # 0 = keyboard column has focus, 1 = gamepad column (Tab swaps)
var pad_remap_sel := 0    # cursor on the controls screen's gamepad column
var _confirm_id := ""     # the purchase awaiting its second, confirming press
var _confirm_ms := 0
var shop_msg := ""        # transient warning line inside the shop panel
var shop_msg_ms := 0
var shop_buy_ms := 0      # when gold last changed hands, so the purse can flash

# --- day-loop state (persisted per slot) ---------------------------------------
var day := 1              # which day of the career this is
var seg_used := 0         # action segments spent today (0..SEG_PER_DAY)
var venue_pick := 0       # which unlocked venue you have chosen to play
var meals := 0            # meals eaten toward the next point of Strength
var day_sel := 0          # cursor in the day hub
var day_msg := ""         # transient hub feedback ("the day is spent, sleep")
var day_msg_tick := -999  # cine_tick the message appeared
var day_anim := ""        # a short hub vignette playing: "eat", "inn" or "shop"
var day_anim_start := 0   # cine_tick it began; its effect applies when it ends
var won := false          # the climb is complete: a record set at the top stage
var pending_win := false  # show the victory screen once the results card is dismissed
var view_venue := -1      # preview override of which venue palette to draw
var ext_center := false   # exterior hero objects (house, lamp) compose mid-frame
						  # for the day hub card; story scenes keep them offset
var shake := 0.0          # screen-shake magnitude, decays each frame

# --- presentation layer: the stage card, the day hub, menus, tutorials --------
var cine_tick := 0        # cosmetic clock for the stage card, menu, and hub motion
var establish_venue := 0  # which venue's exterior the stage card shows
var establish_after := 3  # ball count to start the performance with once dismissed
var seen_tuts: Array[String] = []  # lesson ids already shown, so they fire once
var pending_tuts: Array[String] = []  # lessons queued by an unlock, taught at the hub
# the REWARD DIRECTOR's memory (Louis: rewards spread out, never bunched or absent).
# gifted holds skill ids the pity path granted despite their walls; the counters and
# flags pace the gifts so a struggling player is helped and a farming player is not.
var gifted: Array = []             # skill ids unlocked by pity (skill_req_met honours these)
var perfs_since_unlock := 0        # acts played since ANY skill unlocked (pity trigger)
var aid_pie_day := -1              # the day a pie was last gifted (one per day at most)
var aid_meal_used := false         # the once-per-career stamina rescue has been spent
									  # (an unlock happens mid-set; the lesson must wait)

# --- interactive tutorial (runs on the REAL sim, guided step by step) ---------
var tut_active := false   # a hands-on lesson is running inside ST_PLAY
var tut_id := ""          # "balls" (the 1->2->3 progression) or "prop_<n>"
var tut_step := 0         # index into tut_lesson(tut_id)
var tut_count := 0        # catches (or throws) banked in the current step
var tut_threw_l := false  # a left-hand throw happened this step
var tut_threw_r := false  # a right-hand throw happened this step
var tut_advance_at := -1  # tick to move on (a beat after the goal, so the throw lands)
var tut_tricks := 0       # reward_trick calls banked this step (arm/live trick goals)
var tut_keys := 0         # command-key presses banked this step (the R and P teaching
						  # goals count on their own, so a stray catch cannot clear them)
var tut_pace := 0         # the basics lesson's rung on TUT_PACES (0 = slowest)
var tut_flow_streak := 0  # clean catches in a row toward the next rung; drops zero it
# egg-break effect: shell shards (fly with gravity) and yolk splats (spread on floor)
var shards: Array[Dictionary] = []
var splats: Array[Dictionary] = []
# dropped props now FALL to the stage floor as cosmetic bodies instead of
# vanishing at arm height: eggs break where they land (Louis), other props
# bounce once and rest. `collapsing` is the lost-set grace: the hands give up,
# everything comes down, and only when the last prop lands does the round end.
var falling: Array[Dictionary] = []
var collapsing := false
# cosmetic juice layer: particles (sparks, embers, confetti, shock rings), a short
# hit-stop after big impacts, and the timers that drive HUD/results animation.
# None of this touches the sim, so determinism and fairness are untouched.
var parts: Array[Dictionary] = []
var freeze := 0             # hit-stop ticks left: the world holds, input still reads
var results_tick := -999    # tick the results card opened (drives its reveal)
var results_stamped := false  # the grade stamp sound has fired
var record_broken := false  # beat this venue's best mid-run (fires the flash once)
var last_streak_tick := -999  # when the streak last grew, for the multiplier pulse

# global settings (persisted to SETTINGS_PATH)
var set_shake := true     # screen shake on a drop
var set_collide := false  # hard mode: props that clack mid-air become nearly
						  # uncatchable (half the Perfect window, no chance roll).
						  # A PERFECT pattern never collides, so this only ever
						  # punishes sloppy heights that share air.
var set_music := 1.0      # the procedural adaptive soundtrack's volume, 0..1 (was a bool)
var set_sfx := 1.0        # catch/throw/drop sound effects' volume, 0..1 (was a bool)
var set_fullscreen := false  # borderless fullscreen (also toggled live with F11)

# --- procedural audio (code-only, ART_AND_MUSIC.md): pre-rendered PCM buffers,
# adaptive music by volume-automating looping layers. See setup_audio().
const AUDIO_SR := 22050
var _audio_ready := false
var sfx: Dictionary = {}            # name -> AudioStreamWAV one-shot
var sfx_pool: Array = []            # AudioStreamPlayer round-robin for one-shots
var _sfx_next := 0
# the game's music is Louis's own recorded track (the second deliberate exception
# to the code-only art rule, alongside the font). One looping stream, and the game
# rides its VOLUME per state: full while a performance cooks, easy in menus, a
# hush under cutscenes, a dip on a drop. All in-game SFX stay procedural.
# SHIP BLOCKER (see ART_AND_MUSIC.md Section 7): this file is a free-tier Suno
# render, non-commercial only, until Louis re-renders it under a paid Suno
# subscription and replaces this file under the same name. Do not release a
# build to anyone outside personal testing while this warning is still here.
const MUSIC_PATH := "res://Juggling Game.mp3"
# a second track (Louis) for every non-juggling moment - menus, the day hub, the
# establishing cards, results. The two crossfade: the driving track only while you
# actually juggle, this calmer Chill Trio mix everywhere else.
const MUSIC_PATH_CHILL := "res://Juggling Game (Chill Trio Mix).mp3"
var mus: AudioStreamPlayer
var mus2: AudioStreamPlayer
var _vol := {"mus": -80.0, "mus2": -80.0}
var _mix := 0.0   # handover position: 0 = the Chill Trio mix carries it, 1 = the stage track
var _main_silent := true   # the stage track sits at zero gain: restart it from the top
						   # (its opening bars) the next time the handover brings it in
var _duck := 0.0                    # transient music dip on a drop, decays

# the game's one typeface (ART doc 6): Nunito at a steady semibold weight, warm
# and humane with clear numerals. The single .ttf in fonts/ is the one deliberate
# exception to the code-only art rule. Falls back to the engine font if missing.
var ui_font: Font = null

# previous-frame button states, for edge detection
var _prev := {"lc": false, "lt": false, "rc": false, "rt": false, "trick": false, "cycle": false}

# key-DOWN taps captured straight from the event stream (see _latch_tap). A press
# and release that both fall inside one physics tick are invisible to the state
# poll in _read_inputs, but the event still lands here, so the poll can never drop
# a catch or throw. Consumed and cleared each read; seeded empty at run start.
var _tap := {"lc": false, "lt": false, "rc": false, "rt": false, "trick": false}

# gamepad state. _trig holds the latched trigger states for hysteresis, so a
# noisy analog trigger cannot flutter a throw release. _pad_last remembers which
# device spoke most recently, so the on-screen hints can follow it. _joy_held
# guards against duplicate joypad press events, which have no echo flag.
var _trig := {"lt": false, "rt": false}
var _pad_last := false
var _joy_held := {}
var _stick_dir := {}      # per-axis latch for left-stick menu steps (see _input):
						  # -1 / 0 / +1, so one push is one step, never a stream

# dev-only: headless auto-player + one-frame screenshot
var _demo := false
var _demo_trick := false  # dev: the auto-player also performs tricks, to screenshot them
var _demo_trick_pin := -1 # dev: --trick <id> pins ONE trick (so toggles and held arm
						  # tricks can be watched); -1 alternates High Toss / BTB + Spin
var _demo_hold := 7       # dev: --hold <n> sets the auto-player's throw hold (0..44)
var _collcheck := false   # dev: --collcheck measures the tightest mid-air clearance
						  # of the session (throw inaccuracy zeroed, so it audits the
						  # IDEAL pattern geometry), printed on the --shot capture
var _coll_min := 1000000.0  # dev: min clearance seen (px between prop EDGES; <0 = overlap)
var _coll_at := ""          # dev: where/when the minimum happened, for diagnosis
var _handlog := false       # dev: --handlog prints each hand's x every tick during play,
							  # to tell a real jitter (oscillating x) from a hand that merely
							  # sits still but far from the ball's lane (ROADMAP 12b)
var _eggdemo := false     # dev: repeatedly break an egg, to screenshot the effect
var _shot := false
var _shot_path := ""
var _shot_tick := 170
var _shot_frames := 0
var _calib := false        # dev: --calib prints the autoplayer's score at _calib_ticks, then quits
var _calib_ticks := 3600   # 30 sim-seconds by default (deterministic ticks, not real time)
var _demo_next := RIGHT
const DEMO_BEAT := 28


#endregion

#region STARTUP
func setup_font() -> void:
	# one clean humane face at semibold, set up as a FontVariation so the single
	# variable-weight file serves every size. If the file is ever missing the
	# engine fallback quietly takes over and nothing breaks.
	var base: Variant = load("res://fonts/Nunito.ttf")
	if base is Font:
		var fv := FontVariation.new()
		fv.base_font = base
		fv.variation_opentype = {"wght": 600}
		ui_font = fv


func game_font() -> Font:
	return ui_font if ui_font != null else ThemeDB.fallback_font


func _ready() -> void:
	# Dev-only flags. Normal play passes NONE of these: the game then simply waits
	# for the player's first THROW and never auto-plays or auto-quits.
	#   --demo         run the headless auto-player (for verifying choreography)
	#   --shot <path>  capture one frame to <path> then quit
	var ua := OS.get_cmdline_user_args()
	load_settings()
	setup_font()
	# a pad can arrive or vanish at any moment, and vanishing mid-set must pause
	Input.joy_connection_changed.connect(_on_joy_connection)
	if set_fullscreen and not ua.has("--shot"):
		apply_fullscreen()                       # honour the remembered display mode
												 # (a --shot capture run stays at the
												 # windowed 1280x720 design size, so
												 # screenshots are comparable and a
												 # dev capture never seizes the display)
	setup_audio()                                # synthesise all sound at startup
	hpos = [outer_pos(LEFT), outer_pos(RIGHT)]   # idle hands for the title screen
	if not OS.is_debug_build():
		# a real release export (what ships to players): none of the dev flags
		# below can ever parse, no matter what a player passes on the command
		# line. --debug in particular grants free stat editing and story-jump
		# shortcuts, which must never be reachable in a shipped build. Editor
		# runs and debug-template exports (this project's own screenshot and
		# test workflow) are unaffected, since is_debug_build() is true there.
		game_state = ST_MENU
		return
	if ua.has("--demo"):
		_demo = true
	if ua.has("--debug"):   # debug build: free stat editing (uses a separate save)
		debug_mode = true
	var si := ua.find("--shot")
	if si != -1 and si + 1 < ua.size():
		_shot = true
		_shot_path = ua[si + 1]
	var sa := ua.find("--shotat")   # dev: capture at frame N (to test late transitions)
	if sa != -1 and sa + 1 < ua.size():
		_shot_tick = int(ua[sa + 1])
	var da := ua.find("--dumpaudio")             # dev: write every sound to <dir>, then quit
	if da != -1 and da + 1 < ua.size():
		dump_audio(ua[da + 1])
		get_tree().quit()
		return

	# Dev/test flags jump straight into play; a normal launch opens the main menu.
	if ua.has("--collcheck"):   # dev: audit the ideal pattern for mid-air overlap. Read
		_collcheck = true       # early: it stands alone, and it runs fine under --headless
	if ua.has("--handlog"):     # dev: log hand x every tick (ROADMAP 12b jitter diagnosis)
		_handlog = true
	var skip_menu := _demo or _shot or _collcheck or _handlog or debug_mode or ua.has("--sheet") or ua.has("--shop") or ua.has("--results") or ua.has("--pause") or ua.has("--day") or ua.has("--stats")
	if ua.has("--menu"):
		skip_menu = false
	if skip_menu:
		save_slot = 0
		load_progress()
		var start_n := 3
		var bi := ua.find("--balls")   # dev: force the ball count (audit 4- and 6-ball fountains)
		if bi != -1 and bi + 1 < ua.size():
			strength = maxi(strength, int(BALL_GATES[MAX_BALLS_HARD]))   # every count open
			prop_count[PROP_BALLS] = maxi(prop_count[PROP_BALLS], MAX_BALLS_HARD)   # balls are stock now
			start_n = clampi(int(ua[bi + 1]), MIN_BALLS, MAX_BALLS_HARD)
		var vfi := ua.find("--venue")   # dev: play at venue N (0..6), so booking targets and
		if vfi != -1 and vfi + 1 < ua.size():   # patience decay match that stage (calibration + shots)
			var vn := clampi(int(ua[vfi + 1]), 0, MAX_VENUE)
			if vn >= MAX_VENUE:
				won = true   # The Midnight Show also gates on `won`, not Reputation alone
			reputation = VENUE_REP[vn]
			venue_pick = vn
		var pfi := ua.find("--prop")    # dev: juggle prop N (0..5) with enough owned + Strength
		if pfi != -1 and pfi + 1 < ua.size():
			var pn := clampi(int(ua[pfi + 1]), 0, PROPS.size() - 1)
			prop_type = pn
			prop_count[pn] = maxi(prop_count[pn], MAX_BALLS_HARD)
			strength = maxi(strength, int(PROPS[pn]["req"]))
		start_run(start_n)
		game_state = ST_PLAY
		if ua.has("--demo"):    # dev: the auto-player performs, so we can see the booking HUD
			mode = MODE_PERFORM
		if ua.has("--booking"):   # dev: run a REAL act (rolls a challenge), for shots and --calib.
			# --encore <id> pins the condition.
			booking_active = true
			goals_hit = 0
			encore = roll_encore(run_venue)
			var eni := ua.find("--encore")
			if eni != -1 and eni + 1 < ua.size():
				for ek in ENCORES.size():
					if String(ENCORES[ek]["id"]) == ua[eni + 1]:
						encore = ek
		var ci := ua.find("--calib")   # dev: print the autoplayer's score at N ticks, then quit,
		if ci != -1:                   # to tune VENUE_BASE against real strong-player numbers
			_calib = true
			if ci + 1 < ua.size() and not ua[ci + 1].begins_with("--"):
				_calib_ticks = maxi(120, int(ua[ci + 1]))
		var pi := ua.find("--pattern")   # dev: force a pattern for screenshots, e.g. --pattern shower
		if pi != -1 and pi + 1 < ua.size():
			for pj in PATTERNS.size():
				if String(PATTERNS[pj]["id"]) == ua[pi + 1]:
					dev_meet_req(PATTERNS[pj])   # composite reqs now: floor every axis it asks
					pattern_sel = pj
					start_run(num_balls)
		var tri := ua.find("--trick")   # dev: unlock every trick and let the auto-player
		if tri != -1:                   # show them off. An optional id (--trick high)
			_demo_trick = true          # pins that one trick, so toggles can be watched
			for tj in TRICKS.size():
				dev_meet_req(TRICKS[tj])
			if tri + 1 < ua.size() and not ua[tri + 1].begins_with("--"):
				for tj in TRICKS.size():
					if String(TRICKS[tj]["id"]) == ua[tri + 1]:
						_demo_trick_pin = tj
			if ua.has("--unlock"):   # dev: also show the new-trick banner
				trick_unlock = TR_SPIN
				trick_unlock_tick = 0
		var hoi := ua.find("--hold")    # dev: the auto-player's hold per throw (0..44),
		if hoi != -1 and hoi + 1 < ua.size():   # to verify held heights on screenshots
			_demo_hold = clampi(int(ua[hoi + 1]), 0, HOLD_MAX)
		if ua.has("--collide"):     # dev: force the hard-collisions toggle ON this session
			set_collide = true
		if ua.has("--glow"):        # dev: own the Glow Kit this session, for Blackout shots
			has_glow_kit = true
		if ua.has("--sheet"):   # dev: open the character sheet for a screenshot
			points = maxi(points, 6)
			sheet_open = true
		if ua.has("--shop"):    # dev: open the shop for a screenshot
			shop_open = true
		if ua.has("--results"):   # dev: fabricate a finished act to screenshot the card
			mode = MODE_PERFORM
			run_venue = 4
			goals_hit = 3             # a complete night, for the card's header and grade
			caught = 214; dropped = 3; best_streak = 132; score = 951875
			peak_applause = 0.94; tricks_landed = 11; trick_score = 42600
			last_pay = 6996; last_rep_delta = 60; run_xp = 1240; points = 3
			started = true; running = false; results_open = true; results_record = true
			results_tick = 0
		if ua.has("--pause"):   # dev: open the pause menu for a screenshot
			open_pause()
	else:
		game_state = ST_MENU
	if ua.has("--settings"):    # dev: screenshot the settings screen
		game_state = ST_SETTINGS
	if ua.has("--slots"):       # dev: screenshot the save-slot screen
		game_state = ST_SLOTS
	if ua.has("--remap"):       # dev: screenshot the controls screen (--remap pad
		game_state = ST_REMAP   # focuses the gamepad column instead of keyboard)
		if ua.has("--pad"):
			remap_col = 1
	if ua.has("--capsule"):     # dev: pure key-art for the Steam store, no UI chrome
		game_state = ST_CAPSULE
	var ti := ua.find("--tutorial")   # dev: jump into a hands-on lesson, e.g. --tutorial balls
	if ti != -1:
		var id := ua[ti + 1] if ti + 1 < ua.size() and not ua[ti + 1].begins_with("--") else "balls"
		begin_tutorial(id)
	var ei := ua.find("--establish")  # dev: screenshot a venue exterior card, e.g. --establish 3.
	if ei != -1:                      # add --booking (and optionally --encore) to show the
		establish_venue = int(ua[ei + 1]) if ei + 1 < ua.size() else 2   # act's goals/challenge panel
		if ua.has("--booking"):
			booking_active = true
			run_venue = establish_venue
			goals_hit = 0
			encore = roll_encore(run_venue)
			var eei := ua.find("--encore")
			if eei != -1 and eei + 1 < ua.size():
				for ek2 in ENCORES.size():
					if String(ENCORES[ek2]["id"]) == ua[eei + 1]:
						encore = ek2
		game_state = ST_ESTABLISH
		cine_tick = 0
	if ua.has("--credits"):           # dev: jump straight to the credits roll for a screenshot
		game_state = ST_CREDITS
		cine_tick = 0
	if ua.has("--stats"):             # dev: the records-and-history screen, for a screenshot
		game_state = ST_STATS
		cine_tick = 0
	if ua.has("--gameover"):          # dev: the road's-end screen, for a screenshot
		game_state = ST_GAMEOVER
		cine_tick = 0
	if ua.has("--tutdone"):           # dev: the basics-lesson congrats card, for a screenshot
		game_state = ST_TUTDONE
		cine_tick = 0
	if ua.has("--day"):               # dev: jump straight to the day hub for a screenshot
		enter_day()
	if ua.has("--skills"):            # dev: open the Skills reference for a screenshot
		level = maxi(level, 7)        # enough unlocked that both ready and locked show
		money = maxi(money, 100)
		stamina = stamina_max
		enter_day()
		skills_open = true
		skills_sel = 0
	if ua.has("--eggbreak"):          # dev: exercise the egg-break effect on the stage
		_eggdemo = true
		prop_type = PROP_EGGS
		game_state = ST_PLAY


#endregion

#region MAIN LOOP & INPUT ROUTING
func _physics_process(delta: float) -> void:
	# every screen fades in on arrival: detected passively here (game_state is SET
	# from dozens of places - menu_input, day_input, results dismissal, and more -
	# so watching for the change in one place beats touching every call site)
	if game_state != _fade_prev_state:
		_fade_prev_state = game_state
		_state_fade_t = 0
	elif _state_fade_t < STATE_FADE_FRAMES:
		_state_fade_t += 1
	audio_update()   # pick the music theme and glide the layer volumes, every state
	if _shot or _collcheck or _handlog:
		_shot_frames += 1   # advances even while paused, so we can capture the sheet
		if _shot_frames >= _shot_tick:
			_capture_and_quit()
			return
	if game_state != ST_PLAY:
		cine_tick += 1           # drives the stage card, menu, and hub motion
		if game_state == ST_DAY and day_anim != "":
			day_anim_step()          # a hub vignette is playing; its effect lands at the end
		if _demo and game_state == ST_ESTABLISH and cine_tick > 40:
			establish_key()          # dev: the autoplayer dismisses each set's card, so
									 #      --demo --booking runs a whole booking end to end
		queue_redraw()
		return
	if sheet_open or shop_open or paused:
		if sheet_open and debug_mode:
			sheet_repeat(delta)   # debug build only: holding a stat key keeps stepping it
		queue_redraw()   # the sheet, shop, and pause menu all halt the sim; nothing advances
		return
	if freeze > 0:
		# hit-stop: the world holds its breath for a few ticks so a drop lands with
		# weight. Input is still read (a press during the hold acts on the held world,
		# never lost) and the hands keep easing, but tick and the sim do not advance.
		freeze -= 1
		if not _demo:
			_read_inputs()
		update_hands()
		queue_redraw()
		return
	# SLOW MOTION (ideas.rtf): the sim advances by FRACTIONAL ticks while real
	# time flows on, so every catch window stretches in the player's hands. Input
	# polls every real frame so slow motion can never eat a press. Sources stack
	# (Speed stat, Uncle Dan's Pie, an Amazing! catch, ten straight Perfects) and
	# the rate floors at 0.12: near-frozen, never stopped.
	_frames += 1
	if not _demo:
		_read_inputs()
	_slow_cur = move_toward(_slow_cur, slow_target(), SLOW_RAMP)
	if _slow_cur > 0.001:
		_tick_acc += maxf(1.0 - _slow_cur, 0.12)
		if _tick_acc < 1.0:
			update_hands()
			queue_redraw()
			return
		_tick_acc -= 1.0
	tick += 1
	if _calib and (tick >= _calib_ticks or collapsing):
		# the calibration verdict: what a strong player (the fixed-metronome autoplayer)
		# scores before the crowd walks - or in _calib_ticks if it never does - at this
		# venue / prop / count. Quitting AT the collapse captures the true reachable score,
		# since after a collapse the halted-sim autoplayer keeps zombie-feeding itself.
		var wt := goal_for(run_venue, 0)
		var reason := "COLLAPSE" if collapsing else "time"
		print("CALIB venue=%d prop=%d n=%d hold=%d end=%s tick=%d score=%d caught=%d streak=%d appl=%.2f  goal1=%d clears=%s" % [
			run_venue, prop_type, num_balls, _demo_hold, reason, tick, score, caught, best_streak, applause, wt, str(score >= wt)])
		get_tree().quit()
		return
	step_effects()   # age the egg-break shards, yolk splats, and particles
	if results_open:
		results_anim_sfx()   # the card's count-up ticks, stamp, and record fanfare
	if _eggdemo and tick % 42 == 0:
		var vp := get_viewport_rect().size
		spawn_egg_break(Vector2(vp.x * 0.5 + randf_range(-140, 140), vp.y * 0.42))
	if _demo:
		_demo_step()
	if running:
		update_sim()
	if collapsing and running and balls_airborne() == 0 and falling.is_empty():
		collapsing = false
		running = false   # the last prop has landed: only NOW may the verdict arrive
	if _prev_running and not running and not tut_active:
		on_round_end()   # the run just ended: bank the completion XP (never mid-lesson)
	_prev_running = running
	if tut_active:
		tut_maintain()   # advance the lesson and keep the hands stocked
	update_hands()
	age_popups()
	# screen shake decays toward rest (uses cosmetic RNG so the sim stays deterministic)
	if shake > 0.2:
		position = Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
		shake *= 0.82
	elif position != Vector2.ZERO:
		position = Vector2.ZERO
	queue_redraw()


func _input(event: InputEvent) -> void:
	# both devices funnel into one keycode here, so every per-screen match below
	# serves keyboard and pad identically with zero duplicated navigation code.
	var kc: int = -1
	if event is InputEventKey:
		var ek := event as InputEventKey
		if not (ek.pressed and not ek.echo):
			return
		kc = ek.physical_keycode
		_pad_last = false
		# the controls screen, while listening on the KEYBOARD column, captures the
		# next keyboard key as the new binding (Esc cancels, F11 stays fullscreen)
		if game_state == ST_REMAP and remap_wait and remap_col == 0:
			remap_wait = false
			if kc != KEY_ESCAPE and kc != KEY_F11:
				bind_action(String(REMAP_ACTS[remap_sel][0]), kc)
				play_sfx("ui2", -12.0)
			return
	elif event is InputEventJoypadButton:
		# joypad events carry no echo flag, so a held table drops any duplicate
		# press a driver might deliver while the button is already down
		var jb := event as InputEventJoypadButton
		var held := bool(_joy_held.get(jb.button_index, false))
		_joy_held[jb.button_index] = jb.pressed
		if not jb.pressed or held:
			return
		# the controls screen, while listening on the GAMEPAD column, captures the
		# next RAW pad button as the new binding (Start cancels, mirrors Esc/F11
		# above) - captured here, before _pad_to_key's translation, so the exact
		# physical button gets bound rather than whatever it currently means
		if game_state == ST_REMAP and remap_wait and remap_col == 1:
			remap_wait = false
			if jb.button_index != JOY_BUTTON_START:
				bind_pad_action(String(PAD_ACTS[pad_remap_sel][0]), jb.button_index)
				play_sfx("ui2", -12.0)
			return
		_pad_last = true
		kc = _pad_to_key(jb.button_index)
		if kc == -1:
			return
	elif event is InputEventJoypadMotion:
		# BOTH STICKS steer every list exactly like the arrows (Louis: the sticks
		# move the focus of the selected option in menus). Each axis latches: a push
		# past 0.6 fires ONE step and holds until the stick eases back under 0.35,
		# so drift near centre can never scroll a menu and holding the stick does
		# not machine-gun the cursor. The live sim ignores them entirely (throw and
		# catch are buttons, and a stick brushed mid-juggle must not do anything).
		var jm := event as InputEventJoypadMotion
		if jm.axis != JOY_AXIS_LEFT_X and jm.axis != JOY_AXIS_LEFT_Y \
				and jm.axis != JOY_AXIS_RIGHT_X and jm.axis != JOY_AXIS_RIGHT_Y:
			return
		var dir := 0
		if jm.axis_value > 0.6:
			dir = 1
		elif jm.axis_value < -0.6:
			dir = -1
		elif absf(jm.axis_value) < 0.35:
			_stick_dir[jm.axis] = 0
			return
		else:
			return   # the hysteresis band: keep whatever the latch already holds
		if int(_stick_dir.get(jm.axis, 0)) == dir:
			return   # still held the same way: the step already fired
		_stick_dir[jm.axis] = dir
		if _pad_sim_live():
			return
		_pad_last = true
		if jm.axis == JOY_AXIS_LEFT_X or jm.axis == JOY_AXIS_RIGHT_X:
			kc = KEY_RIGHT if dir > 0 else KEY_LEFT
		else:
			kc = KEY_DOWN if dir > 0 else KEY_UP
	else:
		return
	if kc == KEY_F11:
		# fullscreen toggle, available from every screen, remembered across launches
		set_fullscreen = not set_fullscreen
		apply_fullscreen()
		save_settings()
		return
	match game_state:
		ST_MENU:
			menu_input(kc)
			return
		ST_SLOTS:
			slots_input(kc)
			return
		ST_SETTINGS:
			settings_input(kc)
			return
		ST_STATS:
			if kc == KEY_ESCAPE or kc == KEY_ENTER or kc == KEY_KP_ENTER:
				game_state = ST_SETTINGS
				play_sfx("ui", -12.0)
			return
		ST_REMAP:
			remap_input(kc)
			return
		ST_GAMEOVER:
			if cine_tick > 90:   # a beat of stillness before the page can turn
				reset_new_game()   # the career is over: the slot starts fresh
				game_state = ST_MENU
				menu_sel = 0
				play_sfx("ui", -12.0)
			return
		ST_TUTDONE:
			# the congrats card reads itself out for a beat, then any key begins the day
			if cine_tick > 40 and kc in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE]:
				enter_day()
				set_day_msg("your first day begins  -  the stage is yours")
				play_sfx("ui2", -11.0)
			return
		ST_ESTABLISH:
			establish_key()
			return
		ST_CREDITS:
			credits_key()
			return
		ST_DAY:
			day_input(kc)
			return
	# ST_PLAY only past here. Latch a live-play action key straight from the
	# buffered event stream, so a tap too brief for the state poll in _read_inputs
	# still registers (see _latch_tap). Skipped while the sim is halted (paused /
	# sheet / shop / results), where reads do not run (or are ignored) and a latch
	# would otherwise fire stale on resume.
	if not paused and not sheet_open and not shop_open and not results_open:
		_latch_tap(kc)
	# the in-play pause menu owns all input while it is up
	if paused:
		pause_input(kc)
		return
	# during a hands-on lesson the command keys are locked, so no stray press can break
	# it into a normal run, a panel, or a prop swap. The juggling itself - throw, catch,
	# Space - stays live (polled in _read_inputs). Only the lesson's own keys act here:
	# R re-deals the step, P completes a pattern lesson's "P is the pattern key" step,
	# and Escape pauses. (This is the ONE lesson key handler - a second, later block
	# used to shadow this and left R dead inside lessons.)
	if tut_active:
		if kc == K_CYCLE and tut_id.begins_with("trick_"):
			cycle_trick()   # C is part of a trick lesson's teaching, so it stays live
			return          # (the next Space re-pins the taught trick regardless)
		match kc:
			KEY_ENTER, KEY_KP_ENTER:
				tut_advance()   # a met goal holds open until the player says done
			KEY_R:
				if String(tut_step_data().get("goal", "")) == "press_r":
					tut_demo_reset()   # the step IS the reset key: show it, count it
				else:
					tut_reset_step()
			KEY_P:
				if String(tut_step_data().get("goal", "")) == "press_p":
					tut_demo_pattern_off()   # the step IS the pattern key: show the swap
			KEY_ESCAPE:
				open_pause()
		return
	# the end-of-performance results panel: go again with R (another booking, so
	# it costs a fresh day segment), spend/shop, or Enter/Esc back into the day.
	# It stays open behind the sheet and shop, so you can invest then continue.
	if results_open and not sheet_open and not shop_open:
		match kc:
			KEY_R, KEY_SPACE:
				if not too_tired():
					# "go again" books a WHOLE fresh booking (a new establishing card and a
					# new Encore), not a bare set, so it costs a day segment like any booking
					seg_used += 1
					save_progress()
					results_open = false
					begin_performance(num_balls)
				else:
					play_sfx("whiff", -10.0)   # out of stamina: sleep first (the
											   # card's footer says so in words)
			KEY_TAB:
				sheet_open = true
			KEY_S:
				shop_open = true
			KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE:
				results_open = false
				# clearing the top stage this set rolls straight into the victory
				# screen; otherwise the card dismisses back into the day as normal
				if pending_win:
					pending_win = false
					game_state = ST_CREDITS
					cine_tick = 0
				else:
					enter_day()
		return
	# ST_PLAY: the existing in-game handling below
	if sheet_open:
		sheet_input(kc)
		return
	if shop_open:
		shop_input(kc)
		return
	# a performance cannot be reset or rebuilt mid-set: no restart, no ball-count
	# change, no prop swap, no bailing to practice. That would make a good ending
	# trivial to fish for. You either FINISH cleanly (Enter) or drop out, and you
	# only try again from the results card afterwards. Training stays freely resettable.
	var performing := mode == MODE_PERFORM
	if kc == K_CYCLE:
		cycle_trick()   # which trick the TRICK key is loaded with (remappable, so not in the match)
		return
	match kc:
		KEY_TAB:
			sheet_open = true
		KEY_S:
			shop_open = true
		KEY_ENTER, KEY_KP_ENTER:
			if performing:
				finish_performance()   # end the set on a high note, no drop needed
			else:
				# practice over: Enter steps back into the day - and BANKS the round
				# first (Louis: practice grants XP too). The completion bonus used to
				# fire only on the running->false edge, so leaving mid-run with Enter
				# quietly ate it; a round already over has already banked, so the
				# running check keeps this from paying the same round twice.
				if running and not tut_active:
					running = false
					_prev_running = false
					on_round_end()
				enter_day()
		KEY_R:
			if not performing:
				start_run(num_balls)
		# ([ and ] used to step the count too, but they are unreachable on AZERTY
		# and other layouts (Louis: "they don't work, nor should they"). ONE key
		# per count (3-9, 0, minus) worked up to eleven, but ran out of number row
		# at fifteen (2026-07-18: the cap rose after the throw-height clamp made
		# room for more objects) - 1/2 STEP the count by one instead (2026-07-18,
		# Louis: Minus/Equal were "bad choices" - swapped for 1 and 2, free here
		# since the shop/sheet/pause handlers that also read the number row all
		# gate and return well above this match). Both target functions clamp to
		# [3, max_balls()] on their own, so stepping past either end is always a
		# safe no-op, not an error.
		KEY_1:
			if performing: set_count_live(num_balls - 1)
			else: start_run(num_balls - 1)
		KEY_2:
			if performing: set_count_live(num_balls + 1)
			else: start_run(num_balls + 1)
		KEY_O:
			# switch the object either way: live during a performance (re-skins the
			# props in play, keeps the run), or with a fresh deal in practice
			if performing:
				cycle_prop_live(1)
			else:
				cycle_prop(1)
		KEY_P:
			if performing:
				cycle_pattern_live(1)   # switch the routine live, mid-performance
			else:
				cycle_pattern()   # step the juggling pattern (re-deals the hands)
		KEY_F1:
			if debug_mode: debug_jump_venue(0)   # debug: F1..F7 jump reputation to venues 1..7
		KEY_F2:
			if debug_mode: debug_jump_venue(1)
		KEY_F3:
			if debug_mode: debug_jump_venue(2)
		KEY_F4:
			if debug_mode: debug_jump_venue(3)
		KEY_F5:
			if debug_mode: debug_jump_venue(4)
		KEY_F6:
			if debug_mode: debug_jump_venue(5)
		KEY_F7:
			if debug_mode: debug_jump_venue(6)   # The Midnight Show (also forces `won`)
		KEY_ESCAPE:
			open_pause()


func _pad_sim_live() -> bool:
	# is the juggling sim the thing the pad is talking to right now? While it is,
	# the polled play actions own their buttons (Y = trick) and the event path must
	# stay out of their way; every panel over the sim hands them back.
	return game_state == ST_PLAY and not paused and not results_open and not sheet_open and not shop_open


func _pad_to_key(btn: int) -> int:
	# translate a recognised pad button into the keycode the per-screen matches
	# already understand. -1 means the button has no meaning on this screen.
	# LOUIS'S LAYOUT, 2026-07-18 SWAP: bumpers throw (F / J), triggers catch (D / K)
	# - both polled in _read_inputs, not here - and A <-> B, X <-> Y swapped from
	# the original scheme: A = Enter (confirm / finish / take a bow), B = Escape
	# (back / the game menu), Y = Tab (the sheet), X = TRICK (remappable, see
	# PAD_TRICK), and the dpad carries the four letter commands while playing: up O
	# (object), right P (pattern), down S (shop), left R (restart). In menus the
	# dpad falls back to arrows and the STICKS move the focus, so navigation never
	# fights the play commands.
	if game_state == ST_SLOTS and btn == JOY_BUTTON_X:
		return KEY_X   # delete the highlighted save slot - X keeps this one job here,
						# where it isn't already claimed by TRICK
	if btn == PAD_TRICK:
		# while the sim is live this is the POLLED trick button (see _read_inputs)
		# and must not double-fire here; everywhere else it doubles as Space
		if _pad_sim_live():
			return -1
		return KEY_SPACE
	if btn == PAD_CYCLE:
		return K_CYCLE   # which trick TRICK is loaded with - previously had no
						  # pad button at all; now remappable alongside PAD_TRICK
	match btn:
		JOY_BUTTON_DPAD_UP:
			return KEY_O if game_state == ST_PLAY else KEY_UP
		JOY_BUTTON_DPAD_DOWN:
			return KEY_S if game_state == ST_PLAY else KEY_DOWN
		JOY_BUTTON_DPAD_LEFT:
			return KEY_R if game_state == ST_PLAY else KEY_LEFT
		JOY_BUTTON_DPAD_RIGHT:
			return KEY_P if game_state == ST_PLAY else KEY_RIGHT
		JOY_BUTTON_A:
			return KEY_ENTER    # bottom face: confirm / finish / take a bow (swapped)
		JOY_BUTTON_B:
			return KEY_ESCAPE   # right face: back / the game menu (swapped)
		JOY_BUTTON_Y:
			return KEY_TAB      # top face: the sheet / menu (swapped)
		JOY_BUTTON_START:
			# Start also pauses inside play, the one habit every pad player has
			return KEY_ESCAPE if game_state == ST_PLAY else -1
		JOY_BUTTON_BACK:
			# the load-count step keys (2026-07-18): a pad previously had NO way at
			# all to change the count. Back/R3 were the two guaranteed-universal
			# buttons left unclaimed (every bumper/trigger/face button/dpad
			# direction/L3 already means something else in Louis's layout). The
			# keyboard side moved from Minus/Equal to 1/2, but the virtual key these
			# route to is what the count handler itself matches on, so it moves too.
			return KEY_1 if game_state == ST_PLAY else -1
		JOY_BUTTON_RIGHT_STICK:
			return KEY_2 if game_state == ST_PLAY else -1
	return -1


func _notification(what: int) -> void:
	# a performance must never die to a missed alt-tab: losing window focus mid-set
	# auto-pauses instead of letting the sim keep draining stamina unattended.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if _demo or _shot:
			return   # unattended dev captures may lose focus; they must keep running
		if game_state == ST_PLAY and started and running and not paused and not sheet_open and not shop_open and not results_open:
			open_pause()


func _on_joy_connection(_device: int, connected: bool) -> void:
	# a set must never die to a dead pad battery. losing the pad mid-performance
	# auto-pauses, mirroring the focus-loss guard above, and the hints fall back
	# to the keyboard names because the pad can no longer speak.
	if connected:
		return
	_pad_last = false
	if _demo or _shot:
		return
	if game_state == ST_PLAY and started and running and not paused and not sheet_open and not shop_open and not results_open:
		open_pause()


#endregion

#region PAUSE & PERFORMANCE FLOW
func open_pause() -> void:
	paused = true
	pause_sel = 0
	play_sfx("ui", -12.0)


func pause_input(kc: int) -> void:
	match kc:
		KEY_UP:
			pause_sel = (pause_sel + 2) % 3
			play_sfx("ui", -16.0)
		KEY_DOWN:
			pause_sel = (pause_sel + 1) % 3
			play_sfx("ui", -16.0)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			pause_activate()
		KEY_1:
			pause_sel = 0; pause_activate()
		KEY_2:
			pause_sel = 1; pause_activate()
		KEY_3:
			pause_sel = 2; pause_activate()
		KEY_ESCAPE, KEY_P:
			paused = false
			play_sfx("ui2", -14.0)


func pause_activate() -> void:
	match pause_sel:
		0:   # resume the run right where it froze
			paused = false
			play_sfx("ui2", -14.0)
		1:   # end the session and step back out into the day (clears any panels).
			# `collapsing` clears too: leaving a mid-collapse set through this menu
			# used to carry the latch into the NEXT session, where it silenced every
			# polled key (the "space does nothing in the lesson" bug, Louis)
			paused = false
			tut_active = false
			results_open = false
			sheet_open = false
			shop_open = false
			collapsing = false
			enter_day()
			play_sfx("ui", -12.0)
		2:   # leave the game
			get_tree().quit()


func finish_performance() -> void:
	# CASH IN. The finish key always ends the act gracefully - you catch what you
	# have and bow, the crowd stays happy, nothing falls - and the whole score is
	# kept (a collapse is what strips it back to the last goal). Catching every ball
	# and holding them fires this same function from on_catch, so the two cash-in
	# gestures Louis asked for are one path. Clearing running fires on_round_end from
	# the running->false edge, where resolve_act() settles the night.
	if mode != MODE_PERFORM or not running or tut_active:
		return
	play_sfx("streak", -6.0)   # a short rising flourish to close the act
	running = false


func begin_performance(n: int) -> void:
	# an act opens on an establishing shot of WHERE you are about to play, the way a
	# film cuts to the outside of the building before the scene inside. The act's one
	# optional challenge is rolled here, so the card can announce it up front.
	mode = MODE_PERFORM
	establish_after = n
	establish_venue = play_venue()
	pattern_once = -1   # an act always performs the pattern the player chose with P
	booking_active = true
	goals_hit = 0
	# one challenge for the WHOLE act (Louis: never a different condition per phase),
	# rolled with the global randi (never the sim rng, so the deterministic catch
	# sequence is untouched). The Backyard stays pure: no conditions on stage one.
	encore = roll_encore(play_venue())
	game_state = ST_ESTABLISH
	cine_tick = 0


func establish_key() -> void:
	game_state = ST_PLAY
	start_run(establish_after)   # the card dismissed: walk out and begin the act


# --- act maths: the three goals, the deck's live effects, the drop limit -----

#endregion

#region ACT GOALS & ENCORES
func goal_for(venue: int, gi: int) -> int:
	# goal number gi (0 first, 1 second, 2 final), scaling off the VENUE and the
	# standing ante, never off the player's own record (scaling off your best would
	# punish you for improving). A challenge that stretches the night (The Long Set)
	# stretches only the FINAL goal - the hardest number is the one it makes harder.
	var base := float(VENUE_BASE[clampi(venue, 0, VENUE_BASE.size() - 1)])
	var step := float(GOAL_STEP[clampi(gi, 0, GOAL_STEP.size() - 1)])
	var a := 1.0 + ANTE_STEP * float(ante[clampi(venue, 0, ante.size() - 1)])
	var enc := encore_target_mult() if gi == NUM_GOALS - 1 else 1.0
	return int(round(base * step * a * enc))


func next_goal() -> int:
	# the first goal the act has NOT yet reached, or the final goal once all have
	# fallen (the meter then shows a full bar, not a moving one)
	return goal_for(run_venue, clampi(goals_hit, 0, NUM_GOALS - 1))


func roll_encore(venue: int) -> int:
	# a random challenge for the whole act - never on the Backyard (venue 0), the one
	# pure lesson stage - and otherwise fair game, EXCEPT "For the Danger" (only clubs/
	# knives/torches score), which needs a floor of its own (2026-07-18, Louis: it
	# rolled before he could even afford a club, so the act was unscoreable start to
	# finish). It is now excluded from the pool below The Circus (venue 3) AND unless
	# the player owns ENOUGH of a qualifying prop to actually field the smallest real
	# routine - MIN_BALLS (3), not just one (Louis caught this: owning a single club
	# is not enough to switch to and juggle it at all, let alone score with it).
	if venue < 1:
		return -1
	var pool: Array[int] = []
	for i in ENCORES.size():
		if String(ENCORES[i]["id"]) == "fire" and (venue < 3 \
				or (have(PROP_CLUBS) < MIN_BALLS and have(PROP_KNIVES) < MIN_BALLS and have(PROP_TORCHES) < MIN_BALLS)):
			continue
		pool.append(i)
	if pool.is_empty():
		return -1
	return int(pool[randi() % pool.size()])


func encore_on(id: String) -> bool:
	# is THIS act's challenge the named one? A challenge colours the WHOLE act - one
	# condition from the first throw to the bow (Louis). -1 means a clean night, which
	# is every Backyard night and any venue the roll spared.
	return booking_active and mode == MODE_PERFORM \
		and encore >= 0 and encore < ENCORES.size() and String(ENCORES[encore]["id"]) == id


func encore_decay_mult() -> float:
	# how fast the crowd's patience bleeds this set: The Hecklers double it, The Long
	# Set halves it (a patient crowd for a marathon target)
	if encore_on("hecklers"):
		return 2.0
	if encore_on("long"):
		return 0.5
	return 1.0


func encore_target_mult() -> float:
	return 2.0 if encore_on("long") else 1.0


func encore_score_mult() -> float:
	# For the Danger: only heavy props (clubs and up) score, so a crowd that came for
	# danger cannot be satisfied with balls. A run uses one prop, so the current prop's
	# weight decides the whole set.
	if encore_on("fire") and prop_weight() < 3:
		return 0.0
	return 1.0


func drop_limit() -> int:
	# three drops and the crowd turns. The Understudy lowers it to one.
	if encore_on("understudy"):
		return 1
	return DROP_LIMIT


# =============================================================================
# The day hub (GDD 4.5): a juggler's life between performances. A day holds
# SEG_PER_DAY action segments. Performing and practicing each spend one, eating
# and the shop are quick, sleep ends the day and restores stamina. Everything
# here is texture and pacing around the juggling, never a new difficulty axis,
# so the skill-first guardrails are untouched.
# =============================================================================

func play_venue() -> int:
	# the stage you CHOSE to play tonight, never above what reputation unlocks
	return clampi(venue_pick, 0, venue_index())


func too_tired() -> bool:
	# STAMINA is the day's limiter now (Louis: the day is spent when you have no
	# strength left, not when a counter says so). Work as long as you can stand.
	return stamina < TIRED_FLOOR


func check_dead_end() -> void:
	# the survival check. A meal (EAT_COST) always lifts you back over the
	# tiredness floor, so the road only truly ends when you are too tired to
	# work AND too poor for both the bed and the dinner that would save you.
	# Warned about at every purchase, but if it lands, it lands.
	if too_tired() and money < INN_COST and money < EAT_COST and game_state == ST_DAY:
		game_state = ST_GAMEOVER
		cine_tick = 0


func seg_name() -> String:
	# the day's beats (Louis): wake to DAYLIGHT, work into NIGHT and DEEP NIGHT.
	# ("daylight" not "day": next to the day NUMBER it read as a stutter, "day 1,
	# day".) The clock is flavour; only running out of STAMINA says sleep.
	if too_tired():
		return "time to sleep"
	var names := ["daylight", "night", "deep night"]
	return names[clampi(seg_used, 0, 2)]


func next_venue_rep() -> int:
	# the Reputation the NEXT stage opens at, or 0 when there is nowhere higher
	# left to climb (mirrors venue_index_of's ladder). At the World Arena this
	# names The Midnight Show's Reputation gate, though that stage also needs
	# `won` - close enough as a hint (by the time Reputation alone gets there,
	# a win is generally close behind).
	var steps := [100, 300, 700, 1500, 3000, 6000]
	var vi := venue_index()
	return int(steps[vi]) if vi < steps.size() else 0


#endregion

#region DAY HUB LOGIC
func enter_day() -> void:
	game_state = ST_DAY
	day_sel = 0
	day_msg = ""
	view_venue = -1
	cine_tick = 0
	pattern_once = -1   # a Skills-practice pattern was for that session only
	# came off the stage SPENT: land the cursor on the first recovery you can afford
	# (a meal, else the inn) and say so, so the player is steered to it, not left guessing
	if exhausted:
		exhausted = false
		var rows := day_rows()
		var want := "eat" if money >= EAT_COST and stamina < stamina_max - 1.0 else "inn"
		for i in rows.size():
			if String(rows[i]["id"]) == want:
				day_sel = i
				break
		set_day_msg("your hands gave out  -  eat or sleep to get them back")
	reward_director()   # a stuck player gets a nudge, a gift, or an unlock - never a wall
	save_progress()
	check_dead_end()   # broke AND spent on arrival: the road ends here


func reward_director() -> void:
	# THE REWARD DIRECTOR (Louis): rewards are SPREAD - a new stage always pays (the
	# venue-gated arrival skills in TRICKS/PATTERNS), and when the road between
	# stages runs dry too long, help arrives instead of nothing:
	#   - a long drought with no unlock gifts the nearest walled skill outright
	#   - a broke player finds a pie at the door (at most one a day), so the next
	#     act can still be earned rather than lost to the spiral
	#   - the once-per-career meal rescue keeps empty-stamina-and-broke from being
	#     the end of the road while any of this is still being learned
	# It runs on ARRIVING at the hub, so a gift is always found standing up, never
	# shoved into a set. Practice is the promoted answer for a stuck player: it
	# costs no crowd, grants XP (same as a stage since this batch), and the pity
	# message says so in words.
	if perfs_since_unlock >= 6:
		pity_grant()
	if money < 30 and pie_count == 0 and not pie_active and day != aid_pie_day:
		aid_pie_day = day
		pie_count += 1
		set_day_msg("a fan left a pie at your door  -  eat it before a big night")
		play_sfx("coin", -10.0)
	elif stamina <= 0.15 * stamina_max and money < EAT_COST and not aid_meal_used:
		aid_meal_used = true
		stamina = clampf(0.6 * stamina_max, stamina, stamina_max)
		set_day_msg("a stranger paid for your meal  -  it will not happen twice")
		play_sfx("coin", -10.0)


func pity_grant() -> void:
	# six acts without a single new skill: gift the LOCKED skill nearest its wall,
	# provided its STAGE requirement is already met (the venue-gated arrival skills
	# stay sacred - they are what makes reaching a stage feel like reaching it).
	# "Nearest" is the smallest total shortfall across level, Strength and Accuracy,
	# so the gift is always the thing the player was visibly working toward.
	var best_id := ""
	var best_name := ""
	var best_gap := 1 << 30
	for tab: Array in [TRICKS, PATTERNS]:
		for d: Dictionary in tab:
			var id := String(d.get("id", ""))
			if skill_req_met(d) or venue_index() < int(d.get("ven", 0)):
				continue
			var gap := maxi(0, int(d.get("lvl", 1)) - level) \
				+ maxi(0, int(d.get("str", 0)) - strength) \
				+ maxi(0, int(d.get("acc", 0)) - accuracy)
			if gap < best_gap:
				best_gap = gap
				best_id = id
				best_name = String(d.get("name", id))
	if best_id == "":
		return   # nothing giftable: every remaining wall is a stage, which is right
	gifted.append(best_id)
	perfs_since_unlock = 0
	announce_unlocks()   # queues the lesson and the banner through the normal path
	set_day_msg("all that stage time paid off  -  %s just clicked. Practice is free, and it pays XP." % best_name)


func set_day_msg(m: String) -> void:
	day_msg = m
	day_msg_tick = cine_tick


func day_rows() -> Array[Dictionary]:
	# the hub's actions with their live enabled state and the reason when not.
	# built fresh every frame and every keypress so drawing and input always agree.
	var vname := String(venue_data(play_venue())["name"])
	var out: Array[Dictionary] = []
	# a queued lesson sits at the TOP of the hub, so a new unlock is the first thing you
	# see and can choose to learn - it never yanks you out of a set, and costs no day time
	if not pending_tuts.is_empty():
		out.append({"id": "learn", "name": "LEARN  -  %s" % lesson_title(pending_tuts[0]),
			"cost": "", "ok": true, "why": "",
			"sub": "something new. Taught slow, one step at a time. Costs no time."})
	var tired := too_tired()
	var tired_why := "too tired to work (stamina under %d)  -  sleep first" % int(TIRED_FLOOR)
	out.append({"id": "perform", "name": "PERFORM  at  %s" % vname,
		"cost": "", "ok": not tired,
		"why": tired_why if tired else "",
		"sub": "gold and reputation, while stamina lasts. P books it PURIST."})
	out.append({"id": "practice", "name": "PRACTICE",
		"cost": "", "ok": not tired,
		"why": tired_why if tired else "",
		"sub": "no crowd, no pay. Work as long as you can stand."})
	var full := stamina >= stamina_max - 1.0
	var can_eat := money >= EAT_COST and not full
	var eat_why := ""
	if money < EAT_COST:
		eat_why = "not enough gold"
	elif full:
		eat_why = "not hungry yet"
	out.append({"id": "eat", "name": "EAT",
		"cost": "%d gold" % EAT_COST, "ok": can_eat, "why": eat_why,
		"sub": "stamina back. Every third meal adds Strength."})
	out.append({"id": "inn", "name": "SLEEP  at the inn",
		"cost": "%d gold" % INN_COST, "ok": money >= INN_COST,
		"why": "not enough gold  -  the innkeeper does not haggle" if money < INN_COST else "",
		"sub": "ends the day, wake fully rested. Keep %d gold aside or the road ends." % INN_COST})
	if pie_count > 0:
		out.append({"id": "pie", "name": "EAT  Uncle Dan's Pie",
			"cost": "own %d" % pie_count, "ok": not pie_active, "why": "one is already working" if pie_active else "",
			"sub": "a stimulant slice: the whole day runs a quarter slower, until you sleep."})
	out.append({"id": "shop", "name": "SHOP",
		"cost": "", "ok": true, "why": "",
		"sub": "props and gear. New props teach themselves."})
	out.append({"id": "skills", "name": "SKILLS",
		"cost": "", "ok": true, "why": "",
		"sub": "every trick and pattern you know, and how to pull it off."})
	return out


func day_input(kc: int) -> void:
	# the sheet, shop, and skills overlays keep their usual keys while open over the hub
	if sheet_open:
		sheet_input(kc)
		return
	if shop_open:
		shop_input(kc)
		return
	if skills_open:
		skills_input(kc)
		return
	if day_anim != "":
		return   # a little vignette is playing; the hub listens again when it ends
	check_dead_end()   # a shop spree can strand you; the road ends the moment it is true
	if game_state != ST_DAY:
		return
	var rows := day_rows()
	var n := rows.size()
	match kc:
		KEY_UP, KEY_W:
			day_sel = (day_sel + n - 1) % n
			play_sfx("ui", -14.0)
		KEY_DOWN, KEY_S:
			day_sel = (day_sel + 1) % n
			play_sfx("ui", -14.0)
		KEY_LEFT, KEY_RIGHT:
			# choosing tonight's stage is free, any venue reputation has unlocked.
			# The picker STOPS at both ends (Louis: left to right, never wrapping).
			if String(rows[day_sel]["id"]) == "perform":
				var dir := 1 if kc == KEY_RIGHT else -1
				var np := clampi(play_venue() + dir, 0, venue_index())
				if np != play_venue():
					venue_pick = np
					play_sfx("ui2", -14.0)
		KEY_P:
			# book tonight PURIST: the pure-skill ladder with its own records
			purist = not purist
			set_day_msg("tonight is a PURIST set  -  no stat help, its own records" if purist else "back to the assisted board")
			save_progress()
			play_sfx("ui2", -13.0)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			day_activate(String(rows[day_sel]["id"]), bool(rows[day_sel]["ok"]), String(rows[day_sel]["why"]))
		KEY_TAB:
			sheet_open = true
			play_sfx("ui2", -13.0)
		KEY_ESCAPE:
			save_progress()
			game_state = ST_MENU
			menu_sel = 0
			play_sfx("ui", -12.0)


func day_activate(id: String, ok: bool, why: String) -> void:
	if not ok:
		set_day_msg(why)
		play_sfx("whiff", -10.0)
		return
	match id:
		"perform":
			seg_used += 1
			save_progress()
			begin_performance(num_balls)
			play_sfx("ui2", -11.0)
		"practice":
			seg_used += 1
			career["practices"] = int(career["practices"]) + 1
			save_progress()
			mode = MODE_TRAIN
			game_state = ST_PLAY
			start_run(num_balls)
			play_sfx("ui2", -11.0)
		"eat", "inn":
			# these two open with a small vignette; the effect lands when it
			# ends. Dinner that would break the bed money asks first.
			if id == "eat" and not confirm_spend("eat", EAT_COST, false):
				return
			day_anim = id
			day_anim_start = cine_tick
			play_sfx("ui2", -13.0)
		"shop":
			# the counter opens the moment you ask for it (Louis: the awning
			# vignette between the press and the shop was dead time)
			shop_open = true
			play_sfx("ui2", -13.0)
		"pie":
			pie_count -= 1
			pie_active = true
			set_day_msg("the pie hums in your blood  -  the world runs slow until you sleep")
			save_progress()
			play_sfx("ui2", -11.0)
		"skills":
			skills_open = true          # a reference card, no cost, no vignette
			skills_sel = 0
			play_sfx("ui2", -13.0)
		"learn":
			# drain one queued lesson and teach it now. Marked seen BEFORE teaching, and
			# saved, so it is remembered as taught even if the player quits mid-lesson.
			if not pending_tuts.is_empty():
				var lid: String = pending_tuts[0]
				pending_tuts.remove_at(0)
				if not seen_tuts.has(lid):
					seen_tuts.append(lid)
				save_progress()
				begin_tutorial(lid)
				play_sfx("ui2", -11.0)


func day_anim_len(id: String) -> int:
	match id:
		"inn": return 220
		"eat": return 150
		_: return 100


func day_anim_step() -> void:
	# the little vignette has finished: NOW the action actually happens, so the
	# picture always leads and the ledger follows
	if cine_tick - day_anim_start < day_anim_len(day_anim):
		return
	var id := day_anim
	day_anim = ""
	match id:
		"eat":
			money -= EAT_COST
			play_sfx("money", -9.0)   # gold on the counter
			stamina = minf(stamina_max, stamina + EAT_STAM * stamina_max)
			meals += 1
			if meals % MEALS_PER_STR == 0 and strength < STR_CAP:
				var prev_max := max_balls()
				strength += 1
				check_ball_unlock(prev_max)   # a meal's Strength can cross a ball gate too
				set_day_msg("the good food is paying off  -  Strength +1")
				play_sfx("streak", -8.0)
			else:
				set_day_msg("a hot meal, stamina restored a little")
		"inn":
			money -= INN_COST   # full price, always (the row blocks when short)
			play_sfx("money", -9.0)
			sleep_day()


func sleep_day() -> void:
	# the day turns over: segments refill and stamina comes back full. Sleeping
	# rough was cut (Louis): the inn is the only bed, full price, full rest.
	day += 1
	seg_used = 0
	pie_active = false   # the pie's clarity wears off with sleep
	career["days"] = maxi(int(career["days"]), day)
	stamina = stamina_max
	set_day_msg("day %d  -  you wake rested" % day)
	play_sfx("streak", -9.0)
	save_progress()


#endregion

#region SHEET / SHOP / SKILLS INPUT
func sheet_input(kc: int) -> void:
	# the character sheet's keys, shared by the play overlay and the day hub.
	# Arrows (dpad, stick) walk the four cards and Enter invests in the lit one,
	# so a pad spends points as freely as the number keys do; a number key also
	# pulls the cursor onto its card, so the highlight always shows what just paid.
	var ids := ["acc", "str", "end", "spd"]
	match kc:
		KEY_TAB, KEY_ESCAPE:
			sheet_open = false
		KEY_LEFT:
			sheet_sel = (sheet_sel + ids.size() - 1) % ids.size()
			play_sfx("ui", -15.0)
		KEY_RIGHT:
			sheet_sel = (sheet_sel + 1) % ids.size()
			play_sfx("ui", -15.0)
		KEY_ENTER, KEY_KP_ENTER:
			_sheet_invest(ids[sheet_sel])
		KEY_1:
			sheet_sel = 0
			_sheet_invest("acc")
		KEY_2:
			sheet_sel = 1
			_sheet_invest("str")
		KEY_3:
			sheet_sel = 2
			_sheet_invest("end")
		KEY_4:
			sheet_sel = 3
			_sheet_invest("spd")
		KEY_Q:
			if debug_mode: _adjust("acc", -1)
		KEY_W:
			if debug_mode: _adjust("str", -1)
		KEY_E:
			if debug_mode: _adjust("end", -1)
		KEY_R:
			if debug_mode: _adjust("spd", -1)
		KEY_M:
			if debug_mode:
				money += 50
				save_progress()
		KEY_N:
			if debug_mode:
				money = maxi(0, money - 50)
				save_progress()
		KEY_PERIOD:
			if debug_mode:   # raise reputation to preview later venues/costumes
				reputation += 250
				save_progress()
		KEY_COMMA:
			if debug_mode:
				reputation = maxi(0, reputation - 250)
				save_progress()


func shop_buy_sel() -> void:
	# Enter (pad A) acts on whichever card the cursor lights: a prop, the glasses,
	# the pie, or the Glow Kit - the same purchases the number keys reach directly
	if shop_sel <= 5:
		try_buy(shop_sel)
	elif shop_sel == 6:
		try_buy_glasses()
	elif shop_sel == 7:
		try_buy_pie()
	else:
		try_buy_glow_kit()


func shop_input(kc: int) -> void:
	# the shop's keys, shared by the play overlay and the day hub. The number on
	# each card is its buy key: 1-6 the props (balls included), 7 glasses, 8 pie,
	# 9 the Glow Kit. Arrows (dpad, stick) walk the cards - left/right along a row,
	# up/down between the six-card prop row and the three-card gear row (each pair
	# of prop columns hops to the gear card below it) - and Enter buys the lit
	# one, so a pad shops as freely as the keyboard. A number key also pulls the
	# cursor onto its card.
	match kc:
		KEY_TAB, KEY_ESCAPE, KEY_S:
			shop_open = false
		KEY_LEFT:
			shop_sel = (shop_sel + 8) % 9
			play_sfx("ui", -15.0)
		KEY_RIGHT:
			shop_sel = (shop_sel + 1) % 9
			play_sfx("ui", -15.0)
		KEY_DOWN, KEY_UP:
			if shop_sel <= 5:
				shop_sel = 6 + shop_sel / 2   # props 0-1/2-3/4-5 -> gear 6/7/8
			else:
				shop_sel = (shop_sel - 6) * 2   # gear 6/7/8 -> props 0/2/4
			play_sfx("ui", -15.0)
		KEY_ENTER, KEY_KP_ENTER:
			shop_buy_sel()
		KEY_1:
			shop_sel = 0
			try_buy(PROP_BALLS)
		KEY_2:
			shop_sel = 1
			try_buy(PROP_EGGS)
		KEY_3:
			shop_sel = 2
			try_buy(PROP_RINGS)
		KEY_4:
			shop_sel = 3
			try_buy(PROP_CLUBS)
		KEY_5:
			shop_sel = 4
			try_buy(PROP_KNIVES)
		KEY_6:
			shop_sel = 5
			try_buy(PROP_TORCHES)
		KEY_7:
			shop_sel = 6
			try_buy_glasses()
		KEY_8:
			shop_sel = 7
			try_buy_pie()
		KEY_9:
			shop_sel = 8
			try_buy_glow_kit()


func skills_input(kc: int) -> void:
	# the Skills reference: browse every trick and pattern. Up/Down walk the whole
	# list (tricks then patterns), Left/Right jump between the two columns.
	var n := TRICKS.size() + PATTERNS.size()
	match kc:
		KEY_UP, KEY_W:
			skills_sel = (skills_sel + n - 1) % n
			play_sfx("ui", -15.0)
		KEY_DOWN, KEY_S:
			skills_sel = (skills_sel + 1) % n
			play_sfx("ui", -15.0)
		KEY_LEFT, KEY_A:
			skills_sel = mini(skills_sel, TRICKS.size() - 1)   # into the tricks column
			play_sfx("ui", -15.0)
		KEY_RIGHT, KEY_D:
			skills_sel = maxi(skills_sel, TRICKS.size())        # into the patterns column
			play_sfx("ui", -15.0)
		KEY_ENTER, KEY_KP_ENTER:
			practice_skill(skills_sel)   # drop into a practice with this skill on
		KEY_TAB, KEY_ESCAPE:
			skills_open = false
			play_sfx("ui", -13.0)


func practice_skill(idx: int) -> void:
	# Enter on a Skills entry books a PRACTICE with that skill already engaged, so a
	# trick (or pattern) can be drilled straight from where it is explained (Louis).
	# Costs a day segment like any practice; a locked skill or an empty tank refuses.
	var is_trick := idx < TRICKS.size()
	# the Skills screen lists patterns in UNLOCK order (pattern_order), so a
	# pattern row index translates back to the raw PATTERNS index here
	var pat := -1 if is_trick else int(pattern_order()[idx - TRICKS.size()])
	if is_trick and not trick_unlocked(idx):
		set_day_msg("that trick asks for %s" % skill_req_text(TRICKS[idx]))
		play_sfx("whiff", -10.0)
		return
	if not is_trick and not pattern_unlocked(pat):
		set_day_msg("that pattern asks for %s" % skill_req_text(PATTERNS[pat]))
		play_sfx("whiff", -10.0)
		return
	if too_tired():
		set_day_msg("too tired to practise  -  sleep first")
		play_sfx("whiff", -10.0)
		return
	# a pattern needs a matching ball count (an even fountain, odd cascade); a trick
	# keeps the current count. The pattern rides the ONE-SESSION override, never
	# pattern_sel: trying a pattern from the Skills screen must not re-book the act
	# (Louis) - only P, the player's own hand, changes the persistent choice.
	if not is_trick:
		pattern_once = pat
	skills_open = false
	seg_used += 1
	career["practices"] = int(career["practices"]) + 1
	save_progress()
	mode = MODE_TRAIN
	game_state = ST_PLAY
	# the fountain reads even: borrow one more ball for the session so choosing it
	# from the Skills screen actually shows a fountain (start_run clamps safely)
	var run_n := num_balls
	if pattern_once == FOUNTAIN and run_n % 2 == 1:
		run_n += 1
	start_run(run_n)
	# now engage the chosen trick (start_run has cleared the per-run trick state):
	# a toggle switches ON and stays, an arm trick primes the next throw, Spin just
	# loads. The player still throws to begin, so nothing fires unbidden.
	if is_trick:
		trick_sel = idx
		var kind := String(TRICKS[idx]["kind"])
		if kind == "toggle":
			toggle_on = idx
			toggle_scored = false
			set_trick_msg("%s ON  -  practising" % String(TRICKS[idx]["name"]).to_upper())
		elif kind == "arm":
			trick_primed = true
			set_trick_msg("%s  -  next throw" % String(TRICKS[idx]["name"]).to_upper())
		else:
			set_trick_msg("%s selected  -  %s performs it" % [String(TRICKS[idx]["name"]), k_trick()[0]])
	else:
		set_trick_msg("%s  -  %s" % [String(PATTERNS[pattern]["name"]).to_upper(), String(PATTERNS[pattern]["desc"])])
	play_sfx("ui2", -11.0)


#endregion

#region LIVE PROP / PATTERN / COUNT SWITCHING
func cycle_prop(dir: int) -> void:
	# step to the next prop you own enough of, and restart with it (per-run setting)
	var n := PROPS.size()
	var k := prop_type
	for _i in n:
		k = (k + dir + n) % n
		if available(k):
			prop_type = k
			break
	start_run(num_balls)


func cycle_prop_live(dir: int) -> void:
	# switch objects mid-performance WITHOUT restarting (Louis): the props already in
	# play are re-skinned to the new object and the run, score and streak carry on.
	# The new weight and spin take effect on the next throw. Only objects you own
	# enough of for the CURRENT load are offered.
	var n := PROPS.size()
	var need := maxi(MIN_BALLS, balls.size())
	var found := -1
	var k := prop_type
	for _i in n:
		k = (k + dir + n) % n
		if k != prop_type and have(k) >= need:
			found = k
			break
	if found < 0:
		set_trick_msg("no other object you own %d of" % need)
		play_sfx("late", -12.0)
		return
	prop_type = found
	var i := 0
	for b in balls:
		b.kind = prop_type
		b.color = ball_color(i) if prop_type == PROP_BALLS else prop_color(prop_type)
		b.spin_dir = 1.0 if i % 2 == 0 else -1.0
		i += 1
	set_trick_msg(String(PROPS[prop_type]["name"]).to_upper())
	play_sfx("ui2", -13.0)


func set_count_live(n: int) -> void:
	# change the LOAD mid-performance without restarting (Louis): extra props are
	# handed in from offstage into a hand no ball is flying toward, and removing
	# props takes HELD ones away. The run, score and streak carry on; the streak
	# cap and object mult simply follow the new count from here.
	n = clampi(n, MIN_BALLS, max_balls())
	if n == balls.size():
		return
	if have(prop_type) < n:
		set_trick_msg("you own %d of those  -  the shop sells more" % have(prop_type))
		play_sfx("late", -12.0)
		return
	while balls.size() < n:
		var to_h := -1
		for hh in [LEFT, RIGHT]:
			var busy := false
			for b in balls:
				if b.state == STATE_FLIGHT and b.to_hand == hh:
					busy = true
					break
			if not busy and (to_h < 0 or stack(hh).size() < stack(to_h).size()):
				to_h = hh
		if to_h < 0:
			set_trick_msg("hands are busy  -  try again between catches")
			play_sfx("late", -12.0)
			break
		var nb := Ball.new()
		nb.state = STATE_HAND
		nb.kind = prop_type
		nb.color = ball_color(balls.size()) if prop_type == PROP_BALLS else prop_color(prop_type)
		nb.spin_dir = 1.0 if balls.size() % 2 == 0 else -1.0
		balls.append(nb)
		stack(to_h).append(nb)
	while balls.size() > n:
		var from_h := LEFT if stack(LEFT).size() >= stack(RIGHT).size() else RIGHT
		if stack(from_h).is_empty():
			set_trick_msg("everything is in the air  -  catch one first")
			play_sfx("late", -12.0)
			break
		var gone: Ball = stack(from_h).pop_back()
		balls.erase(gone)
	num_balls = balls.size()
	# the lane bookkeeping re-seeds for the new count (a middle lane may appear
	# or vanish); Tennis keeps its mark unless that very ball just left the stage
	col_air_ref = -1.0
	col_mid_ball = null
	if tennis_ball != null and not balls.has(tennis_ball):
		tennis_ball = null
	set_trick_msg("%d OBJECTS" % num_balls)
	play_sfx("ui2", -13.0)


func cycle_pattern_live(dir: int) -> void:
	# switch the routine mid-performance WITHOUT restarting: like a trick toggle, the
	# new pattern simply shapes every throw from here on. Balls already in flight keep
	# their own paths; the lane bookkeeping resets so Columns starts clean.
	var un: Array = []
	for i in pattern_order():
		if pattern_unlocked(i):
			un.append(i)
	if un.size() <= 1:
		set_trick_msg("the next pattern (Columns) asks for %s" % skill_req_text(PATTERNS[COLUMNS]))
		return
	pattern_once = -1   # the player's own hand on P ends any Skills-practice override
	var idx := un.find(pattern_sel)
	pattern_sel = int(un[(idx + dir + un.size()) % un.size()]) if idx >= 0 else int(un[0])
	pattern = pattern_sel
	col_air_ref = -1.0
	col_mid_ball = null
	tennis_ball = null   # Tennis re-marks its ball on the first throw under it
	set_trick_msg("%s  -  %s" % [String(PATTERNS[pattern_sel]["name"]).to_upper(), String(PATTERNS[pattern_sel]["desc"])])
	play_sfx("ui2", -13.0)


func confirm_spend(id: String, cost: int, in_shop: bool) -> bool:
	# any purchase that would leave tonight's bed unaffordable asks ONCE before
	# it goes through (Louis: warn anywhere the player can strand themselves,
	# because no bed and no strength to busk is the end of the road)
	if money - cost >= INN_COST:
		return true
	var now := int(Time.get_ticks_msec())
	if _confirm_id == id and now - _confirm_ms < 4000:
		_confirm_id = ""
		return true
	_confirm_id = id
	_confirm_ms = now
	var wtext := "careful  -  that leaves you short of the inn (%d gold). press again to spend anyway" % INN_COST
	if in_shop:
		shop_msg = wtext
		shop_msg_ms = now
	else:
		set_day_msg(wtext)
	play_sfx("late", -8.0)
	return false


func try_buy(kind: int) -> void:
	# buy one more of a prop; you can stock as many as you can afford
	var cost := int(PROPS[kind]["cost"])
	if money >= cost:
		if not confirm_spend("prop%d" % kind, cost, true):
			return
		var was := available(kind)
		money -= cost
		prop_count[kind] += 1
		shop_buy_ms = int(Time.get_ticks_msec())
		save_progress()
		play_sfx("money", -6.0)
		if not was and available(kind):
			offer_prop_tutorial(kind)   # first time you can juggle these: explain them


func offer_prop_tutorial(kind: int) -> void:
	# the first time a new prop becomes juggle-able, queue its hands-on lesson. It is
	# routed through the same queue every other unlock uses, so the hub's LEARN row
	# offers it (rather than yanking the player out of the shop mid-purchase).
	queue_lesson("prop_%d" % kind)


# =============================================================================
# Interactive tutorials. Unlike a cutscene, a lesson runs on the REAL sim: the
# player throws and catches actual balls, guided one step at a time, and each
# step advances only once its goal is met. Fired when something unlocks: a fresh
# save teaches the 1-ball basics (then 2, then 3), and buying a new prop teaches
# that prop. There is no menu entry; lessons arrive when they are relevant.
# =============================================================================

#endregion

#region TUTORIAL SYSTEM
func tut_lesson(id: String) -> Array:
	if id.begins_with("prop_"):
		var k := int(id.substr(5))
		var quirks := {
			PROP_EGGS: "They throw like balls, but a drop breaks for good, so keep your hands soft.",
			PROP_RINGS: "Heavier than balls, so they hang a touch longer. Catch them by the rim.",
			PROP_CLUBS: "These tumble in the air. Catch the handle, not the spin, so read the rotation.",
			PROP_KNIVES: "Fast and sharp, with less room for error. Endurance keeps your hands honest.",
			PROP_TORCHES: "The heaviest, lit and roaring. They ask for real Strength and a steady nerve.",
		}
		var quirk := String(quirks.get(k, "A new prop. Feel out its weight and timing."))
		var need := 6 if k == PROP_TORCHES else 5
		return [{"prop": k, "balls": 3, "hand": RIGHT, "goal": "catch", "need": need,
			"text": "New prop: %s" % String(PROPS[k]["name"]), "sub": "%s Land %d clean catches." % [quirk, need]}]
	if id.begins_with("trick_"):
		return trick_lesson_steps(trick_by_id(id.substr(6)))
	if id.begins_with("count_"):
		return count_lesson_steps(int(id.substr(6)))
	if id.begins_with("pattern_"):
		return pattern_lesson_steps(pattern_by_id(id.substr(8)))
	# THE BASICS, in two halves (reworked per Louis, who watched real people play it):
	#
	#   1. GUIDED. Deepest slow motion the sim has, one key at a time, named at the exact
	#      moment it wants pressing - press J, now press D - with the ring on the hand
	#      showing what "now" means. These steps FLOW: they carry themselves to the next
	#      beat the instant they are done, because a scripted call-and-response that stops
	#      to ask for Enter is not a call-and-response.
	#   2. FREESTYLE. One ball, then two, then three, each held open for as long as the
	#      player likes. Here - and ONLY here - Enter means something, and it means one
	#      thing: give me another ball. Everyone tested got the juggling immediately and
	#      then sat there, because the old lesson asked for Enter after every step and so
	#      Enter had stopped meaning anything. Now it appears three times, it always adds
	#      a ball, and the callout grows louder the longer it goes unanswered.
	#
	# The two-ball and three-ball steps gate on REAL juggling (the "juggle" key): catches
	# that leave the air empty behind them do not count toward the goal, so nobody walks
	# out of the basics having only ever thrown one ball at a time. Key names come from
	# the live bindings, so a remapped player is taught THEIR keys, and every step still
	# names them (Louis: never assumed remembered).
	var kj := OS.get_keycode_string(K_RT)
	var kf := OS.get_keycode_string(K_LT)
	var kd := OS.get_keycode_string(K_LC)
	var kk := OS.get_keycode_string(K_RC)
	# the ADAPTIVE pace (Louis): the guided steps are pinned at the 50% cap; every
	# freestyle step reads the TUT_PACES ladder instead, so clean runs speed the world
	# up (50 - 25 - 15 - 0%) and drops give thick time back. The finale only counts at
	# the ladder's floor: ten catches of a real cascade at genuine full speed.
	return [
		# --- guided: the right hand's half of the weave, one key at a time ---
		{"prop": PROP_BALLS, "balls": 1, "hand": RIGHT, "goal": "catch", "need": 1,
			"slow": TUT_SLOW_START, "flow": true, "guide": true,
			"text": "Press %s, then press %s" % [kj, kd],
			"sub": "%s throws from your RIGHT hand. The ball crosses to your LEFT, and a ring closes around that hand as it arrives - press %s the moment the ring flashes gold. Time is running at half speed, so watch it come." % [kj, kd]},
		# --- guided: the left hand's half, so both hands are taught before anything else ---
		{"prop": PROP_BALLS, "balls": 1, "hand": LEFT, "goal": "catch", "need": 1,
			"slow": TUT_SLOW_START, "flow": true, "guide": true,
			"text": "Now the other way: %s, then %s" % [kf, kk],
			"sub": "Every hand has its own two keys. %s throws from the LEFT, %s catches in the RIGHT. Same ring, same gold flash, same 'now'." % [kf, kk]},
		# --- freestyle one: just the feel of one ball, hand to hand ---
		{"prop": PROP_BALLS, "balls": 1, "hand": RIGHT, "goal": "catch", "need": 4,
			"next": "add a second ball",
			"text": "Now play with it",
			"sub": "Both hands, as long as you like: %s and %s throw, %s and %s catch. Clean catches speed the world up, a drop slows it back down." % [kj, kf, kd, kk]},
		# --- freestyle two: BOTH balls start stacked in one hand, so throw, throw,
		#     catch, catch is the only sequence physically available - the player is
		#     always juggling by construction, never scolded into it (Louis). The
		#     throws CROSS (a forced cascade), rehearsing the weave three will ask for.
		#     No "juggle" gate: the second catch of every pair always lands with
		#     nothing else airborne, which is exactly the point of this drill, not
		#     a failure of it - the finale is where that rule gets strict.
		{"prop": PROP_BALLS, "balls": 2, "hand": RIGHT, "goal": "catch", "need": 4,
			"pattern": CASCADE, "next": "add the third ball",
			"text": "Two balls - throw, throw, catch, catch",
			"sub": "Both start stacked in one hand. %s throws the first, %s throws the second BEFORE it lands - now catch them as they arrive. That handover, one ball crossing right after the other, is the whole weave three balls will ask for." % [kj, kj]},
		# --- the finale: a real cascade, ten catches, at genuine full speed ---
		{"prop": PROP_BALLS, "balls": 3, "hand": RIGHT, "goal": "catch", "need": 10,
			"juggle": true, "finale": true, "next": "learn the other keys",
			"text": "Three balls. The cascade",
			"sub": "As each ball comes down, throw the one waiting in that hand up under it FIRST, then catch. Clean catches keep speeding the world up - once it reaches FULL SPEED, land ten in a row. That is juggling, for real."},
		# --- R, drilled rather than described: it is the key that rescues every tangle.
		#     Named through k_restart, so a pad player is taught THEIR button ---
		{"prop": PROP_BALLS, "balls": 3, "hand": RIGHT, "goal": "press_r", "need": 1,
			"next": "see every key at once",
			"text": "Tangled? %s starts you over" % String(k_restart()[0]),
			"sub": "Press %s now and watch the balls come back to your hands. In any practice it re-deals - on stage it does nothing, because a performance is not restartable." % String(k_restart()[0])},
		# --- and the whole command set, named, in one place ---
		{"prop": PROP_BALLS, "balls": 3, "hand": RIGHT, "goal": "read", "need": 0,
			"next": "finish the lesson",
			"text": "Every key you have",
			"sub": "These work whenever you are juggling - practice or performance. You never need to memorise them: the row along the bottom of the screen always names the ones that matter."},
	]


const TRICK_TUT_SLOW := 0.55   # flat, generous slow motion for every trick-lesson step
								# (2026-07-18, Louis: "too cumbersome... don't break it
								# down into hundreds of small steps, that's only for the
								# first tutorial") - a trick lesson teaches ONE new button,
								# not the input system itself, so there is nothing to build
								# UP to across steps and no reason to ramp the world back
								# toward real speed the way the basics lesson does.

func trick_lesson_steps(t: int) -> Array:
	# a trick lesson mirrors the three INPUT GRAMMARS the game has, because the grammar
	# is what confuses people, not the trick: a toggle switches on and off, an arm shot
	# empowers one throw, a live trick acts on what is already in the air. Taught with
	# plain balls (the trick shaping is prop-independent), slow throughout, shown once
	# clearly and asked for only a couple of times - never a graduated drill.
	if t < 0 or t >= TRICKS.size():
		return [{"prop": PROP_BALLS, "balls": 3, "hand": RIGHT, "goal": "catch", "need": 3,
			"text": "Keep the cascade going", "sub": "Land three."}]   # defensive: never index []
	var td: Dictionary = TRICKS[t]
	var nm := String(td["name"])
	var kb := String(k_trick()[0])
	var kcy := String(k_cycle()[0])
	match String(td["kind"]):
		"toggle":
			return [
				{"prop": PROP_BALLS, "balls": 3, "hand": RIGHT, "goal": "trick_on", "need": 1,
					"trick": t, "prompt": "trick", "slow": TRICK_TUT_SLOW,
					"text": "%s: switch it ON" % nm,
					"sub": "Press %s ONCE - not repeatedly. Every throw reshapes into %s until you switch it off." % [kb, nm]},
				{"prop": PROP_BALLS, "balls": 3, "hand": RIGHT, "goal": "catch", "need": 2,
					"prompt": "catch", "slow": TRICK_TUT_SLOW,
					"text": "Now catch a couple of them",
					"sub": "Watch the weave change shape. The bottom-right card reads '%s - ON' whenever it runs." % nm.to_upper()},
				{"prop": PROP_BALLS, "balls": 3, "hand": RIGHT, "goal": "trick_off", "need": 1,
					"trick": t, "prompt": "trick", "slow": TRICK_TUT_SLOW,
					"text": "And switch it OFF",
					"sub": "Press %s once more. One press ON, one press OFF - that is the whole toggle. %s swaps which trick %s carries." % [kb, kcy, kb]},
			]
		"arm":
			return [
				{"prop": PROP_BALLS, "balls": 3, "hand": RIGHT, "goal": "trick_use", "need": 1,
					"trick": t, "prompt": "trick", "slow": TRICK_TUT_SLOW,
					"text": "%s: arm it, then throw" % nm,
					"sub": "Press %s once, then throw. Just that ONE next throw flies over the top, and it lands the trick." % kb},
				{"prop": PROP_BALLS, "balls": 3, "hand": RIGHT, "goal": "trick_use", "need": 2,
					"trick": t, "prompt": "trick", "slow": TRICK_TUT_SLOW,
					"text": "Once more - it is a one-shot, so arm it every time",
					"sub": "%s, throw, catch - each trick is its own press. The bottom-right card says READY while one is armed; %s swaps tricks." % [kb, kcy]},
			]
		_:  # live (Spin): acts on the balls already airborne
			return [
				{"prop": PROP_BALLS, "balls": 3, "hand": RIGHT, "goal": "catch", "need": 2,
					"prompt": "catch", "slow": TRICK_TUT_SLOW,
					"text": "First get all three weaving",
					"sub": "%s acts on the balls already in the air, so fill the air before you call it." % nm},
				{"prop": PROP_BALLS, "balls": 3, "hand": RIGHT, "goal": "trick_use", "need": 1,
					"trick": t, "prompt": "trick", "slow": TRICK_TUT_SLOW,
					"text": "Now press it, and catch through the turn",
					"sub": "Press %s once - it fires the moment you press. Catches come while you spin; the bottom-right card shows its cooldown. %s swaps tricks." % [kb, kcy]},
			]


func count_lesson_steps(n: int) -> Array:
	# a new ball count: a slow drill to feel the higher, faster load, then a faster one.
	# The pattern is left to the parity default (odd -> cascade, even -> fountain).
	return [
		{"prop": PROP_BALLS, "balls": n, "hand": RIGHT, "goal": "catch", "need": 6,
			"prompt": "catch", "slow": 0.6,
			"text": "%d balls now" % n,
			"sub": "Your Strength carries another. It climbs higher and moves faster than before - throw a touch higher than feels right."},
		{"prop": PROP_BALLS, "balls": n, "hand": RIGHT, "goal": "catch", "need": 10, "slow": 0.25,
			"text": "Again, closer to real speed",
			"sub": "Same pattern, less thick time. Land ten."},
	]


func pattern_lesson_steps(p: int) -> Array:
	# a new pattern: forced via the "pattern" step key, run slow with the PATTERNS table's
	# own desc as the teaching text (one source of truth), then drilled toward real speed.
	if p < 0 or p >= PATTERNS.size():
		return [{"prop": PROP_BALLS, "balls": 3, "hand": RIGHT, "goal": "catch", "need": 3,
			"text": "Keep the cascade going", "sub": "Land three."}]
	var pd: Dictionary = PATTERNS[p]
	var nm := String(pd["name"])
	var desc := String(pd.get("desc", "Feel out its shape."))
	var n := 4 if p == FOUNTAIN else 3   # fountain wants an even count; the rest read at 3
	return [
		{"prop": PROP_BALLS, "balls": n, "hand": RIGHT, "pattern": p, "goal": "catch", "need": 5,
			"prompt": "catch", "slow": 0.58,
			"text": "New pattern: %s" % nm, "sub": desc},
		{"prop": PROP_BALLS, "balls": n, "hand": RIGHT, "pattern": p, "goal": "catch", "need": 8, "slow": 0.28,
			"text": "%s, closer to speed" % nm,
			"sub": "Hold its shape as the world speeds up. Land eight."},
		# the last step TEACHES the key that owns patterns: one press of P visibly hands
		# the routine back to the plain weave. The lesson never touches pattern_sel, so
		# what the player chose before the lesson is exactly what they keep after it.
		{"prop": PROP_BALLS, "balls": n, "hand": RIGHT, "goal": "press_p", "need": 1,
			"prompt": "pattern", "slow": 0.4,
			"text": "Patterns live on the P key",
			"sub": "Press P once: the routine swaps back to the plain weave. In any practice, P chooses your pattern - the bottom-left card always names the one running."},
	]


func begin_tutorial(id: String) -> void:
	tut_id = id
	tut_step = 0
	tut_active = true
	tut_pace = 0          # the basics pace ladder re-arms: every lesson opens thick
	tut_flow_streak = 0
	game_state = ST_PLAY
	started = true            # a lesson is its own thing, not the opening "first run"
	_slow_cur = tut_slow()    # a lesson opens ALREADY thick, it does not ease in over the
							  # ~4s the 0.0025 ramp would take from a standing start
	# a lesson is a controlled space: nothing primed or toggled walks in from the last
	# session, so step one always starts from the state its text describes
	toggle_on = -1
	trick_primed = false
	tennis_ball = null
	spin_until = -999
	# ...and nothing LATCHED walks in either (Louis: "the tutorial is broken again -
	# space does nothing"). A performance that ended in collapse and was left through
	# the pause menu kept `collapsing` true forever - only start_run and the on-stage
	# landing of the last prop ever cleared it, and a lesson passes through neither.
	# With it stuck, _read_inputs returned immediately: Space, throws and catches all
	# dead, while the event keys (Escape) still worked. Every flag that can gate the
	# poll is cleared here, so a lesson always opens with live hands.
	collapsing = false
	results_open = false
	falling.clear()
	# the key that ACTIVATED the lesson (Space or Enter on the hub row) is still held
	# right now. Without seeding, the first play frame read that held Space as a fresh
	# edge and fired the trick BEFORE the player saw step one - the step then cleared
	# (or toggled) itself, and the player's own later press did the opposite of the
	# banner's ask. That is the "Space does not work in lessons" bug.
	seed_input_edges()
	tut_setup_step()


func tut_setup_step() -> void:
	var steps := tut_lesson(tut_id)
	var step: Dictionary = steps[clampi(tut_step, 0, steps.size() - 1)]
	mode = MODE_TRAIN
	var want_prop := int(step["prop"])
	var want_n := int(step["balls"])
	var start_hand := int(step.get("hand", RIGHT))
	# a met goal flows into the next step, but ANY change in the ball COUNT deals a
	# clean, fully-held table rather than topping up mid-air (Louis): adding a ball to a
	# hand that a live ball is already dropping into made the current one uncatchable -
	# a forced drop right at "two balls now". Same count (a trick/pattern drill) flows on.
	var fresh := balls.is_empty() or prop_type != want_prop or balls.size() != want_n
	prop_type = want_prop
	num_balls = want_n
	# a pattern lesson forces its own pattern FOR THE LESSON ONLY: pattern_sel (the
	# player's own P choice, the one that persists) is never touched here - a lesson
	# demonstrating Columns must not walk out with Columns selected (Louis). A step
	# without a "pattern" key keeps whatever is running when the juggle flows on, and
	# falls to the parity default only on a fresh deal.
	if step.has("pattern"):
		pattern = int(step["pattern"])
	elif fresh:
		pattern = CASCADE if num_balls % 2 == 1 else FOUNTAIN
	# a trick lesson selects (and de-arms) its trick, so the step starts from a known
	# state: Space will act on exactly this trick. A "switch it OFF" step is the one
	# exception - it must start with the toggle RUNNING (the thing to switch off),
	# otherwise the player's one press flips it back ON and the step cannot complete
	if step.has("trick"):
		trick_sel = int(step["trick"])
		toggle_on = trick_sel if String(step["goal"]) == "trick_off" else -1
		trick_primed = false
		tennis_ball = null
	if fresh:
		balls.clear()
		_stack_l.clear()
		_stack_r.clear()
		popups.clear()
		charging = [false, false]
		applause = 0.7
		streak = 0
		caught = 0
		dropped = 0
		running = false
		stamina_max = 100.0 + 9.0 * float(endurance)
		stamina = stamina_max
		hpos = [outer_pos(LEFT), outer_pos(RIGHT)]
		hand_catch_rest = [catch_slot(LEFT), catch_slot(RIGHT)]
		hclose = [0.0, 0.0]
		catch_flash = [-999, -999]
		throw_kick = [-999, -999]
		rng.seed = 20260705
		# deal the balls; a single-ball step starts in the exact hand it is teaching, and
		# so does the two-ball step (Louis: both stacked in one hand, so throw-throw-
		# catch-catch is the only sequence available - three and up still split 2-1,
		# alternating, for the real cascade's starting hold)
		for i in num_balls:
			var b := Ball.new()
			b.state = STATE_HAND
			b.kind = prop_type
			b.color = ball_color(i) if prop_type == PROP_BALLS else prop_color(prop_type)
			b.spin_dir = 1.0 if i % 2 == 0 else -1.0
			balls.append(b)
			var to_left := (i % 2 == 1) if num_balls > 2 else (start_hand == LEFT)
			if to_left:
				_stack_l.append(b)
			else:
				_stack_r.append(b)
	else:
		# top up: the new step wants more balls, so they simply appear in the
		# emptier hand and the juggle keeps rolling
		while balls.size() < want_n:
			var b := Ball.new()
			b.state = STATE_HAND
			b.kind = prop_type
			b.color = ball_color(balls.size()) if prop_type == PROP_BALLS else prop_color(prop_type)
			b.spin_dir = 1.0 if balls.size() % 2 == 0 else -1.0
			balls.append(b)
			if _stack_l.size() < _stack_r.size():
				_stack_l.append(b)
			else:
				_stack_r.append(b)
	tut_count = 0
	tut_threw_l = false
	tut_threw_r = false
	tut_tricks = 0
	tut_keys = 0
	tut_advance_at = -1
	if _demo:
		print("TUTTRACE setup step=%d goal=%s balls=%d slow=%.2f flow=%s juggle=%s tick=%d" % [tut_step, String(step["goal"]), num_balls, tut_slow(), str(step.get("flow", false)), str(step.get("juggle", false)), tick])
	# a step with nothing to DO (the key legend) is already met the moment it opens, so
	# its Enter prompt is live immediately rather than after some press that never comes.
	# Safe to ask now: every counter above is zeroed, so a step with a real goal cannot
	# read as done here. Must stay AFTER tut_advance_at = -1, which tut_check gates on.
	tut_check()


func tut_step_data() -> Dictionary:
	# the current lesson step, always in range - the one source every tutorial reader uses
	var steps := tut_lesson(tut_id)
	return steps[clampi(tut_step, 0, steps.size() - 1)]


func tut_incoming(h: int) -> bool:
	# is any ball in flight dropping toward hand h right now? (the odd-count middle ball
	# either hand may take, so it counts for both). Used to keep a top-up off a busy hand.
	for b in balls:
		if b.state == STATE_FLIGHT and (b.to_hand == h or b == col_mid_ball):
			return true
	return false


func tut_reset_step() -> void:
	# R re-deals THIS step from a clean hold, so a tangle is never a dead end - the same
	# controlled start it began with, no forced drop, no stray state carried in (Louis)
	balls.clear()
	_stack_l.clear()
	_stack_r.clear()
	charging = [false, false]
	tut_advance_at = -1
	tut_setup_step()   # balls now empty, so it deals the step fresh
	play_sfx("ui2", -13.0)


func tut_demo_reset() -> void:
	# the basics lesson's "press R" step: the press must both DO the thing (the balls
	# re-deal, so the key is seen working) and COUNT toward the goal - tut_reset_step
	# cannot be used as-is because it zeroes the step's counters, which would wipe the
	# very press being taught. So: spill the hands, let tut_maintain re-stock them,
	# and bank the press.
	balls.clear()
	_stack_l.clear()
	_stack_r.clear()
	charging = [false, false]
	tut_keys += 1
	play_sfx("ui2", -13.0)
	tut_check()


func tut_demo_pattern_off() -> void:
	# the pattern lesson's "press P" step: one press visibly hands the routine back to
	# the plain weave, so the player SEES that P is how patterns are chosen - without
	# ever touching pattern_sel (their own persistent choice)
	pattern = CASCADE if num_balls % 2 == 1 else FOUNTAIN
	col_air_ref = -1.0
	col_mid_ball = null
	tennis_ball = null
	tut_keys += 1
	play_sfx("ui2", -13.0)
	tut_check()


func tut_on_throw(h: int) -> void:
	if h == LEFT:
		tut_threw_l = true
	else:
		tut_threw_r = true
	tut_check()


func tut_on_catch(juggled: bool) -> void:
	# a step marked "juggle" only accepts catches that leave a ball in the air behind
	# them (juggling_catch): the two- and three-ball steps must not be clearable by
	# throwing one ball at a time, which is the thing they exist to teach against
	# (Louis). The run has to be CONSECUTIVE - a solo catch puts the count back to zero -
	# because "there is always a ball in the air" is a property of a stretch of juggling,
	# not a tally of good moments. The banner (and the step holding open forever) is
	# the teaching; a solo catch just quietly fails to advance, no scolding popup.
	var step := tut_step_data()
	if bool(step.get("juggle", false)) and not juggled:
		if _demo:
			print("TUTTRACE solo-catch rejected at tick=%d (count was %d)" % [tick, tut_count])
		if tut_count > 0:
			play_sfx("whiff", -14.0)
		tut_count = 0
		tut_flow_streak = 0   # a solo catch is a broken rhythm for the pace ladder too
		return
	# the PACE ladder (basics only): every TUT_PACE_STREAK clean catches in a row earn
	# the next rung down, announced so speeding up reads as the reward it is
	if tut_id == "balls":
		tut_flow_streak += 1
		if tut_flow_streak % TUT_PACE_STREAK == 0 and tut_pace < TUT_PACES.size() - 1:
			tut_pace += 1
			var pl := TUT_PACES[tut_pace]
			var ptxt := "FULL SPEED" if pl <= 0.0 else "faster  -  %d%% slow" % int(round(pl * 100.0))
			add_popup(Vector2(get_viewport_rect().size.x * 0.5, get_viewport_rect().size.y * 0.30), ptxt, Color(0.75, 0.92, 1.0))
			play_sfx("streak", -9.0)
	# the finale counts only at the ladder's floor (Louis: ten catches at 0 slowmo).
	# Catches above the floor still feed the ladder - they are how the floor is
	# reached - but the ten must all land at genuine full speed.
	if bool(step.get("finale", false)) and tut_pace < TUT_PACES.size() - 1:
		return
	tut_count += 1
	tut_check()


func tut_check() -> void:
	if tut_advance_at >= 0:
		return   # already cleared this step, just waiting for the throw to land
	var steps := tut_lesson(tut_id)
	var step: Dictionary = steps[clampi(tut_step, 0, steps.size() - 1)]
	var done := false
	match String(step["goal"]):
		"throw_r": done = tut_threw_r
		"throw_l": done = tut_threw_l
		"trick_on": done = toggle_on == int(step.get("trick", -1))   # the toggle is running
		"trick_off": done = toggle_on < 0                             # ...and now switched off
		"trick_use": done = tut_tricks >= int(step["need"])           # arm/live: reward_trick fired
		"press_r", "press_p": done = tut_keys >= int(step["need"])   # the key itself is the goal
		"read": done = true   # nothing to do but read it: Enter is live from the first frame
		_: done = tut_count >= int(step["need"])
	if done:
		# the goal is met, but the step HOLDS OPEN: the banner flips to "good job -
		# Enter continues, or keep trying", and only the player's Enter moves on
		# (Louis: never cut away while they are still trying it out). A GUIDED step is
		# the exception - it flows on by itself from tut_maintain, a beat later and from
		# a safe context. A "read" step is met at setup, so it makes no noise about it.
		tut_advance_at = tick
		if String(step["goal"]) != "read":
			play_sfx("streak", -10.0)


func tut_advance() -> void:
	# Enter moves the lesson on - and only once the step's goal has been met. A
	# step never advances by itself: the player decides when they are done trying.
	if tut_advance_at < 0:
		return
	tut_step += 1
	if tut_step >= tut_lesson(tut_id).size():
		tut_finish()
	else:
		play_sfx("ui2", -11.0)
		tut_setup_step()


func tut_maintain() -> void:
	# a GUIDED step carries itself: "press J, now press D" is a call-and-response, and
	# stopping to ask for Enter between the call and the response would break the very
	# thing it is teaching. So the moment its goal is met it waits one beat (long enough
	# to read as a win) and flows to the next call. This runs HERE, on the tick, rather
	# than from inside the catch that met the goal - tut_setup_step re-deals the table,
	# and doing that underneath on_catch would pull the ball out from under the rest of
	# it. Enter is left alone entirely, so that when it does appear on the freestyle
	# steps it means one thing only: give me another ball.
	if tut_advance_at >= 0 and bool(tut_step_data().get("flow", false)) \
			and tick - tut_advance_at >= TUT_FLOW_HOLD:
		tut_advance()
		return   # the table is now the NEXT step's: nothing below may touch it
	# the --demo autoplayer has no Enter: it takes each met goal after a beat, so a
	# dev run can walk a whole lesson end to end unattended (never in normal play).
	# It has no R or P either, so on a key-teaching step it mimes the press through
	# the same handler a real player's key reaches.
	if _demo and tut_advance_at >= 0 and tick - tut_advance_at >= 50:
		tut_advance()
		return
	if _demo and tut_advance_at < 0 and tick % 240 == 239:
		match String(tut_step_data().get("goal", "")):
			"press_r": tut_demo_reset()
			"press_p": tut_demo_pattern_off()
	# keep the step playable by topping the hands back up shortly after a ball is
	# lost, so a fumble never stalls a lesson
	if balls.size() < num_balls and tick - last_drop_tick > 34:
		var step := tut_step_data()
		var teach_hand := int(step.get("hand", RIGHT))
		for _i in (num_balls - balls.size()):
			# only ever refill a hand with NOTHING dropping into it, so a top-up never
			# lands on the hand a live ball still needs - that was the forced drop (Louis).
			# If both hands are busy catching, wait a beat and try again next tick.
			var choices: Array[int] = []
			for hh in [LEFT, RIGHT]:
				if not tut_incoming(hh):
					choices.append(hh)
			if choices.is_empty():
				break
			var to_h := int(choices[0])
			if num_balls == 1 and choices.has(teach_hand):
				to_h = teach_hand   # a single-ball step returns the ball to its teaching hand
			else:
				for hh in choices:   # otherwise the emptier free hand keeps the load even
					if stack(hh).size() < stack(to_h).size():
						to_h = hh
			var b := Ball.new()
			b.state = STATE_HAND
			b.kind = prop_type
			b.color = ball_color(balls.size()) if prop_type == PROP_BALLS else prop_color(prop_type)
			b.spin_dir = 1.0
			balls.append(b)
			stack(to_h).append(b)


func tut_finish() -> void:
	if _demo:
		print("TUTTRACE finished id=%s tick=%d" % [tut_id, tick])
	var was_basics := tut_id == "balls"
	tut_active = false
	tut_id = ""
	mode = MODE_TRAIN
	play_sfx("coin", -6.0)   # a bright flourish on finishing a lesson
	if was_basics:
		prop_type = PROP_BALLS   # ONLY the basics lesson forces balls back; a trick or
								 # count lesson taught with the owned prop leaves it be
		# the FIRST lesson earns a small congrats card - the starting kit and a
		# breath - instead of a hard cut into the day hub (Louis)
		game_state = ST_TUTDONE
		cine_tick = 0
		return
	enter_day()
	set_day_msg("lesson complete  -  your day begins")


func tut_kind_tag() -> String:
	# what KIND of thing this lesson teaches, said outright at the top of the banner,
	# because "is this a trick or a pattern?" was exactly the confusion (Louis)
	if tut_id.begins_with("trick_"):
		return "TRICK LESSON  -  a flourish on %s, %s swaps which one" % [String(k_trick()[0]), String(k_cycle()[0])]
	if tut_id.begins_with("pattern_"):
		return "PATTERN LESSON  -  the whole routine, chosen with P"
	if tut_id.begins_with("prop_"):
		return "NEW PROP LESSON"
	if tut_id.begins_with("count_"):
		return "MORE BALLS"
	return "THE BASICS"


func draw_tutorial_banner(font: Font, s: Vector2) -> void:
	var step := tut_step_data()
	var steps := tut_lesson(tut_id)
	draw_tut_prompts(font, s, step)   # a timing ring + bare handed key over the hands, no boxes
	# a SMALL rectangle at the top (2026-07-18, Louis: "not above and below, out of
	# vision, long texts of what to do - that is bad design"): the lesson kind, its
	# one-line title, and progress only. The old two-line "sub" paragraph explaining
	# WHY is gone from the live HUD entirely - what to press right now belongs dead
	# centre instead, drawn below by draw_tut_special_cue off tut_action_cue().
	var bw := s.x * 0.6
	var bx := s.x * 0.5 - bw * 0.5
	var by := 24.0
	var bh := 64.0
	draw_rect(Rect2(bx, by, bw, bh), Color(0.05, 0.03, 0.05, 0.86))
	draw_rect(Rect2(bx, by, bw, bh), Color(0.82, 0.62, 0.34, 0.55), false, 2.0)
	var kind_col := Color(1.0, 0.72, 0.4) if tut_id.begins_with("trick_") else (Color(0.65, 0.85, 1.0) if tut_id.begins_with("pattern_") else Color(0.85, 0.75, 0.6))
	draw_string(font, Vector2(bx, by + 18.0), tut_kind_tag(), HORIZONTAL_ALIGNMENT_CENTER, bw, 12, kind_col)
	draw_string(font, Vector2(bx, by + 42.0), String(step["text"]), HORIZONTAL_ALIGNMENT_CENTER, bw, 20, Color(1.0, 0.9, 0.6))
	# the progress line flips to the GOOD JOB state once the goal is met: the step
	# stays fully playable, and Enter is the player's own "I am done trying" (Louis).
	# A guided step never says it - it is already flowing on by itself - and a read
	# step has nothing to be proud of yet.
	var done := tut_advance_at >= 0
	var flow := bool(step.get("flow", false))
	if done and not flow and String(step["goal"]) != "read":
		var ga := 0.75 + 0.25 * sin(atick() * 0.1)
		draw_string(font, Vector2(bx, by + 58.0), "GOOD JOB  -  you got it", HORIZONTAL_ALIGNMENT_CENTER, bw, 13, Color(0.72, 0.95, 0.7, ga))
	elif not done:
		var prog := "Step %d of %d" % [tut_step + 1, steps.size()]
		if int(step["need"]) > 1 and String(step["goal"]) == "catch":
			# a juggle-gated step counts CONSECUTIVE juggling catches, so the label says
			# so - otherwise a count that drops back to zero looks like a bug (Louis).
			# The finale is plainer still: its ten only run at the pace ladder's floor,
			# so until then the label says what the catches are actually buying.
			if bool(step.get("finale", false)) and tut_pace < TUT_PACES.size() - 1:
				prog += "   -   %d%% slow, clean catches speed it up" % int(round(TUT_PACES[tut_pace] * 100.0))
			else:
				var lbl := "at full speed" if bool(step.get("finale", false)) else ("juggled in a row" if bool(step.get("juggle", false)) else "caught")
				prog += "   -   %s %d / %d" % [lbl, mini(tut_count, int(step["need"])), int(step["need"])]
		draw_string(font, Vector2(bx, by + 58.0), prog, HORIZONTAL_ALIGNMENT_CENTER, bw, 12, Color(0.8, 0.75, 0.68))
	# the controls that actually WORK in a lesson, always, along the very bottom - plus
	# the lesson's own key (trick / pattern) so every command the game has gets its
	# moment of attention in the lesson that owns it (Louis)
	var items: Array = []
	items.append([k_throw(), "throw"])
	items.append([k_catch(), "catch"])
	if tut_id.begins_with("trick_"):
		items.append([k_trick(), "trick"])
		items.append([k_cycle(), "switch trick"])
	elif tut_id.begins_with("pattern_"):
		items.append([k_pattern(), "pattern"])
	items.append([k_restart(), "restart"])
	items.append([k_pause(), "game menu"])
	draw_hints_row(font, s.x * 0.5, s.y - 40.0, items)
	# ONE cue slot, and exactly one thing may hold it - a screen that asks for two keys
	# at once has asked for neither. Enter wins whenever it is live, because the whole
	# point of its own callout is that it stops being missable; otherwise the centred
	# keycap (Louis: dead centre, not a sentence at either edge) names whatever the
	# live sim wants pressed right now.
	if done and flow:
		# the beat a guided step takes on its win before flowing to the next call: the
		# win, and nothing else. Naming the next key here (the cue would, the ball being
		# in the other hand already) would ask for a press the banner has not explained.
		draw_text_shout(font, Vector2(0, s.y - 68.0), "yes  -  that's it", HORIZONTAL_ALIGNMENT_CENTER, s.x, 17, Color(0.72, 0.95, 0.7))
	elif done:
		draw_tut_enter_callout(font, s, step, tut_step >= steps.size() - 1)
	else:
		draw_tut_special_cue(font, s, tut_action_cue(step))
	if String(step["goal"]) == "read":
		draw_tut_legend(font, s)
	# trick feedback ("HIGH TOSS ON", or the lesson's gentle no-trick-here guidance)
	# shows in lessons too - draw_hud, which normally carries it, never runs here
	if trick_msg != "" and tick - trick_msg_tick < 90:
		var ta := clampf(1.0 - float(tick - trick_msg_tick) / 90.0, 0.0, 1.0)
		draw_text_shout(font, Vector2(s.x * 0.5 - 200, s.y - 128.0), trick_msg, HORIZONTAL_ALIGNMENT_CENTER, 400, 17, Color(1.0, 0.88, 0.55, ta))


func tut_action_cue(step: Dictionary) -> Dictionary:
	# THE one button that has no hand of its own - trick, pattern, restart - so it gets
	# no home among the bare per-hand keys draw_tut_prompts already draws over every
	# throw/catch, in every lesson (2026-07-18, Louis, second pass: those were already
	# "central" enough - over the hands, bare, no box - and just wanted nudging a
	# little further off the hands, not replacing). This is the disconnect that broke
	# the Spin lesson: "press SPACE now" used to be baked straight into the step text
	# with no check against whether the press would do anything. The "live" branch
	# below asks on_trick()'s own two questions - enough in the air, not cooling down
	# - before ever naming Space, so the game can no longer promise a press it would
	# then silently refuse.
	var goal := String(step["goal"])
	if goal == "press_p":
		return {"key": String(k_pattern()[0]), "label": "pattern"}
	if goal == "press_r":
		return {"key": String(k_restart()[0]), "label": "restart"}
	if String(step.get("prompt", "")) == "trick":
		var ti: int = int(step.get("trick", trick_sel))
		if ti >= 0 and ti < TRICKS.size():
			var t: Dictionary = TRICKS[ti]
			if String(t["kind"]) == "live":
				if balls_airborne() >= int(t["min_air"]) and tick >= trick_ready:
					return {"key": String(k_trick()[0]), "label": "%s  -  now" % String(t["name"]).to_upper()}
				return {}   # not ready: the per-hand keys are already naming the catch/throw that gets there
			var lbl := "switch on" if goal == "trick_on" else ("switch off" if goal == "trick_off" else "trick")
			return {"key": String(k_trick()[0]), "label": lbl}
	return {}


func draw_tut_special_cue(font: Font, s: Vector2, cue: Dictionary) -> void:
	# Space / P / R belong to neither hand, so they get the same central bottom slot
	# and bordered-keycap look as the Enter callout below (Louis, 2026-07-18: "the
	# space button should be where the enter now button is, nice and central") - the
	# two never show at once, since this only runs while the step is NOT yet done.
	if String(cue.get("key", "")) == "":
		return
	var label := String(cue.get("label", ""))
	var pulse := 0.5 + 0.5 * sin(atick() * 0.13)
	var fs := 19
	var cap := String(cue["key"])
	var lw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var cw := font.get_string_size(cap, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 18.0
	var total := cw + 14.0 + lw
	var bh := float(fs) + 16.0
	var bx := s.x * 0.5 - total * 0.5
	var by := s.y - 96.0
	draw_rect(Rect2(bx - 18.0, by, total + 36.0, bh), Color(0.16, 0.10, 0.04, 0.88))
	draw_rect(Rect2(bx - 18.0, by, total + 36.0, bh), Color(1.0, 0.72, 0.4, 0.45 + 0.45 * pulse), false, 2.0)
	draw_rect(Rect2(bx, by + 6.0, cw, bh - 12.0), Color(1.0, 0.72, 0.4, 0.82 + 0.18 * pulse))
	draw_string(font, Vector2(bx, by + bh - 11.0), cap, HORIZONTAL_ALIGNMENT_CENTER, cw, fs, Color(0.12, 0.07, 0.03))
	draw_string(font, Vector2(bx + cw + 14.0, by + bh - 11.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.93, 0.72))


func draw_tut_enter_callout(font: Font, s: Vector2, step: Dictionary, last: bool) -> void:
	# THE fix for the one thing every tester did (Louis): they got the juggling straight
	# away and then just kept juggling, because "Enter continues" was a small line in a
	# banner they had long stopped reading. So Enter gets a bar of its own above the key
	# row; it says what it will DO ("add a second ball") rather than that it continues;
	# and it grows and quickens for as long as it goes unanswered, so a player happily
	# lost in the juggling is eventually, gently, unmissably told there is more.
	var label := "finish the lesson" if last else String(step.get("next", "continue"))
	var urg := clampf(float(tick - tut_advance_at) / 900.0, 0.0, 1.0)
	var pulse := 0.5 + 0.5 * sin(atick() * (0.07 + 0.06 * urg))
	var fs := int(round(lerpf(17.0, 22.0, urg)))
	var cap := String(k_finish()[0])   # Enter, or A on a pad
	var lw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var cw := font.get_string_size(cap, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 18.0
	var total := cw + 14.0 + lw
	var bh := float(fs) + 16.0
	var bx := s.x * 0.5 - total * 0.5
	var by := s.y - 96.0
	draw_rect(Rect2(bx - 18.0, by, total + 36.0, bh), Color(0.16, 0.10, 0.04, 0.88))
	draw_rect(Rect2(bx - 18.0, by, total + 36.0, bh), Color(1.0, 0.86, 0.42, 0.45 + 0.45 * pulse), false, 2.0)
	draw_rect(Rect2(bx, by + 6.0, cw, bh - 12.0), Color(1.0, 0.86, 0.42, 0.82 + 0.18 * pulse))
	draw_string(font, Vector2(bx, by + bh - 11.0), cap, HORIZONTAL_ALIGNMENT_CENTER, cw, fs, Color(0.12, 0.07, 0.03))
	draw_string(font, Vector2(bx + cw + 14.0, by + bh - 11.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.93, 0.72))
	# ...and the other half of the deal, quieter, because the step never stops being
	# playable and nobody should feel hurried out of the thing they just got working
	draw_string(font, Vector2(0, by - 8.0), "or keep practising as long as you like", HORIZONTAL_ALIGNMENT_CENTER, s.x, 12, Color(0.78, 0.72, 0.64, 0.75))


func draw_tut_legend(font: Font, s: Vector2) -> void:
	# every command the game has, named, in one card (Louis: teach them all the buttons
	# they can press at all times, with clear names). Two columns, sat in the clear band
	# between the banner and the hands at 0.57, so it overlaps neither and the balls stay
	# visible underneath it. Keys come from the live bindings, so a remapped player reads
	# their own; the fixed ones are printed as they are.
	var kt := k_throw()
	var kc := k_catch()
	var rows := [
		[[String(kt[RIGHT]), String(kt[LEFT])], "throw", "right hand, left hand"],
		[[String(kc[RIGHT]), String(kc[LEFT])], "catch", "right hand, left hand"],
		[[String(k_trick()[0])], "trick", "one flourish  -  %s picks which" % String(k_cycle()[0])],
		[[String(k_pattern()[0])], "pattern", "the routine you juggle"],
		[[String(k_object()[0])], "object", "balls, rings, clubs, torches"],
		[k_count(), "how many", "props to juggle, live or fresh"],
		[[String(k_restart()[0])], "restart", "re-deal  -  practice only, never on stage"],
		[[String(k_shop()[0])], "the shop", "buy props and gear"],
		[[String(k_sheet()[0])], "your skills", "the sheet  -  spend your points"],
		[[String(k_pause()[0])], "the game menu", "resume, back to the day, quit"],
		[[String(k_finish()[0])], "finish", "take a bow on stage, or leave practice"],
	]
	var nrows := int(ceil(float(rows.size()) * 0.5))
	var cw := minf(920.0, s.x - 80.0)
	var cx := s.x * 0.5 - cw * 0.5
	var cy := 158.0
	var rowh := 26.0
	var ch := 34.0 + float(nrows) * rowh
	draw_rect(Rect2(cx, cy, cw, ch), Color(0.05, 0.03, 0.05, 0.9))
	draw_rect(Rect2(cx, cy, cw, ch), Color(0.82, 0.62, 0.34, 0.5), false, 2.0)
	var colw := cw * 0.5
	for i in rows.size():
		var row: Array = rows[i]
		var x := cx + 20.0 + float(i / nrows) * colw
		var y := cy + 26.0 + float(i % nrows) * rowh
		var kx := x
		for k in row[0]:
			kx += draw_keycap(font, kx, y - 14.0, String(k)) + 3.0
		draw_string(font, Vector2(x + 62.0, y), String(row[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.0, 0.88, 0.58))
		draw_string(font, Vector2(x + 168.0, y), String(row[2]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.82, 0.76, 0.68, 0.9))


func draw_timing_ring(at: Vector2, d: int) -> void:
	# LESSON ONLY: turn the invisible catch window into a visible target. A ring around
	# the receiving hand tightens as the ball approaches (d = ticks until it lands) and
	# flashes gold across the Perfect window, so a beginner can SEE why a catch is early
	# or on time. Never drawn in a real set - it would defeat the timing skill.
	var pw := perfect_window()
	var r := lerpf(14.0, 48.0, clampf(float(d) / float(PROMPT_LEAD), 0.0, 1.0))
	var perfect := absi(d) <= pw
	var col := Color(1.0, 0.85, 0.35, 0.95) if perfect else Color(0.7, 0.8, 0.95, 0.55)
	var width := 3.5 if perfect else 2.0
	draw_arc(at, r, 0.0, TAU, 40, col, width, true)
	if perfect:
		draw_arc(at, r + 4.0, 0.0, TAU, 40, Color(1.0, 0.9, 0.5, 0.4), 2.0, true)


func draw_tut_key(font: Font, at: Vector2, key: String, col: Color, urgency: float) -> void:
	# a single BARE key letter floating over a hand - outlined, no box - so the handed
	# press (which hand, which key) is guided at the point of action without a text
	# rectangle in the middle of the stage (Louis: keep the centre clear).
	var u := clampf(urgency, 0.0, 1.0)
	var sc := lerpf(1.0, 1.4, u)
	if u > 0.6:
		sc *= 1.0 + 0.06 * sin(atick() * 0.18) * (u - 0.6) / 0.4
	var fs := int(round(19.0 * sc))
	var a := lerpf(0.78, 1.0, u)   # never faint: a calm key must still read at a glance
	draw_text_shout(font, at - Vector2(80.0, 0.0), key, HORIZONTAL_ALIGNMENT_CENTER, 160.0, fs, Color(col.r, col.g, col.b, a))


func draw_tut_prompts(font: Font, s: Vector2, step: Dictionary) -> void:
	# THE lesson affordance (Louis): which key, over which hand, at the moment to press it
	# - but as a bare letter and a timing ring, never a boxed bubble. A met goal no
	# longer silences these: the step holds open for more practice, so the guidance
	# keeps working until the player's Enter moves on.
	var kc := k_catch()
	var kt := k_throw()
	# THROW WINS, full stop (Louis, now three times - most recently: "it should keep
	# telling me to throw the ball until the hand is completely empty, only THEN
	# should it say to catch"). A hand still holding a ball NEVER shows a catch ring,
	# however soon something else is landing there - it keeps asking for its throw key
	# until the stack is empty. Without this, throwing two balls quickly from one hand
	# could leave the OTHER hand's still-unthrown ball hidden: that hand happened to
	# also be where one of the two just-thrown balls was headed, so its incoming-catch
	# ring silently won the same slot the throw key needed.
	var holding := [not stack(LEFT).is_empty(), not stack(RIGHT).is_empty()]
	# catch: a timing ring on the receiving hand, its bare catch key just above it -
	# but only once that hand is empty. The lead runs LONGER than the in-game glow
	# (Louis: shown early enough), so a beginner reads the key well before the ball
	# asks for it.
	var lead := PROMPT_LEAD * 3 / 2
	# when two balls are both bound for the same hand, only the SOONEST one gets a
	# ring - one ring per hand, never a stack of them (Louis)
	var soonest := [lead + 1, lead + 1]
	for b in balls:
		if b.state != STATE_FLIGHT:
			continue
		var d := b.land_tick - tick
		if d <= 0 or d > lead:
			continue
		var h := clampi(b.to_hand, 0, 1)
		if holding[h]:
			continue
		if d < soonest[h]:
			soonest[h] = d
	for h in [LEFT, RIGHT]:
		if soonest[h] > lead:
			continue
		var hp: Vector2 = hpos[h]
		draw_timing_ring(hp, soonest[h])
		var urg := 1.0 - float(soonest[h]) / float(lead)
		draw_tut_key(font, hp + Vector2(0.0, -60.0), String(kc[h]), Color(0.7, 0.88, 1.0), urg)
	# throw: the bare throw key over EVERY hand still holding a ball, all lesson long
	# (Louis: the keys are shown every single time, never assumed learned). It
	# brightens when the step's whole point is that throw, stays calm otherwise.
	var goal := String(step["goal"])
	for hh: int in [LEFT, RIGHT]:
		if not holding[hh]:
			continue
		# a GUIDED step is a call-and-response with one ball on the table, so the hand
		# holding it IS the ask: its key burns as brightly as any named goal would. The
		# step's goal there is the catch at the far end, and reading only that left the
		# throw the whole beat depends on looking optional. A TRICK step (2026-07-18
		# fix) gets the same treatment: "arm it, then throw" landed the trick on a
		# barely-dimmed key next to the ongoing cascade's own bright catch prompts, so
		# the follow-up throw read as optional there too.
		var wants: bool = (goal == "throw_r" and hh == RIGHT) or (goal == "throw_l" and hh == LEFT) \
			or bool(step.get("guide", false)) or String(step.get("prompt", "")) == "trick"
		draw_tut_key(font, hpos[hh] + Vector2(0.0, -60.0), String(kt[hh]), Color(1.0, 0.82, 0.5), 0.85 if wants else 0.4)


#endregion

#region DAY-HUB PURCHASES (PIE / GLASSES)
func try_buy_pie() -> void:
	# Uncle Dan's Pie: a bought minute of slow-motion clarity, eaten in the day
	# hub to arm the next session (ideas.rtf: a temporary stimulant)
	if money < PIE_COST:
		play_sfx("whiff", -10.0)
		return
	if not confirm_spend("pie", PIE_COST, true):
		return
	money -= PIE_COST
	pie_count += 1
	shop_buy_ms = int(Time.get_ticks_msec())
	save_progress()
	play_sfx("money", -6.0)


func try_buy_glasses() -> void:
	if has_glasses or money < GLASSES_COST:
		return
	if not confirm_spend("glasses", GLASSES_COST, true):
		return
	money -= GLASSES_COST
	has_glasses = true
	shop_buy_ms = int(Time.get_ticks_msec())
	save_progress()
	play_sfx("money", -6.0)


func try_buy_glow_kit() -> void:
	if has_glow_kit or money < GLOW_KIT_COST:
		return
	if not confirm_spend("glow_kit", GLOW_KIT_COST, true):
		return
	money -= GLOW_KIT_COST
	has_glow_kit = true
	shop_buy_ms = int(Time.get_ticks_msec())
	save_progress()
	play_sfx("money", -6.0)


# -----------------------------------------------------------------------------
# Game flow: main menu, save slots, settings, cutscenes.
# -----------------------------------------------------------------------------

#endregion

#region MAIN MENU / SLOTS / SETTINGS INPUT
func menu_options() -> Array[String]:
	# the live main-menu list. Both menu_input and draw_menu build the list from
	# here, so the cursor and the drawing can never disagree. (There used to be a
	# "Victory" entry that replayed the credits once any save had won - Louis
	# found it confusing on the START menu, a button that looked pressable but
	# wasn't really for pressing, so it's gone; the real win still rolls credits
	# on its own, from actually clearing the World Arena - see resolve_act/results.)
	var opts: Array[String] = ["Play"]
	opts.append("Settings")
	opts.append("Quit")
	return opts


func menu_input(kc: int) -> void:
	var opts := menu_options()
	var n := opts.size()
	match kc:
		KEY_UP, KEY_W:
			menu_sel = (menu_sel + n - 1) % n
			play_sfx("ui", -14.0)
		KEY_DOWN, KEY_S:
			menu_sel = (menu_sel + 1) % n
			play_sfx("ui", -14.0)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			play_sfx("ui2", -11.0)
			# dispatch on the chosen STRING, never the raw index, so an option list
			# that grows a Credits entry can never send Play where Settings was meant
			var choice := opts[clampi(menu_sel, 0, n - 1)]
			match choice:
				"Play":
					menu_sel = 0
					game_state = ST_SLOTS
				"Settings":
					menu_sel = 0
					game_state = ST_SETTINGS
				"Quit":
					get_tree().quit()
		KEY_ESCAPE:
			get_tree().quit()


func credits_key() -> void:
	# any key ends the roll and returns to the main menu
	play_sfx("ui2", -12.0)
	game_state = ST_MENU
	menu_sel = 0


func slots_input(kc: int) -> void:
	var n := NUM_SLOTS + 1   # the slots, then Back
	match kc:
		KEY_UP, KEY_W:
			menu_sel = (menu_sel + n - 1) % n
		KEY_DOWN, KEY_S:
			menu_sel = (menu_sel + 1) % n
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			if menu_sel >= NUM_SLOTS:
				menu_sel = 0
				game_state = ST_MENU
			else:
				start_slot(menu_sel)
		KEY_X, KEY_DELETE, KEY_BACKSPACE:
			if menu_sel < NUM_SLOTS:
				delete_slot(menu_sel)   # wipe that save file
		KEY_ESCAPE:
			menu_sel = 0
			game_state = ST_MENU


func settings_input(kc: int) -> void:
	var n := 8   # music, sound, shake, collisions, fullscreen, controls, records, Back
	match kc:
		KEY_UP, KEY_W:
			menu_sel = (menu_sel + n - 1) % n
			play_sfx("ui", -14.0)
		KEY_DOWN, KEY_S:
			menu_sel = (menu_sel + 1) % n
			play_sfx("ui", -14.0)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_LEFT, KEY_RIGHT:
			# Music / Sound are VOLUME SLIDERS now, not on/off: Left/Right fine-tune
			# in 10% steps, Enter/Space mutes and restores (0.0 <-> full)
			if menu_sel == 0 or menu_sel == 1:
				var step := 0.1 if kc == KEY_RIGHT else (-0.1 if kc == KEY_LEFT else 0.0)
				if menu_sel == 0:
					set_music = clampf(set_music + step, 0.0, 1.0) if step != 0.0 else (0.0 if set_music > 0.0 else 1.0)
				else:
					set_sfx = clampf(set_sfx + step, 0.0, 1.0) if step != 0.0 else (0.0 if set_sfx > 0.0 else 1.0)
				play_sfx("ui2", -12.0)
				save_settings()
				return
			match menu_sel:
				2:
					set_shake = not set_shake
				3:
					set_collide = not set_collide
				4:
					set_fullscreen = not set_fullscreen
					apply_fullscreen()
				5:
					remap_sel = 0
					remap_wait = false
					game_state = ST_REMAP   # the controls reference (and rebind the six actions)
				6:
					game_state = ST_STATS   # the career ledger, back with Esc
				7:
					menu_sel = 0
					game_state = ST_MENU
			play_sfx("ui2", -12.0)
			save_settings()
		KEY_ESCAPE:
			save_settings()
			menu_sel = 0
			game_state = ST_MENU


func apply_fullscreen() -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if set_fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)


#endregion

#region SAVE SLOTS
func start_slot(i: int) -> void:
	save_slot = i
	var fresh := not FileAccess.file_exists(slot_path(i))
	if fresh:
		reset_new_game()
		# a brand new career opens straight into the hands-on basics (one ball, then
		# two, then the cascade); tut_finish drops into the day when they are done
		seen_tuts.append("balls")
		begin_tutorial("balls")
	else:
		load_progress()
		enter_day()   # an existing career resumes at its day, not mid-juggle


func reset_new_game() -> void:
	# a brand new juggler, so a fresh slot never inherits the previous one's stats
	accuracy = 5
	strength = 6
	endurance = 0
	speed = 0
	pie_count = 0
	pie_active = false
	money = START_GOLD
	reputation = 0
	prop_count = [3, 0, 0, 0, 0, 0]   # the starting kit: three worn stage balls
	prop_type = PROP_BALLS
	has_glasses = false
	has_glow_kit = false
	level = 1
	xp = 0
	points = 0
	won = false
	best_scores = [0, 0, 0, 0, 0, 0, 0]
	best_scores_purist = [0, 0, 0, 0, 0, 0, 0]
	pattern_sel = CASCADE
	purist = false
	career = {"perfs": 0, "practices": 0, "catches": 0, "drops": 0,
		"best_streak": 0, "gold_earned": 0, "tricks": 0, "days": 1, "best_score": 0,
		"mastery": 0}
	day = 1
	seg_used = 0
	venue_pick = 0
	meals = 0
	started = false
	seen_tuts.clear()      # a fresh slot re-teaches everything from scratch
	pending_tuts.clear()
	ante = [0, 0, 0, 0, 0, 0, 0]   # every venue back to its opening bar
	gifted.clear()              # a fresh slot earns (or is re-gifted) everything anew
	perfs_since_unlock = 0
	aid_pie_day = -1
	aid_meal_used = false
	stamina_max = 100.0 + 9.0 * float(endurance)
	stamina = stamina_max
	save_progress()


func slot_path(i: int) -> String:
	return "user://iacto_slot%d.cfg" % i


func slot_summary(i: int) -> String:
	if not FileAccess.file_exists(slot_path(i)):
		return "empty"
	var cf := ConfigFile.new()
	if cf.load(slot_path(i)) != OK:
		return "empty"
	var lv := int(cf.get_value("prog", "level", 1))
	var g := int(cf.get_value("stats", "money", START_GOLD))
	var rep := int(cf.get_value("stats", "reputation", 0))
	var vn := String(venue_data(venue_index_of(rep))["name"])
	var line := "Level %d   -   %s   -   %d gold" % [lv, vn, g]
	if bool(cf.get_value("prog", "won", false)):
		line += "  -  WORLD'S GREATEST JUGGLER"   # this save has conquered the top stage
	return line


func delete_slot(i: int) -> void:
	var dir := DirAccess.open("user://")
	var fn := "iacto_slot%d.cfg" % i
	if dir != null and dir.file_exists(fn):
		dir.remove(fn)


#endregion

#region SETTINGS PERSISTENCE & CONTROLS REMAP
func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) == OK:
		set_shake = bool(cf.get_value("opt", "shake", true))
		set_collide = bool(cf.get_value("opt", "collide", false))
		set_music = clampf(float(cf.get_value("opt", "music", 1.0)), 0.0, 1.0)
		set_sfx = clampf(float(cf.get_value("opt", "sfx", 1.0)), 0.0, 1.0)
		set_fullscreen = bool(cf.get_value("opt", "fullscreen", false))
		K_LC = int(cf.get_value("keys", "lc", KEY_D))
		K_LT = int(cf.get_value("keys", "lt", KEY_F))
		K_RC = int(cf.get_value("keys", "rc", KEY_K))
		K_RT = int(cf.get_value("keys", "rt", KEY_J))
		K_TRICK = int(cf.get_value("keys", "trick", KEY_SPACE))
		K_CYCLE = int(cf.get_value("keys", "cycle", KEY_C))
		PAD_TRICK = int(cf.get_value("keys", "pad_trick", JOY_BUTTON_X))
		PAD_CYCLE = int(cf.get_value("keys", "pad_cycle", JOY_BUTTON_LEFT_STICK))


func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("opt", "shake", set_shake)
	cf.set_value("opt", "collide", set_collide)
	cf.set_value("opt", "music", set_music)
	cf.set_value("opt", "sfx", set_sfx)
	cf.set_value("opt", "fullscreen", set_fullscreen)
	cf.set_value("keys", "lc", K_LC)
	cf.set_value("keys", "lt", K_LT)
	cf.set_value("keys", "rc", K_RC)
	cf.set_value("keys", "rt", K_RT)
	cf.set_value("keys", "trick", K_TRICK)
	cf.set_value("keys", "cycle", K_CYCLE)
	cf.set_value("keys", "pad_trick", PAD_TRICK)
	cf.set_value("keys", "pad_cycle", PAD_CYCLE)
	cf.save(SETTINGS_PATH)


func action_key(id: String) -> int:
	match id:
		"lc": return K_LC
		"lt": return K_LT
		"rc": return K_RC
		"rt": return K_RT
		"trick": return K_TRICK
		_: return K_CYCLE


func bind_action(id: String, kc: int) -> void:
	# assign kc to the action. If another action already holds kc, the two SWAP,
	# so every action always keeps some key and no press can mean two things.
	var old := action_key(id)
	for a in REMAP_ACTS:
		var aid := String(a[0])
		if aid != id and action_key(aid) == kc:
			_set_action_key(aid, old)
	_set_action_key(id, kc)
	save_settings()


func _set_action_key(id: String, kc: int) -> void:
	match id:
		"lc": K_LC = kc
		"lt": K_LT = kc
		"rc": K_RC = kc
		"rt": K_RT = kc
		"trick": K_TRICK = kc
		"cycle": K_CYCLE = kc


func pad_action_button(id: String) -> int:
	return PAD_TRICK if id == "trick" else PAD_CYCLE


func bind_pad_action(id: String, btn: int) -> void:
	# same clash-swap rule as the keyboard six (bind_action above), scoped to the
	# two pad-remappable actions: no press can ever mean two things.
	var old := pad_action_button(id)
	for a in PAD_ACTS:
		var aid := String(a[0])
		if aid != id and pad_action_button(aid) == btn:
			_set_pad_action_button(aid, old)
	_set_pad_action_button(id, btn)
	save_settings()


func _set_pad_action_button(id: String, btn: int) -> void:
	if id == "trick":
		PAD_TRICK = btn
	else:
		PAD_CYCLE = btn


func remap_input(kc: int) -> void:
	# remap_wait is handled upstream in _input (it captures the raw next key or,
	# on the gamepad column, the raw next pad button - see _input). Tab (keyboard,
	# or the pad's own Y/sheet button) swaps which column has focus.
	if kc == KEY_TAB:
		remap_col = 1 - remap_col
		remap_wait = false
		play_sfx("ui", -14.0)
		return
	if remap_col == 0:
		var n := REMAP_ACTS.size()
		match kc:
			KEY_UP, KEY_W:
				remap_sel = (remap_sel + n - 1) % n
				play_sfx("ui", -14.0)
			KEY_DOWN, KEY_S:
				remap_sel = (remap_sel + 1) % n
				play_sfx("ui", -14.0)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				remap_wait = true
				play_sfx("ui2", -13.0)
			KEY_ESCAPE:
				game_state = ST_SETTINGS
				play_sfx("ui", -12.0)
	else:
		var m := PAD_ACTS.size()
		match kc:
			KEY_UP, KEY_W:
				pad_remap_sel = (pad_remap_sel + m - 1) % m
				play_sfx("ui", -14.0)
			KEY_DOWN, KEY_S:
				pad_remap_sel = (pad_remap_sel + 1) % m
				play_sfx("ui", -14.0)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				remap_wait = true
				play_sfx("ui2", -13.0)
			KEY_ESCAPE:
				game_state = ST_SETTINGS
				play_sfx("ui", -12.0)


func pad_button_glyph(btn: int) -> String:
	# short display name for a raw pad button, used only on the Controls screen's
	# gamepad column (the k_* hint helpers elsewhere use plain "A"/"B"/... directly)
	match btn:
		JOY_BUTTON_A: return "A"
		JOY_BUTTON_B: return "B"
		JOY_BUTTON_X: return "X"
		JOY_BUTTON_Y: return "Y"
		JOY_BUTTON_LEFT_SHOULDER: return "LB"
		JOY_BUTTON_RIGHT_SHOULDER: return "RB"
		JOY_BUTTON_LEFT_STICK: return "L3"
		JOY_BUTTON_RIGHT_STICK: return "R3"
		JOY_BUTTON_BACK: return "Back"
		JOY_BUTTON_START: return "Start"
		JOY_BUTTON_DPAD_UP: return "D-Up"
		JOY_BUTTON_DPAD_DOWN: return "D-Down"
		JOY_BUTTON_DPAD_LEFT: return "D-Left"
		JOY_BUTTON_DPAD_RIGHT: return "D-Right"
		_: return "Btn %d" % btn


func draw_remap(font: Font, s: Vector2) -> void:
	view_venue = 2
	draw_backdrop(s)
	view_venue = -1
	draw_rect(Rect2(0, 0, s.x, s.y), Color(0.03, 0.02, 0.03, 0.68))
	draw_title_glow(font, s.y * 0.06, "CONTROLS", 36, Color(1.0, 0.88, 0.5), s)
	draw_ornament(s.x * 0.5, s.y * 0.06 + 62.0, 170.0, Color(0.82, 0.62, 0.34, 0.85))
	var pw := 620.0
	var px := s.x * 0.5 - pw * 0.5
	var kb_focus := remap_col == 0
	var pad_focus := remap_col == 1

	# --- keyboard column (the six core actions) ---
	var oy := s.y * 0.222
	draw_string(font, Vector2(px, oy - 22.0), "KEYBOARD", HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
		Color(0.95, 0.82, 0.5, 0.9) if kb_focus else Color(0.6, 0.56, 0.5, 0.6))
	for i in REMAP_ACTS.size():
		var sel := kb_focus and i == remap_sel
		var ry := oy + float(i) * 40.0
		if sel:
			hud_panel(Rect2(px - 16.0, ry - 22.0, pw + 32.0, 38.0), true)
		var dim := 1.0 if kb_focus else 0.5
		var nm := String(REMAP_ACTS[i][1])
		draw_string(font, Vector2(px, ry), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 18,
			Color(1.0, 0.9, 0.6) if sel else Color(0.8 * dim, 0.74 * dim, 0.66 * dim))
		var kname := OS.get_keycode_string(action_key(String(REMAP_ACTS[i][0])))
		if sel and remap_wait:
			var pa := 0.5 + 0.5 * sin(float(cine_tick) * 0.12)
			draw_string(font, Vector2(px + pw - 220.0, ry), "press a key...", HORIZONTAL_ALIGNMENT_RIGHT, 220.0, 16, Color(1.0, 0.85, 0.45, 0.5 + 0.5 * pa))
		else:
			draw_keycap(font, px + pw - maxf(28.0, 14.0 + 7.0 * float(kname.length())), ry - 13.0, kname)

	# --- gamepad column (TRICK + SWITCH TRICK only - catch/throw stay on the
	# triggers/bumpers, always, never remapped: see PAD_ACTS) ---
	var gy := oy + float(REMAP_ACTS.size()) * 40.0 + 30.0
	draw_string(font, Vector2(px, gy - 22.0), "GAMEPAD", HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
		Color(0.95, 0.82, 0.5, 0.9) if pad_focus else Color(0.6, 0.56, 0.5, 0.6))
	for i in PAD_ACTS.size():
		var sel := pad_focus and i == pad_remap_sel
		var ry := gy + float(i) * 40.0
		if sel:
			hud_panel(Rect2(px - 16.0, ry - 22.0, pw + 32.0, 38.0), true)
		var dim := 1.0 if pad_focus else 0.5
		var nm := String(PAD_ACTS[i][1])
		draw_string(font, Vector2(px, ry), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 18,
			Color(1.0, 0.9, 0.6) if sel else Color(0.8 * dim, 0.74 * dim, 0.66 * dim))
		var gname := pad_button_glyph(pad_action_button(String(PAD_ACTS[i][0])))
		if sel and remap_wait:
			var pa2 := 0.5 + 0.5 * sin(float(cine_tick) * 0.12)
			draw_string(font, Vector2(px + pw - 220.0, ry), "press a button...", HORIZONTAL_ALIGNMENT_RIGHT, 220.0, 16, Color(1.0, 0.85, 0.45, 0.5 + 0.5 * pa2))
		else:
			draw_keycap(font, px + pw - maxf(28.0, 14.0 + 7.0 * float(gname.length())), ry - 13.0, gname)
	draw_string(font, Vector2(px, gy + float(PAD_ACTS.size()) * 40.0 + 4.0),
		"catch and throw always stay on the triggers and bumpers",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.68, 0.63, 0.56, 0.8))

	# the other in-play keys, listed here so live play never has to show them
	var refy := gy + float(PAD_ACTS.size()) * 40.0 + 44.0
	draw_ornament(s.x * 0.5, refy, 150.0, Color(0.82, 0.62, 0.34, 0.6))
	draw_string(font, Vector2(0, refy + 22.0), "OTHER KEYS", HORIZONTAL_ALIGNMENT_CENTER, s.x, 14, Color(0.95, 0.8, 0.55, 0.9))
	draw_string(font, Vector2(0, refy + 46.0), "Enter  finish / end the set      Esc  pause      Tab  character sheet      S  shop", HORIZONTAL_ALIGNMENT_CENTER, s.x, 15, Color(0.82, 0.76, 0.66))
	draw_string(font, Vector2(0, refy + 70.0), "practice only:    R  restart      -  =  ball count      O  change prop      P  change pattern", HORIZONTAL_ALIGNMENT_CENTER, s.x, 15, Color(0.82, 0.76, 0.66))
	draw_string(font, Vector2(0, s.y - 40.0), "Up / Down    Enter rebind    Tab switch device    Esc back", HORIZONTAL_ALIGNMENT_CENTER, s.x, 15, Color(0.7, 0.66, 0.6))
	draw_vignette(s, 0.5)
	draw_frame(s, 22.0, Color(0.82, 0.62, 0.34, 0.5))


#endregion

#region LOW-LEVEL INPUT POLLING (KEYBOARD + PAD)
func seed_input_edges() -> void:
	# prime the edge detector with the keys' REAL current state, so a key still
	# held from the establishing card (Space especially, which would prime a
	# trick) cannot fire a phantom edge on the first play frame
	var dev := pad_dev()
	# pad seeds mirror Louis's layout: triggers are the catches, bumpers the throws,
	# PAD_TRICK the trick (see _read_inputs)
	_prev["lc"] = Input.is_physical_key_pressed(K_LC) or (dev >= 0 and Input.get_joy_axis(dev, JOY_AXIS_TRIGGER_LEFT) > 0.5)
	_prev["rc"] = Input.is_physical_key_pressed(K_RC) or (dev >= 0 and Input.get_joy_axis(dev, JOY_AXIS_TRIGGER_RIGHT) > 0.5)
	_prev["lt"] = Input.is_physical_key_pressed(K_LT) or (dev >= 0 and Input.is_joy_button_pressed(dev, JOY_BUTTON_LEFT_SHOULDER))
	_prev["rt"] = Input.is_physical_key_pressed(K_RT) or (dev >= 0 and Input.is_joy_button_pressed(dev, JOY_BUTTON_RIGHT_SHOULDER))
	_prev["trick"] = Input.is_physical_key_pressed(K_TRICK) or (dev >= 0 and Input.is_joy_button_pressed(dev, PAD_TRICK))
	_prev["cycle"] = Input.is_physical_key_pressed(K_CYCLE)
	# drop any tap latched on a previous screen, so it cannot fire on frame one
	for name in _tap:
		_tap[name] = false


func _read_inputs() -> void:
	# each logical action is keyboard OR pad, combined BEFORE edge detection, so
	# a press on either device yields exactly one edge and can never double-fire.
	if collapsing or results_open:
		return   # the set is over: the hands rest until the next run. results_open
				 # is here so a press behind the results card cannot throw or catch
				 # the props still in hand (the card is driven by _input, not by poll)
	var dev := pad_dev()
	var p_lc := false
	var p_rc := false
	var p_lt := false
	var p_rt := false
	var p_tk := false
	if dev >= 0:
		# Louis's own layout: the BUMPERS throw (they sit where the fingers rest,
		# like F and J on the home row) and the TRIGGERS catch (the squeeze is the
		# catch), PAD_TRICK is the trick (remappable). The trigger latch keeps its
		# hysteresis so an analog trigger near threshold cannot flutter a catch.
		p_lt = Input.is_joy_button_pressed(dev, JOY_BUTTON_LEFT_SHOULDER)
		p_rt = Input.is_joy_button_pressed(dev, JOY_BUTTON_RIGHT_SHOULDER)
		p_tk = Input.is_joy_button_pressed(dev, PAD_TRICK)
		_trig["lt"] = _trig_held("lt", Input.get_joy_axis(dev, JOY_AXIS_TRIGGER_LEFT))
		_trig["rt"] = _trig_held("rt", Input.get_joy_axis(dev, JOY_AXIS_TRIGGER_RIGHT))
	else:
		_trig["lt"] = false
		_trig["rt"] = false
	p_lc = bool(_trig["lt"])
	p_rc = bool(_trig["rt"])
	# take the event-latched taps FIRST (always clearing), then fold them into the
	# polled held state, so a press the 120 Hz poll was too coarse to see still
	# registers this frame. Taking them unconditionally means a held key never
	# leaves a latch behind to delay its release by a frame (see _latch_tap).
	var t_lc := _take_tap("lc")
	var t_lt := _take_tap("lt")
	var t_rc := _take_tap("rc")
	var t_rt := _take_tap("rt")
	var t_tk := _take_tap("trick")
	var k_lc := Input.is_physical_key_pressed(K_LC) or t_lc
	var k_lt := Input.is_physical_key_pressed(K_LT) or t_lt
	var k_rc := Input.is_physical_key_pressed(K_RC) or t_rc
	var k_rt := Input.is_physical_key_pressed(K_RT) or t_rt
	var k_tk := Input.is_physical_key_pressed(K_TRICK) or t_tk
	_note_device(k_lc or k_lt or k_rc or k_rt or k_tk, p_lc or p_lt or p_rc or p_rt or p_tk)
	# the trick press is handled BEFORE the throw edges, so Space hit in the same
	# frame as a throw release still empowers THAT throw (the "powerup" promise:
	# space plus catch-throw makes exactly one trick shot, never the one after).
	var tk := k_tk or p_tk
	if tk and not bool(_prev["trick"]):
		on_trick()
	_prev["trick"] = tk
	_edge("lc", k_lc or p_lc, LEFT, true)
	_edge("lt", k_lt or p_lt, LEFT, false)
	_edge("rc", k_rc or p_rc, RIGHT, true)
	_edge("rt", k_rt or p_rt, RIGHT, false)
	# trick CYCLING is event-driven, not polled (see _pad_to_key / K_CYCLE): a
	# discrete press, keyboard or pad, steps it. This flag is unused by that path.
	_prev["cycle"] = false


func pad_dev() -> int:
	# the device index of the first connected pad, or -1 when none is attached
	var pads := Input.get_connected_joypads()
	return pads[0] if not pads.is_empty() else -1


func _trig_held(name: String, v: float) -> bool:
	# analog triggers latch on above 0.5 and only let go below 0.4. the gap means
	# a trigger sitting near the threshold cannot flutter and fire a spurious
	# throw release, which would ruin the hold-for-height charge.
	if bool(_trig[name]):
		return v > 0.4
	return v > 0.5


func _note_device(kb: bool, pad: bool) -> void:
	# remember which device spoke last so the hints can follow it. the keyboard
	# wins a tie, so pad glyphs only appear from genuine pad input.
	if kb:
		_pad_last = false
	elif pad:
		_pad_last = true


func _edge(name: String, down: bool, h: int, is_catch: bool) -> void:
	var was := bool(_prev[name])
	if is_catch:
		if down and not was:
			on_catch(h)
	else:
		if down and not was:
			on_throw_press(h)
		elif was and not down:
			on_throw_release(h)
	_prev[name] = down


func _latch_tap(kc: int) -> void:
	# a discrete key-DOWN pulled from the buffered event stream, mapped to its
	# logical action. _read_inputs folds this into the polled held state, so a tap
	# whose down and up both fall between two physics ticks (invisible to the state
	# poll) still fires exactly one press. Never produces input on its own: only a
	# real key-down sets a latch, so this can add a missed press but never a phantom.
	if kc == K_LC:
		_tap["lc"] = true
	elif kc == K_LT:
		_tap["lt"] = true
	elif kc == K_RC:
		_tap["rc"] = true
	elif kc == K_RT:
		_tap["rt"] = true
	elif kc == K_TRICK:
		_tap["trick"] = true


func _take_tap(name: String) -> bool:
	# read and CLEAR a latched tap, so it fires on exactly one read and never sticks
	var v := bool(_tap[name])
	_tap[name] = false
	return v


# -----------------------------------------------------------------------------
# Geometry: OUTER catch point and INNER throw point per hand. Rising balls leave
# the inside, falling balls arrive on the outside, so their lanes never overlap.
# -----------------------------------------------------------------------------

#endregion

#region HAND GEOMETRY & BALL SLOTTING
func stack(h: int) -> Array[Ball]:
	return _stack_l if h == LEFT else _stack_r


func other(h: int) -> int:
	return RIGHT if h == LEFT else LEFT


func atick() -> float:
	# one cosmetic clock that advances in EVERY state: tick runs during play,
	# cine_tick runs in menus and cutscenes, so their sum always moves. Scenery
	# animation (stars, dust, lanterns, marquee bulbs) keys off this, which lets
	# the same primitives breathe both in cutscenes and behind live play.
	return float(tick + cine_tick)


func stage_center() -> Vector2:
	# the juggling hand height: about the figure's waist on the eight-head canon, so
	# the hands scoop at a natural level and the arms keep a natural (canon) length
	var s := get_viewport_rect().size
	return Vector2(s.x * 0.5, s.y * 0.57)


func outer_pos(h: int) -> Vector2:
	# the catch position, a little in from a shoulder-and-a-half so the arms rest a touch
	# less splayed (Louis). Kept 46px out from inner_pos so the crossing weave still
	# clears (see inner_pos); pulling only this one in cramps the two roads into overlap.
	# The stance NEVER widens for props or counts (Louis: the wide arms looked
	# horrible) - big loads keep their clearance by shrinking the prop HITBOX
	# instead, the drawn prop staying its true size. See prop_hit_scale.
	var c := stage_center()
	var dx := 100.0
	return Vector2(c.x - dx, c.y) if h == LEFT else Vector2(c.x + dx, c.y)


func inner_pos(h: int) -> Vector2:
	# just outside the torso silhouette, so a carried ball never sits on the body.
	# outer_pos and this move IN TOGETHER (Louis wanted the arms a touch less splayed):
	# the crossing clearance depends on outer - inner (the two crossing balls peak
	# ~(outer - inner) apart), so shrinking both by the same amount narrows the whole
	# stance without pulling the crossing weave into an overlap.
	var c := stage_center()
	var dx := 54.0
	return Vector2(c.x - dx, c.y) if h == LEFT else Vector2(c.x + dx, c.y)


func slot_pos(h: int, slot: int) -> Vector2:
	match slot:
		HAND_INNER:
			return inner_pos(h)
		_:
			return outer_pos(h)


func shoulder_pos(h: int) -> Vector2:
	# where the arms leave the body: the outer corner of the jacket's shoulder, one
	# arm-root radius BELOW the shoulder line. The upper-arm capsule is ~19px thick,
	# so an attach point ON the line let half the deltoid peak above the silhouette
	# (Louis: shoulders belong at shoulder height, not over it).
	var s := get_viewport_rect().size
	var c := s.x * 0.5
	var H := s.y * 0.056
	var y := s.y * 0.80 - 6.38 * H
	var dx := 0.9 * H
	return Vector2(c - dx, y) if h == LEFT else Vector2(c + dx, y)


func columns_x(slot: int) -> float:
	# the x of vertical column `slot` (0..num_balls-1) in a Columns pattern, spread
	# symmetric about centre so every ball owns its own line and no two share air
	var sp := 44.0 if num_balls <= 5 else 40.0
	return stage_center().x + (float(slot) - float(num_balls - 1) * 0.5) * sp


func assign_lane(b: Ball, h: int) -> void:
	# give a lane ball its own column: the nearest free slot on its hand's side.
	# Left hand owns the left columns, right the right, the centre column (odd
	# counts) is the middle ball and is never assigned here. Persists on the ball.
	if b.lane_x >= 0.0:
		return
	var mid_slot := (num_balls / 2) if num_balls % 2 == 1 else -1
	var lo := 0
	var hi := num_balls / 2 - 1
	if h == RIGHT:
		lo = (mid_slot + 1) if mid_slot >= 0 else num_balls / 2
		hi = num_balls - 1
	elif mid_slot >= 0:
		hi = mid_slot - 1
	var taken := {}
	for o in balls:
		if o != b and o.lane_x >= 0.0:
			taken[int(round(o.lane_x))] = true
	for slot in range(lo, hi + 1):
		var x := columns_x(slot)
		if not taken.has(int(round(x))):
			b.lane_x = x
			return
	b.lane_x = columns_x(clampi(lo, 0, num_balls - 1))   # fallback: never leave it unset


func incoming_low(h: int) -> bool:
	# is any NON-over-the-top ball airborne toward hand h's catch point right now?
	# The corner between an outgoing throw and this incoming ball is where every
	# mid-air overlap lived, so throws made over it dodge sideways (see do_throw)
	for b in balls:
		if b.state == STATE_FLIGHT and b.to_hand == h and not b.over_top:
			return true
	return false


func next_throw_over_top(h: int) -> bool:
	# whether hand h's NEXT throw is an over-the-top launch. This is its own KIND
	# of throw (Louis): no inward carry, the hand lobs straight from the OUTER
	# catch point, which is what keeps the high road clear of the low weave. Used
	# always (Reverse Cascade), on one hand (Waterfall's right, the other stays
	# low), for one throw (Overthrow), or back and forth (Tennis's marked ball).
	# Mirrors the over_top decision in do_throw, read BEFORE the ball is popped.
	if trick_primed and trick_sel == TR_OVER:
		return true
	if pattern == RCASC:
		return true
	if pattern == WFALL and h == RIGHT:
		return true
	if pattern == TENNIS:
		if tennis_ball == null or not balls.has(tennis_ball):
			return true   # nothing marked yet: the very NEXT throw claims the mark
		return stack(h).has(tennis_ball)
	# the shower's and half shower's high hand ride the over-the-top road too
	return h == RIGHT and pattern in [SHOWER, HALFSHOWER]


# the STRUCTURAL throw/catch point for hand h under the current pattern/trick -
# always safe to read live, since it reflects what the player has already
# committed to (the pattern, an active toggle), never a guess about a ball in
# flight. throw_slot is read every tick while h is holding (see hand_target);
# catch_slot only seeds the initial hand_catch_rest, since after that the actual
# CATCH point is locked in per-ball at throw time (do_throw), not re-derived here.
func throw_slot(h: int) -> int:
	if pattern == COLUMNS:
		# Columns rests at ONE point (Louis, ROADMAP 12b): the same slot it catches at,
		# so the hand holds still and only the vertical throw-kick moves it. It used to
		# throw from VERY_INNER and catch at INNER - two slots 34px apart, retargeted
		# every catch/throw, so the hand never settled and read as a tremor. The lane
		# ball flies to its own lane_x either way (do_throw's `lanes` branch, never the
		# hand slot), so the hand slot is purely where the sprite waits; INNER sits
		# closest to the actual lanes, so it also shrinks the hand/ball gap.
		return HAND_INNER
	return HAND_OUTER if next_throw_over_top(h) else HAND_INNER


func catch_slot(h: int) -> int:
	if pattern == COLUMNS:
		return HAND_INNER
	if next_throw_over_top(other(h)):
		return over_top_land_slot(h)
	return HAND_OUTER


# where an over-the-top throw COMES DOWN on hand t, and the one rule that keeps the high
# road clear of the low weave. Hand t has three fixed slots: OUTER (its normal catch, dx
# 104), INNER (its normal throw, dx 58), VERY_INNER (dx 24). An over-the-top landing must
# avoid every OTHER thing that occupies a slot on t, so it takes a slot nothing else uses.
# A geometric guarantee, not a tuned gap, holding at any cadence and for patterns not yet
# written (Phase 5).
#
# This is the fix for the ROADMAP 12a regression and its follow-on. ddbd706 landed every
# over-the-top throw at INNER: the reverse cascade wanted that close crossing (both its
# hands ride the high road, launch from OUTER, so INNER was free) but a MIXED pattern's
# low hand LAUNCHES from INNER, so the landing sat on the launch - -14px Half Shower,
# -22px Shower, a launch and a landing on one pixel.
#
# So it lands on the complement of t's OWN launch slot: INNER when t launches from OUTER
# (reverse cascade, both hands high), OUTER when t launches from INNER (a low hand). A
# landing then never sits on a launch, which was the whole -14/-22px regression. Landing
# at OUTER also costs no extra reach - it is the hand's normal catch point, where it is
# already waiting.
#
# This picks the LANDING slot only. It cannot, by itself, keep a MIXED pattern's high
# road from sharing air with the low weave mid-flight: now that every path is a strict
# parabola (Louis - no sideways swerve to dodge with), an over-the-top ball and a low
# ball timed into the same corner simply cross there, exactly as two juggling balls do.
# Good timing keeps them from occupying that corner at the SAME instant (a real player,
# and the Phase 5 siteswap rework, throw on a rhythm that interleaves them); the naive
# alternating autoplayer does not, so --collcheck still reports crossings on Waterfall
# and Tennis. Those read as balls crossing, not as an impossible path, and the mid-air
# clack penalty only bites in hard mode - so this is left to the siteswap rework, which
# replaces this whole hand-picked geometry with a rhythm derived from the pattern.
func over_top_land_slot(t: int) -> int:
	return HAND_INNER if throw_slot(t) == HAND_OUTER else HAND_OUTER


# where hand h wants to be right now (Louis): while holding, wherever ITS OWN
# next throw departs from; once empty, exactly where the soonest ball flying its
# way will actually land (to_pos: the landing ring's spot), so the ring always
# draws centred on the waiting palm - the fountain's widened landing sat 22px
# off the slot the hand used to wait at, and its rings read as "wrong" next to
# the cascade's. With nothing inbound, the slot the last throw aimed at.
func hand_target(h: int) -> Vector2:
	var p: Vector2
	var inc: Ball = null
	for b in balls:
		if b.state == STATE_FLIGHT and b.to_hand == h:
			if inc == null or b.land_tick < inc.land_tick:
				inc = b
	if not stack(h).is_empty():
		# holding, but a hand may catch INTO a held stack now (Louis), so when a
		# ball is about to land its way it still reaches for the landing point;
		# otherwise it rests where its own next throw departs from
		p = inc.to_pos if inc != null and inc.land_tick - tick < 36 else slot_pos(h, throw_slot(h))
	else:
		p = inc.to_pos if inc != null else slot_pos(h, hand_catch_rest[h])
	# a brief upward kick right after a throw sells the release
	var k := tick - int(throw_kick[h])
	if k >= 0 and k < 14:
		p.y -= 22.0 * (1.0 - float(k) / 14.0)
	return p


func ball_color(i: int) -> Color:
	var cols := [
		Color(1.0, 0.82, 0.35),
		Color(1.0, 0.55, 0.25),
		Color(0.95, 0.40, 0.42),
		Color(0.72, 0.86, 0.95),
	]
	return cols[i % cols.size()]


# -----------------------------------------------------------------------------
# Start: balls begin held, and the run begins on the player's first throw.
# -----------------------------------------------------------------------------

# the Strength each ball count asks for, indexed by count (3 is free). The first
# rungs sit in the old 0..100 band; 8-15 climb the raised band toward the 200 cap,
# so the late game keeps earning new loads long after the World Arena. 12-15 added
# 2026-07-18 (Louis, after the throw-height clamp made room for more objects):
# the last few rungs close in tight on STR_CAP, so 15 objects is earned at almost
# exactly a maxed Strength stat, not before it.
const BALL_GATES := {4: 9, 5: 15, 6: 23, 7: 33, 8: 60, 9: 90, 10: 125, 11: 165, 12: 175, 13: 183, 14: 191, 15: 200}


func max_balls() -> int:
	# THREE to start; every larger load is earned through Strength, each landing a bit
	# before the stage that leans on it (Louis). Four is the first unlock now, not free.
	var m := 3
	for n in range(4, MAX_BALLS_HARD + 1):
		if strength >= int(BALL_GATES[n]):
			m = n
	return m


func next_ball_strength() -> int:
	# Strength needed for the next ball unlock, or 0 if already at the cap
	for n in range(4, MAX_BALLS_HARD + 1):
		if strength < int(BALL_GATES[n]):
			return int(BALL_GATES[n])
	return 0


func count_air_scale() -> float:
	# the tap-height FLOOR scales with the load: 3-4 balls stay snappy and low, but five
	# and up must fly higher just to have air to weave in, so even a tap lofts a big load
	# enough to juggle. ~+45% airtime at six matches a real six-ball fountain's hold; the
	# 8-11 late-game loads keep climbing the same curve.
	if num_balls >= 5:
		return 1.3 + 0.15 * float(num_balls - 5)
	return 1.0


#endregion

#region ROUND START, CATCHING, GOALS
func start_run(n: int) -> void:
	if not available(prop_type):
		prop_type = PROP_BALLS   # not enough of that prop owned: fall back to balls
	# you cannot juggle more of a prop than you own (balls are unlimited)
	var cap := mini(max_balls(), have(prop_type))
	num_balls = clampi(n, MIN_BALLS, maxi(MIN_BALLS, cap))
	# the chosen pattern, snapped to what this level owns. The two beginner
	# patterns still auto-match the count's parity (odd weaves, even fountains);
	# an explicitly chosen exotic pattern sticks whatever the count.
	if not pattern_unlocked(pattern_sel) or pattern_sel == CASCADE or pattern_sel == FOUNTAIN:
		pattern_sel = CASCADE if num_balls % 2 == 1 else FOUNTAIN
	pattern = pattern_sel
	# a Skills-screen practice runs its chosen pattern for THIS session without
	# re-booking the act: P (cycle_pattern) clears the override, an explicit choice.
	# The two parity starters stay snapped to the count (an odd fountain has never
	# been juggleable here, and the override must not smuggle one in).
	if pattern_once >= 0 and pattern_unlocked(pattern_once):
		pattern = pattern_once
		if pattern == FOUNTAIN and num_balls % 2 == 1:
			pattern = CASCADE
		elif pattern == CASCADE and num_balls % 2 == 0:
			pattern = FOUNTAIN
	balls.clear()
	_stack_l.clear()
	_stack_r.clear()
	popups.clear()
	charging = [false, false]
	applause = 0.7
	peak_applause = 0.7
	score = 0
	streak = 0
	best_streak = 0
	dropped = 0
	caught = 0
	# per-ACT state re-arms every run (the challenge roll is owned by
	# begin_performance, so practice and a dev autoplay never carry one)
	goals_hit = 0
	set_collapsed = false
	fail_reason = ""   # a fresh act has not failed yet
	running = false
	started = false
	stamina_max = 100.0 + 9.0 * float(endurance)
	# stamina PERSISTS through the day now: only sleep (or a meal) restores it, so
	# a third booking in one evening is genuinely tired work. Dev auto-runs top up
	# so screenshots stay comparable.
	if _demo or _shot or debug_mode:
		stamina = stamina_max
	stamina = clampf(stamina, 0.0, stamina_max)
	run_xp = 0
	last_pay = 0
	last_rep_delta = 0
	run_venue = play_venue()   # records and the results card key off where you performed
	results_open = false
	results_record = false
	results_tick = -999
	results_stamped = false
	record_broken = false
	last_streak_tick = -999
	freeze = 0
	parts.clear()
	paused = false
	round_scored = false
	_prev_running = false
	# reset the per-run trick state. The SELECTION survives between runs (that is
	# the promise of the powerup model), and so does a RUNNING TOGGLE (Louis: an R
	# retry keeps the trick on, so it can be drilled run after run) - only its
	# per-run bookkeeping (the marked tennis ball, the lane reference) re-arms.
	# Snap both onto tricks this level actually owns, so a debug level change can
	# never leave a locked trick loaded or running.
	trick_primed = false
	if toggle_on >= 0 and not trick_unlocked(toggle_on):
		toggle_on = -1
	toggle_scored = false
	tennis_ball = null
	col_air_ref = -1.0
	col_mid_ball = null
	if trick_sel < 0 or not trick_unlocked(trick_sel):
		var un := unlocked_tricks()
		trick_sel = int(un[0]) if not un.is_empty() else -1
	trick_ready = -999
	spin_until = -999
	spin_scored = false
	tricks_landed = 0
	trick_score = 0
	trick_msg = ""
	trick_msg_tick = -999
	rng.seed = 20260705
	seed_input_edges()   # a key still held from the previous screen must not edge-fire
	collapsing = false
	falling.clear()
	# slow motion: the earned bursts reset per run (the pie keeps working all
	# day, so pie_active is untouched here and only sleep clears it)
	perfect_chain = 0
	amazing_until = -999999
	chain_until = -999999
	_slow_cur = 0.0
	_tick_acc = 1.0
	hpos = [outer_pos(LEFT), outer_pos(RIGHT)]
	hand_catch_rest = [catch_slot(LEFT), catch_slot(RIGHT)]
	hclose = [0.0, 0.0]
	catch_flash = [-999, -999]
	throw_kick = [-999, -999]

	# right hand gets the extra on odd counts (the classic two-in-one-hand start)
	for i in num_balls:
		var b := Ball.new()
		b.state = STATE_HAND
		b.kind = prop_type
		b.color = ball_color(i) if prop_type == PROP_BALLS else prop_color(prop_type)
		b.spin_dir = 1.0 if i % 2 == 0 else -1.0
		balls.append(b)
		if i % 2 == 0:
			_stack_r.append(b)
		else:
			_stack_l.append(b)
	_demo_next = RIGHT


# -----------------------------------------------------------------------------
# Catch: strict. Window = secure (quality band). Committed-but-mistimed = drop.
# Nothing near = whiff (small poise wobble, no ball lost).
# -----------------------------------------------------------------------------

func on_catch(h: int) -> void:
	if collapsing:
		return  # the act has fallen apart: you watch it all come down, you cannot save it.
				# Without this a player (or the autoplayer) could keep catching the still-
				# airborne props after the crowd walked, grinding score with the clock off.
	# a hand that already HOLDS a ball may still catch (Louis): the stack takes
	# another. The old "hand occupied, no catch" traffic rule is gone - traffic
	# is now the player's own problem, and holding two is a legitimate rescue.
	var best: Ball = null
	var best_d := 1000000
	for b in balls:
		# the odd-columns middle ball comes straight down dead centre and EITHER
		# hand may scoop it (Louis), so it counts for whichever catch fires first;
		# every other ball is claimed only by the hand it is actually flying to
		if b.state == STATE_FLIGHT and (b.to_hand == h or b == col_mid_ball):
			var d := absi(b.land_tick - tick)
			if d < best_d:
				best = b
				best_d = d
	if best == null or best_d > COMMIT:
		# reached for empty air: a whiff. Discourage mashing with a small wobble.
		applause = maxf(0.0, applause + APPL_WHIFF)
		catch_flash[h] = tick
		hclose[h] = 0.0
		add_popup(outer_pos(h), "whiff", Color(0.7, 0.66, 0.6, 1.0))
		play_sfx("whiff", -12.0)
		return
	if best_d > W_LATE:
		# way off the arrival: a genuine mistime, the ball drops
		drop_ball(best, "MISTIME")
		return
	# out of stamina: your hands simply cannot close (Louis). A well-timed arrival that
	# would otherwise be caught slips through, which soon trips the drop limit and ends
	# the set - see the exhaustion redirect in drop_ball, straight to eat/sleep.
	if stamina <= 0.0:
		drop_ball(best, "SPENT")
		return
	# hard mode (set_collide): a ball that clacked another mid-air only catches
	# on PERFECT timing - the full Perfect window (Louis: same frames as normal,
	# not halved), but the Good/Late chance roll never applies. Saving one still
	# counts as the Perfect it timing-wise is.
	if best.bumped and best_d > perfect_window():
		drop_ball(best, "collided")
		return
	# Perfect timing always secures. A Good or Late catch is a chance that rises
	# with Accuracy and falls with how far off the standard height the throw was.
	# The Perfect window itself shrinks for off-standard throws (Focus widens it),
	# so a wrong-height throw is hard to catch cleanly and easy to lose.
	var wperf := perfect_window()
	if best_d > wperf:
		var quality := 1 if best_d <= W_GOOD else 2
		if rng.randf() > catch_chance(quality, best.height):
			drop_ball(best, "slip")
			return
	# secured. Was the act actually RUNNING as this landed, or did the air just empty?
	# (Louis: juggling is at least one prop airborne at all times; anything else is
	# throwing one thing and catching it). Asked here, before the ball is put away.
	var juggled := juggling_catch(best)
	# harder patterns AND harder loads pay more per catch (their base difficulty is the
	# reward), so grinding the tamest routine is never the best. encore_score_mult zeroes
	# light props on a "For the Danger" night.
	var pm := pattern_mult() * object_mult() * encore_score_mult()
	best.state = STATE_HAND
	stack(h).append(best)
	catch_flash[h] = tick
	caught += 1
	career["catches"] = int(career["catches"]) + 1
	if tut_active:
		tut_on_catch(juggled)   # a guided lesson counts your clean catches toward its goal
	stamina = maxf(0.0, stamina - STAM_DRAIN_CATCH * energy_mult() * (1.0 + WEIGHT_STAM * float(prop_weight(best.kind) - 1)))
	# NO per-prop catch texture here (Louis, 2026-07-18: only perfect/good/late/
	# whiff, never a special sound per object) - it used to be
	# `play_sfx(_catch_sound(best.kind), -20.0)` right here. The sounds themselves
	# are still generated in gen_sfx if this ever wants to come back.
	var sc_before := score
	var cashing_in := false
	if not juggled and not tut_active:
		# NOT JUGGLING (juggling_catch): the air is bare behind this catch. On stage
		# with a goal already reached, that IS the cash-in gesture (Louis): you caught
		# every ball, you are holding them all, the act ends right here on your own
		# terms - same as the finish key, and the crowd reads the stillness as the bow.
		# It is still a REAL catch (Louis: it should show its Perfect/Good/Late and
		# play the same sound as any other), so this falls through to the normal
		# scoring below instead of returning early; `cashing_in` fires the actual
		# finish only at the very end, after that scoring has happened.
		if mode == MODE_PERFORM and booking_active and goals_hit >= 1 \
				and running and not collapsing and balls_airborne() == 0:
			add_popup(outer_pos(h) + Vector2(0, -30), "CAUGHT THEM ALL", Color(1.0, 0.86, 0.42))
			cashing_in = true
		else:
			# otherwise: the player threw one prop and caught it again while the rest sat
			# in their hands. The catch is real - it happened, it cost stamina, it keeps
			# the prop off the floor - but the ACT is not running, so it earns nothing at
			# all: no streak, no score, no crowd, no trick, and no popup calling it out.
			# That shuts the grind where holding two and pumping the third farmed a clean
			# Perfect every single time. A lesson is exempt: it runs at one and two props
			# on purpose, scores nothing, and polices the rule itself (tut_on_catch).
			streak = 0
			perfect_chain = 0
			return
	if best_d <= wperf:
		streak += 1
		best_streak = maxi(best_streak, streak)
		last_streak_tick = tick
		score += int(round(100.0 * streak_mult() * pm))
		applause = minf(1.0, applause + APPL_PERFECT)
		add_xp(3)
		# the slow-motion earn, only when a REAL pattern is up (three props or
		# more, so two lazy balls cannot farm it): a FRAME-perfect catch is an
		# Amazing! burst, and FIFTY straight Perfects buy thirty seconds of thick
		# time, after which the count starts over for the next thirty
		if num_balls >= SLOW_MIN_BALLS:
			perfect_chain += 1
			if best_d == 0:
				amazing_until = _frames + AMAZING_FRAMES
				add_popup(outer_pos(h) + Vector2(0, -52), "AMAZING!", Color(0.75, 0.92, 1.0))
			if perfect_chain >= CHAIN_NEED:
				perfect_chain = 0
				chain_until = _frames + CHAIN_FRAMES
				add_popup(Vector2(get_viewport_rect().size.x * 0.5, get_viewport_rect().size.y * 0.30), "FIFTY PERFECT  -  thirty seconds of thick time", Color(0.75, 0.92, 1.0))
				play_sfx("record", -8.0)
		add_popup(outer_pos(h), "PERFECT", Color(1.0, 0.86, 0.42))
		play_sfx("perfect", -5.0)
		spawn_parts(outer_pos(h), Color(1.0, 0.88, 0.45), 9, 3.4, "spark")
		spawn_parts(outer_pos(h), Color(1.0, 0.9, 0.6), 1, 0.0, "ring")
		if streak % 10 == 0:
			# a milestone: a beat of hit-stop, a shock ring, a toast, the crowd lifts
			freeze = 4
			spawn_parts(outer_pos(h), Color(1.0, 0.82, 0.4), 2, 0.0, "ring")
			var vs := get_viewport_rect().size
			add_popup(Vector2(vs.x * 0.5, vs.y * 0.33), "x%d STREAK" % streak, Color(1.0, 0.82, 0.4))
			if mode == MODE_PERFORM:
				play_sfx("cheer", -11.0)
		elif streak % 5 == 0:
			play_sfx("streak", -7.0)   # a rising flourish at every fifth in a row
	elif best_d <= W_GOOD:
		perfect_chain = 0
		streak += 1
		best_streak = maxi(best_streak, streak)
		last_streak_tick = tick
		score += int(round(50.0 * streak_mult() * pm))
		applause = minf(1.0, applause + APPL_GOOD)
		add_xp(2)
		add_popup(outer_pos(h), "GOOD", Color(0.78, 0.92, 0.6))
		play_sfx("good", -8.0)
		spawn_parts(outer_pos(h), Color(0.85, 0.92, 0.6), 4, 2.4, "spark")
		if streak % 5 == 0:
			play_sfx("streak", -8.0)
	else:
		streak = 0
		perfect_chain = 0
		score += int(round(10.0 * pm))
		applause = maxf(0.0, applause + APPL_LATE)
		add_xp(1)
		add_popup(outer_pos(h), "late", Color(0.95, 0.62, 0.4))
		play_sfx("late", -11.0)
	# the record chase: passing your own best AT this venue mid-act is a moment. The
	# act is one continuous run now, so its live score IS the number the record
	# board will judge.
	if mode == MODE_PERFORM and not record_broken and run_venue >= 0 and run_venue < rec_table().size() \
			and rec_table()[run_venue] > 0 and score > rec_table()[run_venue]:
		record_broken = true
		var s := get_viewport_rect().size
		add_popup(Vector2(s.x * 0.5, s.y * 0.27), "NEW RECORD!", Color(1.0, 0.86, 0.42))
		play_sfx("record", -7.0)
		spawn_parts(Vector2(s.x * 0.5, s.y * 0.16), Color(1.0, 0.85, 0.45), 26, 2.6, "confetti")

	# a live Spin doubles whatever this catch scored, and credits the trick once
	if spinning():
		var extra := score - sc_before
		score += int(round(float(extra) * (SPIN_CATCH_MULT - 1.0)))
		trick_score += int(round(float(extra) * (SPIN_CATCH_MULT - 1.0)))
		applause = minf(1.0, applause + APPL_SPIN)
		add_popup(outer_pos(h) + Vector2(0, -20), "x2", Color(0.72, 0.9, 1.0))
		if not spin_scored:
			spin_scored = true
			tricks_landed += 1
			add_xp(3)
	# an ARM trick (High Toss / Behind the Back) pays its flourish on a clean catch
	if best.trick >= 0 and best_d <= W_GOOD:
		reward_trick(best.trick, outer_pos(h), best.height)
	# THE ACT: this catch (with any trick bonus above) may carry the score across the
	# next goal, which arms - or re-arms - the cash-in
	if booking_active and mode == MODE_PERFORM and not tut_active:
		check_goals()
	if cashing_in:
		finish_performance()   # only now, after the catch has scored like any other


func check_goals() -> void:
	# the instant the score crosses a goal it LOCKS (goals_hit is monotonic: a
	# collapse later can strip score, never a goal already reached). Each crossing
	# is announced by name, and from the first one on the HUD holds the cash-in
	# offer open: bow out with the finish key, catch everything and hold, or push
	# for the next number and risk the collapse.
	if not booking_active or mode != MODE_PERFORM or tut_active:
		return
	while goals_hit < NUM_GOALS and score >= goal_for(run_venue, goals_hit):
		goals_hit += 1
		var s := get_viewport_rect().size
		var names := ["FIRST GOAL", "SECOND GOAL", "FINAL GOAL"]
		var txt := "%s  -  cash in any time, or push on" % names[clampi(goals_hit - 1, 0, 2)]
		if goals_hit >= NUM_GOALS:
			txt = "FINAL GOAL  -  the night is yours. Cash in, or chase the record"
		add_popup(Vector2(s.x * 0.5, s.y * 0.24), txt, Color(1.0, 0.86, 0.42))
		play_sfx("cheer", -5.0)
		play_sfx("record", -8.0)
		spawn_parts(Vector2(s.x * 0.5, s.y * 0.16), Color(1.0, 0.85, 0.45), 22, 2.5, "confetti")


# -----------------------------------------------------------------------------
# Throw: charge on THROW down-edge, launch on release. Longer hold = higher and
# less accurate. Height buys airtime (thins traffic) at the cost of a harder catch.
# -----------------------------------------------------------------------------

#endregion

#region THROWING
func on_throw_press(h: int) -> void:
	if collapsing or stack(h).is_empty():
		return   # nothing you throw during a collapse counts; the set is already over
	charging[h] = true
	charge_start[h] = tick


func on_throw_release(h: int) -> void:
	if not charging[h]:
		return
	charging[h] = false
	if stack(h).is_empty():
		return
	var hold := clampi(tick - int(charge_start[h]), 0, HOLD_MAX)
	do_throw(h, hold)


func do_throw(h: int, hold: int) -> void:
	if collapsing or stack(h).is_empty():
		return
	var b: Ball = stack(h).pop_front()
	b.trail = PackedVector2Array()
	b.bumped = false   # a fresh throw starts clean; only a NEW mid-air clack marks it
	var weight := prop_weight()
	var deficit := prop_deficit()   # >0 when too weak for this prop: lower and wilder
	# A tap is the LOWEST, snappiest throw; each tick of hold adds airtime. Height is set by
	# how long you hold, NOT by Strength: raw muscle must never loft a throw higher (a higher
	# throw is a wilder throw, so tying Strength to height wrongly punished the strong).
	# Strength ONLY matters when you are UNDER a prop's Required Strength: then the whole
	# throw sags (the ideas.rtf rule) with a lower tap floor (DEFICIT_BASE) AND a lower
	# ceiling (DEFICIT_HEIGHT), so a too-heavy prop never gets up to a clean height.
	# higher loads must fly HIGHER just to have time to weave (Louis): a 5/6/7 fountain
	# thrown at the 3-ball tap height comes back down before the hand can clear its other
	# props, so everything drops at once and it felt unthrowable. Airtime rises with the
	# count, so the tap FLOOR does too - a tap already lofts a big load enough to juggle.
	var base_air := float(BASE_AIR) * count_air_scale() * (1.0 - DEFICIT_BASE * deficit)
	var gain_mult := 1.0 - DEFICIT_HEIGHT * deficit
	# SURPLUS Strength over a heavy prop's requirement lofts it HIGHER per held
	# tick, scaled by weight (Louis: five clubs need real height to fit in the
	# air). Balls and eggs are untouched, and being under-strength still sags.
	if prop_req() > 0 and weight > 1 and deficit <= 0.0:
		gain_mult *= 1.0 + STRENGTH_LOFT * strength_surplus() * float(weight - 1) / 4.0
	var air := int(round(base_air + HOLD_GAIN * gain_mult * float(hold)))

	# a primed one-shot (Overthrow) reshapes this ONE throw; consuming the prime here
	# disarms it, while trick_sel keeps the selection for the next Space press. The
	# FLOURISH TOGGLES (High Toss, Behind the Back) shape EVERY throw while they run
	# (Louis: switch on, throw, switch off for a single one - that way the trick can
	# be trained continuously). A trick's forced height is built off the SAME lowered
	# base and Strength penalty, so an under-strength High Toss sags too and cannot
	# cheat the sagging rule.
	var this_trick := -1
	if trick_primed and trick_sel >= 0 and String(TRICKS[trick_sel]["kind"]) == "arm":
		this_trick = trick_sel
		trick_primed = false
	elif toggle_on == TR_HIGH or toggle_on == TR_BTB:
		this_trick = toggle_on
	if this_trick == TR_HIGH or this_trick == TR_BTB:
		var tfrac := clampf(float(air - BASE_AIR) / (HOLD_GAIN * float(HOLD_MAX)), 0.0, 1.4)
		if this_trick == TR_HIGH:
			# a TAP already powers the toss sky high; HOLDING the throw powers it
			# further, up to 1.8 at a full hold - high enough to leave the frame for
			# a beat (a top-edge marker tracks it, see draw_balls_in_flight). The
			# extra height keeps its honest cost: the landing spreads wider and the
			# arrival gets less certain (height feeds drift/wobble/jitter below),
			# while the catch-chance penalty saturates at the 1.4 cap.
			tfrac = 1.35 + 0.45 * minf(tfrac, 1.0)
		else:
			tfrac = clampf(tfrac + 0.12, 0.0, 1.4)   # a touch higher to clear the arc behind the back
		air = int(round(base_air + tfrac * HOLD_GAIN * float(HOLD_MAX) * (1.0 - DEFICIT_HEIGHT * deficit)))
	# the pattern shapes the throw: a shower's feed hand snaps a fast low pass no
	# matter the hold. An ARMED ONE-SHOT (this_trick >= 0 here) always wins its
	# one throw: the player paid a press for it, so no pattern may flatten it
	# into a low pass that would still collect the trick's full bonus on the
	# catch (the shower feed used to do exactly that, a quiet 260-a-catch exploit).
	if pattern == SHOWER and h == LEFT and this_trick < 0:
		air = int(round(base_air * SHOWER_FEED))
	# the PATTERN shapes every throw (there is exactly one pattern at a time now -
	# Louis - so Reverse Cascade, Waterfall and Tennis reshape here as patterns,
	# never as trick toggles), and Overthrow (a one-shot) sends this single throw
	# up and over the top of whatever pattern runs. Pattern throws are NOT tagged
	# as tricks: the pattern's own score mult is its reward.
	# The SHOWER's and HALF SHOWER's high hand ride the same over-the-top road
	# (that is what those patterns ARE), so they inherit the outer launch, the
	# wide landing, and the corner dodge in one mechanic.
	var over_top := this_trick == TR_OVER
	if h == RIGHT and pattern in [SHOWER, HALFSHOWER]:
		over_top = true
	if pattern == WFALL:
		if h == RIGHT:
			over_top = true
		elif this_trick < 0:
			# the other hand keeps the weave, but forced LOW (a ceiling, not a floor),
			# so it visibly flows under the over-the-top side instead of drifting up
			# to meet it when the player holds both hands about the same
			air = mini(air, int(round(base_air + WATERFALL_LOW * HOLD_GAIN * gain_mult * float(HOLD_MAX))))
	elif pattern == RCASC:
		over_top = true
	elif pattern == TENNIS:
		if tennis_ball == null or not balls.has(tennis_ball):
			tennis_ball = b   # the marked ball: the first one thrown under the pattern
		if b == tennis_ball:
			over_top = true
	if over_top:
		var high_min := OVER_TOP_MIN
		if pattern == WFALL and h == RIGHT:
			high_min = maxf(high_min, WATERFALL_HIGH)
		if h == RIGHT and pattern == SHOWER:
			high_min = maxf(high_min, SHOWER_MIN)
		elif h == RIGHT and pattern == HALFSHOWER:
			high_min = maxf(high_min, HALFSHOWER_MIN)
		air = maxi(air, int(round(base_air + high_min * HOLD_GAIN * gain_mult * float(HOLD_MAX))))
	# Columns (the pattern or the toggle trick) pulls this throw's airtime toward the
	# lanes' running height, so a slightly early or late release still lands close to
	# the others instead of drifting the apexes apart (Louis: mismatched heights made
	# the catch timing unreadable). Breakout throws are exempt: an over_top throw and
	# an armed one-shot (High Toss, Behind the Back) are meant to stand out, not blend
	# in - and neither may drag the lanes' reference height up after itself.
	var col_lanes := pattern == COLUMNS
	if col_lanes and not over_top and this_trick != TR_HIGH and this_trick != TR_BTB:
		if col_air_ref < 0.0:
			col_air_ref = float(air)
		else:
			air = int(round(lerp(float(air), col_air_ref, COLUMNS_SYNC)))
		col_air_ref = lerp(col_air_ref, float(air), 0.5)
	# frac is the height ACTUALLY reached (measured off the full-strength tap floor), so a
	# sagging under-strength throw reads as the low throw it is: easier to catch, worth less
	# Applause, and it clamps to 0 when the prop is too heavy to loft at all. The ceiling is
	# 1.8, reserved for a TRICK (only a held High Toss actually reaches it) - plain throws
	# clamp at 1.4. This clamp is EXPLICIT now (2026-07-18): count_air_scale (high ball
	# counts fly higher) and the Strength-surplus loft bonus (a heavy prop you're well
	# over-strength for flies higher too) both push air time up independently, and at
	# their extreme - maxed Strength, the heaviest prop, the highest count - they used to
	# stack past 1.4 on an ordinary throw with no trick at all (measured: a PLAIN full-hold
	# torch throw at 7 objects and max Strength hit 1.8, the trick-only ceiling, and even a
	# bare TAP already reached 0.6). Louis noticed this as "why do Behind the Back throws
	# with 7 torches go so high" - BTB was not the actual cause, just the visible symptom;
	# every plain throw at that combination was already pinned near the ceiling.
	var frac := clampf(float(air - BASE_AIR) / (HOLD_GAIN * float(HOLD_MAX)), 0.0, 1.8 if this_trick >= 0 else 1.4)
	b.height = frac
	b.trick = this_trick

	# Accuracy (dampened by low stamina) sets the base inaccuracy; being UNDER a prop's
	# Required Strength widens it. Weight alone does NOT: a heavy prop you are strong enough
	# for throws just as cleanly as a ball (only low Strength makes a heavy prop wild).
	# Inaccuracy normally scales with the throw's HEIGHT, so a low throw is placed cleanly.
	# But an under-strength RELEASE is itself unsteady, so a "spread floor" keyed to the
	# deficit keeps even a low under-strength throw drifting and wobbling, otherwise a weak
	# juggler could just tap heavy rings low and place them perfectly, which felt wrong.
	var inacc := inacc_factor() * (1.0 + DEFICIT_INACC * deficit)
	var spread := maxf(frac, deficit * DEFICIT_FLOOR)
	var jitter := int(round(rng.randf_range(-1.0, 1.0) * float(JITTER_MAX) * spread * inacc))
	var drift := rng.randf_range(-1.0, 1.0) * DRIFT_MAX * spread * inacc
	if _collcheck:
		# the overlap audit judges the IDEAL pattern: geometry must be clean
		# before inaccuracy gets a say, so the noise terms are zeroed here
		jitter = 0
		drift = 0.0

	b.state = STATE_FLIGHT
	b.launch_tick = tick
	b.land_tick = tick + air + jitter
	b.arc = ARC_PER_AIR * float(air)
	# a throw's stamina price is the prop's FLAT rate (Louis): balls 1, eggs 2,
	# rings 3, clubs 4, knives 5, torches 6. Focus shaves one point per 20
	# Focus, never below 1 - every throw costs at least one. Lessons stay free.
	if not tut_active:
		var drain := maxf(1.0, float(PROPS[b.kind]["stam"]) - floor(focus() / 20.0))
		stamina = maxf(0.0, stamina - drain)
	# where the throw is headed: crossing patterns swap hands, columns (pattern or
	# toggle) keep each ball its lane, and an over-the-top throw always crosses,
	# landing a touch wide of the usual catch point
	# every weaving pattern crosses hands; only Fountain and Columns keep a ball
	# with its own hand (Reverse Cascade, Waterfall and Tennis are all woven too -
	# their over-the-top throws force cross below anyway, but the LOW half of a
	# Waterfall and Tennis's unmarked balls also weave, so they cross here)
	var cross := pattern in [CASCADE, HALFSHOWER, SHOWER, RCASC, WFALL, TENNIS]
	if over_top:
		cross = true
	# an over-the-top throw never joins the lane bookkeeping (it is the breakout,
	# and letting it claim the middle-ball mark or a lane made it un-over-the-top)
	var lanes := col_lanes and not over_top
	# an odd ball count cannot split evenly into two lanes: rather than just piling
	# the extra ball into one side (the same look as a four-ball columns with one
	# ball removed), one ball renders as a middle lane, so the pattern reads as a
	# genuinely symmetric left / middle / right instead of a lopsided double lane.
	var mid_ball := false
	var was_mid := false   # already the marked middle ball BEFORE this throw (its 2nd+ throw)
	if lanes and num_balls % 2 == 1:
		was_mid = col_mid_ball == b
		if col_mid_ball == null or not balls.has(col_mid_ball):
			col_mid_ball = b   # the first ball thrown once lanes engage claims the middle
		mid_ball = b == col_mid_ball
		if mid_ball:
			lanes = false
	if lanes:
		cross = false
	# the middle ball still never crosses hands: it stays with whichever hand first
	# threw it (same as a lane ball), just rendered at center. Crossing it to the
	# OTHER hand would race it against that hand's own permanent lane ball for the
	# same catch slot, and a hand can only ever catch into an empty stack, so
	# whichever of the two landed second became literally uncatchable.
	if mid_ball:
		cross = false
	b.to_hand = other(h) if cross else h
	# lock the receiving hand's waiting point in RIGHT NOW, for exactly this ball
	# (Louis): Columns/lane/mid-ball throws land INNER, an over-the-top throw lands
	# wherever the receiving hand does NOT throw from (over_top_land_slot), and a
	# plain throw lands OUTER. This is the one and only place hand_catch_rest
	# changes, so the empty hand never has to guess where a future throw goes -
	# it already knows, the instant this one leaves the hand. Resolving the slot ONCE
	# here, and reusing it for b.to_pos below, is what keeps the hand and the ball
	# agreeing on a single landing point even if the pattern changes mid-flight.
	var land_slot := HAND_OUTER
	if over_top:
		land_slot = over_top_land_slot(b.to_hand)
	elif lanes or mid_ball:
		land_slot = HAND_INNER
	hand_catch_rest[b.to_hand] = land_slot
	# always launch from wherever the ball is actually sitting: a lane or normal
	# ball rests pulled in at inner_pos while held, the middle ball rests at
	# stage center (see draw_hand) - EXCEPT on the very throw that first marks it
	# as the middle ball, when it has only ever been held at the normal inner_pos
	# and has no center position yet to launch from. An over-the-top throw is its
	# own kind of throw (Louis): NO inward carry, it lobs straight from the OUTER
	# catch point (hand_target holds the hand out there while it waits), so the
	# high road starts wide and never shares air with the low weave.
	b.over_top = over_top
	var cy := stage_center().y
	if lanes:
		# each column owns its own x (assign_lane), so two balls in one hand's
		# lane never stack on the same vertical line - that was the same-hand
		# overlap Louis flagged. Straight up and down within the column.
		assign_lane(b, h)
		b.from_pos = Vector2(b.lane_x, cy)
		b.to_pos = Vector2(b.lane_x + drift, cy)
	elif mid_ball:
		# the middle ball rests at centre once marked (was_mid), but on the throw
		# that first marks it, it launches from wherever it was actually held
		b.from_pos = stage_center() if was_mid else inner_pos(h)
		b.to_pos = stage_center() + Vector2(drift, 0.0)   # flat pass through the middle
	elif over_top:
		# the over-the-top lob leaves from the OUTER catch corner and rides a tall
		# parabola down onto land_slot (over_top_land_slot: the complement of the
		# receiving hand's own launch slot, so a landing never sits on a launch).
		b.from_pos = outer_pos(h)
		b.to_pos = slot_pos(b.to_hand, land_slot) + Vector2(drift, 0.0)
	else:
		# a plain cascade/fountain throw: inner launch, outer catch. A FOUNTAIN is
		# same-hand, so its two balls (half a cycle apart) trace the same arc and
		# cleared by only 5px; widening the landing outward opens the up-leg and
		# down-leg apart so they never share air.
		b.from_pos = inner_pos(h)
		var fwide := 0.0
		if pattern == FOUNTAIN:
			fwide = 22.0 if b.to_hand == RIGHT else -22.0
		b.to_pos = outer_pos(b.to_hand) + Vector2(drift + fwide, 0.0)
	if this_trick == TR_BTB:
		# BEHIND THE BACK actually goes behind now (Louis: it never read as
		# behind): the arm wraps and the ball RELEASES from behind the opposite
		# hip, a touch below the hand line, so it rises past the body - drawn
		# BEHIND the figure until it clears (the two-pass split in the play
		# draw). From release on it is the same clean parabola as any throw.
		var bc := stage_center()
		b.from_pos = Vector2(lerpf(bc.x, inner_pos(other(h)).x, 0.75), bc.y + 26.0)

	throw_kick[h] = tick
	charging[h] = false
	if not started:
		started = true
		running = true
	elif not running and mode == MODE_TRAIN:
		# training and lessons always resume on a throw. Without this, one full drop
		# latched running=false for good (update_sim only clears it, do_throw only set it
		# on the first-ever throw), so misses stopped being cleaned up and the lesson
		# froze with no move able to recover it.
		running = true
	# a clean, controlled (low) throw earns a little Applause; an under-strength throw
	# is low but sloppy, so the deficit strips most of that reward: a sagging heavy
	# prop should not read to the crowd as tidy control.
	applause = minf(1.0, applause + 0.004 * (1.0 - clampf(frac, 0.0, 1.0)) * (1.0 - 0.8 * deficit))
	# but now that the crowd's patience is a resource (Phase 2), a genuinely BIG throw
	# thrills them: on stage, height feeds the meter a little, so spectacle buys time
	# and a timid low weave slowly bores the room even as it stays tidy.
	if mode == MODE_PERFORM and not tut_active:
		applause = minf(1.0, applause + APPL_THROW_HEIGHT * clampf(frac, 0.0, 1.4) * (1.0 - 0.8 * deficit))
	if mode == MODE_PERFORM and not tut_active and frac >= 1.1:
		play_sfx("gasp", -13.0)   # the crowd inhales at a genuinely risky throw
	play_sfx("throw", -13.0, clampf(1.2 - 0.09 * float(weight - 1) - 0.15 * frac, 0.5, 1.4))   # whup, lower for heavy/high
	if tut_active:
		tut_on_throw(h)   # a guided lesson watches your throws to advance its steps


#endregion

#region UNLOCK REQUIREMENTS & PATTERN/TRICK TABLES
# --- unlock requirements: a skill (trick or pattern) may ask for a level, a
# Strength, an Accuracy, and a stage of the career (the venue Reputation has
# reached). ALL present keys must be met, so the content spreads over the whole
# climb instead of dumping itself on the first evenings (Louis).
func dev_meet_req(d: Dictionary) -> void:
	# dev flags only (--pattern / --trick): floor every progress axis to satisfy
	# this entry's ask, so a screenshot run is never silently refused a skill.
	# Reputation only ever rises here (venue_pick is untouched, so the stage
	# actually shown stays whatever --venue chose).
	level = maxi(level, int(d.get("lvl", 1)))
	strength = maxi(strength, int(d.get("str", 0)))
	accuracy = maxi(accuracy, int(d.get("acc", 0)))
	if int(d.get("ven", 0)) > 0:
		reputation = maxi(reputation, VENUE_REP[int(d["ven"])])


func skill_req_met(d: Dictionary) -> bool:
	if gifted.has(String(d.get("id", ""))):
		return true   # the pity director granted it outright; the wall is forgiven
	if level < int(d.get("lvl", 1)):
		return false
	if strength < int(d.get("str", 0)):
		return false
	if accuracy < int(d.get("acc", 0)):
		return false
	if venue_index() < int(d.get("ven", 0)):
		return false
	return true


func skill_req_text(d: Dictionary) -> String:
	# the requirement, said plainly, for lock messages and the Skills screen
	var parts: Array[String] = []
	if int(d.get("lvl", 1)) > 1:
		parts.append("level %d" % int(d["lvl"]))
	if int(d.get("str", 0)) > 0:
		parts.append("Strength %d" % int(d["str"]))
	if int(d.get("acc", 0)) > 0:
		parts.append("Accuracy %d" % int(d["acc"]))
	if int(d.get("ven", 0)) > 0:
		parts.append("reach the %s" % String(venue_data(int(d["ven"]))["name"]))
	if parts.is_empty():
		return "yours from the start"
	return " + ".join(parts)


func pattern_unlocked(i: int) -> bool:
	return skill_req_met(PATTERNS[i])


func pattern_order() -> Array:
	# pattern indices in UNLOCK order (by asking level): the array itself keeps
	# indices 0..4 frozen for old saves, so display and the P cycle sort here
	var out: Array = []
	for i in PATTERNS.size():
		out.append(i)
	out.sort_custom(func(a, b): return int(PATTERNS[a]["lvl"]) < int(PATTERNS[b]["lvl"]))
	return out


func pattern_mult() -> float:
	return float(PATTERNS[pattern]["mult"])


func object_mult() -> float:
	# harder LOADS pay more, independent of which pattern they are juggled in
	# (ideas.rtf: using more objects should give score a good boost compared to
	# just spamming three balls). Balls and weight compound, so five clubs and
	# three torches land in the same neighbourhood - both genuinely harder than
	# an easy three-ball routine, whatever pattern it is run in.
	var ball_step := float(num_balls - MIN_BALLS)
	var weight_step := float(prop_weight() - 1)
	return (1.0 + OBJ_BALL_BONUS * ball_step) * (1.0 + OBJ_WEIGHT_BONUS * weight_step)


func streak_cap() -> int:
	# the multiplier a load can reach is CAPPED at ten per ball (Louis): 3 balls stop
	# at 30, 4 at 40, up to 7 at 70. An easy three-ball run can hold a streak forever,
	# so without this it out-earns a genuinely hard load; the cap makes climbing to more
	# (and heavier) props - object_mult() above - the only way to a bigger multiplier.
	return num_balls * 10


func streak_mult() -> float:
	# the multiplier IS the streak length, growing one per clean catch up to the load's
	# cap, then holding flat there. The streak itself keeps counting (for the record);
	# only its score multiplier stops climbing.
	return float(mini(streak, streak_cap()))


func rec_table() -> Array[int]:
	# which record board this booking plays on: the stat-assisted one or the Purist
	return best_scores_purist if purist else best_scores


func cycle_pattern() -> void:
	# P steps the pattern in training (a performance is committed to its routine).
	# Restarts the run so the hands are re-dealt for the new choreography.
	pattern_once = -1   # the player's own hand on P ends any Skills-practice override
	var un: Array = []
	for i in pattern_order():
		if pattern_unlocked(i):
			un.append(i)
	if un.size() <= 2:
		# only the parity starters are open, and start_run snaps those to the ball
		# count anyway, so there is nothing real to cycle yet - say what comes next
		set_trick_msg("the next pattern (Columns) asks for %s" % skill_req_text(PATTERNS[COLUMNS]))
		return
	var idx := un.find(pattern_sel)
	pattern_sel = int(un[(idx + 1) % un.size()]) if idx >= 0 else int(un[0])
	set_trick_msg("%s  -  %s" % [String(PATTERNS[pattern_sel]["name"]).to_upper(), String(PATTERNS[pattern_sel]["desc"])])
	play_sfx("ui2", -13.0)
	start_run(num_balls)


func trick_unlocked(i: int) -> bool:
	return skill_req_met(TRICKS[i])


func unlocked_tricks() -> Array:
	# in unlock order (by level), so C cycles the way the player learned them
	var out: Array = []
	for i in TRICKS.size():
		if trick_unlocked(i):
			out.append(i)
	out.sort_custom(func(a, b): return int(TRICKS[a]["lvl"]) < int(TRICKS[b]["lvl"]))
	return out


#endregion

#region TRICKS: SPIN / CYCLE / REWARD
func balls_airborne() -> int:
	var n := 0
	for b in balls:
		if b.state == STATE_FLIGHT:
			n += 1
	return n


func juggling_catch(landing: Ball) -> bool:
	# THE definition of juggling (Louis): at least one prop is in the air at ALL times.
	# Anything less is just throwing one object and catching it again, however quickly
	# it is done - and the game must know the difference, everywhere, not only in the
	# lesson that teaches it.
	#
	# Testing that continuously would be wasted work, because the air can only ever
	# EMPTY at a catch: a throw only adds to it, and a drop is punished on its own terms.
	# So the whole rule reduces to one question asked at the one moment it can be
	# broken - does this catch empty the air? If something else is still up as this
	# lands, the air never emptied, and the pattern is live. If not, the player just
	# threw one thing and caught it, and this catch earns nothing (see on_catch).
	#
	# Two props landing on the same tick do not slip through: the first sees the second
	# still airborne and counts, the second finds the air bare behind it and does not -
	# so "hold one, pump two together" tops out at a streak of one, which is the point.
	for b in balls:
		if b != landing and b.state == STATE_FLIGHT:
			return true
	return false


func spinning() -> bool:
	return tick <= spin_until


func set_trick_msg(m: String) -> void:
	trick_msg = m
	trick_msg_tick = tick


func on_trick() -> void:
	# The TRICK key (Space) is the one-shot powerup. With an arm trick selected it
	# primes exactly the next throw (pressing again waves it off); with Spin selected
	# it performs the spin right now. The selection itself lives on C (cycle_trick).
	# In a TRICK lesson the trick being TAUGHT is always usable, on EVERY step of it,
	# whatever your level - the lesson selects it and skips the unlock gate, so it can
	# never dead-end waiting for a Space press the gate silently refused, and a press
	# on the drill steps still acts on the taught trick, never on some other one.
	# In any OTHER lesson Space is not part of the exercise: say so instead of firing
	# a trick invisibly under a pattern drill.
	if tut_active and tut_id.begins_with("trick_"):
		trick_sel = trick_by_id(tut_id.substr(6))
	elif tut_active:
		if tut_id.begins_with("pattern_"):
			set_trick_msg("this lesson is a PATTERN - it runs on its own. Tricks ride %s on the stage" % k_trick()[0])
		else:
			set_trick_msg("no trick in this lesson - just throws and catches")
		return
	elif unlocked_tricks().is_empty():
		set_trick_msg("the first trick (%s) asks for %s" % [String(TRICKS[0]["name"]), skill_req_text(TRICKS[0])])
		return
	elif trick_sel < 0 or not trick_unlocked(trick_sel):
		trick_sel = int(unlocked_tricks()[0])
	var t: Dictionary = TRICKS[trick_sel]
	match String(t["kind"]):
		"live":
			if balls_airborne() < int(t["min_air"]):
				var na := int(t["min_air"])
				set_trick_msg("Spin needs a ball in the air" if na == 1 else "Spin needs %d in the air" % na)
				return
			if tick < trick_ready:
				return   # still cooling down; ignore the mash
			spin_until = tick + SPIN_TICKS
			spin_scored = false
			trick_ready = tick + TRICK_COOLDOWN
			set_trick_msg("SPIN")
			play_sfx("streak", -7.0)
		"toggle":
			# one press ON, the next press OFF, smoothly mid-pattern (Louis).
			# Only one toggle runs at a time; switching replaces the old one.
			if toggle_on == trick_sel:
				toggle_on = -1
				set_trick_msg("%s OFF" % String(t["name"]).to_upper())
				play_sfx("ui", -16.0)
			else:
				toggle_on = trick_sel
				toggle_scored = false
				set_trick_msg("%s ON" % String(t["name"]).to_upper())
				play_sfx("ui2", -13.0)
		_:
			if trick_primed:
				trick_primed = false
				set_trick_msg("waved off  -  plain throw")
				play_sfx("ui", -16.0)
				return
			trick_primed = true
			set_trick_msg("%s  -  next throw" % String(t["name"]).to_upper())
			play_sfx("ui2", -13.0)
	if tut_active:
		tut_check()   # a trick_on / trick_off lesson step clears the instant Space toggles


func cycle_trick() -> void:
	# C steps the SELECTION through every unlocked trick. Switching never fires
	# anything by itself: the loaded trick just waits for its own Space press.
	# A pending one-shot follows the switch, so prime-then-switch never fires
	# the trick you switched away from.
	var un := unlocked_tricks()
	if un.is_empty():
		set_trick_msg("no trick yet  -  keep leveling up")
		return
	var idx := un.find(trick_sel)
	trick_sel = int(un[(idx + 1) % un.size()]) if idx >= 0 else int(un[0])
	if String(TRICKS[trick_sel]["kind"]) == "live":
		trick_primed = false   # Spin fires on Space directly; nothing stays primed
		set_trick_msg("%s selected  -  Space performs it" % String(TRICKS[trick_sel]["name"]))
	else:
		set_trick_msg("%s selected  -  Space powers one throw" % String(TRICKS[trick_sel]["name"]))
	play_sfx("ui2", -13.0)


func reward_trick(t: int, at: Vector2, height: float = 0.0) -> void:
	# a landed shaped catch pays the trick's bonus. One-shots celebrate loudly.
	# A running toggle pays a smaller bonus on every shaped catch it lands, and
	# counts toward the trick tally only once per activation.
	if t < 0 or t >= TRICKS.size():
		return
	var td: Dictionary = TRICKS[t]
	var bonus := int(td["bonus"])
	if t == TR_HIGH and height > 1.35:
		# a HELD High Toss climbs past the tap's 1.35 toward 1.8, and the climb
		# pays: up to half again the flourish at the full frame-leaving height.
		# Higher risk (wider drift, a beat out of sight) earns a higher reward,
		# the same bargain the Purist bonus makes.
		bonus = int(round(float(bonus) * (1.0 + 0.5 * clampf((height - 1.35) / 0.45, 0.0, 1.0))))
	bonus = int(round(float(bonus) * encore_score_mult()))   # For the Danger zeroes light props
	if bonus <= 0:
		return
	var tog := String(td["kind"]) == "toggle"
	score += bonus
	trick_score += bonus
	applause = minf(1.0, applause + (0.03 if tog else 0.09))
	if tog:
		if not toggle_scored:
			toggle_scored = true
			tricks_landed += 1
			add_xp(3)
		add_xp(1)
		add_popup(at + Vector2(0, -34), String(td["shout"]), Color(1.0, 0.85, 0.45, 0.8))
	else:
		tricks_landed += 1
		add_xp(4)
		add_popup(at + Vector2(0, -34), String(td["shout"]), Color(1.0, 0.85, 0.45))
		play_sfx("streak", -6.0)
	if tut_active:
		tut_tricks += 1   # a trick_use lesson step counts each landed shaped catch
		tut_check()


# -----------------------------------------------------------------------------
# Progression: XP from skilled play, levels grant stat points, stats add comfort
# (never auto-play). Accuracy eases high throws, Endurance raises Stamina,
# Strength adds a little height control. All effects capped (GDD 4.1 guardrails).
# -----------------------------------------------------------------------------

#endregion

#region XP, LEVELING & UNLOCK ANNOUNCEMENTS
func xp_to_next(lv: int) -> int:
	return int(round(60.0 * pow(float(lv), 1.4))) + 40 * lv


func all_stats_capped() -> bool:
	# the whole build is finished: every trainable stat sits at its ceiling
	return accuracy >= ACC_CAP and strength >= STR_CAP and endurance >= END_CAP and speed >= SPEED_CAP


func add_xp(amount: int) -> void:
	if amount <= 0:
		return
	xp += amount
	run_xp += amount
	var leveled := false
	while xp >= xp_to_next(level):
		xp -= xp_to_next(level)
		level += 1
		# points per level ACCELERATE with the level (3 early, one more per twelve
		# levels): with 839 points across the four caps, flat 3s put the finished
		# build at level 280 and ~20M XP - hundreds of hours, a treadmill nobody
		# ends. This curve lands it at ~level 115 and ~2.4M XP: about 30-40 hours
		# of skilled play, all content long since unlocked on the way (Louis asked
		# what the completion arc should be - that is the answer it now has).
		points += POINTS_PER_LEVEL + level / 12
		leveled = true
	if leveled:
		var s := get_viewport_rect().size
		# MASTERY (the late game): with every stat capped, points have nowhere to go,
		# so a level-up pays gold instead - skill keeps earning long after the build
		# is finished. Skill still sets the score; this is comfort, like pay always was.
		if all_stats_capped() and points > 0:
			var mg := points * MASTERY_GOLD
			money += mg
			career["mastery"] = int(career.get("mastery", 0)) + points
			points = 0
			add_popup(Vector2(s.x * 0.5, s.y * 0.34), "LEVEL %d  -  MASTERY  +%d gold" % [level, mg], Color(1.0, 0.9, 0.5))
			play_sfx("money", -8.0)
		else:
			add_popup(Vector2(s.x * 0.5, s.y * 0.34), "LEVEL %d" % level, Color(1.0, 0.9, 0.5))
		announce_unlocks()   # a level that crosses a skill's gate teaches it
		save_progress()


func queue_lesson(id: String) -> bool:
	# an unlock during a live set cannot interrupt it, so its lesson WAITS at the hub.
	# Queued once, taught once, then remembered forever (seen_tuts). A lesson already
	# taught, or already waiting, is never re-queued. Returns whether it queued NOW,
	# which is what announce_unlocks uses as its "newly unlocked" signal.
	if seen_tuts.has(id) or pending_tuts.has(id):
		return false
	pending_tuts.append(id)
	return true


func check_ball_unlock(prev_max: int) -> void:
	# max_balls() grows silently at Strength 12/20/30; catch each crossing and queue the
	# lesson that teaches the new, faster, higher count (a genuine content hole before)
	var now := max_balls()
	if now > prev_max:
		queue_lesson("count_%d" % now)


func lesson_title(id: String) -> String:
	# a human name for a queued lesson, shown on the hub's LEARN row
	if id.begins_with("trick_"):
		var t := trick_by_id(id.substr(6))
		return "%s (new trick)" % (String(TRICKS[t]["name"]) if t >= 0 else id.substr(6))
	if id.begins_with("pattern_"):
		var p := pattern_by_id(id.substr(8))
		return "%s (new pattern)" % (String(PATTERNS[p]["name"]) if p >= 0 else id.substr(8))
	if id.begins_with("count_"):
		return "%s balls" % id.substr(6)
	if id.begins_with("prop_"):
		var k := int(id.substr(5))
		return "%s (new prop)" % String(PROPS[k]["name"]) if k >= 0 and k < PROPS.size() else id
	if id == "balls":
		return "the basics"
	return id


func trick_by_id(tid: String) -> int:
	for i in TRICKS.size():
		if String(TRICKS[i]["id"]) == tid:
			return i
	return -1


func pattern_by_id(pid: String) -> int:
	for i in PATTERNS.size():
		if String(PATTERNS[i]["id"]) == pid:
			return i
	return -1


func announce_unlocks() -> void:
	# a requirement can be crossed on ANY progress axis - a level, a stat spend, a
	# stage reached - so after each of those this rechecks everything and announces
	# whatever is newly open. queue_lesson's own once-ever dedupe is the memory of
	# what was already announced, so nothing double-fires across sessions either.
	# Skills open from the very start (Cascade, Fountain) never announce.
	for i in TRICKS.size():
		if not trick_unlocked(i) or skill_req_text(TRICKS[i]) == "yours from the start":
			continue
		if queue_lesson("trick_%s" % String(TRICKS[i]["id"])):
			# the banner, and the fresh trick becomes the SELECTED one, so the very
			# next Space press does the thing the banner just explained (nothing
			# fires by itself: the one-shot still wants its own press)
			trick_unlock = i
			trick_unlock_tick = tick
			trick_sel = i
			trick_primed = false
			perfs_since_unlock = 0   # the reward drought counter re-arms on any unlock
			play_sfx("streak", -5.0)
	for i in PATTERNS.size():
		if not pattern_unlocked(i) or skill_req_text(PATTERNS[i]) == "yours from the start":
			continue
		if queue_lesson("pattern_%s" % String(PATTERNS[i]["id"])):
			set_trick_msg("NEW PATTERN  -  %s  -  P switches patterns in training" % String(PATTERNS[i]["name"]).to_upper())
			perfs_since_unlock = 0
			play_sfx("streak", -6.0)


func energy_mult() -> float:
	# performing costs more energy, and bigger routines cost more still;
	# training is lighter so you can practice without burning out. Focus (trained
	# Accuracy past 100) discounts every action's stamina cost (stage 1).
	if tut_active:
		return 0.0   # a lesson costs no stamina at all, so a slow drill never tires out
	var base := 0.5
	if mode == MODE_PERFORM:
		base = 1.0 + 0.15 * float(num_balls - MIN_BALLS)
	return base * focus_stam_mult()


#endregion

#region ROUND RESOLUTION & CATCH/CHANCE MATH
func on_round_end() -> void:
	if round_scored:
		return
	round_scored = true
	# a set of a real booking resolves through the booking machinery (bank + advance, or
	# end the night). Everything else - practice, a dev autoplay - just banks its XP.
	if mode == MODE_PERFORM and booking_active and not tut_active:
		resolve_act()
		return
	var clean := 1.0
	if caught + dropped > 0:
		clean = float(caught) / float(caught + dropped)
	# harder routines (more balls, heavier props) are worth more XP
	var diff := 1.0 + 0.25 * float(num_balls - MIN_BALLS) + 0.25 * float(prop_weight() - 1)
	add_xp(int(round((float(best_streak) * 4.0 + float(caught) * 1.5) * clean * diff)))
	career["best_streak"] = maxi(int(career["best_streak"]), best_streak)


func resolve_act() -> void:
	# the act is over - cashed in standing up (the finish key, or every ball caught
	# and held) or brought down by a collapse. ONE resolution for the whole night:
	# pay, reputation, records, XP and the win all read the act's single score.
	booking_active = false
	var complete := goals_hit >= NUM_GOALS
	# the push-your-luck settles here: a COLLAPSE strips the score back to the last
	# goal actually reached (goals already reached are safe, everything past them is
	# what you gambled), and a collapse before the first goal banks nothing at all.
	# A cash-in keeps every point on the board - that is why cashing in is a choice
	# worth making.
	if set_collapsed:
		score = goal_for(run_venue, goals_hit - 1) if goals_hit >= 1 else 0
	elif goals_hit == 0:
		fail_reason = "bow"   # walked off under the first goal: say so plainly
	var purist_mult := PURIST_BONUS if purist else 1.0
	# a completion XP bonus off the whole act's play
	var clean := 1.0
	if caught + dropped > 0:
		clean = float(caught) / float(caught + dropped)
	var diff := 1.0 + 0.25 * float(num_balls - MIN_BALLS) + 0.25 * float(prop_weight() - 1)
	var xp_bonus := int(round((float(best_streak) * 4.0 + float(caught) * 1.5) * clean * diff))
	add_xp(xp_bonus)
	run_xp += xp_bonus
	# reputation swings on the goals: (g/3 * 1.5 - 0.5) gives +1.0 of a swing for a
	# complete act, roughly nothing for one goal, -0.5 for a night with none.
	var frac := float(goals_hit) / float(NUM_GOALS)
	var rep_delta := int(round(float(REP_SWING) * (frac * 1.5 - 0.5) * purist_mult))
	var cur_tier := venue_index_of(reputation)
	if cur_tier + 2 < VENUE_REP.size():
		rep_delta = mini(rep_delta, VENUE_REP[cur_tier + 2] - 1 - reputation)
	reputation = maxi(0, reputation + rep_delta)
	last_rep_delta = rep_delta
	# the reward drought grows by one act, THEN the unlock check runs - so a night
	# whose rep jump opens something still ends with the counter at zero
	perfs_since_unlock += 1
	announce_unlocks()   # a Reputation jump can open the stage a skill was waiting on
	# PAY scales with the score that survived (the score already scales with the
	# venue), lifted by Reputation and a Purist premium, with the busking floor so a
	# broke juggler always leaves with something.
	last_pay = int(round(float(score) * BOOK_PAY_PER_SCORE * pay_mult() * purist_mult))
	if money < BROKE_GOLD and score > 0:
		last_pay = maxi(last_pay, BUSK_FLOOR)
	money += last_pay
	if last_pay > 0:
		play_sfx("coin", -8.0)
	# a complete act (all three goals) raises this venue's standing bar for next time
	if complete and run_venue >= 0 and run_venue < ante.size():
		ante[run_venue] += 1
	# the career ledger remembers the night
	career["perfs"] = int(career["perfs"]) + 1
	career["gold_earned"] = int(career["gold_earned"]) + last_pay
	career["tricks"] = int(career["tricks"]) + tricks_landed
	career["best_score"] = maxi(int(career["best_score"]), score)
	career["best_streak"] = maxi(int(career["best_streak"]), best_streak)
	# the record board keys off the act's score. A Purist act writes to the Purist
	# board and never the assisted one.
	results_record = false
	if run_venue >= 0 and run_venue < rec_table().size() and score > rec_table()[run_venue]:
		rec_table()[run_venue] = score
		results_record = true
	# THE WIN: a record at the World Arena clears the game once, the first time, after the
	# results card is dismissed. The career then plays on freely, records still to chase.
	if run_venue >= TOP_VENUE and results_record and not won:
		won = true
		pending_win = true
	results_open = true
	results_tick = tick
	results_stamped = false
	save_progress()
	if _demo:
		# dev: report the whole-act outcome and quit, so --demo --booking is a
		# one-shot end-to-end check of the resolve path (goals, stripping, pay, rep)
		print("ACT venue=%d prop=%d n=%d goals=%d/%d collapsed=%s score=%d pay=%d rep=%+d record=%s" % [
			run_venue, prop_type, num_balls, goals_hit, NUM_GOALS, str(set_collapsed),
			score, last_pay, last_rep_delta, str(results_record)])
		get_tree().quit()


func stamina_mult() -> float:
	# full effect until Stamina drops under STAM_LOW, then ramps down to STAM_MIN_MULT
	var f := stamina / maxf(1.0, stamina_max)
	if f >= STAM_LOW:
		return 1.0
	return lerpf(STAM_MIN_MULT, 1.0, clampf(f / STAM_LOW, 0.0, 1.0))


func slow_target() -> float:
	# where the slow amount is HEADING, 0..1. All sources stack linearly
	# (ideas.rtf): the Speed stat, Uncle Dan's Pie (all day), an Amazing!
	# frame-perfect catch, and an earned fifty-Perfect thirty-second window. Purist sets
	# strip the bought shares but keep the earned bursts (those are skill).
	var a := 0.0 if purist_run() else float(mini(speed, SPEED_CAP)) / 8.0 / 100.0
	if pie_active and not purist_run():
		a += PIE_SLOW
	if _frames < amazing_until:
		a += BURST_SLOW
	if _frames < chain_until:
		a += BURST_SLOW
	if tut_active:
		a = maxf(a, tut_slow())   # a lesson sets a FLOOR on slowness, never a sum: it
								  # must not stack with a Pie into a frozen world. The
								  # basics open AT the cap (Louis: max slowmo, and max
								  # is the same 50% the whole game answers to)
	# the hard ceiling (Louis): past 50% the stepped sim reads as jitter, and 50%
	# is the intended best case anyway - fully invested Speed plus a Pie plus one
	# earned burst reaches it, so the stack only peaks when everything aligns
	return clampf(a, 0.0, SLOW_TOTAL_CAP)


func tut_slow() -> float:
	# the lesson's own slow-motion floor. A step may pin its own value ("slow" key, e.g.
	# a trick step stays thick while its drill step speeds up). The BASICS lesson reads
	# the earned pace ladder instead (Louis): clean catches step the world faster, drops
	# step it slower, so the pace always matches the player rather than the script.
	# Other lessons keep the gentle scripted ease from thick to near-real.
	var steps := tut_lesson(tut_id)
	if tut_step >= 0 and tut_step < steps.size():
		var s: Dictionary = steps[tut_step]
		if s.has("slow"):
			return clampf(float(s["slow"]), 0.0, 1.0)
	if tut_id == "balls":
		return TUT_PACES[clampi(tut_pace, 0, TUT_PACES.size() - 1)]
	if steps.size() <= 1:
		return TUT_SLOW_START
	var f := float(tut_step) / float(steps.size() - 1)
	return lerpf(TUT_SLOW_START, TUT_SLOW_END, clampf(f, 0.0, 1.0))


func slow_amount() -> float:
	return _slow_cur   # the live value, always easing linearly (see SLOW_RAMP)


func purist_run() -> bool:
	# a PURIST booking strips the stat comforts from the catch maths, so its records are
	# pure skill. The Purist's Night Encore does the same to a single set. Which RECORD
	# board a night writes to still keys off the booking's `purist` flag, not this - so a
	# Purist Encore only makes the third set harder, it does not relabel the whole booking.
	# Training is never purist (practice is practice).
	return (purist and mode == MODE_PERFORM) or encore_on("purist")


func eff_accuracy() -> float:
	if purist_run():
		return clampf(5.0 * stamina_mult(), 0.0, 100.0)   # a fresh juggler's hands
	return clampf(float(accuracy) * stamina_mult(), 0.0, 100.0)


func inacc_factor() -> float:
	# 1.0 of the base inaccuracy at Accuracy 0, ACC_MIN_FACTOR at Accuracy 100.
	# Never reaches zero, so a max-height throw always still needs a real catch.
	var f := lerpf(1.0, ACC_MIN_FACTOR, eff_accuracy() / 100.0)
	if encore_on("draft"):
		f *= 2.0   # The Draft: a wind through the room, every throw drifts twice as wide
	return f


func catch_chance(quality: int, height: float) -> float:
	# probability that an off-Perfect catch (quality 1 = Good, 2 = Late) secures.
	# Rises with Accuracy and falls with the throw's height. Perfect timing is
	# handled separately in on_catch.
	if tut_active:
		return 1.0   # a lesson never punishes a reasonable attempt with an unseen dice
					 # roll. A total MISS still loses the ball (MISTIME/MISS_GRACE reach
					 # drop_ball), so whiffing entirely is still taught.
	var acc_norm := clampf(eff_accuracy() / ACC_FULL, 0.0, 1.0)
	var base := GOOD_BASE if quality == 1 else LATE_BASE
	var p := base + acc_norm * ACC_CATCH_BONUS - clampf(height, 0.0, 1.4) * HEIGHT_CATCH_PENALTY
	if not purist_run():
		p += strength_catch_mod()  # raw muscle steadies a heavy prop in the hand (and only a
								   # too-weak grip on a heavy prop makes the catch itself shaky)
		if has_glasses:
			p += GLASSES_CATCH_BONUS   # bought gear lifts the odds of an off-Perfect catch
	if spinning():
		p -= SPIN_ACC_PENALTY      # a Spin means catching blind, so off-Perfect gets riskier
	return clampf(p, MIN_CATCH_P, 1.0)


func strength_surplus() -> float:
	# how far Strength exceeds the CURRENT prop's requirement, as a fraction of the
	# remaining room up to the stat's REAL cap. The old hardcoded 100 here was the
	# previous ceiling: with the cap at 200 it silently froze every benefit past
	# Strength 100, which (with the last ball gate at 165) made points above ~170
	# worth nothing at all (Louis). Now every point from the requirement to 200
	# pays out the same linear slice, for every prop.
	var req := prop_req()
	if req <= 0 or strength <= req:
		return 0.0
	return clampf((float(strength) - float(req)) / maxf(1.0, float(STR_CAP) - float(req)), 0.0, 1.0)


func strength_catch_mod() -> float:
	# How Strength changes the catch of the CURRENT prop. Light props (balls, eggs) are
	# unaffected. For a heavy prop, being well OVER its Required Strength steadies it and
	# eases the catch; being UNDER it makes even the catch shaky. Scales with the prop's
	# weight, so the top props gain the most from raw muscle, and it is never a height or
	# timing change, only a small nudge to the off-Perfect odds.
	var w := prop_weight() - 1                 # 0 for balls/eggs, up to 4 for torches
	var req := prop_req()
	if w <= 0 or req <= 0:
		return 0.0
	if strength > req:
		return strength_surplus() * float(w) * STRENGTH_CATCH
	var ratio := clampf(float(strength) / float(req) - 1.0, -1.0, 0.0)   # -1 hopeless, 0 just enough
	return ratio * float(w) * STRENGTH_CATCH


func focus() -> float:
	# Accuracy trained beyond 100 becomes Focus. Catch maths still cap at 100
	# (see eff_accuracy), so Focus never makes catching easier, only cheaper and,
	# very late, a touch more forgiving on the Perfect window.
	return maxf(0.0, float(accuracy) - 100.0)


func focus_stam_mult() -> float:
	# Stage 1: Focus 0..100 lowers every action's stamina cost toward a floor.
	return lerpf(1.0, FOCUS_STAM_FLOOR, clampf(focus() / 100.0, 0.0, 1.0))


func perfect_window() -> int:
	# Stage 2: once stage 1 has bottomed out (Focus > 100), each FOCUS_WINDOW_PER
	# of further Focus widens the Perfect band by a tick, capped so timing still
	# rules. Never grows past the Good band, so a tier of Good always remains.
	if tut_active:
		return W_LATE   # in a lesson, ANY in-window press is a Perfect: a beginner
						# should never fail a catch they reasonably attempted. The real
						# windows return the instant the lesson ends.
	var w := W_PERFECT
	if not purist_run():           # no Focus widening on the Purist board
		var extra := focus() - 100.0
		var bonus := 0
		if extra > 0.0:
			bonus = mini(FOCUS_WINDOW_MAX, int(extra / FOCUS_WINDOW_PER))
		w = mini(W_GOOD, W_PERFECT + bonus)
	if encore_on("cold"):
		w = maxi(2, w - 2)         # Cold Hands: the Perfect window is two ticks tighter
	return w


func pay_mult() -> float:
	# Reputation lifts earnings only. Score and catching are untouched (GDD 4.1).
	return 1.0 + float(reputation) / REP_PAY_DIV


func run_clean() -> float:
	if caught + dropped <= 0:
		return 1.0
	return float(caught) / float(caught + dropped)


func run_grade() -> String:
	# a single letter that reads the whole set: cleanliness carries it, the crowd's
	# high point and a long streak lift it. Skill first, so clean play dominates.
	var q := 0.55 * run_clean() + 0.28 * peak_applause + 0.17 * clampf(float(best_streak) / 25.0, 0.0, 1.0)
	if q >= 0.90:
		return "S"
	if q >= 0.78:
		return "A"
	if q >= 0.62:
		return "B"
	if q >= 0.42:
		return "C"
	return "D"


func grade_color(g: String) -> Color:
	match g:
		"S": return Color(1.0, 0.86, 0.42)
		"A": return Color(0.7, 0.95, 0.62)
		"B": return Color(0.62, 0.86, 0.98)
		"C": return Color(0.9, 0.8, 0.6)
		_: return Color(0.95, 0.55, 0.45)


func rep_tier() -> String:
	if reputation >= 6000:
		return "Legend"
	if reputation >= 3000:
		return "Renowned"
	if reputation >= 1500:
		return "Headliner"
	if reputation >= 700:
		return "Known Act"
	if reputation >= 300:
		return "Rising Talent"
	if reputation >= 100:
		return "Street Name"
	return "Unknown"


const VENUE_REP := [0, 100, 300, 700, 1500, 3000, 6000]   # reputation at each venue's
														   # door; 6000 is also Legend,
														   # rep_tier()'s top rank
const TOP_VENUE := 5   # the World Arena: the summit of the climb, where the game is won -
						# UNCHANGED (2026-07-18): The Midnight Show is bonus content
						# reachable only AFTER winning, never a new win condition
const MAX_VENUE := 6   # the last real venue index (The Midnight Show); distinct from
						# TOP_VENUE, which specifically means "the win venue" and must
						# never move


#endregion

#region VENUES & PROPS
func debug_jump_venue(i: int) -> void:
	# debug: leap up the ladder by setting Reputation to a venue's door, then land
	# in the day so the higher stages can be played at once (no story to replay).
	# Clamps to MAX_VENUE, not TOP_VENUE (2026-07-18: those are no longer the same
	# thing - The Midnight Show sits past the win venue), and forces `won` too,
	# since venue 7 is gated on both.
	i = clampi(i, 0, MAX_VENUE)
	if i >= MAX_VENUE:
		won = true
	reputation = maxi(reputation, VENUE_REP[i])
	venue_pick = i
	save_progress()
	enter_day()


func venue_index() -> int:
	return venue_index_of(reputation)


func venue_index_of(rep: int) -> int:
	# the stage you play grows as Reputation climbs, six rungs to the World Arena -
	# The Midnight Show (2026-07-18) is a 7th, bonus rung on TOP of that: it asks
	# BOTH Legend reputation AND `won` (Louis: post-game content, never reachable
	# before the real win, however high reputation alone happens to climb)
	if rep >= 6000 and won:
		return MAX_VENUE
	if rep >= 3000:
		return 5
	if rep >= 1500:
		return 4
	if rep >= 700:
		return 3
	if rep >= 300:
		return 2
	if rep >= 100:
		return 1
	return 0


func cur_venue() -> int:
	# cutscenes and previews can override which venue palette we render
	return view_venue if view_venue >= 0 else play_venue()


func venue_data(i: int) -> Dictionary:
	# per-venue palette: backdrop glow / floor / spotlight strength, and the
	# juggler's costume, so each rung of the career looks distinct while sharing
	# the warm theatrical base (ART_AND_MUSIC.md).
	match i:
		0:
			return {"name": "Backyard", "glow": Color(0.55, 0.62, 0.45), "floor": Color(0.09, 0.10, 0.07), "spot": 0.03,
				"suit": Color(0.42, 0.36, 0.28), "suit_dk": Color(0.30, 0.25, 0.19), "vest": Color(0.66, 0.58, 0.40), "collar": Color(0.85, 0.82, 0.72)}
		1:
			return {"name": "Street Corner", "glow": Color(0.95, 0.66, 0.34), "floor": Color(0.07, 0.07, 0.10), "spot": 0.05,
				"suit": Color(0.34, 0.36, 0.46), "suit_dk": Color(0.22, 0.24, 0.33), "vest": Color(0.70, 0.62, 0.42), "collar": Color(0.88, 0.86, 0.78)}
		2:
			return {"name": "Small Theatre", "glow": Color(0.95, 0.55, 0.28), "floor": Color(0.10, 0.05, 0.06), "spot": 0.05,
				"suit": Color(0.62, 0.16, 0.20), "suit_dk": Color(0.44, 0.10, 0.15), "vest": Color(0.90, 0.73, 0.42), "collar": Color(0.96, 0.90, 0.80)}
		3:
			return {"name": "The Circus", "glow": Color(0.98, 0.48, 0.35), "floor": Color(0.12, 0.06, 0.05), "spot": 0.06,
				"suit": Color(0.80, 0.22, 0.24), "suit_dk": Color(0.55, 0.14, 0.16), "vest": Color(0.96, 0.80, 0.40), "collar": Color(0.98, 0.93, 0.82)}
		4:
			return {"name": "Championship", "glow": Color(0.55, 0.68, 0.95), "floor": Color(0.06, 0.07, 0.11), "spot": 0.07,
				"suit": Color(0.20, 0.28, 0.52), "suit_dk": Color(0.13, 0.19, 0.38), "vest": Color(0.80, 0.84, 0.92), "collar": Color(0.90, 0.93, 0.98)}
		5:
			return {"name": "World Arena", "glow": Color(0.78, 0.52, 0.96), "floor": Color(0.09, 0.06, 0.12), "spot": 0.08,
				"suit": Color(0.42, 0.20, 0.55), "suit_dk": Color(0.28, 0.12, 0.40), "vest": Color(0.96, 0.82, 0.45), "collar": Color(0.98, 0.94, 0.86)}
		_:
			# The Midnight Show (2026-07-18): the bonus, post-game 7th stage - a
			# genuinely DARK house (spot half of even the Backyard's, the dimmest
			# of the original six) so the Glow-in-the-Dark Kit has somewhere it is
			# actually worth wearing. The costume carries the whole theme: a suit
			# that nearly vanishes into the dark, and a vest the same phosphor
			# green as the Kit's own halo, so the performer visibly glows.
			return {"name": "The Midnight Show", "glow": Color(0.35, 0.85, 0.55), "floor": Color(0.02, 0.04, 0.03), "spot": 0.015,
				"suit": Color(0.08, 0.10, 0.09), "suit_dk": Color(0.04, 0.05, 0.045), "vest": Color(0.55, 0.95, 0.65), "collar": Color(0.75, 0.92, 0.8)}


func cur_prop() -> Dictionary:
	return PROPS[prop_type]


func prop_req(kind: int = -1) -> int:
	return int(PROPS[prop_type if kind < 0 else kind]["req"])


func prop_weight(kind: int = -1) -> int:
	return int(PROPS[prop_type if kind < 0 else kind]["weight"])


func prop_deficit() -> float:
	# how far below the prop's Required Strength we are, 0 (fine) to 1 (hopeless)
	var req := prop_req()
	if req <= 0 or strength >= req:
		return 0.0
	return clampf(float(req - strength) / float(req), 0.0, 1.0)


func have(kind: int) -> int:
	# EVERY prop is owned by quantity now, balls included (Louis: they don't appear
	# out of thin air) - a fresh save starts with three, the shop sells the rest
	return prop_count[kind]


func available(kind: int) -> bool:
	# selectable only if you own enough to juggle the minimum count
	return have(kind) >= MIN_BALLS


func prop_color(kind: int) -> Color:
	match kind:
		PROP_EGGS:    return Color(0.96, 0.92, 0.82)
		PROP_RINGS:   return Color(0.45, 0.80, 0.95)
		PROP_CLUBS:   return Color(0.90, 0.35, 0.38)
		PROP_KNIVES:  return Color(0.82, 0.86, 0.92)
		PROP_TORCHES: return Color(1.0, 0.62, 0.24)
		_:            return Color(1.0, 0.82, 0.35)


func prop_scale(kind: int) -> float:
	# heavier and longer props are physically bigger than balls, so they read larger
	match kind:
		PROP_RINGS:   return 1.7
		PROP_CLUBS:   return 1.6
		PROP_KNIVES:  return 1.5
		PROP_TORCHES: return 1.75
		PROP_EGGS:    return 1.1
		_:            return 1.0


const RING_HIT_FACTOR := 0.65  # rings are mostly hole - the true catchable rim reads far
								# smaller than the drawn ring's full diameter (Louis), so
								# their hitbox is always shrunk by this factor, on TOP of
								# the many-object squeeze below. Tune here if it feels off.

func prop_hit_scale(kind: int) -> float:
	# the prop's HITBOX, and ONLY its hitbox (Louis: the clubs, torches and knives keep
	# their true drawn size - it was never their look that needed fixing). From six
	# objects up a big load needs daylight between props to be juggleable at all, and
	# the stance must not widen to buy it, so what tightens is the collision radius:
	# big props shed most of their extra bulk quickly, and the whole set eases in a
	# little further toward eleven. Every DRAWING reads prop_scale, the true size, so a
	# six-club load looks exactly like a five-club load - it just forgives near misses.
	var sc := prop_scale(kind)
	var hit := sc
	if num_balls >= 6:
		# big props flatten toward ball size fast (a six-club load reads as compact
		# stage clubs), and the whole set then eases smaller toward eleven objects
		var flatten := clampf(float(num_balls - 5) / 2.0, 0.0, 1.0)      # full by 7
		var excess := (sc - 1.0) * lerpf(0.55, 0.10, flatten)
		var whole := lerpf(1.0, 0.80, clampf(float(num_balls - 5) / 6.0, 0.0, 1.0))
		hit = (1.0 + excess) * whole
	if kind == PROP_RINGS:
		hit *= RING_HIT_FACTOR
	return hit


#endregion

#region STATS INVESTMENT & SAVE/LOAD
func invest(which: String) -> void:
	if points <= 0:
		return
	var prev_max := max_balls()   # Strength may cross a ball-count gate; catch it below
	# a capped stat refuses the point instead of eating it (Speed always did; the
	# others used to consume the point and change nothing)
	match which:
		"acc":
			if accuracy >= ACC_CAP:
				return
			accuracy += 1   # past 100 becomes Focus
		"str":
			if strength >= STR_CAP:
				return
			strength += 1
		"end":
			if endurance >= END_CAP:
				return
			endurance += 1
			stamina_max = 100.0 + 9.0 * float(endurance)
		"spd":
			if speed >= SPEED_CAP:
				return   # the permanent slow tops out (ideas.rtf): no point wasted
			speed += 1
	points -= 1
	check_ball_unlock(prev_max)   # a new ball count queues its own lesson at the hub
	announce_unlocks()            # a stat spend can cross a skill's Strength/Accuracy ask
	save_progress()


func _sheet_invest(which: String) -> void:
	if debug_mode:
		_adjust(which, 1)   # debug build: free, no point cost
	else:
		invest(which)


func sheet_repeat(dt: float) -> void:
	# debug build only: while the character sheet is open, HOLDING a stat-adjust key keeps
	# stepping the stat instead of one press per point. The first press was already applied
	# by _input, so a freshly held key waits SHEET_REPEAT_DELAY before it starts repeating.
	# Normal (non-debug) play never calls this, so there it stays one point per press.
	var key := 0
	var which := ""
	var delta := 0
	if Input.is_physical_key_pressed(KEY_1):
		key = KEY_1; which = "acc"; delta = 1
	elif Input.is_physical_key_pressed(KEY_2):
		key = KEY_2; which = "str"; delta = 1
	elif Input.is_physical_key_pressed(KEY_3):
		key = KEY_3; which = "end"; delta = 1
	elif Input.is_physical_key_pressed(KEY_4):
		key = KEY_4; which = "spd"; delta = 1
	elif Input.is_physical_key_pressed(KEY_R):
		key = KEY_R; which = "spd"; delta = -1
	elif Input.is_physical_key_pressed(KEY_Q):
		key = KEY_Q; which = "acc"; delta = -1
	elif Input.is_physical_key_pressed(KEY_W):
		key = KEY_W; which = "str"; delta = -1
	elif Input.is_physical_key_pressed(KEY_E):
		key = KEY_E; which = "end"; delta = -1
	if key == 0:
		_repeat_key = 0
		return
	if key != _repeat_key:
		_repeat_key = key       # newly held: hold off until the initial delay elapses
		_repeat_t = -SHEET_REPEAT_DELAY
		return
	_repeat_t += dt
	while _repeat_t >= SHEET_REPEAT_RATE:
		_repeat_t -= SHEET_REPEAT_RATE
		_adjust(which, delta)


func _adjust(which: String, delta: int) -> void:
	var prev_max := max_balls()
	match which:
		"acc":
			accuracy = clampi(accuracy + delta, 1, ACC_CAP)
		"str":
			strength = clampi(strength + delta, 1, STR_CAP)
		"end":
			endurance = clampi(endurance + delta, 0, END_CAP)
			stamina_max = 100.0 + 9.0 * float(endurance)
			stamina = minf(stamina, stamina_max)
		"spd":
			speed = clampi(speed + delta, 0, SPEED_CAP)
	check_ball_unlock(prev_max)
	save_progress()


func save_file() -> String:
	# debug_mode stays first so --demo --debug (used to preview venues) still lands
	# on the debug save. Otherwise, any unattended dev autoplay writes to its own
	# scratch file and must never touch a real career slot.
	if debug_mode:
		return SAVE_PATH_DEBUG
	if _demo or _shot:
		return SAVE_PATH_DEMO
	return slot_path(save_slot)


func _migrate_lesson_id(id: String) -> String:
	# the four routine-reshaping toggles became PATTERNS (one pattern at a time,
	# Louis), so their old trick-lesson ids map to the pattern lessons that
	# replaced them. Every other id passes through untouched.
	match id:
		"trick_cols": return "pattern_columns"
		"trick_wfall": return "pattern_wfall"
		"trick_rcasc": return "pattern_rcasc"
		"trick_tennis": return "pattern_tennis"
	return id


func load_progress() -> void:
	var cf := ConfigFile.new()
	if cf.load(save_file()) == OK:
		accuracy = int(cf.get_value("stats", "accuracy", 5))
		strength = int(cf.get_value("stats", "strength", 6))
		endurance = int(cf.get_value("stats", "endurance", 0))
		speed = int(cf.get_value("stats", "speed", 0))
		pie_count = int(cf.get_value("stats", "pies", 0))
		pie_active = bool(cf.get_value("day", "pie_active", false))
		money = int(cf.get_value("stats", "money", START_GOLD))
		reputation = int(cf.get_value("stats", "reputation", 0))
		var pc: Variant = cf.get_value("stats", "prop_count", [])
		if pc is Array:
			for i in mini((pc as Array).size(), prop_count.size()):
				prop_count[i] = int((pc as Array)[i])
		# balls used to be free and unlimited, so old saves stored 0 of them: every
		# save keeps at least the starting kit of three (balls are stock now)
		prop_count[PROP_BALLS] = maxi(prop_count[PROP_BALLS], 3)
		prop_type = int(cf.get_value("stats", "prop_type", PROP_BALLS))
		has_glasses = bool(cf.get_value("stats", "glasses", false))
		has_glow_kit = bool(cf.get_value("stats", "glow_kit", false))
		level = int(cf.get_value("prog", "level", 1))
		xp = int(cf.get_value("prog", "xp", 0))
		points = int(cf.get_value("prog", "points", 0))
		won = bool(cf.get_value("prog", "won", false))
		var bs: Variant = cf.get_value("prog", "best_scores", [])
		if bs is Array:
			for i in mini((bs as Array).size(), best_scores.size()):
				best_scores[i] = int((bs as Array)[i])
		var bp: Variant = cf.get_value("prog", "best_scores_purist", [])
		if bp is Array:
			for i in mini((bp as Array).size(), best_scores_purist.size()):
				best_scores_purist[i] = int((bp as Array)[i])
		pattern_sel = clampi(int(cf.get_value("prog", "pattern_sel", CASCADE)), 0, PATTERNS.size() - 1)
		var cr: Variant = cf.get_value("prog", "career", {})
		if cr is Dictionary:
			for k in career:
				if (cr as Dictionary).has(k):
					career[k] = int((cr as Dictionary)[k])
		# lessons already taught, and lessons queued but not yet taught, both persist -
		# without this an unlock lesson (Phase 1) re-fired every launch (the seen_tuts bug).
		# Ids run through _migrate_lesson_id: a save from before the pattern fold may
		# still hold the four routine toggles as trick lessons.
		var st: Variant = cf.get_value("prog", "seen_tuts", [])
		if st is Array:
			seen_tuts.clear()
			for v in (st as Array):
				seen_tuts.append(_migrate_lesson_id(String(v)))
		var pt: Variant = cf.get_value("prog", "pending_tuts", [])
		if pt is Array:
			pending_tuts.clear()
			for v in (pt as Array):
				pending_tuts.append(_migrate_lesson_id(String(v)))
		# the standing ante per venue (complete acts there): the raised bar the venue
		# remembers between visits. The rest of the act is per-night and unsaved.
		var an: Variant = cf.get_value("prog", "ante", [])
		if an is Array:
			for i in mini((an as Array).size(), ante.size()):
				ante[i] = int((an as Array)[i])
		# the reward director's memory: gifts stay given, the drought clock survives
		var gf: Variant = cf.get_value("prog", "gifted", [])
		if gf is Array:
			gifted.clear()
			for v in (gf as Array):
				gifted.append(String(v))
		perfs_since_unlock = int(cf.get_value("prog", "perfs_since_unlock", 0))
		aid_pie_day = int(cf.get_value("prog", "aid_pie_day", -1))
		aid_meal_used = bool(cf.get_value("prog", "aid_meal_used", false))
		purist = bool(cf.get_value("day", "purist", false))
		day = int(cf.get_value("day", "day", 1))
		seg_used = int(cf.get_value("day", "seg_used", 0))
		venue_pick = int(cf.get_value("day", "venue_pick", -1))
		meals = int(cf.get_value("day", "meals", 0))
	stamina_max = 100.0 + 9.0 * float(endurance)
	# stamina persists through the day now (sleep restores it). An old save that
	# predates the day loop simply wakes rested.
	stamina = clampf(float(cf.get_value("day", "stamina", stamina_max)), 0.0, stamina_max)
	if venue_pick < 0:
		venue_pick = venue_index()   # older saves default to their grandest stage


func save_progress() -> void:
	var cf := ConfigFile.new()
	cf.set_value("stats", "accuracy", accuracy)
	cf.set_value("stats", "strength", strength)
	cf.set_value("stats", "endurance", endurance)
	cf.set_value("stats", "speed", speed)
	cf.set_value("stats", "pies", pie_count)
	cf.set_value("day", "pie_active", pie_active)
	cf.set_value("stats", "money", money)
	cf.set_value("stats", "reputation", reputation)
	cf.set_value("stats", "prop_count", prop_count)
	cf.set_value("stats", "prop_type", prop_type)
	cf.set_value("stats", "glasses", has_glasses)
	cf.set_value("stats", "glow_kit", has_glow_kit)
	cf.set_value("prog", "level", level)
	cf.set_value("prog", "xp", xp)
	cf.set_value("prog", "points", points)
	cf.set_value("prog", "won", won)
	cf.set_value("prog", "best_scores", best_scores)
	cf.set_value("prog", "best_scores_purist", best_scores_purist)
	cf.set_value("prog", "pattern_sel", pattern_sel)
	cf.set_value("prog", "career", career)
	cf.set_value("prog", "seen_tuts", seen_tuts)       # so a lesson fires once, ever
	cf.set_value("prog", "pending_tuts", pending_tuts)  # a queued lesson survives quitting
	cf.set_value("prog", "ante", ante)                  # each venue's standing raised bar
	cf.set_value("prog", "gifted", gifted)              # pity unlocks stay unlocked
	cf.set_value("prog", "perfs_since_unlock", perfs_since_unlock)
	cf.set_value("prog", "aid_pie_day", aid_pie_day)
	cf.set_value("prog", "aid_meal_used", aid_meal_used)
	cf.set_value("day", "purist", purist)
	cf.set_value("day", "day", day)
	cf.set_value("day", "seg_used", seg_used)
	cf.set_value("day", "venue_pick", venue_pick)
	cf.set_value("day", "meals", meals)
	cf.set_value("day", "stamina", stamina)
	cf.save(save_file())


# -----------------------------------------------------------------------------
# Per-tick simulation and hand animation.
# -----------------------------------------------------------------------------

#endregion

#region SIM TICK: DROPS, COLLAPSE, FLIGHT
func spawn_falling(pos: Vector2, kind: int, col: Color) -> void:
	# a lost prop becomes a cosmetic body that FALLS to the stage floor (eggs
	# break where they land, not at arm height, Louis's note)
	# cosmetic randomness only (global randf, never the sim rng, so the sim's
	# deterministic roll sequence is untouched by how a prop happens to tumble)
	falling.append({"pos": pos, "vel": Vector2(randf_range(-0.8, 0.8), 1.4),
		"kind": kind, "col": col, "ang": randf_range(0.0, TAU),
		"spin": randf_range(-0.12, 0.12), "bounced": false, "rest": -1})


func drop_ball(b: Ball, why: String) -> void:
	if not balls.has(b):
		return
	balls.erase(b)
	dropped += 1
	career["drops"] = int(career["drops"]) + 1
	streak = 0
	perfect_chain = 0
	last_drop_tick = tick
	applause = maxf(0.0, applause - 0.26)
	if tut_active:
		# a drop in the basics hands the player their thick time back (Louis: bad
		# performances move the slowmo back up), and it breaks any in-a-row count a
		# juggle-gated step was building - ten at full speed means ten unbroken
		tut_flow_streak = 0
		if bool(tut_step_data().get("juggle", false)):
			tut_count = 0
		if tut_id == "balls" and tut_pace > 0:
			tut_pace -= 1
			add_popup(Vector2(get_viewport_rect().size.x * 0.5, get_viewport_rect().size.y * 0.30),
				"slower  -  find the rhythm again", Color(0.95, 0.78, 0.5))
	if set_shake:
		shake = 5.0
	freeze = 8   # a short hit-stop so the loss registers before play rolls on
	spawn_parts(flight_pos(b), Color(0.75, 0.5, 0.4), 10, 2.6, "spark")
	spawn_falling(flight_pos(b), b.kind, b.color)
	if b.kind == PROP_EGGS:
		# a dropped egg breaks for good, so it leaves your stock (ideas.rtf). A lesson
		# is practice, so a broken egg there is free (the mess shows when it LANDS).
		if not tut_active:
			prop_count[PROP_EGGS] = maxi(0, prop_count[PROP_EGGS] - 1)
			save_progress()
	play_sfx("drop", -7.0)
	if mode == MODE_PERFORM and not tut_active:
		play_sfx("groan", -10.0)   # the crowd sags with the prop (ART doc stingers)
	_duck = 1.0   # a drop briefly ducks the music, so the silence lands
	add_popup(b.to_pos + Vector2(0, -6), why, Color(1.0, 0.32, 0.3))
	# the collapse now has TWO triggers: an emptied crowd (below) and, new in Phase 2,
	# the drop limit. Both funnel through start_collapse(). Training plays on.
	if mode == MODE_PERFORM and not tut_active:
		if stamina <= 0.0:
			# collapsing because you are SPENT, not because the crowd walked: remember it,
			# so the day steers you to eat or sleep the moment this comes down (Louis)
			exhausted = true
		# ONE reason, in priority order, because only one of these actually ended the set:
		# empty hands beat a full drop sheet (you dropped it BECAUSE you were spent), and
		# both beat a bored room that was still, technically, watching.
		if stamina <= 0.0:
			add_popup(b.to_pos + Vector2(0, -28), "SPENT  -  THAT'S THE NIGHT", Color(1.0, 0.5, 0.35))
			start_collapse("spent")
		elif dropped >= drop_limit():
			add_popup(b.to_pos + Vector2(0, -28), "THAT'S THE NIGHT", Color(1.0, 0.5, 0.35))
			start_collapse("drops")
		elif applause <= 0.0:
			start_collapse("crowd")
	elif mode == MODE_TRAIN and not tut_active and stamina <= 0.0 and running:
		# spent in practice too: end the session so the day can steer you to recovery
		exhausted = true
		running = false


func start_collapse(reason: String) -> void:
	# the act falls apart: the hands give up and whatever is still held slips from them,
	# so the player watches it all come down. The round ends only once everything has
	# landed (see the collapse step in _physics_process). Marks set_collapsed so the act
	# resolves as a hard ending, which is what strips the score to the last goal reached.
	# `reason` is WHY, recorded here because here is the only place that actually knows -
	# it is carried, unedited, to the collapse banner and the results card (Louis).
	if collapsing:
		return
	collapsing = true
	set_collapsed = true
	fail_reason = reason
	for h in [LEFT, RIGHT]:
		for hb in stack(h):
			balls.erase(hb)
			spawn_falling(hpos[h], hb.kind, hb.color)
		stack(h).clear()


func fail_text() -> Array:
	# WHY the night ended, as [headline, the plain sentence and what to do about it].
	# Strictly the one reason that actually fired (fail_reason): a player whose hands
	# gave out is never also told the crowd was bored, because the crowd was not the
	# problem and being handed all three possibilities teaches nothing (Louis).
	match fail_reason:
		"crowd":
			return ["THE PUBLIC WASN'T HAPPY",
				"the room ran out of patience and emptied. Catches and big throws are what keep them in their seats."]
		"spent":
			return ["OUT OF STAMINA",
				"your hands had nothing left and stopped closing. Eat or sleep before the next booking."]
		"drops":
			return ["YOU DROPPED IT ALL",
				"%d drops, and this house allows %d." % [dropped, drop_limit()]]
		"bow":
			return ["YOU BOWED OUT UNDER THE TARGET",
				"you chose the bow before the number fell, so the night ends here. The crowd went home happy."]
	return ["", ""]


func update_sim() -> void:
	# THE CLOCK (Phase 2): the crowd's patience bleeds every tick while performing, at a
	# venue-scaled rate the Encore can bend. Reach zero and the room empties (the collapse
	# that was always built and never reached). Catches and big throws pay patience back,
	# so keeping the crowd is simply keeping the act alive.
	if mode == MODE_PERFORM and not tut_active and running and not collapsing:
		applause = maxf(0.0, applause - APPL_DECAY[clampi(run_venue, 0, APPL_DECAY.size() - 1)] * encore_decay_mult())
		if applause <= 0.0:
			start_collapse("crowd")   # the room emptied: nothing to do with drops or stamina
	var lost: Array[Ball] = []
	for b in balls:
		if b.state == STATE_FLIGHT and tick > b.land_tick + MISS_GRACE:
			lost.append(b)
		elif b.state == STATE_FLIGHT and tick % 2 == 0:
			# the flight trail (ART doc 4): sample the path so a comet tail follows the
			# prop, longer for higher (riskier) throws, so risk is legible at a glance
			b.trail.append(flight_pos(b))
			var maxlen := 5 + int(clampf(b.height, 0.0, 1.4) * 8.0)
			while b.trail.size() > maxlen:
				b.trail.remove_at(0)
	# mid-air contact. With the hard-mode toggle on (or the Close Quarters Encore), two
	# props that visibly clack both become nearly uncatchable (see on_catch); a PERFECT
	# pattern never collides, so this only ever punishes sloppy heights that share air.
	# The dev --collcheck harness rides the same loop to audit the ideal geometry.
	var clacks := set_collide or encore_on("tight")
	if clacks or _collcheck:
		var fly: Array[Ball] = []
		var fpos: Array[Vector2] = []
		for b in balls:
			if b.state == STATE_FLIGHT:
				fly.append(b)
				fpos.append(flight_pos(b))
		for i in fly.size():
			for j in range(i + 1, fly.size()):
				var d := fpos[i].distance_to(fpos[j])
				var rr := 11.0 * (prop_hit_scale(fly[i].kind) + prop_hit_scale(fly[j].kind))
				if _collcheck and d - rr < _coll_min:
					_coll_min = d - rr
					_coll_at = "tick %d  a=(%.0f,%.0f ot=%s h=%.2f p=%.2f)  b=(%.0f,%.0f ot=%s h=%.2f p=%.2f)" % [
						tick, fpos[i].x, fpos[i].y, str(fly[i].over_top), fly[i].height,
						clampf(float(tick - fly[i].launch_tick) / float(maxi(1, fly[i].land_tick - fly[i].launch_tick)), 0.0, 1.0),
						fpos[j].x, fpos[j].y, str(fly[j].over_top), fly[j].height,
						clampf(float(tick - fly[j].launch_tick) / float(maxi(1, fly[j].land_tick - fly[j].launch_tick)), 0.0, 1.0)]
				if clacks and d < rr and not (fly[i].bumped and fly[j].bumped):
					fly[i].bumped = true
					fly[j].bumped = true
					var mid := (fpos[i] + fpos[j]) * 0.5
					spawn_parts(mid, Color(1.0, 0.55, 0.4), 7, 3.0, "spark")
					play_sfx("whiff", -14.0, 1.6)   # a soft airy knock
	for b in lost:
		drop_ball(b, "DROP")
	peak_applause = maxf(peak_applause, applause)
	if balls.is_empty():
		running = false


func update_hands() -> void:
	for h in [LEFT, RIGHT]:
		var cur: Vector2 = hpos[h]
		hpos[h] = cur.lerp(hand_target(h), HAND_SMOOTH)
		var want := 1.0 if not stack(h).is_empty() else 0.0
		hclose[h] = lerpf(hclose[h], want, 0.3)
	if _handlog and tick >= 24:
		# one line per tick: each hand's live x, its target x, the slot it is aiming at,
		# and whether it holds. A hand that alternates target slots every few ticks (its
		# aim x jumping) is the tremor; a steady aim far from the ball's lane is the
		# other hypothesis. dc is the centre-relative offset, so 24/58/104 read directly.
		var c := stage_center().x
		print("t%4d  L x=%6.1f aim=%6.1f dc=%5.1f hold=%d   R x=%6.1f aim=%6.1f dc=%5.1f hold=%d" % [
			tick, hpos[LEFT].x, hand_target(LEFT).x, hand_target(LEFT).x - c, int(not stack(LEFT).is_empty()),
			hpos[RIGHT].x, hand_target(RIGHT).x, hand_target(RIGHT).x - c, int(not stack(RIGHT).is_empty())])


func add_popup(pos: Vector2, text: String, col: Color) -> void:
	# a newcomer that would land on a still-living popup (same neighbourhood: a
	# trick shout, its PERFECT, and a Spin's x2 all fire from one catch) slides up
	# above it, so a busy moment stacks into a readable little column instead of
	# three lines of text printed through each other
	var p := pos + Vector2(0, -40)
	var moved := true
	var guard := 0
	while moved and guard < 8:
		moved = false
		guard += 1
		for q in popups:
			var qpos: Vector2 = q["pos"] + Vector2(0, -float(tick - int(q["born"])) * 0.6)
			if absf(qpos.x - p.x) < 120.0 and absf(qpos.y - p.y) < 26.0:
				p.y = qpos.y - 26.0
				moved = true
	popups.append({"pos": p, "text": text, "col": col, "born": tick})


func age_popups() -> void:
	var keep: Array[Dictionary] = []
	for p in popups:
		if tick - int(p["born"]) <= 46:
			keep.append(p)
	popups = keep


func flight_pos(b: Ball) -> Vector2:
	# Every prop is a projectile: constant horizontal velocity, gravity on the
	# vertical, so the path is ALWAYS a clean parabola (Louis) - nothing ever
	# swerves sideways in the air. Which parabola differs per throw (its launch
	# and landing x, and its height b.arc); a column shares one x, so it rides
	# straight up and down on the very same curve. Flight time is set by the
	# throw's height alone (b.land_tick, from the hold), never by how wide it is,
	# so a wide throw of the same height just travels faster across.
	var span := maxi(1, b.land_tick - b.launch_tick)
	var p := clampf(float(tick - b.launch_tick) / float(span), 0.0, 1.0)
	var pos := b.from_pos.lerp(b.to_pos, p)
	pos.y -= 4.0 * b.arc * p * (1.0 - p)   # the parabola: peak height = b.arc at mid-flight
	return pos


# -----------------------------------------------------------------------------
# Rendering: warm-theatrical, code-only. A stylized performer with procedurally
# posed arms and open/closing hands, so the no-crossing choreography is visible.
# Draw order keeps balls above the figure and the HUD clear of the stage.
# -----------------------------------------------------------------------------

#endregion

#region STAGE BACKDROP DRAWING
func _draw() -> void:
	_draw_screen()
	_draw_state_fade()


func _draw_state_fade() -> void:
	# a short fade-in overlay drawn on top of WHATEVER screen just drew, so no
	# individual screen's draw function needs to know about it (see the passive
	# detector in _physics_process). A dark curtain, not pure black, so it reads
	# as a theatrical fade rather than a hard cut to nothing.
	if _state_fade_t >= STATE_FADE_FRAMES:
		return
	var s := get_viewport_rect().size
	var a := 1.0 - float(_state_fade_t) / float(STATE_FADE_FRAMES)
	draw_rect(Rect2(0, 0, s.x, s.y), Color(0.03, 0.02, 0.03, a))


func _draw_screen() -> void:
	var s := get_viewport_rect().size
	var font := game_font()
	match game_state:
		ST_MENU:
			draw_menu(font, s)
			return
		ST_SLOTS:
			draw_slots(font, s)
			return
		ST_SETTINGS:
			draw_settings(font, s)
			return
		ST_STATS:
			draw_stats(font, s)
			return
		ST_REMAP:
			draw_remap(font, s)
			return
		ST_CAPSULE:
			draw_capsule_art(font, s)
			return
		ST_GAMEOVER:
			draw_gameover(font, s)
			return
		ST_TUTDONE:
			draw_tutdone(font, s)
			return
		ST_ESTABLISH:
			draw_establish(font, s)
			return
		ST_CREDITS:
			draw_credits(font, s)
			return
		ST_DAY:
			draw_day(font, s)
			if sheet_open:
				draw_sheet(font, s)
			if shop_open:
				draw_shop(font, s)
			if skills_open:
				draw_skills(font, s)
			return
	draw_backdrop(s)
	draw_egg_splats()      # yolk on the floor sits behind the performer
	draw_balls_in_flight(true)   # Behind-the-Back balls still BEHIND the body
	draw_juggler(s)
	draw_targets()
	draw_balls_in_flight()
	draw_falling()         # lost props tumbling down to the boards
	draw_egg_shards()      # flying shell pieces read above the stage
	draw_charge_gauges()   # the hold-to-throw height gauge beside a charging hand
	draw_vignette(s, 0.5)  # frame the lit stage so it reads photographed, not flat
	if tut_active:
		draw_tutorial_banner(font, s)   # a lesson shows only the guided banner, no HUD -
		if tut_id.begins_with("trick_"):     # - plus the ONE corner card its text points
			draw_trick_hud(font, s)          # at, so "the bottom-right card" is a real
		elif tut_id.begins_with("pattern_"): # thing on screen, not a promise (Louis)
			draw_routine_hud(font, s)
	else:
		draw_hud(font, s)
	draw_popups(font)
	if results_open and not tut_active:
		draw_results(font, s)   # the end-of-performance card, over the frozen stage
	draw_parts()           # sparks and confetti ride above the stage and the card
	if sheet_open:
		draw_sheet(font, s)
	if shop_open:
		draw_shop(font, s)
	if paused:
		draw_pause(font, s)     # the pause menu sits over everything


func draw_backdrop(s: Vector2) -> void:
	var vi := cur_venue()
	var v := venue_data(vi)
	var glow: Color = v["glow"]
	var floor_c: Color = v["floor"]
	var spot: float = v["spot"]
	# `spot` only scales SOME of what follows (the cone and the light pool's spot*0.9
	# term); the floor lip's 0.10 baseline and the footlights below keep a small fixed
	# glow regardless of venue, so even the Midnight Show's near-zero spot (0.015)
	# reads as a dim, softly-lit dark rather than pitch black - a deliberately gentle
	# floor, not a bug, but worth knowing if a venue is ever asked to go fully dark.

	# a warm vertical gradient behind everything gives the stage depth instead of a
	# flat black void (the biggest single "cheap look" fix on the play screen)
	var sky_top := Color(floor_c.r * 0.7, floor_c.g * 0.7, floor_c.b * 0.9)
	var sky_bot := Color(glow.r * 0.10 + 0.02, glow.g * 0.09 + 0.02, glow.b * 0.10 + 0.03)
	draw_gradient_v(Rect2(0, 0, s.x, s.y), sky_top, sky_bot, 22)

	var fy := s.y * 0.80

	# the venue's own set dressing sits behind the light, then a dark veil pushes it
	# back into the depth, so the escalating ladder is FELT without ever competing
	# with the props (ART pillars 1 and 4)
	draw_venue_dressing(s, vi, fy, glow)
	draw_rect(Rect2(0, 0, s.x, fy), Color(sky_bot.r * 0.4, sky_bot.g * 0.4, sky_bot.b * 0.5, 0.42))

	# spotlight cone from above centre: it narrows and warms a touch as a streak
	# builds, the light literally rewarding focus (ART doc, Section 2)
	var hot := clampf(float(streak) / 15.0, 0.0, 1.0) if game_state == ST_PLAY else 0.0
	var top := Vector2(s.x * 0.5, -40.0)
	var spread := 300.0 - 44.0 * hot
	var cone := PackedVector2Array([
		top,
		Vector2(s.x * 0.5 - spread, s.y * 0.82),
		Vector2(s.x * 0.5 + spread, s.y * 0.82),
	])
	draw_colored_polygon(cone, Color(glow.r, glow.g, glow.b, spot * (1.0 + 0.5 * hot)))

	# a SMOOTH warm light pool on the performer, built from many faint overlapping
	# discs (bright centre fading out), so it reads as a soft spotlight instead of
	# the hard target rings it used to be. A small floor keeps the stage from a void.
	var pc := Vector2(s.x * 0.5, s.y * 0.50)
	var pool := (0.045 + spot * 0.9) * (1.0 + 0.30 * hot)
	for i in 26:
		var f := float(i) / 25.0                       # 0 outer .. 1 inner
		var r := lerpf(410.0 - 40.0 * hot, 34.0, f)
		var a := pool * (0.06 + 0.94 * f) * 0.16
		draw_circle(pc, r, Color(glow.r, glow.g, glow.b, a))

	# stage floor, with a soft warm lip of light where it meets the light pool
	draw_rect(Rect2(0, fy, s.x, s.y - fy), floor_c)
	draw_gradient_v(Rect2(0, fy, s.x, 34.0), Color(glow.r, glow.g, glow.b, 0.10 + spot), Color(glow.r, glow.g, glow.b, 0.0), 8)
	draw_line(Vector2(0, fy), Vector2(s.x, fy), Color(glow.r, glow.g, glow.b, 0.55), 3.0)

	# footlights along the stage lip once the career reaches ticketed rooms
	if vi >= 2:
		for i in 12:
			var lx := s.x * (float(i) + 0.5) / 12.0
			var fl := 0.6 + 0.4 * sin(atick() * 0.05 + float(i) * 1.7)
			draw_circle(Vector2(lx, fy + 3.0), 10.0, Color(glow.r, glow.g, glow.b, 0.05 * fl))
			draw_circle(Vector2(lx, fy + 3.0), 3.0, Color(1.0, 0.85, 0.55, 0.4 * fl))

	draw_crowd(s, vi, fy, glow)

	# a drop briefly cools the whole room, the visual half of the music duck
	if game_state == ST_PLAY and tick - last_drop_tick < 26 and tick - last_drop_tick >= 0:
		var da := 0.12 * (1.0 - float(tick - last_drop_tick) / 26.0)
		draw_rect(Rect2(0, 0, s.x, s.y), Color(0.35, 0.45, 0.65, da))


func draw_crowd(s: Vector2, vi: int, fy: float, glow: Color) -> void:
	# the crowd is a suggestion that LIVES: heads with shoulders that bob with the
	# applause, brightening as they warm, an extra row at grander venues, and the
	# occasional pair of hands thrown up when the room is truly won over
	var performing := mode == MODE_PERFORM and game_state == ST_PLAY
	var lit := 0.07
	if performing:
		lit = 0.08 + 0.14 * applause
	var bob_amp := (0.4 + 2.2 * applause) if performing else 0.6
	var rows := 2 if vi >= 2 else 1
	for r in rows:
		var heads := 10 + vi * 7 - r * 3
		var base_y := fy + 14.0 + float(r) * 21.0
		var row_lit := lit * (1.0 - 0.35 * float(r))
		for i in heads:
			var hx := s.x * (float(i) + 0.5) / float(heads) + float(r) * 7.0
			var bob := sin(atick() * 0.045 + float(i) * 1.31 + float(r) * 2.2) * bob_amp
			var hy := base_y + fmod(float(i) * 1.7, 5.0) + bob
			var hr := 6.0 + fmod(float(i) * 2.3, 3.0) + float(r)
			var c := Color(glow.r, glow.g, glow.b, row_lit)
			draw_circle(Vector2(hx, hy), hr, c)                                   # head
			fill_ellipse(Vector2(hx, hy + hr + 5.0), hr * 1.9, hr * 0.9,
				Color(glow.r, glow.g, glow.b, row_lit * 0.7))                     # shoulders, softer
			if performing and applause > 0.82 and (i + r * 3) % 4 == 0:
				var up := absf(sin(atick() * 0.09 + float(i)))                     # hands up!
				draw_circle(Vector2(hx - hr, hy - hr - 4.0 * up), 2.2, Color(glow.r, glow.g, glow.b, row_lit * 1.6))
				draw_circle(Vector2(hx + hr, hy - hr - 5.0 * up), 2.2, Color(glow.r, glow.g, glow.b, row_lit * 1.6))


func draw_venue_dressing(s: Vector2, vi: int, fy: float, glow: Color) -> void:
	# what the stage LOOKS OUT ON, per rung of the ladder. Dim, at the edges, and
	# behind a veil, so the centre stays clear for juggling.
	match vi:
		0:   # backyard: dusk stars, the old tree, a fence, the house with a lit window
			draw_stars(s, 20, 0.42)
			draw_tree(Vector2(s.x * 0.09, fy + 2.0), 1.0)
			draw_fence(s, fy - 2.0, s.x * 0.60, s.x * 0.97)
			draw_house(Vector2(s.x * 0.88, fy + 2.0), 132.0, 108.0)
		1:   # street corner: the cold city behind one warm lamp. The skyline gets its
			# own heavy night veil: lit windows read as distant, never as clutter or a
			# fight with the text that floats over them (Louis).
			draw_moon(Vector2(s.x * 0.87, s.y * 0.13), 20.0)
			draw_stars(s, 26, 0.38)
			draw_city_row(s, fy)
			draw_rect(Rect2(0, 0, s.x, fy), Color(0.03, 0.04, 0.09, 0.85))
			draw_streetlamp(Vector2(s.x * 0.07, fy), fy)
		2:   # small theatre: velvet wings and a valance frame the stage
			draw_theatre_wings(s, fy)
		3:   # circus: the big-top canopy overhead and a string of lanterns
			draw_circus_canopy(s)
			draw_lantern_string(Vector2(-10.0, s.y * 0.20), Vector2(s.x + 10.0, s.y * 0.24))
		4:   # championship: cool banners, a scoreboard glow high in the dark
			for bx in [s.x * 0.06, s.x * 0.16, s.x * 0.84, s.x * 0.94]:
				draw_banner(Vector2(bx, s.y * 0.06), Color(0.3, 0.5, 0.9))
			draw_rect(Rect2(s.x * 0.36, s.y * 0.04, s.x * 0.28, 8.0), Color(0.6, 0.8, 1.0, 0.10))
			draw_stars(s, 14, 0.3)
		5:   # world arena: a vast bowl of warm crowd-lights and roaming beams
			for i in 110:
				var seed := float(i) * 17.7
				var x := s.x * 0.5 + (fposmod(sin(seed) * 99.0, 1.0) - 0.5) * s.x
				var y := fy - 30.0 - fposmod(cos(seed) * 71.0, 1.0) * s.y * 0.34
				if absf(x - s.x * 0.5) < s.x * 0.17 and y > s.y * 0.3:
					continue   # keep the juggling window clear
				var a := 0.25 + 0.35 * sin(atick() * 0.05 + seed)
				draw_circle(Vector2(x, y), 1.6, Color(1.0, 0.82, 0.52, clampf(a, 0.08, 0.6)))
			for k in 2:
				var ang := sin(atick() * 0.008 + float(k) * 2.6) * 0.55
				var src := Vector2(s.x * (0.22 + 0.56 * float(k)), -20.0)
				var dir := Vector2(sin(ang) * 0.6, 1.0).normalized()
				var perp := Vector2(-dir.y, dir.x) * 30.0
				draw_colored_polygon(PackedVector2Array([src, src + dir * 900.0 + perp, src + dir * 900.0 - perp]),
					Color(glow.r, glow.g, glow.b, 0.05))
		_:   # The Midnight Show (2026-07-18) and anything past it: the SAME procedural
			# placement as the World Arena above (same seed formula, so the two still
			# feel like kin), but a scattered handful of lights and no roaming search
			# beams - venue_data's spot (0.015, half the Backyard's) and near-black suit
			# already ask for a genuinely dark house, and reusing the World Arena's full
			# 110-light bowl wholesale here (the old catch-all, before this arm existed)
			# undercut that: a bonus venue built to make the Glow-in-the-Dark Kit matter
			# was reading exactly as bright as the venue it is the reward for beating.
			for i in 18:
				var seed := float(i) * 17.7
				var x := s.x * 0.5 + (fposmod(sin(seed) * 99.0, 1.0) - 0.5) * s.x
				var y := fy - 30.0 - fposmod(cos(seed) * 71.0, 1.0) * s.y * 0.34
				if absf(x - s.x * 0.5) < s.x * 0.17 and y > s.y * 0.3:
					continue   # keep the juggling window clear
				var a := 0.10 + 0.16 * sin(atick() * 0.05 + seed)
				draw_circle(Vector2(x, y), 1.4, Color(1.0, 0.82, 0.52, clampf(a, 0.02, 0.24)))


func draw_theatre_wings(s: Vector2, fy: float) -> void:
	# red velvet wings at both edges and a swagged valance across the top
	var ww := s.x * 0.085
	for side in [0.0, 1.0]:
		var x0 := 0.0 if side == 0.0 else s.x - ww
		draw_gradient_h(Rect2(x0, 0, ww, fy), Color(0.30, 0.05, 0.08) if side == 0.0 else Color(0.13, 0.02, 0.04),
			Color(0.13, 0.02, 0.04) if side == 0.0 else Color(0.30, 0.05, 0.08), 8)
		for k in 4:
			var fx := x0 + ww * (float(k) + 0.5) / 4.0
			draw_rect(Rect2(fx - 2.0, 0, 4.0, fy), Color(0.09, 0.015, 0.03, 0.8))
	var vh := s.y * 0.075
	draw_rect(Rect2(0, 0, s.x, vh), Color(0.30, 0.05, 0.08))
	for i in 9:
		var cx := s.x * (float(i) + 0.5) / 9.0
		draw_arc(Vector2(cx, vh * 0.2), s.x / 18.0, 0.35, PI - 0.35, 18, Color(0.14, 0.02, 0.04), vh * 0.5, true)
	draw_line(Vector2(0, vh + 2.0), Vector2(s.x, vh + 2.0), Color(0.85, 0.65, 0.3, 0.5), 2.0)


func draw_circus_canopy(s: Vector2) -> void:
	# striped tent cloth fanning down from the peak of the frame
	var top := Vector2(s.x * 0.5, -s.y * 0.24)
	var n := 12
	var hemy := s.y * 0.15
	for i in n:
		var a0 := lerpf(-s.x * 0.62, s.x * 0.62, float(i) / float(n))
		var a1 := lerpf(-s.x * 0.62, s.x * 0.62, float(i + 1) / float(n))
		var col := Color(0.42, 0.11, 0.12) if i % 2 == 0 else Color(0.45, 0.42, 0.38)
		draw_colored_polygon(PackedVector2Array([top,
			Vector2(s.x * 0.5 + a0, hemy + absf(a0) * 0.06),
			Vector2(s.x * 0.5 + a1, hemy + absf(a1) * 0.06)]), col)
	for i in n + 1:
		var hx := s.x * 0.5 + lerpf(-s.x * 0.62, s.x * 0.62, float(i) / float(n))
		draw_circle(Vector2(hx, hemy + absf(hx - s.x * 0.5) * 0.06), 3.0, Color(0.85, 0.7, 0.4, 0.5))


#endregion

#region JUGGLER FIGURE DRAWING
func draw_juggler(s: Vector2) -> void:
	var cx := s.x * 0.5
	var v := venue_data(cur_venue())
	var skin := Color(0.87, 0.64, 0.45)
	var hair := Color(0.28, 0.16, 0.11)
	var suit: Color = v["suit"]         # costume changes with the venue
	var suit_dk: Color = v["suit_dk"]
	var vest: Color = v["vest"]
	var collar: Color = v["collar"]
	var button := Color(0.34, 0.20, 0.11)

	# the eight-head canon, so the in-play juggler reads as a real adult person:
	# head one eighth of the height, the crotch
	# at the vertical midpoint, a drawn-in waist. H is the head unit off the floor line.
	var floor_y := s.y * 0.80
	var H := s.y * 0.056

	# body language: the feet stay planted but the trunk BREATHES, and a fresh catch
	# is absorbed with a soft knee-dip of the whole upper body, so the figure reads
	# as a performer riding the rhythm instead of a stand for two arms
	var dip := 1.2 + sin(float(tick) * 0.03) * 1.4
	for hh in [LEFT, RIGHT]:
		var cfd := tick - int(catch_flash[hh])
		if cfd >= 0 and cfd < 12:
			dip = maxf(dip, 5.0 * (1.0 - float(cfd) / 12.0))

	var hip_y := floor_y - 4.0 * H + dip * 0.25
	var knee_y := floor_y - 2.0 * H
	var waist_y := floor_y - 5.0 * H + dip * 0.55
	var chest_y := floor_y - 6.0 * H + dip * 0.8
	var shoulder_y := floor_y - 6.72 * H + dip
	var head := Vector2(cx, floor_y - 7.5 * H + dip)
	var head_r := 0.52 * H

	# a soft ground shadow so the figure stands ON the stage instead of floating (drawn
	# BEFORE the spin transform, so it stays put on the ground while the body turns)
	draw_shadow(Vector2(cx, floor_y + 2.0), 96.0)

	# a live Spin turns the WHOLE figure about its vertical axis. A 2D pirouette is faked
	# by scaling the body width by cos(turn angle) about the centreline: full width facing
	# front, a thin sliver at the profile, mirrored width facing away. facing_back then
	# swaps the face for the back of the head. In sequence this reads as a real turn.
	var facing_back := false
	var spin_on := spinning()
	var sx := 1.0                                 # body width scale: 1 front, ~0 profile, -1 back
	if spin_on:
		var sp := 1.0 - clampf(float(spin_until - tick) / float(SPIN_TICKS), 0.0, 1.0)
		var ang := sp * TAU                       # exactly one full turn across the spin
		sx = cos(ang)
		facing_back = sx < 0.0
		if absf(sx) < 0.14:                        # never collapse fully to a line at the profile
			sx = 0.14 if sx >= 0.0 else -0.14
		draw_set_transform(Vector2(cx * (1.0 - sx), 0.0), 0.0, Vector2(sx, 1.0))

	# legs: a narrow pelvis, thighs tapering to the knee, calves to the ankle, shoes
	var shoe := Color(0.20, 0.12, 0.09)
	draw_colored_polygon(PackedVector2Array([   # pelvis
		Vector2(cx - 0.62 * H, hip_y - 0.3 * H), Vector2(cx + 0.62 * H, hip_y - 0.3 * H),
		Vector2(cx + 0.56 * H, hip_y + 0.12 * H), Vector2(cx - 0.56 * H, hip_y + 0.12 * H)]), suit_dk)
	draw_capsule(Vector2(cx - 0.4 * H, hip_y), Vector2(cx - 0.34 * H, knee_y), 0.46 * H, 0.3 * H, suit_dk)
	draw_capsule(Vector2(cx - 0.34 * H, knee_y), Vector2(cx - 0.32 * H, floor_y - 0.16 * H), 0.3 * H, 0.2 * H, suit_dk)
	draw_capsule(Vector2(cx + 0.4 * H, hip_y), Vector2(cx + 0.34 * H, knee_y), 0.46 * H, 0.3 * H, suit_dk)
	draw_capsule(Vector2(cx + 0.34 * H, knee_y), Vector2(cx + 0.32 * H, floor_y - 0.16 * H), 0.3 * H, 0.2 * H, suit_dk)
	fill_ellipse(Vector2(cx - 0.34 * H, floor_y - 0.1 * H), 0.52 * H, 0.2 * H, shoe)
	fill_ellipse(Vector2(cx + 0.34 * H, floor_y - 0.1 * H), 0.52 * H, 0.2 * H, shoe)

	# neck: a short skin column from just under the jaw down past the collar line, so a
	# real (short) neck shows between the head and the coat instead of the head sitting
	# straight on the shoulders
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - 0.18 * H, head.y + head_r - 0.05 * H), Vector2(cx + 0.18 * H, head.y + head_r - 0.05 * H),
		Vector2(cx + 0.23 * H, shoulder_y + 0.14 * H), Vector2(cx - 0.23 * H, shoulder_y + 0.14 * H)]), skin)

	# jacket: one tapered silhouette (sloped shoulders, a drawn-in waist, a slight hip
	# flare). Its neckline sits at the shoulders (not up near the chin) so the neck shows.
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - 0.92 * H, shoulder_y + 0.1 * H), Vector2(cx - 0.30 * H, shoulder_y - 0.04 * H),
		Vector2(cx + 0.30 * H, shoulder_y - 0.04 * H), Vector2(cx + 0.92 * H, shoulder_y + 0.1 * H),
		Vector2(cx + 0.8 * H, chest_y), Vector2(cx + 0.5 * H, waist_y), Vector2(cx + 0.66 * H, hip_y + 0.15 * H),
		Vector2(cx - 0.66 * H, hip_y + 0.15 * H), Vector2(cx - 0.5 * H, waist_y), Vector2(cx - 0.8 * H, chest_y)]), suit)
	# (the round shoulder caps are gone: they read as epaulettes poking above the
	# jacket line. The polygon's own sloped corner is the shoulder now.)
	draw_circle(Vector2(cx - 0.34 * H, chest_y), 0.5 * H, Color(1.0, 0.95, 0.85, 0.05))   # soft chest sheen

	# front-of-body detailing (collar V and the buttoned waistcoat) only shows while the
	# figure faces the crowd; mid-spin, facing away, the plain back of the coat is seen
	if not facing_back:
		draw_colored_polygon(PackedVector2Array([
			Vector2(cx - 0.28 * H, shoulder_y - 0.02 * H), Vector2(cx, chest_y + 0.22 * H), Vector2(cx - 0.05 * H, shoulder_y - 0.02 * H)]), collar)
		draw_colored_polygon(PackedVector2Array([
			Vector2(cx + 0.28 * H, shoulder_y - 0.02 * H), Vector2(cx, chest_y + 0.22 * H), Vector2(cx + 0.05 * H, shoulder_y - 0.02 * H)]), collar)
		var vest_top := shoulder_y + 0.52 * H
		draw_colored_polygon(PackedVector2Array([
			Vector2(cx - 0.3 * H, vest_top), Vector2(cx + 0.3 * H, vest_top),
			Vector2(cx + 0.28 * H, waist_y), Vector2(cx + 0.36 * H, hip_y - 0.1 * H),
			Vector2(cx - 0.36 * H, hip_y - 0.1 * H), Vector2(cx - 0.28 * H, waist_y)]), vest)
		for bi in 3:
			draw_circle(Vector2(cx, vest_top + 0.3 * H + float(bi) * 0.42 * H), 0.06 * H, button)
	else:
		# a plain collar band across the back of the neck
		draw_colored_polygon(PackedVector2Array([
			Vector2(cx - 0.28 * H, shoulder_y - 0.02 * H), Vector2(cx + 0.28 * H, shoulder_y - 0.02 * H),
			Vector2(cx + 0.24 * H, shoulder_y + 0.1 * H), Vector2(cx - 0.24 * H, shoulder_y + 0.1 * H)]), collar)

	# head: a full head of hair framing the crown and temples. Facing the crowd, the skin
	# face sits over it; facing away mid-spin, the back of the head is all hair with a
	# little skin at the nape, which is what sells the turn. The head keeps its full ROUND
	# size all through a turn (a head reads round from every angle), so it is drawn OUTSIDE
	# the body's width-scale, otherwise it would squash to a thin oval at the profile.
	if spin_on:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(head + Vector2(0, -head_r * 0.32), head_r * 1.12, hair)   # hair mass, up and a touch larger
	if facing_back:
		draw_circle(head, head_r, hair)                                   # back of the head, all hair
		draw_circle(head + Vector2(0, head_r * 0.62), head_r * 0.42, skin)   # a sliver of nape
	else:
		draw_circle(head, head_r, skin)                                   # face over the hair
		draw_circle(head + Vector2(-head_r * 0.26, -head_r * 0.08), head_r * 0.52, Color(1.0, 0.86, 0.6, 0.10))   # cheek highlight
		draw_face(head, head_r)
	if spin_on:                                                            # back to the body width-scale for the arms
		draw_set_transform(Vector2(cx * (1.0 - sx), 0.0), 0.0, Vector2(sx, 1.0))

	# arms follow the hands via a 2-bone solve, so the choreography animates
	# (their shoulder roots ride the same body dip as the trunk)
	draw_arm(shoulder_pos(LEFT) + Vector2(0, dip), hpos[LEFT], LEFT, skin, suit)
	draw_arm(shoulder_pos(RIGHT) + Vector2(0, dip), hpos[RIGHT], RIGHT, skin, suit)

	# hands (and any held balls) on top of the arms
	draw_hand(LEFT)
	draw_hand(RIGHT)

	# done with the (possibly spinning) figure: return to screen space, then lay the
	# sweeping motion streaks over the top so the turn reads as fast
	if spin_on:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_spin_streaks(Vector2(cx, (shoulder_y + hip_y) * 0.5))


func draw_spin_streaks(center: Vector2) -> void:
	var prog := 1.0 - clampf(float(spin_until - tick) / float(SPIN_TICKS), 0.0, 1.0)   # 0 at start, 1 at end
	# curved motion streaks sweeping around the body, flattened to read as a turn
	var base_a := prog * TAU * 2.0
	for k in 3:
		var a0 := base_a + float(k) * (TAU / 3.0)
		var pts := PackedVector2Array()
		for j in 9:
			var a := a0 + float(j) * 0.10
			var rr := 66.0 - float(k) * 7.0
			pts.append(center + Vector2(cos(a) * rr, sin(a) * rr * 0.55))
		draw_polyline(pts, Color(1.0, 0.85, 0.5, 0.34 - 0.07 * float(k)), 3.0)


func fill_ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * float(i) / 20.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)


func draw_face(head: Vector2, r: float = 21.0) -> void:
	# features scale to the head radius r, so the face stays proportioned after the
	# figure moved to the eight-head canon (a smaller head than the old drawing)
	var eye := Color(0.16, 0.10, 0.08)
	var ex := r * 0.34
	var ey := -r * 0.05
	draw_circle(head + Vector2(-ex, ey), r * 0.14, eye)
	draw_circle(head + Vector2(ex, ey), r * 0.14, eye)
	draw_circle(head + Vector2(-ex + r * 0.05, ey - r * 0.05), r * 0.05, Color(1, 1, 1, 0.7))
	draw_circle(head + Vector2(ex + r * 0.05, ey - r * 0.05), r * 0.05, Color(1, 1, 1, 0.7))
	# expression: a smile on a streak, a wince just after a drop, else calm
	var mood := 0
	if tick - last_drop_tick < 45:
		mood = -1
	elif streak >= 3:
		mood = 1
	var my := head.y + r * 0.42
	var mw := r * 0.3
	var mouth := PackedVector2Array([Vector2(head.x - mw, my), Vector2(head.x + mw, my)])
	if mood == 1:
		mouth = PackedVector2Array([Vector2(head.x - mw, my - r * 0.09), Vector2(head.x, my + r * 0.16), Vector2(head.x + mw, my - r * 0.09)])
	elif mood == -1:
		mouth = PackedVector2Array([Vector2(head.x - mw, my + r * 0.12), Vector2(head.x, my - r * 0.09), Vector2(head.x + mw, my + r * 0.12)])
	draw_polyline(mouth, Color(0.45, 0.20, 0.16), maxf(1.8, r * 0.11))


func draw_capsule(a: Vector2, b: Vector2, wa: float, wb: float, col: Color) -> void:
	# a tapered limb: a quad from half-width wa at a to wb at b, with rounded caps.
	# This reads as a real arm instead of a flat stick line.
	var d := b - a
	var L := d.length()
	var ra := wa * 0.5
	var rb := wb * 0.5
	if L < 0.001:
		draw_circle(a, maxf(ra, rb), col)
		return
	var n := Vector2(-d.y, d.x) / L
	draw_colored_polygon(PackedVector2Array([a + n * ra, b + n * rb, b - n * rb, a - n * ra]), col)
	draw_circle(a, ra, col)
	draw_circle(b, rb, col)


func draw_arm(shoulder: Vector2, hand: Vector2, h: int, skin: Color, sleeve: Color) -> void:
	var bend := 1.0 if h == LEFT else -1.0            # elbows bow outward
	# bones scale to the reach (a touch over half each), so the elbow keeps the SAME
	# gentle bend whether the hand is out catching or tucked in holding a ball. Fixed
	# bones over-folded the close pose into a chicken wing.
	var reach := (hand - shoulder).length()
	var bone := maxf(46.0, reach * 0.56)
	var elbow := solve_elbow(shoulder, hand, bone, bone, bend)
	var wrist := hand + (elbow - hand).normalized() * 7.0   # forearm stops just short of the palm
	draw_capsule(shoulder, elbow, 19.0, 14.0, sleeve)  # upper arm (sleeved), tapering to the elbow
	draw_capsule(elbow, wrist, 13.0, 10.0, skin)       # forearm (skin), tapering to the wrist
	draw_circle(elbow, 7.0, sleeve)                    # elbow joint


# two-bone IK: places the elbow so it sits exactly l1 from shoulder a and l2 from
# hand b, by treating a/b/elbow as a triangle and solving it with the law of
# cosines (x = how far along a->b the elbow's foot falls, hgt = its perpendicular
# height off that line). `bend` (+1/-1) picks which side of the a->b line the
# elbow bows to, since the triangle alone has two mirror-image solutions.
func solve_elbow(a: Vector2, b: Vector2, l1: float, l2: float, bend: float) -> Vector2:
	var ab := b - a
	var dist := clampf(ab.length(), 0.001, l1 + l2 - 0.001)
	var dir := ab / ab.length() if ab.length() > 0.001 else Vector2.DOWN
	var x := (dist * dist + l1 * l1 - l2 * l2) / (2.0 * dist)
	var hgt := sqrt(maxf(l1 * l1 - x * x, 0.0))
	var perp := Vector2(-dir.y, dir.x) * bend
	return a + dir * x + perp * hgt


func draw_hand(h: int) -> void:
	var pos: Vector2 = hpos[h]
	var close: float = hclose[h]
	var inward := 1.0 if h == LEFT else -1.0          # +x points toward centre for L

	# catch glow
	var g := 0.0
	var cf := tick - int(catch_flash[h])
	if cf >= 0 and cf < 14:
		g = 1.0 - float(cf) / 14.0
	if g > 0.0:
		draw_circle(pos, 20.0 + g * 12.0, Color(1.0, 0.82, 0.45, 0.35 * g))

	# a clean rounded mitt with NO fingers (Louis: they looked bad and are not
	# needed): a palm disc with a soft cup that stretches up a little to receive
	# when open and settles round when closed
	var sk := Color(0.87, 0.63, 0.43)
	var openf := 1.0 - close
	var stretch := lerpf(0.0, 6.0, openf)
	fill_ellipse(pos + Vector2(inward * openf * 1.5, -stretch * 0.5), 11.5, 11.5 + stretch, sk)
	draw_circle(pos + Vector2(0, -2), 8.0, Color(1.0, 0.82, 0.55, 0.12))

	# held ball(s) rest in the palm - except the Columns middle ball, which rests
	# at stage center even while held, so it never hops between its held spot and
	# where it actually lands/launches (see the from_pos comment in do_throw)
	var st := stack(h)
	for i in st.size():
		var bp := stage_center() if st[i] == col_mid_ball else pos
		draw_prop(st[i], bp + Vector2(0, -3 - float(i) * 6.0))


func draw_targets() -> void:
	# a landing ring brightens as a catch nears, and its COLOUR teaches the timing,
	# all within the game's warm gold family (Louis: no green on stage): faint gold
	# on approach, bright gold while the press would land Good, a white flash inside
	# the Perfect band, dimming amber once the moment is slipping late.
	if encore_on("fright"):
		return   # Stage Fright: the lights are in your eyes, no landing markers at all
	var wp := perfect_window()
	# when two balls are both bound for the same hand (a fast fountain/columns feed,
	# or just a high count), only the SOONEST one gets a landing ring - a hand can
	# only catch one at a time, so a second ring there is clutter, not information
	# (mirrors the tutorial timing-ring fix)
	var soonest: Array[Ball] = [null, null]
	for b in balls:
		if b.state != STATE_FLIGHT:
			continue
		var dd := b.land_tick - tick
		if dd < -MISS_GRACE or dd >= 46:
			continue
		var h := clampi(b.to_hand, 0, 1)
		if soonest[h] == null or dd < soonest[h].land_tick - tick:
			soonest[h] = b
	for h in [LEFT, RIGHT]:
		var b: Ball = soonest[h]
		if b == null:
			continue
		var dd := b.land_tick - tick
		var t := clampf(1.0 - float(maxi(dd, 0)) / 46.0, 0.0, 1.0)
		var adiff := absi(dd)
		var r := 22.0 * prop_scale(b.kind)
		# a clacked ball (hard mode) catches ONLY inside the Perfect window
		# (same frames as normal): its ring stays warning-hot outside it, so
		# the taught timing never lies about what will actually catch
		if adiff <= wp:
			draw_arc(b.to_pos, r, 0.0, TAU, 40, Color(1.0, 1.0, 0.9, 0.95), 5.0, true)
			draw_circle(b.to_pos, r * 0.55, Color(1.0, 0.95, 0.7, 0.25))
		elif b.bumped:
			draw_arc(b.to_pos, r, 0.0, TAU, 40, Color(1.0, 0.4, 0.3, 0.2 + 0.5 * t), 3.0, true)
		elif adiff <= W_GOOD:
			draw_arc(b.to_pos, r, 0.0, TAU, 40, Color(1.0, 0.88, 0.5, 0.9), 4.0, true)
		elif adiff <= W_LATE and dd < 0:
			draw_arc(b.to_pos, r, 0.0, TAU, 40, Color(0.9, 0.62, 0.35, 0.7), 3.0, true)
		else:
			draw_arc(b.to_pos, r, 0.0, TAU, 40,
				Color(1.0, 0.9, 0.5, 0.14 + 0.5 * t), 2.0 + 3.0 * t, true)


func _btb_behind(b: Ball) -> bool:
	# a Behind-the-Back ball spends the first stretch of its flight hidden BEHIND
	# the figure (it was released behind the body), then pops out past the
	# shoulder. Behind = early in the flight AND still over the torso; once it
	# drifts wide or crests, it draws in front like everything else.
	if b.trick != TR_BTB:
		return false
	var span := maxi(1, b.land_tick - b.launch_tick)
	var p := clampf(float(tick - b.launch_tick) / float(span), 0.0, 1.0)
	return p < 0.35 and absf(flight_pos(b).x - stage_center().x) < 90.0


#endregion

#region PROP DRAWING
func draw_balls_in_flight(behind: bool = false) -> void:
	# two passes (see the play draw): the `behind` pass runs BEFORE the juggler
	# so a Behind-the-Back throw genuinely disappears behind the body
	for b in balls:
		if b.state == STATE_FLIGHT:
			if _btb_behind(b) != behind:
				continue
			# BLACKOUT challenge: the throw and the apex stay VISIBLE - the lights only
			# swallow the prop on its way down, so the challenge is catching from
			# memory of the arc, not juggling blind (fully invisible flight was way too
			# difficult - Louis). The cut is a hard one just past the apex: trail and
			# shape both go (a first version ghosted only the shape and the comet trail
			# still traced every prop). A TORCH is the exception: no blackout argues
			# with fire, so its flame burns through the dark stretch - that is the game
			# knowledge: bring torches to a Blackout night.
			if encore_on("blackout"):
				var bspan := maxi(1, b.land_tick - b.launch_tick)
				var bp := clampf(float(tick - b.launch_tick) / float(bspan), 0.0, 1.0)
				if bp > 0.68:
					if b.kind == PROP_TORCHES:
						draw_flame_in_dark(flight_pos(b))
					elif has_glow_kit:
						# the Glow-in-the-Dark Kit's mercy: a faint colour-matched halo, not
						# the full shape and not the trail - still meaningfully harder than
						# normal play, just never fully gone
						draw_glow_in_dark(flight_pos(b), b.color)
					continue
			draw_trail(b)
			var pos := flight_pos(b)
			draw_prop(b, pos)
			if pos.y < -8.0:
				# a fully HELD High Toss climbs clean out of the frame for a beat: a
				# small chevron pointing up tracks the ball's x so the player never
				# loses the prop, only sees it leave. It sits just BELOW the top-centre
				# HUD (the mode title and Applause meter live on the frame edge itself,
				# and a crossing toss spends its apex right over them). Fades in with
				# how far above the frame the ball is, so a barely-cresting throw
				# does not flicker it.
				var above := clampf((-8.0 - pos.y) / 40.0, 0.0, 1.0)
				var mc := Color(b.color.r, b.color.g, b.color.b, 0.35 + 0.5 * above)
				var mx := pos.x
				draw_colored_polygon(PackedVector2Array([
					Vector2(mx - 7.0, 67.0), Vector2(mx + 7.0, 67.0), Vector2(mx, 58.0)]), mc)
				draw_rect(Rect2(mx - 1.0, 70.0, 2.0, 9.0), Color(mc.r, mc.g, mc.b, mc.a * 0.45))


func draw_trail(b: Ball) -> void:
	# the comet tail behind a flying prop: longer for higher throws, its colour
	# cooling toward a pale blue with height, so a risky throw is visibly risky
	var n := b.trail.size()
	if n < 2:
		return
	var cool := clampf(b.height * 0.5, 0.0, 0.6)
	var base := b.color.lerp(Color(0.72, 0.82, 1.0), cool)
	var sc := prop_scale(b.kind)
	for i in n:
		var f := float(i + 1) / float(n)   # 0 tail .. 1 head
		draw_circle(b.trail[i], (2.0 + 6.0 * f) * sc, Color(base.r, base.g, base.b, 0.16 * f * f))


func draw_charge_gauges() -> void:
	# while THROW is held, a slim gauge grows beside that hand: warm gold is a snappy
	# controlled throw, amber buys airtime, red is the wild top. The old green start
	# and the apex preview line across the stage are gone per Louis's note (the green
	# lines on every throw); the gauge alone teaches height control.
	for h in [LEFT, RIGHT]:
		if not charging[h] or stack(h).is_empty():
			continue
		var hold := clampi(tick - int(charge_start[h]), 0, HOLD_MAX)
		var f := float(hold) / float(HOLD_MAX)
		var pos: Vector2 = hpos[h]
		var gx := pos.x + (-30.0 if h == LEFT else 30.0) - 3.0
		var gh := 52.0
		var gy := pos.y + 10.0
		draw_rect(Rect2(gx, gy - gh, 6.0, gh), Color(0.08, 0.05, 0.06, 0.75))
		var col := Color(1.0, 0.86, 0.5).lerp(Color(1.0, 0.68, 0.3), clampf(f * 1.6, 0.0, 1.0))
		if f > 0.78:
			col = col.lerp(Color(1.0, 0.35, 0.3), (f - 0.78) / 0.22)
		draw_rect(Rect2(gx, gy - gh * f, 6.0, gh * f), col)
		draw_rect(Rect2(gx - 1.0, gy - gh * 0.78, 8.0, 1.5), Color(1.0, 0.9, 0.7, 0.7))


func draw_flame_in_dark(pos: Vector2) -> void:
	# the Blackout's one concession: a torch's flame, faint and flickering, with no
	# handle and no trail - a small fire moving through the dark, nothing more
	var fl := 1.0 + 0.2 * sin(float(tick) * 0.5)
	draw_circle(pos + Vector2(0, -10), 16.0, Color(1.0, 0.55, 0.2, 0.06))
	draw_colored_polygon(PackedVector2Array([
		pos + Vector2(-5, -4), pos + Vector2(5, -4), pos + Vector2(0, -16.0 * fl),
	]), Color(1.0, 0.5, 0.15, 0.30))
	draw_colored_polygon(PackedVector2Array([
		pos + Vector2(-2.5, -5), pos + Vector2(2.5, -5), pos + Vector2(0, -12.0 * fl),
	]), Color(1.0, 0.85, 0.4, 0.32))


func draw_glow_in_dark(pos: Vector2, col: Color) -> void:
	# the Glow-in-the-Dark Kit's mercy (2026-07-18): a faint colour-matched halo
	# tracking the prop through Blackout's dark stretch - no shape, no trail, just
	# enough presence that the position stays honest. Genuinely harder than normal
	# play (you're still reading a smear of light, not a prop), genuinely kinder
	# than pure Blackout (never fully gone). The pulse rate is offset by x so a
	# whole load of glowing props doesn't flicker in lockstep.
	var fl := 0.7 + 0.3 * sin(float(tick) * 0.4 + pos.x * 0.05)
	draw_circle(pos, 15.0, Color(col.r, col.g, col.b, 0.09 * fl))
	draw_circle(pos, 5.5, Color(col.r, col.g, col.b, 0.32 * fl))
	draw_circle(pos, 1.8, Color(1.0, 1.0, 1.0, 0.35 * fl))


func draw_prop(b: Ball, pos: Vector2) -> void:
	var sc := prop_scale(b.kind)   # the prop's TRUE size, always: only the hitbox
								   # (prop_hit_scale) ever shrinks - on a big load, or
								   # always a bit for rings (mostly hollow rim)
	# a soft halo reads the catch lane for every prop; the shape says which prop.
	var halo := b.color
	halo.a = 0.16
	if b.bumped:
		# hard mode: a clacked prop glows warning-hot, so the player knows only
		# a frame-tight catch can still save it
		halo = Color(1.0, 0.4, 0.3, 0.24 + 0.1 * sin(float(tick) * 0.5))
	draw_circle(pos, 20.0 * sc, halo)
	if b.trick >= 0:
		# a trick throw carries a warm glowing ring so the crowd (and player) reads it as special
		var pulse := 0.5 + 0.5 * sin(float(tick) * 0.35)
		draw_arc(pos, (23.0 + 3.0 * pulse) * sc, 0.0, TAU, 26, Color(1.0, 0.86, 0.5, 0.5), 2.5, true)
		draw_circle(pos, 15.0 * sc, Color(1.0, 0.85, 0.5, 0.14))
	var ang := 0.0
	if bool(PROPS[b.kind]["spins"]) and b.state == STATE_FLIGHT:
		var span := maxi(1, b.land_tick - b.launch_tick)
		var p := clampf(float(tick - b.launch_tick) / float(span), 0.0, 1.0)
		ang = b.spin_dir * p * TAU * 2.0   # two tumbles across the flight
	match b.kind:
		PROP_EGGS, PROP_BALLS:
			# squash and stretch: a fast ball elongates slightly along its motion,
			# which makes the arc feel alive at zero cost to readability
			var k := 0.0
			var vang := 0.0
			if b.state == STATE_FLIGHT and b.trail.size() > 0:
				var vel := pos - b.trail[b.trail.size() - 1]
				k = clampf(vel.length() * 0.025, 0.0, 0.22)
				vang = vel.angle()
			draw_set_transform(pos, vang, Vector2(1.0 + k, 1.0 - k))
			if b.kind == PROP_EGGS:
				draw_egg(Vector2.ZERO, b.color, sc)
			else:
				draw_ball_shape(Vector2.ZERO, b.color, sc)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		PROP_RINGS:
			draw_ring_prop(pos, b.color, sc)
		PROP_CLUBS:
			draw_club(pos, ang, sc)
		PROP_KNIVES:
			draw_knife(pos, ang, sc)
		PROP_TORCHES:
			draw_torch(pos, ang, sc)
		_:
			draw_ball_shape(pos, b.color, sc)


func draw_ball_shape(pos: Vector2, col: Color, sc: float) -> void:
	draw_circle(pos, 11.0 * sc, col)
	var hi := col.lightened(0.4)
	hi.a = 0.9
	draw_circle(pos + Vector2(-3, -3) * sc, 3.5 * sc, hi)


func draw_egg(pos: Vector2, col: Color, sc: float) -> void:
	fill_ellipse(pos, 9.0 * sc, 12.0 * sc, col)
	var hi := col.lightened(0.25)
	hi.a = 0.9
	draw_circle(pos + Vector2(-3, -4) * sc, 2.6 * sc, hi)


func draw_ring_prop(pos: Vector2, col: Color, sc: float) -> void:
	draw_arc(pos, 12.0 * sc, 0.0, TAU, 28, col, 5.0 * sc, true)
	var hi := col.lightened(0.3)
	hi.a = 0.7
	draw_arc(pos, 12.0 * sc, -2.4, -1.0, 8, hi, 3.0 * sc, true)


func draw_club(pos: Vector2, ang: float, sc: float) -> void:
	draw_set_transform(pos, ang, Vector2.ONE * sc)
	var body := Color(0.90, 0.35, 0.38)
	var band := Color(0.96, 0.92, 0.85)
	draw_line(Vector2(0, 12), Vector2(0, -2), band, 4.0)   # handle
	draw_circle(Vector2(0, 13), 2.6, band)                 # knob
	draw_colored_polygon(PackedVector2Array([              # tapered body
		Vector2(-3, 0), Vector2(3, 0), Vector2(7, -14), Vector2(-7, -14),
	]), body)
	draw_circle(Vector2(0, -14), 7.0, body)                # rounded head
	# a soft same-hue sheen INSIDE the head - the old pale band arc sat on the rim
	# and read as a white chip stuck to the club (Louis), worst at shop-card size
	draw_circle(Vector2(-2.2, -16.2), 2.6, Color(1.0, 0.55, 0.56, 0.45))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func draw_knife(pos: Vector2, ang: float, sc: float) -> void:
	draw_set_transform(pos, ang, Vector2.ONE * sc)
	var steel := Color(0.82, 0.86, 0.92)
	var edge := Color(1.0, 1.0, 1.0, 0.9)
	var handle := Color(0.30, 0.20, 0.14)
	draw_colored_polygon(PackedVector2Array([              # blade
		Vector2(0, -15), Vector2(-4, 3), Vector2(4, 3),
	]), steel)
	draw_line(Vector2(0, -15), Vector2(-4, 3), edge, 1.5)  # bright edge
	draw_line(Vector2(-3, 4), Vector2(3, 4), handle, 3.0)  # guard
	draw_line(Vector2(0, 4), Vector2(0, 12), handle, 4.0)  # grip
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func draw_torch(pos: Vector2, ang: float, sc: float) -> void:
	draw_set_transform(pos, ang, Vector2.ONE * sc)
	var handle := Color(0.24, 0.16, 0.12)
	draw_line(Vector2(0, 14), Vector2(0, -2), handle, 4.0)
	var fl := 1.0 + 0.2 * sin(float(tick) * 0.5)           # flicker
	draw_colored_polygon(PackedVector2Array([              # outer flame
		Vector2(-6, -4), Vector2(6, -4), Vector2(0, -18.0 * fl),
	]), Color(1.0, 0.5, 0.15, 0.95))
	draw_colored_polygon(PackedVector2Array([              # inner flame
		Vector2(-3, -5), Vector2(3, -5), Vector2(0, -13.0 * fl),
	]), Color(1.0, 0.85, 0.4, 0.95))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func draw_prop_icon(kind: int, pos: Vector2, mag: float = 1.0) -> void:
	# a small, still version of the prop shape, for menus. mag blows it up for the
	# shop's big cards, where the tiny list-row size read as clutter (Louis)
	var col := prop_color(kind)
	var sc := minf(prop_scale(kind), 1.0) * mag
	match kind:
		PROP_EGGS:
			draw_egg(pos, col, sc)
		PROP_RINGS:
			draw_ring_prop(pos, col, sc)
		PROP_CLUBS:
			draw_club(pos, 0.0, sc)
		PROP_KNIVES:
			draw_knife(pos, 0.0, sc)
		PROP_TORCHES:
			draw_torch(pos, 0.0, sc)
		_:
			draw_ball_shape(pos, col, sc)


#endregion

#region HUD HELPERS & KEY-HINT LABELS
func hud_panel(r: Rect2, glow: bool = false) -> void:
	# a soft dark card with an ember hairline, so HUD numbers sit on something
	# instead of floating loose over the stage. `glow` breathes the hairline -
	# for a SELECTED menu row, so the cursor reads alive, not just lit; every
	# other (static, always-on) card leaves it off and looks exactly as before.
	draw_rect(r, Color(0.05, 0.03, 0.045, 0.55))
	if glow:
		var pulse := 0.5 + 0.5 * sin(float(cine_tick) * 0.08)
		draw_rect(r, Color(0.95, 0.7, 0.4, lerpf(0.28, 0.55, pulse)), false, 1.6)
	else:
		draw_rect(r, Color(0.9, 0.6, 0.35, 0.22), false, 1.0)


func hud_card(r: Rect2, accent := Color(0.95, 0.66, 0.4, 0.30)) -> void:
	# the rail cards (Phase 2 HUD): a touch more opaque than hud_panel so text stays
	# readable over a busy stage, with a thin top accent line for a little Balatro-ish
	# chunk. All live HUD lives in the LEFT and RIGHT rails now, never over the centre
	# where the props fly.
	draw_rect(r, Color(0.07, 0.04, 0.055, 0.84))
	draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 2.0), Color(accent.r, accent.g, accent.b, 0.5))
	draw_rect(r, accent, false, 1.0)


func draw_meter(x: float, y: float, w: float, h: float, frac: float, fill: Color, label := "") -> void:
	# a labelled progress bar used across the rails (target / crowd / stamina / xp)
	draw_rect(Rect2(x - 1, y - 1, w + 2, h + 2), Color(0.03, 0.02, 0.03, 0.7))
	draw_rect(Rect2(x, y, w, h), Color(0.18, 0.12, 0.10, 0.85))
	draw_rect(Rect2(x, y, w * clampf(frac, 0.0, 1.0), h), fill)
	if label != "":
		draw_string(game_font(), Vector2(x + 7, y + h - 4.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.08, 0.04, 0.03, 0.8))


func draw_drop_marks(x: float, y: float, lim: int, used: int) -> void:
	# the DROP limit, drawn as small DOWNWARD triangles (a falling prop, so it never
	# reads as a count of balls in play - Louis). Solid warm = a drop you can still
	# afford, hollow = spent; the last one left pulses in warning.
	for i in lim:
		var cxm := x + float(i) * 22.0
		var spent := i < used
		var last := (lim - used) == 1 and not spent
		var pts := PackedVector2Array([Vector2(cxm - 7.0, y), Vector2(cxm + 7.0, y), Vector2(cxm, y + 12.0)])
		if spent:
			draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), Color(0.4, 0.24, 0.22, 0.7), 1.5)
		else:
			var c := Color(0.96, 0.44, 0.34)
			if last:
				c = Color(1.0, 0.36, 0.28, 0.72 + 0.28 * sin(float(tick) * 0.28))
			draw_colored_polygon(pts, c)


func _wrap_text(font: Font, text: String, x: float, y: float, w: float, size: int, col: Color) -> void:
	# word-wrap a line to a width, for the Encore description in its rail card
	var words := text.split(" ")
	var line := ""
	var ly := y
	for word in words:
		var test := word if line == "" else line + " " + word
		if line != "" and font.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > w:
			draw_string(font, Vector2(x, ly), line, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
			line = word
			ly += float(size) + 4.0
		else:
			line = test
	if line != "":
		draw_string(font, Vector2(x, ly), line, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func pad_active() -> bool:
	# hints follow whichever device spoke most recently, so a keyboard player
	# never sees pad glyphs and a pad player never hunts for key names
	return _pad_last and pad_dev() >= 0


func k_catch() -> Array[String]:
	# the catch keycap labels for whichever device is active (remap-aware).
	# Pad labels follow Louis's own layout: triggers catch, bumpers throw.
	if pad_active():
		return ["LT", "RT"]
	return [OS.get_keycode_string(K_LC), OS.get_keycode_string(K_RC)]


func k_throw() -> Array[String]:
	if pad_active():
		return ["LB", "RB"]
	return [OS.get_keycode_string(K_LT), OS.get_keycode_string(K_RT)]


func k_pause() -> Array[String]:
	if pad_active():
		return ["B"]
	return ["Esc"]


func k_finish() -> Array[String]:
	# the "I am done here" key: take a bow on stage, advance a lesson, leave
	# practice. On a pad that is A - the bottom face button is Enter (Louis's
	# 2026-07-18 swap; A used to be Escape).
	if pad_active():
		return ["A"]
	return ["Enter"]


func k_sheet() -> Array[String]:
	# the character-sheet key: Tab on a keyboard, Y on a pad (swapped from X)
	if pad_active():
		return ["Y"]
	return ["Tab"]


func k_restart() -> Array[String]:
	# the practice re-deal: R on a keyboard, dpad-left on a pad (Louis)
	if pad_active():
		return ["◀"]
	return ["R"]


func k_shop() -> Array[String]:
	# the shop: S on a keyboard, dpad-down on a pad (Louis)
	if pad_active():
		return ["▼"]
	return ["S"]


func k_object() -> Array[String]:
	# switch the prop: O on a keyboard, dpad-up on a pad (Louis)
	if pad_active():
		return ["▲"]
	return ["O"]


func k_pattern() -> Array[String]:
	# switch the pattern: P on a keyboard, dpad-right on a pad (Louis)
	if pad_active():
		return ["▶"]
	return ["P"]


func k_trick() -> Array[String]:
	# remap-aware: PAD_TRICK defaults to X (swapped from Y) but can be rebound
	if pad_active():
		return [pad_button_glyph(PAD_TRICK)]
	return [OS.get_keycode_string(K_TRICK)]


func k_cycle() -> Array[String]:
	# remap-aware: PAD_CYCLE previously had no pad button at all (2026-07-18 fix)
	if pad_active():
		return [pad_button_glyph(PAD_CYCLE)]
	return [OS.get_keycode_string(K_CYCLE)]


func k_count() -> Array[String]:
	# the load-count step keys (down, then up): not one of the six remappable
	# actions, so not remap-aware, only device-aware. 1/2 on keyboard (2026-07-18:
	# replaced one-key-per-count, which ran out of number row once the cap passed
	# eleven; then Minus/Equal themselves were replaced same day - Louis: "bad
	# choices" - since 1 and 2 sit unclaimed during live play, the shop/sheet/
	# pause screens that also read the number row all being separate, gated
	# handlers); Back/R3 on a pad, which previously had no way at all to change
	# the count mid-performance.
	if pad_active():
		return ["Back", "R3"]
	return ["1", "2"]


func draw_keycap(font: Font, x: float, y: float, label: String) -> float:
	# a small keyboard-key box; returns its width so hints can chain
	var w := maxf(21.0, font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 11.0)
	draw_rect(Rect2(x, y, w, 19.0), Color(0.15, 0.10, 0.10, 0.92))
	draw_rect(Rect2(x, y, w, 19.0), Color(0.85, 0.65, 0.4, 0.45), false, 1.0)
	draw_string(font, Vector2(x, y + 14.0), label, HORIZONTAL_ALIGNMENT_CENTER, w, 12, Color(1.0, 0.9, 0.7))
	return w


func draw_hints_row(font: Font, cx: float, y: float, items: Array) -> void:
	# items: [[keys: Array, action: String], ...] drawn centred as keycaps + labels
	var total := 0.0
	for it in items:
		for k in it[0]:
			total += maxf(21.0, font.get_string_size(String(k), HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 11.0) + 3.0
		total += font.get_string_size(String(it[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 22.0
	total -= 22.0
	var x := cx - total * 0.5
	for it in items:
		for k in it[0]:
			x += draw_keycap(font, x, y, String(k)) + 3.0
		x += 3.0
		draw_string(font, Vector2(x, y + 14.0), String(it[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.82, 0.74, 0.62, 0.9))
		x += font.get_string_size(String(it[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 16.0


func commafy(n: int) -> String:
	# a thousands separator for the big booking numbers, so 34000 reads at a glance
	var raw := str(absi(n))
	var out := ""
	var c := 0
	for i in range(raw.length() - 1, -1, -1):
		out = raw[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if n < 0 else "") + out


func draw_hud(font: Font, s: Vector2) -> void:
	# THE HUD (rebuilt Balatro-style, Louis): the whole live state lives in a LEFT rail
	# (the contest - set, target, crowd, drops, the Encore) and a RIGHT rail (you - the
	# multiplier, stamina, purse, reputation, level). The CENTRE stays clear, because that
	# is where the props actually fly; nothing legible sits in their path any more.
	var performing := mode == MODE_PERFORM
	var gold := Color(1.0, 0.86, 0.45)
	var warm := Color(0.86, 0.76, 0.62)
	var dim := Color(0.72, 0.65, 0.56)

	# slow motion reads on screen: a cool veil + a quiet label, tucked low so it never
	# fights the rails or the stage
	var slow := slow_amount()
	if slow > 0.005:
		draw_rect(Rect2(0, 0, s.x, s.y), Color(0.55, 0.72, 1.0, 0.03 + 0.09 * slow))
		var stext := "SLOW  %d%%" % int(round(slow * 100.0))
		if pie_active:
			stext += "   (pie)"
		if _frames < chain_until:
			stext += "   thick time %ds" % int(ceil(float(chain_until - _frames) / 120.0))
		draw_text_shout(font, Vector2(0, s.y - 96.0), stext, HORIZONTAL_ALIGNMENT_CENTER, s.x, 15, Color(0.75, 0.9, 1.0, 0.9))

	# THE COLLAPSE, as it happens: the act is coming down and the player is told the one
	# reason WHY while the props are still in the air, which is the moment it lands
	# emotionally (Louis). The results card repeats the same words afterwards, so the
	# verdict never changes between the fall and the paperwork. Sits high, clear of the
	# hands at 0.57 and of the props tumbling past them.
	if collapsing:
		var cft := fail_text()
		if String(cft[0]) != "":
			var cy := s.y * 0.22
			draw_text_shout(font, Vector2(0, cy), String(cft[0]), HORIZONTAL_ALIGNMENT_CENTER, s.x, 30, Color(1.0, 0.45, 0.35))
			draw_multiline_string(font, Vector2(s.x * 0.25, cy + 28.0), String(cft[1]),
				HORIZONTAL_ALIGNMENT_CENTER, s.x * 0.5, 14, 2, Color(0.96, 0.82, 0.74, 0.92))

	# ============================ LEFT RAIL: the contest ============================
	var LX := 18.0
	var LW := 300.0
	if performing and not results_open:
		# --- the act header: venue, THE ACT, and one dot per goal reached ---
		hud_card(Rect2(LX, 16, LW, 52))
		draw_string(font, Vector2(LX + 14, 40), String(venue_data(run_venue)["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, gold)
		var setline := "THE ACT"
		if purist:
			setline += "   PURIST"
		draw_string(font, Vector2(LX + 14, 60), setline, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, warm)
		for i in NUM_GOALS:
			var dotc := Vector2(LX + LW - 20.0 - float(NUM_GOALS - 1 - i) * 18.0, 34.0)
			if i < goals_hit:
				draw_circle(dotc, 6.0, gold)
			else:
				draw_circle(dotc, 5.0, Color(0.35, 0.28, 0.24, 0.8))

		# --- the GOALS card: the hero. One continuous score, three notches to pass. ---
		var target := next_goal()
		var tcard_y := 78.0
		hud_card(Rect2(LX, tcard_y, LW, 108), Color(1.0, 0.82, 0.4, 0.4))
		draw_string(font, Vector2(LX + 14, tcard_y + 24), "SCORE", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.85, 0.72, 0.55))
		draw_string(font, Vector2(LX + 14, tcard_y + 52), commafy(score), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(1.0, 0.94, 0.76))
		# the record chase, top-right of the card
		if run_venue >= 0 and run_venue < rec_table().size() and rec_table()[run_venue] > 0:
			if record_broken:
				var ra := 0.7 + 0.3 * sin(float(tick) * 0.12)
				draw_string(font, Vector2(LX + LW - 134, tcard_y + 22), "NEW RECORD", HORIZONTAL_ALIGNMENT_RIGHT, 120.0, 11, Color(1.0, 0.86, 0.42, ra))
			else:
				draw_string(font, Vector2(LX + LW - 134, tcard_y + 22), "best  %s" % commafy(rec_table()[run_venue]), HORIZONTAL_ALIGNMENT_RIGHT, 120.0, 11, dim)
		# the meter runs the WHOLE act - zero to the final goal - with a notch at each
		# goal line, so where you are and what is left both read at a glance
		var g_final := goal_for(run_venue, NUM_GOALS - 1)
		var tfrac := clampf(float(score) / float(maxi(1, g_final)), 0.0, 1.0)
		var barx := LX + 14
		var barw := LW - 28
		var fcol := Color(0.82, 0.5, 0.28).lerp(Color(1.0, 0.86, 0.42), tfrac)
		draw_meter(barx, tcard_y + 63, barw, 20.0, tfrac, fcol)
		for gi in NUM_GOALS - 1:
			var nx := barx + barw * float(goal_for(run_venue, gi)) / float(maxi(1, g_final))
			draw_rect(Rect2(nx - 1.0, tcard_y + 61, 2.0, 24.0), Color(1.0, 0.95, 0.8, 0.75))
		var bartxt := "first goal  %s" % commafy(target)
		if goals_hit >= NUM_GOALS:
			bartxt = "ALL THREE GOALS  -  every point is yours"
		elif goals_hit > 0:
			bartxt = "next goal  %s" % commafy(target)
		draw_string(font, Vector2(barx, tcard_y + 78), bartxt, HORIZONTAL_ALIGNMENT_CENTER, barw, 12, Color(1.0, 0.95, 0.82))
		# the standing offer: from the first goal on, the cash-in is always open
		if goals_hit >= 1:
			var pl := 0.7 + 0.3 * sin(float(tick) * 0.14)
			draw_string(font, Vector2(LX + 14, tcard_y + 100), "%s or catch them all:  cash in  %s" % [String(k_finish()[0]), commafy(score)],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.75, 0.95, 0.7, pl))
		else:
			draw_string(font, Vector2(LX + LW - 148, tcard_y + 100), "%s: bow out" % String(k_finish()[0]), HORIZONTAL_ALIGNMENT_RIGHT, 134.0, 10, Color(0.72, 0.66, 0.58, 0.7))

		# --- the CROWD (patience clock) and the DROP limit ---
		var ccard_y := 194.0
		hud_card(Rect2(LX, ccard_y, LW, 70), Color(0.95, 0.5, 0.4, 0.35))
		draw_string(font, Vector2(LX + 14, ccard_y + 22), "THE CROWD", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.9, 0.72, 0.62))
		var pcol := Color(0.9, 0.3, 0.2).lerp(Color(1.0, 0.85, 0.42), applause)
		draw_meter(LX + 14, ccard_y + 28, LW - 28, 12.0, applause, pcol)
		draw_rect(Rect2(LX + 14 + (LW - 28) * peak_applause - 1.0, ccard_y + 26, 2.0, 16.0), Color(1.0, 0.95, 0.8, 0.6))
		draw_string(font, Vector2(LX + 14, ccard_y + 58), "DROPS", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.9, 0.6, 0.55))
		draw_drop_marks(LX + 72, ccard_y + 48, drop_limit(), dropped)

		# --- the CHALLENGE condition, live for the whole act when one was rolled ---
		if encore >= 0 and encore < ENCORES.size():
			var ec := Color(1.0, 0.55, 0.42)
			hud_card(Rect2(LX, 272, LW, 66), Color(ec.r, ec.g, ec.b, 0.5))
			draw_string(font, Vector2(LX + 14, 294), String(ENCORES[encore]["name"]).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, ec)
			_wrap_text(font, String(ENCORES[encore]["desc"]), LX + 14, 312, LW - 28, 11, Color(0.9, 0.82, 0.72, 0.9))
	elif not performing:
		# training: no contest, just the mode. The prop and pattern are NOT repeated
		# here (Louis: no redundancy) - the routine card at the foot of the stage
		# owns them, along with the keys that switch them.
		var nb := next_ball_strength()
		hud_card(Rect2(LX, 16, LW, 94.0 if nb > 0 else 74.0))
		var tl := "PRACTICE" + ("   -   DEBUG" if debug_mode else "")
		draw_string(font, Vector2(LX + 14, 40), tl, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.72, 0.82, 0.9))
		draw_string(font, Vector2(LX + 14, 60), "no crowd, no pay", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, warm)
		# the count keys, said once here; the bottom-left card counts the load itself
		draw_string(font, Vector2(LX + 14, 78), "%s  %s  step the count" % [String(k_count()[0]), String(k_count()[1])], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.72, 0.66, 0.56, 0.85))
		if nb > 0:
			draw_string(font, Vector2(LX + 14, 94), "next ball at Strength %d" % nb, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.72, 0.66, 0.56, 0.85))

	# ============================ RIGHT RAIL: you ============================
	# hidden during the results panel so it never lingers, dimmed, beside the card
	if not results_open:
		var RW := 264.0
		var RX := s.x - 18.0 - RW
		# the MULTIPLIER - the addictive number, big and heat-coloured. It is the streak
		# CAPPED per load (streak_cap): once you hit the ceiling it holds, so a bigger
		# multiplier means more (and heavier) props, not a longer easy run (Louis).
		hud_card(Rect2(RX, 16, RW, 50))
		var cap := streak_cap()
		var mult := mini(streak, cap)
		var capped := streak >= cap and streak > 0
		var heat := clampf(float(mult) / float(cap), 0.0, 1.0)
		var scol2 := Color(0.85, 0.8, 0.7).lerp(Color(1.0, 0.68, 0.22), heat)
		var mpulse := maxi(0, 7 - (tick - last_streak_tick)) if streak > 0 else 0
		draw_string(font, Vector2(RX + 14, 52), "x%d" % mult, HORIZONTAL_ALIGNMENT_LEFT, -1, 26 + mpulse, scol2)
		draw_string(font, Vector2(RX + RW - 150, 40), "MAX  -  x%d" % cap if capped else "STREAK  /%d" % cap, HORIZONTAL_ALIGNMENT_RIGHT, 136.0, 11, Color(1.0, 0.7, 0.35) if capped else Color(0.85, 0.72, 0.55))
		draw_string(font, Vector2(RX + RW - 150, 56), "best  %d" % best_streak, HORIZONTAL_ALIGNMENT_RIGHT, 136.0, 12, dim)
		# STATE: only what actually moves or matters DURING a run (Louis: the play
		# HUD is not a character sheet). Stamina drains live, so it stays; unspent
		# stat points are actionable (Tab), so they get one pulsing line. Gold,
		# Reputation, and the LV/XP bar never change mid-run - they live in the
		# day hub, the sheet, and the results card instead of being repeated here.
		var pts_row := points > 0
		hud_card(Rect2(RX, 74, RW, 66.0 if pts_row else 48.0))
		var sx := RX + 14.0
		var sw := RW - 28.0
		var sfrac := clampf(stamina / maxf(1.0, stamina_max), 0.0, 1.0)
		draw_string(font, Vector2(sx, 96), "STAMINA", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.85, 0.9, 0.85, 0.85))
		draw_string(font, Vector2(sx + sw - 80.0, 96), "%d / %d" % [int(round(stamina)), int(stamina_max)], HORIZONTAL_ALIGNMENT_RIGHT, 80.0, 11, Color(0.85, 0.9, 0.85, 0.85))
		var stcol := Color(0.55, 0.80, 0.6)
		if sfrac < STAM_LOW:
			stcol = stcol.lerp(Color(0.95, 0.35, 0.25), clampf((STAM_LOW - sfrac) / STAM_LOW, 0.0, 1.0))
		draw_meter(sx, 102, sw, 11.0, sfrac, stcol)
		if pts_row:
			var pa := 0.75 + 0.25 * sin(float(tick) * 0.08)
			draw_string(font, Vector2(sx, 132), "+%d stat point%s  -  %s" % [points, "" if points == 1 else "s", k_sheet()[0]], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.7, 0.95, 0.7, pa))

	# a freshly unlocked trick announces itself, non-blocking, only while juggling
	if not tut_active and running and trick_unlock >= 0 and tick - trick_unlock_tick < 360:
		draw_trick_unlock_banner(font, s)
	# trick feedback line, tucked LOW under the performer so it never sits in the arcs
	if not tut_active and trick_msg != "" and tick - trick_msg_tick < 90:
		var ta := clampf(1.0 - float(tick - trick_msg_tick) / 90.0, 0.0, 1.0)
		draw_text_shout(font, Vector2(s.x * 0.5 - 200, s.y - 128.0), trick_msg, HORIZONTAL_ALIGNMENT_CENTER, 400, 17, Color(1.0, 0.88, 0.55, ta))
	# the loaded-trick readout (bottom-right corner, out of the way). Lessons draw
	# their own corner card from _draw's lesson branch - draw_hud never runs there.
	if not tut_active and not results_open and not unlocked_tricks().is_empty():
		draw_trick_hud(font, s)
	# the routine readout (bottom-left): the object and pattern in play, and the keys
	# that switch them - live mid-performance now, not just in practice (Louis)
	if not tut_active and not results_open:
		draw_routine_hud(font, s)

	if not tut_active and not results_open:
		# an under-strength warning sits low-centre, in words, only when it applies
		if prop_deficit() > 0.0:
			draw_text_shout(font, Vector2(0, s.y - 112.0), "TOO WEAK for %s  -  throws sag low and wild (needs Strength %d)" % [String(cur_prop()["name"]).to_upper(), prop_req()], HORIZONTAL_ALIGNMENT_CENTER, s.x, 13, Color(1.0, 0.55, 0.4))
		if not started:
			var verb := "perform" if performing else "practise"
			var pa2 := 0.75 + 0.25 * sin(float(tick) * 0.06)
			# k_throw(), not a hand-typed label: a pad throws with the BUMPERS (LB/RB),
			# and "L2/R2" (this used to read, wrongly - trigger-style names, which are
			# the CATCH buttons) would have sent a pad player's fingers to the wrong pair
			var kt := k_throw()
			var tnames := "( %s or %s )" % [kt[0], kt[1]]
			draw_text_shout(font, Vector2(0, s.y * 0.22), "press a THROW  %s  to %s" % [tnames, verb],
				HORIZONTAL_ALIGNMENT_CENTER, s.x, 21, Color(1.0, 0.86, 0.55, pa2))
			draw_text_shout(font, Vector2(0, s.y * 0.22 + 26.0), "bookings and rest live in the day  -  Esc, then End the session",
				HORIZONTAL_ALIGNMENT_CENTER, s.x, 14, Color(0.85, 0.75, 0.6, 0.8))
		elif not running:
			# training keeps the plain end-of-run line (a booking goes straight to results)
			draw_text_shout(font, Vector2(0, s.y * 0.20), "ROUND OVER", HORIZONTAL_ALIGNMENT_CENTER, s.x, 40, Color(1.0, 0.5, 0.4))
			draw_text_shout(font, Vector2(0, s.y * 0.20 + 40), "best streak %d   XP +%d   -   R goes again, Enter ends the session" % [best_streak, run_xp], HORIZONTAL_ALIGNMENT_CENTER, s.x, 19, Color(0.9, 0.82, 0.7))


#endregion

#region RESULTS CARD, PAUSE MENU, TRICK/ROUTINE HUD
func _result_row(font: Font, lx: float, rx: float, y: float, label: String, value: String, vc: Color, a: float = 1.0) -> void:
	if a <= 0.0:
		return
	var slide := (1.0 - a) * 10.0
	draw_string(font, Vector2(lx + slide, y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.78, 0.72, 0.66, a))
	draw_string(font, Vector2(rx - 300.0 + slide, y), value, HORIZONTAL_ALIGNMENT_RIGHT, 300.0, 18, Color(vc.r, vc.g, vc.b, a))


func results_age() -> int:
	return tick - results_tick if results_tick >= 0 else 999


func results_anim_sfx() -> void:
	# the results card's little sound story, run from the physics tick (draw code
	# must never play audio): soft ticks under the score count-up, the stamp thud,
	# and the record fanfare with a confetti drop
	var age := results_age()
	if age > 8 and age <= 54 and age % 5 == 0:
		play_sfx("count", -22.0, 1.0 + float(age) * 0.004)
	if age >= 64 and not results_stamped:
		results_stamped = true
		play_sfx("stamp", -8.0)
		if results_record:
			play_sfx("record", -7.0)
			var s := get_viewport_rect().size
			spawn_parts(Vector2(s.x * 0.5, s.y * 0.5 - 240.0), Color(1.0, 0.85, 0.45), 20, 2.8, "confetti")
			spawn_parts(Vector2(s.x * 0.5 - 200.0, s.y * 0.5 - 220.0), Color(0.72, 0.86, 0.95), 12, 2.4, "confetti")
			spawn_parts(Vector2(s.x * 0.5 + 200.0, s.y * 0.5 - 220.0), Color(0.95, 0.55, 0.45), 12, 2.4, "confetti")


func draw_results(font: Font, s: Vector2) -> void:
	# the end-of-performance card: the grade, the numbers, the pay and rep swing, and
	# the venue record to chase. It REVEALS itself: rows slide in one by one while
	# the score counts up, then the grade stamps down. Anticipation is the payoff.
	var age := results_age()
	var card_a := clampf(float(age) / 14.0, 0.0, 1.0)
	draw_rect(Rect2(0, 0, s.x, s.y), Color(0.04, 0.02, 0.03, 0.82 * card_a))
	var pw := 580.0
	var ph := 500.0   # tall enough that the footer hints breathe below the XP row
	var px := s.x * 0.5 - pw * 0.5
	var py := s.y * 0.5 - ph * 0.5 + (1.0 - card_a) * 24.0
	draw_rect(Rect2(px, py, pw, ph), Color(0.12, 0.07, 0.08, 0.98 * card_a))
	draw_rect(Rect2(px, py, pw, ph), Color(0.9, 0.6, 0.35, 0.5 * card_a), false, 2.0)
	if card_a < 1.0:
		return
	var lx := px + 34.0
	var rx := px + pw - 34.0

	# header: the night's outcome and venue; the grade badge stamps in later
	var complete := goals_hit >= NUM_GOALS
	var htag := "THE ACT  -  ALL THREE GOALS" if complete else ("THE ACT  -  %d of %d goals" % [goals_hit, NUM_GOALS])
	var htc := Color(1.0, 0.86, 0.45) if complete else Color(0.9, 0.72, 0.55)
	draw_string(font, Vector2(lx, py + 40.0), htag, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, htc)
	draw_string(font, Vector2(lx, py + 74.0), String(venue_data(run_venue)["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1.0, 0.86, 0.5))
	# WHY the night ended, right under its name, whenever it did not end in a win: the
	# card used to show only what was scored and left the player to guess the cause.
	# The grade badge sits far right, so this line has the left of the card to itself.
	var ft := fail_text()
	if not complete and String(ft[0]) != "":
		draw_string(font, Vector2(lx, py + 96.0), String(ft[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.0, 0.55, 0.42))
	if age >= 64:
		var k := clampf(float(age - 64) / 9.0, 0.0, 1.0)
		var sc := 1.0 + 1.1 * (1.0 - k) * (1.0 - k)   # stamps down from large to rest
		var g := run_grade()
		var gc := grade_color(g)
		var bc := Vector2(rx - 42.0, py + 56.0)
		draw_set_transform(bc, -0.06 * (1.0 - k), Vector2(sc, sc))
		draw_circle(Vector2.ZERO, 42.0, Color(gc.r, gc.g, gc.b, 0.14 * k + 0.06))
		draw_arc(Vector2.ZERO, 42.0, 0.0, TAU, 40, gc, 3.0, true)
		draw_string(font, Vector2(-42.0, 21.0), g, HORIZONTAL_ALIGNMENT_CENTER, 84.0, 58, gc)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_line(Vector2(lx, py + 104.0), Vector2(rx, py + 104.0), Color(0.9, 0.6, 0.35, 0.3), 1.0)

	# stat rows, each fading in a beat after the last; the score value counts up
	var t_count := clampf(float(age - 8) / 46.0, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - t_count, 3.0)
	var shown_score := int(round(float(score) * eased))
	var ra := func(i: int) -> float: return clampf(float(age - 10 - i * 7) / 10.0, 0.0, 1.0)
	var y := py + 140.0
	var rowh := 40.0
	_result_row(font, lx, rx, y, "Booking score", commafy(shown_score), Color(1.0, 0.92, 0.72), ra.call(0))
	if age > 54:
		var rec := "NEW VENUE RECORD" if results_record else "best here   %s" % commafy(rec_table()[run_venue])
		if purist:
			rec = "PURIST  -  " + rec
		var recc := Color(1.0, 0.86, 0.42) if results_record else Color(0.68, 0.62, 0.54)
		if results_record:
			recc.a = 0.7 + 0.3 * sin(float(tick) * 0.1)
		draw_string(font, Vector2(rx - 300.0, y + 15.0), rec, HORIZONTAL_ALIGNMENT_RIGHT, 300.0, 13, recc)
	y += rowh + 8.0
	var pct := int(round(100.0 * run_clean()))
	_result_row(font, lx, rx, y, "Caught  /  Dropped", "%d  /  %d    (%d%%)" % [caught, dropped, pct], Color(0.86, 0.9, 0.82), ra.call(1)); y += rowh
	_result_row(font, lx, rx, y, "Best streak", str(best_streak), Color(0.9, 0.82, 0.6), ra.call(2)); y += rowh
	var tval := "%d   (+%d)" % [tricks_landed, trick_score] if trick_score > 0 else str(tricks_landed)
	_result_row(font, lx, rx, y, "Tricks landed", tval, Color(0.93, 0.8, 0.99), ra.call(3)); y += rowh
	draw_line(Vector2(lx, y - 6.0), Vector2(rx, y - 6.0), Color(0.9, 0.6, 0.35, 0.2), 1.0)
	_result_row(font, lx, rx, y + 20.0, "Pay", "+%d gold" % last_pay, Color(1.0, 0.86, 0.45), ra.call(4)); y += rowh
	var rsign := "+" if last_rep_delta >= 0 else ""
	var rcol := Color(0.7, 0.95, 0.7) if last_rep_delta >= 0 else Color(1.0, 0.55, 0.45)
	_result_row(font, lx, rx, y + 20.0, "Reputation", "%s%d    %s" % [rsign, last_rep_delta, rep_tier()], rcol, ra.call(5)); y += rowh
	_result_row(font, lx, rx, y + 20.0, "XP gained", "+%d" % run_xp, Color(0.82, 0.9, 0.7), ra.call(6)); y += rowh

	# ...and the reason spelled out, in the clear space above the footer: the headline
	# by the venue name says WHAT happened, this says what to do about it. Last to
	# arrive, so it reads as the card's closing word rather than competing with the
	# count-up. A complete booking has no reason to give (nothing failed).
	if not complete and String(ft[1]) != "" and age > 74:
		draw_multiline_string(font, Vector2(px + 34.0, py + ph - 66.0), String(ft[1]),
			HORIZONTAL_ALIGNMENT_CENTER, pw - 68.0, 12, 2, Color(0.86, 0.72, 0.64, 0.85))

	# footer: how to continue, breathing gently once everything is revealed. every
	# slot in this footer has a real pad button - the pad footer names only
	# buttons it can actually press, via the remap-aware k_* hint helpers.
	if age > 80:
		var fa := 0.7 + 0.3 * sin(float(tick) * 0.05)
		var foot := ""
		if pending_win:
			# the top stage just fell: the first key rolls into the victory screen
			foot = "you have conquered the final stage  -  any key"
		elif too_tired():
			# the reason R will not work, in words, right where the player looks
			foot = "too tired to go again  -  %s back to the day, then sleep" % String(k_finish()[0])
		else:
			var kgo := String(k_trick()[0]) if pad_active() else "R"
			var kshop := String(k_shop()[0])
			var ksheet := String(k_sheet()[0])
			var kmenu := String(k_finish()[0])
			foot = "%s  go again      %s  shop      %s  back to the day" % [kgo, kshop, kmenu]
			if points > 0:
				foot = "%s  go again      %s  +%d point%s      %s  shop      %s  back to the day" % [kgo, ksheet, points, "" if points == 1 else "s", kshop, kmenu]
		draw_string(font, Vector2(px, py + ph - 26.0), foot, HORIZONTAL_ALIGNMENT_CENTER, pw, 15, Color(0.86, 0.78, 0.64, fa))


func draw_pause(font: Font, s: Vector2) -> void:
	draw_rect(Rect2(0, 0, s.x, s.y), Color(0.04, 0.02, 0.03, 0.72))
	var pw := 360.0
	var ph := 268.0
	var px := s.x * 0.5 - pw * 0.5
	var py := s.y * 0.5 - ph * 0.5
	draw_rect(Rect2(px, py, pw, ph), Color(0.12, 0.07, 0.08, 0.98))
	draw_rect(Rect2(px, py, pw, ph), Color(0.9, 0.6, 0.35, 0.5), false, 2.0)
	draw_string(font, Vector2(px, py + 52.0), "PAUSED", HORIZONTAL_ALIGNMENT_CENTER, pw, 30, Color(1.0, 0.86, 0.5))
	draw_ornament(px + pw * 0.5, py + 70.0, 120.0, Color(0.82, 0.62, 0.34, 0.7))
	var opts: Array[String] = ["Resume", "End the session", "Quit Game"]
	var oy := py + 116.0
	for i in opts.size():
		var sel := i == pause_sel
		var col := Color(1.0, 0.9, 0.6) if sel else Color(0.74, 0.68, 0.62)
		var label := ("> %s <" % opts[i]) if sel else opts[i]
		draw_string(font, Vector2(px, oy + float(i) * 40.0), label, HORIZONTAL_ALIGNMENT_CENTER, pw, 22, col)
	var pfoot := "up / down  -  A selects  -  B resumes" if pad_active() else "up / down  -  Enter  -  Esc resumes"
	draw_string(font, Vector2(px, py + ph - 20.0), pfoot, HORIZONTAL_ALIGNMENT_CENTER, pw, 12, Color(0.72, 0.66, 0.6))


func draw_trick_unlock_banner(font: Font, s: Vector2) -> void:
	# a small, non-intrusive toast: it names the skill and points to the SKILLS
	# screen for how to use it, instead of the old page-wide how-to card. The
	# loaded skill also appears in the trick HUD at the foot of the stage.
	var age := tick - trick_unlock_tick
	var a := 1.0
	if age < 16:
		a = float(age) / 16.0
	elif age > 300:
		a = clampf(float(360 - age) / 60.0, 0.0, 1.0)
	if a <= 0.0:
		return
	var t: Dictionary = TRICKS[trick_unlock]
	var bw := 336.0
	var bx := s.x * 0.5 - bw * 0.5
	var by := s.y * 0.17
	var glow := 0.5 + 0.5 * sin(float(tick) * 0.11)
	draw_rect(Rect2(bx, by, bw, 40.0), Color(0.10, 0.06, 0.08, 0.86 * a))
	draw_rect(Rect2(bx, by, bw, 40.0), Color(1.0, 0.82, 0.45, (0.34 + 0.28 * glow) * a), false, 1.5)
	draw_string(font, Vector2(bx, by + 18.0), "NEW SKILL   %s" % String(t["name"]).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, bw, 16, Color(1.0, 0.88, 0.52, a))
	draw_string(font, Vector2(bx, by + 33.0), "how to use it lives in  SKILLS", HORIZONTAL_ALIGNMENT_CENTER, bw, 11, Color(0.82, 0.76, 0.66, 0.85 * a))


func draw_trick_hud(font: Font, s: Vector2) -> void:
	# the loaded one-shot: which trick Space is carrying, and whether it is primed.
	# READY burns gold so the player always knows the next throw is the trick shot.
	# Sits bottom-RIGHT, mirroring the venue/prop card bottom-left, so the two share
	# the foot of the stage evenly instead of the trick card floating mid-screen.
	var un := unlocked_tricks()
	var sel := trick_sel
	if tut_active and tut_id.begins_with("trick_"):
		sel = trick_by_id(tut_id.substr(6))   # a lesson shows ITS trick, gate or no gate
	elif sel < 0 or not trick_unlocked(sel):
		sel = int(un[0])
	if sel < 0:
		return
	var kind := String(TRICKS[sel]["kind"])
	var label := String(TRICKS[sel]["name"]).to_upper()
	var hot := false
	if kind == "arm" and trick_primed:
		label += "  -  READY"
		hot = true
	elif kind == "toggle" and toggle_on == sel:
		label += "  -  ON"
		hot = true
	elif toggle_on >= 0:
		# a toggle is RUNNING while the player has cycled the selection to a different
		# trick (ROADMAP 12c). Cycling never stops a toggle - only a second Space does -
		# but the old HUD dimmed this whole line and buried the still-ON toggle in a
		# small lowercase aside, so it read as "my trick switched off". Lead with the
		# running toggle, loud and gold, and demote the mere selection to the aside, so
		# "what is ON" always wins the eye over "what is loaded".
		label = "%s  -  ON   (%s next)" % [String(TRICKS[toggle_on]["name"]).to_upper(),
			String(TRICKS[sel]["name"])]
		hot = true
	var lc := Color(1.0, 0.86, 0.5) if hot else Color(0.72, 0.66, 0.78, 0.85)
	var pw := 330.0
	var px := s.x - 18.0 - pw    # mirror of the venue card's left margin
	var cx := px + pw * 0.5
	hud_panel(Rect2(px, s.y - 78.0, pw, 60.0))
	# no "TRICK -" prefix (the hints row already says trick, and the routine card
	# opposite carries no prefix either), and the title shrinks to FIT the card -
	# "BEHIND THE BACK - ON (High Toss next)" used to run off the right edge
	var fs := 16
	while fs > 11 and font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > pw - 24.0:
		fs -= 1
	draw_string(font, Vector2(px + 12.0, s.y - 52.0), label, HORIZONTAL_ALIGNMENT_CENTER, pw - 24.0, fs, lc)
	var items: Array = []
	var use := ""
	match kind:
		"live":
			use = "spin"
			if tick < trick_ready:
				use = "spin in %.1fs" % (float(trick_ready - tick) / 120.0)
		"toggle":
			use = "switch off" if toggle_on == sel else "switch on"
		_:
			use = "wave off" if trick_primed else "one throw"
	items.append([k_trick(), use])
	if un.size() > 1:
		items.append([k_cycle(), "switch trick"])
	draw_hints_row(font, cx, s.y - 40.0, items)


func draw_routine_hud(font: Font, s: Vector2) -> void:
	# bottom-LEFT mirror of the trick readout: the OBJECT and PATTERN in play, and
	# under them a LIVE count of where every prop is - left hand, in the air, right
	# hand - updating throw by throw (Louis: that beats a row of key hints here; the
	# O and P keys still work, and the lessons and Skills screen teach them).
	var pw := 330.0
	var px := 18.0
	var cx := px + pw * 0.5
	hud_panel(Rect2(px, s.y - 78.0, pw, 60.0))
	var oname := String(cur_prop()["name"]).to_upper()
	var pname := String(PATTERNS[pattern]["name"]).to_upper()
	var ocol := ball_color(0) if prop_type == PROP_BALLS else prop_color(prop_type)
	# object name in its own colour, pattern name warm, centred together as the title
	var otext := oname + "    "
	var ow := font.get_string_size(otext, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var jw := ow + font.get_string_size(pname, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var jx := cx - jw * 0.5
	draw_string(font, Vector2(jx, s.y - 52.0), oname, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ocol)
	draw_string(font, Vector2(jx + ow, s.y - 52.0), pname, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.86, 0.76, 0.62))
	var colw := pw / 3.0
	var cy := s.y - 26.0
	var hand_c := Color(0.92, 0.84, 0.7)
	draw_string(font, Vector2(px, cy), "left hand  %d" % _stack_l.size(), HORIZONTAL_ALIGNMENT_CENTER, colw, 13, hand_c)
	draw_string(font, Vector2(px + colw, cy), "in the air  %d" % balls_airborne(), HORIZONTAL_ALIGNMENT_CENTER, colw, 13, Color(0.7, 0.85, 1.0))
	draw_string(font, Vector2(px + colw * 2.0, cy), "right hand  %d" % _stack_r.size(), HORIZONTAL_ALIGNMENT_CENTER, colw, 13, hand_c)


#endregion

#region CHARACTER SHEET SCREEN
func draw_sheet(font: Font, s: Vector2) -> void:
	# the character sheet, dealt as CARDS like the shop (Louis: Balatro look - one big
	# card per stat, its key printed on the card, a loud banner when points wait)
	draw_rect(Rect2(0, 0, s.x, s.y), Color(0.04, 0.02, 0.03, 0.86))
	var pw := minf(1040.0, s.x - 60.0)
	var ph := 560.0
	var px := s.x * 0.5 - pw * 0.5
	var py := s.y * 0.5 - ph * 0.5
	draw_rect(Rect2(px, py, pw, ph), Color(0.10, 0.06, 0.075, 0.98))
	draw_rect(Rect2(px, py, pw, ph), Color(0.9, 0.6, 0.35, 0.5), false, 2.0)

	var tx := px + 40.0
	var innerw := pw - 80.0
	draw_string(font, Vector2(tx, py + 52.0), "JUGGLER", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(1.0, 0.86, 0.55))
	if debug_mode:
		draw_string(font, Vector2(tx + 168.0, py + 50.0), "DEBUG BUILD", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.55, 0.9, 1.0))
	draw_purse(font, px + pw - 40.0, py + 52.0)
	draw_string(font, Vector2(px, py + 74.0), "Rep %s   %s" % [commafy(reputation), rep_tier()], HORIZONTAL_ALIGNMENT_RIGHT, pw - 40.0, 13, Color(0.82, 0.72, 0.85))

	# the level and its road: one full-width bar, the number on it
	var need := xp_to_next(level)
	var xf := clampf(float(xp) / float(maxi(1, need)), 0.0, 1.0)
	draw_string(font, Vector2(tx, py + 96.0), "LEVEL %d" % level, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1.0, 0.9, 0.6))
	var xbx := tx + 130.0
	var xbw := innerw - 130.0
	draw_rect(Rect2(xbx, py + 82.0, xbw, 16.0), Color(0.2, 0.14, 0.11, 0.8))
	draw_rect(Rect2(xbx, py + 82.0, xbw * xf, 16.0), Color(0.9, 0.7, 0.35))
	draw_string(font, Vector2(xbx, py + 95.0), "%d / %d xp" % [xp, need], HORIZONTAL_ALIGNMENT_CENTER, xbw, 12, Color(1.0, 0.96, 0.85))

	# the SPEND banner: impossible to miss when points are waiting, quiet otherwise
	var by0 := py + 116.0
	if points > 0:
		var pa := 0.75 + 0.25 * sin(float(Time.get_ticks_msec()) * 0.006)
		draw_rect(Rect2(tx, by0, innerw, 34.0), Color(1.0, 0.84, 0.4, 0.16 + 0.10 * pa))
		draw_rect(Rect2(tx, by0, innerw, 34.0), Color(1.0, 0.86, 0.45, 0.7), false, 1.5)
		draw_string(font, Vector2(tx, by0 + 23.0), "%d POINT%s TO SPEND  -  press the key on a card" % [points, "" if points == 1 else "S"],
			HORIZONTAL_ALIGNMENT_CENTER, innerw, 16, Color(1.0, 0.92, 0.7))
	elif all_stats_capped():
		var mtext := "MASTERY - every stat is at its ceiling. Each new level now pays %d gold per point" % MASTERY_GOLD
		if int(career.get("mastery", 0)) > 0:
			mtext += "  (%d earned so far)" % int(career.get("mastery", 0))
		draw_string(font, Vector2(tx, by0 + 23.0), mtext, HORIZONTAL_ALIGNMENT_CENTER, innerw, 13, Color(1.0, 0.88, 0.55))
	else:
		draw_string(font, Vector2(tx, by0 + 23.0), "Skill sets your score. Stats only ease the climb - the next point comes with the next level.",
			HORIZONTAL_ALIGNMENT_CENTER, innerw, 13, Color(0.75, 0.7, 0.62))

	# ---------------- four stat cards ----------------
	var str_note := "heavy props fly higher and catch easier - %d balls now" % max_balls()
	if next_ball_strength() > 0:
		str_note = "heavy props steadier and easier to catch. The %d-ball unlock waits at Str %d" % [max_balls() + 1, next_ball_strength()]
	var acc_note := "a better chance to hold off-Perfect catches, and throws land closer to the hand"
	if accuracy > 100:
		if focus() <= 100.0:
			acc_note = "Focus %d - every action costs less stamina" % int(focus())
		else:
			acc_note = "Focus %d - minimum stamina cost, +%d ticks on the Perfect window" % [int(focus()), perfect_window() - W_PERFECT]
	var spd_pct := speed / 8
	var spd_note := "the world runs %d%% slower for you - 8 points per percent, capped at %d%%" % [spd_pct, SPEED_CAP / 8]
	if speed >= SPEED_CAP:
		spd_note = "the world runs %d%% slower for you - at the cap" % spd_pct
	var stats: Array = [
		["ACCURACY", accuracy, acc_note, "1", Color(0.6, 0.8, 1.0)],
		["STRENGTH", strength, str_note, "2", Color(0.95, 0.55, 0.4)],
		["ENDURANCE", endurance, "raises your maximum stamina, the fuel every throw and catch burns", "3", Color(0.55, 0.8, 0.6)],
		["SPEED", speed, spd_note, "4", Color(0.8, 0.7, 0.95)],
	]
	var gap := 16.0
	var cw := (innerw - gap * 3.0) / 4.0
	var ch := 240.0
	var y0 := py + 168.0
	for i in stats.size():
		var st: Array = stats[i]
		var cx0 := tx + float(i) * (cw + gap)
		var ac: Color = st[4]
		hud_card(Rect2(cx0, y0, cw, ch), Color(ac.r, ac.g, ac.b, 0.45))
		if i == sheet_sel:
			# the card cursor: arrows / dpad / stick moved it here, Enter (pad A)
			# invests here. A breathing gold frame, so it reads without stealing
			# the card's own colour.
			var sa := 0.55 + 0.35 * sin(float(Time.get_ticks_msec()) * 0.006)
			draw_rect(Rect2(cx0 - 4.0, y0 - 4.0, cw + 8.0, ch + 8.0), Color(1.0, 0.86, 0.45, sa), false, 2.5)
		draw_string(font, Vector2(cx0, y0 + 26.0), String(st[0]), HORIZONTAL_ALIGNMENT_CENTER, cw, 14, Color(ac.r, ac.g, ac.b, 0.95))
		draw_string(font, Vector2(cx0, y0 + 78.0), str(int(st[1])), HORIZONTAL_ALIGNMENT_CENTER, cw, 44, Color(1.0, 0.94, 0.76))
		draw_multiline_string(font, Vector2(cx0 + 12.0, y0 + 108.0), String(st[2]),
			HORIZONTAL_ALIGNMENT_CENTER, cw - 24.0, 11, 5, Color(0.78, 0.72, 0.64))
		# the invest plate: bright and green when a point can land here, quiet otherwise
		var can := points > 0
		var plate := Rect2(cx0 + 10.0, y0 + ch - 50.0, cw - 20.0, 40.0)
		var bg := Color(0.16, 0.22, 0.13, 0.9) if can else Color(0.10, 0.07, 0.08, 0.7)
		var line := Color(0.55, 0.85, 0.5, 0.55) if can else Color(0.6, 0.5, 0.45, 0.3)
		draw_rect(plate, bg)
		draw_rect(plate, line, false, 1.0)
		draw_keycap(font, plate.position.x + 8.0, plate.position.y + 10.5, String(st[3]))
		draw_string(font, Vector2(plate.position.x, plate.position.y + 26.0), "+1" if can else "invest",
			HORIZONTAL_ALIGNMENT_RIGHT, plate.size.x - 12.0, 15, Color(0.78, 0.96, 0.72) if can else Color(0.6, 0.55, 0.5, 0.8))

	# ---------------- stamina: a resource, not a stat ----------------
	var sy := y0 + ch + 34.0
	draw_string(font, Vector2(tx, sy), "STAMINA", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.8, 0.9, 0.85))
	var sbx := tx + 130.0
	var sbw := innerw - 260.0
	var sfrac := clampf(stamina / maxf(1.0, stamina_max), 0.0, 1.0)
	draw_rect(Rect2(sbx, sy - 12.0, sbw, 14.0), Color(0.2, 0.14, 0.11, 0.8))
	draw_rect(Rect2(sbx, sy - 12.0, sbw * sfrac, 14.0), Color(0.55, 0.80, 0.6))
	draw_string(font, Vector2(sbx + sbw + 14.0, sy), "%d / %d" % [int(round(stamina)), int(stamina_max)], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.85, 0.9, 0.85))
	draw_string(font, Vector2(tx, sy + 20.0), "drains as you play; meals and sleep bring it back. Empty hands catch nothing.", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.75, 0.68, 0.6))

	var by := py + ph - 32.0
	if debug_mode:
		draw_string(font, Vector2(tx, by), "DEBUG  1/2/3/4 up  Q/W/E/R dn  M/N gold  ,/. rep", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.6, 0.9, 1.0))
	var sh_items: Array = [[["Stick"] if pad_active() else ["Left", "Right"], "choose"]]
	if points > 0:
		sh_items.append([k_finish(), "invest"])
	sh_items.append([k_sheet(), "resume"])
	draw_hints_row(font, px + pw * 0.5, by - 14.0, sh_items)


func draw_purse(font: Font, right_x: float, y: float) -> void:
	# the gold readout every spending screen shares: a coin, the number, and a flash
	# whenever gold just changed hands (paired with the "money" jingle)
	var fl := clampf(1.0 - float(int(Time.get_ticks_msec()) - shop_buy_ms) / 450.0, 0.0, 1.0)
	var fs := 24 + int(round(6.0 * fl))
	var gc := Color(1.0, 0.86, 0.45).lerp(Color(1.0, 0.98, 0.85), fl)
	var txt := "%s g" % commafy(money)
	var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_circle(Vector2(right_x - tw - 22.0, y - 8.0), 9.0, Color(1.0, 0.84, 0.4))
	draw_circle(Vector2(right_x - tw - 25.0, y - 11.0), 3.0, Color(1.0, 0.95, 0.7))
	draw_string(font, Vector2(right_x - tw, y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, gc)


func draw_price_plate(font: Font, r: Rect2, keylabel: String, price: String, afford: bool) -> void:
	# the buy strip at the foot of a shop card: the KEY on the left is the button, the
	# price on the right is the ask. Green means it can happen, dim red means not yet.
	var bg := Color(0.16, 0.22, 0.13, 0.9) if afford else Color(0.16, 0.09, 0.09, 0.85)
	var line := Color(0.55, 0.85, 0.5, 0.55) if afford else Color(0.7, 0.35, 0.3, 0.4)
	var cc := Color(0.78, 0.96, 0.72) if afford else Color(0.85, 0.5, 0.45)
	draw_rect(r, bg)
	draw_rect(r, line, false, 1.0)
	draw_keycap(font, r.position.x + 8.0, r.position.y + r.size.y * 0.5 - 9.5, keylabel)
	draw_string(font, Vector2(r.position.x, r.position.y + r.size.y * 0.5 + 6.0), price,
		HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 12.0, 16, cc)


#endregion

#region SHOP SCREEN
func draw_shop(font: Font, s: Vector2) -> void:
	# the SHOP, dealt as CARDS (Louis: Balatro look - big cards, clean zones, the buy
	# key printed on every card). One zone of five prop cards, one zone of gear, the
	# purse always big top-right.
	draw_rect(Rect2(0, 0, s.x, s.y), Color(0.04, 0.02, 0.03, 0.88))
	var pw := minf(1120.0, s.x - 60.0)
	var ph := 648.0
	var px := s.x * 0.5 - pw * 0.5
	var py := s.y * 0.5 - ph * 0.5
	draw_rect(Rect2(px, py, pw, ph), Color(0.10, 0.06, 0.075, 0.98))
	draw_rect(Rect2(px, py, pw, ph), Color(0.9, 0.6, 0.35, 0.5), false, 2.0)

	var tx := px + 40.0
	var innerw := pw - 80.0
	draw_string(font, Vector2(tx, py + 52.0), "SHOP", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color(1.0, 0.86, 0.55))
	draw_string(font, Vector2(tx + 118.0, py + 50.0), "to juggle N of a prop, own N of them", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.75, 0.68, 0.6))
	draw_purse(font, px + pw - 40.0, py + 52.0)

	# ---------------- PROPS: six big cards in one row ----------------
	draw_string(font, Vector2(tx, py + 96.0), "PROPS", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.95, 0.8, 0.55, 0.9))
	var gap := 14.0
	var cw := (innerw - gap * 5.0) / 6.0
	var ch := 272.0
	var y0 := py + 110.0
	var sel_a := 0.55 + 0.35 * sin(float(Time.get_ticks_msec()) * 0.006)
	for i in PROPS.size():   # balls included: every prop is bought stock now (Louis)
		var cx0 := tx + float(i) * (cw + gap)
		var pcol := prop_color(i)
		var cost := int(PROPS[i]["cost"])
		var afford := money >= cost
		hud_card(Rect2(cx0, y0, cw, ch), Color(pcol.r, pcol.g, pcol.b, 0.45))
		if i == shop_sel:
			# the card cursor (see shop_input): Enter / pad A buys the lit card
			draw_rect(Rect2(cx0 - 4.0, y0 - 4.0, cw + 8.0, ch + 8.0), Color(1.0, 0.86, 0.45, sel_a), false, 2.5)
		var own := prop_count[i]
		var oc := Color(0.75, 0.9, 0.72) if own > 0 else Color(0.6, 0.55, 0.5, 0.8)
		draw_string(font, Vector2(cx0 + 12.0, y0 + 24.0), "own %d" % own, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, oc)
		if available(i):
			draw_string(font, Vector2(cx0, y0 + 24.0), "ready", HORIZONTAL_ALIGNMENT_RIGHT, cw - 12.0, 12, Color(0.6, 0.9, 0.62))
		draw_prop_icon(i, Vector2(cx0 + cw * 0.5, y0 + 92.0), 2.6)
		draw_string(font, Vector2(cx0, y0 + 158.0), String(PROPS[i]["name"]), HORIZONTAL_ALIGNMENT_CENTER, cw, 19, Color(1.0, 0.88, 0.6))
		var req := int(PROPS[i]["req"])
		draw_string(font, Vector2(cx0, y0 + 180.0), "weight %d" % int(PROPS[i]["weight"]), HORIZONTAL_ALIGNMENT_CENTER, cw, 11, Color(0.75, 0.68, 0.6))
		var reqline := "easy to throw" if req == 0 else "clean at Strength %d" % req
		if i == PROP_EGGS:
			reqline = "breaks on a drop"
		var reqcol := Color(0.75, 0.68, 0.6)
		if req > strength:
			reqcol = Color(0.95, 0.6, 0.45)   # under-strength: flag it before the buy
		draw_string(font, Vector2(cx0, y0 + 196.0), reqline, HORIZONTAL_ALIGNMENT_CENTER, cw, 11, reqcol)
		draw_price_plate(font, Rect2(cx0 + 10.0, y0 + ch - 50.0, cw - 20.0, 40.0), str(i + 1), "%s g" % commafy(cost), afford)

	# ---------------- GEAR: three narrow cards (2026-07-18: was two wide cards,
	# grew a third slot for the Glow-in-the-Dark Kit - a wide horizontal layout
	# had no room left for a third item's description, so gear now uses the same
	# narrow vertical template the prop cards above already prove works) ----------------
	var gy := y0 + ch + 30.0
	draw_string(font, Vector2(tx, gy), "GEAR", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.95, 0.8, 0.55, 0.9))
	var gw := (innerw - gap * 2.0) / 3.0
	var gh := 160.0
	var gy0 := gy + 14.0
	var gear_names: Array[String] = ["Glasses", "Uncle Dan's Pie", "Glow-in-the-Dark Kit"]
	var gear_desc: Array[String] = ["a better chance on off-Perfect catches",
		"a whole day of slow, clear time", "props keep a faint glow through Blackout"]
	var gear_accent := [Color(0.72, 0.86, 0.96), Color(0.9, 0.62, 0.3), Color(0.65, 0.95, 0.55)]
	var gear_owned := [has_glasses, false, has_glow_kit]
	var gear_count := [0, pie_count, 0]     # only the Pie is a stock item
	var gear_cost := [GLASSES_COST, PIE_COST, GLOW_KIT_COST]
	for i in 3:
		var cx0 := tx + float(i) * (gw + gap)
		var cc: Color = gear_accent[i]
		hud_card(Rect2(cx0, gy0, gw, gh), Color(cc.r, cc.g, cc.b, 0.4))
		if shop_sel == 6 + i:
			draw_rect(Rect2(cx0 - 4.0, gy0 - 4.0, gw + 8.0, gh + 8.0), Color(1.0, 0.86, 0.45, sel_a), false, 2.5)
		var icx := cx0 + gw * 0.5
		match i:
			0:   # Glasses: two lens arcs and a bridge
				draw_arc(Vector2(icx - 14.0, gy0 + 40.0), 12.0, 0.0, TAU, 20, cc, 2.5, true)
				draw_arc(Vector2(icx + 14.0, gy0 + 40.0), 12.0, 0.0, TAU, 20, cc, 2.5, true)
				draw_line(Vector2(icx - 2.0, gy0 + 40.0), Vector2(icx + 2.0, gy0 + 40.0), cc, 2.5)
			1:   # Pie: a wedge with a crust line
				draw_colored_polygon(PackedVector2Array([
					Vector2(icx - 22.0, gy0 + 52.0), Vector2(icx + 22.0, gy0 + 52.0), Vector2(icx, gy0 + 24.0)]), cc)
				draw_line(Vector2(icx - 22.0, gy0 + 52.0), Vector2(icx + 22.0, gy0 + 52.0), Color(0.6, 0.36, 0.16), 4.0)
			_:   # Glow Kit: the exact halo it buys, so the card IS a preview
				draw_circle(Vector2(icx, gy0 + 40.0), 15.0, Color(cc.r, cc.g, cc.b, 0.22))
				draw_circle(Vector2(icx, gy0 + 40.0), 8.0, Color(cc.r, cc.g, cc.b, 0.6))
				draw_circle(Vector2(icx, gy0 + 40.0), 2.5, Color(1.0, 1.0, 1.0, 0.8))
		draw_string(font, Vector2(cx0, gy0 + 74.0), gear_names[i], HORIZONTAL_ALIGNMENT_CENTER, gw, 17, Color(1.0, 0.88, 0.6))
		_wrap_text(font, gear_desc[i], cx0 + 10.0, gy0 + 94.0, gw - 20.0, 11, Color(0.75, 0.68, 0.6))
		if bool(gear_owned[i]):
			draw_string(font, Vector2(cx0, gy0 + gh - 30.0), "OWNED", HORIZONTAL_ALIGNMENT_CENTER, gw, 16, Color(0.6, 0.9, 0.6))
		else:
			if int(gear_count[i]) > 0:
				draw_string(font, Vector2(cx0, gy0 + 18.0), "own %d" % int(gear_count[i]), HORIZONTAL_ALIGNMENT_RIGHT, gw - 14.0, 12, Color(0.75, 0.9, 0.72))
			draw_price_plate(font, Rect2(cx0 + 12.0, gy0 + gh - 46.0, gw - 24.0, 38.0), str(7 + i), "%s g" % commafy(int(gear_cost[i])), money >= int(gear_cost[i]))

	# ---------------- footer: warnings, then the keys ----------------
	if shop_msg != "" and int(Time.get_ticks_msec()) - shop_msg_ms < 5000:
		draw_string(font, Vector2(px, py + ph - 58.0), shop_msg, HORIZONTAL_ALIGNMENT_CENTER, pw, 13, Color(1.0, 0.62, 0.45))
	if pad_active():
		draw_hints_row(font, px + pw * 0.5, py + ph - 40.0,
			[[["Stick"], "choose"], [k_finish(), "buy"], [k_sheet(), "leave"]])
	else:
		draw_hints_row(font, px + pw * 0.5, py + ph - 40.0,
			[[["Left", "Right"], "choose"], [["Enter"], "buy"], [["1", "9"], "quick buy"], [["Tab"], "leave"]])


#endregion

#region SKILLS SCREEN
func _skills_row(font: Font, x: float, y: float, w: float, ename: String, req: Dictionary, unlocked: bool, sel: bool) -> void:
	# one entry in the Skills reference: name on the left, a ready / gate badge
	# on the right, and a soft highlight when it is the selected entry. The badge
	# stays short (the level, plus a + when stats or a stage are also asked);
	# the detail strip below spells the full requirement out.
	if sel:
		draw_rect(Rect2(x - 12.0, y - 23.0, w, 38.0), Color(1.0, 0.85, 0.45, 0.10))
		draw_rect(Rect2(x - 12.0, y - 23.0, w, 38.0), Color(1.0, 0.85, 0.45, 0.35), false, 1.0)
	var nc := Color(1.0, 0.9, 0.6) if sel else (Color(0.86, 0.8, 0.68) if unlocked else Color(0.55, 0.5, 0.46))
	draw_string(font, Vector2(x, y), ename, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, nc)
	if unlocked:
		draw_string(font, Vector2(x + w - 76.0, y), "ready", HORIZONTAL_ALIGNMENT_RIGHT, 64.0, 12, Color(0.6, 0.9, 0.62))
	else:
		var more: bool = int(req.get("str", 0)) > 0 or int(req.get("acc", 0)) > 0 or int(req.get("ven", 0)) > 0
		draw_string(font, Vector2(x + w - 76.0, y), "Lv %d%s" % [int(req["lvl"]), "+" if more else ""], HORIZONTAL_ALIGNMENT_RIGHT, 64.0, 12, Color(0.72, 0.62, 0.5))


# --- pattern preview (Skills screen): a small self-looping schematic, not a real
# sim. Each dot follows the pattern's ACTUAL inner/outer hand geometry (see
# inner_pos/outer_pos) and the same relative height ordering do_throw uses (a
# low/fast feed < a plain weave < an over-the-top launch), just scaled to fit a
# small box and driven by atick() instead of player input - so it reads as
# THIS pattern, not a generic bouncing-ball loop. It does not touch the real
# `balls` / `pattern` state, so it is safe to animate from any screen.
const PREV_OUTER_DX := 34.0   # local-space stand-in for outer_pos's 100px reach
const PREV_INNER_DX := 18.0   # keeps outer_pos:inner_pos's ~100:54 ratio, scaled down
const PREV_ARC_SCALE := 46.0  # px of peak arc height per 1.0 of a leg's "height" units

func preview_hand_point(is_outer: bool, hand: int) -> Vector2:
	var dx := PREV_OUTER_DX if is_outer else PREV_INNER_DX
	return Vector2(-dx if hand == LEFT else dx, 0.0)


# one pattern's choreography as a list of [legs, ball_count] tracks. Every ball on a
# track runs the SAME repeating leg cycle, spread evenly across its total duration -
# the trick that turns one throw-catch cycle into a continuous multi-ball loop (a real
# 3-ball cascade is one L->R/R->L cycle with 3 balls a third of a cycle apart). A leg is
# [from_outer, from_hand, to_outer, to_hand, height, duration]; height/duration are
# preview-only units, but their ORDER mirrors the real constants: SHOWER_FEED-style
# low feeds are short and flat, a plain weave is the baseline, and an over-the-top leg
# (OVER_TOP_MIN / SHOWER_MIN / HALFSHOWER_MIN / WATERFALL_HIGH territory) is the
# tallest and longest-hanging.
func pattern_preview_tracks(p: int) -> Array:
	var plain_weave := [[false, LEFT, true, RIGHT, 1.0, 0.42], [false, RIGHT, true, LEFT, 1.0, 0.42]]
	match p:
		FOUNTAIN:
			# each hand keeps its own ball, an out-and-back loop with no crossing -
			# literally "its own circle", per the pattern's own description
			return [[[[false, LEFT, true, LEFT, 0.9, 0.4], [true, LEFT, false, LEFT, 0.9, 0.4]], 1],
					[[[false, RIGHT, true, RIGHT, 0.9, 0.4], [true, RIGHT, false, RIGHT, 0.9, 0.4]], 1]]
		COLUMNS:
			# a degenerate from==to leg: the real flight parabola alone (flight_pos)
			# already draws a straight vertical bounce when the endpoints match
			return [[[[false, LEFT, false, LEFT, 1.1, 0.5]], 1],
					[[[false, RIGHT, false, RIGHT, 1.1, 0.5]], 1]]
		HALFSHOWER:
			# left keeps the plain weave, right is fixed on the over-the-top road
			return [[[[false, LEFT, true, RIGHT, 1.0, 0.42], [true, RIGHT, true, LEFT, 1.6, 0.6]], 3]]
		SHOWER:
			# left is a fast low feed (SHOWER_FEED), right rides the full high circle
			return [[[[false, LEFT, true, RIGHT, 0.5, 0.28], [true, RIGHT, true, LEFT, 1.7, 0.62]], 3]]
		RCASC:
			# both hands fixed over-the-top: the weave runs backward, outer to outer
			return [[[[true, LEFT, true, RIGHT, 1.6, 0.6], [true, RIGHT, true, LEFT, 1.6, 0.6]], 3]]
		WFALL:
			# right fixed high over-the-top, left capped low so it flows beneath it
			return [[[[false, LEFT, true, RIGHT, 0.35, 0.3], [true, RIGHT, true, LEFT, 1.8, 0.64]], 3]]
		TENNIS:
			# two balls run the plain weave; the third (its own track) is the one
			# marked ball, over-the-top on every throw regardless of which hand
			return [[plain_weave, 2], [[[true, LEFT, true, RIGHT, 1.6, 0.6], [true, RIGHT, true, LEFT, 1.6, 0.6]], 1]]
		_:
			return [[plain_weave, 3]]   # CASCADE, and a safe fallback for anything new


func pattern_preview_ball_pos(legs: Array, tsec: float) -> Vector2:
	var total := 0.0
	for leg in legs:
		total += float(leg[5])
	if total <= 0.0:
		return Vector2.ZERO
	var tloop := fmod(tsec, total)
	var acc := 0.0
	for idx in legs.size():
		var leg: Array = legs[idx]
		var dur: float = leg[5]
		if idx == legs.size() - 1 or tloop < acc + dur:
			var p := clampf((tloop - acc) / dur, 0.0, 1.0)
			var from_pt := preview_hand_point(bool(leg[0]), int(leg[1]))
			var to_pt := preview_hand_point(bool(leg[2]), int(leg[3]))
			var pos := from_pt.lerp(to_pt, p)
			pos.y -= 4.0 * float(leg[4]) * PREV_ARC_SCALE * p * (1.0 - p)   # flight_pos's own parabola, rescaled
			return pos
		acc += dur
	return Vector2.ZERO


func draw_pattern_preview(font: Font, box: Rect2, p: int) -> void:
	draw_rect(box, Color(0.08, 0.05, 0.06, 0.75))
	draw_rect(box, Color(0.9, 0.6, 0.35, 0.3), false, 1.0)
	draw_string(font, box.position + Vector2(10.0, 16.0), "PREVIEW", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.75, 0.68, 0.58, 0.8))
	var origin := box.position + Vector2(box.size.x * 0.5, box.size.y * 0.58)
	var t := atick() / 120.0
	var ball_i := 0
	var tracks := pattern_preview_tracks(p)
	for ti in tracks.size():
		var legs: Array = tracks[ti][0]
		var n: int = tracks[ti][1]
		var total := 0.0
		for leg in legs:
			total += float(leg[5])
		# Tennis's second track is the one MARKED ball - it gets its own colour
		# (gold) rather than the shared rotation, same as the real marked ball
		var marked := p == TENNIS and ti == 1
		for i in n:
			var phase := t + total * float(i) / float(n)
			var pos := origin + pattern_preview_ball_pos(legs, phase)
			draw_circle(pos, 6.0, Color(1.0, 0.85, 0.3) if marked else ball_color(ball_i))
			ball_i += 1
	draw_string(font, origin + Vector2(-PREV_OUTER_DX - 10.0, 30.0), "L", HORIZONTAL_ALIGNMENT_CENTER, 20.0, 11, Color(0.6, 0.55, 0.5))
	draw_string(font, origin + Vector2(PREV_OUTER_DX - 10.0, 30.0), "R", HORIZONTAL_ALIGNMENT_CENTER, 20.0, 11, Color(0.6, 0.55, 0.5))


func draw_skills(font: Font, s: Vector2) -> void:
	# the Skills reference: every trick and pattern, whether it is yours yet, and
	# the exact keys that pull it off. This is where the trimmed unlock toast now
	# sends the player to learn the how, so a live run is never buried in text.
	draw_rect(Rect2(0, 0, s.x, s.y), Color(0.04, 0.02, 0.03, 0.86))
	var pw := 904.0
	var ph := 626.0
	var px := s.x * 0.5 - pw * 0.5
	var py := s.y * 0.5 - ph * 0.5
	draw_rect(Rect2(px, py, pw, ph), Color(0.12, 0.07, 0.08, 0.98))
	draw_rect(Rect2(px, py, pw, ph), Color(0.9, 0.6, 0.35, 0.5), false, 2.0)

	var kc_use := k_trick()[0]
	var kc_sel := k_cycle()[0]
	draw_string(font, Vector2(px + 40.0, py + 48.0), "SKILLS", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1.0, 0.86, 0.55))
	draw_string(font, Vector2(px + 40.0, py + 74.0), "%s cycles which skill is loaded   -   %s uses it   -   patterns switch with P while you practise" % [kc_sel, kc_use], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.82, 0.75, 0.64))
	draw_string(font, Vector2(px + pw - 210.0, py + 48.0), "Level %d" % level, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1.0, 0.9, 0.6))

	var nt := TRICKS.size()
	var col_l := px + 40.0
	var col_r := px + pw * 0.52
	var colw := pw * 0.44
	var row_h := 46.0
	var y0 := py + 132.0
	# the headers sit well ABOVE the first row so the selection highlight (which
	# reaches ~23px above a row's baseline) never touches the TRICKS / PATTERNS label
	draw_string(font, Vector2(col_l, y0 - 42.0), "TRICKS", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.95, 0.8, 0.55, 0.9))
	draw_string(font, Vector2(col_r, y0 - 42.0), "PATTERNS", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.95, 0.8, 0.55, 0.9))
	for i in nt:
		var td: Dictionary = TRICKS[i]
		_skills_row(font, col_l, y0 + float(i) * row_h, colw, String(td["name"]), td, trick_unlocked(i), i == skills_sel)
	# patterns list in UNLOCK order (pattern_order), not raw array order: the raw
	# indices are frozen for old saves, so the tidy career ladder is sorted here
	var pord := pattern_order()
	for j in pord.size():
		var pd: Dictionary = PATTERNS[pord[j]]
		_skills_row(font, col_r, y0 + float(j) * row_h, colw, String(pd["name"]), pd, pattern_unlocked(pord[j]), (nt + j) == skills_sel)

	# a pattern's preview lives under the (always shorter) TRICKS list, in the
	# left column's own empty space - it never has to fight the PATTERNS list
	# (which is the taller of the two) for room, and the offset is derived from
	# nt/row_h rather than hardcoded, so it stays clear if TRICKS ever grows
	if skills_sel >= nt:
		var pbox_w := 168.0
		var pbox_h := 132.0
		var pbox_x := col_l + (colw - pbox_w) * 0.5
		var pbox_y := y0 + float(nt) * row_h + 20.0
		draw_pattern_preview(font, Rect2(pbox_x, pbox_y, pbox_w, pbox_h), pattern_order()[skills_sel - nt])

	# the detail strip: the selected entry explained, with its exact controls
	var dy := py + ph - 118.0
	draw_rect(Rect2(px + 30.0, dy - 6.0, pw - 60.0, 80.0), Color(0.08, 0.05, 0.06, 0.7))
	draw_rect(Rect2(px + 30.0, dy - 6.0, pw - 60.0, 80.0), Color(0.9, 0.6, 0.35, 0.28), false, 1.0)
	var ename := ""
	var how := ""
	var desc := ""
	var req_line := ""
	var is_unlocked := true
	if skills_sel < nt:
		var td2: Dictionary = TRICKS[skills_sel]
		ename = String(td2["name"])
		desc = String(td2["desc"])
		req_line = skill_req_text(td2)
		is_unlocked = trick_unlocked(skills_sel)
		match String(td2["kind"]):
			"live":
				how = "%s loads it, then %s spins while %d or more are airborne. Catches score double while you spin blind." % [kc_sel, kc_use, int(td2["min_air"])]
			"toggle":
				how = "%s loads it, then %s switches it on, %s again switches it off. It reshapes every throw between." % [kc_sel, kc_use, kc_use]
			_:
				how = "%s loads it, then %s powers your NEXT throw. One press, one trick." % [kc_sel, kc_use]
	else:
		var pd2: Dictionary = PATTERNS[pattern_order()[skills_sel - nt]]
		ename = String(pd2["name"])
		desc = String(pd2["desc"])
		req_line = skill_req_text(pd2)
		is_unlocked = pattern_unlocked(pattern_order()[skills_sel - nt])
		how = "In practice, press P to switch patterns. Score multiplier x%.2f at your CURRENT load (x%.2f base - more balls and heavier props push it higher still). Cascade and Fountain also match the ball count." % [float(pd2["mult"]) * object_mult(), float(pd2["mult"])]
	draw_string(font, Vector2(px + 46.0, dy + 18.0), ename.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color(1.0, 0.88, 0.55) if is_unlocked else Color(0.72, 0.62, 0.55))
	if not is_unlocked:
		# the full requirement, right-aligned so a long ask (level + stat + stage)
		# never collides with the name on the left
		draw_string(font, Vector2(px + pw - 490.0, dy + 18.0), "asks for %s" % req_line, HORIZONTAL_ALIGNMENT_RIGHT, 444.0, 13, Color(0.85, 0.62, 0.5))
	draw_string(font, Vector2(px + 46.0, dy + 42.0), how, HORIZONTAL_ALIGNMENT_LEFT, pw - 92.0, 13, Color(0.9, 0.82, 0.66))
	draw_string(font, Vector2(px + 46.0, dy + 62.0), desc, HORIZONTAL_ALIGNMENT_LEFT, pw - 92.0, 13, Color(0.78, 0.72, 0.64))

	var foot := "arrows browse      Enter  practise this skill      Esc to leave"
	if not is_unlocked:
		foot = "arrows browse      Esc to leave      (this one is still locked)"
	draw_string(font, Vector2(px, py + ph - 22.0), foot, HORIZONTAL_ALIGNMENT_CENTER, pw, 13, Color(0.74, 0.68, 0.6))


# -----------------------------------------------------------------------------
# Menu, save-slot, settings, and misc screens.
# -----------------------------------------------------------------------------

#endregion

#region DAY HUB SCREEN
func draw_day(font: Font, s: Vector2) -> void:
	# the day hub: the chosen venue's exterior breathes behind a veil while the
	# day's ledger and actions sit over it. The world is where you will play
	# tonight, which makes choosing a stage feel like standing in front of it.
	ext_center = true    # the stage's picture is the hub's centrepiece
	draw_venue_exterior(s, play_venue())
	ext_center = false
	# the hub darkens as the day's segments burn: DAY is open, NIGHT draws in,
	# DEEP NIGHT is nearly black and plainly the moment to sleep. seg_used runs
	# 0..SEG_PER_DAY (4 values for 3 named phases, see seg_name): the 4th entry
	# is "all segments spent", which just repeats DEEP NIGHT's darkness rather
	# than going darker still - there is nowhere further for the hub to dim to.
	var seg_dark: float = [0.0, 0.16, 0.32, 0.32][clampi(seg_used, 0, 3)]
	if seg_dark > 0.0:
		draw_rect(Rect2(0, 0, s.x, s.y), Color(0.01, 0.01, 0.04, seg_dark))
	draw_rect(Rect2(0, 0, s.x, s.y), Color(0.03, 0.02, 0.03, 0.52))
	draw_vignette(s, 0.55)
	draw_frame(s, 22.0, Color(0.82, 0.62, 0.34, 0.5))

	# header: which day it is, and how much of it is left told two ways below -
	# the seg_name() label (daylight / night / deep night) and the hub's own
	# background darkening (seg_dark, just above); the ornament here is only the
	# plain divider used under every screen title, not a segment counter
	draw_title_glow(font, s.y * 0.055, "DAY %d" % day, 40, Color(1.0, 0.88, 0.5), s)
	draw_string(font, Vector2(0, s.y * 0.055 + 66.0), seg_name(), HORIZONTAL_ALIGNMENT_CENTER, s.x, 17, Color(0.9, 0.8, 0.62))
	draw_ornament(s.x * 0.5, s.y * 0.055 + 86.0, 170.0, Color(0.82, 0.62, 0.34, 0.85))
	# under the clock: what actually limits the day, said plainly (Louis: it was
	# unclear when and why the day was spent)
	var limit_line := "you can work while stamina lasts"
	if too_tired():
		limit_line = "stamina is spent  -  sleep to start tomorrow"
	draw_string(font, Vector2(0, s.y * 0.055 + 112.0), limit_line, HORIZONTAL_ALIGNMENT_CENTER, s.x, 13, Color(1.0, 0.7, 0.5, 0.95) if too_tired() else Color(0.72, 0.68, 0.6, 0.9))

	# the ledger card: purse, reputation, stamina, and the road to the next meal
	# bonus. It sits high on the left so the stage picture keeps the middle.
	var lw := 300.0
	var lx := 40.0
	var ly := s.y * 0.175
	hud_panel(Rect2(lx, ly, lw, 168.0))
	draw_circle(Vector2(lx + 26.0, ly + 30.0), 7.0, Color(1.0, 0.84, 0.4))
	draw_circle(Vector2(lx + 23.0, ly + 27.0), 2.4, Color(1.0, 0.95, 0.7))
	draw_string(font, Vector2(lx + 42.0, ly + 37.0), "%s gold" % commafy(money), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1.0, 0.86, 0.45))
	draw_string(font, Vector2(lx + 20.0, ly + 64.0), "Rep %s   %s" % [commafy(reputation), rep_tier()], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.82, 0.72, 0.85))
	var sfrac := clampf(stamina / maxf(1.0, stamina_max), 0.0, 1.0)
	draw_string(font, Vector2(lx + 20.0, ly + 92.0), "STAMINA", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.85, 0.9, 0.85, 0.85))
	draw_string(font, Vector2(lx + lw - 90.0, ly + 92.0), "%d / %d" % [int(round(stamina)), int(stamina_max)], HORIZONTAL_ALIGNMENT_RIGHT, 70.0, 12, Color(0.85, 0.9, 0.85, 0.85))
	draw_rect(Rect2(lx + 20.0, ly + 100.0, lw - 40.0, 12.0), Color(0.2, 0.14, 0.11, 0.7))
	var scol := Color(0.55, 0.80, 0.6)
	if sfrac < STAM_LOW:
		scol = scol.lerp(Color(0.95, 0.35, 0.25), clampf((STAM_LOW - sfrac) / STAM_LOW, 0.0, 1.0))
	draw_rect(Rect2(lx + 20.0, ly + 100.0, (lw - 40.0) * sfrac, 12.0), scol)
	if sfrac < STAM_LOW:
		draw_string(font, Vector2(lx + 20.0, ly + 130.0), "worn out  -  throws are getting wild", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.6, 0.45))
	else:
		draw_string(font, Vector2(lx + 20.0, ly + 130.0), "rested enough to work", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.72, 0.68, 0.6))
	var to_str := MEALS_PER_STR - (meals % MEALS_PER_STR)
	draw_string(font, Vector2(lx + 20.0, ly + 152.0), "%d meal%s to the next point of Strength" % [to_str, "" if to_str == 1 else "s"], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.72, 0.68, 0.6))

	# the actions: a compact column on the RIGHT edge, off the stage picture
	# (they used to sprawl across the middle and covered the venue's marquee)
	var rows := day_rows()
	var aw := 348.0
	var ax := s.x - aw - 44.0
	var ay := s.y * 0.285
	for i in rows.size():
		var r: Dictionary = rows[i]
		var sel := i == day_sel
		var ok := bool(r["ok"])
		var ry := ay + float(i) * 44.0
		if sel:
			hud_panel(Rect2(ax - 14.0, ry - 21.0, aw, 40.0), true)
		var name_c := Color(1.0, 0.9, 0.6) if sel else Color(0.8, 0.74, 0.66)
		if not ok:
			name_c = Color(0.55, 0.5, 0.46)
		var label := String(r["name"])
		if String(r["id"]) == "perform":
			# the stage picker lives ON this row: arrows show which way it can
			# still move (left to right along the ladder, never wrapping). The
			# PURIST mark sits under the cost, never inside the name (it used to
			# run into the "1 segment" text on long venue names).
			# arrows wrap the venue NAME, so PERFORM always starts flush with the
			# other rows (a leading arrow pad used to indent the whole row)
			var pv := play_venue()
			var lar := "<  " if pv > 0 else ""
			var rar := "  >" if pv < venue_index() else ""
			label = "PERFORM  at  %s%s%s" % [lar, String(venue_data(pv)["name"]), rar]
			if purist:
				draw_string(font, Vector2(ax + aw - 118.0, ry + 15.0), "PURIST", HORIZONTAL_ALIGNMENT_RIGHT, 90.0, 11, Color(0.82, 0.72, 0.85))
		draw_string(font, Vector2(ax, ry), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, name_c)
		var cost := String(r["cost"])
		if cost != "":
			var cc := Color(0.85, 0.75, 0.58, 0.9) if ok else Color(0.55, 0.5, 0.46)
			draw_string(font, Vector2(ax + aw - 118.0, ry), cost, HORIZONTAL_ALIGNMENT_RIGHT, 90.0, 13, cc)

	# under the list: the selected action explains itself, and the perform row
	# adds its live chase and how the NEXT stage opens. The block sits on its own
	# card (same footprint as the row highlight): drawn bare it fought the fence
	# pickets and the sun glow of the exterior behind it. Long subs (the inn's,
	# the pie's) wrap inside the card instead of clipping at its edge.
	var selr: Dictionary = rows[day_sel]
	var suby := ay + float(rows.size()) * 44.0 + 2.0
	var sub_text := String(selr["sub"])
	var sub_w := aw - 28.0
	var sub_h := font.get_multiline_string_size(sub_text, HORIZONTAL_ALIGNMENT_LEFT, sub_w, 13, 2).y
	var is_perf := String(selr["id"]) == "perform"
	var nxt := next_venue_rep()
	var block_h := 8.0 + sub_h + 10.0
	if is_perf:
		block_h += 26.0 + (20.0 if nxt > 0 else 0.0)
	hud_panel(Rect2(ax - 14.0, suby, aw, block_h))
	draw_multiline_string(font, Vector2(ax, suby + 8.0 + font.get_ascent(13)), sub_text,
		HORIZONTAL_ALIGNMENT_LEFT, sub_w, 13, 2, Color(0.85, 0.78, 0.66))
	if is_perf:
		var vi := play_venue()
		var chase := "no record here yet  -  set one"
		if vi >= 0 and vi < rec_table().size() and rec_table()[vi] > 0:
			chase = "record to beat   %d" % rec_table()[vi]
		var cy := suby + 8.0 + sub_h + 24.0
		draw_string(font, Vector2(ax, cy), chase, HORIZONTAL_ALIGNMENT_LEFT, sub_w, 13, Color(0.96, 0.83, 0.52, 0.9))
		if nxt > 0:
			draw_string(font, Vector2(ax, cy + 20.0), "the next stage opens at Rep %d  (you have %d)" % [nxt, reputation], HORIZONTAL_ALIGNMENT_LEFT, sub_w, 13, Color(0.82, 0.72, 0.85, 0.9))

	# transient feedback (a meal eaten, a spent day) fades after a few seconds
	if day_msg != "" and cine_tick - day_msg_tick < 300:
		var ma := clampf(1.0 - float(cine_tick - day_msg_tick - 220) / 80.0, 0.0, 1.0)
		draw_string(font, Vector2(0, s.y - 92.0), day_msg, HORIZONTAL_ALIGNMENT_CENTER, s.x, 16, Color(1.0, 0.88, 0.55, ma))

	if pad_active():
		draw_hints_row(font, s.x * 0.5, s.y - 52.0, [
			[["Stick"], "choose"], [k_finish(), "do it"], [k_sheet(), "sheet"], [k_pause(), "menu"]])
	else:
		draw_hints_row(font, s.x * 0.5, s.y - 52.0, [
			[["Up", "Down"], "choose"], [["Enter"], "do it"], [["Tab"], "sheet"], [["Esc"], "menu"]])

	if day_anim != "":
		draw_day_anim(font, s)


func draw_day_anim(font: Font, s: Vector2) -> void:
	# the hub's little vignettes: a beat of picture before the ledger moves, so
	# eating, sleeping and shopping feel like moments instead of button presses
	var t := float(cine_tick - day_anim_start) / float(day_anim_len(day_anim))
	t = clampf(t, 0.0, 1.0)
	var ease_in := minf(t * 5.0, 1.0)
	match day_anim:
		"eat":
			var c := Vector2(s.x * 0.5, s.y * 0.52)
			hud_panel(Rect2(c.x - 170.0, c.y - 110.0, 340.0, 210.0))
			# the bowl, and a spoon that dips twice
			fill_ellipse(c + Vector2(0, 30.0), 74.0, 30.0, Color(0.55, 0.34, 0.2))
			fill_ellipse(c + Vector2(0, 22.0), 62.0, 18.0, Color(0.93, 0.72, 0.4))
			var dip := absf(sin(t * TAU * 2.0)) * 18.0
			draw_capsule(c + Vector2(44.0, -34.0 + dip), c + Vector2(58.0, -2.0 + dip), 5.0, 8.0, Color(0.8, 0.78, 0.75))
			# steam: three slow wisps climbing off the soup
			for w in 3:
				var wx := c.x - 30.0 + 30.0 * float(w)
				var pts := PackedVector2Array()
				for k in 9:
					var f := float(k) / 8.0
					pts.append(Vector2(wx + sin(f * 5.0 + t * 9.0 + float(w) * 2.0) * 7.0, c.y + 4.0 - f * (46.0 + 20.0 * t)))
				draw_polyline(pts, Color(1.0, 0.97, 0.9, 0.35 * ease_in * (1.0 - t * 0.5)), 2.5)
			draw_string(font, Vector2(c.x - 170.0, c.y + 82.0), "a hot meal", HORIZONTAL_ALIGNMENT_CENTER, 340.0, 16, Color(1.0, 0.9, 0.65, ease_in))
		"inn":
			# the world dims to sleep, a lit window and drifting z's carry it
			draw_rect(Rect2(0, 0, s.x, s.y), Color(0.01, 0.01, 0.03, 0.55 + 0.4 * t))
			var c := Vector2(s.x * 0.5, s.y * 0.46)
			draw_rect(Rect2(c.x - 60.0, c.y - 70.0, 120.0, 130.0), Color(0.16, 0.11, 0.08))
			draw_rect(Rect2(c.x - 48.0, c.y - 58.0, 96.0, 106.0), Color(1.0, 0.82, 0.45, 0.28 * (1.0 - t * 0.7)))
			draw_rect(Rect2(c.x - 3.0, c.y - 58.0, 6.0, 106.0), Color(0.16, 0.11, 0.08))
			draw_rect(Rect2(c.x - 48.0, c.y - 8.0, 96.0, 6.0), Color(0.16, 0.11, 0.08))
			for z in 3:
				var zt := fposmod(t * 2.2 + float(z) * 0.33, 1.0)
				var zp := c + Vector2(70.0 + zt * 46.0 + float(z) * 8.0, -30.0 - zt * 70.0)
				draw_string(font, zp, "z", HORIZONTAL_ALIGNMENT_LEFT, -1, 18 + z * 4, Color(0.9, 0.88, 0.8, (1.0 - zt) * 0.8))
			draw_string(font, Vector2(0, c.y + 110.0), "the day ends", HORIZONTAL_ALIGNMENT_CENTER, s.x, 16, Color(0.9, 0.85, 0.7, ease_in))


#endregion

#region MAIN MENU SCREEN
func draw_menu(font: Font, s: Vector2) -> void:
	var cx := s.x * 0.5
	# a deep theatre backdrop: warm gradient, one spotlight, a row of footlights
	draw_gradient_v(Rect2(0, 0, s.x, s.y), Color(0.11, 0.05, 0.07), Color(0.03, 0.02, 0.03), 22)
	draw_spotlight_cone(s, cx, 0.10)
	for i in 16:
		var lx := s.x * (float(i) + 0.5) / 16.0
		var fl := 0.6 + 0.4 * sin(float(cine_tick) * 0.06 + float(i))
		draw_circle(Vector2(lx, s.y - 28.0), 14.0, Color(1.0, 0.7, 0.3, 0.08 * fl))
		draw_circle(Vector2(lx, s.y - 28.0), 5.0, Color(1.0, 0.72, 0.32, 0.6 * fl))
	draw_dust(s, 22, Color(1.0, 0.85, 0.55))

	# a slow, graceful cascade above the title, with soft motion trails
	draw_menu_cascade(Vector2(cx, s.y * 0.17), 1.0)

	draw_iacto_logo(font, s.y * 0.32, 92, Color(1.0, 0.88, 0.5), s)
	draw_ornament(cx, s.y * 0.32 + 112.0, 230.0, Color(0.82, 0.62, 0.34, 0.85))
	draw_string(font, Vector2(0, s.y * 0.32 + 160.0), "a juggler's climb", HORIZONTAL_ALIGNMENT_CENTER, s.x, 22, Color(0.85, 0.72, 0.6))

	var opts := menu_options()   # the same live list menu_input drives, so cursor and drawing agree
	var oy := s.y * 0.62
	for i in opts.size():
		var sel := i == menu_sel
		var txt := ("%s" % opts[i]) if not sel else (">    %s    <" % opts[i])
		var col := Color(1.0, 0.9, 0.55) if sel else Color(0.72, 0.66, 0.6)
		draw_string(font, Vector2(0, oy + float(i) * 44.0), txt, HORIZONTAL_ALIGNMENT_CENTER, s.x, 28, col)
	var mfoot := "Up / Down to choose    A to select" if pad_active() else "Up / Down to choose    Enter to select"
	draw_string(font, Vector2(0, s.y - 40.0), mfoot, HORIZONTAL_ALIGNMENT_CENTER, s.x, 15, Color(0.7, 0.66, 0.6))
	draw_string(font, Vector2(s.x - 120.0, s.y - 34.0), "v0.9", HORIZONTAL_ALIGNMENT_RIGHT, 90.0, 12, Color(0.6, 0.55, 0.5, 0.7))

	draw_vignette(s, 0.5)
	draw_frame(s, 22.0, Color(0.82, 0.62, 0.34, 0.5))


func _cascade_pos(t: float, i: int, count: int, hl: Vector2, hr: Vector2, T: float, peak: float) -> Vector2:
	var phase := fposmod(t + float(i) * (T * 2.0 / float(maxi(1, count))), T * 2.0)
	var seg := 0 if phase < T else 1
	var u := (phase - float(seg) * T) / T
	var frm := hl if seg == 0 else hr
	var to := hr if seg == 0 else hl
	var p := frm.lerp(to, u)
	p.y -= peak * 4.0 * u * (1.0 - u)   # a parabolic arc
	return p


func draw_menu_cascade(center: Vector2, sc: float) -> void:
	# a calm, high cascade: much slower than the gameplay demo, each ball trailing a
	# soft comet of faded echoes so the motion reads as elegant rather than busy
	var count := 3
	var T := 112.0                       # slow half-cycle (the gameplay demo uses 52)
	var peak := 104.0 * sc
	var spanx := 76.0 * sc
	var hl := center + Vector2(-spanx, 42.0 * sc)
	var hr := center + Vector2(spanx, 42.0 * sc)
	var t := float(cine_tick) * 0.5      # slow, graceful clock
	for i in count:
		var col := ball_color(i)
		for k in range(10, 0, -1):       # trail: faded echoes back along the path
			var pp := _cascade_pos(t - float(k) * 3.0, i, count, hl, hr, T, peak)
			var a := 0.11 * (1.0 - float(k) / 11.0)
			draw_circle(pp, (12.5 - 0.75 * float(k)) * sc, Color(col.r, col.g, col.b, maxf(a, 0.0)))
		draw_ball_shape(_cascade_pos(t, i, count, hl, hr, T, peak), col, 1.35)


func draw_capsule_art(font: Font, s: Vector2) -> void:
	# dev only (--capsule): pure key-art for the Steam store, no UI chrome at all -
	# reuses the exact menu-screen visual language (same backdrop, ball motif,
	# wordmark, gold frame), just bigger and centred, since that composition is
	# already proven rather than inventing a new risk. Capture at the native
	# 1280x720 with `--capsule --shot <path> --shotat 30`, then centre-crop to
	# 1232x706 (2x Steam's 616x353 Main Capsule - same aspect, so no distortion):
	#   sips --cropToHeightWidth 706 1232 <path>
	var cx := s.x * 0.5
	draw_gradient_v(Rect2(0, 0, s.x, s.y), Color(0.12, 0.055, 0.075), Color(0.03, 0.02, 0.03), 22)
	draw_spotlight_cone(s, cx, 0.16)
	for i in 20:
		var lx := s.x * (float(i) + 0.5) / 20.0
		var fl := 0.6 + 0.4 * sin(float(cine_tick) * 0.06 + float(i))
		draw_circle(Vector2(lx, s.y - 20.0), 12.0, Color(1.0, 0.7, 0.3, 0.09 * fl))
		draw_circle(Vector2(lx, s.y - 20.0), 4.0, Color(1.0, 0.72, 0.32, 0.65 * fl))
	draw_dust(s, 26, Color(1.0, 0.85, 0.55))
	draw_menu_cascade(Vector2(cx, s.y * 0.34), 1.6)
	draw_iacto_logo(font, s.y * 0.58, 112, Color(1.0, 0.88, 0.5), s)
	draw_ornament(cx, s.y * 0.58 + 134.0, 270.0, Color(0.82, 0.62, 0.34, 0.85))
	draw_string(font, Vector2(0, s.y * 0.58 + 182.0), "a juggler's climb", HORIZONTAL_ALIGNMENT_CENTER, s.x, 27, Color(0.88, 0.76, 0.62))
	draw_vignette(s, 0.55)
	draw_frame(s, 22.0, Color(0.82, 0.62, 0.34, 0.55))


#endregion

#region SLOTS / SETTINGS / GAME-OVER / MISC SCREENS
func draw_slots(font: Font, s: Vector2) -> void:
	view_venue = 2
	draw_backdrop(s)
	view_venue = -1
	draw_rect(Rect2(0, 0, s.x, s.y), Color(0.03, 0.02, 0.03, 0.62))
	draw_string(font, Vector2(0, s.y * 0.17), "SAVE FILES", HORIZONTAL_ALIGNMENT_CENTER, s.x, 44, Color(1.0, 0.86, 0.5))

	var pw := 660.0
	var px := s.x * 0.5 - pw * 0.5
	var oy := s.y * 0.30
	for i in NUM_SLOTS:
		var sel := i == menu_sel
		var ry := oy + float(i) * 74.0
		var sum := slot_summary(i)
		draw_rect(Rect2(px, ry, pw, 60.0), Color(0.12, 0.07, 0.08, 0.92))
		draw_rect(Rect2(px, ry, pw, 60.0), Color(0.9, 0.6, 0.35, 0.55) if sel else Color(0.4, 0.32, 0.26, 0.5), false, 2.0)
		var crowned := sum.find("WORLD'S GREATEST") != -1   # a finished save wears a warmer gold
		var tcol := Color(1.0, 0.9, 0.6) if sel else Color(0.8, 0.74, 0.66)
		if crowned:
			tcol = Color(1.0, 0.82, 0.4) if sel else Color(0.98, 0.76, 0.36)
		draw_string(font, Vector2(px + 24.0, ry + 27.0), "Slot %d" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, tcol)
		draw_string(font, Vector2(px + 24.0, ry + 49.0), sum, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.78, 0.72, 0.62))
		if sum != "empty":
			draw_string(font, Vector2(px + pw - 110.0, ry + 37.0), "[X] delete", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.88, 0.55, 0.5))

	var by := oy + float(NUM_SLOTS) * 74.0 + 16.0
	var bsel := menu_sel == NUM_SLOTS
	draw_string(font, Vector2(0, by + 22.0), ("Back" if not bsel else ">   Back   <"), HORIZONTAL_ALIGNMENT_CENTER, s.x, 24, Color(1.0, 0.9, 0.55) if bsel else Color(0.72, 0.66, 0.6))
	var sfoot := "Up / Down    A to play    X to delete    B to go back" if pad_active() else "Up / Down    Enter to play    X to delete    Esc to go back"
	draw_string(font, Vector2(0, s.y - 42.0), sfoot, HORIZONTAL_ALIGNMENT_CENTER, s.x, 15, Color(0.7, 0.66, 0.6))
	draw_vignette(s, 0.5)
	draw_frame(s, 22.0, Color(0.82, 0.62, 0.34, 0.5))


func draw_settings(font: Font, s: Vector2) -> void:
	view_venue = 2
	draw_backdrop(s)
	view_venue = -1
	draw_rect(Rect2(0, 0, s.x, s.y), Color(0.03, 0.02, 0.03, 0.62))
	draw_string(font, Vector2(0, s.y * 0.17), "SETTINGS", HORIZONTAL_ALIGNMENT_CENTER, s.x, 44, Color(1.0, 0.86, 0.5))

	# Music / Sound are volume sliders (float 0..1); the rest stay plain on/off bools
	var rows := [["Screen shake", set_shake], ["Hard collisions  (clacks ruin catches)", set_collide], ["Fullscreen  (F11 anywhere)", set_fullscreen]]
	var pw := 560.0
	var px := s.x * 0.5 - pw * 0.5
	var oy := s.y * 0.28
	var sliders := [["Music", set_music], ["Sound effects", set_sfx]]
	for i in sliders.size():
		var sel := i == menu_sel
		var ry := oy + float(i) * 48.0
		var nm := String(sliders[i][0])
		var vol: float = sliders[i][1]
		draw_string(font, Vector2(px, ry), ("> " if sel else "  ") + nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1.0, 0.9, 0.6) if sel else Color(0.8, 0.74, 0.66))
		draw_meter(px + pw - 190.0, ry - 14.0, 130.0, 16.0, vol, Color(0.55, 0.80, 0.6) if vol > 0.0 else Color(0.5, 0.44, 0.4))
		draw_string(font, Vector2(px + pw - 50.0, ry), "mute" if vol <= 0.0 else "%d%%" % int(round(vol * 100.0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.85, 0.6, 0.55) if vol <= 0.0 else Color(0.8, 0.9, 0.8))
	for i in rows.size():
		var sel := (i + sliders.size()) == menu_sel
		var ry := oy + float(i + sliders.size()) * 48.0
		var nm := String(rows[i][0])
		var on := bool(rows[i][1])
		draw_string(font, Vector2(px, ry), ("> " if sel else "  ") + nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1.0, 0.9, 0.6) if sel else Color(0.8, 0.74, 0.66))
		draw_string(font, Vector2(px + pw - 60.0, ry), "ON" if on else "OFF", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.6, 0.9, 0.6) if on else Color(0.85, 0.6, 0.55))
	var rows_total := rows.size() + sliders.size()

	var csel := menu_sel == rows_total
	var cry := oy + float(rows_total) * 48.0
	draw_string(font, Vector2(px, cry), ("> " if csel else "  ") + "Controls  (rebind the keys)", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1.0, 0.9, 0.6) if csel else Color(0.8, 0.74, 0.66))
	var rsel := menu_sel == rows_total + 1
	var rry := cry + 48.0
	draw_string(font, Vector2(px, rry), ("> " if rsel else "  ") + "Records and history", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1.0, 0.9, 0.6) if rsel else Color(0.8, 0.74, 0.66))
	var bsel := menu_sel == rows_total + 2
	draw_string(font, Vector2(0, rry + 48.0 + 28.0), ("Back" if not bsel else ">   Back   <"), HORIZONTAL_ALIGNMENT_CENTER, s.x, 24, Color(1.0, 0.9, 0.55) if bsel else Color(0.72, 0.66, 0.6))
	var tfoot := "Up / Down    Left / Right adjust    A to toggle    B to go back" if pad_active() else "Up / Down    Left / Right adjust    Enter to toggle    Esc to go back"
	draw_string(font, Vector2(0, s.y - 42.0), tfoot, HORIZONTAL_ALIGNMENT_CENTER, s.x, 15, Color(0.7, 0.66, 0.6))
	draw_vignette(s, 0.5)
	draw_frame(s, 22.0, Color(0.82, 0.62, 0.34, 0.5))


func draw_gameover(font: Font, s: Vector2) -> void:
	# the road's end: no strength to earn, no gold for a bed. The career closes
	# with its numbers and the slot starts over.
	draw_rect(Rect2(0, 0, s.x, s.y), Color(0.02, 0.01, 0.02))
	var fin := clampf(float(cine_tick) / 60.0, 0.0, 1.0)
	draw_title_glow(font, s.y * 0.22, "THE ROAD ENDS HERE", 42, Color(0.9, 0.55, 0.4, fin), s)
	draw_ornament(s.x * 0.5, s.y * 0.22 + 68.0, 220.0, Color(0.7, 0.45, 0.3, 0.8 * fin))
	draw_string(font, Vector2(0, s.y * 0.40), "Too tired to work. Too poor for a bed. The city keeps what it takes.",
		HORIZONTAL_ALIGNMENT_CENTER, s.x, 18, Color(0.85, 0.78, 0.66, fin))
	var lines := [
		"%d day%s on the road" % [int(career["days"]), "" if int(career["days"]) == 1 else "s"],
		"%d performances,  %d catches" % [int(career["perfs"]), int(career["catches"])],
		"best streak %d,  highest score %d" % [int(career["best_streak"]), int(career["best_score"])],
		"%d gold earned, and all of it spent" % int(career["gold_earned"]),
	]
	for i in lines.size():
		var la := clampf(float(cine_tick - 80 - i * 30) / 40.0, 0.0, 1.0)
		draw_string(font, Vector2(0, s.y * 0.50 + float(i) * 30.0), String(lines[i]), HORIZONTAL_ALIGNMENT_CENTER, s.x, 15, Color(0.75, 0.7, 0.62, la))
	if cine_tick > 90:
		var pa := 0.5 + 0.5 * sin(float(cine_tick) * 0.05)
		draw_string(font, Vector2(0, s.y * 0.80), "any key  -  a new juggler picks up the balls", HORIZONTAL_ALIGNMENT_CENTER, s.x, 15, Color(0.8, 0.72, 0.6, 0.4 + 0.5 * pa))
	draw_vignette(s, 0.7)


func draw_tutdone(font: Font, s: Vector2) -> void:
	# the congrats card after the basics lesson (Louis): a breath between "you can
	# juggle now" and the day hub, showing the starting kit instead of hard-cutting
	# to a menu. The Backyard - the first stage - waits behind the veil.
	ext_center = true
	draw_venue_exterior(s, 0)
	ext_center = false
	draw_rect(Rect2(0, 0, s.x, s.y), Color(0.03, 0.02, 0.03, 0.6))
	var fin := clampf(float(cine_tick) / 50.0, 0.0, 1.0)
	draw_title_glow(font, s.y * 0.20, "YOU CAN JUGGLE", 42, Color(1.0, 0.88, 0.5, fin), s)
	draw_ornament(s.x * 0.5, s.y * 0.20 + 66.0, 220.0, Color(0.82, 0.62, 0.34, 0.85 * fin))
	draw_string(font, Vector2(0, s.y * 0.34), "Throw, catch, and keep it flying. The rest is a career.",
		HORIZONTAL_ALIGNMENT_CENTER, s.x, 18, Color(0.88, 0.8, 0.68, fin))

	# the starting kit, one warm panel: the purse and the three balls
	var kw := 460.0
	var kx := s.x * 0.5 - kw * 0.5
	var ky := s.y * 0.44
	var ka := clampf(float(cine_tick - 30) / 40.0, 0.0, 1.0)
	if ka > 0.0:
		# an opaque underlay first: the Backyard house sits right behind this spot
		# and hud_panel alone is translucent enough to let it bleed through the kit
		draw_rect(Rect2(kx, ky, kw, 148.0), Color(0.05, 0.03, 0.05, 0.9 * ka))
		hud_panel(Rect2(kx, ky, kw, 148.0))
		draw_string(font, Vector2(kx, ky + 30.0), "YOUR STARTING KIT", HORIZONTAL_ALIGNMENT_CENTER, kw, 14, Color(0.95, 0.8, 0.55, ka))
		draw_circle(Vector2(kx + 120.0, ky + 66.0), 8.0, Color(1.0, 0.84, 0.4, ka))
		draw_circle(Vector2(kx + 117.0, ky + 63.0), 2.6, Color(1.0, 0.95, 0.7, ka))
		draw_string(font, Vector2(kx + 140.0, ky + 72.0), "%s gold" % commafy(money), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(1.0, 0.86, 0.45, ka))
		for i in 3:
			var bc := ball_color(i)
			bc.a = ka
			draw_ball_shape(Vector2(kx + 104.0 + float(i) * 26.0, ky + 108.0), bc, 0.9)
		draw_string(font, Vector2(kx + 140.0 + 42.0, ky + 114.0), "three juggling balls", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.88, 0.8, 0.68, ka))

	draw_string(font, Vector2(0, s.y * 0.66), "The Backyard is waiting for its first show.",
		HORIZONTAL_ALIGNMENT_CENTER, s.x, 15, Color(0.8, 0.74, 0.64, ka))
	if cine_tick > 40:
		var pa := 0.5 + 0.5 * sin(float(cine_tick) * 0.05)
		draw_string(font, Vector2(0, s.y * 0.78), "Enter  -  begin your first day", HORIZONTAL_ALIGNMENT_CENTER, s.x, 16, Color(1.0, 0.85, 0.55, 0.4 + 0.5 * pa))
	draw_vignette(s, 0.6)


func draw_stats(font: Font, s: Vector2) -> void:
	# the career ledger: the two record boards side by side over the lifetime
	# numbers, so every high score the save has ever set stays visible
	view_venue = 4
	draw_backdrop(s)
	view_venue = -1
	draw_rect(Rect2(0, 0, s.x, s.y), Color(0.03, 0.02, 0.03, 0.68))
	draw_title_glow(font, s.y * 0.06, "RECORDS AND HISTORY", 36, Color(1.0, 0.88, 0.5), s)
	draw_ornament(s.x * 0.5, s.y * 0.06 + 62.0, 210.0, Color(0.82, 0.62, 0.34, 0.85))

	# left: the venue record boards, assisted and Purist
	var lx := s.x * 0.5 - 470.0
	var ly := s.y * 0.30
	hud_panel(Rect2(lx - 20.0, ly - 34.0, 460.0, 300.0))
	draw_string(font, Vector2(lx, ly), "VENUE RECORDS", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(1.0, 0.88, 0.55))
	draw_string(font, Vector2(lx + 230.0, ly), "best", HORIZONTAL_ALIGNMENT_RIGHT, 90.0, 13, Color(0.8, 0.74, 0.66))
	draw_string(font, Vector2(lx + 330.0, ly), "purist", HORIZONTAL_ALIGNMENT_RIGHT, 90.0, 13, Color(0.82, 0.72, 0.85))
	for i in 7:
		var ry := ly + 34.0 + float(i) * 38.0
		var nm := String(venue_data(i)["name"])
		var reached := i <= venue_index()
		draw_string(font, Vector2(lx, ry), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.85, 0.78, 0.66) if reached else Color(0.5, 0.46, 0.42))
		var b := best_scores[i]
		var p := best_scores_purist[i]
		draw_string(font, Vector2(lx + 230.0, ry), str(b) if b > 0 else "-", HORIZONTAL_ALIGNMENT_RIGHT, 90.0, 15, Color(1.0, 0.86, 0.45) if b > 0 else Color(0.5, 0.46, 0.42))
		draw_string(font, Vector2(lx + 330.0, ry), str(p) if p > 0 else "-", HORIZONTAL_ALIGNMENT_RIGHT, 90.0, 15, Color(0.82, 0.72, 0.85) if p > 0 else Color(0.5, 0.46, 0.42))

	# right: the lifetime numbers
	var rx := s.x * 0.5 + 30.0
	hud_panel(Rect2(rx - 20.0, ly - 34.0, 460.0, 300.0))
	draw_string(font, Vector2(rx, ly), "THE CAREER SO FAR", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(1.0, 0.88, 0.55))
	var lines := [
		["days on the road", str(int(career["days"]))],
		["performances", str(int(career["perfs"]))],
		["practice sessions", str(int(career["practices"]))],
		["catches  /  drops", "%d  /  %d" % [int(career["catches"]), int(career["drops"])]],
		["longest streak ever", str(int(career["best_streak"]))],
		["highest score anywhere", str(int(career["best_score"]))],
		["tricks landed", str(int(career["tricks"]))],
		["gold earned on stage", str(int(career["gold_earned"]))],
	]
	if int(career.get("mastery", 0)) > 0:
		lines.append(["mastery points turned to gold", str(int(career["mastery"]))])
	for i in lines.size():
		var ry := ly + 34.0 + float(i) * 30.0
		draw_string(font, Vector2(rx, ry), String(lines[i][0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.85, 0.78, 0.66))
		draw_string(font, Vector2(rx + 280.0, ry), String(lines[i][1]), HORIZONTAL_ALIGNMENT_RIGHT, 140.0, 15, Color(1.0, 0.9, 0.65))

	draw_string(font, Vector2(0, s.y - 42.0), "Esc back", HORIZONTAL_ALIGNMENT_CENTER, s.x, 15, Color(0.7, 0.66, 0.6))
	draw_vignette(s, 0.5)
	draw_frame(s, 22.0, Color(0.82, 0.62, 0.34, 0.5))


# =============================================================================
# Audio. The SFX below are all synthesised in code into an AudioStreamWAV at
# startup (gen_sfx, setup_audio), then just played, so there is no per-frame
# synthesis cost. Music is NOT synthesised: it is two of Louis's own Suno MP3
# loops (MUSIC_PATH "juggling", MUSIC_PATH_CHILL "chill", both loaded and
# looping from setup_audio) that audio_update volume-automates and staged-
# crossfades between - see the _mix walk there. No crowd-murmur bed; that idea
# was cut (2026-07-18) in favour of zero ambient noise and tonal stingers only.
# =============================================================================

#endregion

#region AUDIO SYNTHESIS (SFX)
func setup_audio() -> void:
	gen_sfx()
	for _i in 8:                       # a round-robin pool for overlapping one-shots
		var p := AudioStreamPlayer.new()
		add_child(p)
		sfx_pool.append(p)
	mus = AudioStreamPlayer.new(); add_child(mus); mus.volume_db = -80.0
	var m := load(MUSIC_PATH) as AudioStreamMP3
	if m != null:
		m.loop = true
		mus.stream = m
		mus.play()
	# the calmer non-juggling track, looping alongside, held silent until it is wanted
	mus2 = AudioStreamPlayer.new(); add_child(mus2); mus2.volume_db = -80.0
	var m2 := load(MUSIC_PATH_CHILL) as AudioStreamMP3
	if m2 != null:
		m2.loop = true
		mus2.stream = m2
		mus2.play()
	_audio_ready = true


func play_sfx(name: String, vol_db: float = 0.0, pitch: float = 1.0) -> void:
	if set_sfx <= 0.0 or not _audio_ready or not sfx.has(name):
		return
	var p: AudioStreamPlayer = sfx_pool[_sfx_next]
	_sfx_next = (_sfx_next + 1) % sfx_pool.size()
	p.stream = sfx[name]
	p.volume_db = vol_db + linear_to_db(set_sfx)   # the slider only ATTENUATES: at
													# 1.0 every hand-tuned vol_db above
													# is untouched, same as the old bool
	p.pitch_scale = clampf(pitch, 0.3, 3.0)
	p.play()


func _catch_sound(kind: int) -> String:
	match kind:
		PROP_EGGS: return "c_egg"
		# rings share the ball catch sound (Louis: didn't like the ring timbre)
		PROP_CLUBS: return "c_club"
		PROP_KNIVES: return "c_knife"
		PROP_TORCHES: return "c_torch"
		_: return "c_ball"


func audio_update() -> void:
	# runs every frame in every state: glide the track's volume to fit the moment.
	# Louis's song IS the soundtrack, so the game never changes the material, only
	# how much room it takes: the "juggling" loop plays whenever juggling could
	# start (the stage door onward), the "chill" loop takes over everywhere else
	# (menus, day hub, results), and a prop hitting the floor dips it briefly
	# (via _duck).
	if not _audio_ready:
		return
	var in_play := game_state == ST_PLAY
	var perf := in_play and mode == MODE_PERFORM and not tut_active
	# JUGGLING = anywhere the player could start juggling: the stage card and the
	# whole play state (performance, practice, or a lesson - throwing or not). The
	# handover used to wait for the FIRST THROW, which meant the chill mix was still
	# fading while you were already juggling (Louis); now it starts at the stage
	# door, so the swap is done before the balls go up. Only the results card hands
	# back to the chill mix (the performance is over).
	var juggling := game_state == ST_ESTABLISH or (in_play and not results_open)
	var energy := clampf(applause * 0.65 + clampf(float(streak) / 8.0, 0.0, 1.0) * 0.55, 0.0, 1.0)
	# the handover between the two tracks is STAGED (Louis: they differ too much in
	# tempo and volume to overlap - a crossfade read as a mashup). _mix walks 0..1,
	# and the gain curves carve the walk into three bands: the leaving track fades
	# fully OUT, a breath of true silence holds, then the arriving track fades IN
	# from nothing. Both directions get the same shape.
	_mix = move_toward(_mix, 1.0 if juggling else 0.0, 1.0 / (3.0 * 120.0))
	var chill_g := clampf(1.0 - _mix / 0.38, 0.0, 1.0)     # gone 38% into the walk
	var main_g := clampf((_mix - 0.62) / 0.38, 0.0, 1.0)   # enters only after the hush
	# the stage track RESTARTS from the top whenever it returns from full silence, so
	# every performance opens on the song's opening bars instead of joining mid-loop
	if main_g <= 0.0:
		_main_silent = true
	elif _main_silent:
		_main_silent = false
		mus.play(0.0)
	var main_base := (lerpf(-13.0, -9.0, energy) if perf else -14.0) - _duck * 9.0
	# the slider only ATTENUATES (maxf floors it at -80dB, effectively silent, so
	# there is no separate "if muted" branch to keep in sync with this one)
	var vol_off := linear_to_db(maxf(set_music, 0.0001))
	var main_t := main_base + linear_to_db(maxf(main_g, 0.001)) + vol_off
	var chill_t := -13.0 + linear_to_db(maxf(chill_g, 0.001)) + vol_off
	# the base loudness still GLIDES (energy swells, drop ducks); only the handover
	# itself is the timed crossfade above
	_vol["mus"] = lerpf(_vol["mus"], main_t, 0.06)
	mus.volume_db = maxf(_vol["mus"], -80.0)
	_vol["mus2"] = lerpf(_vol["mus2"], chill_t, 0.06)
	mus2.volume_db = maxf(_vol["mus2"], -80.0)
	_duck = maxf(0.0, _duck - 0.03)


# --- synthesis primitives -----------------------------------------------------

func _wav(data: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var n := data.size()
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		bytes.encode_s16(i * 2, int(clampf(data[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = AUDIO_SR
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = n
	return w


func _wsamp(phase: float, wave: int) -> float:
	var ph := fposmod(phase, TAU)
	match wave:
		1:
			return 4.0 * absf(ph / TAU - 0.5) - 1.0   # triangle
		2:
			return ph / PI - 1.0                       # saw
		3:
			return 1.0 if ph < PI else -1.0            # square
		_:
			return sin(ph)


func _tone(freqs: Array, amps: Array, dur: float, wave: int, atk: float, decay: float, vol: float, noise: float) -> PackedFloat32Array:
	# additive partials with a fast-attack exponential-decay (plucked) envelope
	var n := int(AUDIO_SR * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	var phs := PackedFloat32Array()
	phs.resize(freqs.size())
	for i in n:
		var t := float(i) / AUDIO_SR
		var e := (t / maxf(atk, 0.0001)) if t < atk else exp(-(t - atk) / maxf(decay, 0.0001))
		var s := 0.0
		var asum := 0.0
		for j in freqs.size():
			phs[j] += TAU * float(freqs[j]) / AUDIO_SR
			s += _wsamp(phs[j], wave) * float(amps[j])
			asum += float(amps[j])
		s /= maxf(asum, 0.0001)
		if noise > 0.0:
			s = lerpf(s, randf() * 2.0 - 1.0, noise)
		out[i] = s * e * vol
	return out


func _click(dur: float, decay: float, vol: float) -> PackedFloat32Array:
	# a short broadband noise transient: the real "point of contact" a catch or
	# knock makes, decaying far faster than any tonal body mixed under it via
	# _mix_into. _tone's own `noise` param blends noise for the WHOLE note (right
	# for something airy like a whiff or a torch whoosh); this is for the crisp
	# attack a _tone alone can't give a "something just hit my hand" sound.
	var n := int(AUDIO_SR * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / AUDIO_SR
		out[i] = (randf() * 2.0 - 1.0) * exp(-t / maxf(decay, 0.0001)) * vol
	return out


func _mix_into(base: PackedFloat32Array, extra: PackedFloat32Array) -> PackedFloat32Array:
	# additively layers `extra` under/over `base` (e.g. a _click transient under
	# a _tone body), sample by sample, clamped so the two can never clip together
	for i in mini(base.size(), extra.size()):
		base[i] = clampf(base[i] + extra[i], -1.0, 1.0)
	return base


func _seq_bells(freqs: Array, gap: float, vol: float) -> PackedFloat32Array:
	# a little run of bell notes, for coins and streak flourishes
	var note := 0.18
	var n := int(AUDIO_SR * (gap * float(freqs.size()) + note))
	var out := PackedFloat32Array()
	out.resize(n)
	for j in freqs.size():
		var start := int(AUDIO_SR * gap * float(j))
		var ph := 0.0
		for i in int(AUDIO_SR * note):
			var idx := start + i
			if idx >= n:
				break
			ph += TAU * float(freqs[j]) / AUDIO_SR
			out[idx] = clampf(out[idx] + sin(ph) * exp(-float(i) / AUDIO_SR / 0.08) * vol, -1.0, 1.0)
	return out


func _drop_sound() -> PackedFloat32Array:
	# a prop hitting the floor: a falling low thud (120Hz down to 55Hz) with a
	# sharp noise click layered on top for the impact
	var dur := 0.34
	var n := int(AUDIO_SR * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / AUDIO_SR
		ph += TAU * lerpf(120.0, 55.0, clampf(t / 0.2, 0.0, 1.0)) / AUDIO_SR
		var body := sin(ph) * exp(-t / 0.12)
		var click := (randf() * 2.0 - 1.0) * exp(-t / 0.02) * 0.5
		out[i] = clampf((body * 0.8 + click) * 0.6, -1.0, 1.0)
	return out


func _throw_sound() -> PackedFloat32Array:
	# a soft downward "whup": a quick falling pitch with a little air, not a noise burst
	var dur := 0.16
	var n := int(AUDIO_SR * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / AUDIO_SR
		var f := lerpf(540.0, 240.0, clampf(t / dur, 0.0, 1.0))   # falling whup
		ph += TAU * f / AUDIO_SR
		var air := (randf() * 2.0 - 1.0) * 0.22
		var e := exp(-t / 0.06)
		out[i] = clampf((sin(ph) * 0.75 + air * 0.5) * e * 0.32, -1.0, 1.0)
	return out


func _catch_perfect() -> PackedFloat32Array:
	# the satisfying one: a soft round body plus a bright major-third sparkle on top
	var dur := 0.34
	var n := int(AUDIO_SR * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	var body := 0.0
	var s1 := 0.0
	var s2 := 0.0
	var s3 := 0.0
	for i in n:
		var t := float(i) / AUDIO_SR
		body += TAU * 300.0 / AUDIO_SR      # warm pock body
		s1 += TAU * 1046.5 / AUDIO_SR       # C6
		s2 += TAU * 1318.5 / AUDIO_SR       # E6
		s3 += TAU * 1568.0 / AUDIO_SR       # G6
		var eb := exp(-t / 0.05)
		var eb2 := exp(-t / 0.16)
		var v := sin(body) * 0.5 * eb + (sin(s1) + 0.7 * sin(s2) + 0.5 * sin(s3)) / 2.2 * 0.55 * eb2
		out[i] = clampf(v * 0.6, -1.0, 1.0)
	return out


func _splat_sound() -> PackedFloat32Array:
	# the egg shattering on the floor (paired with spawn_egg_break, not a generic
	# prop drop): a noisy wet burst over a low 150Hz tone, both dying out fast
	var dur := 0.22
	var n := int(AUDIO_SR * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / AUDIO_SR
		ph += TAU * 150.0 / AUDIO_SR
		out[i] = clampf(((randf() * 2.0 - 1.0) * 0.6 + sin(ph) * 0.4) * exp(-t / 0.05) * 0.6, -1.0, 1.0)
	return out


func _gasp_sound() -> PackedFloat32Array:
	# the room inhaling at a risky throw: a soft quick upward slide, pure tone
	var dur := 0.28
	var n := int(AUDIO_SR * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / AUDIO_SR
		ph += TAU * lerpf(320.0, 560.0, clampf(t / dur, 0.0, 1.0)) / AUDIO_SR
		out[i] = sin(ph) * clampf(t / 0.06, 0.0, 1.0) * exp(-maxf(t - 0.14, 0.0) / 0.07) * 0.3
	return out


func _groan_sound() -> PackedFloat32Array:
	# the room sagging at a drop: two low tones sliding down a third, pure tone
	var dur := 0.5
	var n := int(AUDIO_SR * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	var ph2 := 0.0
	for i in n:
		var t := float(i) / AUDIO_SR
		var slide := lerpf(196.0, 155.6, clampf(t / 0.3, 0.0, 1.0))
		ph += TAU * slide / AUDIO_SR
		ph2 += TAU * slide * 1.5 / AUDIO_SR
		out[i] = (sin(ph) + 0.4 * sin(ph2)) / 1.4 * clampf(t / 0.05, 0.0, 1.0) * exp(-maxf(t - 0.2, 0.0) / 0.14) * 0.34
	return out


func _cheer_sound() -> PackedFloat32Array:
	# the room lifting: a warm major chord that swells and settles under a quick
	# rising run of bells. All tone, no noise (the old version was a noise swell,
	# which Louis heard as static rather than a cheer).
	var dur := 1.1
	var n := int(AUDIO_SR * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	var chord := [523.25, 659.26, 783.99]   # C5 E5 G5
	var phs := [0.0, 0.0, 0.0]
	for i in n:
		var t := float(i) / AUDIO_SR
		var e := clampf(t / 0.22, 0.0, 1.0) * exp(-maxf(t - 0.22, 0.0) / 0.38)
		var s := 0.0
		for j in 3:
			phs[j] += TAU * float(chord[j]) * (1.0 + 0.004 * sin(TAU * 5.0 * t + float(j))) / AUDIO_SR
			s += sin(float(phs[j]))
		out[i] = s / 3.0 * e * 0.4
	# the quick bell run on top, stepping up the C major pentatonic
	var run := [783.99, 987.77, 1174.66, 1567.98]
	for j in run.size():
		var start := int(AUDIO_SR * (0.05 + 0.07 * float(j)))
		var ph := 0.0
		for i in int(AUDIO_SR * 0.3):
			var idx := start + i
			if idx >= n:
				break
			ph += TAU * float(run[j]) / AUDIO_SR
			out[idx] = clampf(out[idx] + sin(ph) * exp(-float(i) / AUDIO_SR / 0.09) * 0.22, -1.0, 1.0)
	return out


func _stamp_sound() -> PackedFloat32Array:
	# a heavy stamp for the grade badge: a low thump plus a snap of noise
	var dur := 0.22
	var n := int(AUDIO_SR * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / AUDIO_SR
		ph += TAU * lerpf(140.0, 62.0, clampf(t / 0.12, 0.0, 1.0)) / AUDIO_SR
		var body := sin(ph) * exp(-t / 0.09)
		var snap := (randf() * 2.0 - 1.0) * exp(-t / 0.012) * 0.6
		out[i] = clampf((body * 0.9 + snap) * 0.7, -1.0, 1.0)
	return out


func gen_sfx() -> void:
	# catch feedback, by quality: perfect is satisfying, good is a warm nod, late is a
	# dull "meh", whiff is a soft airy miss. These are the load-bearing sounds.
	sfx["perfect"] = _wav(_catch_perfect(), false)
	sfx["cheer"] = _wav(_cheer_sound(), false)
	sfx["stamp"] = _wav(_stamp_sound(), false)
	sfx["count"] = _wav(_tone([1318.5], [1.0], 0.05, 0, 0.001, 0.02, 0.22, 0.0), false)
	sfx["record"] = _wav(_seq_bells([659.3, 784.0, 987.8, 1318.5], 0.09, 0.5), false)
	sfx["good"] = _wav(_tone([880.0, 1318.5], [1.0, 0.45], 0.24, 0, 0.001, 0.11, 0.46, 0.0), false)
	sfx["late"] = _wav(_tone([392.0], [1.0], 0.15, 1, 0.003, 0.05, 0.34, 0.03), false)
	sfx["whiff"] = _wav(_tone([520.0, 415.0], [1.0, 0.5], 0.10, 0, 0.001, 0.045, 0.18, 0.1), false)
	sfx["throw"] = _wav(_throw_sound(), false)
	sfx["drop"] = _wav(_drop_sound(), false)
	sfx["splat"] = _wav(_splat_sound(), false)
	sfx["coin"] = _wav(_seq_bells([987.8, 1318.5], 0.09, 0.5), false)
	# gold changing hands: a quick high jingle of coin-on-coin clinks, distinct from
	# the two-note "coin" flourish above (which stays the lesson-complete fanfare)
	sfx["money"] = _wav(_seq_bells([1568.0, 2093.0, 1760.0, 2637.0], 0.045, 0.42), false)
	sfx["streak"] = _wav(_seq_bells([784.0, 987.8, 1318.5], 0.08, 0.5), false)
	sfx["ui"] = _wav(_tone([880.0], [1.0], 0.05, 0, 0.001, 0.02, 0.3, 0.0), false)
	sfx["ui2"] = _wav(_tone([1174.7, 1568.0], [1.0, 0.5], 0.10, 0, 0.001, 0.05, 0.35, 0.0), false)
	sfx["gasp"] = _wav(_gasp_sound(), false)
	sfx["groan"] = _wav(_groan_sound(), false)
	# per-prop catch textures: NOT PLAYED right now (Louis: only perfect/good/late/
	# whiff, no per-object sounds) - see the removed play_sfx call in on_catch.
	# Kept generated (and the _click/_mix_into transient helpers kept defined,
	# unused) so this whole texture layer is one commented-out line away from
	# coming back, not deleted.
	sfx["c_ball"] = _wav(_tone([420.0], [1.0], 0.10, 0, 0.001, 0.035, 0.5, 0.15), false)
	sfx["c_egg"] = _wav(_tone([520.0], [1.0], 0.09, 0, 0.001, 0.03, 0.45, 0.2), false)
	sfx["c_club"] = _wav(_tone([190.0, 320.0], [1.0, 0.4], 0.10, 1, 0.001, 0.04, 0.5, 0.25), false)
	sfx["c_knife"] = _wav(_tone([1200.0, 2760.0, 5400.0], [1.0, 0.5, 0.25], 0.42, 0, 0.001, 0.30, 0.32, 0.0), false)
	sfx["c_torch"] = _wav(_tone([140.0], [1.0], 0.28, 0, 0.02, 0.18, 0.4, 0.7), false)


func dump_audio(dir: String) -> void:
	# dev: write every sound to <dir> as .wav, for verification and preview.
	# The music is Louis's own track now, so only the procedural SFX are dumped.
	for name in sfx:
		(sfx[name] as AudioStreamWAV).save_to_wav("%s/sfx_%s.wav" % [dir, name])


# =============================================================================
# Presentation layer. Everything below is procedural (the code-only art rule,
# ART_AND_MUSIC.md): the stage card, the victory screen, the tutorial demos, and
# the shared "royal" polish (gradients, vignette, gold frames, drifting dust).
# cine_tick drives all the motion.
# =============================================================================

#endregion

#region ESTABLISHING CARD & CREDITS
func venue_blurb(i: int) -> String:
	# one line on the crowd you are about to face, so each stage reads distinct
	match i:
		0: return "a quiet yard  -  a forgiving place to find your hands"
		1: return "a street corner  -  passers-by you keep only by playing clean"
		2: return "a ticketed house  -  quiet, paying, and quietly exacting"
		3: return "the big top  -  loud, vast, and hungry for spectacle"
		4: return "a scored floor  -  judged on precision, never on flash"
		5: return "the summit  -  no help left but your own two hands"
		_: return "no lights but yours  -  the crowd that stayed after the win"


func draw_establish(font: Font, s: Vector2) -> void:
	# the STAGE CARD: a portrait of the venue you are about to play, its rung on the
	# ladder, the record to beat, and how the next stage opens. The exterior drifts
	# in a slow push so the card feels composed rather than static.
	var ez := 1.0 + 0.07 * clampf(float(cine_tick) / 340.0, 0.0, 1.0)
	draw_set_transform(s * 0.5 * (1.0 - ez), 0.0, Vector2(ez, ez))
	ext_center = true    # the card is a portrait of the venue: hero mid-frame
	draw_venue_exterior(s, establish_venue)
	ext_center = false
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var fin := clampf(float(cine_tick) / 26.0, 0.0, 1.0)
	if fin < 1.0:
		draw_rect(Rect2(0, 0, s.x, s.y), Color(0.02, 0.01, 0.02, 1.0 - fin))
	draw_vignette(s, 0.6)
	draw_frame(s, 22.0, Color(0.82, 0.62, 0.34, 0.55))

	var tagA := clampf(float(cine_tick - 10) / 20.0, 0.0, 1.0)
	# ONLY the marquee stays over the portrait: STAGE n of 6, the name in lights, the
	# crowd blurb - text with the 8-way outline, no boxes. Everything informational
	# (record, set, target, encore, purist) lives in two small cards at the BOTTOM
	# corners now (Louis: the centred stack of rectangles buried the venue portrait).
	draw_text_shout(font, Vector2(0, s.y * 0.10), "STAGE  %d  of  %d" % [establish_venue + 1, TOP_VENUE + 1], HORIZONTAL_ALIGNMENT_CENTER, s.x, 16, Color(0.9, 0.78, 0.55, 0.85 * tagA))
	var vn := String(venue_data(establish_venue)["name"]).to_upper()
	draw_title_glow(font, s.y * 0.12 + 12.0, vn, 52, Color(1.0, 0.9, 0.55), s)
	draw_ornament(s.x * 0.5, s.y * 0.12 + 72.0, 190.0, Color(0.82, 0.62, 0.34, 0.85))
	draw_text_shout(font, Vector2(0, s.y * 0.12 + 96.0), venue_blurb(establish_venue), HORIZONTAL_ALIGNMENT_CENTER, s.x, 14, Color(0.86, 0.78, 0.66, 0.8 * tagA))

	var py := s.y - 70.0
	draw_gradient_v(Rect2(0, py - 30.0, s.x, s.y - py + 30.0), Color(0.02, 0.01, 0.02, 0.0), Color(0.02, 0.01, 0.02, 0.9), 16)

	# bottom-LEFT: the record chase at this venue (its own board on a purist night)
	var rw := 330.0
	var rh := 96.0 if purist else 76.0
	var rx := 18.0
	var ry := s.y - 88.0 - rh
	hud_panel(Rect2(rx, ry, rw, rh))
	draw_string(font, Vector2(rx + 16.0, ry + 24.0), "RECORD TO BEAT", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.85, 0.72, 0.55, 0.9 * tagA))
	if establish_venue >= 0 and establish_venue < rec_table().size() and rec_table()[establish_venue] > 0:
		draw_string(font, Vector2(rx + 16.0, ry + 54.0), commafy(rec_table()[establish_venue]), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.96, 0.83, 0.52, tagA))
	else:
		draw_string(font, Vector2(rx + 16.0, ry + 52.0), "none yet  -  set one", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.9, 0.82, 0.6, 0.85 * tagA))
	if purist:
		draw_string(font, Vector2(rx + 16.0, ry + 80.0), "PURIST  -  no stat help, its own board", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.82, 0.72, 0.85, 0.9 * tagA))

	# bottom-RIGHT: the act's ask - the three goals to chase, and the whole-act
	# challenge when one was rolled. Cash in from the first number on; each further
	# goal is the gamble.
	if booking_active:
		var has_enc := encore >= 0 and encore < ENCORES.size()
		var bw := 400.0
		var bh := 130.0 if has_enc else 76.0
		var bx := s.x - 18.0 - bw
		var by2 := s.y - 88.0 - bh
		hud_panel(Rect2(bx, by2, bw, bh))
		draw_string(font, Vector2(bx + 16.0, by2 + 24.0), "THE ACT  -  cash in at any goal", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.85, 0.72, 0.55, 0.9 * tagA))
		draw_string(font, Vector2(bx + 16.0, by2 + 54.0), "goals  %s  ·  %s  ·  %s" % [
			commafy(goal_for(establish_venue, 0)), commafy(goal_for(establish_venue, 1)), commafy(goal_for(establish_venue, 2))],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color(1.0, 0.88, 0.5, tagA))
		if has_enc:
			var enc: Dictionary = ENCORES[encore]
			var ec := Color(1.0, 0.55, 0.4)
			draw_string(font, Vector2(bx + 16.0, by2 + 82.0), "TONIGHT'S CHALLENGE:  %s" % String(enc["name"]).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(ec.r, ec.g, ec.b, 0.95 * tagA))
			draw_multiline_string(font, Vector2(bx + 16.0, by2 + 102.0), String(enc["desc"]),
				HORIZONTAL_ALIGNMENT_LEFT, bw - 32.0, 11, 2, Color(0.9, 0.82, 0.72, 0.85 * tagA))

	var pulse := 0.6 + 0.4 * sin(float(cine_tick) * 0.08)
	draw_string(font, Vector2(0, s.y - 34.0), "press any key to begin", HORIZONTAL_ALIGNMENT_CENTER, s.x, 18, Color(1.0, 0.9, 0.6, 0.5 + 0.5 * pulse))


# --- the victory screen: shown once the top stage is conquered ----------------

func draw_credits(font: Font, s: Vector2) -> void:
	var cx := s.x * 0.5
	# the royal backdrop shared with the menu
	draw_gradient_v(Rect2(0, 0, s.x, s.y), Color(0.10, 0.05, 0.07), Color(0.02, 0.015, 0.025), 24)
	draw_spotlight_cone(s, cx, 0.08)
	draw_dust(s, 26, Color(1.0, 0.85, 0.55))
	# the calm cascade keeps watch up high while the roll climbs beneath it
	draw_menu_cascade(Vector2(cx, s.y * 0.12), 0.8)

	# assemble the roll as a stack of rows in content space. Each row sits a fixed
	# gap below the one before it, and cine_tick scrolls the whole stack upward. It
	# opens on the win, then rolls the credits and a line of your own career.
	var gold := Color(1.0, 0.88, 0.5)
	var rows: Array[Dictionary] = []
	var cur := 0.0
	cur += 40.0;  rows.append({"y": cur, "kind": "title", "a": "IACTO", "b": ""})
	cur += 84.0;  rows.append({"y": cur, "kind": "win", "a": "WORLD'S GREATEST JUGGLER", "b": ""})
	cur += 44.0;  rows.append({"y": cur, "kind": "sub", "a": "every stage, conquered", "b": ""})
	cur += 60.0;  rows.append({"y": cur, "kind": "orn", "a": "", "b": ""})
	cur += 78.0;  rows.append({"y": cur, "kind": "line", "a": "best score   %d" % int(career["best_score"]), "b": "%d day%s on the road" % [day, "" if day == 1 else "s"]})
	cur += 90.0;  rows.append({"y": cur, "kind": "orn", "a": "", "b": ""})
	cur += 82.0;  rows.append({"y": cur, "kind": "role", "a": "design", "b": "Louis Vandenbruwaene"})
	cur += 66.0;  rows.append({"y": cur, "kind": "role", "a": "code", "b": "Louis Vandenbruwaene"})
	cur += 66.0;  rows.append({"y": cur, "kind": "role", "a": "art", "b": "Louis Vandenbruwaene"})
	cur += 66.0;  rows.append({"y": cur, "kind": "role", "a": "music", "b": "Louis Vandenbruwaene"})
	cur += 84.0;  rows.append({"y": cur, "kind": "orn", "a": "", "b": ""})
	cur += 84.0;  rows.append({"y": cur, "kind": "line", "a": "made in Godot, every picture and sound", "b": "drawn and synthesised in code"})
	cur += 90.0;  rows.append({"y": cur, "kind": "line", "a": "built with the help of Claude", "b": ""})
	cur += 118.0; rows.append({"y": cur, "kind": "thanks", "a": "thank you for playing", "b": ""})
	var last_y := cur

	# the scroll: slow enough that the whole roll takes about 100 seconds at 60 fps
	var speed := 0.20
	var scroll := float(cine_tick) * speed
	var base := s.y * 0.56   # where content y 0 rests before any scrolling

	for row in rows:
		var ry := base + float(row["y"]) - scroll
		if ry < -80.0 or ry > s.y + 80.0:
			continue   # off the top or bottom, nothing to draw
		# soft edge fades so a line melts in near the bottom and out near the top,
		# which also keeps text clear of the cascade riding above
		var a := 1.0
		if ry > s.y - 150.0:
			a = clampf((s.y - ry) / 150.0, 0.0, 1.0)
		if ry < 150.0:
			a = minf(a, clampf(ry / 150.0, 0.0, 1.0))
		var kind := String(row["kind"])
		var atxt := String(row["a"])
		var btxt := String(row["b"])
		match kind:
			"title":
				draw_iacto_logo(font, ry - 49.0, 76, Color(gold.r, gold.g, gold.b, a), s)
			"sub":
				draw_string(font, Vector2(0, ry), atxt, HORIZONTAL_ALIGNMENT_CENTER, s.x, 24, Color(0.9, 0.8, 0.68, a))
			"orn":
				draw_ornament(cx, ry, 150.0, Color(0.82, 0.62, 0.34, 0.8 * a))
			"role":
				draw_string(font, Vector2(0, ry - 8.0), atxt, HORIZONTAL_ALIGNMENT_CENTER, s.x, 17, Color(0.82, 0.7, 0.52, 0.85 * a))
				draw_string(font, Vector2(0, ry + 22.0), btxt, HORIZONTAL_ALIGNMENT_CENTER, s.x, 27, Color(gold.r, gold.g, gold.b, a))
			"line":
				draw_string(font, Vector2(0, ry), atxt, HORIZONTAL_ALIGNMENT_CENTER, s.x, 21, Color(0.92, 0.86, 0.76, a))
				if btxt != "":
					draw_string(font, Vector2(0, ry + 28.0), btxt, HORIZONTAL_ALIGNMENT_CENTER, s.x, 21, Color(0.92, 0.86, 0.76, a))
			"win":
				draw_string(font, Vector2(0, ry), atxt, HORIZONTAL_ALIGNMENT_CENTER, s.x, 30, Color(1.0, 0.86, 0.42, a))
			"thanks":
				draw_string(font, Vector2(0, ry), atxt, HORIZONTAL_ALIGNMENT_CENTER, s.x, 30, Color(1.0, 0.9, 0.6, a))

	# once the last line has climbed past centre the roll settles into a held final
	# IACTO card, which waits, unmoving, for any key. The scrolling text is above it
	# by then, so the two never overlap.
	var last_sy := base + last_y - scroll
	if last_sy < s.y * 0.30:
		var fa := clampf((s.y * 0.30 - last_sy) / 140.0, 0.0, 1.0)
		var fy := s.y * 0.42
		draw_iacto_logo(font, fy - 55.0, 84, Color(1.0, 0.9, 0.55, fa), s)
		draw_ornament(cx, fy + 44.0, 175.0, Color(0.82, 0.62, 0.34, 0.85 * fa))
		draw_string(font, Vector2(0, fy + 86.0), "press any key", HORIZONTAL_ALIGNMENT_CENTER, s.x, 15, Color(0.82, 0.72, 0.6, 0.65 * fa))

	draw_vignette(s, 0.55)
	draw_frame(s, 22.0, Color(0.82, 0.62, 0.34, 0.5))


#endregion

#region SHARED VISUAL HELPERS
# --- shared premium-look helpers ---------------------------------------------

func draw_gradient_v(r: Rect2, top: Color, bot: Color, steps: int = 22) -> void:
	# a vertical gradient, drawn as stacked strips (no shaders, per the art rule).
	# Strips TILE exactly (each one's bottom is the next one's top) rather than
	# overlapping: an overlap doubled the alpha of semi-transparent gradients at
	# every seam, which showed as dark horizontal lines (e.g. over the menu balls).
	var n := maxi(1, steps)
	for i in n:
		var f := float(i) / float(n)
		var y0 := r.position.y + r.size.y * float(i) / float(n)
		var y1 := r.position.y + r.size.y * float(i + 1) / float(n)
		draw_rect(Rect2(r.position.x, y0, r.size.x, y1 - y0), top.lerp(bot, f))


func draw_gradient_h(r: Rect2, left: Color, right: Color, steps: int = 22) -> void:
	# strips TILE exactly (each one's right edge is the next one's left), like
	# draw_gradient_v. The old version overlapped strips by 1px, which doubled the
	# alpha of a semi-transparent gradient at every seam and showed as faint vertical
	# lines (visible in the vignette bands over the sky). Exact tiling removes them.
	var n := maxi(1, steps)
	for i in n:
		var f := float(i) / float(n)
		var x0 := r.position.x + r.size.x * float(i) / float(n)
		var x1 := r.position.x + r.size.x * float(i + 1) / float(n)
		draw_rect(Rect2(x0, r.position.y, x1 - x0, r.size.y), left.lerp(right, f))


func draw_vignette(s: Vector2, strength: float = 0.55) -> void:
	# darken the four edges so the eye is pulled to the lit centre. This one cheap
	# trick is most of what makes a flat scene read as photographed and rich.
	var band := 170.0
	var dk := Color(0.02, 0.008, 0.02, strength)
	var clear := Color(0.02, 0.008, 0.02, 0.0)
	draw_gradient_v(Rect2(0, 0, s.x, band), dk, clear, 18)
	draw_gradient_v(Rect2(0, s.y - band, s.x, band), clear, dk, 18)
	draw_gradient_h(Rect2(0, 0, band, s.y), dk, clear, 18)
	draw_gradient_h(Rect2(s.x - band, 0, band, s.y), clear, dk, 18)


func draw_letterbox(s: Vector2, top: float, bot: float) -> void:
	draw_rect(Rect2(0, 0, s.x, top), Color(0.02, 0.01, 0.02, 1.0))
	draw_rect(Rect2(0, s.y - bot, s.x, bot), Color(0.02, 0.01, 0.02, 1.0))
	draw_line(Vector2(0, top), Vector2(s.x, top), Color(0.8, 0.6, 0.32, 0.5), 1.5)
	draw_line(Vector2(0, s.y - bot), Vector2(s.x, s.y - bot), Color(0.8, 0.6, 0.32, 0.5), 1.5)


func draw_frame(s: Vector2, inset: float, col: Color) -> void:
	# a royal double gold border with small corner ticks
	var r := Rect2(inset, inset, s.x - 2.0 * inset, s.y - 2.0 * inset)
	draw_rect(r, col, false, 2.0)
	var r2 := r.grow(-6.0)
	draw_rect(r2, Color(col.r, col.g, col.b, col.a * 0.5), false, 1.0)
	var t := 16.0
	for c in [r.position, Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), r.end]:
		var sx := 1.0 if c.x < s.x * 0.5 else -1.0
		var sy := 1.0 if c.y < s.y * 0.5 else -1.0
		draw_line(c, c + Vector2(sx * t, 0), col, 3.0)
		draw_line(c, c + Vector2(0, sy * t), col, 3.0)


func draw_ornament(cx: float, y: float, half_w: float, col: Color) -> void:
	# a thin rule with a centre diamond and end dots, a classic decorative flourish
	draw_line(Vector2(cx - half_w, y), Vector2(cx - 10.0, y), col, 2.0)
	draw_line(Vector2(cx + 10.0, y), Vector2(cx + half_w, y), col, 2.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx, y - 5.0), Vector2(cx + 6.0, y), Vector2(cx, y + 5.0), Vector2(cx - 6.0, y)]), col)
	draw_circle(Vector2(cx - half_w, y), 2.5, col)
	draw_circle(Vector2(cx + half_w, y), 2.5, col)


func draw_title_glow(font: Font, y: float, text: String, size: int, col: Color, s: Vector2) -> void:
	draw_string(font, Vector2(2, y + 2.0 + float(size)), text, HORIZONTAL_ALIGNMENT_CENTER, s.x, size, Color(0, 0, 0, 0.55))
	draw_string(font, Vector2(0, y + float(size)), text, HORIZONTAL_ALIGNMENT_CENTER, s.x, size, col)


func draw_iacto_logo(font: Font, y: float, size: int, col: Color, s: Vector2) -> void:
	# the wordmark: I ACT followed by a juggling ball as the lowercase o - the name
	# is the sentence "I act", and the ball finishes it. The o is a REAL drawn ball
	# (glossy highlight and all), never a letterform, and it bobs very slightly, a
	# prop at the top of a tiny toss.
	var text := "I ACT "
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var br := float(size) * 0.30           # ball radius, sized like a lowercase o
	var total := tw + br * 2.0
	var x := s.x * 0.5 - total * 0.5
	var base := y + float(size)            # same baseline convention as draw_title_glow
	draw_string(font, Vector2(x + 2.0, base + 2.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.55 * col.a))
	draw_string(font, Vector2(x, base), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
	var bob := 3.0 * sin(float(cine_tick) * 0.045)
	var bc := Vector2(x + tw + br, base - br * 1.08 + bob)
	draw_circle(bc + Vector2(2.5, 2.5), br, Color(0, 0, 0, 0.35 * col.a))
	draw_circle(bc, br * 1.5, Color(1.0, 0.82, 0.35, 0.10 * col.a))   # the soft flight halo
	var ball := ball_color(0)
	ball.a = col.a
	draw_ball_shape(bc, ball, br / 11.0)


func draw_dust(s: Vector2, n: int, glow: Color) -> void:
	# warm motes drifting up through the light, a subtle atmosphere layer
	for i in n:
		var seed := float(i) * 41.3
		var bx := fposmod(sin(seed) * 43758.5, 1.0)
		var speed := 0.15 + fposmod(cos(seed) * 12.9, 1.0) * 0.25
		var by := fposmod(0.9 - atick() * 0.0008 * speed - float(i) * 0.13, 1.0)
		var px := bx * s.x + sin(atick() * 0.01 + seed) * 12.0
		var py := by * s.y
		var a := 0.10 + 0.10 * sin(atick() * 0.03 + seed)
		draw_circle(Vector2(px, py), 1.4, Color(glow.r, glow.g, glow.b, maxf(0.0, a)))


#endregion

#region PARTICLE EFFECTS & POPUPS
func spawn_egg_break(at: Vector2) -> void:
	var floor_y := get_viewport_rect().size.y * 0.80
	for i in 8:
		var ang := randf_range(-PI, 0.0)   # shell flies upward and out
		var spd := randf_range(2.2, 5.2)
		shards.append({
			"pos": at + Vector2(randf_range(-4, 4), randf_range(-4, 4)),
			"vel": Vector2(cos(ang), sin(ang)) * spd,
			"ang": randf_range(0.0, TAU), "spin": randf_range(-0.4, 0.4),
			"born": tick, "floor": floor_y + randf_range(-4, 6)})
	splats.append({"pos": Vector2(at.x + randf_range(-8, 8), floor_y + randf_range(-2, 4)),
		"r": 3.0, "born": tick})


# --- the cosmetic particle layer: sparks, embers, confetti, shock rings --------
# Spawned on catches, drops, records and torches; stepped here, never in the sim,
# and drawn late so the juice sits over the stage. All positions use the global
# randf (cosmetic RNG), so the deterministic sim rng is never consumed.

func spawn_parts(at: Vector2, col: Color, n: int, spd: float, kind: String = "spark") -> void:
	for _i in n:
		var ang := randf_range(-PI, PI) if kind != "confetti" else randf_range(-PI * 0.8, -PI * 0.2)
		var v := Vector2(cos(ang), sin(ang)) * randf_range(spd * 0.4, spd)
		if kind == "spark":
			v.y -= spd * 0.5   # sparks kick upward off the impact
		var life := 34
		if kind == "confetti":
			life = 90
		elif kind == "ring":
			life = 18   # a quick pulse; a lingering circle reads as clutter
		parts.append({"kind": kind, "pos": at + Vector2(randf_range(-3, 3), randf_range(-3, 3)),
			"vel": v, "col": col, "born": tick, "life": life,
			"seed": randf() * TAU, "r": randf_range(1.6, 3.0)})


func step_parts() -> void:
	if parts.is_empty():
		return
	var keep: Array[Dictionary] = []
	for d in parts:
		var v: Vector2 = d["vel"]
		match String(d["kind"]):
			"spark":
				v.y += 0.16
				v *= 0.96
			"ember":
				v.y -= 0.05   # embers drift up off the flame
				v.x += sin(float(tick) * 0.2 + float(d["seed"])) * 0.05
				v *= 0.98
			"confetti":
				v.y = minf(v.y + 0.10, 1.4)   # flutter down, swaying
				v.x = sin(float(tick) * 0.11 + float(d["seed"])) * 1.1
			"ring":
				pass
		d["vel"] = v
		d["pos"] = Vector2(d["pos"]) + v
		if tick - int(d["born"]) < int(d["life"]):
			keep.append(d)
	parts = keep


func draw_parts() -> void:
	for d in parts:
		var age := tick - int(d["born"])
		var f := clampf(1.0 - float(age) / float(int(d["life"])), 0.0, 1.0)
		var p: Vector2 = d["pos"]
		var c: Color = d["col"]
		match String(d["kind"]):
			"ring":
				# an expanding shockwave stroke that thins as it grows
				var rr := 14.0 + float(age) * 2.6
				draw_arc(p, rr, 0.0, TAU, 40, Color(c.r, c.g, c.b, 0.5 * f), maxf(1.0, 3.5 * f), true)
			"confetti":
				var ang := float(d["seed"]) + float(age) * 0.12
				draw_set_transform(p, ang, Vector2.ONE)
				draw_rect(Rect2(-3.0, -1.6, 6.0, 3.2), Color(c.r, c.g, c.b, 0.9 * f))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"ember":
				draw_circle(p, float(d["r"]) * (0.6 + 0.4 * f), Color(c.r, c.g, c.b, 0.7 * f))
			_:
				draw_circle(p, float(d["r"]) * f + 0.6, Color(c.r, c.g, c.b, 0.9 * f))


func step_effects() -> void:
	step_parts()
	# lit torches shed a lazy ember now and then, so fire reads as fire
	if tick % 9 == 0:
		for b in balls:
			if b.kind == PROP_TORCHES and b.state == STATE_FLIGHT:
				spawn_parts(flight_pos(b) + Vector2(0, -10), Color(1.0, 0.6, 0.2), 1, 0.7, "ember")
	var keep_sh: Array[Dictionary] = []
	for d in shards:
		var v: Vector2 = d["vel"]
		v.y += 0.28   # gravity
		v *= 0.995
		var p: Vector2 = d["pos"] + v
		if p.y >= float(d["floor"]):
			p.y = float(d["floor"])
			v = Vector2(v.x * 0.4, -v.y * 0.25)   # a small bounce, then settle
			if absf(v.y) < 0.6:
				v.y = 0.0
		d["pos"] = p
		d["vel"] = v
		d["ang"] = float(d["ang"]) + float(d["spin"])
		if tick - int(d["born"]) < 150:
			keep_sh.append(d)
	shards = keep_sh
	var keep_sp: Array[Dictionary] = []
	for d in splats:
		d["r"] = minf(float(d["r"]) + 0.9, 16.0)   # the yolk spreads then holds
		if tick - int(d["born"]) < 260:
			keep_sp.append(d)
	splats = keep_sp
	# dropped props falling to the stage floor: eggs break on LANDING, everything
	# else bounces once, rests a moment, then fades away
	var floor_y := get_viewport_rect().size.y * 0.80
	var keep_f: Array[Dictionary] = []
	for d in falling:
		if int(d["rest"]) >= 0:
			if tick - int(d["rest"]) < 70:
				keep_f.append(d)
			continue
		var v: Vector2 = d["vel"]
		v.y += 0.28
		var p: Vector2 = d["pos"] + v
		d["ang"] = float(d["ang"]) + float(d["spin"])
		if p.y >= floor_y:
			if int(d["kind"]) == PROP_EGGS:
				spawn_egg_break(Vector2(p.x, floor_y))
				play_sfx("splat", -8.0)
				add_popup(Vector2(p.x, floor_y - 14.0), "SPLAT", Color(1.0, 0.32, 0.3))
				continue   # the egg is shards and yolk now
			if not bool(d["bounced"]):
				d["bounced"] = true
				p.y = floor_y
				v = Vector2(v.x * 0.5, -absf(v.y) * 0.35)
				play_sfx(_catch_sound(int(d["kind"])), -22.0, 0.6)   # a dull floor knock
			else:
				p.y = floor_y
				v = Vector2.ZERO
				d["rest"] = tick
		d["pos"] = p
		d["vel"] = v
		keep_f.append(d)
	falling = keep_f


func draw_falling() -> void:
	# the lost props on their way down, and briefly at rest on the boards
	for d in falling:
		var p: Vector2 = d["pos"]
		var a := 1.0
		if int(d["rest"]) >= 0:
			a = clampf(1.0 - float(tick - int(d["rest"])) / 70.0, 0.0, 1.0)
		var col: Color = d["col"]
		col.a *= a
		var sc := prop_scale(int(d["kind"])) * 0.95   # a dropped prop keeps the size it flew at
		match int(d["kind"]):
			PROP_EGGS:
				draw_egg(p, col, sc)
			PROP_RINGS:
				draw_ring_prop(p, col, sc)
			PROP_CLUBS:
				draw_club(p, float(d["ang"]), sc)
			PROP_KNIVES:
				draw_knife(p, float(d["ang"]), sc)
			PROP_TORCHES:
				draw_torch(p, float(d["ang"]), sc)
			_:
				draw_ball_shape(p, col, sc)


func draw_egg_splats() -> void:
	for d in splats:
		var age := tick - int(d["born"])
		var a := clampf(1.0 - float(age) / 260.0, 0.0, 1.0)
		var p: Vector2 = d["pos"]
		var r: float = d["r"]
		fill_ellipse(p, r, r * 0.4, Color(0.95, 0.82, 0.35, 0.5 * a))       # spread yolk
		draw_circle(p, r * 0.45, Color(1.0, 0.7, 0.2, 0.8 * a))             # bright centre
		fill_ellipse(p + Vector2(r * 0.8, 1.0), r * 0.3, r * 0.16, Color(0.97, 0.9, 0.7, 0.4 * a))


func draw_egg_shards() -> void:
	var shell := Color(0.97, 0.93, 0.84)
	var shell_dk := Color(0.85, 0.80, 0.70)
	for d in shards:
		var age := tick - int(d["born"])
		var a := clampf(1.0 - float(age) / 150.0, 0.0, 1.0)
		var p: Vector2 = d["pos"]
		var ang: float = d["ang"]
		# a little curved shell fragment
		draw_set_transform(p, ang, Vector2.ONE)
		draw_colored_polygon(PackedVector2Array([
			Vector2(-4, 1), Vector2(0, -4), Vector2(4, 1), Vector2(0, 3)]),
			Color(shell.r, shell.g, shell.b, a))
		draw_line(Vector2(-4, 1), Vector2(4, 1), Color(shell_dk.r, shell_dk.g, shell_dk.b, a), 1.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func draw_text_shout(font: Font, pos: Vector2, text: String, align: int, width: float, size: int, col: Color) -> void:
	# floating STAGE text - popups, shouts, warnings, prompts - rides over whatever the
	# venue paints (a lit-window skyline, a warm spotlight), so it carries a dark outline
	# to stay legible on any of them without moving off the spot it belongs to (Louis).
	var oc := Color(0.04, 0.02, 0.03, col.a * 0.9)
	for o in [Vector2(-1.5, 0.0), Vector2(1.5, 0.0), Vector2(0.0, -1.5), Vector2(0.0, 1.5),
			Vector2(-1.1, -1.1), Vector2(1.1, -1.1), Vector2(-1.1, 1.1), Vector2(1.1, 1.1)]:
		draw_string(font, pos + o, text, align, width, size, oc)
	draw_string(font, pos, text, align, width, size, col)


func draw_popups(font: Font) -> void:
	for p in popups:
		var age := tick - int(p["born"])
		var a := clampf(1.0 - float(age) / 46.0, 0.0, 1.0)
		var pos: Vector2 = p["pos"] + Vector2(0, -float(age) * 0.6)
		var c: Color = p["col"]
		c.a = a
		var txt := String(p["text"])
		# the big moments land bigger, with a quick settle from oversized to rest
		var big := txt == "PERFECT" or txt == "NEW RECORD!" or txt.begins_with("LEVEL") or txt.ends_with("STREAK")
		var size := 18
		if big:
			size = 23 + maxi(0, 6 - age)
		# the box is 240 wide, so its LEFT edge sits half that from the anchor: the
		# old -60 offset centred every popup 60px right of the hand it belonged to
		draw_text_shout(font, pos - Vector2(120.0, 0), txt, HORIZONTAL_ALIGNMENT_CENTER, 240, size, c)


#endregion

#region VENUE EXTERIOR ART (CUTSCENES)
# --- venue exteriors: the "where", shared by establishing cards and wide shots -

func draw_venue_exterior(s: Vector2, vi: int) -> void:
	match vi:
		0: ext_backyard(s)
		1: ext_street(s)
		2: ext_theatre(s)
		3: ext_circus(s)
		4: ext_champ(s)
		_: ext_arena(s)


func ext_backyard(s: Vector2) -> void:
	# ext_center puts the house mid-frame (the day hub composes around it); the
	# story scenes keep it right of frame so the figures own the middle
	var hx := s.x * (0.5 if ext_center else 0.74)
	var gy := s.y * 0.66
	draw_gradient_v(Rect2(0, 0, s.x, gy), Color(0.13, 0.15, 0.28), Color(0.72, 0.46, 0.32), 26)
	draw_circle(Vector2(s.x * 0.78, gy - 26.0), 62.0, Color(1.0, 0.72, 0.4, 0.22))
	draw_circle(Vector2(s.x * 0.78, gy - 26.0), 34.0, Color(1.0, 0.84, 0.52, 0.45))
	draw_stars(s, 22, 0.3)
	draw_gradient_v(Rect2(0, gy, s.x, s.y - gy), Color(0.22, 0.28, 0.16), Color(0.07, 0.10, 0.06), 18)
	draw_tree(Vector2(s.x * 0.18, gy), 1.05)
	draw_house(Vector2(hx, gy), 158.0, 128.0)
	if ext_center:
		draw_fence(s, gy - 4.0, s.x * 0.62, s.x * 0.92)
	else:
		draw_fence(s, gy - 4.0, s.x * 0.30, s.x * 0.64)
	draw_grass(s, gy)
	draw_dust(s, 18, Color(1.0, 0.85, 0.55))


func ext_street(s: Vector2) -> void:
	var lx := s.x * (0.5 if ext_center else 0.32)
	var gy := s.y * 0.72
	draw_gradient_v(Rect2(0, 0, s.x, s.y), Color(0.04, 0.05, 0.12), Color(0.13, 0.10, 0.15), 26)
	draw_moon(Vector2(s.x * 0.82, s.y * 0.18), 24.0)
	draw_stars(s, 30, 0.42)
	draw_city_row(s, gy)
	draw_rect(Rect2(0, gy, s.x, s.y - gy), Color(0.09, 0.08, 0.10))
	draw_streetlamp(Vector2(lx, gy), gy)
	draw_hat_prop(Vector2(lx + 46.0, gy - 2.0))
	draw_dust(s, 16, Color(1.0, 0.8, 0.5))


func ext_theatre(s: Vector2) -> void:
	var gy := s.y * 0.80
	draw_gradient_v(Rect2(0, 0, s.x, s.y), Color(0.11, 0.06, 0.13), Color(0.32, 0.13, 0.15), 26)
	draw_stars(s, 16, 0.28)
	var fw := s.x * 0.64
	var fh := s.y * 0.52
	var fx := s.x * 0.5
	draw_rect(Rect2(fx - fw * 0.5, gy - fh, fw, fh), Color(0.15, 0.10, 0.11))
	draw_colored_polygon(PackedVector2Array([
		Vector2(fx - fw * 0.52, gy - fh), Vector2(fx + fw * 0.52, gy - fh), Vector2(fx, gy - fh - 58.0)]), Color(0.17, 0.11, 0.12))
	for k in 5:
		var cx := fx - fw * 0.5 + fw * (0.12 + 0.19 * float(k))
		draw_rect(Rect2(cx - 6.0, gy - fh + 30.0, 12.0, fh - 30.0), Color(0.21, 0.15, 0.14))
	var dw := fw * 0.24
	draw_rect(Rect2(fx - dw * 0.5, gy - fh * 0.46, dw, fh * 0.46), Color(1.0, 0.78, 0.4, 0.55))
	draw_circle(Vector2(fx, gy - fh * 0.46), dw * 0.5, Color(1.0, 0.78, 0.4, 0.55))
	draw_marquee(Vector2(fx, gy - fh * 0.66), fw * 0.5)
	draw_colored_polygon(PackedVector2Array([
		Vector2(fx - dw * 0.5, gy), Vector2(fx + dw * 0.5, gy), Vector2(fx + dw * 0.9, s.y), Vector2(fx - dw * 0.9, s.y)]), Color(0.5, 0.10, 0.12))
	draw_rect(Rect2(0, gy, s.x, s.y - gy), Color(0.10, 0.06, 0.07))
	draw_dust(s, 14, Color(1.0, 0.8, 0.5))


func ext_circus(s: Vector2) -> void:
	var gy := s.y * 0.76
	draw_gradient_v(Rect2(0, 0, s.x, s.y), Color(0.05, 0.05, 0.13), Color(0.15, 0.07, 0.10), 26)
	draw_moon(Vector2(s.x * 0.16, s.y * 0.18), 22.0)
	draw_stars(s, 28, 0.42)
	draw_rect(Rect2(0, gy, s.x, s.y - gy), Color(0.10, 0.08, 0.07))
	draw_bigtop(Vector2(s.x * 0.5, gy), s.x * 0.52, s.y * 0.46)
	draw_lantern_string(Vector2(s.x * 0.08, s.y * 0.30), Vector2(s.x * 0.92, s.y * 0.34))
	draw_dust(s, 16, Color(1.0, 0.8, 0.5))


func ext_champ(s: Vector2) -> void:
	var gy := s.y * 0.78
	draw_gradient_v(Rect2(0, 0, s.x, s.y), Color(0.05, 0.07, 0.15), Color(0.10, 0.13, 0.21), 26)
	draw_stars(s, 20, 0.34)
	draw_rect(Rect2(0, gy, s.x, s.y - gy), Color(0.08, 0.09, 0.12))
	draw_arena_bowl(Vector2(s.x * 0.5, gy), s.x * 0.72, s.y * 0.42, Color(0.16, 0.18, 0.24), Color(0.6, 0.8, 1.0))
	for bx in [s.x * 0.20, s.x * 0.36, s.x * 0.64, s.x * 0.80]:
		draw_banner(Vector2(bx, gy - s.y * 0.30), Color(0.3, 0.5, 0.9))
	draw_rect(Rect2(s.x * 0.5 - 42.0, gy - 92.0, 84.0, 92.0), Color(0.7, 0.85, 1.0, 0.4))
	for fx in [s.x * 0.30, s.x * 0.70]:
		draw_circle(Vector2(fx, s.y * 0.20), 42.0, Color(0.8, 0.9, 1.0, 0.12))
	draw_dust(s, 12, Color(0.8, 0.9, 1.0))


func ext_arena(s: Vector2) -> void:
	var gy := s.y * 0.80
	draw_gradient_v(Rect2(0, 0, s.x, s.y), Color(0.03, 0.03, 0.08), Color(0.07, 0.05, 0.12), 26)
	draw_stars(s, 46, 0.55)
	for k in 3:
		var ang := -PI * 0.5 + sin(float(cine_tick) * 0.01 + float(k) * 2.1) * 0.5
		var src := Vector2(s.x * (0.2 + 0.3 * float(k)), gy - s.y * 0.18)
		var dir := Vector2(cos(ang), sin(ang))
		var perp := Vector2(-dir.y, dir.x) * 28.0
		draw_colored_polygon(PackedVector2Array([src, src + dir * 620.0 + perp, src + dir * 620.0 - perp]), Color(0.9, 0.85, 0.7, 0.05))
	draw_arena_bowl(Vector2(s.x * 0.5, gy), s.x * 0.96, s.y * 0.5, Color(0.10, 0.09, 0.16), Color(1.0, 0.85, 0.5))
	for i in 120:
		var seed := float(i) * 17.7
		var x := s.x * 0.5 + (fposmod(sin(seed) * 99.0, 1.0) - 0.5) * s.x * 0.7
		var y := gy - fposmod(cos(seed) * 71.0, 1.0) * s.y * 0.26 - 12.0
		var a := 0.3 + 0.4 * sin(float(cine_tick) * 0.05 + seed)
		draw_circle(Vector2(x, y), 1.5, Color(1.0, 0.8, 0.5, clampf(a, 0.1, 0.7)))
	draw_dust(s, 20, Color(1.0, 0.85, 0.55))


# --- exterior building / prop primitives -------------------------------------

func draw_stars(s: Vector2, n: int, topfrac: float) -> void:
	for i in n:
		var seed := float(i) * 23.13
		var x := fposmod(sin(seed) * 43758.5, 1.0) * s.x
		var y := fposmod(cos(seed) * 24137.0, 1.0) * s.y * topfrac
		var a := 0.3 + 0.5 * sin(atick() * 0.04 + seed)
		draw_circle(Vector2(x, y), 1.3, Color(1, 1, 1, clampf(a, 0.05, 0.7)))


func draw_moon(pos: Vector2, r: float) -> void:
	draw_circle(pos, r * 1.8, Color(0.9, 0.9, 0.8, 0.08))
	draw_circle(pos, r, Color(0.96, 0.95, 0.86, 0.9))
	draw_circle(pos + Vector2(r * 0.4, -r * 0.2), r * 0.85, Color(0.9, 0.88, 0.78, 0.2))


func draw_house(base: Vector2, w: float, h: float) -> void:
	draw_rect(Rect2(base.x - w * 0.5, base.y - h, w, h), Color(0.10, 0.09, 0.11))
	draw_colored_polygon(PackedVector2Array([
		Vector2(base.x - w * 0.6, base.y - h), Vector2(base.x + w * 0.6, base.y - h), Vector2(base.x, base.y - h - h * 0.5)]), Color(0.07, 0.06, 0.08))
	# a squarer four-pane window with a full cross muntin: the old tall two-pane
	# version read as a giant pause icon (Louis spotted it immediately)
	var flick := 0.7 + 0.3 * sin(atick() * 0.05)
	var ww := w * 0.24
	var wh := h * 0.24
	var wx := base.x - w * 0.22
	var wy := base.y - h * 0.62
	draw_circle(Vector2(wx + ww * 0.5, wy + wh * 0.5), w * 0.3, Color(1.0, 0.7, 0.3, 0.12 * flick))
	draw_rect(Rect2(wx, wy, ww, wh), Color(1.0, 0.78, 0.4, 0.92 * flick))
	draw_rect(Rect2(wx, wy, ww, wh), Color(0.2, 0.12, 0.06), false, 2.0)
	draw_line(Vector2(wx + ww * 0.5, wy), Vector2(wx + ww * 0.5, wy + wh), Color(0.2, 0.12, 0.06), 2.0)
	draw_line(Vector2(wx, wy + wh * 0.5), Vector2(wx + ww, wy + wh * 0.5), Color(0.2, 0.12, 0.06), 2.0)


func draw_tree(base: Vector2, sc: float) -> void:
	draw_rect(Rect2(base.x - 6.0 * sc, base.y - 70.0 * sc, 12.0 * sc, 70.0 * sc), Color(0.10, 0.08, 0.07))
	var c := Color(0.09, 0.15, 0.09)
	for o in [Vector2(0, -82), Vector2(-22, -66), Vector2(22, -68), Vector2(-10, -98), Vector2(12, -94)]:
		draw_circle(base + o * sc, 27.0 * sc, c)


func draw_fence(s: Vector2, y: float, x0: float, x1: float) -> void:
	var col := Color(0.14, 0.11, 0.09)
	draw_rect(Rect2(x0, y - 2.0, x1 - x0, 4.0), col)
	var x := x0
	while x <= x1:
		draw_rect(Rect2(x, y - 22.0, 5.0, 22.0), col)
		draw_colored_polygon(PackedVector2Array([Vector2(x, y - 22.0), Vector2(x + 5.0, y - 22.0), Vector2(x + 2.5, y - 28.0)]), col)
		x += 18.0


func draw_grass(s: Vector2, y: float) -> void:
	var col := Color(0.13, 0.20, 0.10)
	var x := 0.0
	while x < s.x:
		var hgt := 6.0 + fposmod(sin(x) * 20.0, 1.0) * 8.0
		draw_line(Vector2(x, y + 6.0), Vector2(x + sin(atick() * 0.02 + x) * 2.0, y + 6.0 - hgt), col, 2.0)
		x += 14.0


func draw_city_row(s: Vector2, gy: float) -> void:
	var xs := [0.0, s.x * 0.14, s.x * 0.30, s.x * 0.50, s.x * 0.66, s.x * 0.82]
	var hs := [0.34, 0.50, 0.42, 0.56, 0.38, 0.48]
	for i in xs.size():
		var bw := s.x * 0.17
		var bh: float = s.y * float(hs[i])
		var bx: float = float(xs[i])
		draw_rect(Rect2(bx, gy - bh, bw, bh), Color(0.07, 0.07, 0.10))
		var wy := gy - bh + 12.0
		while wy < gy - 14.0:
			var wx := bx + 8.0
			while wx < bx + bw - 12.0:
				var lit := fposmod(sin(wx * 3.1 + wy * 1.7 + float(i)) * 99.0, 1.0) > 0.62
				draw_rect(Rect2(wx, wy, 7.0, 9.0), Color(1.0, 0.8, 0.4, 0.8) if lit else Color(0.13, 0.13, 0.17, 0.9))
				wx += 14.0
			wy += 18.0


func draw_streetlamp(base: Vector2, gy: float) -> void:
	for k in range(6, 0, -1):
		draw_circle(Vector2(base.x, gy + 6.0), 20.0 + float(k) * 22.0, Color(1.0, 0.72, 0.36, 0.05 * (1.0 - float(k) / 7.0)))
	fill_ellipse(Vector2(base.x, gy + 4.0), 92.0, 20.0, Color(1.0, 0.7, 0.35, 0.12))
	draw_rect(Rect2(base.x - 3.0, base.y - 152.0, 6.0, 152.0), Color(0.06, 0.06, 0.08))
	draw_rect(Rect2(base.x - 3.0, base.y - 152.0, 30.0, 5.0), Color(0.06, 0.06, 0.08))
	var head := Vector2(base.x + 26.0, base.y - 150.0)
	draw_circle(head, 30.0, Color(1.0, 0.75, 0.4, 0.20))
	draw_colored_polygon(PackedVector2Array([
		Vector2(head.x - 8.0, head.y), Vector2(head.x + 8.0, head.y), Vector2(head.x + 5.0, head.y + 12.0), Vector2(head.x - 5.0, head.y + 12.0)]), Color(1.0, 0.85, 0.5))


func draw_hat_prop(pos: Vector2) -> void:
	fill_ellipse(pos, 26.0, 8.0, Color(0.10, 0.08, 0.09))
	draw_colored_polygon(PackedVector2Array([
		Vector2(pos.x - 14.0, pos.y), Vector2(pos.x + 14.0, pos.y), Vector2(pos.x + 10.0, pos.y - 18.0), Vector2(pos.x - 10.0, pos.y - 18.0)]), Color(0.13, 0.10, 0.11))
	draw_rect(Rect2(pos.x - 10.0, pos.y - 6.0, 20.0, 4.0), Color(0.7, 0.5, 0.3))


func draw_marquee(center: Vector2, w: float) -> void:
	var h := 34.0
	draw_rect(Rect2(center.x - w * 0.5, center.y - h * 0.5, w, h), Color(0.10, 0.07, 0.08))
	draw_rect(Rect2(center.x - w * 0.5, center.y - h * 0.5, w, h), Color(0.9, 0.7, 0.35), false, 2.0)
	var n := int(w / 16.0)
	for i in n:
		var on := ((i + int(atick() / 12.0)) % 2) == 0
		var bx := center.x - w * 0.5 + w * (float(i) + 0.5) / float(n)
		var col := Color(1.0, 0.85, 0.4) if on else Color(0.4, 0.3, 0.2)
		draw_circle(Vector2(bx, center.y - h * 0.5 - 4.0), 2.5, col)
		draw_circle(Vector2(bx, center.y + h * 0.5 + 4.0), 2.5, col)
	draw_string(game_font(), Vector2(center.x - w * 0.5, center.y + 6.0), "TONIGHT", HORIZONTAL_ALIGNMENT_CENTER, w, 18, Color(1.0, 0.85, 0.45))


func draw_bigtop(base: Vector2, w: float, h: float) -> void:
	var top := Vector2(base.x, base.y - h)
	var n := 10
	for i in n:
		var a0 := lerpf(-w * 0.5, w * 0.5, float(i) / float(n))
		var a1 := lerpf(-w * 0.5, w * 0.5, float(i + 1) / float(n))
		var col := Color(0.78, 0.20, 0.22) if i % 2 == 0 else Color(0.94, 0.90, 0.82)
		draw_colored_polygon(PackedVector2Array([top, Vector2(base.x + a0, base.y), Vector2(base.x + a1, base.y)]), col)
	draw_colored_polygon(PackedVector2Array([
		Vector2(base.x - 24.0, base.y), Vector2(base.x + 24.0, base.y), Vector2(base.x + 16.0, base.y - 70.0), Vector2(base.x - 16.0, base.y - 70.0)]), Color(0.08, 0.06, 0.06))
	draw_circle(Vector2(base.x, base.y - 70.0), 16.0, Color(0.08, 0.06, 0.06))
	draw_rect(Rect2(base.x - 30.0, base.y - 8.0, 60.0, 8.0), Color(0.6, 0.15, 0.15))
	draw_rect(Rect2(top.x - 2.0, top.y - 40.0, 4.0, 40.0), Color(0.3, 0.2, 0.14))
	var fl := sin(atick() * 0.1) * 6.0
	draw_colored_polygon(PackedVector2Array([Vector2(top.x + 2.0, top.y - 40.0), Vector2(top.x + 30.0, top.y - 34.0 + fl), Vector2(top.x + 2.0, top.y - 28.0)]), Color(0.95, 0.75, 0.3))


func draw_lantern_string(a: Vector2, b: Vector2) -> void:
	var n := 12
	for i in n + 1:
		var t := float(i) / float(n)
		var p := a.lerp(b, t)
		p.y += sin(t * PI) * 26.0   # a gentle sag
		if i < n:
			var t2 := float(i + 1) / float(n)
			var p2 := a.lerp(b, t2)
			p2.y += sin(t2 * PI) * 26.0
			draw_line(p, p2, Color(0.3, 0.2, 0.15), 1.5)
		var fl := 0.7 + 0.3 * sin(atick() * 0.08 + float(i))
		draw_circle(p, 7.0, Color(1.0, 0.72, 0.35, 0.18 * fl))
		draw_circle(p, 4.0, Color(1.0, 0.8, 0.4, fl))


func draw_arena_bowl(base: Vector2, w: float, h: float, body: Color, rim: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(base.x - w * 0.5, base.y), Vector2(base.x + w * 0.5, base.y),
		Vector2(base.x + w * 0.4, base.y - h), Vector2(base.x - w * 0.4, base.y - h)]), body)
	fill_ellipse(Vector2(base.x, base.y - h), w * 0.4, h * 0.16, body)
	draw_arc(Vector2(base.x, base.y - h), w * 0.4, PI, TAU, 44, Color(rim.r, rim.g, rim.b, 0.5), 3.0)
	draw_circle(Vector2(base.x, base.y - h), w * 0.30, Color(rim.r, rim.g, rim.b, 0.06))


func draw_banner(top: Vector2, col: Color) -> void:
	draw_rect(Rect2(top.x - 2.0, top.y, 4.0, 210.0), Color(0.1, 0.1, 0.12))
	var fl := sin(atick() * 0.12 + top.x) * 5.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(top.x + 2.0, top.y), Vector2(top.x + 40.0, top.y + 6.0 + fl), Vector2(top.x + 40.0, top.y + 30.0 + fl), Vector2(top.x + 2.0, top.y + 30.0)]), col)


func draw_spotlight_cone(s: Vector2, cx: float, strength: float) -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx, -30.0), Vector2(cx - 300.0, s.y * 0.86), Vector2(cx + 300.0, s.y * 0.86)]), Color(1.0, 0.85, 0.55, strength))


func draw_shadow(feet: Vector2, w: float) -> void:
	fill_ellipse(feet, w * 0.5, w * 0.16, Color(0, 0, 0, 0.3))


#endregion

#region DEV: AUTOPLAYER & SCREENSHOT CAPTURE
func _demo_step() -> void:
	# in a --booking demo the autoplayer cashes in the moment the FINAL goal falls, so
	# a whole act runs end to end (all three crossings, the resolve, the pay) and never
	# hangs at a venue whose crowd a low routine can sustain forever (v0/v1)
	if booking_active and goals_hit >= NUM_GOALS and running:
		finish_performance()
		return
	# auto-catch: secure any ball arriving at an empty hand (the odd-columns middle
	# ball counts for either hand, matching the either-hand rule in on_catch)
	for h in [LEFT, RIGHT]:
		if not stack(h).is_empty():
			continue
		for b in balls:
			if b.state == STATE_FLIGHT and (b.to_hand == h or b == col_mid_ball) and absi(b.land_tick - tick) <= 1:
				on_catch(h)
				break
	# dev trick preview: kick off a Spin whenever the pattern is full and cooled down
	# (in unpinned mode, or when Spin itself is the pinned trick)
	var pin_kind := String(TRICKS[_demo_trick_pin]["kind"]) if _demo_trick_pin >= 0 else ""
	if _demo_trick and (_demo_trick_pin == -1 or _demo_trick_pin == TR_SPIN) \
			and balls_airborne() >= 2 and tick >= trick_ready and tick >= 40:
		spin_until = tick + SPIN_TICKS
		spin_scored = false
		trick_ready = tick + TRICK_COOLDOWN
	# a pinned TOGGLE switches on once (one mimed Space press) and stays running
	if _demo_trick and pin_kind == "toggle" and toggle_on != _demo_trick_pin and tick >= 24:
		toggle_on = _demo_trick_pin
		toggle_scored = false
	# a tutorial's "switch it OFF" step needs the mime to let go again - outside a
	# lesson the point is showing the trick run, so this only fires once the lesson
	# has actually reached that step (never mid-drill, never in a bare --trick demo)
	if _demo_trick and tut_active and toggle_on == _demo_trick_pin \
			and String(tut_step_data().get("goal", "")) == "trick_off":
		toggle_on = -1
	# metronome: every beat, release one ball from a hand that actually holds one.
	# This can never desync because it only throws real held balls.
	if tick >= 24 and tick % DEMO_BEAT == 0:
		var h := _demo_next
		if stack(h).is_empty():
			h = other(h)
		if not stack(h).is_empty():
			if _demo_trick:
				# mimic a real Space press per throw for the one-shot (Overthrow);
				# the flourish toggles (High Toss / BTB) run via toggle_on, set
				# once above like any other toggle, so nothing to prime here
				if pin_kind == "arm":
					trick_sel = _demo_trick_pin
					trick_primed = true
				elif _demo_trick_pin == -1 and (tick / DEMO_BEAT) % 2 == 0:
					trick_sel = TR_OVER   # the lone remaining one-shot, shown each other beat
					trick_primed = true
			do_throw(h, _demo_hold)
			_demo_next = other(h)


func _capture_and_quit() -> void:
	if _collcheck:
		# the overlap audit's verdict: the tightest edge-to-edge clearance any two
		# airborne props reached this session (negative would be a visual overlap)
		print("collcheck min clearance: %.1f px" % _coll_min)
		print("collcheck at: %s" % _coll_at)
	# the audit needs no picture, and a picture is the only thing --headless cannot
	# give us (the viewport has no texture there). Asking for one anyway is what used
	# to force the whole pattern sweep through slow, wall-clock-bound windowed runs.
	if _shot_path != "":
		var tex := get_viewport().get_texture()
		if tex != null:
			var img := tex.get_image()
			if img != null:
				img.save_png(_shot_path)
	get_tree().quit()

#endregion