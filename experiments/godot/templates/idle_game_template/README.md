# Idle Game Template — Godot 4

A minimal, data-driven idle game template demonstrating the core algorithmic
principles of the genre. All game values live in JSON files; no tuning requires
touching code.

---

## Algorithmic Principles

### 1. The Tick System — time as a production engine

Every idle game is built around a continuous accumulation function:

```
resources += production_rate * elapsed_time
```

This is numerical integration over time. The engine calls `_process(delta)`
every frame; `delta` is the elapsed seconds since the last frame (~0.016s at
60 FPS). The increment added each frame is `rps * delta`. Over one second,
regardless of framerate, the sum of all deltas equals exactly 1.0 — so
production is always `rps × 1 second`. This approach is framerate-independent
by construction.

**Offline progress** is the same formula applied to a single large interval.
When the player returns, elapsed time is read from the saved timestamp and
multiplied by the current RPS and an `offline_factor` (< 1.0) that rewards
absence without making active play feel pointless.

---

### 2. The Exponential Cost Curve — the engine of tension

The core tension of an idle game is the gap between what you have and what you
need. This gap is maintained across enormous value ranges by a single formula:

```
current_cost = base_cost × growth_rate ^ owned
```

With `growth_rate = 1.15`, each additional unit costs 15% more than the previous.
Production scales linearly with ownership; cost scales exponentially. This
asymmetry creates the "one more purchase" feeling: the player is always close to
the next threshold on a linear scale, while the exponential curve continuously
resets the challenge.

**Bulk buy cost** uses the closed-form geometric series sum, avoiding both
floating-point accumulation and N multiplications:

```
bulk_cost = base_cost × r^owned × (r^N − 1) / (r − 1)
```

---

### 3. The RPS Stack — composing production rates

Total production at any moment:

```
total_rps = Σ (base_production × owned × multiplier)   for each producer
```

Multipliers from upgrades compose multiplicatively and are stored per-producer.
On save/load, multipliers must be **reset to 1.0** before replaying all
purchased upgrades — treating purchase history as the source of truth, not the
stored derived value. Restoring multipliers directly causes exponential doubling
on every load.

---

### 4. Unlock Conditions — two triggering patterns

- **OWNED_COUNT** — checked on every producer purchase (infrequent event).
- **RESOURCE_TOTAL** — checked on every `total_produced_changed` signal
  (fires every frame during active production).

Both patterns use a `_already_signaled` flag to guarantee the unlock signal
fires exactly once regardless of how many times the threshold is crossed.

---

### 5. State Serialization — snapshotting a running system

Only irreducible state is saved:
- Current and total-produced amounts per resource
- Units owned per producer
- Which upgrades are purchased

Derived values (multipliers, RPS) are **never saved** — they are recomputed
from purchase history on load. This makes the save format stable across game
updates and eliminates a whole class of consistency bugs.

---

### 6. The Signal Graph — decoupling production from display

```
GameManager._process(delta)
  → ProducerManager.tick(delta)
	  → ResourceManager.add(resource, amount)
		  → emit resource_changed      → UI refreshes labels
		  → emit total_produced_changed → ProducerManager checks unlocks
			  → emit upgrade_unlocked  → UpgradePanel adds card
```

No UI component reads game state on every frame. Each subscribes to the
relevant signal and updates only when notified. Game logic has zero knowledge
of the display layer — producers accumulate whether or not any UI node exists.

---

## File Structure

```
idle_game_template/
├── data/
│   ├── config.json        ← all game settings (tunable without code)
│   ├── strings_en.json    ← English UI strings
│   ├── strings_fr.json    ← French UI strings
│   ├── producers.json     ← producer definitions
│   └── upgrades.json      ← upgrade definitions
├── autoloads/
│   ├── ConfigManager.gd   ← loads config.json, typed getters
│   ├── StringManager.gd   ← loads strings_<lang>.json, set_language(), language_changed signal
│   ├── ResourceManager.gd ← resource state + signals
│   ├── ProducerManager.gd ← producers, upgrades, RPS, unlock logic
│   ├── SaveManager.gd     ← JSON save/load
│   ├── GameManager.gd     ← game loop, autosave, manual click
│   └── Utils.gd           ← number formatting
├── resources/
│   ├── Producer.gd        ← data class (cost curve, RPS)
│   └── Upgrade.gd         ← data class (unlock + effect logic)
└── scenes/
	├── Main.tscn / Main.gd
	└── ui/
		├── ResourceDisplay.gd
		├── ClickButton.gd
		├── ProducerList.gd
		├── ProducerCard.gd
		└── UpgradePanel.gd
```

**Autoload order** (critical — later singletons depend on earlier ones):
`ConfigManager → StringManager → ResourceManager → ProducerManager → SaveManager → GameManager → Utils`

---

## Editing Game Data

All tuning is done in `data/` — no code changes required.

### config.json

| Key | Description |
|-----|-------------|
| `default_language` | `"en"` or `"fr"` — active language at startup |
| `main_resource` | Resource ID used throughout (default `"gold"`) |
| `auto_save_interval_seconds` | Autosave frequency |
| `offline_cap_hours` | Max offline time credited to the player |
| `offline_factor` | Fraction of normal RPS applied offline (0.0–1.0) |
| `click_base_value` | Gold per manual click before upgrade multipliers |

### producers.json

| Field | Description |
|-------|-------------|
| `id` | Unique string identifier |
| `display_name` | Shown in UI |
| `base_cost` | Cost of the first unit |
| `cost_growth_rate` | Exponential multiplier per unit owned (e.g. `1.15`) |
| `base_production` | Gold per second per unit owned |

### upgrades.json

| Field | Description |
|-------|-------------|
| `unlock_type` | `"OWNED_COUNT"` or `"RESOURCE_TOTAL"` |
| `unlock_producer_id` | Producer to check (OWNED_COUNT only) |
| `unlock_threshold` | Value that triggers unlock |
| `effect_type` | `"MULTIPLY_PRODUCER"`, `"MULTIPLY_ALL"`, `"MULTIPLY_CLICK"` |
| `effect_multiplier` | Multiplier applied on purchase |

### Adding a language

1. Copy `data/strings_en.json` → `data/strings_<code>.json`
2. Translate every value (keys must stay identical).
3. Add the new code to the `langs` array in `Main.gd → _on_lang_button_pressed()`.

The `StringManager` fallback system ensures that any key missing in the new
file automatically resolves to the English string, so partial translations
are safe at runtime.

### Exporting data from a spreadsheet

```python
import json, openpyxl
wb = openpyxl.load_workbook("producers.xlsx")
ws = wb.active
headers = [cell.value for cell in ws[1]]
rows = [dict(zip(headers, [c.value for c in row])) for row in ws.iter_rows(min_row=2)]
with open("data/producers.json", "w") as f:
	json.dump(rows, f, indent="\t", ensure_ascii=False)
```
