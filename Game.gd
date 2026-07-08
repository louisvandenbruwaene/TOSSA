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
const ACC_CATCH_BONUS := 0.50     # added to the chance at full Accuracy
const MIN_CATCH_P := 0.06         # a wild ball is never quite hopeless

# --- throw height as a TIER (ideas.rtf heights 1..5) --------------------------
# A tap throws the STANDARD height (tier 3), the one catch timing is built around.
# Holding lifts it toward 5 (a risky reset); being too weak for the prop drags it
# DOWN toward 1. Both directions away from 3 are harder to catch, so a wrong-height
# throw is a mistake, which is exactly what makes height control matter.
const TIER_STD := 3.0      # the standard, catchable throw (a plain tap)
const TIER_MIN := 1.0
const TIER_MAX := 5.0
const HOLD_MAX := 44       # holding THROW this long reaches the top of the range
const AIR_BASE := 40.0     # airtime = AIR_BASE + AIR_PER_TIER * tier
const AIR_PER_TIER := 27.0 # tier3 ~= 121 ticks (1s), tier1 ~= 67, tier5 ~= 175
const ARC_PER_AIR := 1.7   # arc peak (px) per airtime tick

# how hard a wrong height is to catch, per tier of deviation from the standard
const DEV_UP_PENALTY := 0.28    # too HIGH (tier>3): hard, but Accuracy can recover it
const DEV_DN_PENALTY := 0.55    # too LOW (tier<3, a weak sagging throw): brutal
const DEV_PERFECT_SHRINK := 1.6 # Perfect window loses this many ticks per tier off
const DEV_INACC := 0.6          # extra landing drift/wobble per tier off standard

# --- inaccuracy scale (the risk half of the risk/reward) ----------------------
const DRIFT_MAX := 26.0   # px lateral landing drift at a full tier of deviation
const JITTER_MAX := 5     # ticks of arrival uncertainty
const WOBBLE_MAX := 11.0  # px of in-flight arc wobble

# --- progression / stats meta (GDD Section 4; skill-first guardrails hold) -----
const SAVE_PATH := "user://juggle_save.cfg"
const SAVE_PATH_DEBUG := "user://juggle_debug.cfg"  # debug build: separate progress
const POINTS_PER_LEVEL := 3
const ACC_MIN_FACTOR := 0.35  # inaccuracy floor at Accuracy 100: never zero, so a
                              # max-height throw always still demands a real catch
const STR_HOLD_EFF := 0.015   # per Strength point: more height per tick of hold,
                              # so a strong juggler reaches a big throw in less time
const STAM_DRAIN_CATCH := 0.4
const STAM_DRAIN_THROW := 0.3
const STAM_LOW := 0.25        # below this fraction of max, fatigue lowers Accuracy
const STAM_MIN_MULT := 0.5    # Accuracy multiplier at empty stamina (GDD 4.7)

# --- reputation: the career-climb currency (GDD 4.4). Scales PAY, never score
# or catching, so it stays on the comfort axis and never touches the skill floor.
const REP_PAY_DIV := 400.0    # pay multiplier = 1 + reputation / REP_PAY_DIV
const REP_SWING := 60         # reputation gained by a great set, lost by a poor one
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
const WEIGHT_INACC := 0.12   # each weight step over balls adds this much inaccuracy
const WEIGHT_STAM := 0.25    # each weight step adds this fraction of stamina cost

# --- shop: spend gold on props and gear (ideas.rtf shop) ----------------------
const GLASSES_COST := 5000
const GLASSES_CATCH_BONUS := 0.20  # ideas.rtf: glasses raise the catch chance

# input map (physical keycodes; a real remap layer comes with the options menu)
const K_LC := KEY_D
const K_LT := KEY_F
const K_RC := KEY_K
const K_RT := KEY_J
const K_TRICK := KEY_SPACE

# hand animation
const HAND_SMOOTH := 0.22  # per-tick lerp of hand toward its target position


class Ball:
	var state := STATE_FLIGHT
	var to_hand := LEFT
	var from_pos := Vector2.ZERO
	var to_pos := Vector2.ZERO
	var launch_tick := 0
	var land_tick := 0
	var arc := 120.0
	var wobble := 0.0
	var tier := TIER_STD      # throw height tier 1..5; 3 is standard, off-3 is harder to catch
	var color := Color.WHITE
	var kind := 0             # which prop (index into PROPS); sets look and weight
	var spin_dir := 1.0       # tumble direction for spinning props (clubs/knives/torches)


var tick := 0
var pattern := CASCADE
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
var trick_hint := -999
var rng := RandomNumberGenerator.new()

# progression / stats (persisted to SAVE_PATH)
var accuracy := 5         # lands throws closer; low Accuracy forces Perfect catches
var strength := 6         # quicker high throws; gates ball count and hard tricks
var endurance := 6        # raises max Stamina; gates heavy props later
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
var stamina := 56.0       # within-run resource; low stamina lowers Accuracy
var stamina_max := 56.0   # 50 + Endurance
var run_xp := 0           # xp earned in the current run, for the results screen
var last_pay := 0         # gold earned from the last finished performance
var round_scored := false
var sheet_open := false
var shop_open := false
var debug_mode := false   # debug build: free stat editing in the character sheet
var _prev_running := false

# previous-frame button states, for edge detection
var _prev := {"lc": false, "lt": false, "rc": false, "rt": false, "trick": false}

# dev-only: headless auto-player + one-frame screenshot
var _demo := false
var _shot := false
var _shot_path := ""
var _shot_tick := 170
var _shot_frames := 0
var _demo_next := RIGHT
const DEMO_BEAT := 28


func _ready() -> void:
	# Dev-only flags. Normal play passes NONE of these: the game then simply waits
	# for the player's first THROW and never auto-plays or auto-quits.
	#   --demo         run the headless auto-player (for verifying choreography)
	#   --shot <path>  capture one frame to <path> then quit
	var ua := OS.get_cmdline_user_args()
	if ua.has("--demo"):
		_demo = true
	if ua.has("--debug"):   # debug build: free stat editing (uses a separate save)
		debug_mode = true
	var si := ua.find("--shot")
	if si != -1 and si + 1 < ua.size():
		_shot = true
		_shot_path = ua[si + 1]
	load_progress()
	start_run(3)
	if ua.has("--demo"):    # dev: the auto-player performs, so we can see Applause
		mode = MODE_PERFORM
	if ua.has("--sheet"):   # dev: open the character sheet for a screenshot
		points = maxi(points, 6)
		sheet_open = true
	if ua.has("--shop"):    # dev: open the shop for a screenshot
		shop_open = true


func _physics_process(_delta: float) -> void:
	if _shot:
		_shot_frames += 1   # advances even while paused, so we can capture the sheet
		if _shot_frames >= _shot_tick:
			_capture_and_quit()
			return
	if sheet_open or shop_open:
		queue_redraw()   # the sheet and shop pause the sim; nothing advances
		return
	tick += 1
	if _demo:
		_demo_step()
	else:
		_read_inputs()
	if running:
		update_sim()
	if _prev_running and not running:
		on_round_end()   # the run just ended: bank the completion XP
	_prev_running = running
	update_hands()
	age_popups()
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var kc: int = event.physical_keycode
	if sheet_open:
		match kc:
			KEY_TAB, KEY_ESCAPE:
				sheet_open = false
			KEY_1:
				_sheet_invest("acc")
			KEY_2:
				_sheet_invest("str")
			KEY_3:
				_sheet_invest("end")
			KEY_Q:
				if debug_mode: _adjust("acc", -1)
			KEY_W:
				if debug_mode: _adjust("str", -1)
			KEY_E:
				if debug_mode: _adjust("end", -1)
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
		return
	if shop_open:
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
		return
	match kc:
		KEY_TAB:
			sheet_open = true
		KEY_S:
			shop_open = true
		KEY_P:
			toggle_mode()
		KEY_R:
			start_run(num_balls)
		KEY_BRACKETLEFT:
			start_run(num_balls - 1)
		KEY_BRACKETRIGHT:
			start_run(num_balls + 1)
		KEY_3:
			start_run(3)
		KEY_4:
			start_run(4)
		KEY_5:
			start_run(5)
		KEY_6:
			start_run(6)
		KEY_7:
			start_run(7)
		KEY_O:
			cycle_prop(1)   # cycle to the next owned prop
		KEY_ESCAPE:
			get_tree().quit()


func toggle_mode() -> void:
	mode = MODE_PERFORM if mode == MODE_TRAIN else MODE_TRAIN
	start_run(num_balls)   # restart cleanly in the new mode


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


func try_buy(kind: int) -> void:
	# buy one more of a prop; you can stock as many as you can afford
	var cost := int(PROPS[kind]["cost"])
	if money >= cost:
		money -= cost
		prop_count[kind] += 1
		save_progress()


func try_buy_glasses() -> void:
	if has_glasses or money < GLASSES_COST:
		return
	money -= GLASSES_COST
	has_glasses = true
	save_progress()


# -----------------------------------------------------------------------------
# Input: edge-detected presses for the four hand actions plus trick.
# -----------------------------------------------------------------------------

func _read_inputs() -> void:
	_edge("lc", Input.is_physical_key_pressed(K_LC), LEFT, true)
	_edge("lt", Input.is_physical_key_pressed(K_LT), LEFT, false)
	_edge("rc", Input.is_physical_key_pressed(K_RC), RIGHT, true)
	_edge("rt", Input.is_physical_key_pressed(K_RT), RIGHT, false)
	var tk := Input.is_physical_key_pressed(K_TRICK)
	if tk and not bool(_prev["trick"]):
		on_trick()
	_prev["trick"] = tk


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


# -----------------------------------------------------------------------------
# Geometry: OUTER catch point and INNER throw point per hand. Rising balls leave
# the inside, falling balls arrive on the outside, so their lanes never overlap.
# -----------------------------------------------------------------------------

func stack(h: int) -> Array[Ball]:
	return _stack_l if h == LEFT else _stack_r


func other(h: int) -> int:
	return RIGHT if h == LEFT else LEFT


func stage_center() -> Vector2:
	var s := get_viewport_rect().size
	return Vector2(s.x * 0.5, s.y * 0.66)


func outer_pos(h: int) -> Vector2:
	var c := stage_center()
	var dx := 152.0
	return Vector2(c.x - dx, c.y) if h == LEFT else Vector2(c.x + dx, c.y)


func inner_pos(h: int) -> Vector2:
	# just outside the torso silhouette, so a carried ball never sits on the body
	var c := stage_center()
	var dx := 72.0
	return Vector2(c.x - dx, c.y) if h == LEFT else Vector2(c.x + dx, c.y)


func shoulder_pos(h: int) -> Vector2:
	var s := get_viewport_rect().size
	var c := s.x * 0.5
	var dx := 44.0
	return Vector2(c - dx, s.y * 0.50) if h == LEFT else Vector2(c + dx, s.y * 0.50)


# where hand h wants to be right now: inner while carrying (to throw), else outer
func hand_target(h: int) -> Vector2:
	var holding := not stack(h).is_empty()
	var p := inner_pos(h) if holding else outer_pos(h)
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
	# Strength unlocks more balls, gradually (no big jumps). 3 and 4 from the start.
	var m := 4
	if strength >= 12:
		m = 5
	if strength >= 20:
		m = 6
	if strength >= 30:
		m = 7
	return m


func next_ball_strength() -> int:
	# Strength needed for the next ball unlock, or 0 if already at the cap
	if strength < 12:
		return 12
	if strength < 20:
		return 20
	if strength < 30:
		return 30
	return 0


func start_run(n: int) -> void:
	if not available(prop_type):
		prop_type = PROP_BALLS   # not enough of that prop owned: fall back to balls
	# you cannot juggle more of a prop than you own (balls are unlimited)
	var cap := mini(max_balls(), have(prop_type))
	num_balls = clampi(n, MIN_BALLS, maxi(MIN_BALLS, cap))
	pattern = CASCADE if num_balls % 2 == 1 else FOUNTAIN
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
	running = false
	started = false
	stamina_max = 50.0 + float(endurance)
	stamina = stamina_max          # each run starts rested
	run_xp = 0
	last_pay = 0
	round_scored = false
	_prev_running = false
	rng.seed = 20260705
	hpos = [outer_pos(LEFT), outer_pos(RIGHT)]
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
	if not stack(h).is_empty():
		return  # hand occupied; you physically cannot catch (this IS the traffic rule)
	var best: Ball = null
	var best_d := 1000000
	for b in balls:
		if b.state == STATE_FLIGHT and b.to_hand == h:
			var d := absi(b.land_tick - tick)
			if d < best_d:
				best = b
				best_d = d
	if best == null or best_d > COMMIT:
		# reached for empty air: a whiff. Discourage mashing with a small wobble.
		applause = maxf(0.0, applause - 0.04)
		catch_flash[h] = tick
		hclose[h] = 0.0
		add_popup(outer_pos(h), "whiff", Color(0.7, 0.66, 0.6, 1.0))
		return
	if best_d > W_LATE:
		# way off the arrival: a genuine mistime, the ball drops
		drop_ball(best, "MISTIME")
		return
	# Perfect timing always secures. A Good or Late catch is a chance that rises
	# with Accuracy and falls with how far off the standard height the throw was.
	# The Perfect window itself shrinks for off-standard throws (Focus widens it),
	# so a wrong-height throw is hard to catch cleanly and easy to lose.
	var wperf := maxi(2, perfect_window() - int(round(absf(best.tier - TIER_STD) * DEV_PERFECT_SHRINK)))
	if best_d > wperf:
		var quality := 1 if best_d <= W_GOOD else 2
		if rng.randf() > catch_chance(quality, best.tier):
			drop_ball(best, "slip")
			return
	# secured
	best.state = STATE_HAND
	stack(h).append(best)
	catch_flash[h] = tick
	caught += 1
	stamina = maxf(0.0, stamina - STAM_DRAIN_CATCH * energy_mult() * (1.0 + WEIGHT_STAM * float(prop_weight(best.kind) - 1)))
	if best_d <= wperf:
		streak += 1
		best_streak = maxi(best_streak, streak)
		score += 100 * streak
		applause = minf(1.0, applause + 0.05)
		add_xp(3)
		add_popup(outer_pos(h), "PERFECT", Color(1.0, 0.86, 0.42))
	elif best_d <= W_GOOD:
		streak += 1
		best_streak = maxi(best_streak, streak)
		score += 50 * streak
		applause = minf(1.0, applause + 0.025)
		add_xp(2)
		add_popup(outer_pos(h), "GOOD", Color(0.78, 0.92, 0.6))
	else:
		streak = 0
		score += 10
		applause = maxf(0.0, applause - 0.02)
		add_xp(1)
		add_popup(outer_pos(h), "late", Color(0.95, 0.62, 0.4))


# -----------------------------------------------------------------------------
# Throw: charge on THROW down-edge, launch on release. Longer hold = higher and
# less accurate. Height buys airtime (thins traffic) at the cost of a harder catch.
# -----------------------------------------------------------------------------

func on_throw_press(h: int) -> void:
	if stack(h).is_empty():
		return
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
	if stack(h).is_empty():
		return
	var b: Ball = stack(h).pop_front()
	var weight := prop_weight()
	var deficit := prop_deficit()   # >0 when too weak for this prop
	# A tap is the standard tier 3; holding lifts toward tier 5, and Strength lets you
	# reach the top of the range with less hold. Being too weak for the prop drags the
	# ACTUAL height down toward tier 1 (the ideas.rtf sagging-throw rule).
	var hold_frac := clampf(float(hold) / float(HOLD_MAX), 0.0, 1.0)
	var reach := clampf(hold_frac * (1.0 + float(strength) * STR_HOLD_EFF), 0.0, 1.0)
	var intended := TIER_STD + (TIER_MAX - TIER_STD) * reach
	var tier := clampf(lerpf(intended, TIER_MIN, deficit), TIER_MIN, TIER_MAX)
	var dev := absf(tier - TIER_STD)   # 0 standard .. 2 worst, in either direction
	b.tier = tier

	# any deviation from the standard, plus a heavy prop, widens the inaccuracy
	var inacc := inacc_factor() * (0.35 + DEV_INACC * dev) * (1.0 + WEIGHT_INACC * float(weight - 1))
	var jitter := int(round(rng.randf_range(-1.0, 1.0) * float(JITTER_MAX) * inacc))
	var drift := rng.randf_range(-1.0, 1.0) * DRIFT_MAX * inacc
	var air := int(round(AIR_BASE + AIR_PER_TIER * tier))   # higher tier = more airtime

	b.state = STATE_FLIGHT
	b.launch_tick = tick
	b.land_tick = tick + air + jitter
	b.arc = ARC_PER_AIR * float(air)
	b.wobble = WOBBLE_MAX * dev * inacc_factor()
	stamina = maxf(0.0, stamina - STAM_DRAIN_THROW * energy_mult() * (1.0 + WEIGHT_STAM * float(weight - 1)))
	b.to_hand = other(h) if pattern == CASCADE else h
	b.from_pos = inner_pos(h)
	b.to_pos = outer_pos(b.to_hand) + Vector2(drift, 0.0)

	throw_kick[h] = tick
	charging[h] = false
	if not started:
		started = true
		running = true
	# a clean standard throw earns a little Applause; a wrong height does not, and a
	# clearly bad one flags itself high above the stage so the player learns to fix it
	applause = minf(1.0, applause + 0.012 * (1.0 - clampf(dev, 0.0, 1.0)))
	if dev >= 0.8:
		var lbl := "TOO LOW" if tier < TIER_STD else ("RESET" if tier > 4.3 else "too high")
		var lc := Color(1.0, 0.5, 0.4, 0.95) if tier < TIER_STD else Color(1.0, 0.82, 0.45, 0.9)
		add_popup(Vector2(outer_pos(b.to_hand).x, get_viewport_rect().size.y * 0.31), lbl, lc)


func on_trick() -> void:
	# Tricks are the next step. The input is wired now so the plumbing exists; with
	# zero slots equipped it simply acknowledges "nothing armed".
	trick_hint = tick


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
		save_progress()


func energy_mult() -> float:
	# performing costs more energy, and bigger routines cost more still;
	# training is lighter so you can practice without burning out. Focus (trained
	# Accuracy past 100) discounts every action's stamina cost (stage 1).
	var base := 0.5
	if mode == MODE_PERFORM:
		base = 1.0 + 0.15 * float(num_balls - MIN_BALLS)
	return base * focus_stam_mult()


func on_round_end() -> void:
	if round_scored:
		return
	round_scored = true
	var clean := 1.0
	if caught + dropped > 0:
		clean = float(caught) / float(caught + dropped)
	# harder routines (more balls) are worth more XP and pay more
	var diff := 1.0 + 0.25 * float(num_balls - MIN_BALLS)
	var bonus := int(round((float(best_streak) * 4.0 + float(caught) * 1.5) * clean * diff))
	add_xp(bonus)
	if mode == MODE_PERFORM:
		# reputation swings on the show's quality: clean play carries it, the
		# crowd's high point tops it up. A sloppy set drags it down.
		var quality := clampf(0.7 * clean + 0.3 * peak_applause, 0.0, 1.0)
		var rep_delta := int(round((quality - 0.5) * float(REP_SWING)))
		reputation = maxi(0, reputation + rep_delta)
		last_pay = int(round((float(caught) * 1.2 + float(best_streak) * 2.0) * clean * diff * pay_mult()))
		money += last_pay
		var s := get_viewport_rect().size
		add_popup(Vector2(s.x * 0.5, s.y * 0.30), "+%d gold" % last_pay, Color(1.0, 0.86, 0.4))
		var rc := Color(0.7, 0.95, 0.7) if rep_delta >= 0 else Color(1.0, 0.55, 0.45)
		add_popup(Vector2(s.x * 0.5, s.y * 0.345), "%s%d rep" % ["+" if rep_delta >= 0 else "", rep_delta], rc)
	save_progress()


func stamina_mult() -> float:
	# full effect until Stamina drops under STAM_LOW, then ramps down to STAM_MIN_MULT
	var f := stamina / maxf(1.0, stamina_max)
	if f >= STAM_LOW:
		return 1.0
	return lerpf(STAM_MIN_MULT, 1.0, clampf(f / STAM_LOW, 0.0, 1.0))


func eff_accuracy() -> float:
	return clampf(float(accuracy) * stamina_mult(), 0.0, 100.0)


func inacc_factor() -> float:
	# 1.0 of the base inaccuracy at Accuracy 0, ACC_MIN_FACTOR at Accuracy 100.
	# Never reaches zero, so a max-height throw always still needs a real catch.
	return lerpf(1.0, ACC_MIN_FACTOR, eff_accuracy() / 100.0)


func catch_chance(quality: int, tier: float) -> float:
	# probability that an off-Perfect catch (quality 1 = Good, 2 = Late) secures.
	# Rises with Accuracy and falls hard the further the throw is from the standard
	# height (tier 3), with a low sagging throw punished more than a high one.
	# Perfect timing is handled separately in on_catch.
	var acc_norm := clampf(eff_accuracy() / ACC_FULL, 0.0, 1.0)
	var base := GOOD_BASE if quality == 1 else LATE_BASE
	var dev_up := maxf(0.0, tier - TIER_STD)
	var dev_dn := maxf(0.0, TIER_STD - tier)
	var p := base + acc_norm * ACC_CATCH_BONUS - DEV_UP_PENALTY * dev_up - DEV_DN_PENALTY * dev_dn
	if has_glasses:
		p += GLASSES_CATCH_BONUS   # bought gear lifts the odds of an off-Perfect catch
	return clampf(p, MIN_CATCH_P, 1.0)


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
	var extra := focus() - 100.0
	var bonus := 0
	if extra > 0.0:
		bonus = mini(FOCUS_WINDOW_MAX, int(extra / FOCUS_WINDOW_PER))
	return mini(W_GOOD, W_PERFECT + bonus)


func pay_mult() -> float:
	# Reputation lifts earnings only. Score and catching are untouched (GDD 4.1).
	return 1.0 + float(reputation) / REP_PAY_DIV


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


func venue_index() -> int:
	# the stage you play grows as Reputation climbs (the STORY.md venue ladder)
	if reputation >= 3000:
		return 5
	if reputation >= 1500:
		return 4
	if reputation >= 700:
		return 3
	if reputation >= 300:
		return 2
	if reputation >= 100:
		return 1
	return 0


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
	match which:
		"acc":
			accuracy = mini(ACC_CAP, accuracy + 1)   # past 100 becomes Focus
		"str":
			strength = mini(100, strength + 1)
		"end":
			endurance = mini(100, endurance + 1)
			stamina_max = 50.0 + float(endurance)
	points -= 1
	save_progress()


func _sheet_invest(which: String) -> void:
	if debug_mode:
		_adjust(which, 1)   # debug build: free, no point cost
	else:
		invest(which)


func _adjust(which: String, delta: int) -> void:
	match which:
		"acc":
			accuracy = clampi(accuracy + delta, 1, ACC_CAP)
		"str":
			strength = clampi(strength + delta, 1, 100)
		"end":
			endurance = clampi(endurance + delta, 1, 100)
			stamina_max = 50.0 + float(endurance)
			stamina = minf(stamina, stamina_max)
	save_progress()


func save_file() -> String:
	return SAVE_PATH_DEBUG if debug_mode else SAVE_PATH


func load_progress() -> void:
	var cf := ConfigFile.new()
	if cf.load(save_file()) == OK:
		accuracy = int(cf.get_value("stats", "accuracy", 5))
		strength = int(cf.get_value("stats", "strength", 6))
		endurance = int(cf.get_value("stats", "endurance", 6))
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
	stamina_max = 50.0 + float(endurance)
	stamina = stamina_max


func save_progress() -> void:
	var cf := ConfigFile.new()
	cf.set_value("stats", "accuracy", accuracy)
	cf.set_value("stats", "strength", strength)
	cf.set_value("stats", "endurance", endurance)
	cf.set_value("stats", "money", money)
	cf.set_value("stats", "reputation", reputation)
	cf.set_value("stats", "prop_count", prop_count)
	cf.set_value("stats", "prop_type", prop_type)
	cf.set_value("stats", "glasses", has_glasses)
	cf.set_value("prog", "level", level)
	cf.set_value("prog", "xp", xp)
	cf.set_value("prog", "points", points)
	cf.save(save_file())


# -----------------------------------------------------------------------------
# Per-tick simulation and hand animation.
# -----------------------------------------------------------------------------

func drop_ball(b: Ball, why: String) -> void:
	if not balls.has(b):
		return
	balls.erase(b)
	dropped += 1
	streak = 0
	last_drop_tick = tick
	applause = maxf(0.0, applause - 0.26)
	var dtext := why
	if b.kind == PROP_EGGS:
		# a dropped egg breaks for good, so it leaves your stock (ideas.rtf)
		prop_count[PROP_EGGS] = maxi(0, prop_count[PROP_EGGS] - 1)
		save_progress()
		dtext = "SPLAT"
	add_popup(b.to_pos + Vector2(0, -6), dtext, Color(1.0, 0.32, 0.3))
	# only a performance ends when the crowd is lost; training just plays on
	if mode == MODE_PERFORM and applause <= 0.0:
		running = false


func update_sim() -> void:
	var lost: Array[Ball] = []
	for b in balls:
		if b.state == STATE_FLIGHT and tick > b.land_tick + MISS_GRACE:
			lost.append(b)
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


func add_popup(pos: Vector2, text: String, col: Color) -> void:
	popups.append({"pos": pos + Vector2(0, -40), "text": text, "col": col, "born": tick})


func age_popups() -> void:
	var keep: Array[Dictionary] = []
	for p in popups:
		if tick - int(p["born"]) <= 46:
			keep.append(p)
	popups = keep


func flight_pos(b: Ball) -> Vector2:
	var span := maxi(1, b.land_tick - b.launch_tick)
	var p := clampf(float(tick - b.launch_tick) / float(span), 0.0, 1.0)
	var pos := b.from_pos.lerp(b.to_pos, p)
	pos.y -= 4.0 * b.arc * p * (1.0 - p)                 # parabolic arc
	pos.x += b.wobble * sin(p * PI) * sin(p * 9.0)       # high-throw arc wobble
	return pos


# -----------------------------------------------------------------------------
# Rendering: warm-theatrical, code-only. A stylized performer with procedurally
# posed arms and open/closing hands, so the no-crossing choreography is visible.
# Draw order keeps balls above the figure and the HUD clear of the stage.
# -----------------------------------------------------------------------------

func _draw() -> void:
	var s := get_viewport_rect().size
	var font := ThemeDB.fallback_font
	draw_backdrop(s)
	draw_juggler(s)
	draw_targets()
	draw_balls_in_flight()
	draw_hud(font, s)
	draw_popups(font)
	if sheet_open:
		draw_sheet(font, s)
	if shop_open:
		draw_shop(font, s)


func draw_backdrop(s: Vector2) -> void:
	var vi := venue_index()
	var v := venue_data(vi)
	var glow: Color = v["glow"]
	var floor_c: Color = v["floor"]
	var spot: float = v["spot"]

	# spotlight cone from above centre
	var top := Vector2(s.x * 0.5, -40.0)
	var spread := 300.0
	var cone := PackedVector2Array([
		top,
		Vector2(s.x * 0.5 - spread, s.y * 0.82),
		Vector2(s.x * 0.5 + spread, s.y * 0.82),
	])
	draw_colored_polygon(cone, Color(glow.r, glow.g, glow.b, spot))
	for i in range(6, 0, -1):
		var r := 90.0 + float(i) * 66.0
		var a := 0.05 * (1.0 - float(i) / 7.0)
		draw_circle(Vector2(s.x * 0.5, s.y * 0.5), r, Color(glow.r, glow.g, glow.b, a))

	# stage floor
	var fy := s.y * 0.80
	draw_rect(Rect2(0, fy, s.x, s.y - fy), floor_c)
	draw_line(Vector2(0, fy), Vector2(s.x, fy), Color(glow.r, glow.g, glow.b, 0.55), 3.0)

	# crowd: a row of dim heads seated in front, more of them at grander venues, and
	# brighter while the crowd is pleased. Suggestion, not detail (ART_AND_MUSIC.md).
	var heads := 10 + vi * 7
	var lit := 0.07
	if mode == MODE_PERFORM:
		lit = 0.08 + 0.13 * applause
	for i in heads:
		var hx := s.x * (float(i) + 0.5) / float(heads)
		var hy := fy + 14.0 + fmod(float(i) * 1.7, 5.0)
		var hr := 6.0 + fmod(float(i) * 2.3, 3.0)
		draw_circle(Vector2(hx, hy), hr, Color(glow.r, glow.g, glow.b, lit))


func draw_juggler(s: Vector2) -> void:
	var cx := s.x * 0.5
	var v := venue_data(venue_index())
	var skin := Color(0.87, 0.64, 0.45)
	var hair := Color(0.28, 0.16, 0.11)
	var suit: Color = v["suit"]         # costume changes with the venue
	var suit_dk: Color = v["suit_dk"]
	var vest: Color = v["vest"]
	var collar: Color = v["collar"]
	var button := Color(0.34, 0.20, 0.11)

	var head_r := 27.0
	var head := Vector2(cx, s.y * 0.415)
	var head_bottom := head.y + head_r
	var shoulder_y := s.y * 0.50
	var hip_y := s.y * 0.685
	var floor_y := s.y * 0.80

	# legs: trousers (tapered quads) with a small pelvis join, then shoes
	var shoe := Color(0.20, 0.12, 0.09)
	draw_colored_polygon(PackedVector2Array([   # pelvis
		Vector2(cx - 30, hip_y - 10), Vector2(cx + 30, hip_y - 10),
		Vector2(cx + 28, hip_y + 8), Vector2(cx - 28, hip_y + 8),
	]), suit_dk)
	draw_colored_polygon(PackedVector2Array([   # left leg
		Vector2(cx - 27, hip_y), Vector2(cx - 3, hip_y),
		Vector2(cx - 10, floor_y - 8), Vector2(cx - 25, floor_y - 8),
	]), suit_dk)
	draw_colored_polygon(PackedVector2Array([   # right leg
		Vector2(cx + 3, hip_y), Vector2(cx + 27, hip_y),
		Vector2(cx + 25, floor_y - 8), Vector2(cx + 10, floor_y - 8),
	]), suit_dk)
	fill_ellipse(Vector2(cx - 24, floor_y - 4), 18.0, 8.0, shoe)   # toe points out
	fill_ellipse(Vector2(cx + 24, floor_y - 4), 18.0, 8.0, shoe)

	# neck: a tapered polygon that closes the head-to-torso gap (no floating stub)
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - 11, head_bottom - 7), Vector2(cx + 11, head_bottom - 7),
		Vector2(cx + 15, shoulder_y + 6), Vector2(cx - 15, shoulder_y + 6),
	]), skin)

	# jacket with rounded shoulders (caps sit under where the arms attach)
	draw_circle(Vector2(cx - 44, shoulder_y), 16.0, suit)
	draw_circle(Vector2(cx + 44, shoulder_y), 16.0, suit)
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - 48, shoulder_y + 2), Vector2(cx + 48, shoulder_y + 2),
		Vector2(cx + 34, hip_y), Vector2(cx - 34, hip_y),
	]), suit)

	# cream collar V over the neck base
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - 21, shoulder_y - 3), Vector2(cx, shoulder_y + 24), Vector2(cx - 3, shoulder_y - 3),
	]), collar)
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx + 21, shoulder_y - 3), Vector2(cx, shoulder_y + 24), Vector2(cx + 3, shoulder_y - 3),
	]), collar)

	# gold waistcoat down the front, with buttons
	var vest_top := shoulder_y + 22.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - 15, vest_top), Vector2(cx + 15, vest_top),
		Vector2(cx + 21, hip_y - 4), Vector2(cx - 21, hip_y - 4),
	]), vest)
	for bi in 3:
		draw_circle(Vector2(cx, vest_top + 16.0 + float(bi) * 22.0), 2.6, button)

	# head: hair behind, skin face over it, warm rim light
	draw_circle(head + Vector2(0, -6), head_r + 1.0, hair)
	draw_circle(head, head_r, skin)
	draw_circle(head + Vector2(0, -2), head_r, Color(1.0, 0.82, 0.55, 0.10))
	draw_face(head)

	# arms follow the hands via a 2-bone solve, so the choreography animates
	draw_arm(shoulder_pos(LEFT), hpos[LEFT], LEFT, skin, suit)
	draw_arm(shoulder_pos(RIGHT), hpos[RIGHT], RIGHT, skin, suit)

	# hands (and any held balls) on top of the arms
	draw_hand(LEFT)
	draw_hand(RIGHT)


func fill_ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * float(i) / 20.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)


func draw_face(head: Vector2) -> void:
	var eye := Color(0.16, 0.10, 0.08)
	draw_circle(head + Vector2(-9, -1), 3.2, eye)
	draw_circle(head + Vector2(9, -1), 3.2, eye)
	draw_circle(head + Vector2(-8, -2), 1.1, Color(1, 1, 1, 0.7))
	draw_circle(head + Vector2(10, -2), 1.1, Color(1, 1, 1, 0.7))
	# expression: a smile on a streak, a wince just after a drop, else calm
	var mood := 0
	if tick - last_drop_tick < 45:
		mood = -1
	elif streak >= 3:
		mood = 1
	var my := head.y + 11.0
	var mouth := PackedVector2Array([Vector2(head.x - 7, my + 1), Vector2(head.x + 7, my + 1)])
	if mood == 1:
		mouth = PackedVector2Array([Vector2(head.x - 8, my - 2), Vector2(head.x, my + 4), Vector2(head.x + 8, my - 2)])
	elif mood == -1:
		mouth = PackedVector2Array([Vector2(head.x - 7, my + 3), Vector2(head.x, my - 2), Vector2(head.x + 7, my + 3)])
	draw_polyline(mouth, Color(0.45, 0.20, 0.16), 2.5)


func draw_arm(shoulder: Vector2, hand: Vector2, h: int, skin: Color, sleeve: Color) -> void:
	var bend := 1.0 if h == LEFT else -1.0            # elbows bow outward
	var elbow := solve_elbow(shoulder, hand, 78.0, 86.0, bend)
	draw_line(shoulder, elbow, sleeve, 14.0)          # upper arm (sleeved)
	draw_line(elbow, hand, skin, 11.0)                # forearm
	draw_circle(elbow, 6.5, sleeve)


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

	# palm
	draw_circle(pos, 12.0, Color(0.86, 0.62, 0.42))
	# fingers: spread and long when open (ready), curled short when closed
	var spread := lerpf(0.55, 0.12, close)
	var flen := lerpf(15.0, 8.0, close)
	var base_ang := -PI / 2.0                          # point up when open
	base_ang += close * inward * 0.7                   # curl inward when closed
	for f in 4:
		var off := (float(f) - 1.5) * spread
		var ang := base_ang + off
		var tip := pos + Vector2(cos(ang), sin(ang)) * flen
		draw_line(pos, tip, Color(0.84, 0.60, 0.40), 4.5)
	# thumb toward the inside
	var tang := -PI / 2.0 + inward * 1.1
	draw_line(pos, pos + Vector2(cos(tang), sin(tang)) * 11.0, Color(0.84, 0.60, 0.40), 5.0)

	# held ball(s) rest in the palm
	var st := stack(h)
	for i in st.size():
		draw_prop(st[i], pos + Vector2(0, -3 - float(i) * 6.0))


func draw_targets() -> void:
	# a landing ring brightens as a catch nears, so high-throw drift is readable
	for b in balls:
		if b.state == STATE_FLIGHT:
			var dd := b.land_tick - tick
			if dd >= -MISS_GRACE and dd < 46:
				var t := clampf(1.0 - float(maxi(dd, 0)) / 46.0, 0.0, 1.0)
				draw_arc(b.to_pos, 22.0 * prop_scale(b.kind), 0.0, TAU, 40,
					Color(1.0, 0.9, 0.5, 0.14 + 0.5 * t), 2.0 + 3.0 * t, true)


func draw_balls_in_flight() -> void:
	for b in balls:
		if b.state == STATE_FLIGHT:
			draw_prop(b, flight_pos(b))


func draw_prop(b: Ball, pos: Vector2) -> void:
	var sc := prop_scale(b.kind)
	# a soft halo reads the catch lane for every prop; the shape says which prop.
	var halo := b.color
	halo.a = 0.16
	draw_circle(pos, 20.0 * sc, halo)
	var ang := 0.0
	if bool(PROPS[b.kind]["spins"]) and b.state == STATE_FLIGHT:
		var span := maxi(1, b.land_tick - b.launch_tick)
		var p := clampf(float(tick - b.launch_tick) / float(span), 0.0, 1.0)
		ang = b.spin_dir * p * TAU * 2.0   # two tumbles across the flight
	match b.kind:
		PROP_EGGS:
			draw_egg(pos, b.color, sc)
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
	var sc := minf(prop_scale(kind), 1.3)
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


func draw_hud(font: Font, s: Vector2) -> void:
	var by := 40.0
	var performing := mode == MODE_PERFORM

	# mode label, top centre; Applause bar only when performing (not training)
	var mlabel := "PERFORMING" if performing else "TRAINING"
	if debug_mode:
		mlabel += "   -   DEBUG"
	var mcol := Color(1.0, 0.82, 0.4) if performing else Color(0.68, 0.74, 0.82)
	draw_string(font, Vector2(s.x * 0.5 - 200, 22), mlabel, HORIZONTAL_ALIGNMENT_CENTER, 400, 15, mcol)
	if performing:
		var bw := 300.0
		var bx := s.x * 0.5 - bw * 0.5
		draw_rect(Rect2(bx, by, bw, 15.0), Color(0.2, 0.14, 0.11, 0.7))
		var pcol := Color(0.9, 0.3, 0.2).lerp(Color(1.0, 0.85, 0.42), applause)
		draw_rect(Rect2(bx, by, bw * applause, 15.0), pcol)
		draw_string(font, Vector2(bx, by - 4.0), "APPLAUSE", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.9, 0.7, 0.8))

	# stamina bar, top right (turns red when fatigue starts biting Accuracy)
	var sw := 220.0
	var sx := s.x - 30.0 - sw
	var sfrac := clampf(stamina / maxf(1.0, stamina_max), 0.0, 1.0)
	draw_rect(Rect2(sx, by, sw, 15.0), Color(0.2, 0.14, 0.11, 0.7))
	var scol := Color(0.55, 0.80, 0.6)
	if sfrac < STAM_LOW:
		scol = scol.lerp(Color(0.95, 0.35, 0.25), clampf((STAM_LOW - sfrac) / STAM_LOW, 0.0, 1.0))
	draw_rect(Rect2(sx, by, sw * sfrac, 15.0), scol)
	draw_string(font, Vector2(sx, by - 4.0), "STAMINA  %d / %d" % [int(round(stamina)), int(stamina_max)], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.85, 0.9, 0.85, 0.8))
	draw_string(font, Vector2(sx, by + 30.0), "%d gold" % money, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1.0, 0.86, 0.45))
	draw_string(font, Vector2(sx, by + 50.0), "Rep %d  %s" % [reputation, rep_tier()], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.82, 0.72, 0.85))

	# score / streak / catches, top left
	draw_string(font, Vector2(30, 44), "SCORE  %d" % score, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1.0, 0.9, 0.7))
	draw_string(font, Vector2(30, 72), "STREAK %d   best %d" % [streak, best_streak], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.9, 0.8, 0.6))
	var acc := "-"
	if caught + dropped > 0:
		acc = "%d%%" % int(round(100.0 * float(caught) / float(caught + dropped)))
	draw_string(font, Vector2(30, 94), "CAUGHT %d  DROPPED %d  (%s)" % [caught, dropped, acc], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.8, 0.72, 0.58))

	# level + xp bar
	var need := xp_to_next(level)
	var xf := clampf(float(xp) / float(maxi(1, need)), 0.0, 1.0)
	draw_string(font, Vector2(30, 121), "LV %d" % level, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 0.85, 0.5))
	draw_rect(Rect2(72, 110, 180, 10), Color(0.2, 0.14, 0.11, 0.7))
	draw_rect(Rect2(72, 110, 180.0 * xf, 10), Color(0.9, 0.7, 0.35))
	draw_string(font, Vector2(262, 120), "%d / %d xp" % [xp, need], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.8, 0.72, 0.58))
	if points > 0:
		draw_string(font, Vector2(30, 143), "+%d stat point%s  -  press Tab" % [points, "" if points == 1 else "s"], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.7, 0.95, 0.7))

	if tick - trick_hint < 40:
		draw_string(font, Vector2(s.x * 0.5 - 90, s.y * 0.30), "no trick armed", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.8, 0.7, 0.9, 0.8))

	var patt := "CASCADE  (crossing)" if pattern == CASCADE else "FOUNTAIN  (columns)"
	var propname := String(cur_prop()["name"]).to_upper()
	var vname := String(venue_data(venue_index())["name"]).to_upper()
	if prop_deficit() > 0.0:
		draw_string(font, Vector2(30, s.y - 96), "TOO WEAK for %s  -  throws sag low and wild (needs Strength %d)" % [propname, prop_req()], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.0, 0.55, 0.4))
	draw_string(font, Vector2(30, s.y - 74), "%s  -  %d %s  -  %s" % [vname, num_balls, propname, patt], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1.0, 0.8, 0.5))
	var unlock := ""
	if next_ball_strength() > 0:
		unlock = "   ( next ball at Strength %d )" % next_ball_strength()
	draw_string(font, Vector2(30, s.y - 52), "[ ] count   O prop   S shop%s" % unlock, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.78, 0.7, 0.58, 0.85))
	draw_string(font, Vector2(30, s.y - 30),
		"catch D/K  throw F/J (hold=higher)  O prop  P perform/train  Tab sheet  R restart  Esc quit",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.82, 0.72, 0.6, 0.85))

	if not started:
		var verb := "perform" if performing else "practise"
		draw_string(font, Vector2(s.x * 0.5 - 220, s.y * 0.23),
			"press a THROW (F or J) to %s   -   P to %s instead" % [verb, "train" if performing else "perform"],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1.0, 0.86, 0.55))
	elif not running:
		draw_string(font, Vector2(s.x * 0.5 - 150, s.y * 0.20), "ROUND OVER", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(1.0, 0.5, 0.4))
		var tail := "   gold +%d" % last_pay if performing else ""
		draw_string(font, Vector2(s.x * 0.5 - 190, s.y * 0.20 + 40), "best streak %d   XP +%d%s   -   press R to go again" % [best_streak, run_xp, tail], HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color(0.9, 0.82, 0.7))


func draw_sheet(font: Font, s: Vector2) -> void:
	draw_rect(Rect2(0, 0, s.x, s.y), Color(0.04, 0.02, 0.03, 0.82))
	var pw := 580.0
	var ph := 388.0
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
	draw_rect(Rect2(tx, py + 62.0, innerw - 120.0, 10.0), Color(0.2, 0.14, 0.11, 0.8))
	draw_rect(Rect2(tx, py + 62.0, (innerw - 120.0) * xf, 10.0), Color(0.9, 0.7, 0.35))
	draw_string(font, Vector2(tx, py + 88.0), "%d / %d xp to next level" % [xp, need], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.8, 0.72, 0.58))

	var str_note := "faster high throws; %d balls now" % max_balls()
	if next_ball_strength() > 0:
		str_note = "faster high throws; %d-ball unlock at Str %d" % [max_balls() + 1, next_ball_strength()]
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
	# stamina is a resource, not an investable stat
	draw_string(font, Vector2(tx, ry), "STAMINA", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.8, 0.9, 0.85))
	draw_rect(Rect2(tx + 130.0, ry - 13.0, innerw - 260.0, 12.0), Color(0.2, 0.14, 0.11, 0.8))
	draw_rect(Rect2(tx + 130.0, ry - 13.0, (innerw - 260.0) * clampf(stamina / maxf(1.0, stamina_max), 0.0, 1.0), 12.0), Color(0.55, 0.80, 0.6))
	draw_string(font, Vector2(tx + innerw - 120.0, ry), "%d / %d" % [int(round(stamina)), int(stamina_max)], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.85, 0.9, 0.85))
	draw_string(font, Vector2(tx, ry + 16.0), "drains as you play; low stamina makes throws wild", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.75, 0.68, 0.6))

	var by := py + ph - 46.0
	if debug_mode:
		draw_string(font, Vector2(tx, by), "DEBUG  1/2/3 up  Q/W/E dn  M/N gold  ,/. rep", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.6, 0.9, 1.0))
	elif points > 0:
		draw_string(font, Vector2(tx, by), "%d point%s to spend  -  press 1 / 2 / 3" % [points, "" if points == 1 else "s"], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.7, 0.95, 0.7))
	else:
		draw_string(font, Vector2(tx, by), "Skill sets your score. Stats only ease the climb.", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.75, 0.7, 0.62))
	draw_string(font, Vector2(px + pw - 150.0, by), "Tab to resume", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.8, 0.72, 0.6))


func draw_shop(font: Font, s: Vector2) -> void:
	draw_rect(Rect2(0, 0, s.x, s.y), Color(0.04, 0.02, 0.03, 0.85))
	var pw := 640.0
	var ph := 452.0
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


func draw_popups(font: Font) -> void:
	for p in popups:
		var age := tick - int(p["born"])
		var a := clampf(1.0 - float(age) / 46.0, 0.0, 1.0)
		var pos: Vector2 = p["pos"] + Vector2(0, -float(age) * 0.6)
		var c: Color = p["col"]
		c.a = a
		draw_string(font, pos, p["text"], HORIZONTAL_ALIGNMENT_CENTER, 120, 18, c)


# -----------------------------------------------------------------------------
# Dev-only auto-player. Drives a scripted opening so headless runs and the
# --shot capture show real juggling (real arcs, real choreography) to verify.
# -----------------------------------------------------------------------------

func _demo_step() -> void:
	# auto-catch: secure any ball arriving at an empty hand
	for h in [LEFT, RIGHT]:
		if not stack(h).is_empty():
			continue
		for b in balls:
			if b.state == STATE_FLIGHT and b.to_hand == h and absi(b.land_tick - tick) <= 1:
				on_catch(h)
				break
	# metronome: every beat, release one ball from a hand that actually holds one.
	# This can never desync because it only throws real held balls.
	if tick >= 24 and tick % DEMO_BEAT == 0:
		var h := _demo_next
		if stack(h).is_empty():
			h = other(h)
		if not stack(h).is_empty():
			do_throw(h, 7)
			_demo_next = other(h)


func _capture_and_quit() -> void:
	var img := get_viewport().get_texture().get_image()
	if img != null and _shot_path != "":
		img.save_png(_shot_path)
	get_tree().quit()
