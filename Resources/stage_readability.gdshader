shader_type canvas_item;
render_mode unshaded;
#include "res://Resources/shaders/simplex_noise.gdshaderinc"

uniform float strength = 1.0;
uniform vec2 stage_size = vec2(1280.0, 720.0);
uniform vec4 house_light : source_color = vec4(1.0, 0.72, 0.4, 1.0);
uniform float house_veil = 0.42;
uniform float atmosphere_time = 0.0;
uniform float motion_amount = 1.0;
uniform float outdoor = 0.0;
uniform float midnight = 0.0;
varying vec2 stage_position;
varying vec4 vertex_tint;

void vertex() {
	stage_position = VERTEX;
	vertex_tint = COLOR;
}

void fragment() {
	vec2 at = floor(stage_position / 2.0) * 2.0 / stage_size;
	// Adapted from GDQuest wind_uv: sine displacement weighted from a pinned root.
	// Only the backyard foliage moves; architecture and the ground stay fixed.
	float foliage = outdoor * (1.0 - smoothstep(0.14, 0.24, at.x)) *
		smoothstep(0.16, 0.30, at.y) * (1.0 - smoothstep(0.58, 0.78, at.y));
	float wind = floor(sin(atmosphere_time * 0.7 + at.y * 5.0) * 1.5 * foliage * motion_amount);
	vec2 sample_uv = UV + vec2(wind * 2.0 / stage_size.x, 0.0);
	vec4 source = texture(TEXTURE, sample_uv) * vertex_tint;
	float lane = (1.0 - smoothstep(0.13, 0.32, abs(at.x - 0.5))) *
		(1.0 - smoothstep(0.76, 0.90, at.y));
	float edge = smoothstep(0.25, 0.60, length((at - 0.5) * vec2(0.85, 1.0)));
	float floor_area = smoothstep(0.80, 0.90, at.y);
	float veil = house_veil * mix(0.42, 0.95, lane) * (1.0 - floor_area * 0.65);
	vec3 room = source.rgb * (1.0 - veil) * (1.0 - edge * 0.16);
	float luma = dot(room, vec3(0.299, 0.587, 0.114));
	room = mix(room, mix(vec3(luma), room, 0.82) * 0.82, lane);
	// Thin drifting air catches the room's existing lamps, at the wings only.
	float mist = smoothstep(-0.4, 0.75, snoise(at * vec2(4.0, 7.0) +
		vec2(atmosphere_time * 0.025, -atmosphere_time * 0.012)));
	float air = mist * (1.0 - lane) * sin(clamp(at.y, 0.0, 1.0) * 3.141593);
	room += house_light.rgb * air * 0.026 * (1.0 - midnight);
	room *= mix(1.0, 0.50, midnight);
	COLOR = vec4(mix(source.rgb, room, strength), source.a);
}
