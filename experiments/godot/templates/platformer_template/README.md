# Platformer Template — Godot 4

A data-driven 2D platformer demonstrating the core algorithms of the genre.
All gameplay values live in `data/config.json`; two full levels are defined in
`data/levels.json`. No external sprites or assets are required — every object
draws itself with `_draw()`.

---

## Algorithmic Principles

### 1. Variable-Height Jump — gravity multiplier system

A naive fixed-velocity jump always produces the same arc. Real platformers let
the player choose between a small hop and a full jump depending on how long the
button is held. Two multipliers make this possible:

```
While rising and button held:     normal gravity
While rising and button released: velocity.y *= (1 / short_hop_multiplier)
While falling:                    gravity *= fall_gravity_multiplier
```

The result: releasing early dramatically increases the downward acceleration,
truncating the arc. Holding to the peak gives the full jump height. The heavier
fall gravity also prevents the floaty feeling that comes from symmetric gravity.

### 2. Coyote Time — forgive walking off a ledge

The player can still jump for `coyote_time` seconds after their foot leaves a
ledge. Without this, players who press jump a fraction of a second too late (
while their character is already in the air) get nothing and feel cheated.

```
if is_on_floor():
    coyote_timer = coyote_time      # refresh every grounded frame
else:
    coyote_timer -= delta           # count down in the air

if jump_pressed and coyote_timer > 0:
    perform_jump()
    coyote_timer = 0                # consume — prevents double-jump
```

The timer is consumed on jump so the player cannot jump again before landing.

### 3. Jump Buffer — forgive pressing jump slightly early

Pressing jump just before touching the ground normally does nothing. A buffer
stores the intent and fires the jump on the very next grounded frame:

```
if jump_just_pressed:
    buffer_timer = jump_buffer_time

if buffer_timer > 0 and coyote_timer > 0:
    perform_jump()
    buffer_timer = 0
```

Coyote time and jump buffer cooperate: the buffer fires the stored jump the
instant the player lands (or the coyote window opens), making edge jumps and
landing jumps feel responsive.

### 4. Stomp vs. Hurt — collision normal disambiguation

When the player's CharacterBody2D slides into an Enemy, the contact can mean
two opposite things. `get_slide_collision()` provides the normal vector that
distinguishes them:

```
normal.y < -0.65 and velocity.y >= 0  →  player is above, moving down = stomp
otherwise                              →  side or bottom contact = player hurt
```

The threshold `-0.65` (cos 49°) gives a generous stomp zone so the player does
not need pixel-perfect accuracy. On stomp: enemy dies, player bounces with
`bounce_velocity`. On hurt: `GameState.player_die()` is called.

### 5. Patrol Enemy AI — edge ray + wall detection

The enemy walks in `direction` (±1) and checks two conditions each tick:

**Wall hit**: `CharacterBody2D.is_on_wall()` detects geometry contacts.  
**Edge ahead**: a `RayCast2D` at the front foot points downward. When the
platform ends, the ray stops hitting anything → the enemy turns before falling.

```
RayCast2D position = (direction × half_width, 0)
RayCast2D target   = (0, half_height + 10)    ← just below foot level

if is_on_wall() or not edge_ray.is_colliding() or past_patrol_limit:
    flip_direction()
```

A `flip_cooldown` (0.25 s) prevents oscillation when both conditions trigger
simultaneously at a platform corner. `patrol_distance` limits how far the enemy
wanders from its spawn so it stays on its assigned platform.

### 6. Level Data Pipeline — JSON → scene tree

`levels.json` defines each level declaratively. `LevelBuilder.build()` reads
one level entry and creates the scene tree contents:

1. **Clear** existing nodes with `free()` (not `queue_free()` — see below).
2. **Platforms** — `StaticBody2D` (layer 1) with `RectangleShape2D`.
3. **Enemies** — `CharacterBody2D` (layer 4) with `RayCast2D`.
4. **Coins** — `Area2D` (mask layer 2 = player), removed by `free()` on pickup.
5. **Player** — `CharacterBody2D` (layer 2), `Camera2D` child with limits.
6. **Exit** — `Area2D` that calls `GameState.complete_level()`.

**Why `free()` not `queue_free()`**: `queue_free()` schedules deletion for the
end of the frame. During the same frame, `get_child_count()` and node queries
still see the old nodes alongside newly added ones — phantom colliders and
duplicate signals. `free()` removes the node from the tree immediately.

### 7. Responsive UI — CanvasLayer + stretch mode

The HUD lives in a `CanvasLayer`, which renders at a fixed position independent
of the `Camera2D`. A `MarginContainer` with `anchors_preset = FULL_RECT` fills
the entire viewport. A `VBoxContainer` inside holds the top bar and the bottom
controls label with a spacer between them.

`project.godot` sets `window/stretch/mode = "canvas_items"` and
`window/stretch/aspect = "keep_width"`. Everything — world and UI — scales
proportionally when the window is resized. No hardcoded pixel positions appear
anywhere in the scene or scripts.

---

## File Structure

```
platformer_template/
├── data/
│   ├── config.json        ← all gameplay constants
│   ├── strings_en.json    ← English UI strings
│   ├── strings_fr.json    ← French UI strings
│   └── levels.json        ← level definitions (platforms, enemies, coins, exit)
├── autoloads/
│   ├── ConfigManager.gd   ← loads config.json, typed getters
│   ├── StringManager.gd   ← loads strings_<lang>.json, set_language(), language_changed signal
│   └── GameState.gd       ← score, lives, phase, signals
├── scripts/               ← pure Node classes (no .tscn — set up in _ready())
│   ├── Platform.gd        ← StaticBody2D, draws itself
│   ├── Player.gd          ← CharacterBody2D, jump system, stomp logic
│   ├── Enemy.gd           ← CharacterBody2D, patrol AI
│   ├── Collectible.gd     ← Area2D coin, free() on pickup
│   ├── Exit.gd            ← Area2D level exit
│   └── LevelBuilder.gd    ← static build() function
└── scenes/
    ├── Main.tscn / Main.gd
    └── ui/
        └── HUD.gd
```

**Autoload order** (critical): `ConfigManager → StringManager → GameState`

---

## Editing Game Data

### config.json

| Key | Description |
|-----|-------------|
| `default_language` | `"en"` or `"fr"` — startup language |
| `gravity` | Downward acceleration (px/s²) |
| `jump_velocity` | Initial upward velocity (negative = up) |
| `fall_gravity_multiplier` | Gravity multiplier while falling |
| `short_hop_multiplier` | Applied to velocity.y when jump released early |
| `coyote_time` | Seconds the player can jump after leaving a ledge |
| `jump_buffer_time` | Seconds an early jump input is remembered |
| `player_speed` | Horizontal movement speed (px/s) |
| `max_lives` | Starting lives |
| `coin_score_value` | Score per coin |
| `enemy_kill_score` | Score for stomping an enemy |
| `enemy_speed` | Enemy patrol speed (px/s) |
| `bounce_velocity` | Upward velocity after stomping an enemy |
| `camera_smoothing` | Camera2D position_smoothing_speed |
| `respawn_delay` | Seconds before rebuilding the level on death |

### levels.json — level entry fields

| Field | Description |
|-------|-------------|
| `width / height` | Level bounds in pixels (sets camera limits) |
| `kill_y` | Y position below which the player dies (fall death) |
| `player_start` | `[x, y]` player center at spawn |
| `platforms` | Array of `{x, y, w, h, color}` — top-left origin |
| `enemies` | Array of `{x, y, patrol}` — center position + patrol distance |
| `coins` | Array of `{x, y}` — center position |
| `exit` | `{x, y}` — center of the exit flag |

### Adding a language

1. Copy `data/strings_en.json` → `data/strings_<code>.json`.
2. Translate every value (keys must stay identical).
3. Add the code to the `langs` array in `HUD.gd → _on_lang_pressed()`.

Missing keys fall back to English automatically at runtime.
