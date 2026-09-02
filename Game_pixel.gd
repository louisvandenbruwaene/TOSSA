class_name TossaPixel
extends Node
## THE PIXEL RENDER STACK - the half of the remaster that is architecture rather than art.
##
## Game.gd currently keeps the pixel grid by HAND: art_snap, fill_disc_pix, draw_ring_pix,
## draw_arc_pix, draw_capsule_pix, fill_poly_pix, fill_ellipse_pix, draw_glow_pix, the
## whole-magnification rule in art_prop_zoom, the half-step lock in fig_scale_H, and the
## `px` argument threaded through draw_figure_body so a preview can draw at 1 screen pixel
## per art pixel while the stage draws at 2. Every one of those exists for the same reason:
## the game renders at 1280x720 and then tries to behave as if it were 640x360.
##
## RENDER AT 640x360 AND THE REASON EVAPORATES. A stage drawn into a 640x360 framebuffer
## cannot produce a half pixel, cannot resample a sprite fractionally, and cannot draw a
## flame that steps at one screen pixel beside a coat that steps at two - there is only one
## pixel size in the building. The helpers above become one-line forwards to the engine
## primitives they replaced (see the GRID COMPAT region at the bottom), and the density
## bugs stop being a class of bug.
##
## WHAT THIS FILE OWNS
##   1. the stack itself: SubViewport(640x360, nearest) -> integer-scaled Sprite2D -> window,
##      an input bridge so the game still gets its keys, and a full-res CanvasLayer above it
##      for HUD text when you want crisp text;
##   2. the stage light as ONE shader - veil, top-weighting, the lip past the floor line,
##      the pool, blackout, the drop cool, the vignette - replacing ~300 lines of stacked
##      gradient rects that can, and did, produce a hard step at the standing line;
##   3. a fixed palette, a shader-side snap to it, and an offline quantiser, so seven
##      separately generated backdrops stop being seven separate colour worlds;
##   4. indexed costume art: one texture, one draw call, a palette swapped per venue -
##      replacing art_blit_regions' five greyscale masks and its all-or-nothing rule;
##   5. limbs as textured polygons with a banded shading ramp, which is draw_capsule_pix's
##      look without draw_capsule_pix's rasteriser.
##
## INSTALLING IT (the scene change is two minutes and is the recommended path)
##
##   Preferred - in the editor:
##       Root (Node2D)
##        +- SubViewportContainer (stretch on, texture_filter Nearest)
##        |   +- SubViewport (size 640x360)
##        |       +- Game (Game.gd)          <- scale (0.5, 0.5)
##        +- Hud (CanvasLayer)               <- optional, phase B
##   Then in Game.gd's _ready:  pix = TossaPixel.new(); add_child(pix); pix.adopt(self)
##
##   Or programmatically, if you would rather not touch the scene:
##       var pix := TossaPixel.new()
##       add_child(pix)
##       pix.install(self)          # builds the stack and reparents `self` into it
##
## THE ONE MECHANICAL EDIT IN Game.gd. Inside the viewport, get_viewport_rect().size is
## (640, 360) - true, and not what 30 call sites in Game.gd mean by it. They mean "the
## design frame", which is still 1280x720 because the node is drawn at half scale. So:
##
##       func view_size() -> Vector2:
##           return TossaPixel.DESIGN
##
##   ...and  sed -i 's/get_viewport_rect()\.size/view_size()/g'  over Game.gd.
##   That is the whole port. Nothing else in the drawing code has to change to run.
##
## WHAT TO DELETE AFTERWARDS, in this order, testing between each:
##   art_snap (identity now)          fill_disc_pix / draw_ring_pix / draw_arc_pix
##   draw_glow_pix                    fill_poly_pix / fill_ellipse_pix / draw_spoke_pix
##   draw_capsule_pix                 art_prop_zoom's integer rounding
##   fig_scale_H's half-step snap     the `px` argument on draw_figure_body/draw_figure_design
## Each of those is load-bearing ONLY while the framebuffer is 1280x720.
##
## INPUT. A SubViewport that is not inside a SubViewportContainer receives NO input events,
## so dropping Game.gd into one would silently kill every key in the game - the same class
## of failure as the 2026-07 input-drop bug, arriving by a different door. InputBridge below
## forwards them and puts mouse positions into buffer coordinates on the way through. This
## is why install() is not just "make a viewport and reparent".
##
## TEXT. Phase A puts the HUD in the low-res buffer with everything else, so every font
## size in Game.gd halves in real pixels: ps(13) becomes 6.5 buffer pixels and a vector
## font turns to mud. Use a bitmap pixel font at its native size (5x7 / 8x8) and even
## sizes only - see snap_font_size(). If you want the HUD crisp at window resolution
## instead, use HUD_FULLRES and move the HUD draw calls into draw_hud_layer(ci); the
## proxy and the redraw plumbing for that are already here.

# ---------------------------------------------------------------------------------------
#region CONFIGURATION
# ---------------------------------------------------------------------------------------

## The coordinate space Game.gd is written in, and goes on being written in.
const DESIGN := Vector2(1280.0, 720.0)

## The framebuffer the stage is actually rendered into. DESIGN / 2, which is why the host
## is drawn at scale 0.5 and why ART_PIXEL's old value of 2.0 becomes exactly 1.0 here.
const BUFFER := Vector2i(640, 360)

## What one authored art pixel is worth in DESIGN units. Unchanged from Game.gd on purpose:
## sprite authoring, the manifest, and every measured constant keep meaning what they meant.
const ART_PIXEL := 2.0

## DESIGN -> BUFFER. Everything that converts between the two goes through this, so moving
## to 320x180 later is one constant rather than a hunt.
const HOST_SCALE := 0.5

enum HudMode {
	HUD_IN_STAGE,  ## phase A: the HUD renders in the 640x360 buffer with everything else
	HUD_FULLRES,  ## phase B: the HUD renders in a CanvasLayer at window resolution
}

## Integer scaling only, by default. A 2.5x upscale of pixel art puts some source pixels
## across three screen pixels and some across two, which is the same failure fig_scale_H
## was written to prevent, one stage later in the pipeline.
enum ScaleMode {
	SCALE_INTEGER,  ## largest whole multiple that fits, letterboxed
	SCALE_STRETCH,  ## fill the window, fractional - for store capsules and video capture only
}

var hud_mode: HudMode = HudMode.HUD_IN_STAGE
var scale_mode: ScaleMode = ScaleMode.SCALE_INTEGER
var background := Color(0.0, 0.0, 0.0, 1.0)  ## what shows in the letterbox bars

# ---------------------------------------------------------------------------------------
#endregion
#region THE PALETTE
# ---------------------------------------------------------------------------------------
# ONE PALETTE, OR THE VENUES STAY SEVEN SEPARATE COLOUR WORLDS. Five of the seven backdrops
# are generated, each from its own prompt, so each arrives with its own greys, its own
# browns and its own idea of what "warm" is - which is exactly why draw_backdrop needs a
# per-venue `veil` constant, why bg_floor_colour has to sample the painting to find a floor
# colour that agrees with it, and why a charged prop had to be normalised against its own
# brightest pixel to read the same green in every room. Those are all one problem.
#
# 48 colours, in ramps rather than as a scatter: a pixel artist shades by walking a ramp,
# and a palette without ramps forces every shading decision back into per-asset guesswork.
# The venue accents are MEMBERS of the palette (row: house light), so a costume tinted with
# a venue colour cannot leave the palette and get snapped somewhere unexpected.
const PALETTE_HEX: PackedStringArray = [
	# neutrals: the room, the dark, the paper
	"0b0a0f",
	"16141d",
	"23202c",
	"34303f",
	"4a4557",
	"6a6478",
	"938da0",
	"c9c4d2",
	"f2eff5",
	# wood, leather, boards, crates, the tree
	"2a1a12",
	"3d2718",
	"56361f",
	"70492a",
	"8f6039",
	"b07f4f",
	"cca071",
	# house light: gold, amber, footlight, brass  (the warm venue accents live here)
	"5a3a12",
	"8a5a17",
	"bf831f",
	"e5ab34",
	"f7cd63",
	"fdeaa6",
	# curtain, tomato, club body, crimson
	"3a0d12",
	"5e131c",
	"8c1f27",
	"b83741",
	"d9636a",
	"efa0a2",
	# night, cool shadow, moonlight, jumbotron blue  (the cold venue accents)
	"0a1024",
	"132043",
	"1e3670",
	"2f57a8",
	"5a86d6",
	"9dbcf0",
	# phosphor: the glow kit, the midnight show's accent
	"0d3524",
	"12653c",
	"2aa15f",
	"62e08f",
	"b6f7c9",
	# skin and hair
	"52301f",
	"7a4a33",
	"a9714b",
	"d9a173",
	"f0c8a0",
	# steel: knives, trusses, chainsaw bar
	"3b4048",
	"5c636e",
	"868d99",
	"c2c8d2",
]


static func palette() -> PackedColorArray:
	var out := PackedColorArray()
	for h: String in PALETTE_HEX:
		out.append(Color.html(h))
	return out


# ---------------------------------------------------------------------------------------
#endregion
#region SHADERS
# ---------------------------------------------------------------------------------------

## THE STAGE LIGHT, AS ONE PASS. Everything draw_backdrop and draw_stage_light lay down
## after the painting - the veil, its top weighting, its decay past the standing line, the
## warm pool, blackout, the drop's cool wash, the vignette - stated once, continuously, at
## buffer resolution.
##
## A CONTINUOUS FUNCTION CANNOT PRODUCE A STEP. The hard line under the performer's feet
## (2026-08-15) existed because the veil was a rect that ended at `fy` and a second rect
## picked up below it; the lip fix made the two agree at one seam by hand. Here there is no
## seam to make agree - one expression covers the whole frame, and the only quantisation is
## the deliberate one below.
##
## THE LIGHT IS BANDED ON PURPOSE. `light_steps` posterises every term to whole steps, which
## is how pixel artists have always drawn a lamp and is what stops a smooth gradient from
## reading as vector light poured over pixel scenery. It is the same instinct as
## GLOW_PIX_STEPS, applied to the whole stage instead of to one prop's halo - and, as there,
## changing the number recalibrates every light in the game rather than adjusting one.
const GRADE_SHADER := """
shader_type canvas_item;
render_mode unshaded, blend_disabled;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest;
uniform vec2 buffer_size = vec2(640.0, 360.0);

// the room behind the performer
uniform float floor_y : hint_range(0.0, 1.0) = 0.80;   // the standing line, in UV
uniform float veil : hint_range(0.0, 1.0) = 0.42;      // this venue's push-back
uniform float veil_top : hint_range(1.0, 2.5) = 1.55;  // ...deepening toward the ceiling
uniform float veil_lip : hint_range(0.0, 0.5) = 0.10;  // ...and decaying past the boards
uniform vec3 veil_col : source_color = vec3(0.012, 0.018, 0.032);

// the light he stands in
uniform vec2 pool_at = vec2(0.5, 0.62);
uniform float pool_r : hint_range(0.05, 2.0) = 0.62;
uniform float pool_amt : hint_range(0.0, 1.0) = 0.22;
uniform vec3 glow_col : source_color = vec3(1.0, 0.82, 0.50);

// the house going dark, a dropped prop cooling the room, and the frame
uniform float darkness : hint_range(0.0, 1.0) = 0.0;
uniform vec3 dark_col : source_color = vec3(0.012, 0.014, 0.022);
uniform float cool : hint_range(0.0, 1.0) = 0.0;
uniform float vignette : hint_range(0.0, 1.0) = 0.5;
uniform float fade : hint_range(0.0, 1.0) = 0.0;

uniform int light_steps = 14;
uniform sampler2D palette_tex : filter_nearest, repeat_disable;
uniform int palette_size = 0;

float quant(float x, int steps) {
	if (steps <= 1) { return x; }
	return floor(clamp(x, 0.0, 1.0) * float(steps)) / float(steps);
}

vec3 snap_to_palette(vec3 c) {
	if (palette_size <= 0) { return c; }
	float best = 1e9;
	vec3 out_c = c;
	for (int i = 0; i < 256; i++) {
		if (i >= palette_size) { break; }
		vec3 p = texelFetch(palette_tex, ivec2(i, 0), 0).rgb;
		vec3 d = p - c;
		// green-weighted, to match the offline quantiser exactly - an unweighted
		// distance here and a weighted one there would put the running game and the
		// saved assets on two different readings of the same palette
		float m = dot(d * d, vec3(0.30, 0.59, 0.11));
		if (m < best) { best = m; out_c = p; }
	}
	return out_c;
}

void fragment() {
	// sample on the buffer grid whatever resolution this rect happens to be drawn at,
	// so the light steps with the art rather than with the window
	vec2 uv = (floor(SCREEN_UV * buffer_size) + 0.5) / buffer_size;
	vec3 c = texture(screen_tex, uv).rgb;

	// THE VEIL: strongest at the ceiling, the venue's own value at the standing line,
	// decaying to nothing a little way onto the boards. The seats up there are the
	// darkest part of the building and the people in them see least.
	float above = clamp((floor_y - uv.y) / max(floor_y, 0.001), 0.0, 1.0);
	float past = clamp((uv.y - floor_y) / max(veil_lip, 0.001), 0.0, 1.0);
	float v = veil * mix(1.0, veil_top, above) * (1.0 - past);
	c = mix(c, veil_col, quant(v, light_steps));

	// THE POOL: a ground-level lift on the performer. It names no lantern - there is no
	// cone and no source claimed - which is the whole reason the cone was deleted.
	vec2 d = (uv - pool_at) * vec2(buffer_size.x / buffer_size.y, 1.0);
	float p = 1.0 - smoothstep(0.0, max(pool_r, 0.001), length(d));
	c += glow_col * quant(p * p * pool_amt, light_steps);

	// blackout, then the drop's cool, then the frame
	c = mix(c, dark_col, quant(darkness, light_steps));
	c = mix(c, vec3(0.35, 0.45, 0.65), cool * 0.12);
	vec2 vd = (uv - vec2(0.5)) * 2.0;
	c *= 1.0 - quant(clamp(dot(vd, vd) * 0.45, 0.0, 1.0) * vignette, light_steps);

	c = mix(c, vec3(0.03, 0.02, 0.03), fade);
	COLOR = vec4(snap_to_palette(clamp(c, vec3(0.0), vec3(1.0))), 1.0);
}
"""

## INDEXED COSTUME ART. art_blit_regions exists because costume_palette() repaints five
## colours per venue and one tint cannot carry five - so the body became five greyscale
## masks, five draw calls, and an all-or-nothing rule to stop a half-sprited torso.
##
## An index map carries all five in ONE texture: the red channel is a palette slot, the
## palette is a 256x1 texture the game rewrites whenever the costume changes, and the whole
## body is one draw call that cannot be half-served. The Glow Suit stops being a special
## case in draw_juggler and becomes another palette.
##
## USE THIS ONLY ON A NODE OF ITS OWN (make_costume_sprite). Godot's immediate-mode draw
## API has no per-command material: setting ci.material inside _draw() re-materials the
## WHOLE canvas item, so a shader assigned mid-figure would repaint the limbs drawn either
## side of it. For the figure, which is drawn in one _draw with the limbs, use bake_costume
## below instead - it does the same palette lookup on the CPU and hands back a plain texture.
const COSTUME_SHADER := """
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D pal : filter_nearest, repeat_disable;
uniform vec4 tint : source_color = vec4(1.0);

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	if (src.a < 0.5) { discard; }              // hard alpha: these plates are cut, not feathered
	int idx = int(floor(src.r * 255.0 + 0.5));
	vec4 p = texelFetch(pal, ivec2(idx, 0), 0);
	COLOR = vec4(p.rgb * tint.rgb, p.a * tint.a);
}
"""

# ---------------------------------------------------------------------------------------
#endregion
#region THE STACK
# ---------------------------------------------------------------------------------------

var host: Node2D = null  ## the node running Game.gd
var root: Node2D = null  ## what everything below hangs off, in the main window
var stage_vp: SubViewport = null
var backbuffer: BackBufferCopy = null
var grade: ColorRect = null  ## the light, sitting on top of the stage, inside the buffer
var display: Sprite2D = null  ## the buffer, nearest-scaled into the window
var bridge: Node = null  ## keeps the keys working - see InputBridge
var hud_layer: CanvasLayer = null
var hud: Node2D = null  ## HUD_FULLRES only: calls host.draw_hud_layer(self)

var _grade_mat: ShaderMaterial = null
var _palette_tex: ImageTexture = null
var _scale := 1
var _offset := Vector2.ZERO
var _owns_display := true


func install(game: Node2D) -> void:
	## Build the stack and move `game` into it. Deferred, because reparenting a node during
	## its own _ready happens while the tree is busy and Godot will refuse it.
	host = game
	_build.call_deferred(true)


func adopt(game: Node2D) -> void:
	## For the editor path, where the scene already has the SubViewport and `game` is
	## already inside it. Wires the shader, the display scaling and the HUD layer without
	## touching the tree.
	host = game
	_build.call_deferred(false)


func _build(reparent: bool) -> void:
	if host == null or not is_instance_valid(host):
		push_error("TossaPixel: no host")
		return

	if reparent:
		root = Node2D.new()
		root.name = "PixelStack"
		host.get_tree().root.add_child(root)

		stage_vp = SubViewport.new()
		stage_vp.name = "Stage"
		root.add_child(stage_vp)
		host.reparent(stage_vp, false)
	else:
		stage_vp = host.get_parent() as SubViewport
		if stage_vp == null:
			push_error("TossaPixel.adopt: the host is not inside a SubViewport - use install()")
			return
		root = Node2D.new()
		root.name = "PixelStack"
		host.get_tree().root.add_child(root)
		# If the scene already puts the viewport in a container, that container is doing the
		# blit and the input forwarding. Building our own would draw the stage twice and
		# deliver every key twice, so in that case we wire only the light and the HUD.
		_owns_display = not (stage_vp.get_parent() is SubViewportContainer)

	# THE FRAMEBUFFER. Nearest by default for every canvas item inside it, so no sprite
	# anywhere in the game can quietly be drawn smoothed - which is the single setting most
	# often missing when pixel art "looks soft for no reason".
	stage_vp.size = BUFFER
	stage_vp.transparent_bg = false
	stage_vp.disable_3d = true
	stage_vp.use_hdr_2d = false
	stage_vp.msaa_2d = Viewport.MSAA_DISABLED
	stage_vp.canvas_item_default_texture_filter = (
		Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	)
	# transforms snapped, vertices NOT: Game.gd's triangle edges depend on explicit alpha
	# feathers and vertex snapping would flatten them (its own docs/coding_guidelines note).
	stage_vp.snap_2d_transforms_to_pixel = true
	stage_vp.snap_2d_vertices_to_pixel = false
	stage_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	stage_vp.handle_input_locally = true

	# ...and the host draws its 1280x720 units into it at half scale, which is what makes
	# the port a scene change rather than a rewrite.
	host.position = Vector2.ZERO
	host.scale = Vector2(HOST_SCALE, HOST_SCALE)
	host.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	# THE LIGHT, INSIDE THE BUFFER. It has to be in here rather than on the display sprite:
	# a shader on the upscaled sprite runs per WINDOW pixel, so its gradients would be
	# smooth over blocky art - the exact seam this whole file exists to close.
	backbuffer = BackBufferCopy.new()
	backbuffer.name = "GradeBackbuffer"
	backbuffer.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	stage_vp.add_child(backbuffer)

	_grade_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = GRADE_SHADER
	_grade_mat.shader = sh
	_grade_mat.set_shader_parameter("buffer_size", Vector2(BUFFER))

	grade = ColorRect.new()
	grade.name = "StageLight"
	grade.material = _grade_mat
	grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grade.size = Vector2(BUFFER)
	grade.color = Color(1, 1, 1, 1)
	stage_vp.add_child(grade)

	set_palette(palette())

	if _owns_display:
		# THE WINDOW SIDE: one nearest-filtered blit at a whole multiple.
		display = Sprite2D.new()
		display.name = "StageDisplay"
		display.centered = false
		display.texture = stage_vp.get_texture()
		display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		root.add_child(display)

		# ...and the keys, which a bare SubViewport would otherwise never see.
		var b := InputBridge.new()
		b.name = "InputBridge"
		b.pix = self
		root.add_child(b)
		bridge = b

	hud_layer = CanvasLayer.new()
	hud_layer.name = "Hud"
	hud_layer.layer = 10
	root.add_child(hud_layer)
	if hud_mode == HudMode.HUD_FULLRES:
		var proxy := HudProxy.new()
		proxy.name = "HudCanvas"
		proxy.target = host
		proxy.method = "draw_hud_layer"
		proxy.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		hud_layer.add_child(proxy)
		hud = proxy

	var win := main_window()
	if win != null and not win.size_changed.is_connected(_fit):
		win.size_changed.connect(_fit)
	_fit()


func main_window() -> Window:
	## NOT host.get_window(): once the host lives inside the SubViewport, "the window it is
	## in" is a question about the buffer, not about the thing being resized. The scene tree
	## root is the real window and is what letterboxing has to answer to.
	if host == null or not is_instance_valid(host) or host.get_tree() == null:
		return null
	return host.get_tree().root


func _fit() -> void:
	var win_node := main_window()
	if win_node == null:
		return
	RenderingServer.set_default_clear_color(background)
	if display == null:
		return
	var win := Vector2(win_node.size)
	var b := Vector2(BUFFER)
	if scale_mode == ScaleMode.SCALE_INTEGER:
		_scale = maxi(1, int(floor(minf(win.x / b.x, win.y / b.y))))
		display.scale = Vector2(float(_scale), float(_scale))
		_offset = ((win - b * float(_scale)) * 0.5).floor()
	else:
		var k := minf(win.x / b.x, win.y / b.y)
		display.scale = Vector2(k, k)
		_offset = ((win - b * k) * 0.5).floor()
		_scale = maxi(1, int(round(k)))
	display.position = _offset


func set_scale_mode(mode: ScaleMode) -> void:
	scale_mode = mode
	_fit()


func redraw() -> void:
	## Game.gd's queue_redraw still works for the stage; this also refreshes a full-res HUD.
	if host != null:
		host.queue_redraw()
	if hud != null:
		hud.queue_redraw()


func view_size() -> Vector2:
	## What get_viewport_rect().size used to mean to Game.gd's layout code.
	return DESIGN


func screen_to_stage(p: Vector2) -> Vector2:
	## Window pixels -> the DESIGN units Game.gd lays out in. Mouse picking and the debug
	## panel need this; the keyboard path does not care.
	if _scale <= 0:
		return p
	return (p - _offset) / float(_scale) / HOST_SCALE


func stage_to_screen(p: Vector2) -> Vector2:
	return p * HOST_SCALE * float(_scale) + _offset


func screen_to_buffer_xform() -> Transform2D:
	## What InputBridge applies to a mouse event on its way into the buffer.
	var s := 1.0 / float(maxi(1, _scale))
	return Transform2D(0.0, Vector2(s, s), 0.0, -_offset * s)


static func snap_font_size(size: int) -> int:
	## An odd font size inside a half-scale canvas lands on a half buffer pixel and the
	## glyph rows come out uneven - the text version of fig_scale_H's problem. Route ps()
	## through this and the question stops arising.
	return maxi(2, int(round(float(size) * 0.5)) * 2)


# ---------------------------------------------------------------------------------------
#endregion
#region STAGE LIGHT PARAMETERS
# ---------------------------------------------------------------------------------------


func set_light(p: Dictionary) -> void:
	## Every term the old backdrop stack tuned by hand, in one call. Keys are optional, so
	## a screen that only wants to fade can pass {"fade": x} and leave the room alone.
	if _grade_mat == null:
		return
	for k: String in p.keys():
		_grade_mat.set_shader_parameter(k, p[k])


func set_from_venue(
	v: Dictionary,
	floor_y_design: float,
	streak_hot: float = 0.0,
	darkness: float = 0.0,
	cool: float = 0.0,
	fade: float = 0.0
) -> void:
	## The bridge from venue_data to the shader. `floor_y_design` is stage_floor_y() in
	## Game.gd's own units, converted here so no caller has to know about the buffer.
	##
	## THE POOL STILL ANSWERS A STREAK, which is the half of the stage light the player
	## earns - it tightens and brightens as the run builds, exactly as `hot` did.
	var glow: Color = v.get("glow", Color(1.0, 0.82, 0.5))
	var spot := float(v.get("spot", 0.10))
	var veil := float(v.get("veil", 0.42))
	var fy := clampf(floor_y_design / DESIGN.y, 0.0, 1.0)
	set_light(
		{
			"floor_y": fy,
			"veil": veil,
			"veil_top": 1.55,
			"veil_lip": 0.10,
			"pool_at": Vector2(0.5, fy - 0.30),
			"pool_r": 0.62 - 0.06 * streak_hot,
			"pool_amt": (0.045 + spot * 0.9) * (1.0 + 0.30 * streak_hot),
			"glow_col": Vector3(glow.r, glow.g, glow.b),
			"darkness": darkness,
			"cool": cool,
			"fade": fade,
		}
	)


func set_light_steps(n: int) -> void:
	set_light({"light_steps": maxi(1, n)})


func set_palette(colors: PackedColorArray) -> void:
	## Hand the shader a palette to snap the finished stage to. Pass an empty array to turn
	## the snap off - which is the right thing to do while judging a new generation, since
	## a snapped preview hides how far off-palette the source actually is.
	if _grade_mat == null:
		return
	if colors.is_empty():
		_grade_mat.set_shader_parameter("palette_size", 0)
		return
	_palette_tex = palette_texture(colors)
	_grade_mat.set_shader_parameter("palette_tex", _palette_tex)
	_grade_mat.set_shader_parameter("palette_size", colors.size())


static func palette_texture(colors: PackedColorArray) -> ImageTexture:
	var img := Image.create(maxi(1, colors.size()), 1, false, Image.FORMAT_RGBA8)
	for i in colors.size():
		img.set_pixel(i, 0, colors[i])
	return ImageTexture.create_from_image(img)


# ---------------------------------------------------------------------------------------
#endregion
#region INDEXED COSTUME ART
# ---------------------------------------------------------------------------------------
# Index 0 is transparent, always. After that the map is (region, band) -> slot, so a
# region's shading ramp is contiguous and a costume change is one texture upload of a few
# hundred bytes rather than five blits.

const COSTUME_BANDS := 4  # matches LIMB_BANDS, so a sleeve and its torso agree
const COSTUME_FLOOR := 0.64  # ...and LIMB_FLOOR, for the same reason


static func costume_slot(region: int, band: int, bands: int = COSTUME_BANDS) -> int:
	return 1 + region * bands + clampi(band, 0, bands - 1)


static func pack_costume_indexed(masks: Array, bands: int = COSTUME_BANDS) -> ImageTexture:
	## Take the greyscale region plates the seam already has - one per costume colour, each
	## carrying that region's VALUE the way art_glow_mask's plate does - and fold them into
	## one index map. Paint order is the array order, exactly as art_blit_regions' `regions`
	## argument was: suit, then collar, then vest, then buttons. Getting it wrong still
	## buries the waistcoat under the jacket; it is just one texture that is wrong now
	## instead of four draws.
	var img := pack_costume_index_image(masks, bands)
	if img == null:
		return null
	return ImageTexture.create_from_image(img)


static func pack_costume_index_image(masks: Array, bands: int = COSTUME_BANDS) -> Image:
	if masks.is_empty():
		return null
	var first: Image = masks[0]
	var w := first.get_width()
	var h := first.get_height()
	for r in masks.size():
		var m: Image = masks[r]
		if m.get_width() != w or m.get_height() != h:
			push_error("TossaPixel: costume region %d is a different size" % r)
			return null
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var slot := 0
			for r in masks.size():
				var m: Image = masks[r]
				var c := m.get_pixel(x, y)
				if c.a < 0.5:
					continue
				var val := maxf(c.r, maxf(c.g, c.b))
				slot = costume_slot(r, int(floor(val * float(bands - 1) + 0.5)), bands)
			if slot == 0:
				out.set_pixel(x, y, Color(0, 0, 0, 0))
			else:
				var f := float(slot) / 255.0
				out.set_pixel(x, y, Color(f, f, f, 1.0))
	return out


static func costume_palette_image(
	region_colors: Array, bands: int = COSTUME_BANDS, floor_f: float = COSTUME_FLOOR
) -> Image:
	## The live costume, as a palette. Each region walks its own ramp from `floor_f` of its
	## colour up to the colour itself, which is the same quantised cylinder limb_shade
	## builds - so the jacket, the sleeve and the trouser are lit by one lamp.
	var img := Image.create(256, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for r in region_colors.size():
		var col: Color = region_colors[r]
		for b in bands:
			var f := floor_f + (1.0 - floor_f) * (float(b) / float(maxi(1, bands - 1)))
			var slot := costume_slot(r, b, bands)
			if slot < 256:
				img.set_pixel(slot, 0, Color(col.r * f, col.g * f, col.b * f, 1.0))
	return img


static func make_costume_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = COSTUME_SHADER
	mat.shader = sh
	mat.set_shader_parameter(
		"pal", ImageTexture.create_from_image(Image.create(256, 1, false, Image.FORMAT_RGBA8))
	)
	mat.set_shader_parameter("tint", Color.WHITE)
	return mat


static func set_costume_palette(
	mat: ShaderMaterial,
	region_colors: Array,
	bands: int = COSTUME_BANDS,
	floor_f: float = COSTUME_FLOOR
) -> void:
	## Cheap enough to call every frame: 256 pixels, one upload, no allocation on the GPU
	## side beyond the update. That is what lets the Glow Suit be a palette instead of a
	## branch in draw_juggler, and what lets a venue's costume change without a second asset.
	if mat == null:
		return
	var img := costume_palette_image(region_colors, bands, floor_f)
	var tex: Variant = mat.get_shader_parameter("pal")
	if tex is ImageTexture and (tex as ImageTexture).get_size() == Vector2(256.0, 1.0):
		(tex as ImageTexture).update(img)
	else:
		mat.set_shader_parameter("pal", ImageTexture.create_from_image(img))


static func set_costume_tint(mat: ShaderMaterial, tint: Color) -> void:
	if mat != null:
		mat.set_shader_parameter("tint", tint)


static func make_costume_sprite(index_tex: Texture2D) -> Sprite2D:
	## The shader path, for anything that is allowed to be its own node - the shop preview,
	## the tailor, the SKILLS hub portrait. Set its palette with set_costume_palette on
	## sprite.material and it repaints for free.
	var s := Sprite2D.new()
	s.texture = index_tex
	s.centered = false
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.material = make_costume_material()
	return s


static func bake_costume(
	index_img: Image,
	region_colors: Array,
	bands: int = COSTUME_BANDS,
	floor_f: float = COSTUME_FLOOR
) -> ImageTexture:
	## THE FIGURE'S PATH, and the one that replaces art_blit_regions. draw_juggler draws the
	## body in the same _draw as the limbs, and Godot has no per-command material, so the
	## costume shader cannot be switched on for one draw_texture_rect and off again - it
	## would repaint everything in that canvas item. Doing the palette lookup on the CPU
	## gives the same picture as a plain texture with no material at all.
	##
	## This is not a per-frame call and does not need to be: the costume changes when the
	## player buys something or the venue changes, which is a few times a run. Cache the
	## result beside the wardrobe state and rebake on that change.
	if index_img == null:
		return null
	var pal := costume_palette_image(region_colors, bands, floor_f)
	var w := index_img.get_width()
	var h := index_img.get_height()
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var lut: Array[Color] = []
	lut.resize(256)
	for i in 256:
		lut[i] = pal.get_pixel(i, 0)
	for y in h:
		for x in w:
			var src := index_img.get_pixel(x, y)
			if src.a < 0.5:
				out.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			out.set_pixel(x, y, lut[clampi(int(round(src.r * 255.0)), 0, 255)])
	return ImageTexture.create_from_image(out)


static func draw_costume(ci: CanvasItem, baked: Texture2D, box: Rect2) -> void:
	## art_blit_regions' replacement: one call, all five colours, and no all-or-nothing rule
	## to enforce because there is no way to be half-served. `baked` comes from bake_costume.
	if ci == null or baked == null:
		return
	ci.draw_texture_rect(baked, box, false)


# ---------------------------------------------------------------------------------------
#endregion
#region LIMBS
# ---------------------------------------------------------------------------------------
# draw_capsule_pix rasterises an arm by hand, one draw_rect per art row, shading each row by
# solving where the band boundaries fall - about 35 rects and a per-row band walk per
# segment. It exists because a limb STRETCHES every frame (bones are maxf(46.0, reach*0.56))
# so it cannot be a fixed sprite, and because the art grid had to be enforced in game code.
#
# Inside the buffer, neither reason survives. The grid is the framebuffer's, and the shading
# is a one-dimensional ramp ACROSS the limb - which is a texture coordinate. So: one convex
# polygon, UVs running 0..1 across the limb's own axis, sampling a banded ramp. One draw
# call, any angle, any length, the same look.

const LIMB_BANDS := 4
const LIMB_FLOOR := 0.64
const LIMB_LIGHT_U := -0.42

var _limb_ramps: Dictionary = {}


func limb_ramp(
	bands: int = LIMB_BANDS, floor_f: float = LIMB_FLOOR, light_u: float = LIMB_LIGHT_U
) -> ImageTexture:
	## The quantised cylinder, as a 1 x 64 texture. Same formula as limb_shade, so an arm
	## and the torso beside it are still lit by the same lamp from the same direction - the
	## thing LIMB_BANDS / LIMB_FLOOR / LIMB_LIGHT_U were written to keep true.
	var key := "%d|%.3f|%.3f" % [bands, floor_f, light_u]
	if _limb_ramps.has(key):
		return _limb_ramps[key]
	var n := 64
	var img := Image.create(1, n, false, Image.FORMAT_RGBA8)
	for i in n:
		var u := -1.0 + 2.0 * (float(i) + 0.5) / float(n)
		var lam := clampf(cos(u * (PI * 0.5) - light_u * (PI * 0.5)) * 0.5 + 0.5, 0.0, 1.0)
		var q := clampf(floor(lam * float(bands)), 0.0, float(bands - 1))
		var f := floor_f + (1.0 - floor_f) * (q / float(maxi(1, bands - 1)))
		img.set_pixel(0, i, Color(f, f, f, 1.0))
	var tex := ImageTexture.create_from_image(img)
	_limb_ramps[key] = tex
	return tex


static func limb_points(a: Vector2, b: Vector2, wa: float, wb: float, segs: int = 7) -> Dictionary:
	## The capsule's outline, plus the UV that says how far across the limb each vertex is.
	## Deliberately the same shape draw_capsule builds - the quad plus two end discs - and
	## not the convex hull of the discs, so a taper looks identical to the old version and
	## the two can be held against each other.
	var ra := wa * 0.5
	var rb := wb * 0.5
	var d := b - a
	var seg_len := d.length()
	var dir := (d / seg_len) if seg_len > 0.001 else Vector2.RIGHT
	var n := Vector2(-dir.y, dir.x)
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	# round the a end, from +n (u = 1) back through -dir to -n (u = 0)
	for i in segs + 1:
		var ang := PI * 0.5 + PI * float(i) / float(segs)
		var off := dir * cos(ang) + n * sin(ang)
		pts.append(a + off * ra)
		uvs.append(Vector2(0.5, sin(ang) * 0.5 + 0.5))
	# ...then the b end, from -n (u = 0) through +dir to +n (u = 1)
	for i in segs + 1:
		var ang2 := -PI * 0.5 + PI * float(i) / float(segs)
		var off2 := dir * cos(ang2) + n * sin(ang2)
		pts.append(b + off2 * rb)
		uvs.append(Vector2(0.5, sin(ang2) * 0.5 + 0.5))
	return {"points": pts, "uvs": uvs}


func draw_limb(
	ci: CanvasItem,
	a: Vector2,
	b: Vector2,
	wa: float,
	wb: float,
	col: Color,
	bands: int = LIMB_BANDS,
	floor_f: float = LIMB_FLOOR,
	light_u: float = LIMB_LIGHT_U
) -> void:
	## draw_capsule_pix's replacement. Same silhouette, same banding, one call.
	if ci == null or col.a <= 0.004:
		return
	var g := limb_points(a, b, wa, wb)
	ci.draw_colored_polygon(g["points"], col, g["uvs"], limb_ramp(bands, floor_f, light_u))


# ---------------------------------------------------------------------------------------
#endregion
#region THE QUANTISER
# ---------------------------------------------------------------------------------------
# The offline half of the palette. The shader snap keeps the RUNNING game on palette; this
# puts the assets on it, which is the version that matters because it is what an artist
# then edits. Nearest colour, no dithering: dithering is how photographs are reduced, and it
# is exactly wrong for flat pixel art - it turns a clean fill into noise that then shimmers
# the moment the object moves.


static func nearest_in_palette(c: Color, colors: PackedColorArray) -> Color:
	## Green-weighted, because the eye is: an unweighted distance sends the house golds to
	## whichever neutral happens to be nearest in raw RGB. The shader's snap_to_palette uses
	## the same weights, so a snapped frame and a quantised asset agree.
	var best := INF
	var pick := c
	for p: Color in colors:
		var dr := p.r - c.r
		var dg := p.g - c.g
		var db := p.b - c.b
		var m := dr * dr * 0.30 + dg * dg * 0.59 + db * db * 0.11
		if m < best:
			best = m
			pick = p
	return pick


static func quantize_image(img: Image, colors: PackedColorArray, alpha_cut: float = 0.5) -> Image:
	var out := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
	var cache: Dictionary = {}
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a < alpha_cut:
				out.set_pixel(x, y, Color(0, 0, 0, 0))  # hard alpha, never a feathered rim
				continue
			var key := c.to_rgba32()
			if cache.has(key):
				out.set_pixel(x, y, cache[key])
				continue
			var pick := nearest_in_palette(c, colors)
			var solid := Color(pick.r, pick.g, pick.b, 1.0)
			cache[key] = solid
			out.set_pixel(x, y, solid)
	return out


static func quantize_file(
	path_in: String, path_out: String, colors: PackedColorArray = PackedColorArray()
) -> bool:
	var cols := colors if not colors.is_empty() else palette()
	var img := Image.load_from_file(path_in)
	if img == null:
		push_error("TossaPixel: cannot read %s" % path_in)
		return false
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	return quantize_image(img, cols).save_png(path_out) == OK


static func quantize_folder(dir_path: String, suffix: String = "") -> int:
	## --quantize <dir>: walk a folder of generated art and put all of it on the palette.
	## With no suffix it overwrites in place, which is what you want once you trust it and
	## is why it prints a count rather than staying silent.
	var cols := palette()
	var d := DirAccess.open(dir_path)
	if d == null:
		push_error("TossaPixel: cannot open %s" % dir_path)
		return 0
	var n := 0
	for f in d.get_files():
		if not f.to_lower().ends_with(".png"):
			continue
		var src := dir_path.path_join(f)
		var dst := src if suffix == "" else dir_path.path_join(f.get_basename() + suffix + ".png")
		if quantize_file(src, dst, cols):
			n += 1
	print("art: quantised %d file(s) in %s to a %d-colour palette" % [n, dir_path, cols.size()])
	return n


static func palette_report(img: Image, colors: PackedColorArray) -> Dictionary:
	## How far off-palette a generation actually is, before anything is snapped. Run it on a
	## fresh backdrop: a large `max_dist` means the room will visibly shift when quantised,
	## which is the moment to re-prompt rather than to accept and repaint later.
	var worst := 0.0
	var total := 0.0
	var n := 0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a < 0.5:
				continue
			var best := INF
			for p: Color in colors:
				var dr := p.r - c.r
				var dg := p.g - c.g
				var db := p.b - c.b
				best = minf(best, dr * dr * 0.30 + dg * dg * 0.59 + db * db * 0.11)
			best = sqrt(best)
			worst = maxf(worst, best)
			total += best
			n += 1
	return {"max_dist": worst, "mean_dist": total / float(maxi(1, n)), "pixels": n}


# ---------------------------------------------------------------------------------------
#endregion
#region GRID COMPAT
# ---------------------------------------------------------------------------------------
# Forwards for the hand-rolled rasterisers, so Game.gd can be ported in one pass and the
# old bodies deleted in the next. Every one of these is now what it would have been if the
# game had always rendered at its own resolution: an engine primitive.
#
# Keep the ANTIALIASED flags off. It is the default for polygons and rects, but draw_circle
# and draw_arc both take the flag and both default to false - which is right here, and worth
# knowing before someone "fixes" a jagged edge by turning it on.


static func art_snap(v: Vector2) -> Vector2:
	return v  # the framebuffer is the grid now


static func fill_disc(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	if col.a > 0.004 and r > 0.0:
		ci.draw_circle(c, r, col)


static func draw_ring(ci: CanvasItem, c: Vector2, r: float, w: float, col: Color) -> void:
	if col.a > 0.004 and r > 0.0:
		ci.draw_arc(c, r, 0.0, TAU, maxi(12, int(r)), col, w, false)


static func draw_arc_band(
	ci: CanvasItem, c: Vector2, r: float, thick: float, b0: float, b1: float, col: Color
) -> void:
	## draw_arc_pix's replacement, and the analytic span solve goes with it. The crowd dial's
	## zones are crisp because the buffer has no room for a fringe, not because the code
	## refuses to draw one.
	if col.a > 0.004 and r > 0.0:
		ci.draw_arc(c, r, b0, b1, maxi(8, int(r)), col, thick, false)


static func draw_spoke(
	ci: CanvasItem, c: Vector2, ang: float, r0: float, r1: float, w: float, col: Color
) -> void:
	var d := Vector2(cos(ang), sin(ang))
	ci.draw_line(c + d * r0, c + d * r1, col, w, false)


static func fill_poly(ci: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	if pts.size() >= 3:
		ci.draw_colored_polygon(pts, col)


static func fill_ellipse(
	ci: CanvasItem, c: Vector2, rx: float, ry: float, rot: float, col: Color, segs: int = 24
) -> void:
	var pts := PackedVector2Array()
	for i in segs:
		var a := TAU * float(i) / float(segs)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	ci.draw_colored_polygon(pts, col)


static func draw_glow_banded(
	ci: CanvasItem, c: Vector2, r: float, col: Color, steps: int = 4
) -> void:
	## The prop halo, still banded, still four steps - GLOW_PIX_STEPS' note holds and its
	## reasoning is unchanged: at five or more the steps read as a gradient again, which is
	## the thing being avoided. What is gone is the per-row rect fill underneath it.
	if col.a <= 0.004 or r <= 0.0:
		return
	for i in steps:
		var t := float(i) / float(steps)
		var br := r * (1.0 - t * 0.72)
		if br < 1.0:
			continue
		ci.draw_circle(c, br, Color(col.r, col.g, col.b, col.a * (0.14 + 0.86 * pow(t, 1.7))))


static func prop_zoom(sc: float, prop_scale: float) -> float:
	## art_prop_zoom rounded to a whole magnification because a fractional one drew a club's
	## pixels at 6.4 screen px beside a ball's at 4. In the buffer a prop sprite is blitted
	## at 1:1 and the window scale is the only magnification there is, so the zoom is free to
	## be exactly what the caller asked for. Kept as a function, and kept honest about it,
	## because the shop's PROP_ICON_MAG still wants a clean 3x and should say so.
	return sc / maxf(prop_scale, 0.001)


#endregion


class HudProxy:
	extends Node2D
	## A canvas that hands its own _draw back to the host. Used for HUD_FULLRES, where the
	## HUD has to live in a CanvasLayer at window resolution while the code that draws it
	## stays in Game.gd. The host implements:  func draw_hud_layer(ci: CanvasItem) -> void
	var target: Object = null
	var method := ""

	func _draw() -> void:
		if target != null and method != "" and target.has_method(method):
			target.call(method, self)


class InputBridge:
	extends Node
	## WITHOUT THIS THE GAME HAS NO KEYS. A SubViewport only receives input when something
	## hands it some: a SubViewportContainer does that, a bare SubViewport parented to a
	## Node2D does not. So the whole game would render perfectly and ignore every press.
	##
	## Mouse events are moved into buffer coordinates on the way in, so a click still lands
	## where it looks like it landed once the letterbox and the integer scale are accounted
	## for. Keys need no transform and are passed straight through.
	var pix: TossaPixel = null

	func _input(event: InputEvent) -> void:
		if pix == null or pix.stage_vp == null:
			return
		var ev := event
		if (
			event is InputEventMouse
			or event is InputEventScreenTouch
			or event is InputEventScreenDrag
		):
			ev = event.xformed_by(pix.screen_to_buffer_xform())
		pix.stage_vp.push_input(ev, true)
