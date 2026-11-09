# =============================================================================
# EnemyFactory.gd — The enemy team of each round
# =============================================================================
# Enemies come from the same unit pool as the player, so the player learns
# the units by fighting them. For round r (1 to rounds_total):
#   count      enemy_count_base + floor((r - 1) x enemy_count_per_round), max 8
#              (2 units in round 1, 7 in round 14)
#   tiers      drawn with the shop odds of level
#              min(8, 3 + floor((r - 1) / enemy_level_step)), level 7 in round 11
#   stars      2-star chance = (r - enemy_star2_start) x enemy_star2_per_round,
#              3-star chance = (r - enemy_star3_start) x enemy_star3_per_round
#   stats      x (1 + enemy_stat_growth x (r - 1)): +1.2 % hp and attack a round
#   boss       on boss rounds, the obsidian golem joins (hp x the boss
#              multiplier of that round) and takes boss_slots (3) of the slots
#   placement  melee units in the front rows, ranged units in the back rows
# The random generator is seeded by the game seed and the round, so the
# lineup shown during preparation is the one that fights.
# =============================================================================

class_name EnemyFactory
extends RefCounted

## Returns an Array of {"unit": Unit, "cell": Vector2i} in arena coordinates
## (rows 0 to board_rows - 1, the enemy half; the last of them is the front).
static func build(round_number: int, seed_value: int) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 1000 + round_number
	var lineup: Array[Unit] = []
	var count: int = mini(8, ConfigManager.get_int("enemy_count_base", 2)
		+ int(floor((round_number - 1) * ConfigManager.get_float("enemy_count_per_round", 0.45))))
	var boss_index: int = RoundManager.boss_index(round_number)
	if boss_index >= 0:
		lineup.append(_make_boss(boss_index, round_number))
		count = maxi(count - ConfigManager.get_int("boss_slots", 3), 1)
	var level: int = mini(8, 3 + int(floor((round_number - 1) / ConfigManager.get_float("enemy_level_step", 2.0))))
	for i in count:
		var unit := Unit.new()
		unit.setup(UnitDatabase.unit_data(UnitDatabase.random_id_for_level(level, rng)), _star_for(round_number, rng))
		unit.stat_scale = 1.0 + ConfigManager.get_float("enemy_stat_growth", 0.03) * (round_number - 1)
		lineup.append(unit)
	return _place(lineup, rng)

static func _make_boss(boss_index: int, round_number: int) -> Unit:
	var boss := Unit.new()
	boss.setup(UnitDatabase.unit_data(UnitDatabase.boss_id()), 1)
	var multipliers: Array = ConfigManager.get_array("boss_hp_multipliers")
	var mult: float = float(multipliers[mini(boss_index, multipliers.size() - 1)]) if not multipliers.is_empty() else 1.0
	boss.stat_scale = mult * (1.0 + ConfigManager.get_float("enemy_stat_growth", 0.03) * (round_number - 1) * 0.5)
	return boss

static func _star_for(round_number: int, rng: RandomNumberGenerator) -> int:
	var roll: float = rng.randf()
	var star3: float = maxf(0.0, (round_number - ConfigManager.get_float("enemy_star3_start", 11.0)) * ConfigManager.get_float("enemy_star3_per_round", 0.1))
	var star2: float = maxf(0.0, (round_number - ConfigManager.get_float("enemy_star2_start", 4.0)) * ConfigManager.get_float("enemy_star2_per_round", 0.08))
	if roll < star3:
		return 3
	if roll < star3 + star2:
		return 2
	return 1

static func _place(lineup: Array[Unit], rng: RandomNumberGenerator) -> Array[Dictionary]:
	var cols: int = ConfigManager.get_int("board_cols", 7)
	var rows: int = ConfigManager.get_int("board_rows", 4)
	var taken: Dictionary = {}
	var result: Array[Dictionary] = []
	for unit in lineup:
		# Melee: front rows (rows - 1, rows - 2); ranged: back rows (0, 1)
		var preferred: Array[int] = [0, 1, rows - 2, rows - 1]
		if not unit.is_ranged():
			preferred = [rows - 1, rows - 2, rows - 3, 0]
		var cell: Vector2i = _free_cell(preferred, cols, taken, rng)
		taken[cell] = true
		result.append({"unit": unit, "cell": cell})
	return result

static func _free_cell(preferred_rows: Array[int], cols: int, taken: Dictionary, rng: RandomNumberGenerator) -> Vector2i:
	for row in preferred_rows:
		# Fill from the centre outward, with a little randomness (keys drawn
		# once: a random comparator would break the sort)
		var keyed: Array[Vector2] = []
		for c in cols:
			keyed.append(Vector2(absi(c * 2 - (cols - 1)) + rng.randf() * 2.5, c))
		keyed.sort()
		for entry in keyed:
			var cell := Vector2i(int(entry.y), row)
			if not taken.has(cell):
				return cell
	return Vector2i(0, 0)
