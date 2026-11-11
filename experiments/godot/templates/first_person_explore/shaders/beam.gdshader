// Columns of light (seals, return beams): additive, brighter at the base,
// with bands rising along the column. Local y goes from 0 to `height`.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform vec3 color : source_color = vec3(1.0, 0.8, 0.45);
uniform float height = 40.0;
uniform float strength = 0.5;

varying float ly;

void vertex() {
	ly = VERTEX.y / height + 0.5;
}

void fragment() {
	float fade = pow(1.0 - clamp(ly, 0.0, 1.0), 1.6);
	float bands = 0.75 + 0.25 * sin(ly * 60.0 - TIME * 4.0);
	float facing = abs(dot(NORMAL, VIEW));
	ALBEDO = color * fade * bands * strength * (0.4 + 0.6 * facing);
}
