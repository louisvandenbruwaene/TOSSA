## Locks down persisted pattern ordering and core catalog values.
extends SceneTree

const TOSSA_CATALOG = preload("res://scripts/TossaCatalog.gd")


func _init() -> void:
	var expected_ids := ["cascade", "columns", "halfshower", "shower", "rcasc", "tennis"]
	var failed := 0
	if TOSSA_CATALOG.PATTERNS.size() != expected_ids.size():
		push_error("Pattern count changed; save migration is required.")
		failed += 1
	for i in expected_ids.size():
		if i >= TOSSA_CATALOG.PATTERNS.size() or TOSSA_CATALOG.PATTERNS[i]["id"] != expected_ids[i]:
			push_error("Pattern index %d must remain %s." % [i, expected_ids[i]])
			failed += 1
	if float(TOSSA_CATALOG.PATTERNS[3]["mult"]) != 3.0:
		push_error("Shower's approved multiplier changed.")
		failed += 1
	if failed == 0:
		print("TossaCatalog: pattern order and values verified")
	quit(failed)
