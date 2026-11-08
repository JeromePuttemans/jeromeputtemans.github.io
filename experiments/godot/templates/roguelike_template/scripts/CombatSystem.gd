# =============================================================================
# CombatSystem.gd: damage resolution (pure static functions).
# =============================================================================
# FORMULA:
#   roll   = attack + random(-1, 0, +1)
#   damage = max(1, roll - defense)
#   critical hit (chance crit_chance): damage x 2, applied AFTER defense,
#   so a crit stays strong against armored enemies.
#
# Examples with the default data:
#   player ATK 5 vs orc DEF 1  -> 3, 4 or 5 damage (crit: 6, 8 or 10)
#   troll ATK 8 vs player DEF 1 -> 6, 7 or 8 damage
#   rat ATK 3 vs player DEF 4   -> roll 2..4 - 4, at least 1 damage
#
# The minimum of 1 guarantees combat always progresses: no stalemate where
# nobody can hurt anybody. The +/-1 variance keeps outcomes slightly
# uncertain, so a fight at low HP stays tense.
# =============================================================================

class_name CombatSystem
extends RefCounted

## Resolves one attack and applies it. Returns {damage: int, crit: bool}.
static func resolve(attack: int, defender: Entity, crit_chance: float,
		rng: RandomNumberGenerator) -> Dictionary:
	var roll: int = attack + rng.randi_range(-1, 1)
	var damage: int = maxi(1, roll - defender.defense)
	var crit: bool = crit_chance > 0.0 and rng.randf() < crit_chance
	if crit:
		damage *= 2
	defender.take_damage(damage)
	return {damage = damage, crit = crit}
