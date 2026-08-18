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
	if failed == 0:
		print("TossaBalance: venue curve and sustained-run goal gate verified")
	quit(failed)
