extends SceneTree
# ---------------------------------------------------------------------------------------
# PIXELTOSSA: write one placeholder PNG per art seam key.
#
#   godot --headless --script res://scripts/gen_placeholders.gd
#
# These are NOT art and are not meant to survive. Their entire job is to prove the pipeline
# end to end - manifest -> import -> art_blit -> screen - and to state, in the file itself,
# how big the real art has to be. Every one is authored at 320x180 density (1 image pixel =
# a 4x4 screen block), so a placeholder and the final art it is replaced by are the same
# number of pixels, and swapping one for the other moves nothing on screen.
#
# WHY WHITE. Props, hands and gear are drawn through the game's own colour as a TINT - a
# ball's per-object colour, a glove's venue cloth, a gear card's accent. White art tints to
# any of those; art with its own colour baked in fights them. So a placeholder is a white
# silhouette with a darker keyline, plus ONE magenta pixel at the top-left corner: enough
# to spot instantly on screen, small enough never to be mistaken for a design decision.
#
# The sizes below are derived from the live drawing constants (BALL_RADIUS_PX = 11 gives a
# 22-unit ball, which is 22/4 -> 6 art pixels across) rather than guessed. If a prop is
# rescaled in Game.gd, regenerate rather than hand-editing a number here.
# ---------------------------------------------------------------------------------------

const MARK := Color(1.0, 0.0, 1.0, 1.0)     # the "this is a placeholder" corner pixel
const FILL := Color(1.0, 1.0, 1.0, 1.0)
const EDGE := Color(0.62, 0.62, 0.62, 1.0)

# key -> [folder, w, h, shape]
const SPEC := {
	# --- props (Assets/Props) - tinted, rotated, sized off prop_scale ---------------
	"ball":      ["Props", 6, 6, "disc"],
	"egg":       ["Props", 5, 6, "disc"],
	"ring":      ["Props", 7, 7, "ring"],
	"club":      ["Props", 5, 11, "club"],
	"knife":     ["Props", 4, 11, "blade"],
	"torch":     ["Props", 5, 11, "club"],
	"chainsaw":  ["Props", 12, 7, "box"],
	# --- character (Assets/Characters) --------------------------------------------
	"head":         ["Characters", 14, 14, "disc"],
	"head_back":    ["Characters", 14, 14, "disc"],
	"hat_top":      ["Characters", 16, 12, "box"],
	"glasses":      ["Characters", 11, 4, "box"],
	"helmet":       ["Characters", 17, 9, "box"],
	"boot":         ["Characters", 6, 8, "box"],
	"hand_open":    ["Characters", 6, 7, "disc"],
	"hand_closed":  ["Characters", 6, 6, "disc"],
	"glove_open":   ["Characters", 6, 7, "disc"],
	"glove_closed": ["Characters", 6, 6, "disc"],
	# --- effects (Assets/Effects) --------------------------------------------------
	"flower_t0": ["Effects", 5, 5, "disc"],
	"flower_t1": ["Effects", 6, 6, "disc"],
	"flower_t2": ["Effects", 7, 7, "disc"],
	"tomato":    ["Effects", 4, 4, "disc"],
	# --- UI (Assets/UI) - stretched to their box, so proportion is what matters -----
	"keycap":     ["UI", 8, 5, "box"],
	"card_skill": ["UI", 26, 36, "box"],
	"card_trick": ["UI", 26, 36, "box"],
	# --- backdrops (Assets/Backgrounds) - the full 320x180 canvas ------------------
	"backyard":      ["Backgrounds", 320, 180, "backdrop"],
	"street_corner": ["Backgrounds", 320, 180, "backdrop"],
	"small_theatre": ["Backgrounds", 320, 180, "backdrop"],
	"the_circus":    ["Backgrounds", 320, 180, "backdrop"],
	"championship":  ["Backgrounds", 320, 180, "backdrop"],
	"world_arena":   ["Backgrounds", 320, 180, "backdrop"],
	"midnight_show": ["Backgrounds", 320, 180, "backdrop"],
}

# which manifest group each folder writes its keys under
const GROUP := {
	"Props": "prop", "Characters": "char", "Effects": "fx",
	"UI": "ui", "Backgrounds": "bg",
}


func _initialize() -> void:
	var lines: Array[String] = []
	var n := 0
	for name: String in SPEC.keys():
		var spec: Array = SPEC[name]
		var folder := str(spec[0])
		var w := int(spec[1])
		var h := int(spec[2])
		var img := _make(w, h, str(spec[3]))
		var dir := "res://Assets/" + folder
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
		var path := dir + "/" + name + ".png"
		var err := img.save_png(path)
		if err != OK:
			push_error("could not write %s (%d)" % [path, err])
			continue
		n += 1
		lines.append('  "%s/%s": { "path": "%s", "pivot": [0.5, 0.5], "scale": 1.0 }'
			% [GROUP[folder], name, path])
	# the ready-to-use manifest that registers everything just written. Kept SEPARATE from
	# art_manifest.json on purpose: the default run of this branch must stay pixel-identical
	# to `main`, so placeholders are opt-in via `--artmanifest`, never the default.
	var f := FileAccess.open("res://Resources/art_manifest.placeholder.json", FileAccess.WRITE)
	f.store_string("{\n" + ",\n".join(lines) + "\n}\n")
	f.close()
	print("wrote %d placeholder(s) + Resources/art_manifest.placeholder.json" % n)
	print("try it:  godot --audio-driver Dummy -- --artmanifest res://Resources/art_manifest.placeholder.json")
	quit()


func _make(w: int, h: int, shape: String) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx := (float(w) - 1.0) * 0.5
	var cy := (float(h) - 1.0) * 0.5
	for y in h:
		for x in w:
			var inside := false
			match shape:
				"disc", "ring":
					var dx := (float(x) - cx) / maxf(cx, 0.5)
					var dy := (float(y) - cy) / maxf(cy, 0.5)
					var d := dx * dx + dy * dy
					inside = d <= 1.05
					if shape == "ring" and d < 0.30:
						inside = false          # the hole a ring must keep
				"club":
					# a waisted profile: narrow at the handle, swelling to the head, which is
					# the silhouette that reads as "club" before any detail does
					var t := float(y) / maxf(float(h) - 1.0, 1.0)
					var hw := lerpf(0.28, 1.0, t * t)
					inside = absf(float(x) - cx) <= hw * cx + 0.35
				"blade":
					var t2 := float(y) / maxf(float(h) - 1.0, 1.0)
					inside = absf(float(x) - cx) <= lerpf(1.0, 0.15, t2) * cx + 0.35
				"backdrop":
					# a coarse grid so it is obvious at a glance that the whole backdrop is
					# provisional, and so the 320x180 canvas can be counted off on screen
					inside = (x % 16 == 0) or (y % 16 == 0)
				_:
					inside = true
			if inside:
				img.set_pixel(x, y, FILL)
	if shape != "backdrop":
		# a keyline, so the silhouette's edge is legible against a lit stage
		for y in h:
			for x in w:
				if img.get_pixel(x, y).a < 0.5:
					continue
				var edge := false
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nx := x + d.x
					var ny := y + d.y
					if nx < 0 or ny < 0 or nx >= w or ny >= h or img.get_pixel(nx, ny).a < 0.5:
						edge = true
				if edge:
					img.set_pixel(x, y, EDGE)
	img.set_pixel(0, 0, MARK)     # the placeholder tell
	return img
