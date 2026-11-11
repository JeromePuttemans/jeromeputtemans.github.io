// Sky: gradient from the horizon to the zenith, sun disc and halo, drifting
// clouds, and stars when `night` rises (ending). Sun.gd sets the colours
// for the current hour.
shader_type sky;

uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 zenith_color : source_color = vec3(0.25, 0.45, 0.85);
uniform vec3 horizon_color : source_color = vec3(0.8, 0.85, 0.95);
uniform vec3 low_color : source_color = vec3(0.55, 0.6, 0.75);
uniform vec3 sun_color : source_color = vec3(1.0, 0.95, 0.85);
uniform float night = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float h = d.y;
	vec3 col;
	if (h >= 0.0) {
		col = mix(horizon_color, zenith_color, pow(h, 0.5));
	} else {
		col = mix(horizon_color, low_color, clamp(pow(-h, 0.6) * 1.5, 0.0, 1.0));
	}
	float s = max(dot(d, normalize(sun_dir)), 0.0);
	col += sun_color * (pow(s, 6.0) * 0.16 + pow(s, 64.0) * 0.35) * (1.0 - night);
	float disc = smoothstep(0.9992, 0.9996, s);
	col = mix(col, sun_color * 2.6, disc * (1.0 - night));
	if (h > 0.0) {
		vec2 uv = d.xz / (h + 0.12) * 0.9 + vec2(TIME * 0.006, TIME * 0.002);
		float n = fbm(uv * 1.5);
		float c = smoothstep(0.55, 0.85, n) * smoothstep(0.0, 0.2, h);
		vec3 cloud = mix(horizon_color * 1.08, vec3(1.0), 0.4) + sun_color * pow(s, 5.0) * 0.4;
		col = mix(col, cloud * (1.0 - night * 0.85), c * 0.65);
		if (night > 0.0) {
			vec3 cell = floor(d * 240.0);
			float star = hash(cell.xy + cell.z * 17.31);
			col += vec3(smoothstep(0.9965, 1.0, star)) * night * 1.5 * smoothstep(0.0, 0.2, h) * (1.0 - c);
		}
	}
	COLOR = col;
}
