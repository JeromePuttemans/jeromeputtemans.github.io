// Sea of clouds far below the islands: slow fbm swells lit by the sun's
// colour, fading into the fog.
shader_type spatial;
render_mode unshaded;

#include "res://shaders/noise.gdshaderinc"

uniform vec3 light_color : source_color = vec3(1.0, 0.95, 0.9);
uniform vec3 shade_color : source_color = vec3(0.55, 0.6, 0.75);

varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = wp.xz * 0.012;
	float n = fbm2(uv + vec2(TIME * 0.004, TIME * 0.002));
	float m = fbm2(uv * 3.0 - vec2(TIME * 0.01, 0.0));
	float v = smoothstep(0.25, 0.85, n * 0.7 + m * 0.4);
	ALBEDO = mix(shade_color, light_color, v);
}
