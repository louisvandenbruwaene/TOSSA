extends Node2D
## JUGGLE core mechanic, Prototype 1.1.
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
const INN_COST := 15       # a proper bed: full stamina on waking. It wants FULL
						   # payment now (Louis): a juggler who cannot afford the
						   # bed and cannot stand to busk has reached the end of
						   # the road, and the game says so honestly (game over)
const TIRED_FLOOR := 12.0  # below this stamina you cannot work, only sleep
const VENUE_PAY := 0.35    # each venue tier pays this much more than the last
const BUSK_FLOOR := 8      # a broke juggler always earns at least this from the hat
const BROKE_GOLD := 20     # the busking floor applies below this purse
const NUM_SLOTS := 3

# --- progression / stats meta (GDD Section 4; skill-first guardrails hold) -----
const SAVE_PATH_DEBUG := "user://juggle_debug.cfg"  # debug build: separate progress
const SAVE_PATH_DEMO := "user://juggle_demo.cfg"     # --demo/--shot autoplay: never a real career save
const SETTINGS_PATH := "user://juggle_settings.cfg" # global options, shared by slots
const POINTS_PER_LEVEL := 3
const ACC_MIN_FACTOR := 0.35  # inaccuracy floor at Accuracy 100: never zero, so a
							  # max-height throw always still demands a real catch
const STAM_DRAIN_CATCH := 0.4
const STAM_DRAIN_THROW := 0.3
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
# --- patterns as learnable content (GDD economy: harder base pays more, so one
# tamed routine is never optimal). P cycles the unlocked patterns in training.
# "mult" scales every catch's score, the reward for the pattern's base difficulty.
const PATTERNS := [
	{"id": "cascade",    "name": "Cascade",     "lvl": 1, "mult": 1.0,
	 "desc": "The weave. Every throw crosses to the other hand."},
	{"id": "fountain",   "name": "Fountain",    "lvl": 1, "mult": 1.1,
	 "desc": "Each hand juggles its own circle. Even counts feel natural."},
	{"id": "columns",    "name": "Columns",     "lvl": 3, "mult": 1.15,
	 "desc": "Straight up and down in fixed lanes; an odd count opens a middle lane too. Clean or nothing."},
	{"id": "halfshower", "name": "Half Shower", "lvl": 5, "mult": 1.25,
	 "desc": "The right hand throws over the top, the left keeps the weave."},
	{"id": "shower",     "name": "Shower",      "lvl": 8, "mult": 1.4,
	 "desc": "The full circle. Right throws high, left feeds fast and low."},
]
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
const MAX_BALLS_HARD := 7

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
	{"name": "Balls",   "weight": 1, "req": 0,  "cost": 0,    "spins": false},
	{"name": "Eggs",    "weight": 1, "req": 0,  "cost": 1,    "spins": false},
	{"name": "Rings",   "weight": 2, "req": 12, "cost": 200,  "spins": false},
	{"name": "Clubs",   "weight": 3, "req": 22, "cost": 500,  "spins": true},
	{"name": "Knives",  "weight": 4, "req": 34, "cost": 1000, "spins": true},
	{"name": "Torches", "weight": 5, "req": 48, "cost": 2000, "spins": true},
]
const WEIGHT_STAM := 0.25    # each weight step adds this fraction of stamina cost

# --- shop: spend gold on props and gear (ideas.rtf shop) ----------------------
const GLASSES_COST := 8000     # the only route to a 100%/80% catch ceiling (Section 1
								# of README.md): priced as the capstone purchase it now
								# functionally is, not a minor bonus on an already-full curve
const GLASSES_CATCH_BONUS := 0.20  # ideas.rtf: glasses raise the catch chance

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

# hand animation. Every hand rests at exactly one of three fixed points - never a
# predicted, in-between spot - and moves to a DIFFERENT one only in direct response
# to a throw or catch (Louis): no drifting ahead of the ball to meet it.
const HAND_SMOOTH := 0.22  # per-tick lerp of hand toward its target position
const HAND_OUTER := 0        # the catch point, standard
const HAND_INNER := 1        # the throw point, standard; also the catch point for
							  # anything riding the over-the-top road, and BOTH points
							  # for Columns (one rest slot, so the hand does not tremor)

# --- tricks (GDD Section 3): flourishes fired with the TRICK key (Space). C
# selects which trick Space is loaded with (the selection persists). THREE
# grammars (Louis): "toggle" switches ON with one press and OFF with the next,
# smoothly reshaping every throw in between (High Toss, Behind the Back, the
# columns lanes and over-the-top arcs) - for a single flourish you switch on,
# throw, and switch off; "arm" is the one-shot powerup (Overthrow only), one
# press empowers exactly the next throw; "live" acts on the balls already
# airborne (Spin). Each landed shaped catch pays its bonus, so a trick is a
# skill choice, never a free bonus. A running toggle SURVIVES an R restart in
# training, so a trick can be drilled run after run. Tricks unlock by level.
const TR_HIGH := 0
const TR_BTB := 1
const TR_SPIN := 2
const TR_OVER := 3
const TR_COLS := 4
const TR_WFALL := 5
const TR_RCASC := 6
const TR_TENNIS := 7
const TRICKS := [
	{"id": "high", "name": "High Toss",        "kind": "toggle", "lvl": 2, "min_air": 0, "bonus": 90,  "shout": "HIGH TOSS!",
	 "desc": "Toggle: every throw flies sky high - hold the throw and it climbs clean out of the frame. For a single toss, switch on, throw, switch off."},
	{"id": "btb",  "name": "Behind the Back",  "kind": "toggle", "lvl": 4, "min_air": 0, "bonus": 60,  "shout": "BEHIND THE BACK!",
	 "desc": "Toggle: every throw loops behind the back. Style the crowd loves, if you keep landing it."},
	{"id": "spin", "name": "Spin",             "kind": "live",   "lvl": 7, "min_air": 1, "bonus": 0,   "shout": "SPIN!",
	 "desc": "Spin the moment a ball is in the air. Catches score double, you catch blind."},
	{"id": "over", "name": "Overthrow",        "kind": "arm",    "lvl": 3, "min_air": 0, "bonus": 120, "shout": "OVERTHROW!",
	 "desc": "Power one throw up and OVER the top of the pattern."},
	{"id": "cols", "name": "Columns",          "kind": "toggle", "lvl": 5, "min_air": 0, "bonus": 30,  "shout": "columns",
	 "desc": "Toggle: every ball rides its own straight lane - an odd count opens a middle lane too."},
	{"id": "wfall", "name": "Waterfall",       "kind": "toggle", "lvl": 6, "min_air": 0, "bonus": 45,  "shout": "waterfall",
	 "desc": "Toggle: the right hand keeps throwing over the top."},
	{"id": "rcasc", "name": "Reverse Cascade", "kind": "toggle", "lvl": 9, "min_air": 0, "bonus": 60,  "shout": "reverse!",
	 "desc": "Toggle: BOTH hands throw over the top, the weave runs backward."},
	{"id": "tennis", "name": "Tennis",         "kind": "toggle", "lvl": 10, "min_air": 0, "bonus": 50, "shout": "tennis",
	 "desc": "Toggle: one marked ball sails over the top, back and forth."},
]
const SPIN_TICKS := 44             # how long a Spin lasts (about a third of a second)
const TRICK_COOLDOWN := 96         # ticks before a LIVE trick can fire again
# (per-trick score bonuses live in the TRICKS table's "bonus" field)

# --- slow motion (ideas.rtf): every source adds its share, stacking linearly.
# The Speed stat is permanent and capped, the Pie is a bought minute, the
# Amazing! frame-perfect catch and a run of ten straight Perfects are earned
# bursts. Slow motion stretches the catch windows in REAL time, which is what
# makes five clubs and seven torches humanly possible.
const SPEED_CAP := 100         # the Speed stat's permanent ceiling (points, not percent:
								# 4 points per 1% slow motion, so the cap is still 25%)
const PIE_COST := 1000         # a slice lasts the WHOLE DAY, until you sleep
const AMAZING_FRAMES := 480    # the frame-perfect reward burst (four seconds)
const CHAIN_NEED := 50         # perfect catches in a row to earn a slow window
const CHAIN_FRAMES := 3600     # ...which then lasts thirty seconds, then re-earn
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
const TUT_SLOW_START := 0.62   # the first step of a lesson: 62% slow
const TUT_SLOW_END := 0.20     # the last step: nearly real time
const PROMPT_LEAD := 90        # ticks before a catch that its key prompt begins to glow
							   # and brighten (at 62% slow that is about two real seconds)
const SPIN_CATCH_MULT := 2.0       # every catch during a Spin scores double
const SPIN_ACC_PENALTY := 0.28     # a Spin lowers the off-Perfect catch chance (juggling blind)

# --- THE BOOKING (Phase 2) ----------------------------------------------------
# A performance is no longer one open-ended set: it is a booking of three sets at
# one venue, played back to back. Each set is a contest with a number to beat (the
# TARGET), a crowd whose patience DRAINS (the applause meter, now a clock), and a
# hard DROP LIMIT (the damage). Clear a target and you may WALK OFF to bank it, or
# push for a growing overtime multiplier and risk the night. The third set adds a
# named ENCORE condition drawn from a deck. This is the layer that turns a lovely
# toy into a game with stakes, and almost all of it activates machinery Game.gd
# already had (the collapse, the applause meter, the graceful finish, purist,
# set_collide, the record boards) and simply never pressed on.
const SET_WARMUP := 0
const SET_MAIN := 1
const SET_ENCORE := 2
const SETS_PER_BOOKING := 3
# the Warm-up target per venue. The whole phase lives or dies on these numbers, so
# they were set against the --calib autoplayer sweep, not guessed: a flawless three-
# ball cascade clears the Backyard Warm-up and falls well short of the Championship.
const VENUE_BASE := [8000, 20000, 55000, 85000, 100000, 140000]
const SET_STEP := [1.0, 1.9, 3.2]     # Warm-up, The Set, The Encore: each a taller bar
const ANTE_STEP := 0.15               # each cleared booking at a venue raises its bar 15%
# the crowd's patience bleeds this much per tick, per venue (120 ticks a second). At
# the Backyard a still juggler loses the room in ~24s; at the World Arena in ~8. Every
# Perfect catch pays ~0.05 back, so keeping the crowd is a matter of keeping juggling.
const APPL_DECAY := [0.00034, 0.00044, 0.00056, 0.00068, 0.00080, 0.00092]
const DROP_LIMIT := 3                 # three drops and the crowd turns (an Encore may lower it)
const OVERTIME_PER_CATCH := 0.02      # each catch past the target grows the walk-off bonus
const OVERTIME_MAX := 2.5             # ...capped, so pushing forever is not the play
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
	{"id": "blackout",  "name": "Blackout",           "desc": "Only the top of each arc is lit. Catch what you cannot see."},
	{"id": "cold",      "name": "Cold Hands",         "desc": "The Perfect window is two ticks tighter."},
	{"id": "long",      "name": "The Long Set",       "desc": "Twice the target, but the crowd is patient. An endurance test."},
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
var set_index := 0            # 0 Warm-up, 1 The Set, 2 The Encore
var booking_score := 0        # banked across the booking's cleared sets (the record number)
var booking_active := false   # true from begin_performance until the booking resolves
var overtime := 0.0           # the walk-off multiplier, earned by catches past the target
var set_cleared := false      # this set's target has been beaten (locks true, enables the walk-off)
var set_collapsed := false    # this set ended by the crowd walking or the drop limit (overtime lost)
var exhausted := false        # the collapse was caused by empty stamina: on return to the day,
							  # steer the player straight to EAT / SLEEP (Louis)
var encore := -1              # index into ENCORES for this booking's third set, or -1
var sets_cleared := 0         # how many of the three the player cleared, for pay and reputation
var ante: Array[int] = [0, 0, 0, 0, 0, 0]   # bookings cleared per venue: the standing raised bar
# the booking's running totals, summed across its sets so the results card reads the
# whole night, not just the last set
var book_caught := 0
var book_dropped := 0
var book_best_streak := 0
var book_tricks := 0
var book_trick_score := 0
var book_xp := 0

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
var level := 1
var xp := 0               # xp accumulated inside the current level
var points := 0           # unspent stat points
var stamina := 100.0      # within-run resource; empty = you cannot catch, so mind it
var stamina_max := 100.0  # 100 base + 9 per Endurance point, to 1000 at Endurance 100
var run_xp := 0           # xp earned in the current run, for the results screen
var last_pay := 0         # gold earned from the last finished performance
var last_rep_delta := 0   # reputation change from the last performance, for the results screen
var run_venue := 0        # which venue this run was performed at (records key off this)
var best_scores: Array[int] = [0, 0, 0, 0, 0, 0]  # best performance score per venue tier
# --- the Purist ladder (GDD "Purist boards"): a performance booked as PURIST
# strips every stat comfort from the catch maths (Accuracy read as a fresh
# juggler's, no glasses, no Focus window, no Strength steadying), so its records
# are pure skill. Separate per-venue bests, toggled per booking in the day hub.
var purist := false
var best_scores_purist: Array[int] = [0, 0, 0, 0, 0, 0]
# --- the career ledger (persisted per slot): lifetime numbers behind the record
# boards, shown on the RECORDS AND HISTORY screen reached from Settings
var career := {"perfs": 0, "practices": 0, "catches": 0, "drops": 0,
	"best_streak": 0, "gold_earned": 0, "tricks": 0, "days": 1, "best_score": 0}
var results_open := false # the end-of-performance results panel is showing
var results_record := false  # this performance beat the venue's record
var paused := false       # the in-play pause menu is up (freezes the sim)
var pause_sel := 0        # cursor in the pause menu
var round_scored := false
# --- tricks: which trick Space is loaded with (cycled with C, persists), whether
# Space has primed a one-shot, the live-Spin timer, and the run's trick tally.
var trick_sel := -1       # the selected trick (index into TRICKS), or -1 before any unlock
var trick_primed := false # Space pressed: the very next throw becomes the selected arm trick
var toggle_on := -1       # the toggle trick currently running (TR_COLS etc), or -1
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
var menu_sel := 0         # cursor index in whichever menu is open
var save_slot := 0        # which save file is active
var remap_sel := 0        # cursor on the controls screen
var remap_wait := false   # true while the controls screen listens for the next key
var _confirm_id := ""     # the purchase awaiting its second, confirming press
var _confirm_ms := 0
var shop_msg := ""        # transient warning line inside the shop panel
var shop_msg_ms := 0

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
									  # (an unlock happens mid-set; the lesson must wait)

# --- interactive tutorial (runs on the REAL sim, guided step by step) ---------
var tut_active := false   # a hands-on lesson is running inside ST_PLAY
var tut_id := ""          # "balls" (the 1->2->3 progression) or "prop_<n>"
var tut_step := 0         # index into tut_lesson(tut_id)
var tut_count := 0        # catches (or throws) banked in the current step
var tut_threw_l := false  # a left-hand throw happened this step
var tut_threw_r := false  # a right-hand throw happened this step
var tut_advance_at := -1  # tick to move on (a beat after the goal, so the throw lands)
var tut_flash := ""       # brief "Nice!" feedback between steps
var tut_tricks := 0       # reward_trick calls banked this step (arm/live trick goals)
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
var set_flags := true     # show the TOO LOW / too high throw flags
var set_collide := false  # hard mode: props that clack mid-air become nearly
						  # uncatchable (half the Perfect window, no chance roll).
						  # A PERFECT pattern never collides, so this only ever
						  # punishes sloppy heights that share air.
var set_music := true     # the procedural adaptive soundtrack
var set_sfx := true       # catch/throw/drop sound effects and the crowd bed
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
	if set_fullscreen:
		apply_fullscreen()                       # honour the remembered display mode
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
			strength = maxi(strength, 33)   # so max_balls() allows up to 7
			start_n = clampi(int(ua[bi + 1]), MIN_BALLS, MAX_BALLS_HARD)
		var vfi := ua.find("--venue")   # dev: play at venue N (0..5), so booking targets and
		if vfi != -1 and vfi + 1 < ua.size():   # patience decay match that stage (calibration + shots)
			var vn := clampi(int(ua[vfi + 1]), 0, TOP_VENUE)
			reputation = VENUE_REP[vn]
			venue_pick = vn
		var pfi := ua.find("--prop")    # dev: juggle prop N (0..5) with enough owned + Strength
		if pfi != -1 and pfi + 1 < ua.size():
			var pn := clampi(int(ua[pfi + 1]), 0, PROPS.size() - 1)
			prop_type = pn
			prop_count[pn] = maxi(prop_count[pn], 7)
			strength = maxi(strength, int(PROPS[pn]["req"]))
		start_run(start_n)
		game_state = ST_PLAY
		if ua.has("--demo"):    # dev: the auto-player performs, so we can see the booking HUD
			mode = MODE_PERFORM
		if ua.has("--booking"):   # dev: run a REAL booking (rolls an Encore), for shots and --calib.
			# --encore <id> pins the condition; --set <n> jumps straight to that set (2 = the Encore).
			booking_active = true
			set_index = 0
			booking_score = 0
			sets_cleared = 0
			encore = randi() % ENCORES.size()
			var eni := ua.find("--encore")
			if eni != -1 and eni + 1 < ua.size():
				for ek in ENCORES.size():
					if String(ENCORES[ek]["id"]) == ua[eni + 1]:
						encore = ek
			var sei := ua.find("--set")
			if sei != -1 and sei + 1 < ua.size():
				set_index = clampi(int(ua[sei + 1]), 0, SET_ENCORE)
				booking_score = set_target_for(run_venue, 0) if set_index > 0 else 0
		var ci := ua.find("--calib")   # dev: print the autoplayer's score at N ticks, then quit,
		if ci != -1:                   # to tune VENUE_BASE against real strong-player numbers
			_calib = true
			if ci + 1 < ua.size() and not ua[ci + 1].begins_with("--"):
				_calib_ticks = maxi(120, int(ua[ci + 1]))
		var pi := ua.find("--pattern")   # dev: force a pattern for screenshots, e.g. --pattern shower
		if pi != -1 and pi + 1 < ua.size():
			for pj in PATTERNS.size():
				if String(PATTERNS[pj]["id"]) == ua[pi + 1]:
					level = maxi(level, int(PATTERNS[pj]["lvl"]))
					pattern_sel = pj
					start_run(num_balls)
		var tri := ua.find("--trick")   # dev: unlock every trick and let the auto-player
		if tri != -1:                   # show them off. An optional id (--trick wfall)
			_demo_trick = true          # pins that one trick, so toggles can be watched
			level = 10
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
		if ua.has("--sheet"):   # dev: open the character sheet for a screenshot
			points = maxi(points, 6)
			sheet_open = true
		if ua.has("--shop"):    # dev: open the shop for a screenshot
			shop_open = true
		if ua.has("--results"):   # dev: fabricate a finished booking to screenshot the card
			mode = MODE_PERFORM
			run_venue = 4
			sets_cleared = 3          # a complete night, for the card's header and grade
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
	var ti := ua.find("--tutorial")   # dev: jump into a hands-on lesson, e.g. --tutorial balls
	if ti != -1:
		var id := ua[ti + 1] if ti + 1 < ua.size() and not ua[ti + 1].begins_with("--") else "balls"
		begin_tutorial(id)
	var ei := ua.find("--establish")  # dev: screenshot a venue exterior card, e.g. --establish 3.
	if ei != -1:                      # add --booking (and optionally --set/--encore) to show the
		establish_venue = int(ua[ei + 1]) if ei + 1 < ua.size() else 2   # booking's set/target/encore panel
		if ua.has("--booking"):
			booking_active = true
			run_venue = establish_venue
			set_index = SET_WARMUP
			var esi := ua.find("--set")
			if esi != -1 and esi + 1 < ua.size():
				set_index = clampi(int(ua[esi + 1]), 0, SET_ENCORE)
			encore = randi() % ENCORES.size()
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


func _physics_process(delta: float) -> void:
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
		var wt := set_target_for(run_venue, SET_WARMUP)
		var reason := "COLLAPSE" if collapsing else "time"
		print("CALIB venue=%d prop=%d n=%d hold=%d end=%s tick=%d score=%d caught=%d streak=%d appl=%.2f  warmup=%d clears=%s" % [
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
		# the controls screen, while listening, captures the next KEYBOARD key as
		# the new binding (Esc cancels, F11 stays the fullscreen toggle)
		if game_state == ST_REMAP and remap_wait:
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
		_pad_last = true
		kc = _pad_to_key(jb.button_index)
		if kc == -1:
			return
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
	# during a hands-on lesson the command keys are locked; catch/throw are polled
	# separately, so only Escape does anything here (it opens the pause menu)
	if tut_active:
		if kc == KEY_ESCAPE:
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
	if tut_active:
		# a lesson is a controlled space (Louis): ONLY reset and pause act on a key, so
		# no stray press can break it into a normal run, a panel, or a prop swap. The
		# juggling itself - throw, catch, Space - stays live (polled in _read_inputs),
		# and the lesson only ever advances on its own goals.
		match kc:
			KEY_R:
				tut_reset_step()
			KEY_ESCAPE:
				open_pause()
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
				enter_day()            # practice over: Enter steps back into the day
		KEY_R:
			if not performing:
				start_run(num_balls)
		KEY_BRACKETLEFT:
			if not performing:
				start_run(num_balls - 1)
		KEY_BRACKETRIGHT:
			if not performing:
				start_run(num_balls + 1)
		KEY_3:
			if not performing: start_run(3)
		KEY_4:
			if not performing: start_run(4)
		KEY_5:
			if not performing: start_run(5)
		KEY_6:
			if not performing: start_run(6)
		KEY_7:
			if not performing: start_run(7)
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
			if debug_mode: debug_jump_venue(0)   # debug: F1..F6 jump reputation to venues 1..6
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
		KEY_ESCAPE:
			open_pause()


func _pad_to_key(btn: int) -> int:
	# translate a recognised pad button into the keycode the per-screen matches
	# already understand. -1 means the button has no meaning on this screen.
	match btn:
		JOY_BUTTON_DPAD_UP:
			return KEY_UP
		JOY_BUTTON_DPAD_DOWN:
			return KEY_DOWN
		JOY_BUTTON_A:
			# while the sim is live, A is the polled trick button, so it must not
			# double as Enter there or every spin attempt would finish the set
			if game_state == ST_PLAY and not paused and not results_open and not sheet_open and not shop_open:
				return -1
			return KEY_ENTER
		JOY_BUTTON_B:
			return KEY_ESCAPE
		JOY_BUTTON_START:
			# Start mirrors Escape inside play, so it opens and closes the pause
			# menu. outside play Escape can mean quit, so Start stays unmapped.
			return KEY_ESCAPE if game_state == ST_PLAY else -1
		JOY_BUTTON_X:
			return KEY_X
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
		1:   # end the session and step back out into the day (clears any panels)
			paused = false
			tut_active = false
			results_open = false
			sheet_open = false
			shop_open = false
			enter_day()
			play_sfx("ui", -12.0)
		2:   # leave the game
			get_tree().quit()


func finish_performance() -> void:
	# TAKE A BOW (Phase 2, revised per Louis). The finish key ALWAYS ends the set
	# gracefully - you catch what you have and bow, the crowd stays happy, nothing falls.
	# If the target was cleared you bank it (with overtime) and advance; if not, you have
	# chosen to bow out below the number, which banks the partial and ends the night on a
	# high note rather than risking a collapse. A set only ever COLLAPSES involuntarily,
	# from an emptied crowd or the drop limit. Clearing running fires on_round_end from the
	# running->false edge, where resolve_set() banks and either advances or resolves.
	if mode != MODE_PERFORM or not running or tut_active:
		return
	play_sfx("streak", -6.0)   # a short rising flourish to close the set
	running = false


func begin_performance(n: int) -> void:
	# a booking opens on an establishing shot of WHERE you are about to play, the way a
	# film cuts to the outside of the building before the scene inside. It also rolls
	# this booking's Encore and clears the per-booking accumulators, so the whole night
	# is set up here and the three sets simply run.
	mode = MODE_PERFORM
	establish_after = n
	establish_venue = play_venue()
	booking_active = true
	set_index = SET_WARMUP
	booking_score = 0
	sets_cleared = 0
	# a fresh cosmetic roll for the Encore (global randi, never the sim rng, so the
	# deterministic catch sequence is untouched by which condition came up)
	encore = randi() % ENCORES.size()
	book_caught = 0
	book_dropped = 0
	book_best_streak = 0
	book_tricks = 0
	book_trick_score = 0
	book_xp = 0
	game_state = ST_ESTABLISH
	cine_tick = 0


func next_set() -> void:
	# advance to the next set of the booking WITHOUT returning to the hub: re-establish
	# the card (so each set gets its "here is what they want" beat), then start_run deals
	# a fresh set that keeps the same loadout and the accumulating booking_score.
	set_index = clampi(set_index + 1, 0, SET_ENCORE)
	establish_after = num_balls
	establish_venue = play_venue()
	game_state = ST_ESTABLISH
	cine_tick = 0


func establish_key() -> void:
	game_state = ST_PLAY
	start_run(establish_after)   # the card dismissed: walk out and begin the set


# --- booking maths: the target (gate), the deck's live effects, the drop limit -----

func set_target_for(venue: int, si: int) -> int:
	# the number to beat, scaling off the VENUE and the standing ante, never off the
	# player's own record (scaling off your best would punish you for improving). The
	# Encore's multiplier folds in only on the third set.
	var base := float(VENUE_BASE[clampi(venue, 0, VENUE_BASE.size() - 1)])
	var step := float(SET_STEP[clampi(si, 0, SET_STEP.size() - 1)])
	var a := 1.0 + ANTE_STEP * float(ante[clampi(venue, 0, ante.size() - 1)])
	var enc := encore_target_mult() if si == SET_ENCORE else 1.0
	return int(round(base * step * a * enc))


func set_target() -> int:
	return set_target_for(run_venue, set_index)


func book_total() -> int:
	# the live running total across the booking: banked sets plus the current set's score.
	# monotonic, so it drives the record chase and the "how close am I" HUD honestly.
	return booking_score + score


func encore_on(id: String) -> bool:
	# is THIS booking's Encore active right now? Only ever true on the third set of a
	# real booking, so a warm-up and a --demo run are never touched by a condition.
	return booking_active and mode == MODE_PERFORM and set_index == SET_ENCORE \
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
	# the Reputation the NEXT stage opens at, or 0 when the arena is yours
	# (mirrors venue_index_of's ladder)
	var steps := [100, 300, 700, 1500, 3000]
	var vi := venue_index()
	return int(steps[vi]) if vi < steps.size() else 0


func enter_day() -> void:
	game_state = ST_DAY
	day_sel = 0
	day_msg = ""
	view_venue = -1
	cine_tick = 0
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
	save_progress()
	check_dead_end()   # broke AND spent on arrival: the road ends here


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
		"eat", "inn", "shop":
			# these three open with a small vignette; the effect lands when it
			# ends. Dinner that would break the bed money asks first.
			if id == "eat" and not confirm_spend("eat", EAT_COST, false):
				return
			day_anim = id
			day_anim_start = cine_tick
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
			stamina = minf(stamina_max, stamina + EAT_STAM * stamina_max)
			meals += 1
			if meals % MEALS_PER_STR == 0 and strength < 100:
				var prev_max := max_balls()
				strength += 1
				check_ball_unlock(prev_max)   # a meal's Strength can cross a ball gate too
				set_day_msg("the good food is paying off  -  Strength +1")
				play_sfx("streak", -8.0)
			else:
				set_day_msg("a hot meal, stamina restored a little")
				play_sfx("coin", -10.0)
			save_progress()
		"inn":
			money -= INN_COST   # full price, always (the row blocks when short)
			sleep_day()
		"shop":
			shop_open = true
			play_sfx("ui2", -13.0)


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


func sheet_input(kc: int) -> void:
	# the character sheet's keys, shared by the play overlay and the day hub
	match kc:
		KEY_TAB, KEY_ESCAPE:
			sheet_open = false
		KEY_1:
			_sheet_invest("acc")
		KEY_2:
			_sheet_invest("str")
		KEY_3:
			_sheet_invest("end")
		KEY_4:
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


func shop_input(kc: int) -> void:
	# the shop's keys, shared by the play overlay and the day hub
	match kc:
		KEY_TAB, KEY_ESCAPE, KEY_S:
			shop_open = false
		KEY_1:
			try_buy(PROP_EGGS)
		KEY_2:
			try_buy(PROP_RINGS)
		KEY_3:
			try_buy(PROP_CLUBS)
		KEY_4:
			try_buy(PROP_KNIVES)
		KEY_5:
			try_buy(PROP_TORCHES)
		KEY_6:
			try_buy_glasses()
		KEY_7:
			try_buy_pie()


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
	if is_trick and not trick_unlocked(idx):
		set_day_msg("that trick unlocks at level %d" % int(TRICKS[idx]["lvl"]))
		play_sfx("whiff", -10.0)
		return
	if not is_trick and not pattern_unlocked(idx - TRICKS.size()):
		set_day_msg("that pattern unlocks at level %d" % int(PATTERNS[idx - TRICKS.size()]["lvl"]))
		play_sfx("whiff", -10.0)
		return
	if too_tired():
		set_day_msg("too tired to practise  -  sleep first")
		play_sfx("whiff", -10.0)
		return
	# a pattern needs a matching ball count (an even fountain, odd cascade); a trick
	# keeps the current count. Set the pattern BEFORE start_run so it deals right.
	if not is_trick:
		pattern_sel = idx - TRICKS.size()
	skills_open = false
	seg_used += 1
	career["practices"] = int(career["practices"]) + 1
	save_progress()
	mode = MODE_TRAIN
	game_state = ST_PLAY
	start_run(num_balls)
	# now engage the chosen trick (start_run has cleared the per-run trick state):
	# a toggle switches ON and stays, an arm trick primes the next throw, Spin just
	# loads. The player still throws to begin, so nothing fires unbidden.
	if is_trick:
		trick_sel = idx
		var kind := String(TRICKS[idx]["kind"])
		if kind == "toggle":
			toggle_on = idx
			toggle_scored = false
			tennis_ball = null
			if idx == TR_COLS:
				col_air_ref = -1.0
				col_mid_ball = null
			set_trick_msg("%s ON  -  practising" % String(TRICKS[idx]["name"]).to_upper())
		elif kind == "arm":
			trick_primed = true
			set_trick_msg("%s  -  next throw" % String(TRICKS[idx]["name"]).to_upper())
		else:
			set_trick_msg("%s selected  -  %s performs it" % [String(TRICKS[idx]["name"]), k_trick()[0]])
	else:
		set_trick_msg("%s  -  %s" % [String(PATTERNS[pattern_sel]["name"]).to_upper(), String(PATTERNS[pattern_sel]["desc"])])
	play_sfx("ui2", -11.0)


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


func cycle_pattern_live(dir: int) -> void:
	# switch the routine mid-performance WITHOUT restarting: like a trick toggle, the
	# new pattern simply shapes every throw from here on. Balls already in flight keep
	# their own paths; the lane bookkeeping resets so Columns starts clean.
	var un: Array = []
	for i in PATTERNS.size():
		if pattern_unlocked(i):
			un.append(i)
	if un.size() <= 1:
		set_trick_msg("more patterns unlock at level %d" % int(PATTERNS[COLUMNS]["lvl"]))
		return
	var idx := un.find(pattern_sel)
	pattern_sel = int(un[(idx + dir + un.size()) % un.size()]) if idx >= 0 else int(un[0])
	pattern = pattern_sel
	col_air_ref = -1.0
	col_mid_ball = null
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
		save_progress()
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
	# the core progression: one ball, then two, then the three-ball cascade.
	# Key names come from the live bindings, so a remapped player is taught
	# THEIR keys, not the defaults.
	var kj := OS.get_keycode_string(K_RT)
	var kf := OS.get_keycode_string(K_LT)
	var kd := OS.get_keycode_string(K_LC)
	var kk := OS.get_keycode_string(K_RC)
	return [
		{"prop": PROP_BALLS, "balls": 1, "hand": RIGHT, "goal": "throw_r", "need": 1,
			"text": "Throw the ball from your RIGHT hand", "sub": "Tap %s. Just let it fall this time, no need to catch it yet." % kj},
		{"prop": PROP_BALLS, "balls": 1, "hand": LEFT, "goal": "throw_l", "need": 1,
			"text": "Now throw from your LEFT hand", "sub": "Tap %s, and let it fall again. Feel that each hand has its own throw." % kf},
		{"prop": PROP_BALLS, "balls": 1, "hand": RIGHT, "goal": "catch", "need": 1,
			"text": "This time, catch it", "sub": "Throw with %s, then catch it in your LEFT hand with %s as it comes down." % [kj, kd]},
		{"prop": PROP_BALLS, "balls": 1, "hand": LEFT, "goal": "catch", "need": 1,
			"text": "And the other way", "sub": "Throw with %s, then catch it in your RIGHT hand with %s." % [kf, kk]},
		{"prop": PROP_BALLS, "balls": 1, "hand": RIGHT, "goal": "catch", "need": 4,
			"text": "Keep one ball going, back and forth", "sub": "Throw, catch, throw from that hand, catch. Land four in a row."},
		{"prop": PROP_BALLS, "balls": 2, "hand": RIGHT, "goal": "catch", "need": 4,
			"text": "Two balls now, one in each hand", "sub": "Throw the first, and as it peaks throw the second up under it. Land four catches."},
		{"prop": PROP_BALLS, "balls": 3, "hand": RIGHT, "goal": "catch", "need": 4,
			"text": "Three balls. The cascade", "sub": "Every time a ball falls, throw the one in the catching hand up first. Keep it weaving for four."},
	]


func trick_lesson_steps(t: int) -> Array:
	# a trick lesson mirrors the three INPUT GRAMMARS the game has, because the grammar
	# is what confuses people, not the trick: a toggle switches on and off, an arm shot
	# empowers one throw, a live trick acts on what is already in the air. Taught with
	# plain balls (the trick shaping is prop-independent), slow, and drilled.
	if t < 0 or t >= TRICKS.size():
		return [{"prop": PROP_BALLS, "balls": 3, "hand": RIGHT, "goal": "catch", "need": 3,
			"text": "Keep the cascade going", "sub": "Land three."}]   # defensive: never index []
	var td: Dictionary = TRICKS[t]
	var nm := String(td["name"])
	var kb := String(k_trick()[0])
	match String(td["kind"]):
		"toggle":
			return [
				{"prop": PROP_BALLS, "balls": 3, "hand": RIGHT, "goal": "trick_on", "need": 1,
					"trick": t, "prompt": "trick", "slow": 0.62,
					"text": "%s: switch it ON" % nm,
					"sub": "Press %s. Every throw reshapes into %s until you press it again." % [kb, nm]},
				{"prop": PROP_BALLS, "balls": 3, "hand": RIGHT, "goal": "catch", "need": 3,
					"prompt": "catch", "slow": 0.5,
					"text": "Now keep it going, and catch them down",
					"sub": "Watch how the weave changes shape. Land three while it runs."},
				{"prop": PROP_BALLS, "balls": 3, "hand": RIGHT, "goal": "trick_off", "need": 1,
					"trick": t, "prompt": "trick", "slow": 0.35,
					"text": "And switch it OFF",
					"sub": "Press %s again to fall back to a normal weave. That is the whole toggle." % kb},
			]
		"arm":
			return [
				{"prop": PROP_BALLS, "balls": 3, "hand": RIGHT, "goal": "trick_use", "need": 1,
					"trick": t, "prompt": "trick", "slow": 0.55,
					"text": "%s: arm it, then throw" % nm,
					"sub": "Press %s, then throw. Just that ONE next throw flies over the top, and it lands the trick." % kb},
				{"prop": PROP_BALLS, "balls": 3, "hand": RIGHT, "goal": "trick_use", "need": 2,
					"trick": t, "prompt": "trick", "slow": 0.4,
					"text": "Again - it is a one-shot, so arm it each time",
					"sub": "Press %s, throw, catch. Land two more. Every %s is its own press." % [kb, nm]},
			]
		_:  # live (Spin): acts on the balls already airborne
			return [
				{"prop": PROP_BALLS, "balls": 3, "hand": RIGHT, "goal": "catch", "need": 2,
					"prompt": "catch", "slow": 0.55,
					"text": "First get all three weaving",
					"sub": "%s acts on the balls already in the air, so fill the air before you call it." % nm},
				{"prop": PROP_BALLS, "balls": 3, "hand": RIGHT, "goal": "trick_use", "need": 1,
					"trick": t, "prompt": "trick", "slow": 0.62,
					"text": "Now press it, and catch through the turn",
					"sub": "Press %s. The catches come while you are still spinning - trust the timing, it is thick and slow here." % kb},
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
	]


func begin_tutorial(id: String) -> void:
	tut_id = id
	tut_step = 0
	tut_active = true
	game_state = ST_PLAY
	started = true            # a lesson is its own thing, not the opening "first run"
	_slow_cur = tut_slow()    # a lesson opens ALREADY thick, it does not ease in over the
							  # ~4s the 0.0025 ramp would take from a standing start
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
	# a pattern lesson forces its own pattern; otherwise the parity default
	if step.has("pattern"):
		pattern = int(step["pattern"])
		pattern_sel = pattern
	else:
		pattern = CASCADE if num_balls % 2 == 1 else FOUNTAIN
	# a trick lesson selects (and de-arms) its trick, so the step starts from a known
	# state: Space will act on exactly this trick, nothing is primed or toggled yet
	if step.has("trick"):
		trick_sel = int(step["trick"])
		toggle_on = -1
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
		# deal the balls; a single-ball step starts in the exact hand it is teaching
		for i in num_balls:
			var b := Ball.new()
			b.state = STATE_HAND
			b.kind = prop_type
			b.color = ball_color(i) if prop_type == PROP_BALLS else prop_color(prop_type)
			b.spin_dir = 1.0 if i % 2 == 0 else -1.0
			balls.append(b)
			var to_left := (i % 2 == 1) if num_balls > 1 else (start_hand == LEFT)
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
	tut_advance_at = -1


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
	tut_flash = ""
	tut_setup_step()   # balls now empty, so it deals the step fresh
	play_sfx("ui2", -13.0)


func tut_on_throw(h: int) -> void:
	if h == LEFT:
		tut_threw_l = true
	else:
		tut_threw_r = true
	tut_check()


func tut_on_catch() -> void:
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
		_: done = tut_count >= int(step["need"])
	if done:
		tut_flash = "Nice!"
		tut_advance_at = tick + 72   # let the last throw finish its arc before cutting on


func tut_maintain() -> void:
	# advance when the post-goal beat elapses, and keep the step playable by topping
	# the hands back up shortly after a ball is lost, so a fumble never stalls a lesson
	if tut_advance_at >= 0 and tick >= tut_advance_at:
		tut_flash = ""
		tut_step += 1
		if tut_step >= tut_lesson(tut_id).size():
			tut_finish()
		else:
			play_sfx("streak", -8.0)   # a little rising "nice, next" between steps
			tut_setup_step()
		return
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
	var was_basics := tut_id == "balls"
	tut_active = false
	tut_id = ""
	tut_flash = ""
	mode = MODE_TRAIN
	if was_basics:
		prop_type = PROP_BALLS   # ONLY the basics lesson forces balls back; a trick or
								 # count lesson taught with the owned prop leaves it be
	play_sfx("coin", -6.0)   # a bright flourish on finishing a lesson
	enter_day()
	set_day_msg("lesson complete  -  your day begins")


func draw_tutorial_banner(font: Font, s: Vector2) -> void:
	var step := tut_step_data()
	var steps := tut_lesson(tut_id)
	draw_tut_prompts(font, s, step)   # a timing ring + bare handed key over the hands, no boxes
	# the ONE rectangle at the top (Louis): the lesson text and progress. Everything else
	# lives along the bottom, so the centre - where the props fly - stays clear.
	var bw := s.x * 0.66
	var bx := s.x * 0.5 - bw * 0.5
	var by := 24.0
	draw_rect(Rect2(bx, by, bw, 92.0), Color(0.05, 0.03, 0.05, 0.86))
	draw_rect(Rect2(bx, by, bw, 92.0), Color(0.82, 0.62, 0.34, 0.55), false, 2.0)
	draw_string(font, Vector2(bx, by + 30.0), "LESSON  -  " + String(step["text"]), HORIZONTAL_ALIGNMENT_CENTER, bw, 23, Color(1.0, 0.9, 0.6))
	draw_string(font, Vector2(bx + 20.0, by + 55.0), String(step["sub"]), HORIZONTAL_ALIGNMENT_CENTER, bw - 40.0, 15, Color(0.9, 0.85, 0.78))
	var prog := "Step %d of %d" % [tut_step + 1, steps.size()]
	if String(step["goal"]).begins_with("catch") and int(step["need"]) > 1:
		prog += "        caught  %d / %d" % [mini(tut_count, int(step["need"])), int(step["need"])]
	draw_string(font, Vector2(bx, by + 80.0), prog, HORIZONTAL_ALIGNMENT_CENTER, bw, 14, Color(0.8, 0.75, 0.68))
	# ALL the controls, always, along the very bottom (Louis: every command, not just the
	# one this step uses). The trick key lights up when the step calls for it.
	var trick_hot := String(step.get("prompt", "")) == "trick"
	var tcol := Color(1.0, 0.72, 0.4) if trick_hot else Color(0.82, 0.74, 0.62, 0.9)
	draw_hints_row(font, s.x * 0.5, s.y - 40.0,
		[[k_throw(), "throw"], [k_catch(), "catch"], [k_trick(), "trick"], [["R"], "reset"], [k_pause(), "pause"]])
	if trick_hot:
		var pa := 0.55 + 0.45 * (0.5 + 0.5 * sin(atick() * 0.13))
		draw_text_shout(font, Vector2(0, s.y - 64.0), "press %s now" % String(k_trick()[0]), HORIZONTAL_ALIGNMENT_CENTER, s.x, 15, Color(tcol.r, tcol.g, tcol.b, pa))
	if tut_flash != "":
		draw_text_shout(font, Vector2(0, s.y - 92.0), tut_flash, HORIZONTAL_ALIGNMENT_CENTER, s.x, 24, Color(0.7, 0.95, 0.7))


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
	var sc := lerpf(0.9, 1.4, u)
	if u > 0.6:
		sc *= 1.0 + 0.06 * sin(atick() * 0.18) * (u - 0.6) / 0.4
	var fs := int(round(19.0 * sc))
	var a := lerpf(0.5, 1.0, u)
	draw_text_shout(font, at - Vector2(80.0, 0.0), key, HORIZONTAL_ALIGNMENT_CENTER, 160.0, fs, Color(col.r, col.g, col.b, a))


func draw_tut_prompts(font: Font, s: Vector2, step: Dictionary) -> void:
	# THE lesson affordance (Louis): which key, over which hand, at the moment to press it
	# - but as a bare letter and a timing ring, never a boxed bubble. Silent once a step is
	# cleared, so success leaves the centre quiet.
	if tut_advance_at >= 0:
		return
	var kc := k_catch()
	var kt := k_throw()
	# catch: a timing ring on the receiving hand, its bare catch key just above it
	for b in balls:
		if b.state != STATE_FLIGHT:
			continue
		var d := b.land_tick - tick
		if d <= 0 or d > PROMPT_LEAD:
			continue
		var h := b.to_hand
		var hp: Vector2 = hpos[clampi(h, 0, 1)]
		draw_timing_ring(hp, d)
		var urg := 1.0 - float(d) / float(PROMPT_LEAD)
		draw_tut_key(font, hp + Vector2(0.0, -44.0), String(kc[clampi(h, 0, 1)]), Color(0.7, 0.88, 1.0), urg)
	# throw: the bare throw key over the hand the step wants to throw from
	var prompt := String(step.get("prompt", ""))
	var goal := String(step["goal"])
	if prompt == "throw" or prompt == "hold" or goal == "throw_r" or goal == "throw_l":
		var th := RIGHT if (goal == "throw_r" or prompt == "throw") else LEFT
		if goal == "throw_l":
			th = LEFT
		for hh in [int(step.get("hand", th)), LEFT, RIGHT]:
			if not stack(hh).is_empty():
				th = hh
				break
		if not stack(th).is_empty():
			draw_tut_key(font, hpos[th] + Vector2(0.0, -44.0), String(kt[th]), Color(1.0, 0.82, 0.5), 0.7)


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
	save_progress()
	play_sfx("coin", -8.0)


func try_buy_glasses() -> void:
	if has_glasses or money < GLASSES_COST:
		return
	if not confirm_spend("glasses", GLASSES_COST, true):
		return
	money -= GLASSES_COST
	has_glasses = true
	save_progress()


# -----------------------------------------------------------------------------
# Game flow: main menu, save slots, settings, cutscenes.
# -----------------------------------------------------------------------------

func menu_options() -> Array[String]:
	# the live main-menu list. Victory appears only once a save has conquered the
	# top stage, so a first-time player never sees it. Both menu_input and draw_menu
	# build the list from here, so the cursor and the drawing can never disagree.
	var opts: Array[String] = ["Play"]
	if has_won():
		opts.append("Victory")
	opts.append("Settings")
	opts.append("Quit")
	return opts


func has_won() -> bool:
	# true once the climb has been completed anywhere: the currently loaded game,
	# or any save slot on disk. Peeks the slot files the same way slot_summary does.
	if won:
		return true
	for i in NUM_SLOTS:
		if not FileAccess.file_exists(slot_path(i)):
			continue
		var cf := ConfigFile.new()
		if cf.load(slot_path(i)) != OK:
			continue
		if bool(cf.get_value("prog", "won", false)):
			return true
	return false


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
				"Victory":
					menu_sel = 0
					game_state = ST_CREDITS
					cine_tick = 0
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
	var n := 9   # music, sound, shake, flags, collisions, fullscreen, controls, records, Back
	match kc:
		KEY_UP, KEY_W:
			menu_sel = (menu_sel + n - 1) % n
			play_sfx("ui", -14.0)
		KEY_DOWN, KEY_S:
			menu_sel = (menu_sel + 1) % n
			play_sfx("ui", -14.0)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_LEFT, KEY_RIGHT:
			match menu_sel:
				0:
					set_music = not set_music
				1:
					set_sfx = not set_sfx
				2:
					set_shake = not set_shake
				3:
					set_flags = not set_flags
				4:
					set_collide = not set_collide
				5:
					set_fullscreen = not set_fullscreen
					apply_fullscreen()
				6:
					remap_sel = 0
					remap_wait = false
					game_state = ST_REMAP   # the controls reference (and rebind the six actions)
				7:
					game_state = ST_STATS   # the career ledger, back with Esc
				8:
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
	prop_count = [0, 0, 0, 0, 0, 0]
	prop_type = PROP_BALLS
	has_glasses = false
	level = 1
	xp = 0
	points = 0
	won = false
	best_scores = [0, 0, 0, 0, 0, 0]
	best_scores_purist = [0, 0, 0, 0, 0, 0]
	pattern_sel = CASCADE
	purist = false
	career = {"perfs": 0, "practices": 0, "catches": 0, "drops": 0,
		"best_streak": 0, "gold_earned": 0, "tricks": 0, "days": 1, "best_score": 0}
	day = 1
	seg_used = 0
	venue_pick = 0
	meals = 0
	started = false
	seen_tuts.clear()      # a fresh slot re-teaches everything from scratch
	pending_tuts.clear()
	ante = [0, 0, 0, 0, 0, 0]   # every venue back to its opening bar
	stamina_max = 100.0 + 9.0 * float(endurance)
	stamina = stamina_max
	save_progress()


func slot_path(i: int) -> String:
	return "user://juggle_slot%d.cfg" % i


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
	var fn := "juggle_slot%d.cfg" % i
	if dir != null and dir.file_exists(fn):
		dir.remove(fn)


func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) == OK:
		set_shake = bool(cf.get_value("opt", "shake", true))
		set_flags = bool(cf.get_value("opt", "flags", true))
		set_collide = bool(cf.get_value("opt", "collide", false))
		set_music = bool(cf.get_value("opt", "music", true))
		set_sfx = bool(cf.get_value("opt", "sfx", true))
		set_fullscreen = bool(cf.get_value("opt", "fullscreen", false))
		K_LC = int(cf.get_value("keys", "lc", KEY_D))
		K_LT = int(cf.get_value("keys", "lt", KEY_F))
		K_RC = int(cf.get_value("keys", "rc", KEY_K))
		K_RT = int(cf.get_value("keys", "rt", KEY_J))
		K_TRICK = int(cf.get_value("keys", "trick", KEY_SPACE))
		K_CYCLE = int(cf.get_value("keys", "cycle", KEY_C))


func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("opt", "shake", set_shake)
	cf.set_value("opt", "flags", set_flags)
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


func remap_input(kc: int) -> void:
	# remap_wait is handled upstream in _input (it captures the raw next key)
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


func draw_remap(font: Font, s: Vector2) -> void:
	view_venue = 2
	draw_backdrop(s)
	view_venue = -1
	draw_rect(Rect2(0, 0, s.x, s.y), Color(0.03, 0.02, 0.03, 0.68))
	draw_title_glow(font, s.y * 0.06, "CONTROLS", 36, Color(1.0, 0.88, 0.5), s)
	draw_ornament(s.x * 0.5, s.y * 0.06 + 62.0, 170.0, Color(0.82, 0.62, 0.34, 0.85))
	var pw := 620.0
	var px := s.x * 0.5 - pw * 0.5
	var oy := s.y * 0.28
	for i in REMAP_ACTS.size():
		var sel := i == remap_sel
		var ry := oy + float(i) * 52.0
		if sel:
			hud_panel(Rect2(px - 16.0, ry - 26.0, pw + 32.0, 46.0))
		var nm := String(REMAP_ACTS[i][1])
		draw_string(font, Vector2(px, ry), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1.0, 0.9, 0.6) if sel else Color(0.8, 0.74, 0.66))
		var kname := OS.get_keycode_string(action_key(String(REMAP_ACTS[i][0])))
		if sel and remap_wait:
			var pa := 0.5 + 0.5 * sin(float(cine_tick) * 0.12)
			draw_string(font, Vector2(px + pw - 220.0, ry), "press a key...", HORIZONTAL_ALIGNMENT_RIGHT, 220.0, 18, Color(1.0, 0.85, 0.45, 0.5 + 0.5 * pa))
		else:
			draw_keycap(font, px + pw - maxf(28.0, 14.0 + 7.0 * float(kname.length())), ry - 15.0, kname)
	var refy := oy + float(REMAP_ACTS.size()) * 52.0 + 22.0
	draw_string(font, Vector2(0, refy), "the pad is fixed: L1 R1 catch, L2 R2 throw, A trick, Y switch", HORIZONTAL_ALIGNMENT_CENTER, s.x, 14, Color(0.72, 0.66, 0.6))
	# the other in-play keys, listed here so live play never has to show them
	draw_ornament(s.x * 0.5, refy + 26.0, 150.0, Color(0.82, 0.62, 0.34, 0.6))
	draw_string(font, Vector2(0, refy + 50.0), "OTHER KEYS", HORIZONTAL_ALIGNMENT_CENTER, s.x, 14, Color(0.95, 0.8, 0.55, 0.9))
	draw_string(font, Vector2(0, refy + 74.0), "Enter  finish / end the set      Esc  pause      Tab  character sheet      S  shop", HORIZONTAL_ALIGNMENT_CENTER, s.x, 15, Color(0.82, 0.76, 0.66))
	draw_string(font, Vector2(0, refy + 98.0), "practice only:    R  restart      3 to 7  ball count      O  change prop      P  change pattern", HORIZONTAL_ALIGNMENT_CENTER, s.x, 15, Color(0.82, 0.76, 0.66))
	draw_string(font, Vector2(0, s.y - 40.0), "Up / Down    Enter rebind    Esc back", HORIZONTAL_ALIGNMENT_CENTER, s.x, 15, Color(0.7, 0.66, 0.6))
	draw_vignette(s, 0.5)
	draw_frame(s, 22.0, Color(0.82, 0.62, 0.34, 0.5))


func seed_input_edges() -> void:
	# prime the edge detector with the keys' REAL current state, so a key still
	# held from the establishing card (Space especially, which would prime a
	# trick) cannot fire a phantom edge on the first play frame
	var dev := pad_dev()
	_prev["lc"] = Input.is_physical_key_pressed(K_LC) or (dev >= 0 and Input.is_joy_button_pressed(dev, JOY_BUTTON_LEFT_SHOULDER))
	_prev["rc"] = Input.is_physical_key_pressed(K_RC) or (dev >= 0 and Input.is_joy_button_pressed(dev, JOY_BUTTON_RIGHT_SHOULDER))
	_prev["lt"] = Input.is_physical_key_pressed(K_LT) or (dev >= 0 and Input.get_joy_axis(dev, JOY_AXIS_TRIGGER_LEFT) > 0.5)
	_prev["rt"] = Input.is_physical_key_pressed(K_RT) or (dev >= 0 and Input.get_joy_axis(dev, JOY_AXIS_TRIGGER_RIGHT) > 0.5)
	_prev["trick"] = Input.is_physical_key_pressed(K_TRICK) or (dev >= 0 and Input.is_joy_button_pressed(dev, JOY_BUTTON_A))
	_prev["cycle"] = Input.is_physical_key_pressed(K_CYCLE) or (dev >= 0 and Input.is_joy_button_pressed(dev, JOY_BUTTON_Y))
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
	var p_tk := false
	var p_cy := false
	if dev >= 0:
		p_lc = Input.is_joy_button_pressed(dev, JOY_BUTTON_LEFT_SHOULDER)
		p_rc = Input.is_joy_button_pressed(dev, JOY_BUTTON_RIGHT_SHOULDER)
		p_tk = Input.is_joy_button_pressed(dev, JOY_BUTTON_A)
		p_cy = Input.is_joy_button_pressed(dev, JOY_BUTTON_Y)
		_trig["lt"] = _trig_held("lt", Input.get_joy_axis(dev, JOY_AXIS_TRIGGER_LEFT))
		_trig["rt"] = _trig_held("rt", Input.get_joy_axis(dev, JOY_AXIS_TRIGGER_RIGHT))
	else:
		_trig["lt"] = false
		_trig["rt"] = false
	var p_lt := bool(_trig["lt"])
	var p_rt := bool(_trig["rt"])
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
	_note_device(k_lc or k_lt or k_rc or k_rt or k_tk, p_lc or p_lt or p_rc or p_rt or p_tk or p_cy)
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
	# the top face button mirrors the C key and steps which trick Space is loaded
	# with. lessons and the results card lock C, so the pad honours that too.
	if p_cy and not bool(_prev["cycle"]) and not tut_active and not results_open:
		cycle_trick()
	_prev["cycle"] = p_cy


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
	if toggle_on == TR_RCASC:
		return true
	if toggle_on == TR_WFALL and h == RIGHT:
		return true
	if toggle_on == TR_TENNIS:
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
	if pattern == COLUMNS or toggle_on == TR_COLS:
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
	if pattern == COLUMNS or toggle_on == TR_COLS:
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
# next throw departs from; once empty, exactly where the ball just thrown its
# way was aimed, and nowhere else until that catch (or a whiff) resolves.
func hand_target(h: int) -> Vector2:
	var p := slot_pos(h, throw_slot(h)) if not stack(h).is_empty() else slot_pos(h, hand_catch_rest[h])
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

func max_balls() -> int:
	# THREE to start; every larger load is earned through Strength, each landing a bit
	# before the venue that leans on it (Louis). Four is the first unlock now, not free.
	var m := 3
	if strength >= 9:
		m = 4
	if strength >= 15:
		m = 5
	if strength >= 23:
		m = 6
	if strength >= 33:
		m = 7
	return m


func next_ball_strength() -> int:
	# Strength needed for the next ball unlock, or 0 if already at the cap
	if strength < 9:
		return 9
	if strength < 15:
		return 15
	if strength < 23:
		return 23
	if strength < 33:
		return 33
	return 0


func count_air_scale() -> float:
	# the tap-height FLOOR scales with the load: 3-4 balls stay snappy and low, but 5/6/7
	# must fly higher just to have air to weave in, so even a tap lofts a big load enough
	# to juggle. ~+45% airtime at six matches the hold a real six-ball fountain needs.
	match num_balls:
		5: return 1.3
		6: return 1.45
		7: return 1.6
		_: return 1.0


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
	# per-SET booking state re-arms every run (the per-BOOKING state - set_index,
	# booking_score, encore - is owned by begin_performance and next_set, never here,
	# so practice and a dev autoplay leave it at its harmless defaults)
	set_cleared = false
	set_collapsed = false
	overtime = 0.0
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
	if not stack(h).is_empty():
		return  # hand occupied; you physically cannot catch (this IS the traffic rule)
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
	# secured. Harder patterns AND harder loads pay more per catch (their base
	# difficulty is the reward), so grinding the tamest routine is never the best.
	# encore_score_mult zeroes light props on a "For the Danger" night.
	var pm := pattern_mult() * object_mult() * encore_score_mult()
	best.state = STATE_HAND
	stack(h).append(best)
	catch_flash[h] = tick
	caught += 1
	career["catches"] = int(career["catches"]) + 1
	if tut_active:
		tut_on_catch()   # a guided lesson counts your clean catches toward its goal
	stamina = maxf(0.0, stamina - STAM_DRAIN_CATCH * energy_mult() * (1.0 + WEIGHT_STAM * float(prop_weight(best.kind) - 1)))
	play_sfx(_catch_sound(best.kind), -20.0)   # the prop's own timbre, now just a faint texture
	var sc_before := score
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
	# the record chase: passing your own best AT this venue mid-booking is a moment. The
	# record is now the whole night's booking_score, so the live total is book_total()
	# (banked sets plus this set), which is what a completed booking will be judged on.
	if mode == MODE_PERFORM and not record_broken and run_venue >= 0 and run_venue < rec_table().size() \
			and rec_table()[run_venue] > 0 and book_total() > rec_table()[run_venue]:
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
	# THE BOOKING: this catch (with any trick bonus above) may clear the set's target,
	# unlocking the walk-off; every catch PAST the target grows the overtime multiplier
	# you gamble by staying out for. A catch that itself crosses the line clears the set
	# but earns no overtime yet - overtime is strictly what you catch beyond the number.
	if booking_active and mode == MODE_PERFORM and not tut_active:
		if set_cleared:
			overtime = minf(OVERTIME_MAX, overtime + OVERTIME_PER_CATCH)
		check_set_cleared()


func check_set_cleared() -> void:
	# the instant the set's score reaches the target, the gate opens: the crowd roars,
	# the HUD flips to the walk-off prompt, and finish_performance() will now bank.
	if set_cleared or not booking_active or mode != MODE_PERFORM or tut_active:
		return
	if score >= set_target():
		set_cleared = true
		var s := get_viewport_rect().size
		add_popup(Vector2(s.x * 0.5, s.y * 0.24), "TARGET CLEARED  -  walk off, or push for more", Color(1.0, 0.86, 0.42))
		play_sfx("cheer", -5.0)
		play_sfx("record", -8.0)
		spawn_parts(Vector2(s.x * 0.5, s.y * 0.16), Color(1.0, 0.85, 0.45), 22, 2.5, "confetti")


# -----------------------------------------------------------------------------
# Throw: charge on THROW down-edge, launch on release. Longer hold = higher and
# less accurate. Height buys airtime (thins traffic) at the cost of a harder catch.
# -----------------------------------------------------------------------------

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
	# an active TOGGLE trick reshapes every throw while it runs, and Overthrow
	# (a one-shot) sends this single throw up and over the top of the pattern.
	# A toggle only TAGS a throw the one-shot has not already claimed: the tag
	# decides which trick the catch pays, and the loud one-shot must never be
	# paid out as the toggle's small per-catch bonus.
	# The SHOWER's and HALF SHOWER's high hand ride the same over-the-top road
	# as the toggles (that is what those patterns ARE), so they inherit the
	# outer launch, the wide landing, and the corner dodge in one mechanic.
	var over_top := this_trick == TR_OVER
	if h == RIGHT and pattern in [SHOWER, HALFSHOWER]:
		over_top = true
	if toggle_on == TR_COLS:
		if this_trick < 0:
			this_trick = TR_COLS
	elif toggle_on == TR_WFALL:
		if h == RIGHT:
			over_top = true
			if this_trick < 0:
				this_trick = TR_WFALL
		elif this_trick < 0:
			# the other hand keeps the weave, but forced LOW (a ceiling, not a floor),
			# so it visibly flows under the over-the-top side instead of drifting up
			# to meet it when the player holds both hands about the same
			air = mini(air, int(round(base_air + WATERFALL_LOW * HOLD_GAIN * gain_mult * float(HOLD_MAX))))
	elif toggle_on == TR_RCASC:
		over_top = true
		if this_trick < 0:
			this_trick = TR_RCASC
	elif toggle_on == TR_TENNIS:
		if tennis_ball == null or not balls.has(tennis_ball):
			tennis_ball = b   # the marked ball: the first one thrown after the toggle
		if b == tennis_ball:
			over_top = true
			if this_trick < 0:
				this_trick = TR_TENNIS
	if over_top:
		var high_min := OVER_TOP_MIN
		if this_trick == TR_WFALL:
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
	var col_lanes := pattern == COLUMNS or toggle_on == TR_COLS
	if col_lanes and not over_top and this_trick != TR_HIGH and this_trick != TR_BTB:
		if col_air_ref < 0.0:
			col_air_ref = float(air)
		else:
			air = int(round(lerp(float(air), col_air_ref, COLUMNS_SYNC)))
		col_air_ref = lerp(col_air_ref, float(air), 0.5)
	# frac is the height ACTUALLY reached (measured off the full-strength tap floor), so a
	# sagging under-strength throw reads as the low throw it is: easier to catch, worth less
	# Applause, and it clamps to 0 when the prop is too heavy to loft at all. The ceiling is
	# 1.8, which only a HELD High Toss reaches (plain throws top out at 1.4): every consumer
	# of height that must not scale past the design cap clamps itself at 1.4 internally.
	var frac := clampf(float(air - BASE_AIR) / (HOLD_GAIN * float(HOLD_MAX)), 0.0, 1.8)
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
	stamina = maxf(0.0, stamina - STAM_DRAIN_THROW * energy_mult() * (1.0 + WEIGHT_STAM * float(weight - 1)))
	# where the throw is headed: crossing patterns swap hands, columns (pattern or
	# toggle) keep each ball its lane, and an over-the-top throw always crosses,
	# landing a touch wide of the usual catch point
	var cross := pattern in [CASCADE, HALFSHOWER, SHOWER]
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
	# Behind the Back is a flourish, drawn as a high wide sweeping loop in flight_pos

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
	# a clean, controlled (low) throw earns a little Applause; a very high one does not
	# and flags itself above the stage so the player learns height control. An
	# under-strength throw is low but sloppy, so the deficit strips most of that reward:
	# a sagging heavy prop should not read to the crowd as tidy control.
	applause = minf(1.0, applause + 0.004 * (1.0 - clampf(frac, 0.0, 1.0)) * (1.0 - 0.8 * deficit))
	# but now that the crowd's patience is a resource (Phase 2), a genuinely BIG throw
	# thrills them: on stage, height feeds the meter a little, so spectacle buys time
	# and a timid low weave slowly bores the room even as it stays tidy.
	if mode == MODE_PERFORM and not tut_active:
		applause = minf(1.0, applause + APPL_THROW_HEIGHT * clampf(frac, 0.0, 1.4) * (1.0 - 0.8 * deficit))
	if set_flags and frac >= 1.0:
		add_popup(Vector2(outer_pos(b.to_hand).x, get_viewport_rect().size.y * 0.31), "too high", Color(1.0, 0.82, 0.45, 0.9))
	if mode == MODE_PERFORM and not tut_active and frac >= 1.1:
		play_sfx("gasp", -13.0)   # the crowd inhales at a genuinely risky throw
	play_sfx("throw", -13.0, clampf(1.2 - 0.09 * float(weight - 1) - 0.15 * frac, 0.5, 1.4))   # whup, lower for heavy/high
	if tut_active:
		tut_on_throw(h)   # a guided lesson watches your throws to advance its steps


func pattern_unlocked(i: int) -> bool:
	return level >= int(PATTERNS[i]["lvl"])


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
	var un: Array = []
	for i in PATTERNS.size():
		if pattern_unlocked(i):
			un.append(i)
	if un.size() <= 2 and level < 3:
		set_trick_msg("more patterns unlock at level %d" % int(PATTERNS[COLUMNS]["lvl"]))
		return
	var idx := un.find(pattern_sel)
	pattern_sel = int(un[(idx + 1) % un.size()]) if idx >= 0 else int(un[0])
	set_trick_msg("%s  -  %s" % [String(PATTERNS[pattern_sel]["name"]).to_upper(), String(PATTERNS[pattern_sel]["desc"])])
	play_sfx("ui2", -13.0)
	start_run(num_balls)


func trick_unlocked(i: int) -> bool:
	return level >= int(TRICKS[i]["lvl"])


func unlocked_tricks() -> Array:
	# in unlock order (by level), so C cycles the way the player learned them
	var out: Array = []
	for i in TRICKS.size():
		if trick_unlocked(i):
			out.append(i)
	out.sort_custom(func(a, b): return int(TRICKS[a]["lvl"]) < int(TRICKS[b]["lvl"]))
	return out


func balls_airborne() -> int:
	var n := 0
	for b in balls:
		if b.state == STATE_FLIGHT:
			n += 1
	return n


func spinning() -> bool:
	return tick <= spin_until


func set_trick_msg(m: String) -> void:
	trick_msg = m
	trick_msg_tick = tick


func on_trick() -> void:
	# The TRICK key (Space) is the one-shot powerup. With an arm trick selected it
	# primes exactly the next throw (pressing again waves it off); with Spin selected
	# it performs the spin right now. The selection itself lives on C (cycle_trick).
	# in a lesson, the trick being TAUGHT is always usable, whatever your level - the
	# step selects it and skips the unlock gate, so it can never dead-end waiting for a
	# Space press the gate silently refused (Louis: the trick lesson would not respond).
	if tut_active and tut_step_data().has("trick"):
		trick_sel = int(tut_step_data()["trick"])
	elif unlocked_tricks().is_empty():
		set_trick_msg("first trick unlocks at level %d" % int(TRICKS[0]["lvl"]))
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
				tennis_ball = null
				set_trick_msg("%s OFF" % String(t["name"]).to_upper())
				play_sfx("ui", -16.0)
			else:
				toggle_on = trick_sel
				toggle_scored = false
				tennis_ball = null   # Tennis marks the next thrown ball
				if trick_sel == TR_COLS:
					col_air_ref = -1.0
					col_mid_ball = null
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

func xp_to_next(lv: int) -> int:
	return int(round(60.0 * pow(float(lv), 1.4))) + 40 * lv


func add_xp(amount: int) -> void:
	if amount <= 0:
		return
	var prev_level := level
	xp += amount
	run_xp += amount
	var leveled := false
	while xp >= xp_to_next(level):
		xp -= xp_to_next(level)
		level += 1
		points += POINTS_PER_LEVEL
		leveled = true
	if leveled:
		var s := get_viewport_rect().size
		add_popup(Vector2(s.x * 0.5, s.y * 0.34), "LEVEL %d" % level, Color(1.0, 0.9, 0.5))
		announce_new_tricks(prev_level)   # a level that crosses a trick's gate teaches it
		announce_new_patterns(prev_level)   # and so does one that crosses a pattern's
		save_progress()


func queue_lesson(id: String) -> void:
	# an unlock during a live set cannot interrupt it, so its lesson WAITS at the hub.
	# Queued once, taught once, then remembered forever (seen_tuts). A lesson already
	# taught, or already waiting, is never re-queued.
	if seen_tuts.has(id) or pending_tuts.has(id):
		return
	pending_tuts.append(id)


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


func announce_new_patterns(prev_level: int) -> void:
	# a pattern whose unlock level we just crossed announces itself on the trick
	# feedback line, teaching the P key in the same breath, and queues its lesson
	for i in PATTERNS.size():
		var lv := int(PATTERNS[i]["lvl"])
		if lv > prev_level and lv <= level:
			set_trick_msg("NEW PATTERN  -  %s  -  P switches patterns in training" % String(PATTERNS[i]["name"]).to_upper())
			queue_lesson("pattern_%s" % String(PATTERNS[i]["id"]))
			play_sfx("streak", -6.0)


func announce_new_tricks(prev_level: int) -> void:
	# a trick whose unlock level we just crossed gets a banner and becomes the
	# SELECTED trick, so the very next Space press does the thing the banner just
	# explained (nothing fires by itself: the one-shot still wants its own press),
	# and queues a hands-on lesson to be taught at the hub
	for i in TRICKS.size():
		var lv := int(TRICKS[i]["lvl"])
		if lv > prev_level and lv <= level:
			trick_unlock = i
			trick_unlock_tick = tick
			trick_sel = i
			trick_primed = false
			queue_lesson("trick_%s" % String(TRICKS[i]["id"]))
			play_sfx("streak", -5.0)


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


func on_round_end() -> void:
	if round_scored:
		return
	round_scored = true
	# a set of a real booking resolves through the booking machinery (bank + advance, or
	# end the night). Everything else - practice, a dev autoplay - just banks its XP.
	if mode == MODE_PERFORM and booking_active and not tut_active:
		resolve_set()
		return
	var clean := 1.0
	if caught + dropped > 0:
		clean = float(caught) / float(caught + dropped)
	# harder routines (more balls, heavier props) are worth more XP
	var diff := 1.0 + 0.25 * float(num_balls - MIN_BALLS) + 0.25 * float(prop_weight() - 1)
	add_xp(int(round((float(best_streak) * 4.0 + float(caught) * 1.5) * clean * diff)))
	career["best_streak"] = maxi(int(career["best_streak"]), best_streak)


func resolve_set() -> void:
	# a set just ended - by a clean walk-off (finish_performance) or a collapse (the crowd
	# walked, or the drop limit landed). Roll its play into the booking, then either bank
	# and advance to the next set, or resolve the whole night.
	book_caught += caught
	book_dropped += dropped
	book_best_streak = maxi(book_best_streak, best_streak)
	book_tricks += tricks_landed
	book_trick_score += trick_score
	book_xp += run_xp
	if set_cleared:
		sets_cleared += 1
		# a clean walk-off banks the score with its overtime multiplier. A cleared set that
		# ended in COLLAPSE still counts as cleared - you beat the number - but the overtime
		# and the raw score above the target are lost, banking only the bare target. That is
		# the whole push-your-luck: clear it, then leave with the win or gamble for more.
		var banked := set_target() if set_collapsed else int(round(float(score) * (1.0 + overtime)))
		booking_score += banked
		if set_index < SET_ENCORE:
			play_sfx("coin", -9.0)
			next_set()   # walk out again, one rung higher, the booking_score carried across
		else:
			resolve_booking(true)    # the Encore fell: a complete night
	else:
		# below the target. A voluntary BOW (finish, not a collapse) keeps the crowd happy
		# and still banks the partial score toward the night's pay and record; a COLLAPSE
		# banks nothing for this set. Either way the booking ends here - you did not clear.
		if not set_collapsed:
			booking_score += score
		resolve_booking(false)


func resolve_booking(complete: bool) -> void:
	# the whole night is over. Pay, reputation, records and the win now key off the
	# BOOKING, not a single set: a record means one complete great night, and reputation
	# swings on how much of the booking you cleared rather than the old divide-by-your-own-
	# record (which punished you for having a high best).
	booking_active = false
	var purist_mult := PURIST_BONUS if purist else 1.0
	# a completion XP bonus off the whole night's play
	var clean := 1.0
	if book_caught + book_dropped > 0:
		clean = float(book_caught) / float(book_caught + book_dropped)
	var diff := 1.0 + 0.25 * float(num_balls - MIN_BALLS) + 0.25 * float(prop_weight() - 1)
	var xp_bonus := int(round((float(book_best_streak) * 4.0 + float(book_caught) * 1.5) * clean * diff))
	add_xp(xp_bonus)
	book_xp += xp_bonus
	# how much of the three you cleared: 0, 1/3, 2/3, or a whole night. (f*1.5 - 0.5) gives
	# +1.0 of a swing for a complete booking, 0 for one set, -0.5 for bombing the warm-up.
	var frac := float(sets_cleared) / float(SETS_PER_BOOKING)
	var rep_delta := int(round(float(REP_SWING) * (frac * 1.5 - 0.5) * purist_mult))
	var cur_tier := venue_index_of(reputation)
	if cur_tier + 2 < VENUE_REP.size():
		rep_delta = mini(rep_delta, VENUE_REP[cur_tier + 2] - 1 - reputation)
	reputation = maxi(0, reputation + rep_delta)
	last_rep_delta = rep_delta
	# PAY scales with what you banked (a partial booking pays partial; the score already
	# scales with the venue, so no separate venue multiplier), lifted by Reputation and a
	# Purist premium, with the busking floor so a broke juggler always leaves with something.
	last_pay = int(round(float(booking_score) * BOOK_PAY_PER_SCORE * pay_mult() * purist_mult))
	if money < BROKE_GOLD and booking_score > 0:
		last_pay = maxi(last_pay, BUSK_FLOOR)
	money += last_pay
	if last_pay > 0:
		play_sfx("coin", -8.0)
	# a completed booking raises this venue's standing bar for next time (the ante)
	if complete and run_venue >= 0 and run_venue < ante.size():
		ante[run_venue] += 1
	# the career ledger remembers the night
	career["perfs"] = int(career["perfs"]) + 1
	career["gold_earned"] = int(career["gold_earned"]) + last_pay
	career["tricks"] = int(career["tricks"]) + book_tricks
	career["best_score"] = maxi(int(career["best_score"]), booking_score)
	career["best_streak"] = maxi(int(career["best_streak"]), book_best_streak)
	# the record board keys off the whole night's booking_score. A Purist booking writes
	# to the Purist board and never the assisted one.
	results_record = false
	if run_venue >= 0 and run_venue < rec_table().size() and booking_score > rec_table()[run_venue]:
		rec_table()[run_venue] = booking_score
		results_record = true
	# hand the display vars the BOOKING totals so the results card reads the whole night,
	# not just the final set (this run is finished; these all reset on the next start_run)
	score = booking_score
	caught = book_caught
	dropped = book_dropped
	best_streak = book_best_streak
	tricks_landed = book_tricks
	trick_score = book_trick_score
	run_xp = book_xp
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
		# dev: report the whole-booking outcome and quit, so --demo --booking is a
		# one-shot end-to-end check of the resolve path (targets, banking, pay, rep)
		print("BOOKING venue=%d prop=%d n=%d sets=%d/%d complete=%s booking_score=%d pay=%d rep=%+d record=%s" % [
			run_venue, prop_type, num_balls, sets_cleared, SETS_PER_BOOKING, str(complete),
			booking_score, last_pay, last_rep_delta, str(results_record)])
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
	var a := 0.0 if purist_run() else float(mini(speed, SPEED_CAP)) / 4.0 / 100.0
	if pie_active and not purist_run():
		a += 0.25
	if _frames < amazing_until:
		a += 0.25
	if _frames < chain_until:
		a += 0.25
	if tut_active:
		a = maxf(a, tut_slow())   # a lesson sets a FLOOR on slowness, never a sum: it
								  # must not stack with a Pie into a frozen world
	return clampf(a, 0.0, 1.0)


func tut_slow() -> float:
	# the lesson's own slow-motion floor. A step may pin its own value ("slow" key, e.g.
	# a trick step stays thick while its drill step speeds up); otherwise it eases from
	# thick to real across the lesson's steps, so the player is handed back to full speed
	# gradually rather than dropped out of a slow world into a fast one.
	var steps := tut_lesson(tut_id)
	if tut_step >= 0 and tut_step < steps.size():
		var s: Dictionary = steps[tut_step]
		if s.has("slow"):
			return clampf(float(s["slow"]), 0.0, 1.0)
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
	# how far Strength exceeds the CURRENT prop's requirement, as a fraction of
	# the remaining room up to the stat's own cap (100), not a fixed multiple
	# of the requirement. A fixed multiple (the old 2x-req rule) meant every
	# point of Strength past 96 (double a Torch's 48) did nothing at all;
	# scaling against the stat's real ceiling instead means surplus Strength
	# keeps paying out, however slightly, all the way to 100, for every prop.
	var req := prop_req()
	if req <= 0 or strength <= req:
		return 0.0
	return clampf((float(strength) - float(req)) / maxf(1.0, 100.0 - float(req)), 0.0, 1.0)


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


const VENUE_REP := [0, 100, 300, 700, 1500, 3000]   # reputation at each venue's door
const TOP_VENUE := 5   # the World Arena: the summit of the climb, where the game is won


func debug_jump_venue(i: int) -> void:
	# debug: leap up the ladder by setting Reputation to a venue's door, then land
	# in the day so the higher stages can be played at once (no story to replay).
	i = clampi(i, 0, TOP_VENUE)
	reputation = maxi(reputation, VENUE_REP[i])
	venue_pick = i
	save_progress()
	enter_day()


func venue_index() -> int:
	return venue_index_of(reputation)


func venue_index_of(rep: int) -> int:
	# the stage you play grows as Reputation climbs, six rungs to the World Arena
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
		_:
			return {"name": "World Arena", "glow": Color(0.78, 0.52, 0.96), "floor": Color(0.09, 0.06, 0.12), "spot": 0.08,
				"suit": Color(0.42, 0.20, 0.55), "suit_dk": Color(0.28, 0.12, 0.40), "vest": Color(0.96, 0.82, 0.45), "collar": Color(0.98, 0.94, 0.86)}


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
	# balls are free and effectively unlimited; other props you own by quantity
	return 999 if kind == PROP_BALLS else prop_count[kind]


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


func invest(which: String) -> void:
	if points <= 0:
		return
	var prev_max := max_balls()   # Strength may cross a ball-count gate; catch it below
	match which:
		"acc":
			accuracy = mini(ACC_CAP, accuracy + 1)   # past 100 becomes Focus
		"str":
			strength = mini(100, strength + 1)
		"end":
			endurance = mini(100, endurance + 1)
			stamina_max = 100.0 + 9.0 * float(endurance)
		"spd":
			if speed >= SPEED_CAP:
				return   # the permanent slow tops out (ideas.rtf): no point wasted
			speed += 1
	points -= 1
	check_ball_unlock(prev_max)   # a new ball count queues its own lesson at the hub
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
			strength = clampi(strength + delta, 1, 100)
		"end":
			endurance = clampi(endurance + delta, 0, 100)
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
		prop_type = int(cf.get_value("stats", "prop_type", PROP_BALLS))
		has_glasses = bool(cf.get_value("stats", "glasses", false))
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
		pattern_sel = int(cf.get_value("prog", "pattern_sel", CASCADE))
		var cr: Variant = cf.get_value("prog", "career", {})
		if cr is Dictionary:
			for k in career:
				if (cr as Dictionary).has(k):
					career[k] = int((cr as Dictionary)[k])
		# lessons already taught, and lessons queued but not yet taught, both persist -
		# without this an unlock lesson (Phase 1) re-fired every launch (the seen_tuts bug)
		var st: Variant = cf.get_value("prog", "seen_tuts", [])
		if st is Array:
			seen_tuts.clear()
			for v in (st as Array):
				seen_tuts.append(String(v))
		var pt: Variant = cf.get_value("prog", "pending_tuts", [])
		if pt is Array:
			pending_tuts.clear()
			for v in (pt as Array):
				pending_tuts.append(String(v))
		# the standing ante per venue (bookings cleared there): the raised bar the venue
		# remembers between visits. The rest of the booking is per-night and unsaved.
		var an: Variant = cf.get_value("prog", "ante", [])
		if an is Array:
			for i in mini((an as Array).size(), ante.size()):
				ante[i] = int((an as Array)[i])
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
		if dropped >= drop_limit() or stamina <= 0.0:
			add_popup(b.to_pos + Vector2(0, -28), "SPENT  -  THAT'S THE SET" if exhausted else "THAT'S THE SET", Color(1.0, 0.5, 0.35))
			start_collapse()
		elif applause <= 0.0:
			start_collapse()
	elif mode == MODE_TRAIN and not tut_active and stamina <= 0.0 and running:
		# spent in practice too: end the session so the day can steer you to recovery
		exhausted = true
		running = false


func start_collapse() -> void:
	# the act falls apart: the hands give up and whatever is still held slips from them,
	# so the player watches it all come down. The round ends only once everything has
	# landed (see the collapse step in _physics_process). Marks set_collapsed so the set
	# resolves as a hard ending, which is what strips a cleared set's overtime bonus.
	if collapsing:
		return
	collapsing = true
	set_collapsed = true
	for h in [LEFT, RIGHT]:
		for hb in stack(h):
			balls.erase(hb)
			spawn_falling(hpos[h], hb.kind, hb.color)
		stack(h).clear()


func update_sim() -> void:
	# THE CLOCK (Phase 2): the crowd's patience bleeds every tick while performing, at a
	# venue-scaled rate the Encore can bend. Reach zero and the room empties (the collapse
	# that was always built and never reached). Catches and big throws pay patience back,
	# so keeping the crowd is simply keeping the act alive.
	if mode == MODE_PERFORM and not tut_active and running and not collapsing:
		applause = maxf(0.0, applause - APPL_DECAY[clampi(run_venue, 0, APPL_DECAY.size() - 1)] * encore_decay_mult())
		if applause <= 0.0:
			start_collapse()
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
				var rr := 11.0 * (prop_scale(fly[i].kind) + prop_scale(fly[j].kind))
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

func _draw() -> void:
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
		ST_GAMEOVER:
			draw_gameover(font, s)
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
	draw_juggler(s)
	draw_targets()
	draw_balls_in_flight()
	draw_falling()         # lost props tumbling down to the boards
	draw_egg_shards()      # flying shell pieces read above the stage
	draw_charge_gauges()   # the hold-to-throw height gauge beside a charging hand
	draw_vignette(s, 0.5)  # frame the lit stage so it reads photographed, not flat
	if tut_active:
		draw_tutorial_banner(font, s)   # a lesson shows only the guided banner, no HUD
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
		_:   # world arena: a vast bowl of warm crowd-lights and roaming beams
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
	for b in balls:
		if b.state == STATE_FLIGHT:
			var dd := b.land_tick - tick
			if dd >= -MISS_GRACE and dd < 46:
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


func draw_balls_in_flight() -> void:
	for b in balls:
		if b.state == STATE_FLIGHT:
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


func draw_prop(b: Ball, pos: Vector2) -> void:
	var sc := prop_scale(b.kind)
	# BLACKOUT Encore: only the top of each arc is lit. A prop in the lower two-thirds
	# of its flight is drawn as a bare ghost (a faint halo, no shape), so the player must
	# track it by rhythm and read the apex, then catch what they cannot quite see.
	if encore_on("blackout") and b.state == STATE_FLIGHT:
		var span := maxi(1, b.land_tick - b.launch_tick)
		var p := clampf(float(tick - b.launch_tick) / float(span), 0.0, 1.0)
		if 4.0 * p * (1.0 - p) < 0.55:
			draw_circle(pos, 16.0 * sc, Color(b.color.r, b.color.g, b.color.b, 0.05))
			return
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
	draw_arc(Vector2(0, -14), 7.0, -2.5, -1.2, 6, band, 2.0, true)
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


func draw_prop_icon(kind: int, pos: Vector2) -> void:
	# a small, still version of the prop shape, for menus
	var col := prop_color(kind)
	var sc := minf(prop_scale(kind), 1.0)
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


func hud_panel(r: Rect2) -> void:
	# a soft dark card with an ember hairline, so HUD numbers sit on something
	# instead of floating loose over the stage
	draw_rect(r, Color(0.05, 0.03, 0.045, 0.55))
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
	# the catch keycap labels for whichever device is active (remap-aware)
	if pad_active():
		return ["L1", "R1"]
	return [OS.get_keycode_string(K_LC), OS.get_keycode_string(K_RC)]


func k_throw() -> Array[String]:
	if pad_active():
		return ["L2", "R2"]
	return [OS.get_keycode_string(K_LT), OS.get_keycode_string(K_RT)]


func k_pause() -> Array[String]:
	if pad_active():
		return ["B"]
	return ["Esc"]


func k_trick() -> Array[String]:
	if pad_active():
		return ["A"]
	return [OS.get_keycode_string(K_TRICK)]


func k_cycle() -> Array[String]:
	if pad_active():
		return ["Y"]
	return [OS.get_keycode_string(K_CYCLE)]


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

	# ============================ LEFT RAIL: the contest ============================
	var LX := 18.0
	var LW := 300.0
	if performing and not results_open:
		# --- the booking header: venue, which of the three sets, and the set dots ---
		hud_card(Rect2(LX, 16, LW, 52))
		draw_string(font, Vector2(LX + 14, 40), String(venue_data(run_venue)["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, gold)
		var setnames := ["WARM-UP", "THE SET", "THE ENCORE"]
		var setline := "SET %d / %d   %s" % [set_index + 1, SETS_PER_BOOKING, setnames[clampi(set_index, 0, 2)]]
		if purist:
			setline += "   PURIST"
		draw_string(font, Vector2(LX + 14, 60), setline, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, warm)
		for i in SETS_PER_BOOKING:
			var dotc := Vector2(LX + LW - 20.0 - float(SETS_PER_BOOKING - 1 - i) * 18.0, 34.0)
			if i < sets_cleared:
				draw_circle(dotc, 6.0, gold)
			elif i == set_index:
				draw_arc(dotc, 6.0, 0.0, TAU, 20, gold, 2.0, true)
			else:
				draw_circle(dotc, 5.0, Color(0.35, 0.28, 0.24, 0.8))

		# --- the TARGET card: the hero. Your score climbing toward the number to beat. ---
		var target := set_target()
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
		var tfrac := clampf(float(score) / float(maxi(1, target)), 0.0, 1.0)
		var barx := LX + 14
		var barw := LW - 28
		if set_cleared:
			var pl := 0.72 + 0.28 * sin(float(tick) * 0.16)
			draw_rect(Rect2(barx - 1, tcard_y + 63, barw + 2, 20.0), Color(1.0, 0.86, 0.42, pl))
			var otxt := "CLEARED   Enter to bank"
			if overtime > 0.001:
				otxt = "CLEARED  x%.2f   Enter to bank" % (1.0 + overtime)
			draw_string(font, Vector2(barx, tcard_y + 78), otxt, HORIZONTAL_ALIGNMENT_CENTER, barw, 12, Color(0.12, 0.06, 0.03))
		else:
			var fcol := Color(0.82, 0.5, 0.28).lerp(Color(1.0, 0.86, 0.42), tfrac)
			draw_meter(barx, tcard_y + 63, barw, 20.0, tfrac, fcol)
			draw_string(font, Vector2(barx, tcard_y + 78), "target  %s" % commafy(target), HORIZONTAL_ALIGNMENT_CENTER, barw, 12, Color(1.0, 0.95, 0.82))
		# banked-so-far and the take-a-bow hint
		if booking_score > 0:
			draw_string(font, Vector2(LX + 14, tcard_y + 100), "banked  %s" % commafy(booking_score), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.85, 0.78, 0.6, 0.8))
		if not set_cleared:
			draw_string(font, Vector2(LX + LW - 134, tcard_y + 100), "Enter: take a bow", HORIZONTAL_ALIGNMENT_RIGHT, 120.0, 10, Color(0.72, 0.66, 0.58, 0.7))

		# --- the CROWD (patience clock) and the DROP limit ---
		var ccard_y := 194.0
		hud_card(Rect2(LX, ccard_y, LW, 70), Color(0.95, 0.5, 0.4, 0.35))
		draw_string(font, Vector2(LX + 14, ccard_y + 22), "THE CROWD", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.9, 0.72, 0.62))
		var pcol := Color(0.9, 0.3, 0.2).lerp(Color(1.0, 0.85, 0.42), applause)
		draw_meter(LX + 14, ccard_y + 28, LW - 28, 12.0, applause, pcol)
		draw_rect(Rect2(LX + 14 + (LW - 28) * peak_applause - 1.0, ccard_y + 26, 2.0, 16.0), Color(1.0, 0.95, 0.8, 0.6))
		draw_string(font, Vector2(LX + 14, ccard_y + 58), "DROPS", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.9, 0.6, 0.55))
		draw_drop_marks(LX + 72, ccard_y + 48, drop_limit(), dropped)

		# --- the ENCORE condition, only while the Encore is the set at hand ---
		if set_index == SET_ENCORE and encore >= 0 and encore < ENCORES.size():
			var ec := Color(1.0, 0.55, 0.42)
			hud_card(Rect2(LX, 272, LW, 66), Color(ec.r, ec.g, ec.b, 0.5))
			draw_string(font, Vector2(LX + 14, 294), String(ENCORES[encore]["name"]).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, ec)
			_wrap_text(font, String(ENCORES[encore]["desc"]), LX + 14, 312, LW - 28, 11, Color(0.9, 0.82, 0.72, 0.9))
	elif not performing:
		# training: no contest, just what you are drilling
		hud_card(Rect2(LX, 16, LW, 64))
		var tl := "PRACTICE" + ("   -   DEBUG" if debug_mode else "")
		draw_string(font, Vector2(LX + 14, 40), tl, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.72, 0.82, 0.9))
		draw_string(font, Vector2(LX + 14, 60), "%s   -   %s   -   no crowd, no pay" % [String(cur_prop()["name"]).to_lower(), String(PATTERNS[pattern]["name"]).to_lower()], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, warm)
		if next_ball_strength() > 0:
			draw_string(font, Vector2(LX + 14, 78 + 16), "next ball at Strength %d" % next_ball_strength(), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.72, 0.66, 0.56, 0.85))

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
		# STATE: stamina, purse, reputation, level
		hud_card(Rect2(RX, 74, RW, 132))
		var sx := RX + 14.0
		var sw := RW - 28.0
		var sfrac := clampf(stamina / maxf(1.0, stamina_max), 0.0, 1.0)
		draw_string(font, Vector2(sx, 96), "STAMINA", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.85, 0.9, 0.85, 0.85))
		draw_string(font, Vector2(sx + sw - 80.0, 96), "%d / %d" % [int(round(stamina)), int(stamina_max)], HORIZONTAL_ALIGNMENT_RIGHT, 80.0, 11, Color(0.85, 0.9, 0.85, 0.85))
		var stcol := Color(0.55, 0.80, 0.6)
		if sfrac < STAM_LOW:
			stcol = stcol.lerp(Color(0.95, 0.35, 0.25), clampf((STAM_LOW - sfrac) / STAM_LOW, 0.0, 1.0))
		draw_meter(sx, 102, sw, 11.0, sfrac, stcol)
		draw_circle(Vector2(sx + 7.0, 132.0), 6.0, gold)
		draw_circle(Vector2(sx + 5.0, 130.0), 2.0, Color(1.0, 0.95, 0.7))
		draw_string(font, Vector2(sx + 20.0, 138.0), "%s gold" % commafy(money), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, gold)
		draw_string(font, Vector2(sx + sw - 160.0, 138.0), "Rep %s  %s" % [commafy(reputation), rep_tier()], HORIZONTAL_ALIGNMENT_RIGHT, 160.0, 12, Color(0.82, 0.72, 0.85))
		var need := xp_to_next(level)
		var xf := clampf(float(xp) / float(maxi(1, need)), 0.0, 1.0)
		# LV label and the exact xp on their own row, so the number never sits
		# muddied on top of the meter fill; the bar spans full width beneath
		draw_string(font, Vector2(sx, 160), "LV %d" % level, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, gold)
		draw_string(font, Vector2(sx + sw - 110.0, 160), "%s / %s" % [commafy(xp), commafy(need)], HORIZONTAL_ALIGNMENT_RIGHT, 110.0, 11, Color(0.85, 0.78, 0.6, 0.85))
		draw_meter(sx, 166, sw, 8.0, xf, Color(0.9, 0.7, 0.35))
		if points > 0:
			var pa := 0.75 + 0.25 * sin(float(tick) * 0.08)
			draw_string(font, Vector2(sx, 192), "+%d stat point%s  -  Tab" % [points, "" if points == 1 else "s"], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.7, 0.95, 0.7, pa))

	# a freshly unlocked trick announces itself, non-blocking, only while juggling
	if not tut_active and running and trick_unlock >= 0 and tick - trick_unlock_tick < 360:
		draw_trick_unlock_banner(font, s)
	# trick feedback line, tucked LOW under the performer so it never sits in the arcs
	if not tut_active and trick_msg != "" and tick - trick_msg_tick < 90:
		var ta := clampf(1.0 - float(tick - trick_msg_tick) / 90.0, 0.0, 1.0)
		draw_text_shout(font, Vector2(s.x * 0.5 - 200, s.y - 128.0), trick_msg, HORIZONTAL_ALIGNMENT_CENTER, 400, 17, Color(1.0, 0.88, 0.55, ta))
	# the loaded-trick readout (bottom-right corner, out of the way)
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
			var tnames := "( L2 or R2 )" if pad_active() else "( %s or %s )" % [OS.get_keycode_string(K_LT), OS.get_keycode_string(K_RT)]
			draw_text_shout(font, Vector2(0, s.y * 0.22), "press a THROW  %s  to %s" % [tnames, verb],
				HORIZONTAL_ALIGNMENT_CENTER, s.x, 21, Color(1.0, 0.86, 0.55, pa2))
			draw_text_shout(font, Vector2(0, s.y * 0.22 + 26.0), "bookings and rest live in the day  -  Esc, then End the session",
				HORIZONTAL_ALIGNMENT_CENTER, s.x, 14, Color(0.85, 0.75, 0.6, 0.8))
		elif not running:
			# training keeps the plain end-of-run line (a booking goes straight to results)
			draw_text_shout(font, Vector2(0, s.y * 0.20), "ROUND OVER", HORIZONTAL_ALIGNMENT_CENTER, s.x, 40, Color(1.0, 0.5, 0.4))
			draw_text_shout(font, Vector2(0, s.y * 0.20 + 40), "best streak %d   XP +%d   -   R goes again, Enter ends the session" % [best_streak, run_xp], HORIZONTAL_ALIGNMENT_CENTER, s.x, 19, Color(0.9, 0.82, 0.7))


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
	var complete := sets_cleared >= SETS_PER_BOOKING
	var htag := "BOOKING COMPLETE" if complete else ("BOOKING  -  %d of %d cleared" % [sets_cleared, SETS_PER_BOOKING])
	var htc := Color(1.0, 0.86, 0.45) if complete else Color(0.9, 0.72, 0.55)
	draw_string(font, Vector2(lx, py + 40.0), htag, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, htc)
	draw_string(font, Vector2(lx, py + 74.0), String(venue_data(run_venue)["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1.0, 0.86, 0.5))
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

	# footer: how to continue, breathing gently once everything is revealed. the
	# shop and sheet stay keyboard names even on pad, since they have no button.
	if age > 80:
		var fa := 0.7 + 0.3 * sin(float(tick) * 0.05)
		var foot := ""
		if pending_win:
			# the top stage just fell: the first key rolls into the victory screen
			foot = "you have conquered the final stage  -  any key"
		elif too_tired():
			# the reason R will not work, in words, right where the player looks
			foot = "too tired to go again  -  Enter back to the day, then sleep"
		else:
			var kgo := "A" if pad_active() else "R"
			var kmenu := "Enter" if not pad_active() else "B"
			foot = "%s  go again      S  shop      %s  back to the day" % [kgo, kmenu]
			if points > 0:
				foot = "%s  go again      Tab  +%d point%s      S  shop      %s  back to the day" % [kgo, points, "" if points == 1 else "s", kmenu]
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
	var sel := trick_sel if trick_sel >= 0 and trick_unlocked(trick_sel) else int(un[0])
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
	draw_string(font, Vector2(px + 10.0, s.y - 52.0), "TRICK  -  %s" % label, HORIZONTAL_ALIGNMENT_CENTER, pw - 20.0, 16, lc)
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
	# bottom-LEFT mirror of the trick readout: the OBJECT and PATTERN in play, and the
	# keys to switch each. Live during a performance now (re-skins / reshapes on the
	# fly), a fresh deal in practice - the hints are the same either way (Louis).
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
	draw_hints_row(font, cx, s.y - 40.0, [[["O"], "object"], [["P"], "pattern"]])


func draw_sheet(font: Font, s: Vector2) -> void:
	draw_rect(Rect2(0, 0, s.x, s.y), Color(0.04, 0.02, 0.03, 0.82))
	var pw := 580.0
	var ph := 440.0
	var px := s.x * 0.5 - pw * 0.5
	var py := s.y * 0.5 - ph * 0.5
	draw_rect(Rect2(px, py, pw, ph), Color(0.12, 0.07, 0.08, 0.98))
	draw_rect(Rect2(px, py, pw, ph), Color(0.9, 0.6, 0.35, 0.5), false, 2.0)

	var tx := px + 36.0
	var innerw := pw - 72.0
	draw_string(font, Vector2(tx, py + 48.0), "JUGGLER", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1.0, 0.86, 0.55))
	if debug_mode:
		draw_string(font, Vector2(tx + 140.0, py + 48.0), "DEBUG BUILD", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.55, 0.9, 1.0))
	draw_string(font, Vector2(px + pw - 190.0, py + 40.0), "Level %d" % level, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1.0, 0.9, 0.6))
	draw_string(font, Vector2(px + pw - 190.0, py + 62.0), "%d gold" % money, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1.0, 0.86, 0.45))
	draw_string(font, Vector2(px + pw - 190.0, py + 82.0), "Rep %d  %s" % [reputation, rep_tier()], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.82, 0.72, 0.85))
	# xp bar
	var need := xp_to_next(level)
	var xf := clampf(float(xp) / float(maxi(1, need)), 0.0, 1.0)
	var xbw := 300.0   # kept short so it never runs under the gold/reputation column
	draw_rect(Rect2(tx, py + 66.0, xbw, 10.0), Color(0.2, 0.14, 0.11, 0.8))
	draw_rect(Rect2(tx, py + 66.0, xbw * xf, 10.0), Color(0.9, 0.7, 0.35))
	draw_string(font, Vector2(tx, py + 92.0), "%d / %d xp to next level" % [xp, need], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.8, 0.72, 0.58))

	var str_note := "heavy props fly higher and catch easier  -  %d balls now" % max_balls()
	if next_ball_strength() > 0:
		str_note = "heavy props steadier and easier to catch  -  %d-ball unlock at Str %d" % [max_balls() + 1, next_ball_strength()]
	var acc_note := "higher chance to catch off-Perfect; lands throws closer"
	if accuracy > 100:
		if focus() <= 100.0:
			acc_note = "Focus %d  -  cheaper stamina every action" % int(focus())
		else:
			acc_note = "Focus %d  -  min stamina cost, +%d Perfect ticks" % [int(focus()), perfect_window() - W_PERFECT]
	var ry := py + 132.0
	draw_stat_row(font, tx, ry, innerw, "ACCURACY", accuracy, acc_note, "1")
	ry += 52.0
	draw_stat_row(font, tx, ry, innerw, "STRENGTH", strength, str_note, "2")
	ry += 52.0
	draw_stat_row(font, tx, ry, innerw, "ENDURANCE", endurance, "raises your maximum stamina", "3")
	ry += 52.0
	var spd_pct := speed / 4
	var spd_note := "the world runs %d%% slower for you  -  4 points per percent, cap %d%%" % [spd_pct, SPEED_CAP / 4]
	if speed >= SPEED_CAP:
		spd_note = "the world runs %d%% slower for you  -  at the cap" % spd_pct
	draw_stat_row(font, tx, ry, innerw, "SPEED", speed, spd_note, "4")
	ry += 52.0
	# stamina is a resource, not an investable stat
	draw_string(font, Vector2(tx, ry), "STAMINA", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.8, 0.9, 0.85))
	draw_rect(Rect2(tx + 130.0, ry - 13.0, innerw - 260.0, 12.0), Color(0.2, 0.14, 0.11, 0.8))
	draw_rect(Rect2(tx + 130.0, ry - 13.0, (innerw - 260.0) * clampf(stamina / maxf(1.0, stamina_max), 0.0, 1.0), 12.0), Color(0.55, 0.80, 0.6))
	draw_string(font, Vector2(tx + innerw - 120.0, ry), "%d / %d" % [int(round(stamina)), int(stamina_max)], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.85, 0.9, 0.85))
	draw_string(font, Vector2(tx, ry + 16.0), "drains as you play; low stamina makes throws wild", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.75, 0.68, 0.6))

	var by := py + ph - 46.0
	if debug_mode:
		draw_string(font, Vector2(tx, by), "DEBUG  1/2/3/4 up  Q/W/E/R dn  M/N gold  ,/. rep", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.6, 0.9, 1.0))
	elif points > 0:
		draw_string(font, Vector2(tx, by), "%d point%s to spend  -  press 1 / 2 / 3 / 4" % [points, "" if points == 1 else "s"], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.7, 0.95, 0.7))
	else:
		draw_string(font, Vector2(tx, by), "Skill sets your score. Stats only ease the climb.", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.75, 0.7, 0.62))
	draw_string(font, Vector2(px + pw - 150.0, by), "Tab to resume", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.8, 0.72, 0.6))


func draw_shop(font: Font, s: Vector2) -> void:
	draw_rect(Rect2(0, 0, s.x, s.y), Color(0.04, 0.02, 0.03, 0.85))
	var pw := 640.0
	var ph := 502.0
	var px := s.x * 0.5 - pw * 0.5
	var py := s.y * 0.5 - ph * 0.5
	draw_rect(Rect2(px, py, pw, ph), Color(0.12, 0.07, 0.08, 0.98))
	draw_rect(Rect2(px, py, pw, ph), Color(0.9, 0.6, 0.35, 0.5), false, 2.0)

	var tx := px + 40.0
	var innerw := pw - 80.0
	draw_string(font, Vector2(tx, py + 48.0), "SHOP", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1.0, 0.86, 0.55))
	draw_string(font, Vector2(px + pw - 170.0, py + 44.0), "%d gold" % money, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1.0, 0.86, 0.45))

	var ry := py + 100.0
	var keynum := 1
	for kind in range(1, PROPS.size()):   # skip balls (index 0, always owned)
		draw_shop_row(font, tx, ry, innerw, kind, keynum)
		ry += 50.0
		keynum += 1
	draw_glasses_row(font, tx, ry, innerw, keynum)
	ry += 50.0
	draw_pie_row(font, tx, ry, innerw, keynum + 1)

	if shop_msg != "" and int(Time.get_ticks_msec()) - shop_msg_ms < 5000:
		draw_string(font, Vector2(tx, py + ph - 54.0), shop_msg, HORIZONTAL_ALIGNMENT_LEFT, innerw, 13, Color(1.0, 0.62, 0.45))
	draw_string(font, Vector2(tx, py + ph - 30.0), "press a number to buy one   -   to juggle N of a prop you must own N", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.75, 0.68, 0.6))
	draw_string(font, Vector2(px + pw - 150.0, py + ph - 30.0), "Tab / S to leave", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.8, 0.72, 0.6))


func draw_shop_row(font: Font, x: float, y: float, w: float, kind: int, keynum: int) -> void:
	draw_prop_icon(kind, Vector2(x + 16.0, y - 4.0))
	var nm := String(PROPS[kind]["name"])
	var wt := int(PROPS[kind]["weight"])
	var req := int(PROPS[kind]["req"])
	var cost := int(PROPS[kind]["cost"])
	draw_string(font, Vector2(x + 48.0, y), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1.0, 0.88, 0.6))
	var sub := "weight %d   throws clean at Strength %d" % [wt, req]
	if req == 0:
		sub = "weight %d   easy to throw" % wt
	if kind == PROP_EGGS:
		sub += "   (breaks on drop)"
	draw_string(font, Vector2(x + 48.0, y + 16.0), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.75, 0.68, 0.6))
	# how many you own, then a per-unit price and the buy key (buy as many as you like)
	var hc := Color(0.72, 0.88, 0.72) if available(kind) else Color(0.72, 0.66, 0.58)
	draw_string(font, Vector2(x + w - 262.0, y), "own %d" % prop_count[kind], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, hc)
	var afford := money >= cost
	var cc := Color(0.75, 0.95, 0.75) if afford else Color(0.9, 0.5, 0.45)
	draw_string(font, Vector2(x + w - 168.0, y), "%d g" % cost, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, cc)
	draw_string(font, Vector2(x + w - 48.0, y), "[%d]" % keynum, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, cc)


func draw_glasses_row(font: Font, x: float, y: float, w: float, keynum: int) -> void:
	var gc := Color(0.72, 0.86, 0.96)
	draw_arc(Vector2(x + 8.0, y - 5.0), 6.0, 0.0, TAU, 16, gc, 2.0, true)   # spectacles
	draw_arc(Vector2(x + 22.0, y - 5.0), 6.0, 0.0, TAU, 16, gc, 2.0, true)
	draw_line(Vector2(x + 14.0, y - 5.0), Vector2(x + 16.0, y - 5.0), gc, 2.0)
	draw_string(font, Vector2(x + 44.0, y), "Glasses", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1.0, 0.88, 0.6))
	draw_string(font, Vector2(x + 44.0, y + 16.0), "sharper sight: a better chance on off-Perfect catches", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.75, 0.68, 0.6))
	if has_glasses:
		draw_string(font, Vector2(x + w - 130.0, y), "OWNED", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.6, 0.9, 0.6))
	else:
		var afford := money >= GLASSES_COST
		var cc := Color(0.75, 0.95, 0.75) if afford else Color(0.9, 0.5, 0.45)
		draw_string(font, Vector2(x + w - 160.0, y), "%d g" % GLASSES_COST, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, cc)
		draw_string(font, Vector2(x + w - 44.0, y), "[%d]" % keynum, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, cc)


func draw_pie_row(font: Font, x: float, y: float, w: float, keynum: int) -> void:
	# Uncle Dan's Pie: a warm slice with a steam curl for an icon
	var pc := Color(0.9, 0.62, 0.3)
	draw_colored_polygon(PackedVector2Array([
		Vector2(x + 4.0, y + 2.0), Vector2(x + 28.0, y + 2.0), Vector2(x + 16.0, y - 14.0)]), pc)
	draw_line(Vector2(x + 4.0, y + 2.0), Vector2(x + 28.0, y + 2.0), Color(0.6, 0.36, 0.16), 3.0)
	draw_string(font, Vector2(x + 44.0, y), "Uncle Dan's Pie", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1.0, 0.88, 0.6))
	draw_string(font, Vector2(x + 44.0, y + 16.0), "eat in the day hub: the whole day runs slow and clear, until you sleep", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.75, 0.68, 0.6))
	draw_string(font, Vector2(x + w - 262.0, y), "own %d" % pie_count, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.72, 0.88, 0.72) if pie_count > 0 else Color(0.72, 0.66, 0.58))
	var afford := money >= PIE_COST
	var cc := Color(0.75, 0.95, 0.75) if afford else Color(0.9, 0.5, 0.45)
	draw_string(font, Vector2(x + w - 168.0, y), "%d g" % PIE_COST, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, cc)
	draw_string(font, Vector2(x + w - 48.0, y), "[%d]" % keynum, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, cc)


func _skills_row(font: Font, x: float, y: float, w: float, ename: String, lvl: int, unlocked: bool, sel: bool) -> void:
	# one entry in the Skills reference: name on the left, a ready / Lv-gate badge
	# on the right, and a soft highlight when it is the selected entry.
	if sel:
		draw_rect(Rect2(x - 12.0, y - 23.0, w, 38.0), Color(1.0, 0.85, 0.45, 0.10))
		draw_rect(Rect2(x - 12.0, y - 23.0, w, 38.0), Color(1.0, 0.85, 0.45, 0.35), false, 1.0)
	var nc := Color(1.0, 0.9, 0.6) if sel else (Color(0.86, 0.8, 0.68) if unlocked else Color(0.55, 0.5, 0.46))
	draw_string(font, Vector2(x, y), ename, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, nc)
	if unlocked:
		draw_string(font, Vector2(x + w - 76.0, y), "ready", HORIZONTAL_ALIGNMENT_RIGHT, 64.0, 12, Color(0.6, 0.9, 0.62))
	else:
		draw_string(font, Vector2(x + w - 76.0, y), "Lv %d" % lvl, HORIZONTAL_ALIGNMENT_RIGHT, 64.0, 12, Color(0.72, 0.62, 0.5))


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
		_skills_row(font, col_l, y0 + float(i) * row_h, colw, String(td["name"]), int(td["lvl"]), trick_unlocked(i), i == skills_sel)
	for j in PATTERNS.size():
		var pd: Dictionary = PATTERNS[j]
		_skills_row(font, col_r, y0 + float(j) * row_h, colw, String(pd["name"]), int(pd["lvl"]), pattern_unlocked(j), (nt + j) == skills_sel)

	# the detail strip: the selected entry explained, with its exact controls
	var dy := py + ph - 118.0
	draw_rect(Rect2(px + 30.0, dy - 6.0, pw - 60.0, 80.0), Color(0.08, 0.05, 0.06, 0.7))
	draw_rect(Rect2(px + 30.0, dy - 6.0, pw - 60.0, 80.0), Color(0.9, 0.6, 0.35, 0.28), false, 1.0)
	var ename := ""
	var how := ""
	var desc := ""
	var locked_at := 0
	var is_unlocked := true
	if skills_sel < nt:
		var td2: Dictionary = TRICKS[skills_sel]
		ename = String(td2["name"])
		desc = String(td2["desc"])
		locked_at = int(td2["lvl"])
		is_unlocked = trick_unlocked(skills_sel)
		match String(td2["kind"]):
			"live":
				how = "%s loads it, then %s spins while %d or more are airborne. Catches score double while you spin blind." % [kc_sel, kc_use, int(td2["min_air"])]
			"toggle":
				how = "%s loads it, then %s switches it on, %s again switches it off. It reshapes every throw between." % [kc_sel, kc_use, kc_use]
			_:
				how = "%s loads it, then %s powers your NEXT throw. One press, one trick." % [kc_sel, kc_use]
	else:
		var pd2: Dictionary = PATTERNS[skills_sel - nt]
		ename = String(pd2["name"])
		desc = String(pd2["desc"])
		locked_at = int(pd2["lvl"])
		is_unlocked = pattern_unlocked(skills_sel - nt)
		how = "In practice, press P to switch patterns. Score multiplier x%.2f at your CURRENT load (x%.2f base - more balls and heavier props push it higher still). Cascade and Fountain also match the ball count." % [float(pd2["mult"]) * object_mult(), float(pd2["mult"])]
	draw_string(font, Vector2(px + 46.0, dy + 18.0), ename.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color(1.0, 0.88, 0.55) if is_unlocked else Color(0.72, 0.62, 0.55))
	if not is_unlocked:
		draw_string(font, Vector2(px + pw - 230.0, dy + 18.0), "unlocks at level %d" % locked_at, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.85, 0.62, 0.5))
	draw_string(font, Vector2(px + 46.0, dy + 42.0), how, HORIZONTAL_ALIGNMENT_LEFT, pw - 92.0, 13, Color(0.9, 0.82, 0.66))
	draw_string(font, Vector2(px + 46.0, dy + 62.0), desc, HORIZONTAL_ALIGNMENT_LEFT, pw - 92.0, 13, Color(0.78, 0.72, 0.64))

	var foot := "arrows browse      Enter  practise this skill      Esc to leave"
	if not is_unlocked:
		foot = "arrows browse      Esc to leave      (this one is still locked)"
	draw_string(font, Vector2(px, py + ph - 22.0), foot, HORIZONTAL_ALIGNMENT_CENTER, pw, 13, Color(0.74, 0.68, 0.6))


# -----------------------------------------------------------------------------
# Menu, save-slot, settings, and cutscene screens.
# -----------------------------------------------------------------------------

func draw_day(font: Font, s: Vector2) -> void:
	# the day hub: the chosen venue's exterior breathes behind a veil while the
	# day's ledger and actions sit over it. The world is where you will play
	# tonight, which makes choosing a stage feel like standing in front of it.
	ext_center = true    # the stage's picture is the hub's centrepiece
	draw_venue_exterior(s, play_venue())
	ext_center = false
	# the hub darkens as the day's segments burn: DAY is open, NIGHT draws in,
	# DEEP NIGHT is nearly black and plainly the moment to sleep
	var seg_dark: float = [0.0, 0.16, 0.32, 0.32][clampi(seg_used, 0, 3)]
	if seg_dark > 0.0:
		draw_rect(Rect2(0, 0, s.x, s.y), Color(0.01, 0.01, 0.04, seg_dark))
	draw_rect(Rect2(0, 0, s.x, s.y), Color(0.03, 0.02, 0.03, 0.52))
	draw_vignette(s, 0.55)
	draw_frame(s, 22.0, Color(0.82, 0.62, 0.34, 0.5))

	# header: which day it is and how much of it is left, as three little diamonds
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
	draw_string(font, Vector2(lx + 42.0, ly + 37.0), "%d gold" % money, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1.0, 0.86, 0.45))
	draw_string(font, Vector2(lx + 20.0, ly + 64.0), "Rep %d   %s" % [reputation, rep_tier()], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.82, 0.72, 0.85))
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
			hud_panel(Rect2(ax - 14.0, ry - 21.0, aw, 40.0))
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
		"shop":
			# the awning rolls down over the counter and the shop is open
			var c := Vector2(s.x * 0.5, s.y * 0.5)
			hud_panel(Rect2(c.x - 190.0, c.y - 100.0, 380.0, 190.0))
			var drop := 64.0 * minf(t * 1.6, 1.0)
			for st in 7:
				var sx0 := c.x - 168.0 + float(st) * 48.0
				var scol := Color(0.75, 0.2, 0.18) if st % 2 == 0 else Color(0.92, 0.88, 0.8)
				draw_rect(Rect2(sx0, c.y - 86.0, 48.0, drop), scol)
			draw_rect(Rect2(c.x - 176.0, c.y - 86.0 + drop, 352.0, 5.0), Color(0.5, 0.3, 0.16))
			draw_rect(Rect2(c.x - 150.0, c.y + 26.0, 300.0, 34.0), Color(0.42, 0.26, 0.14))
			draw_string(font, Vector2(c.x - 190.0, c.y + 78.0), "the shop opens", HORIZONTAL_ALIGNMENT_CENTER, 380.0, 16, Color(1.0, 0.9, 0.65, ease_in))


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

	draw_title_glow(font, s.y * 0.32, "JUGGLE", 92, Color(1.0, 0.88, 0.5), s)
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

	var rows := [["Music", set_music], ["Sound effects", set_sfx], ["Screen shake", set_shake], ["Throw flags (TOO LOW / high)", set_flags], ["Hard collisions  (clacks ruin catches)", set_collide], ["Fullscreen  (F11 anywhere)", set_fullscreen]]
	var pw := 560.0
	var px := s.x * 0.5 - pw * 0.5
	var oy := s.y * 0.28
	for i in rows.size():
		var sel := i == menu_sel
		var ry := oy + float(i) * 48.0
		var nm := String(rows[i][0])
		var on := bool(rows[i][1])
		draw_string(font, Vector2(px, ry), ("> " if sel else "  ") + nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1.0, 0.9, 0.6) if sel else Color(0.8, 0.74, 0.66))
		draw_string(font, Vector2(px + pw - 60.0, ry), "ON" if on else "OFF", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.6, 0.9, 0.6) if on else Color(0.85, 0.6, 0.55))

	var csel := menu_sel == rows.size()
	var cry := oy + float(rows.size()) * 48.0
	draw_string(font, Vector2(px, cry), ("> " if csel else "  ") + "Controls  (rebind the keys)", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1.0, 0.9, 0.6) if csel else Color(0.8, 0.74, 0.66))
	var rsel := menu_sel == rows.size() + 1
	var rry := cry + 48.0
	draw_string(font, Vector2(px, rry), ("> " if rsel else "  ") + "Records and history", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1.0, 0.9, 0.6) if rsel else Color(0.8, 0.74, 0.66))
	var bsel := menu_sel == rows.size() + 2
	draw_string(font, Vector2(0, rry + 48.0 + 28.0), ("Back" if not bsel else ">   Back   <"), HORIZONTAL_ALIGNMENT_CENTER, s.x, 24, Color(1.0, 0.9, 0.55) if bsel else Color(0.72, 0.66, 0.6))
	var tfoot := "Up / Down    A to toggle    B to go back" if pad_active() else "Up / Down    Enter to toggle    Esc to go back"
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
	for i in 6:
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
	for i in lines.size():
		var ry := ly + 34.0 + float(i) * 30.0
		draw_string(font, Vector2(rx, ry), String(lines[i][0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.85, 0.78, 0.66))
		draw_string(font, Vector2(rx + 280.0, ry), String(lines[i][1]), HORIZONTAL_ALIGNMENT_RIGHT, 140.0, 15, Color(1.0, 0.9, 0.65))

	draw_string(font, Vector2(0, s.y - 42.0), "Esc back", HORIZONTAL_ALIGNMENT_CENTER, s.x, 15, Color(0.7, 0.66, 0.6))
	draw_vignette(s, 0.5)
	draw_frame(s, 22.0, Color(0.82, 0.62, 0.34, 0.5))


# =============================================================================
# Procedural audio (ART_AND_MUSIC.md, code-only rule). Every sound is synthesised
# in code into an AudioStreamWAV at startup, then just played, so there is no
# per-frame synthesis cost. Music is "adaptive" by volume-automating three
# looping layers (a static pad drone, a bass that enters when you juggle, and an
# arpeggio that swells with Applause) plus a crowd murmur bed.
# =============================================================================

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
	if not set_sfx or not _audio_ready or not sfx.has(name):
		return
	var p: AudioStreamPlayer = sfx_pool[_sfx_next]
	_sfx_next = (_sfx_next + 1) % sfx_pool.size()
	p.stream = sfx[name]
	p.volume_db = vol_db
	p.pitch_scale = clampf(pitch, 0.3, 3.0)
	p.play()


func _catch_sound(kind: int) -> String:
	match kind:
		PROP_EGGS: return "c_egg"
		PROP_RINGS: return "c_ring"
		PROP_CLUBS: return "c_club"
		PROP_KNIVES: return "c_knife"
		PROP_TORCHES: return "c_torch"
		_: return "c_ball"


func audio_update() -> void:
	# runs every frame in every state: glide the track's volume to fit the moment.
	# Louis's song IS the soundtrack, so the game never changes the material, only
	# how much room it takes: fullest while a performance is cooking, easy in the
	# menus and the day hub, a hush under cutscene captions, a dip when a prop
	# hits the floor (via _duck).
	if not _audio_ready:
		return
	var in_play := game_state == ST_PLAY
	var perf := in_play and mode == MODE_PERFORM and not tut_active
	# JUGGLING = a live run on the stage (performance, practice, or a lesson). The main
	# track rides only here; everywhere else the Chill Trio mix carries it (Louis). They
	# crossfade, so stepping onto the stage lifts the drive and stepping off eases back.
	var juggling := in_play and running and not results_open
	var energy := clampf(applause * 0.65 + clampf(float(streak) / 8.0, 0.0, 1.0) * 0.55, 0.0, 1.0)
	var main_t := -80.0
	var chill_t := -80.0
	if juggling:
		main_t = lerpf(-13.0, -9.0, energy) if perf else -14.0
	else:
		chill_t = -13.0
	if not set_music:
		main_t = -80.0
		chill_t = -80.0
	_vol["mus"] = lerpf(_vol["mus"], main_t - _duck * 9.0, 0.06)
	mus.volume_db = _vol["mus"]
	_vol["mus2"] = lerpf(_vol["mus2"], chill_t, 0.05)
	mus2.volume_db = _vol["mus2"]
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
	sfx["streak"] = _wav(_seq_bells([784.0, 987.8, 1318.5], 0.08, 0.5), false)
	sfx["ui"] = _wav(_tone([880.0], [1.0], 0.05, 0, 0.001, 0.02, 0.3, 0.0), false)
	sfx["ui2"] = _wav(_tone([1174.7, 1568.0], [1.0, 0.5], 0.10, 0, 0.001, 0.05, 0.35, 0.0), false)
	sfx["gasp"] = _wav(_gasp_sound(), false)
	sfx["groan"] = _wav(_groan_sound(), false)
	sfx["c_ball"] = _wav(_tone([420.0], [1.0], 0.10, 0, 0.001, 0.035, 0.5, 0.15), false)
	sfx["c_egg"] = _wav(_tone([520.0], [1.0], 0.09, 0, 0.001, 0.03, 0.45, 0.2), false)
	sfx["c_ring"] = _wav(_tone([300.0, 452.0], [1.0, 0.5], 0.34, 0, 0.004, 0.22, 0.4, 0.0), false)
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

func venue_blurb(i: int) -> String:
	# one line on the crowd you are about to face, so each stage reads distinct
	match i:
		0: return "a quiet yard  -  a forgiving place to find your hands"
		1: return "a street corner  -  passers-by you keep only by playing clean"
		2: return "a ticketed house  -  quiet, paying, and quietly exacting"
		3: return "the big top  -  loud, vast, and hungry for spectacle"
		4: return "a scored floor  -  judged on precision, never on flash"
		_: return "the summit  -  no help left but your own two hands"


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
	# STAGE n of 6, then the name in lights, then the crowd blurb
	draw_string(font, Vector2(0, s.y * 0.12), "STAGE  %d  of  %d" % [establish_venue + 1, TOP_VENUE + 1], HORIZONTAL_ALIGNMENT_CENTER, s.x, 17, Color(0.9, 0.78, 0.55, 0.85 * tagA))
	var vn := String(venue_data(establish_venue)["name"]).to_upper()
	draw_title_glow(font, s.y * 0.14 + 12.0, vn, 56, Color(1.0, 0.9, 0.55), s)
	draw_ornament(s.x * 0.5, s.y * 0.14 + 78.0, 190.0, Color(0.82, 0.62, 0.34, 0.85))
	draw_string(font, Vector2(0, s.y * 0.14 + 104.0), venue_blurb(establish_venue), HORIZONTAL_ALIGNMENT_CENTER, s.x, 15, Color(0.86, 0.78, 0.66, 0.8 * tagA))

	# the record to beat here (its own board on a purist night), plus a purist tag
	var recy := s.y * 0.14 + 140.0
	if purist:
		draw_string(font, Vector2(0, recy), "PURIST BOOKING  -  no stat help, its own record board", HORIZONTAL_ALIGNMENT_CENTER, s.x, 14, Color(0.82, 0.72, 0.85, 0.85 * tagA))
		recy += 24.0
	if establish_venue >= 0 and establish_venue < rec_table().size() and rec_table()[establish_venue] > 0:
		draw_string(font, Vector2(0, recy), "record to beat   %s" % commafy(rec_table()[establish_venue]), HORIZONTAL_ALIGNMENT_CENTER, s.x, 18, Color(0.96, 0.83, 0.52, 0.85 * tagA))
	else:
		draw_string(font, Vector2(0, recy), "no record here yet  -  set one", HORIZONTAL_ALIGNMENT_CENTER, s.x, 16, Color(0.9, 0.82, 0.6, 0.7 * tagA))

	# THE BOOKING (Phase 2): which of the three sets you are about to walk into, the number
	# you must beat, and - from the very first card - the Encore condition waiting at the end,
	# so a player knows what the night wants of them before they choose to walk out.
	if booking_active:
		var by2 := recy + 46.0
		var setnames := ["THE WARM-UP", "THE SET", "THE ENCORE"]
		var target := set_target_for(establish_venue, set_index)
		draw_string(font, Vector2(0, by2), "%s  of  %d    -    target  %s" % [setnames[clampi(set_index, 0, 2)], SETS_PER_BOOKING, commafy(target)],
			HORIZONTAL_ALIGNMENT_CENTER, s.x, 20, Color(1.0, 0.88, 0.5, 0.9 * tagA))
		if encore >= 0 and encore < ENCORES.size():
			var enc: Dictionary = ENCORES[encore]
			var pw := clampf(s.x * 0.5, 460.0, 720.0)
			var pxx := s.x * 0.5 - pw * 0.5
			var eyy := by2 + 24.0
			var hot := set_index == SET_ENCORE   # the condition is live THIS set
			var ec := Color(1.0, 0.55, 0.4) if hot else Color(0.85, 0.7, 0.55)
			draw_rect(Rect2(pxx, eyy, pw, 52.0), Color(0.12, 0.06, 0.07, 0.55 * tagA))
			draw_rect(Rect2(pxx, eyy, pw, 52.0), Color(ec.r, ec.g, ec.b, 0.5 * tagA), false, 1.5)
			var etag := "TONIGHT'S ENCORE" if not hot else "THE ENCORE  -  NOW"
			draw_string(font, Vector2(pxx, eyy + 20.0), "%s:  %s" % [etag, String(enc["name"]).to_upper()], HORIZONTAL_ALIGNMENT_CENTER, pw, 15, Color(ec.r, ec.g, ec.b, 0.9 * tagA))
			draw_string(font, Vector2(pxx + 16.0, eyy + 40.0), String(enc["desc"]), HORIZONTAL_ALIGNMENT_CENTER, pw - 32.0, 12, Color(0.9, 0.82, 0.72, 0.8 * tagA))

	var py := s.y - 70.0
	draw_gradient_v(Rect2(0, py - 30.0, s.x, s.y - py + 30.0), Color(0.02, 0.01, 0.02, 0.0), Color(0.02, 0.01, 0.02, 0.9), 16)
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
	cur += 40.0;  rows.append({"y": cur, "kind": "title", "a": "JUGGLE", "b": ""})
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
				draw_title_glow(font, ry - 49.0, atxt, 76, Color(gold.r, gold.g, gold.b, a), s)
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
	# JUGGLE card, which waits, unmoving, for any key. The scrolling text is above it
	# by then, so the two never overlap.
	var last_sy := base + last_y - scroll
	if last_sy < s.y * 0.30:
		var fa := clampf((s.y * 0.30 - last_sy) / 140.0, 0.0, 1.0)
		var fy := s.y * 0.42
		draw_title_glow(font, fy - 55.0, "JUGGLE", 84, Color(1.0, 0.9, 0.55, fa), s)
		draw_ornament(cx, fy + 44.0, 175.0, Color(0.82, 0.62, 0.34, 0.85 * fa))
		draw_string(font, Vector2(0, fy + 86.0), "press any key", HORIZONTAL_ALIGNMENT_CENTER, s.x, 15, Color(0.82, 0.72, 0.6, 0.65 * fa))

	draw_vignette(s, 0.55)
	draw_frame(s, 22.0, Color(0.82, 0.62, 0.34, 0.5))


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
		var sc := prop_scale(int(d["kind"])) * 0.95
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


func draw_stat_row(font: Font, x: float, y: float, w: float, name: String, value: int, note: String, keyhint: String) -> void:
	draw_string(font, Vector2(x, y), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(1.0, 0.88, 0.6))
	var barx := x + 130.0
	var barw := w - 260.0
	draw_rect(Rect2(barx, y - 13.0, barw, 12.0), Color(0.2, 0.14, 0.11, 0.8))
	draw_rect(Rect2(barx, y - 13.0, barw * clampf(float(value) / 100.0, 0.0, 1.0), 12.0), Color(0.85, 0.65, 0.35))
	draw_string(font, Vector2(x + w - 120.0, y), "%d" % value, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 0.9, 0.7))
	draw_string(font, Vector2(x, y + 16.0), note, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.75, 0.68, 0.6))
	if (points > 0 or debug_mode) and keyhint != "":
		draw_string(font, Vector2(x + w - 60.0, y), "[%s]+" % keyhint, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.7, 0.95, 0.7))


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


func _demo_step() -> void:
	# in a --booking demo the autoplayer walks off the moment a target is cleared, banking
	# with whatever overtime it built, so a whole booking advances cleanly and never hangs
	# at a venue whose crowd a low routine can sustain forever (v0/v1)
	if booking_active and set_cleared and running:
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
		tennis_ball = null
		if _demo_trick_pin == TR_COLS:
			col_air_ref = -1.0
			col_mid_ball = null
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
