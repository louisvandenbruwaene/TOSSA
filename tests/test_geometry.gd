## Contract checks for the parabolic flight and collision-audit seam.
extends SceneTree

const TOSSA_GEOMETRY = preload("res://scripts/TossaGeometry.gd")


func _init() -> void:
	var failed := 0
	var start := Vector2(10.0, 100.0)
	var finish := Vector2(110.0, 100.0)
	if TOSSA_GEOMETRY.flight_position(start, finish, 40.0, 0, 20, 0) != start:
		push_error("Flight must begin at its launch point.")
		failed += 1
	if TOSSA_GEOMETRY.flight_position(start, finish, 40.0, 0, 20, 20) != finish:
		push_error("Flight must end at its landing point.")
		failed += 1
	var apex := TOSSA_GEOMETRY.flight_position(start, finish, 40.0, 0, 20, 10)
	if not apex.is_equal_approx(Vector2(60.0, 60.0)):
		push_error("Flight apex must rise by exactly its arc height.")
		failed += 1
	var apex_velocity := TOSSA_GEOMETRY.flight_velocity(start, finish, 40.0, 0, 20, 10)
	if not is_zero_approx(apex_velocity.y):
		push_error("Vertical velocity must be zero at the apex.")
		failed += 1
	if not is_equal_approx(TOSSA_GEOMETRY.edge_clearance(Vector2.ZERO, Vector2(10.0, 0.0), 3.0, 2.0), 5.0):
		push_error("Collision clearance must measure the gap between edges.")
		failed += 1
	if failed == 0:
		print("TossaGeometry: flight and clearance contracts verified")
	quit(failed)
