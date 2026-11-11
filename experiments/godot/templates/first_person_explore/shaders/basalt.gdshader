// Black stones (gnomons): dark speckled basalt with a glowing gold line
// every two metres, so they read at once as the stones that cast shadows.
shader_type spatial;

#include "res://shaders/noise.gdshaderinc"

uniform vec3 gold : source_color = vec3(1.0, 0.72, 0.28);
uniform float glow = 1.6;

varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float n = noise2(wp.xz * 3.0 + vec2(wp.y * 2.0));
	vec3 c = vec3(0.07, 0.07, 0.1) * (0.75 + 0.5 * n);
	float line = smoothstep(0.455, 0.49, abs(fract(wp.y * 0.5) - 0.5));
	ALBEDO = mix(c, gold * 0.4, line);
	EMISSION = gold * line * glow;
	ROUGHNESS = 0.42;
}
