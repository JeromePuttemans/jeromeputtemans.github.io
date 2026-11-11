// Island top: patches of green and golden grass on the flat face, a band of
// earth on the rim.
shader_type spatial;
render_mode specular_disabled;

#include "res://shaders/noise.gdshaderinc"

uniform vec3 grass_a : source_color = vec3(0.36, 0.5, 0.2);
uniform vec3 grass_b : source_color = vec3(0.66, 0.62, 0.3);
uniform vec3 earth : source_color = vec3(0.42, 0.3, 0.2);

varying vec3 wp;
varying vec3 wn;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float n = fbm2(wp.xz * 0.3);
	float m = noise2(wp.xz * 3.1);
	vec3 c = mix(grass_a, grass_b, smoothstep(0.38, 0.72, n));
	c *= 0.86 + 0.24 * m;
	float side = 1.0 - smoothstep(0.4, 0.8, wn.y);
	vec3 soil = earth * (0.8 + 0.3 * noise2(wp.xy * 4.0 + wp.zy * 4.0));
	ALBEDO = mix(c, soil, side);
	ROUGHNESS = 0.95;
}
