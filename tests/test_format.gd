## Lightweight no-addon test for TossaFormat's pure contract.
extends SceneTree

const TOSSA_FORMAT = preload("res://scripts/TossaFormat.gd")


func _init() -> void:
	var cases := [
		["commafy zero", TOSSA_FORMAT.commafy(0), "0"],
		["commafy negative", TOSSA_FORMAT.commafy(-1234567), "-1,234,567"],
		["ordinary score", TOSSA_FORMAT.score_text(999999999.0), "999,999,999"],
		["large score", TOSSA_FORMAT.score_text(1.0e9), "1.00e9"],
		["large negative score", TOSSA_FORMAT.score_text(-2.5e12), "-2.50e12"],
		["non-finite score", TOSSA_FORMAT.score_text(INF), "E300+"],
		["matched small scores", ", ".join(TOSSA_FORMAT.score_texts_matched([640.0, 1280.0])), "640, 1,280"],
		["matched mixed scores", ", ".join(TOSSA_FORMAT.score_texts_matched([4.5e8, 9.0e8, 1.35e9])), "4.50e8, 9.00e8, 1.35e9"],
		["small multiplier", TOSSA_FORMAT.mult_text(2.5), "2.50"],
		["large multiplier", TOSSA_FORMAT.mult_text(1234567.0), "1,234,567"],
		["sprint duration", TOSSA_FORMAT.duration_text(3723), "01:02:03"],
	]
	var failed := 0
	for test_case in cases:
		if test_case[1] != test_case[2]:
			failed += 1
			push_error("%s: expected %s, got %s" % [test_case[0], test_case[2], test_case[1]])
	if failed == 0:
		print("TossaFormat: %d cases passed" % cases.size())
	quit(failed)
