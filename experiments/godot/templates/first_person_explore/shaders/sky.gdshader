// Sky: a pale void, from a white horizon to a cool grey zenith, a small
// white sun with a soft halo, and stars when `night` rises (ending).
// Sun.gd sets the colours for the current hour; they stay almost
// colourless, only warmed a little at dawn and dusk.
shader_type sky;

uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 zenith_color : source_color = vec3(0.8, 0.82, 0.86);
uniform vec3 horizon_color : source_color = vec3(0.95, 0.95, 0.94);
uniform vec3 low_color : source_color = vec3(0.9, 0.9, 0.9);
uniform vec3 sun_color : source_color = vec3(1.0, 0.98, 0.94);
uniform float night = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float h = d.y;
	vec3 col;
	if (h >= 0.0) {
		col = mix(horizon_color, zenith_color, pow(h, 0.6));
	} else {
		col = mix(horizon_color, low_color, clamp(pow(-h, 0.5) * 1.4, 0.0, 1.0));
	}
	vec3 sd = normalize(sun_dir);
	float s = max(dot(d, sd), 0.0);
	float flat_s = max(dot(normalize(vec2(d.x, d.z) + 1e-4), normalize(vec2(sd.x, sd.z) + 1e-4)), 0.0);
	col = mix(col, col * sun_color, pow(flat_s, 3.0) * (1.0 - smoothstep(0.0, 0.5, h)) * 0.6);
	col += sun_color * (pow(s, 8.0) * 0.1 + pow(s, 150.0) * 0.45) * (1.0 - night);
	float disc = smoothstep(0.99945, 0.9997, s);
	col = mix(col, sun_color * 1.9, disc * (1.0 - night));
	if (night > 0.0 && h > 0.0) {
		vec3 cell = floor(d * 260.0);
		float star = hash(cell.xy + cell.z * 17.31);
		col += vec3(smoothstep(0.9968, 1.0, star)) * night * 1.4 * smoothstep(0.0, 0.25, h);
	}
	COLOR = col;
}
