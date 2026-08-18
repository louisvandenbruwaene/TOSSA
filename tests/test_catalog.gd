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
	var expected_props := ["Ball", "Egg", "Ring", "Club", "Knife", "Torch", "Chainsaw"]
	for i in expected_props.size():
		if i >= TOSSA_CATALOG.PROPS.size() or TOSSA_CATALOG.PROPS[i]["name"] != expected_props[i]:
			push_error("Prop index %d must remain %s." % [i, expected_props[i]])
			failed += 1
	if TOSSA_CATALOG.PROP_SIG.size() != expected_props.size() or int(TOSSA_CATALOG.PROPS[3]["pwin"]) != 1 or int(TOSSA_CATALOG.PROPS[6]["pwin"]) != -1:
		push_error("Prop timing/signature contract changed.")
		failed += 1
	var expected_tricks := ["btb", "high", "spin"]
	for i in expected_tricks.size():
		if i >= TOSSA_CATALOG.TRICKS.size() or TOSSA_CATALOG.TRICKS[i]["id"] != expected_tricks[i]:
			push_error("Trick index %d must remain %s." % [i, expected_tricks[i]])
			failed += 1
	var expected_encores := ["hecklers", "fright", "gale", "blackout", "cold", "long", "understudy", "fire", "scared", "fancy", "study", "lines", "overhand", "critic", "critic_hard", "purist_acc", "purist_str", "purist_end", "purist_spd"]
	for i in expected_encores.size():
		if i >= TOSSA_CATALOG.ENCORES.size() or TOSSA_CATALOG.ENCORES[i]["id"] != expected_encores[i]:
			push_error("Encore %d must remain %s." % [i, expected_encores[i]])
			failed += 1
	if TOSSA_CATALOG.PURIST_IDS != ["purist_acc", "purist_spd"]:
		push_error("Purist Encore IDs changed.")
		failed += 1
	if TOSSA_CATALOG.VENUE_FLAVOUR.size() != 7:
		push_error("Every venue must keep one named rival and deterministic taste.")
		failed += 1
	for venue in TOSSA_CATALOG.VENUE_FLAVOUR:
		if String(venue.get("rival", "")).is_empty() or String(venue.get("trigger", "")).is_empty():
			push_error("Venue flavour entries require a rival and trigger.")
			failed += 1
	if failed == 0:
		print("TossaCatalog: patterns, props, tricks, and encores verified")
	quit(failed)
