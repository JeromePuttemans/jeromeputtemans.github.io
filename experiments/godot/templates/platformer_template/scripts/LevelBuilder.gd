# =============================================================================
# LevelBuilder.gd — Static utility: constructs a level from JSON data.
# =============================================================================
# build() clears existing World children and populates new ones.
# It returns the newly created Player node so Main.gd can store a reference,
# set the camera limits, and connect respawn logic.
#
# CRITICAL: uses free() not queue_free() when clearing old nodes.
# queue_free() is deferred — the old nodes would remain in the tree during
# the same frame that new ones are added, causing phantom colliders.
#
# JSON COORDINATE SYSTEM:
#   Platforms: { x, y, w, h } where (x, y) is the TOP-LEFT corner.
#   LevelBuilder converts to center position for the StaticBody2D.
#   Enemies / coins / exit: { x, y } are the CENTER of the node.
# =============================================================================

class_name LevelBuilder
extends RefCounted

## Builds a complete level from `data` into the three container nodes.
## Returns the Player node (already added to `world`).
static func build(
		data:         Dictionary,
		platforms:    Node2D,
		enemies_node: Node2D,
		coins_node:   Node2D,
		world:        Node2D) -> Player:

	# --- Clear previous level contents immediately (free, not queue_free) ---
	for c in platforms.get_children():    c.free()
	for c in enemies_node.get_children(): c.free()
	for c in coins_node.get_children():   c.free()

	# Remove previous player if present
	var old_player = world.get_node_or_null("Player")
	if old_player != null:
		old_player.free()

	# --- Platforms -----------------------------------------------------------
	for pd in data.get("platforms", []):
		var p = Platform.new()
		p.name = "Platform"
		platforms.add_child(p)
		p.setup(float(pd["w"]), float(pd["h"]), pd.get("color", "3a3a52"))
		# Convert top-left JSON coords to center position
		p.position = Vector2(pd["x"] + pd["w"] * 0.5, pd["y"] + pd["h"] * 0.5)

	# --- Enemies -------------------------------------------------------------
	for ed in data.get("enemies", []):
		var e = Enemy.new()
		e.name            = "Enemy"
		e.patrol_distance = float(ed.get("patrol", 150))
		enemies_node.add_child(e)
		e.position = Vector2(float(ed["x"]), float(ed["y"]))
		e._origin_x = e.position.x   # must be set after position is assigned

	# --- Coins ---------------------------------------------------------------
	for cd in data.get("coins", []):
		var coin = Collectible.new()
		coin.name = "Coin"
		coins_node.add_child(coin)
		coin.position = Vector2(float(cd["x"]), float(cd["y"]))

	# --- Player --------------------------------------------------------------
	var player = Player.new()
	player.name = "Player"
	world.add_child(player)
	var start = data.get("player_start", [80, 600])
	player.position       = Vector2(float(start[0]), float(start[1]))
	player.start_position = player.position

	# --- Exit ----------------------------------------------------------------
	var exit_data = data.get("exit", {})
	if not exit_data.is_empty():
		var exit = Exit.new()
		exit.name = "Exit"
		world.add_child(exit)
		exit.position = Vector2(float(exit_data["x"]), float(exit_data["y"]))

	return player
