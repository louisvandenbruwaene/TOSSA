## Deterministic catch contract, using the live game's comfort and difficulty rules.
extends SceneTree
const GAME = preload("res://Game.gd")
func _init() -> void:
	var game = GAME.new()
	var failures := 0
	for difficulty in [0, 1, 2]:
		game.difficulty = difficulty
		for accuracy in [0, 5, 100, 200]:
			game.accuracy = accuracy
			for height in [0.0, 0.4, 1.8]:
				for quality in [1, 2]:
					if game.catch_chance(quality, height) != 1.0:
						failures += 1
				var cost: float = game.edge_catch_cost(height)
				if cost < 1.0 or cost > 3.0:
					failures += 1
	game.accuracy = 0
	var untrained: float = game.edge_catch_cost(0.0)
	game.accuracy = 100
	if game.edge_catch_cost(0.0) > untrained:
		failures += 1
	game.legacy_random_catches = true
	game.difficulty = 1
	game.accuracy = 0
	if game.catch_chance(2, 0.0) >= 1.0:
		failures += 1
	# Drive actual catches on both hands, outside the tutorial, at both off-Perfect grades.
	game.legacy_random_catches = false
	game.tick = 100
	for hand in [0, 1]:
		for distance in [game.perfect_window() + 1, game.good_window() + 1, game.late_window()]:
			for direction in [-1, 1]:
				game.balls.clear()
				game._stack_l.clear()
				game._stack_r.clear()
				game.stamina = 200.0
				var ball = GAME.Ball.new()
				ball.to_hand = hand
				ball.land_tick = 100 + distance * direction
				game.balls.append(ball)
				game.on_catch(hand)
				if ball.state != GAME.STATE_HAND or not game.stack(hand).has(ball):
					failures += 1
	game.free()
	if failures: push_error("Catch comfort contract failed: %d" % failures)
	else: print("TossaCatch: predictable catches, bounded cost and legacy comparison verified")
	quit(failures)
