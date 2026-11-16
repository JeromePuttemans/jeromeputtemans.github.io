// Mist far below the platforms: slow pale swells into which the pilotis
// disappear, lit by the colour of the hour and lost in the fog.
shader_type spatial;
render_mode unshaded;

#include "res://shaders/noise.gdshaderinc"

uniform vec3 light_color : source_color = vec3(0.96, 0.96, 0.95);
uniform vec3 shade_color : source_color = vec3(0.84, 0.85, 0.88);

varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = wp.xz * 0.01;
	float n = fbm2(uv + vec2(TIME * 0.003, TIME * 0.0015));
	float m = fbm2(uv * 3.0 - vec2(TIME * 0.008, 0.0));
	ALBEDO = mix(shade_color, light_color, smoothstep(0.3, 0.8, n * 0.7 + m * 0.4));
}
