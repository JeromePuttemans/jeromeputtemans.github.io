# =============================================================================
# AISystem.gd: enemy decision (pure static functions).
# =============================================================================
# Called by GameState for an enemy that is already alerted (awareness is
# handled in GameState._enemy_act). Returns one action:
#   {type = "attack"}               adjacent to the player (8 directions)
#   {type = "shoot"}                ranged enemy with a clear line of sight
#   {type = "move", pos = Vector2i} one step
#   {type = "idle"}
#
# BEHAVIOURS ("ai" field in enemies.json):
#   melee    walk down the shared DijkstraMap toward the player, attack when
#            adjacent
#   erratic  like melee, but half of its actions are a random step (bats:
#            hard to pin down, yet they come at you)
#   ranged   shoot when the player is within `range` tiles and in line of
#            sight (FOVSystem.has_los); otherwise close in. Breaking line of
#            sight around a corner is the counter-play.
#
# Distances use the Chebyshev metric max(|dx|, |dy|): a diagonal step costs
# the same as a straight one, as for the player.
# =============================================================================

class_name AISystem
extends RefCounted

static func decide(enemy: EnemyEntity, player: PlayerEntity, dungeon: DungeonData,
		enemy_positions: Dictionary, dmap: DijkstraMap, sees_player: bool,
		rng: RandomNumberGenerator) -> Dictionary:
	var dist: int = chebyshev(enemy.grid_pos, player.grid_pos)

	if enemy.ai == "erratic" and rng.randf() < 0.5:
		var p: Vector2i = _random_free_neighbor(enemy.grid_pos, dungeon, enemy_positions, player.grid_pos, rng)
		if p != enemy.grid_pos:
			return {type = "move", pos = p}

	if dist <= 1:
		return {type = "attack"}

	if enemy.ai == "ranged" and sees_player and dist <= enemy.attack_range \
			and FOVSystem.has_los(dungeon, enemy.grid_pos, player.grid_pos):
		return {type = "shoot"}

	var step: Vector2i = dmap.step_toward(enemy.grid_pos, enemy_positions, player.grid_pos)
	if step != enemy.grid_pos:
		return {type = "move", pos = step}
	return {type = "idle"}

static func chebyshev(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))

static func _random_free_neighbor(pos: Vector2i, dungeon: DungeonData, enemy_positions: Dictionary,
		player_pos: Vector2i, rng: RandomNumberGenerator) -> Vector2i:
	var options: Array[Vector2i] = []
	for dir in DijkstraMap.DIRS:
		var n: Vector2i = pos + dir
		if dungeon.is_walkable(n) and not enemy_positions.has(n) and n != player_pos:
			options.append(n)
	if options.is_empty():
		return pos
	return options[rng.randi_range(0, options.size() - 1)]
