// Floating rock under the islands: warm sandstone strata, darker towards
// the tip (local y goes from 0 at the top to minus the depth).
shader_type spatial;
render_mode specular_disabled;

#include "res://shaders/noise.gdshaderinc"

uniform vec3 stone_a : source_color = vec3(0.72, 0.56, 0.4);
uniform vec3 stone_b : source_color = vec3(0.52, 0.38, 0.3);

varying vec3 wp;
varying float depth;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	depth = clamp(-VERTEX.y / 11.0, 0.0, 1.0);
}

void fragment() {
	float wobble = noise2(wp.xz * 0.4) * 2.0;
	float band = 0.5 + 0.5 * sin(wp.y * 2.6 + wobble);
	vec3 c = mix(stone_a, stone_b, band);
	c *= 0.82 + 0.3 * noise2(vec2(wp.x + wp.z, wp.y) * 2.3);
	c *= mix(1.0, 0.45, depth);
	ALBEDO = c;
	ROUGHNESS = 0.92;
}
