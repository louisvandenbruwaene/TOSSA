## Save-migration fixtures that never read or overwrite a real career.
extends SceneTree

const TOSSA_SAVE_SCHEMA = preload("res://scripts/TossaSaveSchema.gd")


func _init() -> void:
	var failed := 0
	var legacy := [0, 0, 1, 2, 3, 4, 2, 5]
	for old_index in legacy.size():
		var got := TOSSA_SAVE_SCHEMA.migrate_pattern(old_index, 0)
		if int(got["index"]) != legacy[old_index] or int(got["version"]) != 2:
			push_error("Legacy pattern %d migrated incorrectly: %s" % [old_index, str(got)])
			failed += 1
	var current := TOSSA_SAVE_SCHEMA.migrate_pattern(4, 2)
	if int(current["index"]) != 4:
		push_error("Current save pattern indices must not be remapped.")
		failed += 1
	var corrupt := TOSSA_SAVE_SCHEMA.migrate_pattern(99, 2)
	if int(corrupt["index"]) != 5:
		push_error("Current out-of-range values must clamp safely.")
		failed += 1
	if failed == 0:
		print("TossaSaveSchema: migration fixtures verified")
	quit(failed)
