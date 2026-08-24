# Shoot 'Em Up Template — Godot 4

Vertical space shooter with strong game feel, procedural graphics (no textures),
data-driven enemies and waves, full EN/FR localisation.

---

## Game Feel (Steve Swink)

### Screen Shake — Trauma System
`add_trauma(amount)` accumulates a 0→1 value. Each frame it decays by
`shake_decay × delta`. The actual shake offset is `trauma²`, making small
traumas nearly invisible and full trauma very intense — a non-linear curve
that feels physically satisfying. Applied to the **World** node only, keeping
the CanvasLayer HUD stable.

### Hitstop
`Engine.time_scale = 0.0` for N frames (counted in `PROCESS_MODE_ALWAYS`).
Freezes all game logic briefly on strong impacts. 3 frames for enemy death,
5 frames for player hit. Restores automatically via `_hitstop_frames` counter.

### Player Lerp Movement
`_velocity.lerp(input × max_speed, lerp_weight × delta)` gives organic
acceleration without sacrificing responsiveness. `player_lerp = 14.0`
reads as snappy but weighted — "game feel" per Chapter 4.

### Squash & Stretch
Player ship squashes/stretches based on horizontal velocity:
`scale_x = 1 + (vel.x / max_speed) × 0.22`. Communicates momentum visually.

### Exhaust Trail
Ring buffer of past engine nozzle positions. Drawn as fading circles with
size decreasing toward the tail. Flickers using `sin(time × 18)` for a
flame effect.

### Bullet Trails
Each `ShmupBullet` keeps a ring buffer of past global positions. Trail is
drawn in local space as fading translucent circles — gives projectiles
apparent speed and satisfying visual weight.

### Explosions
Expanding ring + N radial particles, both fading over `explosion_duration`.
A brief central flash disappears in the first 30% of the animation (impact).

### iFrames Blink
After player hit, `_iframe_t` counts down. During this period the ship blinks
using `sin(time × blink_rate × TAU) > 0` — communicates protection state.

### Floating Score Labels
On enemy death, a `+N` label floats upward with ease-out fade and a pop scale.

---

## Architecture

### Object Pool (ShmupBullet / BulletPool)
Pre-instantiates N bullet nodes at startup. `acquire()` scans linearly for the
first inactive bullet. With early exit, this is O(1) in typical cases.
Avoids runtime `Node.new()` / `queue_free()` cost in the hot path.

### Distance-Squared Collision
All collision checks use `distance_squared_to()` to avoid a `sqrt` per pair.
Player hitbox = 10 px radius (forgiving, arcade-style). Two pools scanned
per frame: O(enemy_count × player_bullet_count) + O(enemy_bullet_count).

### Parallax Star Field
3 layers of random Vector2 positions scrolling at different speeds.
When a star exits the bottom, it wraps to the top with a new random X.
No sprites — pure `_draw()` circles with varying alpha per layer.

### Enemy Movement Patterns
- `straight` — constant Y velocity
- `sine` — straight + `sin(time × 2.8) × amplitude` horizontal oscillation
- `dive` — steers toward player's X position at spawn, then straight down
- `boss` — `sin(time × 0.9) × 36%` of play width pendulum near top

### Bullet Shoot Patterns
- `single` — straight down
- `spread3` — center + ±20° offset
- `ring8` — 8 bullets evenly spaced around 360°
- `aimed` — toward last known player position

### Wave Spawner Stagger
Within a formation, each enemy has a `delay = index × 0.18s`. Enemies are
sorted by delay and spawned when `_spawn_timer >= delay`. Produces the
characteristic "stream entry" of formations in shmups.

---

## File Structure
```
shmup_template/
├── data/
│   ├── config.json       ← all tuning constants
│   ├── enemies.json      ← 4 enemy types
│   ├── waves.json        ← 8 waves (+ boss)
│   ├── strings_en.json   ← English UI strings
│   └── strings_fr.json   ← French UI strings
├── autoloads/
│   ├── ConfigManager.gd  ← loads config.json; fallbacks always 0/0.0
│   ├── StringManager.gd  ← set_language(), language_changed signal
│   ├── GameState.gd      ← score, lives, wave, phase, signals
│   └── EnemyDatabase.gd  ← loads enemies.json
├── scripts/
│   ├── Player.gd         ← lerp movement, iframes, squash/stretch, trail
│   ├── Enemy.gd          ← movement patterns, shoot patterns, hit flash
│   ├── Bullet.gd         ← pooled projectile with trail
│   ├── BulletPool.gd     ← object pool manager
│   ├── Explosion.gd      ← expanding ring + radial particles
│   ├── FloatingLabel.gd  ← score pop that floats up
│   ├── StarField.gd      ← 3-layer parallax stars
│   └── WaveManager.gd    ← formation spawner, wave completion
└── scenes/
    ├── Main.tscn / Main.gd   ← shake, hitstop, collision, orchestration
    └── ui/
        └── HUD.gd            ← score, lives, wave, language toggle
```

**Autoload order:** ConfigManager → StringManager → GameState → EnemyDatabase

**Controls:** Arrows or WASD to move — Z or Space to shoot — R to restart

---

## Editing

### config.json key params
| Key | Effect |
|-----|--------|
| `player_speed` | Max player speed (px/s) |
| `player_lerp` | Movement lerp weight — higher = snappier |
| `player_fire_rate` | Bullets per second |
| `iframe_duration` | Seconds of invincibility after hit |
| `trauma_player_hit` | Shake intensity on player hit (0–1) |
| `hitstop_player` | Freeze frames on player hit |
| `shake_decay` | How fast shake fades |

### Adding an enemy type
Add an entry to `data/enemies.json`. Supported `move` values: `straight`,
`sine`, `dive`, `boss`. Supported `shoot` values: `none`, `single`, `spread3`,
`ring8`, `aimed`. Add a matching `score_per_<id>` key to `config.json`.

### Adding a language
Copy `strings_en.json` → `strings_<code>.json`, translate values,
add the code to the `langs` array in `HUD.gd → _on_lang()`.
