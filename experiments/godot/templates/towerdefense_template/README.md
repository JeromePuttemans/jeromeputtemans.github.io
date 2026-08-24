# Tower Defense Template — Godot 4

A data-driven tower defense demonstrating the core algorithms of the genre.
All gameplay values live in `data/config.json`; tower types, enemy types, waves
and map layouts are each in their own JSON file. No external sprites — every
object draws itself with `_draw()`.

---

## Algorithmic Principles

### 1. Grid & Tile System

The map is a 2D array of tile characters loaded from `maps.json`.
`'B'` (buildable) and `'P'` (path) define where towers can be placed and where
enemies walk. `GridMap.grid_to_world(col, row)` converts integer grid
coordinates to pixel centers; `world_to_grid(pos)` is the inverse.

Tower placement writes to two parallel arrays — `_occupied[r][c]` (bool) and
`_towers[r][c]` (Tower reference) — keeping O(1) lookup for both validation and
retrieval without scanning the scene tree.

### 2. Waypoint Pathfinding

Enemy paths are defined as an ordered list of `[col, row]` waypoints in
`maps.json`. `WaveManager` passes the converted world-space list to each enemy
at spawn. Each frame the enemy computes the direction to `waypoints[_wp_index]`,
moves `speed × delta` pixels along it, and advances the index when it arrives
within 4 px (the arrival threshold). This is O(1) per enemy per frame.

The alternative (runtime A*) is unnecessary for a tower defense because paths
are static and pre-verified by the designer.

### 3. Enemy Progress Tracking

Towers use a "first" targeting strategy — attack the enemy furthest along the
path. `Enemy.progress()` returns a float representing total distance traveled:

```
progress = sum of all completed segment lengths
         + partial distance on the current segment
```

This is computed on demand (not cached) because it changes every frame. For
larger enemy counts, caching on a dirty flag would be a worthwhile optimization.

### 4. Tower Fire Rate — cooldown float, no Timer nodes

Each tower has a `_cooldown: float` that decrements in `_process(delta)`.
When it reaches 0 the tower fires and resets to `1.0 / fire_rate`. Using a
float avoids creating hundreds of Timer nodes that would all need management.
The pattern scales to any number of towers with zero additional overhead.

### 5. Projectile Homing

Projectiles do not compute a straight-line intercept. Each frame they move
`projectile_speed × delta` pixels toward the target's *current* position. This
gives smooth homing that looks natural at normal game speeds. If the target dies
before impact, `is_instance_valid()` catches the freed reference and the
projectile removes itself.

### 6. Splash Damage

When `splash == true`, on impact the projectile iterates all enemies in the
`Enemies` container and deals damage to any within `splash_radius` pixels of the
impact point. This is a brute-force O(n) scan — acceptable for typical enemy
counts. A spatial hash or quadtree would be needed for very large waves.

### 7. Wave State Machine

```
SPAWNING state:
  Every spawn_interval seconds: pop type_id from _spawn_queue, create Enemy
  When queue empties: _spawning = false

Completion check (runs after every enemy removal):
  if _alive_count == 0 AND _spawn_queue.is_empty() AND NOT _spawning:
      GameState.wave_cleared()
```

The critical invariant: `_spawning` must be set to `false` **at the moment the
last enemy is spawned** (not on the next tick), otherwise the completion check
can never succeed because `not _spawning` would always be false.

### 8. Sell Refund

`sell_value = int(cost × sell_refund_ratio)` computed once at tower creation.
`sell_refund_ratio` (default 0.6) lives in `config.json`. Selling calls
`grid_map.remove_tower()` then `tower.free()` — immediate removal with no
deferred deletion to avoid phantom grid occupancy.

### 9. `free()` vs `queue_free()` in this project

| Context | Method | Reason |
|---------|--------|--------|
| Selling a tower (user action) | `free()` | Grid must be immediately clear |
| Clearing level on restart | `free()` | No phantom colliders next frame |
| Enemy death / exit (signal callback) | `queue_free()` | Godot locks the node during signal emission |
| Projectile self-removal | `queue_free()` | Called during `_process`, safe |

---

## File Structure

```
towerdefense_template/
├── data/
│   ├── config.json       ← global gameplay constants
│   ├── towers.json       ← tower type definitions
│   ├── enemies.json      ← enemy type definitions
│   ├── waves.json        ← 10 wave compositions
│   ├── maps.json         ← grid layout + waypoints
│   ├── strings_en.json   ← English UI strings
│   └── strings_fr.json   ← French UI strings
├── autoloads/
│   ├── ConfigManager.gd  ← loads config.json; fallbacks always 0/0.0
│   ├── StringManager.gd  ← set_language(), language_changed signal
│   ├── GameState.gd      ← gold, lives, score, phase, signals
│   ├── TowerDatabase.gd  ← loads towers.json
│   └── EnemyDatabase.gd  ← loads enemies.json
├── scripts/
│   ├── GridMap.gd        ← tile grid, placement validation, _draw()
│   ├── Enemy.gd          ← waypoint follower, health bar, signals
│   ├── Tower.gd          ← targeting, fire-rate cooldown, _draw()
│   ├── Projectile.gd     ← homing, splash, _draw()
│   └── WaveManager.gd    ← spawn queue, alive counter, completion check
└── scenes/
    ├── Main.tscn / Main.gd
    └── ui/
        └── HUD.gd
```

**Autoload order**: `ConfigManager → StringManager → GameState → TowerDatabase → EnemyDatabase`

---

## Editing Game Data

### config.json

| Key | Description |
|-----|-------------|
| `default_language` | `"en"` or `"fr"` |
| `tile_size` | Pixel size of one grid cell |
| `starting_gold` | Gold at game start |
| `starting_lives` | Lives at game start |
| `wave_between_delay` | Seconds between waves (auto-start countdown) |
| `spawn_interval` | Seconds between individual enemy spawns |
| `sell_refund_ratio` | Fraction of tower cost returned on sell (0.0–1.0) |
| `projectile_speed` | Projectile movement speed (px/s) |
| `enemy_reach_damage` | Lives lost when an enemy exits |

### towers.json fields

`id`, `display_name`, `cost`, `damage`, `range`, `fire_rate`, `splash` (bool),
`splash_radius`, `color` (hex without #)

### enemies.json fields

`id`, `display_name`, `hp`, `speed` (px/s), `reward` (gold + score), `color`
(hex), `size` (circle radius in px)

### waves.json

Each entry: `{ "wave": N, "spawns": [ {"type": "id", "count": N}, ... ] }`
Spawns within a wave are flattened into a single queue and spawned in order.

### maps.json

`cols`, `rows`, `waypoints` (array of `[col, row]` in path order),
`grid` (array of strings, one per row — `'B'` buildable, `'P'` path).

The first and last waypoints should align with the left and right edges
(or any edges) of the grid so enemies enter and exit cleanly.

### Adding a language

1. Copy `data/strings_en.json` → `data/strings_<code>.json` and translate.
2. Add the code to the `langs` array in `HUD.gd → _on_lang_pressed()`.
