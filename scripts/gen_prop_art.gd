extends SceneTree
# ---------------------------------------------------------------------------------------
# PIXELTOSSA: the first real pixel art. Four props, drawn to resemble what the game draws
# today rather than to reinvent them.
#
#   godot --headless --script res://scripts/gen_prop_art.gd
#
# THE ART IS THE SOURCE, not the PNG. Every sprite below is a block of text you can edit
# directly - change a character, re-run, look at it. That is deliberate: a 6x6 ball is 36
# decisions, and they are far easier to argue about as text in a diff than as a binary blob
# nobody can review. The PNGs are build output.
#
# ---------------------------------------------------------------------------------------
# SIZES ARE NOT CHOSEN, THEY ARE DERIVED. Each prop's on-screen extent comes from the live
# drawing constants, divided by ART_PIXEL (4):
#
#   prop  | local extent (units) | x prop_scale | screen px | / 4 | sprite
#   ball  |  22 (r 11 x2)        | 1.0          |  22.0     | 5.5 |  6 x  6
#   ring  |  24 (r 12 x2)        | 1.7          |  40.8     |10.2 | 10 x 10
#   club  |  8.2 w x 40.3 h      | 1.6          |  13 x 64  | 3.3 |  3 x 16
#   knife |  8.8 w x 39.2 h      | 1.5          |  13 x 59  | 3.3 |  3 x 15
#
# Note the ROUNDING, which is the first real consequence of going pixel art: a ball is 22
# screen units and the 4px grid offers only 20 or 24. It becomes 24, about 9% larger. That
# is normal and correct (pixel art snaps sizes to the grid, that IS the grid) and it touches
# nothing but the picture - hitboxes are separate (prop_hit_scale) and unchanged.
#
# Note also how NARROW the long props are. A club is 40 units long and 8 wide; at this
# density that is 3 pixels across, and no amount of wanting will buy a fourth. Almost all of
# a club's character has to live in its silhouette and its two bands.
#
# PIVOTS matter as much as sizes. cap_club and cap_knife both `draw_set_transform(p, ang)`,
# so a prop tumbles about the draw position, and that position is NOT the middle of the
# shape: a club spans -22.5..+17.8 about it, a knife -26..+13.2. Get this wrong and the prop
# orbits a point it should be spinning around, which looks like bad art and is not.
#
# ---------------------------------------------------------------------------------------
# COLOUR, AND THE ONE RULE THAT IS EASY TO GET WRONG. draw_prop_rich hands the tint to the
# ROUND props only (ball, egg, ring go through cap_ball/cap_egg/cap_ring, which take `col`);
# club, knife, torch and chainsaw carry their own painted palettes and never see it. So:
#
#   ball, ring   -> author in GREYSCALE. The game multiplies by ball_color(i), one of four
#                   colours cycled by index, so a grey pixel becomes that colour at that
#                   brightness. The consequence worth remembering: a tint can only ever
#                   DARKEN, never brighten, so the highlight must be the brightest value in
#                   the file (1.0) and everything else sits below it.
#   club, knife  -> author in FINISHED COLOUR, straight off the shop card's palette.
# ---------------------------------------------------------------------------------------

# `.` is always transparent. Everything else indexes the per-sprite palette below.
const ART := {
	# --- BALL, 6x6, greyscale ------------------------------------------------------
	# Checked against the real thing rather than guessed: cap_ball is a disc, a DARKER
	# single seam wandering across it (`panel` is 0.84x the body, not brighter) and one
	# broad soft sheen up and left. The first version of this sprite had the seam bright,
	# which is backwards and read as a scratch.
	#
	# At six pixels across with a one-pixel rim there are sixteen interior pixels to spend,
	# and the first version spent them on FOUR values (rim, body, seam, sheen). Magnified on
	# a shop card that read as noise, and this file's own art doctrine says why: "no painted
	# highlight - all of those shimmer at small size on a moving object and were reverted
	# twice". A sheen is a claim about where the light is, and it is the first thing to go
	# when pixels run out.
	#
	# So THREE values, and the seam keeps its place because the seam is the identity: it is
	# the difference between a juggling ball and a dot. One clean diagonal - an S-curve needs
	# about twelve pixels before the S reads as an S rather than as jitter.
	"ball": {
		"folder": "Props",
		"rows": [
			".oooo.",
			"obbbpo",
			"obbpbo",
			"obpbbo",
			"opbbbo",
			".oooo.",
		],
		"pal": {
			"o": Color(0.62, 0.62, 0.62),   # rim, all the way round
			"b": Color(0.94, 0.94, 0.94),   # body
			"p": Color(0.76, 0.76, 0.76),   # the seam, DARKER than the body - checked against
											# cap_ball, whose `panel` is 0.84x, not brighter
		},
	},

	# --- RING, 10x10, greyscale ----------------------------------------------------
	# The one round prop that keeps its modelling, because a ring must read as an annulus:
	# the hole is the whole identity of the object and has to survive at any size. Kept
	# genuinely open in the middle (4x4 of nothing) rather than suggested with a dark fill.
	"ring": {
		"folder": "Props",
		"rows": [
			"...oooo...",
			".oohhbboo.",
			".ohhbbbbo.",
			"oohb..bboo",
			"ohb....bbo",
			"obb....bbo",
			"oobb..bboo",
			".obbbbbbo.",
			".oobbbboo.",
			"...oooo...",
		],
		"pal": {
			"o": Color(0.58, 0.58, 0.58),   # rim
			"b": Color(0.88, 0.88, 0.88),   # body
			"h": Color(1.00, 1.00, 1.00),   # the gloss, up and left like every light on
											# this stage, and the brightest value for the
											# same tint reason as the ball
		},
	},

	# --- CLUB, 3x16, finished colour -----------------------------------------------
	# Nose (the fat end) at the TOP, knob at the bottom, matching CLUB_NOSE_Y = -22.5 and
	# CLUB_BUTT_Y = +17.8 - y is down, so the nose is the negative one. Two cream bands on
	# the red body and a pale handle, which is what a juggling club has where a bowling pin
	# does not, and the thing the eye actually uses to tell the two apart.
	"club": {
		"folder": "Props",
		"pivot": [0.5, 0.558],   # CLUB_NOSE_Y -22.5 of a -22.5..+17.8 extent: the club
								 # tumbles about y=0, which is 55.8% down the sprite
		"rows": [
			".r.",
			"rrr",
			"rrr",
			"rrR",
			"www",
			"rrR",
			"www",
			"rrR",
			"rrR",
			".rR",
			".w.",
			".w.",
			".w.",
			".w.",
			"www",
			".W.",
		],
		"pal": {
			"r": Color(0.90, 0.35, 0.38),   # body, straight off cap_club_v2
			"R": Color(0.56, 0.18, 0.22),   # its shaded side
			"w": Color(0.96, 0.92, 0.85),   # band + handle
			"W": Color(0.70, 0.66, 0.60),
		},
	},

	# --- KNIFE, 3x15, finished colour ----------------------------------------------
	# Point up. At three pixels wide a knife is carried entirely by its taper and its guard:
	# without the guard it is a grey stick, and the guard gets exactly one row to exist in.
	"knife": {
		"folder": "Props",
		"pivot": [0.5, 0.663],   # tip -26 of a -26..+13.2 extent
		"rows": [
			".s.",
			".s.",
			"ssS",
			"ssS",
			"ssS",
			"ssS",
			"ssS",
			"ssS",
			"ssS",
			"ssS",
			"ggg",
			".h.",
			".h.",
			".H.",
			".g.",
		],
		"pal": {
			"s": Color(0.84, 0.87, 0.92),   # blade
			"S": Color(0.52, 0.56, 0.64),   # its shaded edge
			"g": Color(0.85, 0.68, 0.30),   # brass guard and pommel
			"h": Color(0.42, 0.28, 0.18),   # the grip
			"H": Color(0.28, 0.18, 0.11),
		},
	},
}


func _initialize() -> void:
	var lines: Array[String] = []
	for name: String in ART.keys():
		var spec: Dictionary = ART[name]
		var rows: Array = spec["rows"]
		var pal: Dictionary = spec["pal"]
		var h := rows.size()
		var w := str(rows[0]).length()
		for r: String in rows:
			if r.length() != w:
				push_error("%s: row '%s' is %d wide, expected %d" % [name, r, r.length(), w])
				quit(1)
				return
		var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		for y in h:
			var row := str(rows[y])
			for x in w:
				var ch := row[x]
				if ch == ".":
					continue
				if not pal.has(ch):
					push_error("%s: no palette entry for '%s'" % [name, ch])
					quit(1)
					return
				img.set_pixel(x, y, pal[ch])
		var path := "res://Assets/%s/%s.png" % [spec["folder"], name]
		if img.save_png(path) != OK:
			push_error("could not write " + path)
			continue
		print("  %-6s %2dx%-2d -> %s" % [name, w, h, path])
		var piv: Array = spec.get("pivot", [0.5, 0.5])
		lines.append('  "prop/%s": { "path": "%s", "pivot": [%s, %s], "scale": 1.0 }'
			% [name, path, piv[0], piv[1]])
	print("wrote %d sprite(s)\n" % lines.size())
	# the manifest lines, ready to paste - the pivots are derived from the drawing constants
	# above, so this is the one place they can be got right without measuring by eye
	print("--- Resources/art_manifest.json entries ---")
	print(",\n".join(lines))
	print("-------------------------------------------")
	quit()
