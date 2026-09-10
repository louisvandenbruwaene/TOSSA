extends SceneTree
const ROUTINE = preload("res://scripts/TossaRoutine.gd")
class RoutineGame extends "res://Game.gd":
	var awarded := 0
	func routine_available() -> bool:
		return true
	func add_xp(amount: int) -> void:
		awarded += amount
	func warm_room(_amount: float) -> void:
		pass
	func set_trick_msg(_text: String) -> void:
		pass
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _init() -> void:
	var state := ROUTINE.fresh()
	for event in ["spin", "finish", "height"]:
		state = ROUTINE.advance(state, event)
	check(state == ROUTINE.fresh(), "A routine cannot skip its opening catches")
	for i in 6: state = ROUTINE.advance(state, "catch")
	check(state["phase"] == 1, "Six clean catches open the height step")
	check(ROUTINE.advance(state, "edge") == ROUTINE.fresh(), "An edge resets the sequence")
	var game := RoutineGame.new()
	game.num_balls = 3
	game.tick = 100
	for i in 3:
		var ball = game.Ball.new()
		ball.state = game.STATE_FLIGHT
		ball.launch_tick = 100
		ball.land_tick = 300
		game.balls.append(ball)
	for repeat in 2:
		for i in 6: game.routine_event("catch")
		game.routine_event("finish")
		check(game.awarded == repeat * 20, "An early finish earns no routine XP")
		game.routine_event("height")
		game.routine_event("spin")
		check(game.routine_progress["phase"] == 2, "Spin requires the high throw still in flight")
		game.balls[0].over_tap = 0.5
		game.balls[1].state = game.STATE_HAND
		game.routine_event("spin")
		check(game.routine_progress["phase"] == 2, "Spin requires every prop airborne")
		game.balls[1].state = game.STATE_FLIGHT
		game.routine_event("spin")
		for i in 6: game.routine_event("catch")
		check(game.routine_progress["phase"] == 4, "The high spin needs a clean recovery")
		game.routine_event("finish")
		game.routine_event("finish")
		check(game.awarded == 20, "Routine rewards are capped at 20 XP per run")
		game.routine_event("miss")
		game.balls[0].over_tap = 0.0
	game.free()
	if failures == 0: print("TossaRoutine: sequence order, airborne requirements, reset and reward cap verified")
	quit(failures)
