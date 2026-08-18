## Locks the replay recording contract before a ghost reader is integrated.
extends SceneTree

const TOSSA_REPLAY = preload("res://scripts/TossaReplay.gd")


func _init() -> void:
	var failed := 0
	var record := TOSSA_REPLAY.new_record(20260818, 2, 0, 0, 3)
	if not TOSSA_REPLAY.is_valid(record):
		push_error("A new replay record must be valid.")
		failed += 1
	if not TOSSA_REPLAY.append_event(record, 12, "throw_left") or not TOSSA_REPLAY.append_event(record, 12, "throw_right"):
		push_error("Equal-tick actions must preserve their accepted order.")
		failed += 1
	if TOSSA_REPLAY.append_event(record, 11, "throw_left"):
		push_error("A replay must reject backwards events.")
		failed += 1
	if TOSSA_REPLAY.append_event(record, -1, "throw_left") or TOSSA_REPLAY.append_event(record, 13, ""):
		push_error("A replay must reject invalid event data.")
		failed += 1
	if not TOSSA_REPLAY.is_valid(record):
		push_error("A record with ordered events must remain valid.")
		failed += 1
	var playback := TOSSA_REPLAY.actions_at_tick(record, 12, 0)
	if playback["actions"] != ["throw_left", "throw_right"] or int(playback["cursor"]) != 2:
		push_error("Playback must return every equal-tick action in accepted order.")
		failed += 1
	var route := TOSSA_REPLAY.new_route(20260818)
	if not TOSSA_REPLAY.append_stage(route, record) or not TOSSA_REPLAY.finish_route(route, 65432):
		push_error("A route must accept an ordered stage and final time.")
		failed += 1
	if not TOSSA_REPLAY.is_valid_route(route) or TOSSA_REPLAY.stage_for_venue(route, 2) != record:
		push_error("A finished route must validate and return its recorded stage.")
		failed += 1
	if TOSSA_REPLAY.append_stage(route, record):
		push_error("A route must reject duplicate or backwards venues.")
		failed += 1
	var corrupt := record.duplicate(true)
	corrupt["version"] = 99
	if TOSSA_REPLAY.is_valid(corrupt):
		push_error("An unsupported replay version must be rejected.")
		failed += 1
	if failed == 0:
		print("TossaReplay: recording contract verified")
	quit(failed)
