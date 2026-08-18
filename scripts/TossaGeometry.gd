## Pure flight and collision geometry shared by the live simulation and audits.
class_name TossaGeometry
extends RefCounted


static func flight_position(from: Vector2, to: Vector2, arc: float, launch_tick: int, land_tick: int, now_tick: int) -> Vector2:
	var span := maxi(1, land_tick - launch_tick)
	var p := clampf(float(now_tick - launch_tick) / float(span), 0.0, 1.0)
	var pos := from.lerp(to, p)
	pos.y -= 4.0 * arc * p * (1.0 - p)
	return pos


static func flight_velocity(from: Vector2, to: Vector2, arc: float, launch_tick: int, land_tick: int, now_tick: int) -> Vector2:
	var span := maxi(1, land_tick - launch_tick)
	var p := clampf(float(now_tick - launch_tick) / float(span), 0.0, 1.0)
	return (to - from - Vector2(0.0, 4.0 * arc * (1.0 - 2.0 * p))) / float(span)


static func edge_clearance(a: Vector2, b: Vector2, radius_a: float, radius_b: float) -> float:
	return a.distance_to(b) - radius_a - radius_b
