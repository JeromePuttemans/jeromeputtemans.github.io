# =============================================================================
# Utils.gd — Autoload (Singleton)
# =============================================================================
# Number and duration formatting, in the current language.
#
# NUMBERS: below 1 000, the plain value (one decimal under 10). Above, three
#   significant digits and a suffix for each power of 1 000:
#     English  1.25K, 12.5M, 125B, then T, Qa, Qi, Sx, Sp, Oc, No, Dc
#     French   1,25 k, 12,5 M, 125 Md (milliard), then Bn (billion = 10^12),
#              Bd, Tn, Td: the French long scale
#   Past the last suffix, scientific notation (1.25e36). Below 10, up to two
#   decimals without trailing zeros (0.15, 1.5, 3).
# Idle games reach astronomical values fast: raw floats would be unreadable.
# =============================================================================

extends Node

const SUFFIXES_EN: Array[String] = ["", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"]
const SUFFIXES_FR: Array[String] = ["", "k", "M", "Md", "Bn", "Bd", "Tn", "Td"]

func format_number(n: float) -> String:
	var french: bool = StringManager.get_language() == "fr"
	var value: float = absf(n)
	var prefix: String = "-" if n < 0.0 else ""
	if value < 10.0:
		return prefix + _trim_zeros(_decimal(floor(value * 100.0) / 100.0, 2, french))
	if value < 1000.0:
		return prefix + str(int(floor(value)))
	var suffixes: Array[String] = SUFFIXES_FR if french else SUFFIXES_EN
	var tier: int = int(floor(log(value) / log(1000.0)))
	if tier >= suffixes.size():
		var exponent: int = int(floor(log(value) / log(10.0)))
		var mantissa: String = _decimal(round(value / pow(10.0, exponent) * 100.0) / 100.0, 2, french)
		return prefix + mantissa + "e" + str(exponent)
	var scaled: float = value / pow(1000.0, tier)
	var decimals: int = 2 if scaled < 10.0 else (1 if scaled < 100.0 else 0)
	var number: String = _trim_zeros(_decimal(floor(scaled * pow(10.0, decimals)) / pow(10.0, decimals), decimals, french))
	return prefix + number + (" " if french else "") + suffixes[tier]

## "1,50" -> "1,5", "3,00" -> "3".
func _trim_zeros(text: String) -> String:
	if not ("," in text or "." in text):
		return text
	while text.ends_with("0"):
		text = text.left(text.length() - 1)
	return text.trim_suffix(",").trim_suffix(".")

func _decimal(value: float, decimals: int, french: bool) -> String:
	var text: String = ("%." + str(decimals) + "f") % value
	return text.replace(".", ",") if french else text

## 45 -> "45 s", 754 -> "12 min 34 s", 8040 -> "2 h 14 min".
func format_duration(seconds: float) -> String:
	var total: int = int(seconds)
	if total < 60:
		return "%d s" % total
	if total < 3600:
		return "%d min %02d s" % [int(total / 60.0), total % 60]
	return "%d h %02d min" % [int(total / 3600.0), int((total % 3600) / 60.0)]

func format_percent(ratio: float) -> String:
	var text: String = str(int(round(ratio * 100.0)))
	return text + (" %" if StringManager.get_language() == "fr" else "%")
