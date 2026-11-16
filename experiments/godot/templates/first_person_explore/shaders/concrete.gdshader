// White architectural concrete: a faint grain, formwork joints and tie
// holes (faded out with distance, so they never shimmer), and a sky light
// from above that leaves undersides and soffits a soft grey. Below
// fade_top, the surface darkens over fade_len metres (the Oculus well).
shader_type spatial;

#include "res://shaders/noise.gdshaderinc"

uniform vec3 base : source_color = vec3(0.9, 0.895, 0.88);
uniform vec2 panel = vec2(2.4, 1.2);
uniform float detail = 1.0;
uniform float fade_top = -100000.0;
uniform float fade_len = 1.0;

varying vec3 wp;
varying vec3 wn;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 uv = abs(wn.y) > 0.6 ? wp.xz : vec2(wp.x * abs(wn.z) + wp.z * abs(wn.x), wp.y);
	float grain = noise2(uv * 11.0) * 0.5 + noise2(uv * 37.0) * 0.5;
	float cloud = fbm2(uv * 0.3);
	vec3 c = base * (0.97 + 0.03 * grain + 0.04 * (cloud - 0.5));
	vec2 cell = uv / panel;
	vec2 fw = fwidth(cell);
	float lod = clamp(1.0 - max(fw.x * panel.x, fw.y * panel.y) * 7.0, 0.0, 1.0) * detail;
	vec2 to_joint = (0.5 - abs(fract(cell) - 0.5)) * panel;
	float joint = 1.0 - smoothstep(0.0, 0.012 + max(fw.x * panel.x, fw.y * panel.y), min(to_joint.x, to_joint.y));
	vec2 q = (fract(cell * 2.0) - 0.5) * panel * 0.5;
	float hole = 1.0 - smoothstep(0.012, 0.022, length(q));
	c *= 1.0 - lod * (joint * 0.07 + hole * 0.22);
	float sky = mix(0.58, 1.0, wn.y * 0.5 + 0.5);
	float well = clamp((fade_top - wp.y) / fade_len, 0.0, 1.0);
	ALBEDO = c * sky * mix(1.0, 0.03, well);
	ROUGHNESS = 0.9;
	SPECULAR = 0.2;
}
