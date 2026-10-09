extends SceneTree
const POSE = preload("res://scripts/TossaPerformancePose.gd")
var failures := 0

func check(condition: bool, message: String = "Pose exceeds its displacement budget") -> void:
	if not condition:
		push_error(message)
		failures += 1

func _init() -> void:
	var checks := 0
	var size := Vector2(152, 164)
	for left in [26.0, 38.0, 52.0]:
		for right in [26.0, 38.0, 52.0]:
			for age in [0.0, 6.0, 12.0, 23.0, 100.0]:
				var pose := POSE.sample(left, right, 3.7, age, false)
				check(absf(pose.x) <= 3.001 and pose.y >= 0.0 and pose.y <= 2.401)
				for x in [0.0, 45.0, 76.0, 106.0, 152.0]:
					check(POSE.body_offset(Vector2(x, 164), size, pose) == Vector2.ZERO,
						"A cosmetic pose must never lift a planted sole")
				var root := POSE.body_offset(Vector2(40, 37), size, pose)
				check(POSE.arm_offset(37.0, 37.0, 72.0, root) == root,
					"Sleeve root must follow the shoulder")
				for y in [70.0, 72.0, 74.0, 90.0]:
					check(POSE.arm_offset(y, 37.0, 72.0, root) == Vector2.ZERO,
						"Palm and fingertips must not move for cosmetic animation")
				check(POSE.sample(left, right, 3.7, age, true) == Vector3.ZERO,
					"Reduce motion must suppress secondary animation")
				checks += 1
	check(POSE.sample(26, 52, 0, 12, false).y > POSE.sample(26, 52, 0, 24, false).y,
		"A catch should absorb and settle")
	print("TossaPerformancePose: ", checks, " poses preserve palms, shoulders, planted soles and reduced motion")
	quit(failures)
