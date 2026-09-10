shader_type canvas_item;
render_mode unshaded;
uniform float strength = 1.0;
uniform vec2 stage_size = vec2(1280.0, 720.0);
varying vec2 stage_position;
void vertex() { stage_position = VERTEX; }
void fragment() {
	vec4 source = texture(TEXTURE, UV) * COLOR;
	// A broad, quiet colour field behind the juggling lane, on the same 2px art grid.
	// This changes scenery contrast only; it creates neither light cones nor prop glow.
	vec2 at = (floor(stage_position / 2.0) * 2.0) / stage_size;
	float lane = (1.0 - smoothstep(0.16, 0.34, abs(at.x - 0.5))) *
		(1.0 - smoothstep(0.72, 0.88, at.y));
	float amount = lane * strength;
	float luma = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	vec3 quiet = mix(vec3(luma), source.rgb, 0.65) * 0.70 + vec3(0.025, 0.023, 0.030);
	COLOR = vec4(mix(source.rgb, quiet, amount), source.a);
}
