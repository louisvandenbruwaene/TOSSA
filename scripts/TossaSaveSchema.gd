## Pure save migrations with fixture-friendly inputs.
##
## File IO and live game state stay in Game.gd; old serialized values are translated
## here so every shipped migration can be exercised without touching user://.
class_name TossaSaveSchema
extends RefCounted


const PATTERN_VERSION := 2


static func migrate_pattern(raw_index: int, version: int) -> Dictionary:
	var migrated := raw_index
	if version < PATTERN_VERSION:
		# Original layout: Cascade, Fountain, Columns, Half Shower, Shower,
		# Reverse Cascade, Waterfall, Tennis. Fountain and Waterfall fold into
		# their closest surviving routines; later entries move to current indices.
		match raw_index:
			0, 1: migrated = 0
			2: migrated = 1
			3: migrated = 2
			4: migrated = 3
			5: migrated = 4
			6: migrated = 2
			7: migrated = 5
			_: migrated = 0
	return {"index": clampi(migrated, 0, 5), "version": PATTERN_VERSION}
