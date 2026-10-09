extends RefCounted
## Cosmetic pose in source pixels. Never writes to the juggling simulation.
## sine_in_out adapts glslify/glsl-easings (MIT); see third_party/visuals.

static func sine_in_out(t: float) -> float:
	return -0.5 * (cos(PI * clampf(t, 0.0, 1.0)) - 1.0)

static func sample(left: float, right: float, clock: float, catch_age: float,
		reduced: bool) -> Vector3:
	if reduced:
		return Vector3.ZERO
	var weight := clampf((right - left) / 22.0, -1.0, 1.0)
	var absorb := sin(PI * clampf(catch_age / 24.0, 0.0, 1.0)) * 2.4
	var breath := 0.5 + 0.5 * sin(clock * 1.8)
	return Vector3(weight * 3.0, maxf(absorb, breath), sin(clock * 2.2 - 0.7) * 1.5 - weight)

static func body_offset(at: Vector2, size: Vector2, pose: Vector3) -> Vector2:
	var height := at.y / maxf(size.y, 1.0)
	var upper := 1.0 - sine_in_out((height - 0.25) / 0.72)
	# Coat hems can follow through, while trouser legs and soles stay planted.
	var edge := clampf((absf(at.x - size.x * 0.5) / size.x - 0.14) * 12.0, 0.0, 1.0)
	var hem := sin(PI * clampf((height - 0.48) / 0.50, 0.0, 1.0)) * edge
	return Vector2(roundf(pose.x * upper + pose.z * hem), roundf(pose.y * upper))

static func arm_offset(y: float, shoulder_y: float, palm_y: float, root: Vector2) -> Vector2:
	# Both the palm and everything beyond it are pinned exactly. The upper sleeve
	# follows the moving shoulder; a catch never stretches a glove away from a prop.
	var weight := 1.0 - sine_in_out((y - shoulder_y) / maxf(1.0, palm_y - shoulder_y - 3.0))
	return Vector2(roundf(root.x * weight), roundf(root.y * weight))
