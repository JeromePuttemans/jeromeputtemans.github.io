# Auto-Battler Template — Godot 4

A minimal, data-driven auto-battler demonstrating the core algorithmic
principles of the genre. All game values live in JSON files; no tuning requires
touching code.

---

## Algorithmic Principles

### 1. The Phase State Machine — PREP → BATTLE → RESULT → PREP

The entire auto-battler loop is a four-state machine:

```
PREP    — player shops, places units on the board
BATTLE  — BattleSimulator runs; events replayed tick by tick via a Timer
RESULT  — outcome applied to player HP; 1.5 s pause before next PREP
GAME_OVER / VICTORY — terminal states; only new_game() exits them
```

The key design insight is that BATTLE is **not real-time** — the simulator runs
to completion instantly and returns a list of events. A `Timer` then replays
those events at `battle_tick_delay_ms` intervals, creating the appearance of
animated combat without coupling the simulation to the frame loop.

This separation means the simulation is fully **deterministic and testable**:
given the same units, `BattleSimulator.run()` always produces the same event
sequence regardless of framerate or timer resolution.

**Coroutine guard:** `_start_result_phase()` uses `await` for the 1.5 s
auto-advance delay. After the await, a phase guard `if phase != RESULT: return`
prevents the coroutine from advancing a game that was restarted during the pause.

---

### 2. Initiative-Ordered Combat — speed as a first-class stat

Each combat tick works as follows:

```
1. Collect all living units from both teams.
2. Sort by speed descending (higher speed acts first).
   Ties broken by instance_id (lower id acts first — deterministic).
3. Each unit in order attacks the lowest-HP living enemy.
4. Remove dead units immediately.
5. Repeat until one team is empty.
```

**Why sort by speed each tick?** Units die mid-tick. Rebuilding the order
every tick ensures dead units never get a posthumous turn, and the order
correctly reflects the surviving combatants.

**Why target the lowest-HP enemy?** This greedy heuristic maximises the chance
of eliminating a unit this tick — killing a unit removes all its future attacks.
It is simple to implement and produces readable, intentional-looking combat.

**Damage formula:** `damage = max(1, attacker.attack - defender.defense)`
The minimum of 1 guarantees combat always terminates — a fully armoured unit
can still be worn down.

---

### 3. The Board and Bench — slot arrays as the data model

The board is a flat Array of `cols × rows` slots (row-major order).
The bench is a flat Array of `bench_size` slots.
Both arrays store `Unit` references or `null` for empty slots.

```
board slot index = row * cols + col
```

This flat representation keeps slot operations O(1):
- `get_board_unit(col, row)` — O(1) index lookup
- `first_empty_board_slot()` — O(cols × rows) linear scan, at most ~8 slots
- Moving a unit between board and bench — erase + assign in two arrays

**Spatial index not needed:** with at most 8 board slots, a linear scan to
find an empty slot or locate a unit is negligible. This is unlike the roguelike
grid (50 × 30 = 1500 cells) where an O(1) dictionary index is justified.

---

### 4. Economy — interest and income scaling

Each round the player receives a fixed `gold_per_round` income plus interest:

```
interest = min(floor(gold_held / 10), interest_cap)
total_income = gold_per_round + interest
```

Interest rewards players who save gold without spending it all — a key
decision axis in the genre. The cap prevents degenerate snowball strategies.

The shop costs `shop_refresh_cost` gold to reroll. This creates a second gold
sink: spending gold now for better options vs. banking it for interest.

Units cost `unit_buy_cost` and sell for `unit_sell_value` (always less than
the buy cost). The buy/sell spread discourages frantic speculative buying.

---

### 5. Enemy Scaling — round-proportional difficulty

Enemy team size scales linearly from `enemy_team_size_min` to
`enemy_team_size_max` across the total number of rounds:

```
progress = (current_round - 1) / (total_rounds - 1)   # 0.0 → 1.0
count = min_size + round(progress × (max_size - min_size))
```

Enemy types are drawn randomly from `units.json`, giving the same unit pool
as the player. This keeps the template self-contained while producing
variably difficult encounters.

---

### 6. The Signal Graph — decoupling state from display

```
RoundManager mutates state
  → emit gold_changed(v)      → EconomyHUD updates gold label
  → emit hp_changed(v)        → EconomyHUD updates HP label
  → emit board_changed()      → BoardView.queue_redraw(), BenchPanel rebuild
  → emit phase_changed(p)     → all panels enable/disable buttons
  → emit battle_event(ev)     → BattleLog appends line, BoardView animates
  → emit game_over/game_won   → Main shows overlay
```

No UI component polls state each frame. Each subscribes to the signal that
carries only the data it needs, updating exactly when state changes.

`BoardView` is a pure renderer: it reads `RoundManager.board` in `_draw()` and
has no write access to game state. Click events on board tiles call back into
`RoundManager.return_unit_to_bench()` — the only direction data flows from UI
to game logic.

---

## File Structure

```
autobattler_template/
├── data/
│   ├── config.json        ← all game settings (tunable without code)
│   ├── strings_en.json    ← English UI strings
│   ├── strings_fr.json    ← French UI strings
│   └── units.json         ← unit type definitions
├── autoloads/
│   ├── ConfigManager.gd   ← loads config.json, typed getters
│   ├── StringManager.gd   ← loads strings_<lang>.json, set_language(), language_changed signal
│   ├── UnitDatabase.gd    ← loads units.json, get_type(id)
│   └── RoundManager.gd    ← state machine, economy, battle replay
├── scripts/               ← pure data/logic classes (no Node dependency)
│   ├── Unit.gd            ← unit data + combat helpers
│   ├── Board.gd           ← board/bench slot arrays
│   └── BattleSimulator.gd ← deterministic battle engine
└── scenes/
    ├── Main.tscn / Main.gd
    └── ui/
        ├── BoardView.gd     ← pure renderer (_draw()), handles board clicks
        ├── EconomyHUD.gd    ← round / gold / HP / language button
        ├── BenchPanel.gd    ← bench units with Place / Sell buttons
        ├── ShopPanel.gd     ← shop pool with Buy / Refresh buttons
        ├── BattleLog.gd     ← scrolling battle event log
        └── ReadyButton.gd   ← Start Battle / Fighting... toggle
```

**Autoload order** (critical):
`ConfigManager → StringManager → UnitDatabase → RoundManager`

---

## Editing Game Data

### config.json

| Key | Description |
|-----|-------------|
| `default_language` | `"en"` or `"fr"` — active language at startup |
| `board_cols / board_rows` | Board grid dimensions |
| `bench_size` | Maximum units on the bench |
| `tile_size` | Pixel size of each board tile |
| `shop_size` | Number of offers in the shop |
| `shop_refresh_cost` | Gold cost to reroll the shop |
| `unit_buy_cost / unit_sell_value` | Economy constants |
| `player_hp_start` | Player starting HP |
| `rounds_total` | Number of rounds before victory |
| `gold_per_round` | Base gold income per round |
| `interest_cap` | Maximum interest gold per round |
| `battle_tick_delay_ms` | Milliseconds between battle event replays |
| `base_damage_to_player` | HP lost on a round defeat |
| `enemy_team_size_min/max` | Enemy count range (scales with round) |

### units.json

| Field | Description |
|-------|-------------|
| `id` | Unique string identifier |
| `display_name` | Shown in UI and battle log |
| `glyph` | Single character rendered on the board |
| `color` | Hex color (without `#`) |
| `hp` | Starting hit points |
| `attack` | Raw damage before defender's reduction |
| `defense` | Damage reduction per hit |
| `speed` | Initiative — higher acts first each tick |

### Adding a language

1. Copy `data/strings_en.json` → `data/strings_<code>.json`
2. Translate every value (keys must stay identical).
3. Add the new code to the `langs` array in `EconomyHUD.gd → _on_lang_pressed()`.

Any key missing in the new file automatically falls back to the English string —
partial translations are safe at runtime.
