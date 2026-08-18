## Pure text formatting shared by the game UI, results, and developer harnesses.
##
## This module deliberately knows nothing about Nodes, saves, rendering, or live game
## state. It is the first extraction from Game.gd because its inputs and outputs are
## deterministic and easy to test in isolation. Keep presentation formatting here;
## keep placement, colours, and font fitting with the screen that owns them.
class_name TossaFormat
extends RefCounted


static func commafy(n: int) -> String:
	var raw := str(absi(n))
	var out := ""
	var c := 0
	for i in range(raw.length() - 1, -1, -1):
		out = raw[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if n < 0 else "") + out


static func score_text(v: float) -> String:
	# Scores are floats and can outgrow an int. Never route one through commafy:
	# Godot saturates that conversion at INT64_MAX, which turns distinct records into
	# the same misleading number. Ordinary scores stay familiar; late-game values
	# become a compact, finite-safe scientific notation.
	if not is_finite(v):
		return "E300+"
	var a := absf(v)
	if a < 1.0e9:
		return commafy(int(round(v)))
	# Floating-point logs can land infinitesimally below an exact power of ten
	# (log(1e9) as 8.999999...), producing the misleading 10.00e8. The epsilon is
	# far smaller than any display precision and only corrects that representation edge.
	var e := int(floor(log(a) / log(10.0) + 1.0e-9))
	var m := a / pow(10.0, float(e))
	return "%s%.2fe%d" % ["-" if v < 0.0 else "", m, e]


static func mult_text(v: float) -> String:
	if v < 100.0:
		return "%.2f" % v
	if v < 1.0e6:
		return commafy(int(round(v)))
	return score_text(v)
