## Result-to-practice navigation uses normal costs and protects special endings.
extends SceneTree
class ReviewGame extends "res://Game.gd":
	var saves := 0
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
		hide()
	func save_progress() -> void:
		saves += 1
	func save_settings() -> void:
		pass
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game := ReviewGame.new()
	root.add_child(game)
	game.game_state = game.ST_PLAY
	game.results_open = true
	game.mode = game.MODE_PERFORM
	game.stamina = 180.0
	game.strength = 20
	game.prop_count[0] = 3
	game.prop_type = 0
	game.num_balls = 3
	game.pattern = game.CASCADE
	game.last_mistake = "Right catch too early"
	game.pending_demo_wall = true
	check(not game.can_practise_result(), "Practice must not bypass a special ending")
	var original_day := game.seg_used
	game.practise_result()
	check(game.seg_used == original_day and game.results_open, "Refused practice must not cost a segment or close results")
	var retry := InputEventKey.new()
	retry.pressed = true
	retry.physical_keycode = KEY_R
	game._input(retry)
	check(game.results_open and game.seg_used == original_day, "Retry must not bypass special endings")
	game.pending_demo_wall = false
	game.sprint_active = true
	check(not game.can_practise_result(), "Sprint cannot escape into practice")
	game.sprint_active = false
	game.practise_result()
	check(game.mode == game.MODE_TRAIN and not game.results_open, "Practice must leave the result panel")
	check(game.seg_used == original_day + 1, "Practice costs exactly one ordinary day segment")
	check(game.practice_focus == "Right catch too early", "Practice must preserve the actionable mistake")
	check(game.num_balls == 3 and game.pattern == game.CASCADE, "Practice must retain the routine")
	check(game.stamina <= 180.0, "Practice must not grant free stamina")
	check(not game.booking_active and not game.daily_active and game.encores.is_empty(), "Practice must not carry performance conditions")
	check(game.saves == 1, "The navigation must save once")
	game.free()
	if failures == 0: print("TossaPractice: costs, ending guards, focus and routine preserved")
	quit(failures)
