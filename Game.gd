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
const DEFICIT_HEIGHT := 0.5         # a full Strength deficit halves reachable height
const DEFICIT_INACC := 1.1          # a full Strength deficit roughly doubles inaccuracy

# --- inaccuracy scale (the risk half of the risk/reward) ----------------------
const DRIFT_MAX := 26.0   # px lateral landing drift at max height
const JITTER_MAX := 5     # ticks of arrival uncertainty at max height
const WOBBLE_MAX := 11.0  # px of in-flight arc wobble at max height

# --- game flow: the app boots to a menu, not straight into a run ---------------
const ST_MENU := 0        # title / main menu
const ST_SLOTS := 1       # pick a save file
const ST_SETTINGS := 2    # options
const ST_CUTSCENE := 3    # an illustrated story beat (now an animated mini-film)
const ST_PLAY := 4        # the juggling itself
const ST_ESTABLISH := 5   # an exterior "establishing shot" of the venue before a set
const NUM_SLOTS := 3

# --- progression / stats meta (GDD Section 4; skill-first guardrails hold) -----
const SAVE_PATH_DEBUG := "user://juggle_debug.cfg"  # debug build: separate progress
const SETTINGS_PATH := "user://juggle_settings.cfg" # global options, shared by slots
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

# --- tricks (GDD Section 3): flourishes performed with the TRICK key (Space). A
# trick is either ARMED onto the next throw (High Toss, Behind the Back) and paid
# off when you land its catch, or LIVE, acting on the balls already in the air
# (Spin). Each lands for a scoring and Applause bonus and each carries real risk,
# so a trick is a skill choice, never a free bonus. Tricks unlock by level, so the
# flourishes arrive as the meta deepens. C cycles which trick the key is primed to.
const TR_HIGH := 0
const TR_BTB := 1
const TR_SPIN := 2
const TRICKS := [
	{"id": "high", "name": "High Toss",        "kind": "arm",  "lvl": 2, "min_air": 0,
	 "desc": "Arm the next throw sky high. Land the catch for a burst of applause."},
	{"id": "btb",  "name": "Behind the Back",  "kind": "arm",  "lvl": 4, "min_air": 0,
	 "desc": "Arm a showy behind-the-back throw. Style the crowd loves, if you land it."},
	{"id": "spin", "name": "Spin",             "kind": "live", "lvl": 7, "min_air": 2,
	 "desc": "Spin while everything is airborne. Catches score double, you catch blind."},
]
const SPIN_TICKS := 44             # how long a Spin lasts (about a third of a second)
const TRICK_COOLDOWN := 96         # ticks before a LIVE trick can fire again
const HIGH_BONUS := 260            # score for landing a High Toss cleanly
const BTB_BONUS := 150             # score for landing a Behind the Back cleanly
const SPIN_CATCH_MULT := 2.0       # every catch during a Spin scores double
const SPIN_ACC_PENALTY := 0.28     # a Spin lowers the off-Perfect catch chance (juggling blind)


class Ball:
	var state := STATE_FLIGHT
	var to_hand := LEFT
	var from_pos := Vector2.ZERO
	var to_pos := Vector2.ZERO
	var launch_tick := 0
	var land_tick := 0
	var arc := 120.0
	var wobble := 0.0
	var height := 0.0         # normalized throw height 0..~1.4; higher lowers catch odds
	var color := Color.WHITE
	var kind := 0             # which prop (index into PROPS); sets look and weight
	var spin_dir := 1.0       # tumble direction for spinning props (clubs/knives/torches)
	var trick := -1           # which trick shaped this throw (TR_HIGH/TR_BTB), or -1 for a plain throw


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
var rng := RandomNumberGenerator.new()

# progression / stats (persisted per save slot, see save_file())
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
var last_rep_delta := 0   # reputation change from the last performance, for the results screen
var run_venue := 0        # which venue this run was performed at (records key off this)
var best_scores: Array[int] = [0, 0, 0, 0, 0, 0]  # best performance score per venue tier
var results_open := false # the end-of-performance results panel is showing
var results_record := false  # this performance beat the venue's record
var paused := false       # the in-play pause menu is up (freezes the sim)
var pause_sel := 0        # cursor in the pause menu
var round_scored := false
# --- tricks: which trick the TRICK key is primed to (cycled with C), a trick
# armed onto the next throw, the live-Spin timer, and the run's trick tally.
var trick_primed := 0     # index into TRICKS the TRICK key will fire
var trick_armed := -1     # a trick armed onto the next throw (TR_HIGH/TR_BTB), or -1
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
var debug_mode := false   # debug build: free stat editing in the character sheet
var _prev_running := false

# game-flow state
var game_state := ST_MENU
var menu_sel := 0         # cursor index in whichever menu is open
var save_slot := 0        # which save file is active
var venue_seen := 0       # highest venue reached, so promotions fire once
var story_seen := 0       # how many endgame story milestones have played (see STORY_REP)
var cutscene_queue: Array[String] = []  # pending story beats to show
var view_venue := -1      # cutscene/preview override of which venue palette to draw
var shake := 0.0          # screen-shake magnitude, decays each frame

# --- cinematic layer: animated cutscenes, establishing cards, tutorials -------
var cine_tick := 0        # cosmetic clock for cutscenes/establish/tutorial motion
var cs_shot := 0          # index of the shot within the current beat's script
var cs_shot_start := 0    # cine_tick at which the current shot began (for fades)
var cs_freeze := false    # dev: pin the current shot (for stable screenshots)
var establish_venue := 0  # which venue's exterior the establishing card shows
var establish_after := 3  # ball count to start the performance with once dismissed
var seen_tuts: Array[String] = []  # lesson ids already shown, so they fire once

# --- interactive tutorial (runs on the REAL sim, guided step by step) ---------
var tut_active := false   # a hands-on lesson is running inside ST_PLAY
var tut_id := ""          # "balls" (the 1->2->3 progression) or "prop_<n>"
var tut_step := 0         # index into tut_lesson(tut_id)
var tut_count := 0        # catches (or throws) banked in the current step
var tut_threw_l := false  # a left-hand throw happened this step
var tut_threw_r := false  # a right-hand throw happened this step
var tut_advance_at := -1  # tick to move on (a beat after the goal, so the throw lands)
var tut_flash := ""       # brief "Nice!" feedback between steps
# egg-break effect: shell shards (fly with gravity) and yolk splats (spread on floor)
var shards: Array[Dictionary] = []
var splats: Array[Dictionary] = []

# global settings (persisted to SETTINGS_PATH)
var set_shake := true     # screen shake on a drop
var set_hints := true     # show the control hints along the bottom
var set_flags := true     # show the TOO LOW / too high throw flags
var set_music := true     # the procedural adaptive soundtrack
var set_sfx := true       # catch/throw/drop sound effects and the crowd bed

# --- procedural audio (code-only, ART_AND_MUSIC.md): pre-rendered PCM buffers,
# adaptive music by volume-automating looping layers. See setup_audio().
const AUDIO_SR := 22050
var _audio_ready := false
var sfx: Dictionary = {}            # name -> AudioStreamWAV one-shot
var sfx_pool: Array = []            # AudioStreamPlayer round-robin for one-shots
var _sfx_next := 0
var mus_pad: AudioStreamPlayer      # looping music layers, volume-automated
var mus_bass: AudioStreamPlayer
var mus_arp: AudioStreamPlayer
var crowd_ply: AudioStreamPlayer    # looping crowd murmur, tracks Applause
var music_theme := -99              # venue index whose layers are loaded (-99 = none)
var _vol := {"pad": -80.0, "bass": -80.0, "arp": -80.0, "crowd": -80.0}
var _duck := 0.0                    # transient music dip on a drop, decays

# previous-frame button states, for edge detection
var _prev := {"lc": false, "lt": false, "rc": false, "rt": false, "trick": false}

# dev-only: headless auto-player + one-frame screenshot
var _demo := false
var _demo_trick := false  # dev: the auto-player also performs tricks, to screenshot them
var _eggdemo := false     # dev: repeatedly break an egg, to screenshot the effect
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
	var sa := ua.find("--shotat")   # dev: capture at frame N (to test late transitions)
	if sa != -1 and sa + 1 < ua.size():
		_shot_tick = int(ua[sa + 1])
	load_settings()
	setup_audio()                                # synthesise all sound at startup
	var da := ua.find("--dumpaudio")             # dev: write every sound to <dir>, then quit
	if da != -1 and da + 1 < ua.size():
		dump_audio(ua[da + 1])
		get_tree().quit()
		return
	hpos = [outer_pos(LEFT), outer_pos(RIGHT)]   # idle hands for the title screen

	# Dev/test flags jump straight into play; a normal launch opens the main menu.
	var skip_menu := _demo or _shot or debug_mode or ua.has("--sheet") or ua.has("--shop") or ua.has("--results") or ua.has("--pause")
	if ua.has("--menu"):
		skip_menu = false
	if skip_menu:
		save_slot = 0
		load_progress()
		start_run(3)
		game_state = ST_PLAY
		if ua.has("--demo"):    # dev: the auto-player performs, so we can see Applause
			mode = MODE_PERFORM
		if ua.has("--trick"):   # dev: unlock every trick and let the auto-player show them off
			_demo_trick = true
			level = 9
			var unl := unlocked_tricks()
			trick_primed = int(unl[0]) if not unl.is_empty() else 0
			if ua.has("--unlock"):   # dev: also show the new-trick banner
				trick_unlock = TR_SPIN
				trick_unlock_tick = 0
		if ua.has("--sheet"):   # dev: open the character sheet for a screenshot
			points = maxi(points, 6)
			sheet_open = true
		if ua.has("--shop"):    # dev: open the shop for a screenshot
			shop_open = true
		if ua.has("--results"):   # dev: fabricate a finished performance to screenshot the card
			mode = MODE_PERFORM
			run_venue = 2
			caught = 78; dropped = 4; best_streak = 33; score = 14820
			peak_applause = 0.94; tricks_landed = 5; trick_score = 1350
			last_pay = 240; last_rep_delta = 22; run_xp = 190; points = 3
			started = true; running = false; results_open = true; results_record = true
		if ua.has("--pause"):   # dev: open the pause menu for a screenshot
			open_pause()
	else:
		game_state = ST_MENU
	if ua.has("--settings"):    # dev: screenshot the settings screen
		game_state = ST_SETTINGS
	if ua.has("--slots"):       # dev: screenshot the save-slot screen
		game_state = ST_SLOTS
	var ci := ua.find("--cutscene")   # dev: screenshot a story beat, e.g. --cutscene v2
	if ci != -1:
		var id := ua[ci + 1] if ci + 1 < ua.size() and not ua[ci + 1].begins_with("--") else "intro"
		begin_cutscene([id])
	var ti := ua.find("--tutorial")   # dev: jump into a hands-on lesson, e.g. --tutorial balls
	if ti != -1:
		var id := ua[ti + 1] if ti + 1 < ua.size() and not ua[ti + 1].begins_with("--") else "balls"
		begin_tutorial(id)
	var ei := ua.find("--establish")  # dev: screenshot a venue exterior card, e.g. --establish 3
	if ei != -1:
		establish_venue = int(ua[ei + 1]) if ei + 1 < ua.size() else 2
		game_state = ST_ESTABLISH
		cine_tick = 0
	var ni := ua.find("--csn")        # dev: pin a specific shot index for a stable capture
	if ni != -1 and ni + 1 < ua.size():
		cs_shot = int(ua[ni + 1])
		cs_freeze = true
	if ua.has("--eggbreak"):          # dev: exercise the egg-break effect on the stage
		_eggdemo = true
		prop_type = PROP_EGGS
		game_state = ST_PLAY


func _physics_process(_delta: float) -> void:
	audio_update()   # pick the music theme and glide the layer volumes, every state
	if _shot:
		_shot_frames += 1   # advances even while paused, so we can capture the sheet
		if _shot_frames >= _shot_tick:
			_capture_and_quit()
			return
	if game_state != ST_PLAY:
		cine_tick += 1           # drives cutscene / establish / menu motion
		if game_state == ST_CUTSCENE:
			cutscene_autoadvance()   # shots play themselves, movie-like, until skipped
		queue_redraw()
		return
	if sheet_open or shop_open or paused:
		queue_redraw()   # the sheet, shop, and pause menu all halt the sim; nothing advances
		return
	tick += 1
	step_effects()   # age the egg-break shards and yolk splats
	if _eggdemo and tick % 42 == 0:
		var vp := get_viewport_rect().size
		spawn_egg_break(Vector2(vp.x * 0.5 + randf_range(-140, 140), vp.y * 0.42))
	if _demo:
		_demo_step()
	else:
		_read_inputs()
	if running:
		update_sim()
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
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var kc: int = event.physical_keycode
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
		ST_CUTSCENE:
			cutscene_key(kc)
			return
		ST_ESTABLISH:
			establish_key()
			return
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
	# the end-of-performance results panel: go again, spend/shop, or leave to the
	# menu. It stays open behind the sheet and shop, so you can invest then continue.
	if results_open and not sheet_open and not shop_open:
		match kc:
			KEY_R, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				results_open = false
				start_run(num_balls)
			KEY_TAB:
				sheet_open = true
			KEY_S:
				shop_open = true
			KEY_ESCAPE:
				results_open = false
				game_state = ST_MENU
		return
	# ST_PLAY: the existing in-game handling below
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
		KEY_C:
			cycle_trick()   # rotate which trick the TRICK key (Space) is primed to
		KEY_F1:
			if debug_mode: debug_jump_venue(0)   # debug story jump: F1..F6 = venues 1..6
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
			if debug_mode: debug_jump_story(0)   # F7..F9 = the endgame beats rival/record/finale
		KEY_F8:
			if debug_mode: debug_jump_story(1)
		KEY_F9:
			if debug_mode: debug_jump_story(2)
		KEY_ESCAPE:
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
		1:   # step back to the main menu (clearing any lesson or panels)
			paused = false
			tut_active = false
			results_open = false
			sheet_open = false
			shop_open = false
			game_state = ST_MENU
			menu_sel = 0
			play_sfx("ui", -12.0)
		2:   # leave the game
			get_tree().quit()


func toggle_mode() -> void:
	if mode == MODE_TRAIN:
		begin_performance(num_balls)   # show the venue exterior, then go on stage
	else:
		mode = MODE_TRAIN
		start_run(num_balls)           # dropping back to practice is instant


func begin_performance(n: int) -> void:
	# a performance opens on an establishing shot of WHERE you are about to play,
	# the way a film cuts to the outside of the building before the scene inside
	mode = MODE_PERFORM
	establish_after = n
	establish_venue = venue_index()
	game_state = ST_ESTABLISH
	cine_tick = 0


func establish_key() -> void:
	game_state = ST_PLAY
	start_run(establish_after)   # the card dismissed: walk out and begin the set


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
		var was := available(kind)
		money -= cost
		prop_count[kind] += 1
		save_progress()
		if not was and available(kind):
			offer_prop_tutorial(kind)   # first time you can juggle these: explain them


func offer_prop_tutorial(kind: int) -> void:
	# the first time a new prop becomes juggle-able, run its hands-on lesson once
	var id := "prop_%d" % kind
	if seen_tuts.has(id):
		return
	seen_tuts.append(id)
	shop_open = false            # clear the shop overlay for a clean lesson handoff
	begin_tutorial(id)


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
	# the core progression: one ball, then two, then the three-ball cascade
	return [
		{"prop": PROP_BALLS, "balls": 1, "hand": RIGHT, "goal": "throw_r", "need": 1,
			"text": "Throw the ball from your RIGHT hand", "sub": "Tap J. Just let it fall this time, no need to catch it yet."},
		{"prop": PROP_BALLS, "balls": 1, "hand": LEFT, "goal": "throw_l", "need": 1,
			"text": "Now throw from your LEFT hand", "sub": "Tap F, and let it fall again. Feel that each hand has its own throw."},
		{"prop": PROP_BALLS, "balls": 1, "hand": RIGHT, "goal": "catch", "need": 1,
			"text": "This time, catch it", "sub": "Throw with J, then catch it in your LEFT hand with D as it comes down."},
		{"prop": PROP_BALLS, "balls": 1, "hand": LEFT, "goal": "catch", "need": 1,
			"text": "And the other way", "sub": "Throw with F, then catch it in your RIGHT hand with K."},
		{"prop": PROP_BALLS, "balls": 1, "hand": RIGHT, "goal": "catch", "need": 4,
			"text": "Keep one ball going, back and forth", "sub": "Throw, catch, throw from that hand, catch. Land four in a row."},
		{"prop": PROP_BALLS, "balls": 2, "hand": RIGHT, "goal": "catch", "need": 4,
			"text": "Two balls now, one in each hand", "sub": "Throw the first, and as it peaks throw the second up under it. Land four catches."},
		{"prop": PROP_BALLS, "balls": 3, "hand": RIGHT, "goal": "catch", "need": 6,
			"text": "Three balls. The cascade", "sub": "Every time a ball falls, throw the one in the catching hand up first. Keep it weaving for six."},
	]


func begin_tutorial(id: String) -> void:
	tut_id = id
	tut_step = 0
	tut_active = true
	game_state = ST_PLAY
	started = true            # a lesson is its own thing, not the opening "first run"
	tut_setup_step()


func tut_setup_step() -> void:
	var steps := tut_lesson(tut_id)
	var step: Dictionary = steps[clampi(tut_step, 0, steps.size() - 1)]
	prop_type = int(step["prop"])
	num_balls = int(step["balls"])
	mode = MODE_TRAIN
	pattern = CASCADE if num_balls % 2 == 1 else FOUNTAIN
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
	stamina_max = 50.0 + float(endurance)
	stamina = stamina_max
	hpos = [outer_pos(LEFT), outer_pos(RIGHT)]
	hclose = [0.0, 0.0]
	catch_flash = [-999, -999]
	throw_kick = [-999, -999]
	rng.seed = 20260705
	# deal the balls; a single-ball step starts in the exact hand it is teaching
	var start_hand := int(step.get("hand", RIGHT))
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
	tut_count = 0
	tut_threw_l = false
	tut_threw_r = false
	tut_advance_at = -1


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
		for _i in (num_balls - balls.size()):
			var b := Ball.new()
			b.state = STATE_HAND
			b.kind = prop_type
			b.color = ball_color(balls.size()) if prop_type == PROP_BALLS else prop_color(prop_type)
			b.spin_dir = 1.0
			balls.append(b)
			if stack(RIGHT).size() <= stack(LEFT).size():
				_stack_r.append(b)
			else:
				_stack_l.append(b)


func tut_finish() -> void:
	var was_prop := tut_id.begins_with("prop_")
	tut_active = false
	tut_id = ""
	tut_flash = ""
	mode = MODE_TRAIN
	if not was_prop:
		prop_type = PROP_BALLS   # after the basics, drop back to plain balls
	var s := get_viewport_rect().size
	add_popup(Vector2(s.x * 0.5, s.y * 0.40), "lesson complete", Color(1.0, 0.86, 0.42))
	play_sfx("coin", -6.0)   # a bright flourish on finishing a lesson
	start_run(3)


func draw_tutorial_banner(font: Font, s: Vector2) -> void:
	var steps := tut_lesson(tut_id)
	var step: Dictionary = steps[clampi(tut_step, 0, steps.size() - 1)]
	var bw := s.x * 0.66
	var bx := s.x * 0.5 - bw * 0.5
	var by := 40.0
	draw_rect(Rect2(bx, by, bw, 92.0), Color(0.05, 0.03, 0.05, 0.86))
	draw_rect(Rect2(bx, by, bw, 92.0), Color(0.82, 0.62, 0.34, 0.55), false, 2.0)
	draw_string(font, Vector2(bx, by + 30.0), "LESSON  -  " + String(step["text"]), HORIZONTAL_ALIGNMENT_CENTER, bw, 23, Color(1.0, 0.9, 0.6))
	draw_string(font, Vector2(bx + 20.0, by + 55.0), String(step["sub"]), HORIZONTAL_ALIGNMENT_CENTER, bw - 40.0, 15, Color(0.9, 0.85, 0.78))
	var prog := "Step %d of %d" % [tut_step + 1, steps.size()]
	if String(step["goal"]).begins_with("catch") and int(step["need"]) > 1:
		prog += "        caught  %d / %d" % [mini(tut_count, int(step["need"])), int(step["need"])]
	draw_string(font, Vector2(bx, by + 80.0), prog, HORIZONTAL_ALIGNMENT_CENTER, bw, 14, Color(0.8, 0.75, 0.68))
	# a quiet controls reminder along the bottom (the normal HUD hints are hidden)
	draw_string(font, Vector2(0, s.y - 30.0), "D / K  catch      F / J  throw  (hold to go higher)      Esc  pause",
		HORIZONTAL_ALIGNMENT_CENTER, s.x, 14, Color(0.8, 0.72, 0.6, 0.8))
	if tut_flash != "":
		draw_string(font, Vector2(0, s.y * 0.32), tut_flash, HORIZONTAL_ALIGNMENT_CENTER, s.x, 30, Color(0.7, 0.95, 0.7))


func try_buy_glasses() -> void:
	if has_glasses or money < GLASSES_COST:
		return
	money -= GLASSES_COST
	has_glasses = true
	save_progress()


# -----------------------------------------------------------------------------
# Game flow: main menu, save slots, settings, cutscenes.
# -----------------------------------------------------------------------------

func menu_input(kc: int) -> void:
	var n := 3   # Play, Settings, Quit (lessons arrive on unlock, not from a menu)
	match kc:
		KEY_UP, KEY_W:
			menu_sel = (menu_sel + n - 1) % n
			play_sfx("ui", -14.0)
		KEY_DOWN, KEY_S:
			menu_sel = (menu_sel + 1) % n
			play_sfx("ui", -14.0)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			play_sfx("ui2", -11.0)
			match menu_sel:
				0:
					menu_sel = 0
					game_state = ST_SLOTS
				1:
					menu_sel = 0
					game_state = ST_SETTINGS
				2:
					get_tree().quit()
		KEY_ESCAPE:
			get_tree().quit()


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
	var n := 6   # music, sound, shake, hints, flags, Back
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
					set_hints = not set_hints
				4:
					set_flags = not set_flags
				5:
					menu_sel = 0
					game_state = ST_MENU
			play_sfx("ui2", -12.0)
			save_settings()
		KEY_ESCAPE:
			save_settings()
			menu_sel = 0
			game_state = ST_MENU


# --- cinematic beat engine (shared by story cutscenes and tutorials) ----------
# A "beat" (a story milestone, or one lesson) is a list of SHOTS. Each shot draws
# an animated tableau and holds for a while, then cuts to the next with a fade,
# so a beat plays like a short film. A key press skips forward. cine_tick drives
# all the motion; cs_shot / cs_shot_start track the cut and the fade.

func begin_cutscene(beats: Array) -> void:
	cutscene_queue.assign(beats)
	game_state = ST_CUTSCENE
	cine_tick = 0
	start_beat()


func cur_beat_id() -> String:
	return String(cutscene_queue[0]) if cutscene_queue.size() > 0 else ""


func cur_script() -> Array:
	return cutscene_script(cur_beat_id())


func start_beat() -> void:
	cs_shot = 0
	cs_shot_start = cine_tick


func cutscene_key(_kc: int) -> void:
	next_shot()   # any key cuts forward to the next shot


func cutscene_autoadvance() -> void:
	if cs_freeze:
		return
	var script := cur_script()
	if script.is_empty():
		finish_beats()
		return
	var shot: Dictionary = script[mini(cs_shot, script.size() - 1)]
	if cine_tick - cs_shot_start >= int(shot.get("hold", 300)):
		next_shot()


func next_shot() -> void:
	var script := cur_script()
	if cs_shot + 1 < script.size():
		cs_shot += 1
		cs_shot_start = cine_tick
		return
	if cutscene_queue.size() > 0:
		cutscene_queue.pop_front()
	if cutscene_queue.is_empty():
		finish_beats()
	else:
		start_beat()


func finish_beats() -> void:
	view_venue = -1
	game_state = ST_PLAY
	if not started:
		# a fresh game: after the opening story, teach the basics hands-on before the
		# first real run (one ball, then two, then the cascade)
		if not seen_tuts.has("balls"):
			seen_tuts.append("balls")
			begin_tutorial("balls")
		else:
			start_run(3)


func start_slot(i: int) -> void:
	save_slot = i
	var fresh := not FileAccess.file_exists(slot_path(i))
	if fresh:
		reset_new_game()
		begin_cutscene(["intro"])
	else:
		load_progress()
		game_state = ST_PLAY
		start_run(3)


func reset_new_game() -> void:
	# a brand new juggler, so a fresh slot never inherits the previous one's stats
	accuracy = 5
	strength = 6
	endurance = 6
	money = START_GOLD
	reputation = 0
	prop_count = [0, 0, 0, 0, 0, 0]
	prop_type = PROP_BALLS
	has_glasses = false
	level = 1
	xp = 0
	points = 0
	venue_seen = 0
	story_seen = 0
	best_scores = [0, 0, 0, 0, 0, 0]
	started = false
	stamina_max = 50.0 + float(endurance)
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
	return "Level %d   -   %s   -   %d gold" % [lv, vn, g]


func delete_slot(i: int) -> void:
	var dir := DirAccess.open("user://")
	var fn := "juggle_slot%d.cfg" % i
	if dir != null and dir.file_exists(fn):
		dir.remove(fn)


func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) == OK:
		set_shake = bool(cf.get_value("opt", "shake", true))
		set_hints = bool(cf.get_value("opt", "hints", true))
		set_flags = bool(cf.get_value("opt", "flags", true))
		set_music = bool(cf.get_value("opt", "music", true))
		set_sfx = bool(cf.get_value("opt", "sfx", true))


func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("opt", "shake", set_shake)
	cf.set_value("opt", "hints", set_hints)
	cf.set_value("opt", "flags", set_flags)
	cf.set_value("opt", "music", set_music)
	cf.set_value("opt", "sfx", set_sfx)
	cf.save(SETTINGS_PATH)


func cutscene_script(id: String) -> Array:
	# Each story beat is a short film: a list of animated SHOTS. "scene" picks the
	# tableau, "stage" the moment inside it, "who" names a speaker (gold), "cap" is
	# the line, "hold" is how long it plays before it auto-cuts. Prose stays warm
	# and spare (STORY.md), and free of dashes and semicolons.
	match id:
		"intro":
			return [
				{"scene": "backyard", "stage": 0, "who": "", "hold": 340,
					"cap": "A backyard at dusk. An old street juggler named Bruna presses three worn balls into your hands and steps back."},
				{"scene": "backyard", "stage": 1, "who": "Bruna", "hold": 360,
					"cap": "\"Three balls. Two hands. Everything else in this trade is just noise on top of that.\""},
				{"scene": "backyard", "stage": 2, "who": "Bruna", "hold": 380,
					"cap": "\"Gear gets you to the door. The crowd is the thing you earn once you are inside. Now throw.\""},
				{"scene": "backyard", "stage": 3, "who": "", "hold": 360,
					"cap": "So it begins, with nothing to your name but a pair of quick hands and something to prove."},
			]
		"v1":
			return [
				{"scene": "street", "stage": 0, "who": "", "hold": 340,
					"cap": "A cold corner and a warm lamp. A hat on the cobbles. The city does not slow down for anyone who has not earned it."},
				{"scene": "street", "stage": 1, "who": "", "hold": 340,
					"cap": "You find the pulse of it. One stranger slows to watch. Then another stops beside them."},
				{"scene": "street", "stage": 2, "who": "", "hold": 380,
					"cap": "The first coin rings in the hat. It only ever comes when the hands are clean, and never a moment before."},
			]
		"v2":
			return [
				{"scene": "theatre", "stage": 0, "who": "", "hold": 340,
					"cap": "Indoors now, and ticketed. Your name is printed on the bill, close to the bottom."},
				{"scene": "theatre", "stage": 1, "who": "Silvio", "hold": 400,
					"cap": "\"Real hands, kid. Genuine talent. A pity real hands are so slow to pay the rent.\""},
				{"scene": "theatre", "stage": 2, "who": "", "hold": 380,
					"cap": "Silvio Grand headlines above you, gracious in the way that stings. You watch from the wings, and you learn."},
			]
		"v3":
			return [
				{"scene": "circus", "stage": 0, "who": "", "hold": 340,
					"cap": "A travelling troupe pitches its tent at the edge of town and waves you inside."},
				{"scene": "circus", "stage": 1, "who": "", "hold": 380,
					"cap": "Lantern light and sawdust and a found family. Here the spectacle is real, and so is the fall."},
				{"scene": "circus", "stage": 2, "who": "", "hold": 380,
					"cap": "They teach you the weight of a blade and the cost of dropping one. You decide not to drop one."},
			]
		"v4":
			return [
				{"scene": "champ", "stage": 0, "who": "", "hold": 340,
					"cap": "No hat this time. A scoreboard. The best in the country, measured down to the single catch."},
				{"scene": "champ", "stage": 1, "who": "Silvio", "hold": 400,
					"cap": "\"Second place. Close, though. Buy yourself better torches and maybe next year is yours.\""},
				{"scene": "champ", "stage": 2, "who": "", "hold": 420,
					"cap": "He wins on paper with the priciest gear money can buy. You place second on a cleaner run. The gap is narrowing, and it is narrowing from your side."},
			]
		"rival":
			return [
				{"scene": "champ", "stage": 0, "who": "", "hold": 340,
					"cap": "The international stage. The finest hands alive, and the first room no amount of money can buy your way through."},
				{"scene": "champ", "stage": 3, "who": "", "hold": 400,
					"cap": "Silvio lunges for a torch his gear has thrown a hand's width wrong. It falls. The room does not gasp. It simply goes quiet."},
				{"scene": "champ", "stage": 2, "who": "", "hold": 420,
					"cap": "You keep it clean, and you keep it up, long past where nerve alone can carry a set. The rivalry turns here, and it turns quietly."},
			]
		"record":
			return [
				{"scene": "arena", "stage": 0, "who": "", "hold": 340,
					"cap": "Not a show tonight. An ordeal. One routine, impossibly long, and a single drop ends all of it."},
				{"scene": "arena", "stage": 1, "who": "", "hold": 400,
					"cap": "The music thins to almost nothing. There is only the count, your breath, and the weight moving through your hands."},
				{"scene": "arena", "stage": 2, "who": "", "hold": 440,
					"cap": "You hold, and hold, past the point where most hands give out, and the number climbs into places nobody has written down before."},
			]
		"finale":
			return [
				{"scene": "arena", "stage": 3, "who": "", "hold": 380,
					"cap": "Five torches. The largest crowd there is. A set that asks for everything at once and gives back nothing but the room's held breath."},
				{"scene": "arena", "stage": 3, "who": "", "hold": 400,
					"cap": "Silvio watches from the seats now, where the shortcut always ends. He is not bitter. He simply never learned to do this."},
				{"scene": "arena", "stage": 3, "who": "", "hold": 380,
					"cap": "Clean catch. Clean throw. The same two things she taught you, under all the pressure the world can bring. You land it."},
				{"scene": "backyard", "stage": 3, "who": "Bruna", "hold": 480,
					"cap": "\"There it is. Talent was always the cheap part, kid. This you earned.\" The same backyard. The same two hands. The circle closes."},
			]
		_:
			return [
				{"scene": "arena", "stage": 0, "who": "", "hold": 360,
					"cap": "The largest crowd there is, a field of small warm lights in one great dark bowl."},
				{"scene": "arena", "stage": 1, "who": "", "hold": 400,
					"cap": "Silvio watches from the seats now. No gear on earth can carry this stage. Only your hands can."},
				{"scene": "arena", "stage": 2, "who": "", "hold": 420,
					"cap": "So you throw, the way she taught you in a backyard a lifetime ago. Clean catch. Clean throw. The whole world holds its breath."},
			]


func beat_title(id: String) -> String:
	match id:
		"intro": return "The Backyard"
		"v1": return "Street Corner"
		"v2": return "The Small Theatre"
		"v3": return "The Circus"
		"v4": return "The Championship"
		"v5", "v6", "v7", "v8", "v9": return "The World Arena"
		"rival": return "The Turn"
		"record": return "The World Record"
		"finale": return "The World's Greatest Juggler"
		"one": return "Lesson  -  One Ball"
		"two": return "Lesson  -  Two Balls"
		"cascade": return "Lesson  -  The Cascade"
		"prop_1": return "New Prop  -  Eggs"
		"prop_2": return "New Prop  -  Rings"
		"prop_3": return "New Prop  -  Clubs"
		"prop_4": return "New Prop  -  Knives"
		"prop_5": return "New Prop  -  Torches"
		_: return ""


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
	last_rep_delta = 0
	run_venue = venue_index()   # records and the results card key off where you performed
	results_open = false
	results_record = false
	paused = false
	round_scored = false
	_prev_running = false
	# reset the trick state, and prime the key to the lowest trick this level owns
	trick_armed = -1
	trick_ready = -999
	spin_until = -999
	spin_scored = false
	tricks_landed = 0
	trick_score = 0
	trick_msg = ""
	trick_msg_tick = -999
	var unl := unlocked_tricks()
	trick_primed = int(unl[0]) if not unl.is_empty() else 0
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
		play_sfx("whiff", -14.0)
		return
	if best_d > W_LATE:
		# way off the arrival: a genuine mistime, the ball drops
		drop_ball(best, "MISTIME")
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
	# secured
	best.state = STATE_HAND
	stack(h).append(best)
	catch_flash[h] = tick
	caught += 1
	if tut_active:
		tut_on_catch()   # a guided lesson counts your clean catches toward its goal
	stamina = maxf(0.0, stamina - STAM_DRAIN_CATCH * energy_mult() * (1.0 + WEIGHT_STAM * float(prop_weight(best.kind) - 1)))
	play_sfx(_catch_sound(best.kind), -8.0)   # the prop's own catch timbre, every catch
	var sc_before := score
	if best_d <= wperf:
		streak += 1
		best_streak = maxi(best_streak, streak)
		score += 100 * streak
		applause = minf(1.0, applause + 0.05)
		add_xp(3)
		add_popup(outer_pos(h), "PERFECT", Color(1.0, 0.86, 0.42))
		play_sfx("perfect", -9.0)
		if streak % 5 == 0:
			play_sfx("streak", -7.0)   # a rising flourish at every fifth in a row
	elif best_d <= W_GOOD:
		streak += 1
		best_streak = maxi(best_streak, streak)
		score += 50 * streak
		applause = minf(1.0, applause + 0.025)
		add_xp(2)
		add_popup(outer_pos(h), "GOOD", Color(0.78, 0.92, 0.6))
		play_sfx("good", -11.0)
		if streak % 5 == 0:
			play_sfx("streak", -8.0)
	else:
		streak = 0
		score += 10
		applause = maxf(0.0, applause - 0.02)
		add_xp(1)
		add_popup(outer_pos(h), "late", Color(0.95, 0.62, 0.4))
		play_sfx("late", -11.0)

	# a live Spin doubles whatever this catch scored, and credits the trick once
	if spinning():
		var extra := score - sc_before
		score += int(round(float(extra) * (SPIN_CATCH_MULT - 1.0)))
		trick_score += int(round(float(extra) * (SPIN_CATCH_MULT - 1.0)))
		applause = minf(1.0, applause + 0.02)
		add_popup(outer_pos(h) + Vector2(0, -20), "x2", Color(0.72, 0.9, 1.0))
		if not spin_scored:
			spin_scored = true
			tricks_landed += 1
			add_xp(3)
	# an ARM trick (High Toss / Behind the Back) pays its flourish on a clean catch
	if best.trick >= 0 and best_d <= W_GOOD:
		reward_trick(best.trick, outer_pos(h))


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
	var deficit := prop_deficit()   # >0 when too weak for this prop: lower and wilder
	# A tap is the LOWEST, snappiest throw (BASE_AIR); each tick of hold adds airtime.
	# Strength makes each tick worth more height, so a strong juggler reaches a big
	# throw in less time. Being under a prop's Required Strength cuts the reachable
	# height (the ideas.rtf sagging-throw rule).
	var gain_mult := (1.0 + float(strength) * STR_HOLD_EFF) * (1.0 - DEFICIT_HEIGHT * deficit)
	var air := BASE_AIR + int(round(HOLD_GAIN * gain_mult * float(hold)))
	var frac := clampf(float(air - BASE_AIR) / (HOLD_GAIN * float(HOLD_MAX)), 0.0, 1.4)

	# a trick armed by the TRICK key reshapes this throw before we roll its accuracy,
	# so a High Toss genuinely flies (and is genuinely harder to catch)
	var this_trick := -1
	if trick_armed >= 0:
		this_trick = trick_armed
		trick_armed = -1
		if this_trick == TR_HIGH:
			frac = 1.35
		elif this_trick == TR_BTB:
			frac = clampf(frac + 0.12, 0.0, 1.4)   # a touch higher to clear the arc behind the back
		air = BASE_AIR + int(round(frac * HOLD_GAIN * float(HOLD_MAX)))
	b.height = frac
	b.trick = this_trick

	# Accuracy (dampened by low stamina) sets the base inaccuracy; a heavy prop and an
	# under-strength throw both widen it, and it all scales with the throw's height.
	var inacc := inacc_factor() * (1.0 + WEIGHT_INACC * float(weight - 1) + DEFICIT_INACC * deficit)
	var jitter := int(round(rng.randf_range(-1.0, 1.0) * float(JITTER_MAX) * frac * inacc))
	var drift := rng.randf_range(-1.0, 1.0) * DRIFT_MAX * frac * inacc

	b.state = STATE_FLIGHT
	b.launch_tick = tick
	b.land_tick = tick + air + jitter
	b.arc = ARC_PER_AIR * float(air)
	b.wobble = WOBBLE_MAX * frac * inacc
	stamina = maxf(0.0, stamina - STAM_DRAIN_THROW * energy_mult() * (1.0 + WEIGHT_STAM * float(weight - 1)))
	b.to_hand = other(h) if pattern == CASCADE else h
	b.from_pos = inner_pos(h)
	if this_trick == TR_BTB:
		# launch from across the body so the throw reads as a behind-the-back flourish
		b.from_pos = inner_pos(other(h)) + Vector2(0, 12)
		b.wobble += 5.0
	b.to_pos = outer_pos(b.to_hand) + Vector2(drift, 0.0)

	throw_kick[h] = tick
	charging[h] = false
	if not started:
		started = true
		running = true
	# a clean, controlled (low) throw earns a little Applause; a very high one does not
	# and flags itself above the stage so the player learns height control
	applause = minf(1.0, applause + 0.01 * (1.0 - clampf(frac, 0.0, 1.0)))
	if set_flags and frac >= 1.0:
		add_popup(Vector2(outer_pos(b.to_hand).x, get_viewport_rect().size.y * 0.31), "too high", Color(1.0, 0.82, 0.45, 0.9))
	play_sfx("throw", -16.0, clampf(1.2 - 0.09 * float(weight - 1) - 0.15 * frac, 0.5, 1.4))   # whoosh, lower for heavy/high
	if tut_active:
		tut_on_throw(h)   # a guided lesson watches your throws to advance its steps


func trick_unlocked(i: int) -> bool:
	return level >= int(TRICKS[i]["lvl"])


func unlocked_tricks() -> Array:
	var out: Array = []
	for i in TRICKS.size():
		if trick_unlocked(i):
			out.append(i)
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
	# The TRICK key (Space) fires whichever trick is primed. An "arm" trick loads
	# onto the next throw; a "live" trick (Spin) acts on the balls already up.
	var unl := unlocked_tricks()
	if unl.is_empty():
		set_trick_msg("no trick yet  -  keep leveling up")
		return
	if not unl.has(trick_primed):
		trick_primed = int(unl[0])
	var t: Dictionary = TRICKS[trick_primed]
	if int(t["min_air"]) > 0 and balls_airborne() < int(t["min_air"]):
		set_trick_msg("%s needs %d in the air" % [String(t["name"]), int(t["min_air"])])
		return
	if String(t["kind"]) == "arm":
		trick_armed = trick_primed
		set_trick_msg("%s armed  -  throw it" % String(t["name"]))
		play_sfx("ui2", -12.0)
	else:
		if tick < trick_ready:
			return   # still cooling down; ignore the mash
		spin_until = tick + SPIN_TICKS
		spin_scored = false
		trick_ready = tick + TRICK_COOLDOWN
		set_trick_msg("SPIN")
		play_sfx("streak", -7.0)


func cycle_trick() -> void:
	# C rotates the primed trick through the ones the current level has unlocked.
	var unl := unlocked_tricks()
	if unl.is_empty():
		set_trick_msg("no trick yet  -  keep leveling up")
		return
	var idx := unl.find(trick_primed)
	idx = (idx + 1) % unl.size() if idx >= 0 else 0
	trick_primed = int(unl[idx])
	set_trick_msg("%s ready" % String(TRICKS[trick_primed]["name"]))
	play_sfx("ui", -14.0)


func reward_trick(t: int, at: Vector2) -> void:
	# a landed ARM trick pays a flourish bonus on a clean (Perfect or Good) catch
	var bonus := 0
	var label := ""
	match t:
		TR_HIGH:
			bonus = HIGH_BONUS
			label = "HIGH TOSS!"
		TR_BTB:
			bonus = BTB_BONUS
			label = "BEHIND THE BACK!"
		_:
			return
	score += bonus
	trick_score += bonus
	tricks_landed += 1
	applause = minf(1.0, applause + 0.09)
	add_xp(4)
	add_popup(at + Vector2(0, -34), label, Color(1.0, 0.85, 0.45))
	play_sfx("streak", -6.0)


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
		save_progress()


func announce_new_tricks(prev_level: int) -> void:
	# a trick whose unlock level we just crossed gets a banner and is primed ready,
	# so the very next TRICK press does the thing the banner just explained
	for i in TRICKS.size():
		var lv := int(TRICKS[i]["lvl"])
		if lv > prev_level and lv <= level:
			trick_unlock = i
			trick_unlock_tick = tick
			trick_primed = i
			play_sfx("streak", -5.0)


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
		last_rep_delta = rep_delta
		last_pay = int(round((float(caught) * 1.2 + float(best_streak) * 2.0) * clean * diff * pay_mult()))
		money += last_pay
		if last_pay > 0:
			play_sfx("coin", -8.0)   # the pay chime at the end of a performance
		# a new personal best at this venue is the meta hook: a target to chase
		results_record = false
		if run_venue >= 0 and run_venue < best_scores.size() and score > best_scores[run_venue]:
			best_scores[run_venue] = score
			results_record = true
		# the results panel takes over the end-of-run screen for performances
		results_open = true
	# story beats fire on reputation milestones, once each: first the venue
	# promotions (tiers 1..5), then the endgame chapters past the arena (the
	# rivalry turning, the record ordeal, the finale). Both accumulate into one
	# cutscene so a big set can play its whole run of beats in order.
	var beats: Array[String] = []
	var vi := venue_index()
	if vi > venue_seen:
		for k in range(venue_seen + 1, vi + 1):
			beats.append("v%d" % k)
		venue_seen = vi
	while story_seen < STORY_REP.size() and reputation >= int(STORY_REP[story_seen]["rep"]):
		beats.append(String(STORY_REP[story_seen]["id"]))
		story_seen += 1
	save_progress()
	if not beats.is_empty():
		begin_cutscene(beats)


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


func catch_chance(quality: int, height: float) -> float:
	# probability that an off-Perfect catch (quality 1 = Good, 2 = Late) secures.
	# Rises with Accuracy and falls with the throw's height. Perfect timing is
	# handled separately in on_catch.
	var acc_norm := clampf(eff_accuracy() / ACC_FULL, 0.0, 1.0)
	var base := GOOD_BASE if quality == 1 else LATE_BASE
	var p := base + acc_norm * ACC_CATCH_BONUS - clampf(height, 0.0, 1.4) * HEIGHT_CATCH_PENALTY
	if has_glasses:
		p += GLASSES_CATCH_BONUS   # bought gear lifts the odds of an off-Perfect catch
	if spinning():
		p -= SPIN_ACC_PENALTY      # a Spin means catching blind, so off-Perfect gets riskier
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

# endgame story chapters, past the arena, keyed to reputation. These are the
# climax beats STORY.md builds toward: the rivalry finally turning, the record
# ordeal, and the finale where only your hands can win. They play once each.
const STORY_REP := [
	{"rep": 4000, "id": "rival"},
	{"rep": 5200, "id": "record"},
	{"rep": 6500, "id": "finale"},
]


func debug_jump_venue(i: int) -> void:
	# debug: leap anywhere in the story. Sets Reputation to that venue's threshold,
	# marks it seen (so promotions do not re-fire), plays its beat, and lands there.
	i = clampi(i, 0, 5)
	reputation = VENUE_REP[i]
	venue_seen = i
	save_progress()
	begin_cutscene(["intro" if i == 0 else "v%d" % i])


func debug_jump_story(i: int) -> void:
	# debug: preview the endgame story beats (rival/record/finale) without grinding
	# to their reputation gates. Marks them seen so they do not re-fire in play.
	i = clampi(i, 0, STORY_REP.size() - 1)
	reputation = maxi(reputation, int(STORY_REP[i]["rep"]))
	venue_seen = maxi(venue_seen, 5)
	story_seen = maxi(story_seen, i + 1)
	save_progress()
	begin_cutscene([String(STORY_REP[i]["id"])])


func venue_index() -> int:
	return venue_index_of(reputation)


func venue_index_of(rep: int) -> int:
	# the stage you play grows as Reputation climbs (the STORY.md venue ladder)
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
	return view_venue if view_venue >= 0 else venue_index()


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
	return SAVE_PATH_DEBUG if debug_mode else slot_path(save_slot)


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
		venue_seen = int(cf.get_value("prog", "venue_seen", venue_index()))
		story_seen = int(cf.get_value("prog", "story_seen", 0))
		var bs: Variant = cf.get_value("prog", "best_scores", [])
		if bs is Array:
			for i in mini((bs as Array).size(), best_scores.size()):
				best_scores[i] = int((bs as Array)[i])
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
	cf.set_value("prog", "venue_seen", venue_seen)
	cf.set_value("prog", "story_seen", story_seen)
	cf.set_value("prog", "best_scores", best_scores)
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
	if set_shake:
		shake = 5.0
	var dtext := why
	if b.kind == PROP_EGGS:
		# a dropped egg breaks for good, so it leaves your stock (ideas.rtf). A lesson
		# is practice, so a broken egg there is free (but still shows the mess).
		if not tut_active:
			prop_count[PROP_EGGS] = maxi(0, prop_count[PROP_EGGS] - 1)
			save_progress()
		dtext = "SPLAT"
		spawn_egg_break(flight_pos(b))   # shell shards fly, a yolk splats on the floor
		play_sfx("splat", -8.0)
	play_sfx("drop", -7.0)
	_duck = 1.0   # a drop briefly ducks the music, so the silence lands
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
		ST_CUTSCENE:
			draw_cutscene(font, s)
			return
		ST_ESTABLISH:
			draw_establish(font, s)
			return
	draw_backdrop(s)
	draw_egg_splats()      # yolk on the floor sits behind the performer
	draw_juggler(s)
	draw_targets()
	draw_balls_in_flight()
	draw_egg_shards()      # flying shell pieces read above the stage
	draw_vignette(s, 0.5)  # frame the lit stage so it reads photographed, not flat
	if tut_active:
		draw_tutorial_banner(font, s)   # a lesson shows only the guided banner, no HUD
	else:
		draw_hud(font, s)
	draw_popups(font)
	if results_open and not tut_active:
		draw_results(font, s)   # the end-of-performance card, over the frozen stage
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

	# spotlight cone from above centre
	var top := Vector2(s.x * 0.5, -40.0)
	var spread := 300.0
	var cone := PackedVector2Array([
		top,
		Vector2(s.x * 0.5 - spread, s.y * 0.82),
		Vector2(s.x * 0.5 + spread, s.y * 0.82),
	])
	draw_colored_polygon(cone, Color(glow.r, glow.g, glow.b, spot))

	# a SMOOTH warm light pool on the performer, built from many faint overlapping
	# discs (bright centre fading out), so it reads as a soft spotlight instead of
	# the hard target rings it used to be. A small floor keeps the stage from a void.
	var pc := Vector2(s.x * 0.5, s.y * 0.50)
	var pool := 0.045 + spot * 0.9
	for i in 26:
		var f := float(i) / 25.0                       # 0 outer .. 1 inner
		var r := lerpf(410.0, 34.0, f)
		var a := pool * (0.06 + 0.94 * f) * 0.16
		draw_circle(pc, r, Color(glow.r, glow.g, glow.b, a))

	# stage floor, with a soft warm lip of light where it meets the light pool
	var fy := s.y * 0.80
	draw_rect(Rect2(0, fy, s.x, s.y - fy), floor_c)
	draw_gradient_v(Rect2(0, fy, s.x, 34.0), Color(glow.r, glow.g, glow.b, 0.10 + spot), Color(glow.r, glow.g, glow.b, 0.0), 8)
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
	var v := venue_data(cur_venue())
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

	# a soft ground shadow so the figure stands ON the stage instead of floating
	draw_shadow(Vector2(cx, floor_y + 2.0), 96.0)

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

	# a live Spin: sweeping motion streaks, and the juggler turns their back mid-spin
	if spinning():
		draw_spin_effect(Vector2(cx, (shoulder_y + hip_y) * 0.5), head, head_r, hair)


func draw_spin_effect(center: Vector2, head: Vector2, head_r: float, hair: Color) -> void:
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
	# mid-spin the performer faces away, so hair covers the face for a beat
	if prog > 0.3 and prog < 0.7:
		draw_circle(head + Vector2(0, -4), head_r + 1.0, hair)


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

	# a clean mitt: a palm, a rounded finger group that extends to receive when open
	# and curls to a fist when closed, and a thumb toward the inside. Reads as a hand
	# catching, not a splayed claw.
	var sk := Color(0.87, 0.63, 0.43)
	var dk := Color(0.80, 0.56, 0.38)
	var openf := 1.0 - close
	# fingers point up and a touch inward, reaching further when open to catch
	var fdir := Vector2(inward * 0.22, -1.0).normalized()
	var reach := lerpf(7.0, 15.0, openf)
	var ftip := pos + fdir * reach
	draw_capsule(pos, ftip, 17.0, 13.0, sk)            # the four fingers, held together
	# thumb, a shorter capsule toward the centre line
	var tdir := Vector2(inward, -0.2).normalized()
	draw_capsule(pos, pos + tdir * lerpf(8.0, 11.0, openf), 8.0, 6.0, dk)
	# palm over the wrist join, drawn last so the hand reads as one solid shape
	draw_circle(pos, 11.5, sk)
	draw_circle(pos + Vector2(0, -2), 8.0, Color(1.0, 0.82, 0.55, 0.12))

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

	# a freshly unlocked trick announces itself, non-blocking so a live run is never frozen
	if not tut_active and trick_unlock >= 0 and tick - trick_unlock_tick < 600:
		draw_trick_unlock_banner(font, s)
	# trick feedback line, centred (works even before any trick is unlocked)
	if not tut_active and trick_msg != "" and tick - trick_msg_tick < 90:
		var ta := clampf(1.0 - float(tick - trick_msg_tick) / 90.0, 0.0, 1.0)
		draw_string(font, Vector2(s.x * 0.5 - 170, s.y * 0.30), trick_msg, HORIZONTAL_ALIGNMENT_CENTER, 340, 18, Color(1.0, 0.88, 0.55, ta))
	# the primed-trick readout sits just above the control hints, once a trick exists
	if not tut_active and not results_open and not unlocked_tricks().is_empty():
		draw_trick_hud(font, s)

	# the round chrome (venue line, control hints, ROUND OVER, start prompt) is
	# hidden during a lesson, and behind the results card, to keep those clean
	if not tut_active and not results_open:
		var patt := "CASCADE  (crossing)" if pattern == CASCADE else "FOUNTAIN  (columns)"
		var propname := String(cur_prop()["name"]).to_upper()
		var vname := String(venue_data(venue_index())["name"]).to_upper()
		if prop_deficit() > 0.0:
			draw_string(font, Vector2(30, s.y - 96), "TOO WEAK for %s  -  throws sag low and wild (needs Strength %d)" % [propname, prop_req()], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.0, 0.55, 0.4))
		draw_string(font, Vector2(30, s.y - 74), "%s  -  %d %s  -  %s" % [vname, num_balls, propname, patt], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1.0, 0.8, 0.5))
		if set_hints:
			var unlock := ""
			if next_ball_strength() > 0:
				unlock = "   ( next ball at Strength %d )" % next_ball_strength()
			draw_string(font, Vector2(30, s.y - 52), "[ ] count   O prop   S shop%s" % unlock, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.78, 0.7, 0.58, 0.85))
			draw_string(font, Vector2(30, s.y - 30),
				"catch D/K  throw F/J (hold=higher)  O prop  P perform/train  Tab sheet  R restart  Esc pause",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.82, 0.72, 0.6, 0.85))

		if not started:
			var verb := "perform" if performing else "practise"
			draw_string(font, Vector2(s.x * 0.5 - 220, s.y * 0.23),
				"press a THROW (F or J) to %s   -   P to %s instead" % [verb, "train" if performing else "perform"],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1.0, 0.86, 0.55))
		elif not running and not results_open:
			# training (or a performance with no panel) keeps the plain end-of-run line
			draw_string(font, Vector2(s.x * 0.5 - 150, s.y * 0.20), "ROUND OVER", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(1.0, 0.5, 0.4))
			draw_string(font, Vector2(s.x * 0.5 - 190, s.y * 0.20 + 40), "best streak %d   XP +%d   -   press R to go again" % [best_streak, run_xp], HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color(0.9, 0.82, 0.7))


func _result_row(font: Font, lx: float, rx: float, y: float, label: String, value: String, vc: Color) -> void:
	draw_string(font, Vector2(lx, y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.78, 0.72, 0.66))
	draw_string(font, Vector2(rx - 300.0, y), value, HORIZONTAL_ALIGNMENT_RIGHT, 300.0, 18, vc)


func draw_results(font: Font, s: Vector2) -> void:
	# the end-of-performance card: the grade, the numbers, the pay and rep swing, and
	# the venue record to chase. This is the meta payoff screen for a whole set.
	draw_rect(Rect2(0, 0, s.x, s.y), Color(0.04, 0.02, 0.03, 0.82))
	var pw := 580.0
	var ph := 460.0
	var px := s.x * 0.5 - pw * 0.5
	var py := s.y * 0.5 - ph * 0.5
	draw_rect(Rect2(px, py, pw, ph), Color(0.12, 0.07, 0.08, 0.98))
	draw_rect(Rect2(px, py, pw, ph), Color(0.9, 0.6, 0.35, 0.5), false, 2.0)
	var lx := px + 34.0
	var rx := px + pw - 34.0

	# header: the run's venue, and a grade badge to the right
	draw_string(font, Vector2(lx, py + 40.0), "PERFORMANCE", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.85, 0.72, 0.55))
	draw_string(font, Vector2(lx, py + 74.0), String(venue_data(run_venue)["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1.0, 0.86, 0.5))
	var g := run_grade()
	var gc := grade_color(g)
	var bc := Vector2(rx - 42.0, py + 56.0)
	draw_circle(bc, 42.0, Color(gc.r, gc.g, gc.b, 0.14))
	draw_arc(bc, 42.0, 0.0, TAU, 40, gc, 3.0, true)
	draw_string(font, Vector2(bc.x - 42.0, bc.y + 21.0), g, HORIZONTAL_ALIGNMENT_CENTER, 84.0, 58, gc)
	draw_line(Vector2(lx, py + 104.0), Vector2(rx, py + 104.0), Color(0.9, 0.6, 0.35, 0.3), 1.0)

	# stat rows
	var y := py + 140.0
	var rowh := 40.0
	_result_row(font, lx, rx, y, "Score", str(score), Color(1.0, 0.92, 0.72))
	var rec := "NEW VENUE RECORD" if results_record else "best here   %d" % best_scores[run_venue]
	var recc := Color(1.0, 0.86, 0.42) if results_record else Color(0.68, 0.62, 0.54)
	draw_string(font, Vector2(rx - 300.0, y + 15.0), rec, HORIZONTAL_ALIGNMENT_RIGHT, 300.0, 13, recc)
	y += rowh + 8.0
	var pct := int(round(100.0 * run_clean()))
	_result_row(font, lx, rx, y, "Caught  /  Dropped", "%d  /  %d    (%d%%)" % [caught, dropped, pct], Color(0.86, 0.9, 0.82)); y += rowh
	_result_row(font, lx, rx, y, "Best streak", str(best_streak), Color(0.9, 0.82, 0.6)); y += rowh
	var tval := "%d   (+%d)" % [tricks_landed, trick_score] if trick_score > 0 else str(tricks_landed)
	_result_row(font, lx, rx, y, "Tricks landed", tval, Color(0.93, 0.8, 0.99)); y += rowh
	draw_line(Vector2(lx, y - 6.0), Vector2(rx, y - 6.0), Color(0.9, 0.6, 0.35, 0.2), 1.0)
	_result_row(font, lx, rx, y + 20.0, "Pay", "+%d gold" % last_pay, Color(1.0, 0.86, 0.45)); y += rowh
	var rsign := "+" if last_rep_delta >= 0 else ""
	var rcol := Color(0.7, 0.95, 0.7) if last_rep_delta >= 0 else Color(1.0, 0.55, 0.45)
	_result_row(font, lx, rx, y + 20.0, "Reputation", "%s%d    %s" % [rsign, last_rep_delta, rep_tier()], rcol); y += rowh
	_result_row(font, lx, rx, y + 20.0, "XP gained", "+%d" % run_xp, Color(0.82, 0.9, 0.7)); y += rowh

	# footer: how to continue
	var foot := "R  go again      S  shop      Esc  menu"
	if points > 0:
		foot = "R  go again      Tab  +%d point%s      S  shop      Esc  menu" % [points, "" if points == 1 else "s"]
	draw_string(font, Vector2(px, py + ph - 26.0), foot, HORIZONTAL_ALIGNMENT_CENTER, pw, 15, Color(0.86, 0.78, 0.64))


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
	var opts: Array[String] = ["Resume", "Main Menu", "Quit Game"]
	var oy := py + 116.0
	for i in opts.size():
		var sel := i == pause_sel
		var col := Color(1.0, 0.9, 0.6) if sel else Color(0.74, 0.68, 0.62)
		var label := ("> %s <" % opts[i]) if sel else opts[i]
		draw_string(font, Vector2(px, oy + float(i) * 40.0), label, HORIZONTAL_ALIGNMENT_CENTER, pw, 22, col)
	draw_string(font, Vector2(px, py + ph - 20.0), "up / down  -  Enter  -  Esc resumes", HORIZONTAL_ALIGNMENT_CENTER, pw, 12, Color(0.72, 0.66, 0.6))


func draw_trick_unlock_banner(font: Font, s: Vector2) -> void:
	var age := tick - trick_unlock_tick
	var a := 1.0
	if age < 18:
		a = float(age) / 18.0
	elif age > 540:
		a = clampf(float(600 - age) / 60.0, 0.0, 1.0)
	var t: Dictionary = TRICKS[trick_unlock]
	var bw := 620.0
	var bx := s.x * 0.5 - bw * 0.5
	var cy := s.y * 0.19
	draw_rect(Rect2(bx, cy - 28.0, bw, 88.0), Color(0.10, 0.06, 0.08, 0.9 * a))
	draw_rect(Rect2(bx, cy - 28.0, bw, 88.0), Color(1.0, 0.82, 0.45, 0.55 * a), false, 2.0)
	draw_string(font, Vector2(bx, cy - 4.0), "NEW TRICK   -   %s" % String(t["name"]).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, bw, 21, Color(1.0, 0.88, 0.5, a))
	var how := "press C to select it, then Space to spin" if String(t["kind"]) == "live" else "press Space to arm it, then throw"
	draw_string(font, Vector2(bx, cy + 22.0), how, HORIZONTAL_ALIGNMENT_CENTER, bw, 15, Color(1.0, 0.9, 0.65, a))
	draw_string(font, Vector2(bx + 16.0, cy + 44.0), String(t["desc"]), HORIZONTAL_ALIGNMENT_CENTER, bw - 32.0, 13, Color(0.86, 0.8, 0.72, 0.85 * a))


func draw_trick_hud(font: Font, s: Vector2) -> void:
	var unl := unlocked_tricks()
	if not unl.has(trick_primed):
		trick_primed = int(unl[0])
	var t: Dictionary = TRICKS[trick_primed]
	var x := s.x * 0.5 - 150.0
	var y := s.y - 132.0
	draw_string(font, Vector2(x, y), "TRICK  -  %s" % String(t["name"]).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 300, 16, Color(0.93, 0.8, 0.99))
	var status := "Space to perform"
	var scol := Color(0.82, 0.74, 0.92, 0.9)
	if trick_armed == trick_primed:
		status = "ARMED  -  throw it"
		scol = Color(1.0, 0.86, 0.5)
	elif String(t["kind"]) == "live" and tick < trick_ready:
		status = "cooldown %.1fs" % (float(trick_ready - tick) / 120.0)
		scol = Color(0.72, 0.62, 0.64, 0.85)
	elif String(t["kind"]) == "live":
		status = "Space to spin"
	if unl.size() > 1:
		status += "     C to switch"
	draw_string(font, Vector2(x, y + 20.0), status, HORIZONTAL_ALIGNMENT_CENTER, 300, 13, scol)


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
	var xbw := 300.0   # kept short so it never runs under the gold/reputation column
	draw_rect(Rect2(tx, py + 66.0, xbw, 10.0), Color(0.2, 0.14, 0.11, 0.8))
	draw_rect(Rect2(tx, py + 66.0, xbw * xf, 10.0), Color(0.9, 0.7, 0.35))
	draw_string(font, Vector2(tx, py + 92.0), "%d / %d xp to next level" % [xp, need], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.8, 0.72, 0.58))

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


# -----------------------------------------------------------------------------
# Menu, save-slot, settings, and cutscene screens.
# -----------------------------------------------------------------------------

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

	# a live juggling cascade above the title (real motion, not a frozen motif)
	var dj := demo_juggle(Vector2(cx, s.y * 0.15), 1.0, 3)
	for b in dj["balls"]:
		draw_ball_shape(b["pos"], b["col"], 1.25)

	draw_title_glow(font, s.y * 0.32, "JUGGLE", 92, Color(1.0, 0.88, 0.5), s)
	draw_ornament(cx, s.y * 0.32 + 112.0, 230.0, Color(0.82, 0.62, 0.34, 0.85))
	draw_string(font, Vector2(0, s.y * 0.32 + 160.0), "a juggler's climb", HORIZONTAL_ALIGNMENT_CENTER, s.x, 22, Color(0.85, 0.72, 0.6))

	var opts := ["Play", "Settings", "Quit"]
	var oy := s.y * 0.62
	for i in opts.size():
		var sel := i == menu_sel
		var txt := ("%s" % opts[i]) if not sel else (">    %s    <" % opts[i])
		var col := Color(1.0, 0.9, 0.55) if sel else Color(0.72, 0.66, 0.6)
		draw_string(font, Vector2(0, oy + float(i) * 44.0), txt, HORIZONTAL_ALIGNMENT_CENTER, s.x, 28, col)
	draw_string(font, Vector2(0, s.y - 40.0), "Up / Down to choose    Enter to select", HORIZONTAL_ALIGNMENT_CENTER, s.x, 15, Color(0.7, 0.66, 0.6))

	draw_vignette(s, 0.5)
	draw_frame(s, 22.0, Color(0.82, 0.62, 0.34, 0.5))


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
		var tcol := Color(1.0, 0.9, 0.6) if sel else Color(0.8, 0.74, 0.66)
		draw_string(font, Vector2(px + 24.0, ry + 27.0), "Slot %d" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, tcol)
		draw_string(font, Vector2(px + 24.0, ry + 49.0), sum, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.78, 0.72, 0.62))
		if sum != "empty":
			draw_string(font, Vector2(px + pw - 110.0, ry + 37.0), "[X] delete", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.88, 0.55, 0.5))

	var by := oy + float(NUM_SLOTS) * 74.0 + 16.0
	var bsel := menu_sel == NUM_SLOTS
	draw_string(font, Vector2(0, by + 22.0), ("Back" if not bsel else ">   Back   <"), HORIZONTAL_ALIGNMENT_CENTER, s.x, 24, Color(1.0, 0.9, 0.55) if bsel else Color(0.72, 0.66, 0.6))
	draw_string(font, Vector2(0, s.y - 42.0), "Up / Down    Enter to play    X to delete    Esc to go back", HORIZONTAL_ALIGNMENT_CENTER, s.x, 15, Color(0.7, 0.66, 0.6))
	draw_vignette(s, 0.5)
	draw_frame(s, 22.0, Color(0.82, 0.62, 0.34, 0.5))


func draw_settings(font: Font, s: Vector2) -> void:
	view_venue = 2
	draw_backdrop(s)
	view_venue = -1
	draw_rect(Rect2(0, 0, s.x, s.y), Color(0.03, 0.02, 0.03, 0.62))
	draw_string(font, Vector2(0, s.y * 0.17), "SETTINGS", HORIZONTAL_ALIGNMENT_CENTER, s.x, 44, Color(1.0, 0.86, 0.5))

	var rows := [["Music", set_music], ["Sound effects", set_sfx], ["Screen shake", set_shake], ["Control hints", set_hints], ["Throw flags (TOO LOW / high)", set_flags]]
	var pw := 560.0
	var px := s.x * 0.5 - pw * 0.5
	var oy := s.y * 0.30
	for i in rows.size():
		var sel := i == menu_sel
		var ry := oy + float(i) * 52.0
		var nm := String(rows[i][0])
		var on := bool(rows[i][1])
		draw_string(font, Vector2(px, ry), ("> " if sel else "  ") + nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1.0, 0.9, 0.6) if sel else Color(0.8, 0.74, 0.66))
		draw_string(font, Vector2(px + pw - 60.0, ry), "ON" if on else "OFF", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.6, 0.9, 0.6) if on else Color(0.85, 0.6, 0.55))

	var bsel := menu_sel == rows.size()
	draw_string(font, Vector2(0, oy + float(rows.size()) * 52.0 + 30.0), ("Back" if not bsel else ">   Back   <"), HORIZONTAL_ALIGNMENT_CENTER, s.x, 24, Color(1.0, 0.9, 0.55) if bsel else Color(0.72, 0.66, 0.6))
	draw_string(font, Vector2(0, s.y - 42.0), "Up / Down    Enter to toggle    Esc to go back", HORIZONTAL_ALIGNMENT_CENTER, s.x, 15, Color(0.7, 0.66, 0.6))
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
	mus_pad = AudioStreamPlayer.new(); add_child(mus_pad); mus_pad.volume_db = -80.0
	mus_bass = AudioStreamPlayer.new(); add_child(mus_bass); mus_bass.volume_db = -80.0
	mus_arp = AudioStreamPlayer.new(); add_child(mus_arp); mus_arp.volume_db = -80.0
	crowd_ply = AudioStreamPlayer.new(); add_child(crowd_ply); crowd_ply.volume_db = -80.0
	crowd_ply.stream = gen_crowd()
	crowd_ply.play()
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
	# runs every frame in every state: pick the theme and glide the layer volumes
	if not _audio_ready:
		return
	var want := clampi(cur_venue(), 0, 5) if (game_state == ST_PLAY or game_state == ST_ESTABLISH) else 2
	if want != music_theme:
		load_music_theme(want)
	var in_play := game_state == ST_PLAY
	var perf := in_play and mode == MODE_PERFORM and not tut_active
	var active := in_play and running
	var energy := clampf(applause * 0.65 + clampf(float(streak) / 8.0, 0.0, 1.0) * 0.55, 0.0, 1.0)
	var pad_t := -13.0
	var bass_t := -11.0 if active else -50.0
	var arp_t := lerpf(-32.0, -9.0, energy) if in_play else -18.0
	var crowd_t := lerpf(-27.0, -5.0, applause) if perf else -60.0
	if game_state == ST_MENU or game_state == ST_CUTSCENE:
		pad_t = -11.0
		bass_t = -50.0
		arp_t = -17.0
	if not set_music:
		pad_t = -80.0
		bass_t = -80.0
		arp_t = -80.0
	if not set_music or not set_sfx:
		crowd_t = -80.0
	var duck := _duck * 9.0
	_vol["pad"] = lerpf(_vol["pad"], pad_t - duck, 0.06)
	_vol["bass"] = lerpf(_vol["bass"], bass_t - duck, 0.08)
	_vol["arp"] = lerpf(_vol["arp"], arp_t - duck, 0.08)
	_vol["crowd"] = lerpf(_vol["crowd"], crowd_t, 0.05)
	mus_pad.volume_db = _vol["pad"]
	mus_bass.volume_db = _vol["bass"]
	mus_arp.volume_db = _vol["arp"]
	crowd_ply.volume_db = _vol["crowd"]
	_duck = maxf(0.0, _duck - 0.03)


var _theme_cache: Dictionary = {}

func load_music_theme(vi: int) -> void:
	if not _theme_cache.has(vi):
		_theme_cache[vi] = gen_music_layers(vi)
	var L: Dictionary = _theme_cache[vi]
	mus_pad.stream = L["pad"]
	mus_bass.stream = L["bass"]
	mus_arp.stream = L["arp"]
	mus_pad.play()
	mus_bass.play()
	mus_arp.play()
	music_theme = vi


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


func gen_sfx() -> void:
	sfx["perfect"] = _wav(_tone([1046.5, 1568.0], [1.0, 0.6], 0.30, 0, 0.002, 0.10, 0.5, 0.0), false)
	sfx["good"] = _wav(_tone([784.0, 1176.0], [1.0, 0.4], 0.22, 0, 0.002, 0.08, 0.42, 0.0), false)
	sfx["late"] = _wav(_tone([330.0], [1.0], 0.16, 1, 0.004, 0.06, 0.4, 0.05), false)
	sfx["whiff"] = _wav(_tone([600.0], [1.0], 0.12, 0, 0.001, 0.05, 0.3, 0.85), false)
	sfx["drop"] = _wav(_drop_sound(), false)
	sfx["splat"] = _wav(_splat_sound(), false)
	sfx["coin"] = _wav(_seq_bells([987.8, 1318.5], 0.09, 0.5), false)
	sfx["streak"] = _wav(_seq_bells([784.0, 987.8, 1318.5], 0.08, 0.5), false)
	sfx["ui"] = _wav(_tone([880.0], [1.0], 0.05, 0, 0.001, 0.02, 0.3, 0.0), false)
	sfx["ui2"] = _wav(_tone([1174.7, 1568.0], [1.0, 0.5], 0.10, 0, 0.001, 0.05, 0.35, 0.0), false)
	sfx["c_ball"] = _wav(_tone([420.0], [1.0], 0.10, 0, 0.001, 0.035, 0.5, 0.15), false)
	sfx["c_egg"] = _wav(_tone([520.0], [1.0], 0.09, 0, 0.001, 0.03, 0.45, 0.2), false)
	sfx["c_ring"] = _wav(_tone([300.0, 452.0], [1.0, 0.5], 0.34, 0, 0.004, 0.22, 0.4, 0.0), false)
	sfx["c_club"] = _wav(_tone([190.0, 320.0], [1.0, 0.4], 0.10, 1, 0.001, 0.04, 0.5, 0.25), false)
	sfx["c_knife"] = _wav(_tone([1200.0, 2760.0, 5400.0], [1.0, 0.5, 0.25], 0.42, 0, 0.001, 0.30, 0.32, 0.0), false)
	sfx["c_torch"] = _wav(_tone([140.0], [1.0], 0.28, 0, 0.02, 0.18, 0.4, 0.7), false)
	sfx["throw"] = _wav(_tone([300.0], [1.0], 0.14, 0, 0.005, 0.07, 0.28, 0.8), false)


func gen_crowd() -> AudioStreamWAV:
	var dur := 3.0
	var n := int(AUDIO_SR * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		lp = lp * 0.96 + (randf() * 2.0 - 1.0) * 0.04   # lowpass white noise -> murmur
		var lfo := 0.7 + 0.3 * sin(TAU * float(i) / AUDIO_SR * 0.7)
		out[i] = clampf(lp * 3.0 * lfo, -1.0, 1.0)
	_fade_ends(out, 40)
	return _wav(out, true)


func _fade_ends(buf: PackedFloat32Array, ms: float) -> void:
	# ramp the first and last few ms to zero, so a looped buffer never clicks
	var f := mini(int(AUDIO_SR * ms / 1000.0), buf.size() / 2)
	for i in f:
		var g := float(i) / float(f)
		buf[i] *= g
		buf[buf.size() - 1 - i] *= g


# --- adaptive music: a static drone plus a bass and an arpeggio ---------------

func venue_music(vi: int) -> Dictionary:
	vi = clampi(vi, 0, 5)
	var roots := [196.0, 220.0, 174.61, 233.08, 261.63, 196.0]   # a colour per venue tier
	var tempos := [88.0, 96.0, 100.0, 108.0, 112.0, 100.0]
	var brights := [0.45, 0.6, 0.7, 0.8, 0.9, 0.95]
	return {"root": float(roots[vi]), "tempo": float(tempos[vi]), "bright": float(brights[vi]), "chords": [0, 8]}


func _align(freq: float, dur: float) -> float:
	# quantise to a whole number of cycles over dur, so a sustained tone loops clean
	return maxf(1.0, round(freq * dur)) / dur


func _pluck_into(buf: PackedFloat32Array, start: int, freq: float, decay: float, vol: float, wave: int) -> void:
	var n := buf.size()
	var ph := 0.0
	for i in int(AUDIO_SR * decay * 3.0):
		var idx := start + i
		if idx >= n:
			break
		ph += TAU * freq / AUDIO_SR
		buf[idx] = clampf(buf[idx] + _wsamp(ph, wave) * exp(-float(i) / AUDIO_SR / maxf(decay, 0.0001)) * vol, -1.0, 1.0)


func gen_music_floats(vi: int) -> Dictionary:
	var p := venue_music(vi)
	var root: float = p["root"]
	var beat := 60.0 / float(p["tempo"])
	var chords: Array = p["chords"]
	var bars := chords.size()
	var dur := float(bars * 4) * beat
	var n := int(AUDIO_SR * dur)
	var pad := PackedFloat32Array(); pad.resize(n)
	var bass := PackedFloat32Array(); bass.resize(n)
	var arp := PackedFloat32Array(); arp.resize(n)

	# pad: a static power-chord drone (root, fifth, octave), aligned so it loops seamlessly
	var pf := [_align(root, dur), _align(root * 1.5, dur), _align(root * 2.0, dur)]
	var pph := PackedFloat32Array(); pph.resize(3)
	for i in n:
		var s := 0.0
		for j in 3:
			pph[j] += TAU * float(pf[j]) / AUDIO_SR
			s += sin(pph[j])
		pad[i] = (s / 3.0) * 0.5 * (0.85 + 0.15 * sin(TAU * float(i) / AUDIO_SR * 0.15))

	var arp_pat := [0, 3, 7, 10, 12, 10, 7, 3]   # a minor riff, consonant under the drone
	for bar in bars:
		var croot := root * pow(2.0, float(chords[bar]) / 12.0)
		for bt in 4:
			_pluck_into(bass, int(AUDIO_SR * float(bar * 4 + bt) * beat), croot * 0.5, minf(beat * 0.9, 0.35), 0.5, 1)
		for e in 8:
			var f := croot * pow(2.0, float(arp_pat[e]) / 12.0) * 2.0
			_pluck_into(arp, int(AUDIO_SR * (float(bar * 4) + float(e) * 0.5) * beat), f, 0.16, 0.32 * float(p["bright"]), 0)
	_fade_ends(bass, 12)
	_fade_ends(arp, 12)
	return {"pad": pad, "bass": bass, "arp": arp}


func gen_music_layers(vi: int) -> Dictionary:
	var f := gen_music_floats(vi)
	return {"pad": _wav(f["pad"], true), "bass": _wav(f["bass"], true), "arp": _wav(f["arp"], true)}


func dump_audio(dir: String) -> void:
	# dev: write every sound to <dir> as .wav, for verification and preview
	for name in sfx:
		(sfx[name] as AudioStreamWAV).save_to_wav("%s/sfx_%s.wav" % [dir, name])
	(crowd_ply.stream as AudioStreamWAV).save_to_wav("%s/crowd.wav" % dir)
	for vi in [0, 2, 4]:
		var f := gen_music_floats(vi)
		var pad: PackedFloat32Array = f["pad"]
		var bass: PackedFloat32Array = f["bass"]
		var arp: PackedFloat32Array = f["arp"]
		var mix := PackedFloat32Array()
		mix.resize(pad.size() * 2)
		for rep in 2:
			for i in pad.size():
				mix[rep * pad.size() + i] = clampf(pad[i] * 0.5 + bass[i] * 0.9 + arp[i] * 0.8, -1.0, 1.0)
		_wav(mix, false).save_to_wav("%s/music%d_mix.wav" % [dir, vi])


# =============================================================================
# Cinematic layer. Everything below is procedural (the code-only art rule,
# ART_AND_MUSIC.md): the film-style cutscenes, the establishing cards, the
# tutorial demos, and the shared "royal" polish (gradients, vignette, letterbox,
# gold frames, drifting dust). cine_tick drives all the motion.
# =============================================================================

func draw_cutscene(font: Font, s: Vector2) -> void:
	var script := cur_script()
	if script.is_empty():
		return
	var shot: Dictionary = script[clampi(cs_shot, 0, script.size() - 1)]
	draw_shot(shot, s)

	# each cut dissolves in from black, so the shots read as a film, not a slideshow
	var age := cine_tick - cs_shot_start
	var fin := clampf(float(age) / 22.0, 0.0, 1.0)
	if fin < 1.0:
		draw_rect(Rect2(0, 0, s.x, s.y), Color(0.02, 0.01, 0.02, 1.0 - fin))
	draw_vignette(s, 0.62)

	var topbar := 70.0
	var botbar := 122.0
	draw_letterbox(s, topbar, botbar)

	# title, centred in the top bar, with a gold ornament rule under it
	var title := beat_title(cur_beat_id())
	draw_title_glow(font, 30.0, title, 30, Color(1.0, 0.88, 0.55), s)
	draw_ornament(s.x * 0.5, 58.0, 150.0, Color(0.82, 0.62, 0.34, 0.85))

	# caption in the lower bar, fading in just after the picture
	var capA := clampf(float(age - 8) / 20.0, 0.0, 1.0)
	var who := String(shot.get("who", ""))
	var cap := String(shot.get("cap", ""))
	var mx := 96.0
	var cy := s.y - botbar + 32.0
	if who != "":
		draw_string(font, Vector2(mx, cy), who, HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color(1.0, 0.82, 0.42, capA))
		cy += 27.0
	draw_multiline_string(font, Vector2(mx, cy), cap, HORIZONTAL_ALIGNMENT_LEFT, s.x - 2.0 * mx, 20, -1, Color(0.95, 0.9, 0.82, capA))

	draw_shot_dots(script.size(), cs_shot, s.x * 0.5, s.y - 20.0)
	draw_string(font, Vector2(s.x - 220.0, s.y - 14.0), "any key:  next", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.72, 0.67, 0.6))


func draw_shot(shot: Dictionary, s: Vector2) -> void:
	match String(shot.get("scene", "")):
		"backyard": scene_backyard(s, int(shot.get("stage", 0)))
		"street": scene_street(s, int(shot.get("stage", 0)))
		"theatre": scene_theatre(s, int(shot.get("stage", 0)))
		"circus": scene_circus(s, int(shot.get("stage", 0)))
		"champ": scene_champ(s, int(shot.get("stage", 0)))
		"arena": scene_arena(s, int(shot.get("stage", 0)))
		_: draw_venue_exterior(s, 0)


# --- the establishing card: WHERE you are about to perform --------------------

func draw_establish(font: Font, s: Vector2) -> void:
	draw_venue_exterior(s, establish_venue)
	var fin := clampf(float(cine_tick) / 26.0, 0.0, 1.0)
	if fin < 1.0:
		draw_rect(Rect2(0, 0, s.x, s.y), Color(0.02, 0.01, 0.02, 1.0 - fin))
	draw_vignette(s, 0.6)
	draw_frame(s, 22.0, Color(0.82, 0.62, 0.34, 0.55))

	# a small tag up top, then the venue name and a warm prompt, all in the light
	var tagA := clampf(float(cine_tick - 10) / 20.0, 0.0, 1.0)
	draw_string(font, Vector2(0, s.y * 0.12), "TONIGHT  YOU  PERFORM  AT", HORIZONTAL_ALIGNMENT_CENTER, s.x, 17, Color(0.9, 0.78, 0.55, 0.85 * tagA))
	var vn := String(venue_data(establish_venue)["name"]).to_upper()
	draw_title_glow(font, s.y * 0.14 + 12.0, vn, 56, Color(1.0, 0.9, 0.55), s)
	draw_ornament(s.x * 0.5, s.y * 0.14 + 78.0, 190.0, Color(0.82, 0.62, 0.34, 0.85))

	# the standing record here, so the player walks on with a number to beat
	if establish_venue >= 0 and establish_venue < best_scores.size() and best_scores[establish_venue] > 0:
		draw_string(font, Vector2(0, s.y * 0.14 + 112.0), "your record here   %d" % best_scores[establish_venue], HORIZONTAL_ALIGNMENT_CENTER, s.x, 18, Color(0.96, 0.83, 0.52, 0.85 * tagA))

	var py := s.y - 70.0
	draw_gradient_v(Rect2(0, py - 30.0, s.x, s.y - py + 30.0), Color(0.02, 0.01, 0.02, 0.0), Color(0.02, 0.01, 0.02, 0.9), 16)
	var pulse := 0.6 + 0.4 * sin(float(cine_tick) * 0.08)
	draw_string(font, Vector2(0, s.y - 34.0), "press any key to step on stage", HORIZONTAL_ALIGNMENT_CENTER, s.x, 18, Color(1.0, 0.9, 0.6, 0.5 + 0.5 * pulse))


# --- shared premium-look helpers ---------------------------------------------

func draw_gradient_v(r: Rect2, top: Color, bot: Color, steps: int = 22) -> void:
	# a vertical gradient, drawn as stacked strips (no shaders, per the art rule)
	var n := maxi(1, steps)
	for i in n:
		var f := float(i) / float(n)
		var y := r.position.y + r.size.y * f
		draw_rect(Rect2(r.position.x, y, r.size.x, r.size.y / float(n) + 1.0), top.lerp(bot, f))


func draw_gradient_h(r: Rect2, left: Color, right: Color, steps: int = 22) -> void:
	var n := maxi(1, steps)
	for i in n:
		var f := float(i) / float(n)
		var x := r.position.x + r.size.x * f
		draw_rect(Rect2(x, r.position.y, r.size.x / float(n) + 1.0, r.size.y), left.lerp(right, f))


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
		var by := fposmod(0.9 - float(cine_tick) * 0.0008 * speed - float(i) * 0.13, 1.0)
		var px := bx * s.x + sin(float(cine_tick) * 0.01 + seed) * 12.0
		var py := by * s.y
		var a := 0.10 + 0.10 * sin(float(cine_tick) * 0.03 + seed)
		draw_circle(Vector2(px, py), 1.4, Color(glow.r, glow.g, glow.b, maxf(0.0, a)))


func draw_shot_dots(n: int, cur: int, cx: float, y: float) -> void:
	var gap := 14.0
	var x0 := cx - gap * float(n - 1) * 0.5
	for i in n:
		var on := i <= cur
		draw_circle(Vector2(x0 + gap * float(i), y), 3.5 if on else 2.5,
			Color(1.0, 0.85, 0.5, 0.95) if on else Color(0.6, 0.55, 0.5, 0.6))


# --- procedural characters (Milo, Bruna, Silvio, the troupe) ------------------

func milo_pal(vi: int) -> Dictionary:
	var v := venue_data(vi)
	return {"skin": Color(0.87, 0.64, 0.45), "coat": v["suit"], "coat_dk": v["suit_dk"],
		"trouser": v["suit_dk"], "accent": v["vest"], "hair": Color(0.28, 0.16, 0.11), "hat": "none"}


func bruna_pal() -> Dictionary:
	return {"skin": Color(0.82, 0.62, 0.46), "coat": Color(0.46, 0.30, 0.34), "coat_dk": Color(0.32, 0.21, 0.24),
		"trouser": Color(0.30, 0.24, 0.24), "accent": Color(0.80, 0.55, 0.45), "hair": Color(0.82, 0.80, 0.76), "shawl": true, "hat": "none"}


func silvio_pal() -> Dictionary:
	return {"skin": Color(0.90, 0.70, 0.55), "coat": Color(0.16, 0.15, 0.22), "coat_dk": Color(0.09, 0.08, 0.13),
		"trouser": Color(0.10, 0.09, 0.13), "accent": Color(0.95, 0.82, 0.40), "hair": Color(0.14, 0.11, 0.09), "hat": "top"}


func arm_reach(shoulder: Vector2, hand: Vector2, l1: float, l2: float) -> Vector2:
	# the actual hand position after clamping the target to the arm's length, so a
	# scene can place a held prop exactly where the clamped hand ends up (no drift)
	var to := hand - shoulder
	var d := to.length()
	var maxr := (l1 + l2) * 0.97
	return shoulder + to / d * maxr if d > maxr else hand


func draw_arm_s(shoulder: Vector2, hand: Vector2, bend: float, skin: Color, sleeve: Color, l1: float, l2: float, w: float) -> void:
	# clamp the target within reach so the arm never stretches into a noodle, then
	# bend with bones scaled to the reach (matching the play figure's natural elbow)
	var h2 := arm_reach(shoulder, hand, l1, l2)
	var reach := (h2 - shoulder).length()
	var bone := maxf(l1 * 0.62, reach * 0.56)
	var elbow := solve_elbow(shoulder, h2, bone, bone, bend)
	var wrist := h2 + (elbow - h2).normalized() * w * 0.6
	draw_capsule(shoulder, elbow, w * 2.6, w * 2.0, sleeve)
	draw_capsule(elbow, wrist, w * 1.9, w * 1.4, skin)
	draw_circle(elbow, w * 1.0, sleeve)
	draw_circle(h2, w * 1.2, skin)


func reach_hand(feet: Vector2, sc: float, side: float, off: Vector2) -> Vector2:
	# a hand position guaranteed within a draw_person figure's arm reach, so a held
	# prop placed at the same point stays in the hand (side +1 right, -1 left)
	var sh := Vector2(feet.x + side * 22.0 * sc, feet.y - 112.0 * sc)
	var maxr := 80.0 * sc
	if off.length() > maxr:
		off = off.normalized() * maxr
	return sh + off


func draw_person(pos: Vector2, sc: float, pal: Dictionary, lhand = null, rhand = null, mood: int = 0) -> void:
	# a repositionable, rescalable version of the stage figure, so scenes can stage
	# two or three people at once. pos is the FEET, the figure grows upward from it.
	var breathe := sin(float(cine_tick) * 0.05 + pos.x * 0.02) * 1.4 * sc
	var skin: Color = pal.get("skin", Color(0.87, 0.64, 0.45))
	var coat: Color = pal["coat"]
	var coat_dk: Color = pal["coat_dk"]
	var trouser: Color = pal.get("trouser", coat_dk)
	var hair: Color = pal.get("hair", Color(0.25, 0.15, 0.1))

	var hipY := pos.y - 58.0 * sc
	var shY := pos.y - 112.0 * sc + breathe
	var headC := Vector2(pos.x, pos.y - 146.0 * sc + breathe)
	var hr := 17.0 * sc

	var lh: Vector2 = lhand if lhand != null else Vector2(pos.x - 34.0 * sc, hipY - 4.0 * sc)
	var rh: Vector2 = rhand if rhand != null else Vector2(pos.x + 34.0 * sc, hipY - 4.0 * sc)

	# legs
	draw_colored_polygon(PackedVector2Array([
		Vector2(pos.x - 20.0 * sc, hipY), Vector2(pos.x - 3.0 * sc, hipY),
		Vector2(pos.x - 6.0 * sc, pos.y), Vector2(pos.x - 19.0 * sc, pos.y)]), trouser)
	draw_colored_polygon(PackedVector2Array([
		Vector2(pos.x + 3.0 * sc, hipY), Vector2(pos.x + 20.0 * sc, hipY),
		Vector2(pos.x + 19.0 * sc, pos.y), Vector2(pos.x + 6.0 * sc, pos.y)]), trouser)
	fill_ellipse(Vector2(pos.x - 15.0 * sc, pos.y), 12.0 * sc, 5.0 * sc, Color(0.18, 0.11, 0.08))
	fill_ellipse(Vector2(pos.x + 15.0 * sc, pos.y), 12.0 * sc, 5.0 * sc, Color(0.18, 0.11, 0.08))

	# torso / coat
	draw_colored_polygon(PackedVector2Array([
		Vector2(pos.x - 24.0 * sc, shY), Vector2(pos.x + 24.0 * sc, shY),
		Vector2(pos.x + 20.0 * sc, hipY + 4.0 * sc), Vector2(pos.x - 20.0 * sc, hipY + 4.0 * sc)]), coat)
	draw_circle(Vector2(pos.x - 24.0 * sc, shY), 10.0 * sc, coat)
	draw_circle(Vector2(pos.x + 24.0 * sc, shY), 10.0 * sc, coat)
	# a warm accent placket down the front
	var accent: Color = pal.get("accent", coat_dk)
	draw_colored_polygon(PackedVector2Array([
		Vector2(pos.x - 6.0 * sc, shY + 6.0 * sc), Vector2(pos.x + 6.0 * sc, shY + 6.0 * sc),
		Vector2(pos.x + 8.0 * sc, hipY), Vector2(pos.x - 8.0 * sc, hipY)]), accent)

	# arms reach to the hands
	draw_arm_s(Vector2(pos.x - 22.0 * sc, shY), lh, 1.0, skin, coat, 40.0 * sc, 44.0 * sc, 6.5 * sc)
	draw_arm_s(Vector2(pos.x + 22.0 * sc, shY), rh, -1.0, skin, coat, 40.0 * sc, 44.0 * sc, 6.5 * sc)

	# neck, head, hair, face
	draw_colored_polygon(PackedVector2Array([
		Vector2(pos.x - 7.0 * sc, headC.y + hr - 3.0), Vector2(pos.x + 7.0 * sc, headC.y + hr - 3.0),
		Vector2(pos.x + 9.0 * sc, shY + 4.0), Vector2(pos.x - 9.0 * sc, shY + 4.0)]), skin)
	draw_circle(headC, hr, skin)
	if pal.get("shawl", false):
		# an old street juggler's shawl and hood
		draw_circle(headC + Vector2(0, -2.0 * sc), hr + 3.0 * sc, hair)
		draw_circle(headC, hr, skin)
		draw_colored_polygon(PackedVector2Array([
			Vector2(pos.x - 30.0 * sc, shY + 4.0), Vector2(pos.x + 30.0 * sc, shY + 4.0),
			Vector2(pos.x + 22.0 * sc, shY + 30.0 * sc), Vector2(pos.x - 22.0 * sc, shY + 30.0 * sc)]), pal["coat_dk"])
	else:
		draw_circle(headC + Vector2(0, -hr * 0.5), hr, hair)   # hair cap
		draw_circle(headC + Vector2(0, hr * 0.35), hr, skin)   # face lower half back over
	if String(pal.get("hat", "none")) == "top":
		draw_rect(Rect2(headC.x - hr - 3.0 * sc, headC.y - hr - 22.0 * sc, (hr + 3.0 * sc) * 2.0, 6.0 * sc), Color(0.08, 0.07, 0.1))
		draw_rect(Rect2(headC.x - hr * 0.8, headC.y - hr - 22.0 * sc, hr * 1.6, 22.0 * sc), Color(0.10, 0.09, 0.12))
		draw_rect(Rect2(headC.x - hr * 0.8, headC.y - hr - 8.0 * sc, hr * 1.6, 3.0 * sc), accent)
	draw_person_face(headC, hr, mood)


func draw_person_face(headC: Vector2, hr: float, mood: int) -> void:
	var eye := Color(0.16, 0.10, 0.08)
	draw_circle(headC + Vector2(-hr * 0.35, -hr * 0.05), hr * 0.15, eye)
	draw_circle(headC + Vector2(hr * 0.35, -hr * 0.05), hr * 0.15, eye)
	var my := headC.y + hr * 0.45
	var w := hr * 0.4
	var mouth := PackedVector2Array([Vector2(headC.x - w, my), Vector2(headC.x + w, my)])
	if mood == 1:
		mouth = PackedVector2Array([Vector2(headC.x - w, my - 1.5), Vector2(headC.x, my + 3.0), Vector2(headC.x + w, my - 1.5)])
	elif mood == -1:
		mouth = PackedVector2Array([Vector2(headC.x - w, my + 2.0), Vector2(headC.x, my - 2.0), Vector2(headC.x + w, my + 2.0)])
	draw_polyline(mouth, Color(0.45, 0.20, 0.16), 2.0)


func draw_simple_hand(pos: Vector2, close: float, inward: float, sc: float) -> void:
	draw_circle(pos, 10.0 * sc, Color(0.86, 0.62, 0.42))
	var spread := lerpf(0.5, 0.12, close)
	var flen := lerpf(13.0, 7.0, close) * sc
	var base_ang := -PI / 2.0 + close * inward * 0.6
	for f in 4:
		var ang := base_ang + (float(f) - 1.5) * spread
		draw_line(pos, pos + Vector2(cos(ang), sin(ang)) * flen, Color(0.84, 0.60, 0.40), 3.8 * sc)


# --- juggle demonstration (tutorials, and juggling story figures) -------------

func demo_juggle(center: Vector2, sc: float, count: int) -> Dictionary:
	# a small closed-form cascade: each ball rides a crossing arc, staggered in
	# phase, so 1 ball ping-pongs, 2 balls exchange, 3+ weave a real cascade
	var hl := center + Vector2(-56.0 * sc, 42.0 * sc)
	var hr := center + Vector2(56.0 * sc, 42.0 * sc)
	var T := 52.0
	var peak := 104.0 * sc
	var t := float(cine_tick)
	var out: Array = []
	for i in count:
		var phase := fposmod(t + float(i) * (T * 2.0 / float(maxi(1, count))), T * 2.0)
		var seg := 0 if phase < T else 1
		var u := (phase - float(seg) * T) / T
		var frm := hl if seg == 0 else hr
		var to := hr if seg == 0 else hl
		var p := frm.lerp(to, u)
		p.y -= peak * 4.0 * u * (1.0 - u)
		out.append({"pos": p, "col": ball_color(i)})
	return {"balls": out, "hl": hl, "hr": hr, "peak": peak}


# --- the egg-break effect (shell shards fly, a yolk splats and spreads) --------

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


func step_effects() -> void:
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


func draw_popups(font: Font) -> void:
	for p in popups:
		var age := tick - int(p["born"])
		var a := clampf(1.0 - float(age) / 46.0, 0.0, 1.0)
		var pos: Vector2 = p["pos"] + Vector2(0, -float(age) * 0.6)
		var c: Color = p["col"]
		c.a = a
		draw_string(font, pos, p["text"], HORIZONTAL_ALIGNMENT_CENTER, 120, 18, c)


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
	var gy := s.y * 0.66
	draw_gradient_v(Rect2(0, 0, s.x, gy), Color(0.13, 0.15, 0.28), Color(0.72, 0.46, 0.32), 26)
	draw_circle(Vector2(s.x * 0.70, gy - 26.0), 62.0, Color(1.0, 0.72, 0.4, 0.22))
	draw_circle(Vector2(s.x * 0.70, gy - 26.0), 34.0, Color(1.0, 0.84, 0.52, 0.45))
	draw_stars(s, 22, 0.3)
	draw_gradient_v(Rect2(0, gy, s.x, s.y - gy), Color(0.22, 0.28, 0.16), Color(0.07, 0.10, 0.06), 18)
	draw_tree(Vector2(s.x * 0.18, gy), 1.05)
	draw_house(Vector2(s.x * 0.74, gy), 158.0, 128.0)
	draw_fence(s, gy - 4.0, s.x * 0.30, s.x * 0.64)
	draw_grass(s, gy)
	draw_dust(s, 18, Color(1.0, 0.85, 0.55))


func ext_street(s: Vector2) -> void:
	var gy := s.y * 0.72
	draw_gradient_v(Rect2(0, 0, s.x, s.y), Color(0.04, 0.05, 0.12), Color(0.13, 0.10, 0.15), 26)
	draw_moon(Vector2(s.x * 0.82, s.y * 0.18), 24.0)
	draw_stars(s, 30, 0.42)
	draw_city_row(s, gy)
	draw_rect(Rect2(0, gy, s.x, s.y - gy), Color(0.09, 0.08, 0.10))
	draw_streetlamp(Vector2(s.x * 0.32, gy), gy)
	draw_hat_prop(Vector2(s.x * 0.32 + 46.0, gy - 2.0))
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
		var a := 0.3 + 0.5 * sin(float(cine_tick) * 0.04 + seed)
		draw_circle(Vector2(x, y), 1.3, Color(1, 1, 1, clampf(a, 0.05, 0.7)))


func draw_moon(pos: Vector2, r: float) -> void:
	draw_circle(pos, r * 1.8, Color(0.9, 0.9, 0.8, 0.08))
	draw_circle(pos, r, Color(0.96, 0.95, 0.86, 0.9))
	draw_circle(pos + Vector2(r * 0.4, -r * 0.2), r * 0.85, Color(0.9, 0.88, 0.78, 0.2))


func draw_house(base: Vector2, w: float, h: float) -> void:
	draw_rect(Rect2(base.x - w * 0.5, base.y - h, w, h), Color(0.10, 0.09, 0.11))
	draw_colored_polygon(PackedVector2Array([
		Vector2(base.x - w * 0.6, base.y - h), Vector2(base.x + w * 0.6, base.y - h), Vector2(base.x, base.y - h - h * 0.5)]), Color(0.07, 0.06, 0.08))
	var flick := 0.7 + 0.3 * sin(float(cine_tick) * 0.05)
	var wx := base.x - w * 0.20
	var wy := base.y - h * 0.66
	draw_circle(Vector2(wx + w * 0.11, wy + h * 0.14), w * 0.3, Color(1.0, 0.7, 0.3, 0.12 * flick))
	draw_rect(Rect2(wx, wy, w * 0.22, h * 0.30), Color(1.0, 0.78, 0.4, 0.92 * flick))
	draw_rect(Rect2(wx, wy, w * 0.22, h * 0.30), Color(0.2, 0.12, 0.06), false, 2.0)
	draw_line(Vector2(wx + w * 0.11, wy), Vector2(wx + w * 0.11, wy + h * 0.30), Color(0.2, 0.12, 0.06), 1.5)


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
		draw_line(Vector2(x, y + 6.0), Vector2(x + sin(float(cine_tick) * 0.02 + x) * 2.0, y + 6.0 - hgt), col, 2.0)
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
		var on := ((i + int(cine_tick / 12)) % 2) == 0
		var bx := center.x - w * 0.5 + w * (float(i) + 0.5) / float(n)
		var col := Color(1.0, 0.85, 0.4) if on else Color(0.4, 0.3, 0.2)
		draw_circle(Vector2(bx, center.y - h * 0.5 - 4.0), 2.5, col)
		draw_circle(Vector2(bx, center.y + h * 0.5 + 4.0), 2.5, col)
	draw_string(ThemeDB.fallback_font, Vector2(center.x - w * 0.5, center.y + 6.0), "TONIGHT", HORIZONTAL_ALIGNMENT_CENTER, w, 18, Color(1.0, 0.85, 0.45))


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
	var fl := sin(float(cine_tick) * 0.1) * 6.0
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
		var fl := 0.7 + 0.3 * sin(float(cine_tick) * 0.08 + float(i))
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
	var fl := sin(float(cine_tick) * 0.12 + top.x) * 5.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(top.x + 2.0, top.y), Vector2(top.x + 40.0, top.y + 6.0 + fl), Vector2(top.x + 40.0, top.y + 30.0 + fl), Vector2(top.x + 2.0, top.y + 30.0)]), col)


func draw_spotlight_cone(s: Vector2, cx: float, strength: float) -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx, -30.0), Vector2(cx - 300.0, s.y * 0.86), Vector2(cx + 300.0, s.y * 0.86)]), Color(1.0, 0.85, 0.55, strength))


func draw_shadow(feet: Vector2, w: float) -> void:
	fill_ellipse(feet, w * 0.5, w * 0.16, Color(0, 0, 0, 0.3))


func draw_silhouette(feet: Vector2, sc: float, col: Color) -> void:
	var shY := feet.y - 108.0 * sc
	draw_colored_polygon(PackedVector2Array([
		Vector2(feet.x - 16.0 * sc, shY), Vector2(feet.x + 16.0 * sc, shY),
		Vector2(feet.x + 12.0 * sc, feet.y), Vector2(feet.x - 12.0 * sc, feet.y)]), col)
	draw_circle(Vector2(feet.x, shY - 16.0 * sc), 12.0 * sc, col)


func draw_curtain(s: Vector2) -> void:
	draw_gradient_v(Rect2(0, 0, s.x, s.y * 0.64), Color(0.16, 0.03, 0.05), Color(0.07, 0.01, 0.02), 18)
	var n := 14
	for i in n:
		var x := s.x * float(i) / float(n)
		var shade := 0.15 + 0.06 * sin(float(i) * 1.7)
		draw_rect(Rect2(x, 0, s.x / float(n) * 0.6, s.y * 0.62), Color(shade + 0.06, 0.03, 0.05))
		draw_rect(Rect2(x + s.x / float(n) * 0.6, 0, s.x / float(n) * 0.4, s.y * 0.62), Color(shade, 0.02, 0.04))
	draw_rect(Rect2(0, 0, s.x, 40.0), Color(0.30, 0.06, 0.08))
	draw_line(Vector2(0, 40.0), Vector2(s.x, 40.0), Color(0.85, 0.65, 0.3), 2.0)


func draw_scoreboard(s: Vector2) -> void:
	var bw := s.x * 0.42
	var bx := s.x * 0.5 - bw * 0.5
	var by := s.y * 0.14
	draw_rect(Rect2(bx, by, bw, 70.0), Color(0.05, 0.06, 0.10))
	draw_rect(Rect2(bx, by, bw, 70.0), Color(0.5, 0.7, 1.0, 0.5), false, 2.0)
	var f := ThemeDB.fallback_font
	draw_string(f, Vector2(bx + 20.0, by + 30.0), "SILVIO   98.4", HORIZONTAL_ALIGNMENT_LEFT, bw - 40.0, 20, Color(0.7, 0.85, 1.0))
	draw_string(f, Vector2(bx + 20.0, by + 56.0), "MILO     97.9", HORIZONTAL_ALIGNMENT_LEFT, bw - 40.0, 20, Color(1.0, 0.88, 0.55))


func draw_ring_interior(s: Vector2) -> void:
	draw_gradient_v(Rect2(0, 0, s.x, s.y), Color(0.14, 0.07, 0.05), Color(0.05, 0.03, 0.03), 20)
	var gy := s.y * 0.80
	fill_ellipse(Vector2(s.x * 0.5, gy), s.x * 0.42, 46.0, Color(0.55, 0.34, 0.18, 0.5))
	fill_ellipse(Vector2(s.x * 0.5, gy), s.x * 0.30, 32.0, Color(0.8, 0.55, 0.28, 0.4))
	draw_lantern_string(Vector2(s.x * 0.06, s.y * 0.22), Vector2(s.x * 0.94, s.y * 0.24))


# --- story scene tableaux -----------------------------------------------------

func scene_backyard(s: Vector2, stage: int) -> void:
	draw_venue_exterior(s, 0)
	var fy := s.y * 0.80
	match stage:
		0:
			# Bruna offers the three balls in her outstretched right hand; Milo stands
			# close, ready. The balls sit IN her hand (reach_hand keeps the arm honest).
			var bfeet := Vector2(s.x * 0.42, fy)
			var mfeet := Vector2(s.x * 0.60, fy)
			draw_shadow(bfeet, 70.0)
			draw_shadow(mfeet, 66.0)
			var bob := sin(float(cine_tick) * 0.06) * 3.0
			var bhand := reach_hand(bfeet, 1.05, 1.0, Vector2(66.0, -8.0 + bob))
			draw_person(bfeet, 1.05, bruna_pal(), null, bhand, 1)
			draw_person(mfeet, 1.0, milo_pal(0), reach_hand(mfeet, 1.0, -1.0, Vector2(-40.0, 6.0)), null, 0)
			for i in 3:
				draw_ball_shape(bhand + Vector2(-6.0 + float(i) * 6.0, -7.0 - float(i) * 5.0), ball_color(i), 0.95)
		1:
			# now the balls are in Milo's hand, Bruna beside him with a nod
			var bfeet := Vector2(s.x * 0.40, fy)
			var mfeet := Vector2(s.x * 0.58, fy)
			draw_shadow(bfeet, 76.0)
			draw_shadow(mfeet, 76.0)
			var mhand := reach_hand(mfeet, 1.15, -1.0, Vector2(-58.0, -14.0))
			draw_person(bfeet, 1.1, bruna_pal(), null, reach_hand(bfeet, 1.1, 1.0, Vector2(58.0, -6.0)), 1)
			draw_person(mfeet, 1.15, milo_pal(0), mhand, null, 0)
			for i in 3:
				draw_ball_shape(mhand + Vector2(float(i) * 5.0 - 5.0, -6.0 - float(i) * 5.0), ball_color(i), 1.0)
		2:
			draw_shadow(Vector2(s.x * 0.5, fy), 80.0)
			var u := fposmod(float(cine_tick) / 70.0, 1.0)
			var frm := Vector2(s.x * 0.5 + 40.0, fy - 120.0)
			var to := Vector2(s.x * 0.5 - 40.0, fy - 120.0)
			var bp := frm.lerp(to, u)
			bp.y -= 150.0 * 4.0 * u * (1.0 - u)
			draw_person(Vector2(s.x * 0.5, fy), 1.2, milo_pal(0), Vector2(s.x * 0.5 - 46.0, fy - 118.0), Vector2(s.x * 0.5 + 46.0, fy - 140.0), 0)
			draw_ball_shape(bp, ball_color(0), 1.1)
			draw_silhouette(Vector2(s.x * 0.14, fy), 0.8, Color(0.06, 0.05, 0.06))
		_:
			draw_shadow(Vector2(s.x * 0.52, fy), 80.0)
			var dj := demo_juggle(Vector2(s.x * 0.52, s.y * 0.5), 1.2, 3)
			draw_person(Vector2(s.x * 0.52, fy), 1.2, milo_pal(0), dj["hl"], dj["hr"], 1)
			for b in dj["balls"]:
				draw_ball_shape(b["pos"], b["col"], 1.15)
			draw_person(Vector2(s.x * 0.16, fy), 0.9, bruna_pal(), null, null, 1)


func scene_street(s: Vector2, stage: int) -> void:
	draw_venue_exterior(s, 1)
	var fy := s.y * 0.80
	match stage:
		0:
			draw_silhouette(Vector2(s.x * 0.78, fy), 0.9, Color(0.06, 0.05, 0.07))
		1:
			draw_shadow(Vector2(s.x * 0.5, fy), 74.0)
			var dj := demo_juggle(Vector2(s.x * 0.5, s.y * 0.5), 1.1, 3)
			draw_person(Vector2(s.x * 0.5, fy), 1.1, milo_pal(1), dj["hl"], dj["hr"], 0)
			for b in dj["balls"]:
				draw_ball_shape(b["pos"], b["col"], 1.1)
			draw_silhouette(Vector2(s.x * 0.74, fy), 0.9, Color(0.06, 0.05, 0.07))
		_:
			draw_shadow(Vector2(s.x * 0.5, fy), 74.0)
			var dj := demo_juggle(Vector2(s.x * 0.5, s.y * 0.5), 1.1, 3)
			draw_person(Vector2(s.x * 0.5, fy), 1.1, milo_pal(1), dj["hl"], dj["hr"], 1)
			for b in dj["balls"]:
				draw_ball_shape(b["pos"], b["col"], 1.1)
			draw_silhouette(Vector2(s.x * 0.72, fy), 0.9, Color(0.06, 0.05, 0.07))
			# a coin arcs down into the hat by the lamp
			var u := fposmod(float(cine_tick) / 90.0, 1.0)
			var frm := Vector2(s.x * 0.72, fy - 120.0)
			var to := Vector2(s.x * 0.32 + 46.0, fy - 2.0)
			var cp := frm.lerp(to, u)
			cp.y -= 120.0 * 4.0 * u * (1.0 - u)
			fill_ellipse(cp, 6.0, 6.0, Color(1.0, 0.84, 0.4))
			draw_circle(cp + Vector2(-2, -2), 2.0, Color(1.0, 0.95, 0.7))


func scene_theatre(s: Vector2, stage: int) -> void:
	match stage:
		0:
			draw_venue_exterior(s, 2)
		1:
			draw_curtain(s)
			var fy := s.y * 0.82
			draw_rect(Rect2(0, s.y * 0.62, s.x, s.y - s.y * 0.62), Color(0.14, 0.08, 0.06))
			draw_spotlight_cone(s, s.x * 0.55, 0.14)
			draw_shadow(Vector2(s.x * 0.55, fy), 80.0)
			draw_person(Vector2(s.x * 0.55, fy), 1.15, silvio_pal(), Vector2(s.x * 0.55 - 20.0, fy - 90.0), Vector2(s.x * 0.55 + 78.0, fy - 60.0), 1)
			draw_silhouette(Vector2(s.x * 0.08, fy - 6.0), 0.85, Color(0.04, 0.03, 0.04))
			draw_rect(Rect2(0, 0, s.x * 0.10, s.y), Color(0.10, 0.02, 0.03))
		_:
			draw_gradient_v(Rect2(0, 0, s.x, s.y), Color(0.06, 0.04, 0.05), Color(0.02, 0.01, 0.02), 18)
			var fy := s.y * 0.82
			draw_colored_polygon(PackedVector2Array([
				Vector2(s.x * 0.72, 0), Vector2(s.x, 0), Vector2(s.x, s.y), Vector2(s.x * 0.80, s.y)]), Color(1.0, 0.82, 0.45, 0.10))
			draw_shadow(Vector2(s.x * 0.4, fy), 78.0)
			draw_person(Vector2(s.x * 0.4, fy), 1.2, milo_pal(2), null, null, 0)


func scene_circus(s: Vector2, stage: int) -> void:
	match stage:
		0:
			draw_venue_exterior(s, 3)
		1:
			draw_ring_interior(s)
			var fy := s.y * 0.82
			for k in 5:
				draw_silhouette(Vector2(s.x * (0.16 + 0.17 * float(k)), fy + 6.0), 0.7, Color(0.05, 0.04, 0.04))
			draw_shadow(Vector2(s.x * 0.5, fy), 74.0)
			draw_person(Vector2(s.x * 0.5, fy), 1.1, milo_pal(3), null, null, 1)
			var gl := 0.6 + 0.4 * sin(float(cine_tick) * 0.2)
			draw_knife(Vector2(s.x * 0.5, s.y * 0.34), float(cine_tick) * 0.1, 1.6)
			draw_circle(Vector2(s.x * 0.5, s.y * 0.34), 10.0, Color(1.0, 1.0, 1.0, 0.3 * gl))
		_:
			draw_ring_interior(s)
			var fy := s.y * 0.82
			for k in 5:
				draw_silhouette(Vector2(s.x * (0.14 + 0.18 * float(k)), fy + 8.0), 0.66, Color(0.05, 0.04, 0.04))
			draw_shadow(Vector2(s.x * 0.5, fy), 76.0)
			var dj := demo_juggle(Vector2(s.x * 0.5, s.y * 0.5), 1.15, 3)
			draw_person(Vector2(s.x * 0.5, fy), 1.15, milo_pal(3), dj["hl"], dj["hr"], 1)
			for b in dj["balls"]:
				draw_knife(b["pos"], float(cine_tick) * 0.12, 1.4)


func scene_champ(s: Vector2, stage: int) -> void:
	match stage:
		0:
			draw_venue_exterior(s, 4)
		1:
			draw_gradient_v(Rect2(0, 0, s.x, s.y), Color(0.06, 0.08, 0.14), Color(0.03, 0.04, 0.07), 18)
			draw_scoreboard(s)
			var fy := s.y * 0.84
			draw_shadow(Vector2(s.x * 0.56, fy), 80.0)
			# Silvio hoists the trophy
			draw_person(Vector2(s.x * 0.56, fy), 1.15, silvio_pal(), Vector2(s.x * 0.56 - 40.0, fy - 168.0), Vector2(s.x * 0.56 + 40.0, fy - 168.0), 1)
			draw_colored_polygon(PackedVector2Array([
				Vector2(s.x * 0.56 - 12.0, fy - 176.0), Vector2(s.x * 0.56 + 12.0, fy - 176.0),
				Vector2(s.x * 0.56 + 6.0, fy - 196.0), Vector2(s.x * 0.56 - 6.0, fy - 196.0)]), Color(1.0, 0.85, 0.4))
			draw_rect(Rect2(s.x * 0.56 - 4.0, fy - 176.0, 8.0, 10.0), Color(1.0, 0.85, 0.4))
			draw_shadow(Vector2(s.x * 0.3, fy), 66.0)
			draw_person(Vector2(s.x * 0.3, fy), 0.95, milo_pal(4), null, null, 0)
		3:
			# Silvio's fall: he lunges after a torch his gear threw wrong, and misses
			draw_gradient_v(Rect2(0, 0, s.x, s.y), Color(0.06, 0.08, 0.14), Color(0.03, 0.04, 0.07), 18)
			draw_scoreboard(s)
			var fy := s.y * 0.84
			draw_shadow(Vector2(s.x * 0.5, fy), 80.0)
			var rh := reach_hand(Vector2(s.x * 0.5, fy), 1.2, 1.0, Vector2(66.0, -78.0))
			draw_person(Vector2(s.x * 0.5, fy), 1.2, silvio_pal(), null, rh, -1)
			var u := fposmod(float(cine_tick) / 66.0, 1.0)
			var fp := Vector2(s.x * 0.5 + 120.0, s.y * 0.26 + u * u * 320.0)
			draw_torch(fp, float(cine_tick) * 0.22, 1.5)
		_:
			draw_gradient_v(Rect2(0, 0, s.x, s.y), Color(0.06, 0.08, 0.14), Color(0.03, 0.04, 0.07), 18)
			draw_scoreboard(s)
			var fy := s.y * 0.84
			draw_shadow(Vector2(s.x * 0.5, fy), 80.0)
			draw_person(Vector2(s.x * 0.5, fy), 1.2, milo_pal(4), null, null, 0)


func scene_arena(s: Vector2, stage: int) -> void:
	match stage:
		0:
			draw_venue_exterior(s, 5)
		3:
			# the finale: five torches, the biggest crowd, Silvio seated in the stands
			draw_gradient_v(Rect2(0, 0, s.x, s.y), Color(0.03, 0.03, 0.08), Color(0.06, 0.04, 0.10), 18)
			var gy := s.y * 0.84
			for i in 130:
				var seed := float(i) * 13.7
				var x := s.x * 0.5 + (fposmod(sin(seed) * 99.0, 1.0) - 0.5) * s.x * 0.94
				var y := gy - fposmod(cos(seed) * 71.0, 1.0) * s.y * 0.34 - 18.0
				var a := 0.35 + 0.45 * sin(float(cine_tick) * 0.05 + seed)
				draw_circle(Vector2(x, y), 1.7, Color(1.0, 0.82, 0.52, clampf(a, 0.12, 0.8)))
			draw_silhouette(Vector2(s.x * 0.13, gy - 4.0), 0.6, Color(0.05, 0.04, 0.05))   # Silvio, watching
			draw_spotlight_cone(s, s.x * 0.5, 0.17)
			draw_shadow(Vector2(s.x * 0.5, gy), 90.0)
			var djf := demo_juggle(Vector2(s.x * 0.5, s.y * 0.46), 1.3, 5)
			draw_person(Vector2(s.x * 0.5, gy), 1.3, milo_pal(5), djf["hl"], djf["hr"], 1)
			for b in djf["balls"]:
				draw_torch(b["pos"], float(cine_tick) * 0.16, 1.4)
			draw_circle(Vector2(s.x * 0.5, s.y * 0.46), 240.0, Color(1.0, 0.9, 0.6, 0.07))
		_:
			draw_gradient_v(Rect2(0, 0, s.x, s.y), Color(0.03, 0.03, 0.08), Color(0.06, 0.04, 0.10), 18)
			var gy := s.y * 0.84
			for i in 90:
				var seed := float(i) * 13.7
				var x := s.x * 0.5 + (fposmod(sin(seed) * 99.0, 1.0) - 0.5) * s.x * 0.9
				var y := gy - fposmod(cos(seed) * 71.0, 1.0) * s.y * 0.30 - 20.0
				var a := 0.3 + 0.4 * sin(float(cine_tick) * 0.05 + seed)
				draw_circle(Vector2(x, y), 1.6, Color(1.0, 0.8, 0.5, clampf(a, 0.1, 0.7)))
			draw_spotlight_cone(s, s.x * 0.5, 0.12 + (0.05 if stage == 2 else 0.0))
			draw_shadow(Vector2(s.x * 0.5, gy), 84.0)
			var dj := demo_juggle(Vector2(s.x * 0.5, s.y * 0.48), 1.25, 5)
			draw_person(Vector2(s.x * 0.5, gy), 1.25, milo_pal(5), dj["hl"], dj["hr"], 1)
			for b in dj["balls"]:
				draw_ball_shape(b["pos"], b["col"], 1.2)
			if stage == 2:
				draw_circle(Vector2(s.x * 0.5, s.y * 0.48), 200.0, Color(1.0, 0.9, 0.6, 0.05))


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
	# dev trick preview: kick off a Spin whenever the pattern is full and cooled down
	if _demo_trick and balls_airborne() >= 2 and tick >= trick_ready and tick >= 40:
		spin_until = tick + SPIN_TICKS
		spin_scored = false
		trick_ready = tick + TRICK_COOLDOWN
	# metronome: every beat, release one ball from a hand that actually holds one.
	# This can never desync because it only throws real held balls.
	if tick >= 24 and tick % DEMO_BEAT == 0:
		var h := _demo_next
		if stack(h).is_empty():
			h = other(h)
		if not stack(h).is_empty():
			if _demo_trick:
				trick_armed = TR_HIGH if (tick / DEMO_BEAT) % 2 == 0 else TR_BTB
			do_throw(h, 7)
			_demo_next = other(h)


func _capture_and_quit() -> void:
	var img := get_viewport().get_texture().get_image()
	if img != null and _shot_path != "":
		img.save_png(_shot_path)
	get_tree().quit()
