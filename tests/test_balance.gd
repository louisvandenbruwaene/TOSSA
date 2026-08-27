## Locks the venue curve and the sustained-run gate to the intended progression.
extends SceneTree

const TOSSA_BALANCE = preload("res://scripts/TossaBalance.gd")
const TOSSA_CATALOG = preload("res://scripts/TossaCatalog.gd")
const PROP_STRENGTH := [1.0, 1.0, 3.0, 4.0, 6.0, 8.0, 13.0]

# The expected house builds from Game.gd's live ladder. These inputs make the scale contract
# legible here: modest balls at the Backyard, eleven chainsaws at the Midnight Show.
const BUILDS := [
	{"n": 3, "prop": 0, "pat": 0},
	{"n": 4, "prop": 0, "pat": 1},
	{"n": 5, "prop": 3, "pat": 1},
	{"n": 5, "prop": 4, "pat": 2},
	{"n": 7, "prop": 5, "pat": 2},
	{"n": 9, "prop": 5, "pat": 4},
	{"n": 11, "prop": 6, "pat": 5},
]


func _init() -> void:
	var failed := 0
	var finals: Array[float] = []
	for venue in TOSSA_BALANCE.PERFECT_CATCHES.size():
		var goal_x := TOSSA_BALANCE.weighted_goal(venue, 2, 3.0)
		var b: Dictionary = BUILDS[venue]
		var prop := int(b["prop"])
		var pattern := int(b["pat"])
		finals.append(TOSSA_BALANCE.score_for(goal_x, int(b["n"]),
			float(TOSSA_CATALOG.PROP_SIG[prop]), float(TOSSA_CATALOG.PATTERNS[pattern]["mult"]),
			PROP_STRENGTH[prop]))
		if venue > 0 and finals[venue] <= finals[venue - 1]:
			push_error("Every venue's expected final goal must exceed the previous venue.")
			failed += 1
	if finals[0] > 5000.0:
		push_error("The Backyard final goal must remain a small, readable score.")
		failed += 1
	if finals[-1] < 1.0e20 or log(finals[-1] / finals[0]) / log(10.0) < 20.0:
		push_error("The Midnight Show must reach enormous scores over twenty orders above the Backyard.")
		failed += 1
	var first_goal := TOSSA_BALANCE.weighted_goal(0, 0, 3.0)
	if TOSSA_BALANCE.goal_ready(1.0e100, 1.0, true, 3.0, first_goal):
		push_error("One Perfect catch must never open a goal, even with an enormous trick score.")
		failed += 1
	var run_floor := TOSSA_BALANCE.run_required(first_goal)
	if TOSSA_BALANCE.run_ready(run_floor - 0.01, first_goal) \
			or not TOSSA_BALANCE.run_ready(run_floor, first_goal):
		push_error("The clean-run gate must open exactly at its documented 75%% boundary.")
		failed += 1
	if TOSSA_BALANCE.goal_ready(0.99, 1.0, true, run_floor, first_goal) \
			or TOSSA_BALANCE.goal_ready(1.0, 1.0, false, run_floor, first_goal) \
			or not TOSSA_BALANCE.goal_ready(1.0, 1.0, true, run_floor, first_goal):
		push_error("A goal must require score, clock, and sustained run together.")
		failed += 1
	# Three tap-height balls produce 3 / (84 / 120) catches a second. Each complete
	# exchange costs one stamina to throw plus 0.4 to catch. A fresh career must survive
	# the Backyard's 30-second final clock without requiring gear or an imperfect act.
	var backyard_perfect_cost := 30.0 * (3.0 / (84.0 / 120.0)) * 1.4
	if TOSSA_BALANCE.stamina_capacity(0) < backyard_perfect_cost:
		push_error("Starting stamina must cover a perfect Backyard final-goal act.")
		failed += 1
	if not is_equal_approx(TOSSA_BALANCE.stamina_capacity(100), 1000.0):
		push_error("The stamina rebalance must preserve the Endurance-100 cap of 1,000.")
		failed += 1
	if not is_equal_approx(TOSSA_BALANCE.migrate_legacy_stamina(100.0, 0), 200.0) \
			or not is_equal_approx(TOSSA_BALANCE.migrate_legacy_stamina(50.0, 0), 100.0):
		push_error("Old saves must preserve their stamina percentage on the new curve.")
		failed += 1
	# Stat tracks are local buckets, never fractions of the 200-point career cap.
	if not is_zero_approx(TOSSA_BALANCE.goal_bucket_fill(10, 10, 20)) \
			or not is_equal_approx(TOSSA_BALANCE.goal_bucket_fill(15, 10, 20), 0.5) \
			or not is_equal_approx(TOSSA_BALANCE.goal_bucket_fill(20, 10, 20), 1.0) \
			or not is_equal_approx(TOSSA_BALANCE.goal_bucket_fill(150, 150, 150, true), 1.0):
		push_error("Every stat goal bucket must be empty at its start and full at its end.")
		failed += 1
	# THE TRICK FACTOR IS UPSIDE, NOT A LADDER OF ITS OWN. This is the contract the
	# 2026-08-19 rewrite exists to hold: before it, three tricks at the BACKYARD scored
	# 1.26e34 - seven orders of magnitude past the Midnight Show's own final goal - because
	# the whole sum was raised to the power of one-plus-the-number-of-distinct-tricks.
	var btb := float(TOSSA_CATALOG.TRICKS[0]["diff"])
	var high := float(TOSSA_CATALOG.TRICKS[1]["diff"])
	var spin := float(TOSSA_CATALOG.TRICKS[2]["diff"])
	if not is_equal_approx(TOSSA_BALANCE.trick_factor({}), 1.0):
		push_error("A trickless act must score exactly its streaks, with no trick factor.")
		failed += 1
	if TOSSA_BALANCE.trick_factor({spin: 1}) <= 1.0:
		push_error("Landing a trick once must pay something.")
		failed += 1
	# diminishing returns: the tenth landing must be worth strictly less than the first
	var first_gain := TOSSA_BALANCE.trick_factor({spin: 1}) - TOSSA_BALANCE.trick_factor({spin: 0})
	var tenth_gain := TOSSA_BALANCE.trick_factor({spin: 10}) - TOSSA_BALANCE.trick_factor({spin: 9})
	if tenth_gain >= first_gain:
		push_error("Repeating one trick must pay less each time, not the same or more.")
		failed += 1
	# the harder trick pays more for the same number of landings
	if TOSSA_BALANCE.trick_factor({spin: 5}) <= TOSSA_BALANCE.trick_factor({high: 5}):
		push_error("A harder trick must be worth more than an easy one at equal landings.")
		failed += 1
	# ...and the whole factor stays upside rather than a venue of its own
	var everything := {btb: 200, high: 200, spin: 200}
	if TOSSA_BALANCE.trick_factor(everything) > TOSSA_BALANCE.TRICK_FACTOR_CAP + 0.001:
		push_error("The trick factor must never exceed its cap.")
		failed += 1
	# A FULLY FLOURISHED BACKYARD ACT MUST NOT REACH THE NEXT HOUSE'S FINAL GOAL. The
	# ladder's whole meaning is that a venue is climbed by taking more objects up, never by
	# pressing the trick key more often in the room you are already in.
	var backyard_final := finals[0]
	var flourished: float = backyard_final * TOSSA_BALANCE.trick_factor({btb: 50, high: 50, spin: 50})
	if flourished >= finals[1]:
		push_error("Tricks at one venue must not reach the NEXT venue's final goal.")
		failed += 1
	if failed == 0:
		print("TossaBalance: venue curve, sustained-run gate and bounded trick factor verified")
	quit(failed)
