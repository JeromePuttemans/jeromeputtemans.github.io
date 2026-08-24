# =============================================================================
# CombatSystem.gd — Damage resolution (pure static functions).
# =============================================================================
# FORMULA: damage = max(1, attacker.attack - defender.defense)
#
# The minimum of 1 guarantees combat always progresses — no attack is ever
# completely absorbed. This is intentional: roguelikes must avoid stalemates
# where the player can never kill an enemy or vice versa.
#
# Extension ideas:
#   - Random variance:  damage = randi_range(attack - 2, attack + 2) - defense
#   - Critical hits:    if randf() < 0.1: damage *= 2
#   - Status effects:   apply via Entity flags before calling resolve_attack
# =============================================================================

class_name CombatSystem
extends RefCounted

## Resolves one attack from `attacker` against `defender`.
## Calls defender.take_damage() and returns the actual damage dealt.
static func resolve_attack(raw_attack: int, defender: Entity) -> int:
	return defender.take_damage(raw_attack)
