# =============================================================================
# Poses.gd — Library of skeleton poses, in degrees, facing right
# =============================================================================
# A pose gives the angle of every limb of the automaton:
#   torso   lean from upright, positive = leaning forward
#   head    tilt added to the torso
#   ua / fa upper arm angle from straight down (90 = horizontal forward,
#           180 = straight up), forearm bend added to it; _f = lead arm
#           (drawn in front), _b = rear arm (drawn behind)
#   th / sh thigh angle from straight down (positive = knee forward), shin
#           bend added to it (negative = knee bent backward)
#   hx      horizontal shift of the hip, lift  extra height (air poses)
# Grounded poses are lowered automatically until the lower foot touches
# the floor (Rig.joints), so a crouch only needs bent legs.
# Fighter blends from one pose to the next (Poses.blend) to animate.
# =============================================================================

class_name Poses
extends RefCounted

const KEYS: Array[String] = ["torso", "head", "ua_f", "fa_f", "ua_b", "fa_b", "th_f", "sh_f", "th_b", "sh_b", "hx", "lift"]

const LIBRARY: Dictionary = {
	"idle": {torso = 6, head = -4, ua_f = 38, fa_f = 100, ua_b = 26, fa_b = 108, th_f = 16, sh_f = -14, th_b = -14, sh_b = -8},
	"crouch": {torso = 20, head = -10, ua_f = 42, fa_f = 100, ua_b = 30, fa_b = 108, th_f = 78, sh_f = -118, th_b = 28, sh_b = -122},
	"jump": {torso = 4, head = -6, ua_f = 64, fa_f = 76, ua_b = 22, fa_b = 92, th_f = 62, sh_f = -96, th_b = 12, sh_b = -84},
	"fall": {torso = 0, head = 0, ua_f = 72, fa_f = 58, ua_b = 44, fa_b = 62, th_f = 34, sh_f = -42, th_b = -8, sh_b = -34},
	"block": {torso = -6, head = -12, ua_f = 74, fa_f = 124, ua_b = 62, fa_b = 122, th_f = 14, sh_f = -18, th_b = -20, sh_b = -8},
	"crouch_block": {torso = 8, head = -14, ua_f = 78, fa_f = 118, ua_b = 66, fa_b = 120, th_f = 78, sh_f = -118, th_b = 28, sh_b = -122},
	"hit_high": {torso = -24, head = -26, ua_f = -8, fa_f = 44, ua_b = -22, fa_b = 34, th_f = 22, sh_f = -24, th_b = -22, sh_b = -4},
	"hit_low": {torso = 32, head = 18, ua_f = 12, fa_f = 62, ua_b = 4, fa_b = 70, th_f = 50, sh_f = -80, th_b = 6, sh_b = -60},
	"air_hit": {torso = -50, head = -20, ua_f = 130, fa_f = 30, ua_b = 150, fa_b = 20, th_f = 40, sh_f = -60, th_b = 64, sh_b = -40, lift = 20},
	"down": {torso = -92, head = 0, ua_f = 170, fa_f = 10, ua_b = 190, fa_b = 0, th_f = 92, sh_f = -6, th_b = 84, sh_b = -10},
	"getup": {torso = 30, head = -10, ua_f = 10, fa_f = 40, ua_b = -10, fa_b = 30, th_f = 80, sh_f = -120, th_b = 30, sh_b = -130},
	"dash": {torso = 28, head = -8, ua_f = 50, fa_f = 70, ua_b = -30, fa_b = 50, th_f = 50, sh_f = -60, th_b = -40, sh_b = -30},
	"backdash": {torso = -18, head = -6, ua_f = 60, fa_f = 90, ua_b = 40, fa_b = 90, th_f = -10, sh_f = -40, th_b = 30, sh_b = -70},
	"victory": {torso = -4, head = -10, ua_f = 172, fa_f = 6, ua_b = 24, fa_b = 120, th_f = 12, sh_f = -6, th_b = -16, sh_b = -4},
	"ko": {torso = -92, head = 10, ua_f = 200, fa_f = 0, ua_b = 160, fa_b = 10, th_f = 96, sh_f = 0, th_b = 80, sh_b = -14},
	"jab_wind": {torso = 2, head = -4, ua_f = 46, fa_f = 112, ua_b = 30, fa_b = 108, th_f = 18, sh_f = -16, th_b = -16, sh_b = -8},
	"jab": {torso = 14, head = -6, ua_f = 92, fa_f = 0, ua_b = 30, fa_b = 112, th_f = 26, sh_f = -18, th_b = -22, sh_b = -6},
	"straight_wind": {torso = -8, head = -4, ua_f = 28, fa_f = 124, ua_b = 44, fa_b = 100, th_f = 12, sh_f = -16, th_b = -18, sh_b = -10},
	"straight": {torso = 24, head = -10, ua_f = 90, fa_f = 0, ua_b = -24, fa_b = 64, th_f = 38, sh_f = -30, th_b = -32, sh_b = 0, hx = 10},
	"low_jab": {torso = 30, head = -14, ua_f = 86, fa_f = 0, ua_b = 30, fa_b = 104, th_f = 78, sh_f = -118, th_b = 28, sh_b = -122},
	"sweep_wind": {torso = 22, head = -10, ua_f = 30, fa_f = 80, ua_b = 10, fa_b = 90, th_f = 70, sh_f = -120, th_b = 30, sh_b = -122},
	"sweep": {torso = 44, head = -20, ua_f = 14, fa_f = 60, ua_b = -12, fa_b = 70, th_f = 92, sh_f = 0, th_b = 62, sh_b = -142, hx = -6},
	"kick_wind": {torso = -4, head = -6, ua_f = 50, fa_f = 100, ua_b = 30, fa_b = 100, th_f = 74, sh_f = -118, th_b = -10, sh_b = -4},
	"kick": {torso = -16, head = -8, ua_f = 60, fa_f = 90, ua_b = 10, fa_b = 90, th_f = 100, sh_f = 0, th_b = -8, sh_b = 0},
	"air_jab": {torso = 14, head = -8, ua_f = 62, fa_f = 0, ua_b = 30, fa_b = 100, th_f = 50, sh_f = -80, th_b = 10, sh_b = -70},
	"air_kick": {torso = -12, head = -6, ua_f = 80, fa_f = 70, ua_b = 50, fa_b = 80, th_f = 58, sh_f = 0, th_b = 20, sh_b = -90},
	"uppercut_wind": {torso = 28, head = -6, ua_f = 20, fa_f = 120, ua_b = 30, fa_b = 100, th_f = 70, sh_f = -110, th_b = 26, sh_b = -120},
	"uppercut": {torso = 4, head = -16, ua_f = 168, fa_f = 8, ua_b = 30, fa_b = 90, th_f = 32, sh_f = -30, th_b = -30, sh_b = -44, lift = 6},
	"cast_wind": {torso = -12, head = -4, ua_f = 18, fa_f = 124, ua_b = 10, fa_b = 124, th_f = 12, sh_f = -16, th_b = -20, sh_b = -10},
	"cast": {torso = 18, head = -8, ua_f = 92, fa_f = 0, ua_b = 92, fa_b = 4, th_f = 30, sh_f = -24, th_b = -26, sh_b = -4},
	"rush": {torso = 36, head = -12, ua_f = 100, fa_f = -8, ua_b = 82, fa_b = 18, th_f = 42, sh_f = -44, th_b = -42, sh_b = -18},
	"slam_wind": {torso = -14, head = -14, ua_f = 172, fa_f = 10, ua_b = 168, fa_b = 14, th_f = 14, sh_f = -14, th_b = -16, sh_b = -6},
	"slam": {torso = 38, head = -16, ua_f = 66, fa_f = 0, ua_b = 60, fa_b = 6, th_f = 40, sh_f = -50, th_b = -26, sh_b = -10},
	"grab": {torso = 22, head = -8, ua_f = 86, fa_f = 22, ua_b = 80, fa_b = 34, th_f = 30, sh_f = -24, th_b = -24, sh_b = -4},
	"lift": {torso = -18, head = -14, ua_f = 150, fa_f = 0, ua_b = 152, fa_b = 0, th_f = 14, sh_f = -10, th_b = -20, sh_b = -6},
	"counter": {torso = -10, head = -10, ua_f = 104, fa_f = 92, ua_b = 82, fa_b = 102, th_f = 10, sh_f = -24, th_b = -24, sh_b = -14},
	"roar": {torso = -16, head = -22, ua_f = 124, fa_f = 30, ua_b = 118, fa_b = 36, th_f = 20, sh_f = -10, th_b = -20, sh_b = -6},
	"spin": {torso = 10, head = 0, ua_f = 96, fa_f = 0, ua_b = -84, fa_b = 0, th_f = 20, sh_f = -16, th_b = -20, sh_b = -8},
	"slide": {torso = -30, head = -4, ua_f = 10, fa_f = 40, ua_b = -40, fa_b = 40, th_f = 88, sh_f = 0, th_b = 50, sh_b = -100},
	"flip": {torso = -10, head = -10, ua_f = 140, fa_f = 20, ua_b = 120, fa_b = 30, th_f = 130, sh_f = 0, th_b = 30, sh_b = -100, lift = 10},
	"evade": {torso = -30, head = -10, ua_f = 120, fa_f = 40, ua_b = 140, fa_b = 30, th_f = 50, sh_f = -100, th_b = 10, sh_b = -100, lift = 30},
	"stomp": {torso = 20, head = -10, ua_f = 70, fa_f = 40, ua_b = 50, fa_b = 50, th_f = 40, sh_f = -10, th_b = -20, sh_b = -80},
}

static var _cache: Dictionary = {}

## Pose by name, angles converted to radians (cached).
static func get_pose(name: String) -> Dictionary:
	if _cache.has(name):
		return _cache[name]
	var src: Dictionary = LIBRARY.get(name, LIBRARY["idle"]) as Dictionary
	var pose: Dictionary = {}
	for key in KEYS:
		var v: float = float(src.get(key, 0.0))
		pose[key] = v if key == "hx" or key == "lift" else deg_to_rad(v)
	_cache[name] = pose
	return pose

static func blend(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var out: Dictionary = {}
	for key in KEYS:
		out[key] = lerpf(float(a.get(key, 0.0)), float(b.get(key, 0.0)), t)
	return out

static func copy(a: Dictionary) -> Dictionary:
	return a.duplicate()
