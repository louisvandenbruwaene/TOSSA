extends SceneTree
## Reproducible import of generated master paintings to TOSSA's 640x360 / 48-colour assets.
## Run: godot --headless --path . --script scripts/import_theatre_art.gd
func _init() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://Resources/palette/palette.json"))
	var palette: Array[Color] = []
	for hex in data["hex"]:
		palette.append(Color.html(hex))
	for name: String in ["small_theatre", "the_circus"]:
		var source := "res://extras/visual_overhaul/" + name + "_master.png"
		var picture := Image.load_from_file(source)
		if picture == null:
			push_error("Missing art master: " + source)
			quit(1)
			return
		picture.resize(640, 360, Image.INTERPOLATE_LANCZOS)
		picture.convert(Image.FORMAT_RGB8)
		var mapped := {}
		for y in 360:
			for x in 640:
				var color := picture.get_pixel(x, y)
				var key := color.to_rgba32()
				if not mapped.has(key):
					var best := Color.BLACK
					var error := INF
					for candidate in palette:
						var d := color - candidate
						var distance := d.r * d.r * 0.30 + d.g * d.g * 0.59 + d.b * d.b * 0.11
						if distance < error:
							error = distance
							best = candidate
					mapped[key] = best
				picture.set_pixel(x, y, mapped[key])
		var output := "res://Assets/Backgrounds/" + name + "_v2.png"
		if picture.save_png(output) != OK:
			push_error("Could not save " + output)
			quit(1)
			return
		print("Imported ", output, " (640x360, locked palette, no diffusion noise)")
	quit()
