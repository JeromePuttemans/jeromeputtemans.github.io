// Black stones: matte graphite with a fine grain and a soft sheen. In a
// white world they are the only dark volumes, so they read at once as the
// stones that cast solid shadows.
shader_type spatial;

#include "res://shaders/noise.gdshaderinc"

uniform vec3 base : source_color = vec3(0.05, 0.05, 0.055);

varying vec3 wp;
varying vec3 wn;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 uv = abs(wn.y) > 0.6 ? wp.xz : vec2(wp.x * abs(wn.z) + wp.z * abs(wn.x), wp.y);
	float g = noise2(uv * 13.0) * 0.6 + noise2(uv * 41.0) * 0.4;
	ALBEDO = base * (0.85 + 0.3 * g) * mix(0.75, 1.0, wn.y * 0.5 + 0.5);
	ROUGHNESS = 0.5;
	SPECULAR = 0.35;
}
