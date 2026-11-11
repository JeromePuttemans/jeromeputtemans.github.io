// Solid shadows: deep indigo glass with drifting light and sparkles. The
// edge ribbon uses the same shader with `edge` set: a gold outline. Inside
// a cloud's shade (cloud_a, cloud_b: x, z, radius; negative radius = none)
// the shadow is cut out, with a glowing rim.
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

#include "res://shaders/noise.gdshaderinc"

uniform vec4 tint : source_color = vec4(0.07, 0.05, 0.2, 0.8);
uniform vec3 rim : source_color = vec3(1.0, 0.78, 0.4);
uniform float edge = 0.0;
uniform float pulse = 0.0;
uniform vec3 cloud_a = vec3(0.0, 0.0, -1.0);
uniform vec3 cloud_b = vec3(0.0, 0.0, -1.0);

varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float d = min(length(wp.xz - cloud_a.xy) - cloud_a.z, length(wp.xz - cloud_b.xy) - cloud_b.z);
	if (d < 0.0) {
		discard;
	}
	float near_cloud = 1.0 - smoothstep(0.0, 0.7, d);
	if (edge > 0.5) {
		ALBEDO = rim * (1.2 + pulse * 0.8);
		ALPHA = 0.9;
	} else {
		float n = noise2(wp.xz * 0.9 + vec2(TIME * 0.25, -TIME * 0.18));
		float sparkle = step(0.994, hash2(floor(wp.xz * 11.0) + vec2(floor(TIME * 3.0))));
		vec3 c = tint.rgb + vec3(0.12, 0.1, 0.3) * n * 0.6 + rim * sparkle * 0.5;
		c += rim * near_cloud * 0.9 + rim * pulse * 0.08;
		ALBEDO = c;
		ALPHA = tint.a;
	}
}
