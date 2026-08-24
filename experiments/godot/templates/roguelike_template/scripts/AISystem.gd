# =============================================================================
# AISystem.gd — Enemy behavior (pure static functions).
# =============================================================================
# ALGORITHM: Greedy chase AI with proximity attack.
#
# Each enemy tick:
#   1. Compute Chebyshev distance to the player.
#      Chebyshev: max(|dx|, |dy|) — diagonal moves cost the same as cardinal.
#   2. If distance == 1: ATTACK (bump-to-attack, no movement).
#   3. If distance > chase_range: IDLE (enemy is unaware of the player).
#   4. Otherwise: move one step toward the player.
#      Preferred: diagonal step (dx, dy) to close distance fastest.
#      Fallback 1: horizontal step (dx, 0).
#      Fallback 2: vertical step (0, dy).
#      If all three options are blocked: IDLE this turn.
#
# No pathfinding — enemies can get stuck in corridors behind other enemies.
# For a template this is acceptable; A* can be added as an extension.
# =============================================================================

class_name AISystem
extends RefCounted

## Returns an action Dictionary for the given enemy:
##   {"type": "attack"}
##   {"type": "move",   "pos": Vector2i}
##   {"type": "idle"}
static func get_action(
		enemy: EnemyEntity,
		player: PlayerEntity,
		dungeon: DungeonData,
		enemy_positions: Dictionary) -> Dictionary:

	var dist = _chebyshev(enemy.grid_pos, player.grid_pos)

	if dist <= 1:
		return {"type": "attack"}

	if dist > enemy.chase_range:
		return {"type": "idle"}

	# Determine preferred step direction
	var dx = sign(player.grid_pos.x - enemy.grid_pos.x)
	var dy = sign(player.grid_pos.y - enemy.grid_pos.y)

	# Build candidate moves (diagonal first for fastest approach)
	var candidates: Array = []
	if dx != 0 and dy != 0:
		candidates = [
			enemy.grid_pos + Vector2i(dx, dy),   # preferred: diagonal
			enemy.grid_pos + Vector2i(dx,  0),   # fallback:  horizontal
			enemy.grid_pos + Vector2i( 0, dy),   # fallback:  vertical
		]
	elif dx != 0:
		candidates = [enemy.grid_pos + Vector2i(dx, 0)]
	else:
		candidates = [enemy.grid_pos + Vector2i(0, dy)]

	for pos in candidates:
		if _can_move_to(pos, dungeon, enemy_positions, player):
			return {"type": "move", "pos": pos}

	return {"type": "idle"}

# Chebyshev distance: the number of king-moves between two grid cells.
static func _chebyshev(a: Vector2i, b: Vector2i) -> int:
	return max(abs(a.x - b.x), abs(a.y - b.y))

## Returns true if an enemy can legally move to `pos`.
static func _can_move_to(
		pos: Vector2i,
		dungeon: DungeonData,
		enemy_positions: Dictionary,
		player: PlayerEntity) -> bool:
	if not dungeon.is_walkable(pos):
		return false
	if enemy_positions.has(pos):
		return false   # Another enemy is already there
	if pos == player.grid_pos:
		return false   # Player's cell — attack branch handles this, not move
	return true
