class_name PostFX
extends ColorRect

# PostFX: one full-screen shader over the world, under the HUD (CanvasLayer 1).
# It reads what the world drew (hint_screen_texture) and bends it:
#   RIPPLES     up to four rings that grow from a point and push the pixels
#               outward as they pass: the release wave, the Nova, a boss
#               dying. A ring is (centre in 0..1, radius in screen heights,
#               strength); it grows at its speed and fades as it widens.
#   ABERRATION  red and blue sampled apart from the centre outward: a hit,
#               a Nova. Decays on its own.
#   VIGNETTE    darker corners; "danger" tints them red (last hull point).
# Positions are given in arena pixels (1280 x 720) and converted here.

const MAX_RIPPLES: int = 4

const SHADER_CODE: String = """
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform vec4 ripple0 = vec4(0.0);
uniform vec4 ripple1 = vec4(0.0);
uniform vec4 ripple2 = vec4(0.0);
uniform vec4 ripple3 = vec4(0.0);
uniform float aspect = 1.7778;
uniform float ring_width = 0.07;
uniform float aberration = 0.0;
uniform float vignette = 0.45;
uniform float danger = 0.0;

vec2 ripple_offset(vec2 uv, vec4 r) {
	if (r.w <= 0.0) {
		return vec2(0.0);
	}
	vec2 d = uv - r.xy;
	d.x *= aspect;
	float dist = length(d);
	float x = (dist - r.z) / ring_width;
	if (abs(x) >= 1.0) {
		return vec2(0.0);
	}
	float wave = sin(x * 3.14159) * (1.0 - abs(x));
	vec2 dir = d / max(dist, 0.0001);
	dir.x /= aspect;
	return -dir * wave * r.w;
}

void fragment() {
	vec2 uv = UV;
	vec2 off = ripple_offset(uv, ripple0) + ripple_offset(uv, ripple1)
			+ ripple_offset(uv, ripple2) + ripple_offset(uv, ripple3);
	// UV spans the rect, SCREEN_UV the window: convert the offsets.
	vec2 scale = fwidth(SCREEN_UV) / max(fwidth(UV), vec2(0.000001));
	vec2 suv = SCREEN_UV + off * scale;
	vec2 from_center = uv - vec2(0.5);
	vec2 ab = from_center * aberration * scale;
	vec3 col;
	col.r = texture(screen_tex, suv + ab).r;
	col.g = texture(screen_tex, suv).g;
	col.b = texture(screen_tex, suv - ab).b;
	float edge = smoothstep(0.32, 0.78, length(from_center * vec2(1.0, 0.8)));
	col *= 1.0 - edge * vignette;
	col = mix(col, vec3(0.85, 0.06, 0.12), edge * danger * 0.55);
	COLOR = vec4(col, 1.0);
}
"""

var arena: Vector2 = Vector2(1280.0, 720.0)
var danger: float = 0.0

var _ripples: Array[Dictionary] = []
var _aberration: float = 0.0
var _mat: ShaderMaterial = null

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = SHADER_CODE
	_mat = ShaderMaterial.new()
	_mat.shader = shader
	material = _mat
	color = Color.WHITE

## A ring of distortion growing from `at` (arena pixels). strength is the
## pixel push as a share of the screen (0.01 = subtle, 0.03 = strong).
func ripple(at: Vector2, strength: float, speed: float = 1.1, reach: float = 0.7) -> void:
	if _ripples.size() >= MAX_RIPPLES:
		_ripples.remove_at(0)
	_ripples.append({uv = at / arena, r = 0.0, strength = strength, speed = speed, reach = reach})

func aberrate(amount: float) -> void:
	_aberration = clampf(maxf(_aberration, amount), 0.0, 0.014)

func clear() -> void:
	_ripples.clear()
	_aberration = 0.0
	danger = 0.0

func step(delta: float) -> void:
	for i in range(_ripples.size() - 1, -1, -1):
		var r: Dictionary = _ripples[i]
		r["r"] = float(r["r"]) + float(r["speed"]) * delta
		if float(r["r"]) >= float(r["reach"]):
			_ripples.remove_at(i)
	_aberration = maxf(_aberration - delta * 0.04, 0.0)
	for k in MAX_RIPPLES:
		var v := Vector4.ZERO
		if k < _ripples.size():
			var r2: Dictionary = _ripples[k]
			var uv: Vector2 = r2["uv"] as Vector2
			var fade: float = 1.0 - float(r2["r"]) / float(r2["reach"])
			v = Vector4(uv.x, uv.y, float(r2["r"]), float(r2["strength"]) * fade * fade)
		_mat.set_shader_parameter("ripple%d" % k, v)
	_mat.set_shader_parameter("aberration", _aberration)
	_mat.set_shader_parameter("danger", danger)
	_mat.set_shader_parameter("aspect", arena.x / arena.y)
