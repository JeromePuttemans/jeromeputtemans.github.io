// Columns of light (seal markers, return beams): blended, not added, so they
// stay visible against a white sky. Bands rise along the column and the
// rim is denser than the middle, like a glass tube. Local y goes from
// minus height / 2 to height / 2.
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;

uniform vec3 color : source_color = vec3(1.0, 0.38, 0.1);
uniform float height = 40.0;
uniform float strength = 0.5;

varying float ly;

void vertex() {
	ly = VERTEX.y / height + 0.5;
}

void fragment() {
	float fade = pow(1.0 - clamp(ly, 0.0, 1.0), 1.4);
	float bands = 0.65 + 0.35 * step(0.5, fract(ly * height * 0.5 - TIME * 0.8));
	float facing = abs(dot(NORMAL, VIEW));
	ALBEDO = color;
	ALPHA = clamp(fade * bands * strength * (0.4 + 0.6 * (1.0 - facing)), 0.0, 1.0);
}
