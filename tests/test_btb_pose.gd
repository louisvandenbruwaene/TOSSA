extends SceneTree
const GAME = preload("res://Game.gd")
func _init() -> void:
	var game = GAME.new()
	var failures := 0
	var ball = GAME.Ball.new()
	ball.trick = game.TR_BTB
	ball.thrown_from = game.LEFT
	ball.to_hand = game.RIGHT
	ball.launch_tick = 100
	ball.land_tick = 300
	game.balls.append(ball)
	game.tick = 100
	if game.btb_arm_fold(game.LEFT) != 0.0: failures += 1
	game.tick = 112
	if game.btb_arm_fold(game.LEFT) != 1.0: failures += 1
	if game.btb_arm_fold(game.RIGHT) != 0.0: failures += 1
	var incoming = GAME.Ball.new()
	incoming.to_hand = game.LEFT
	incoming.land_tick = 125
	game.balls.append(incoming)
	if game.btb_arm_fold(game.LEFT) != 0.0: failures += 1
	game.balls.erase(incoming)
	game._stack_l.append(incoming)
	if game.btb_arm_fold(game.LEFT) != 0.0: failures += 1
	game._stack_l.clear()
	game.tick = 124
	if game.btb_arm_fold(game.LEFT) != 0.0: failures += 1
	if ball.launch_tick != 100 or ball.land_tick != 300: failures += 1
	game.free()
	if failures == 0: print("TossaPose: behind-back gesture keeps release, catch and held-prop contact intact")
	else: push_error("Behind-back pose contact guard failed")
	quit(failures)
