// Solid shadows: graphite glass hatched with fine diagonal lines, like the
// shade on an architect's drawing. The edge ribbon uses the same shader
// with `edge` set: a light outline that turns to the accent colour while
// the hour moves. Inside a cloud's shade (cloud_a, cloud_b: x, z, radius;
// negative radius = none) the shadow is cut out, with an accent rim.
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

uniform vec4 tint : source_color = vec4(0.085, 0.085, 0.095, 0.9);
uniform vec3 line_color : source_color = vec3(0.93, 0.93, 0.91);
uniform vec3 accent : source_color = vec3(1.0, 0.38, 0.1);
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
	float near_cloud = 1.0 - smoothstep(0.0, 0.6, d);
	if (edge > 0.5) {
		ALBEDO = mix(line_color, accent, clamp(pulse * 0.9 + near_cloud, 0.0, 1.0));
		ALPHA = 0.95;
	} else {
		float u = (wp.x + wp.z) * 3.2;
		float fw = fwidth(u);
		float l = abs(fract(u) - 0.5);
		float hatch = (1.0 - smoothstep(0.05, 0.05 + fw * 1.2, l)) * clamp(1.0 - fw * 2.2, 0.0, 1.0);
		vec3 c = tint.rgb + vec3(0.06 + pulse * 0.05) * hatch;
		ALBEDO = mix(c, accent, near_cloud * 0.9);
		ALPHA = mix(tint.a, 1.0, near_cloud);
	}
}
