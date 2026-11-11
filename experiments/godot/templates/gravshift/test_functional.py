#!/usr/bin/env python3
"""Functional tests for Gravshift: run from the gravshift project root."""

import os
import re
import json
import sys
from collections import Counter

SCRIPTS_DIR = "scripts"
SCENES_DIR = "scenes"
DATAS_DIR = "datas"

fails = []
warnings = []

# -- helpers -------------------------------------------------------------------

def fail(msg: str) -> None:
    fails.append(f"  FAIL  {msg}")

def warn(msg: str) -> None:
    warnings.append(f"  WARN  {msg}")

def gd_files():
    """Yield (path, lines) for every .gd file under SCRIPTS_DIR."""
    for root, _, files in os.walk(SCRIPTS_DIR):
        for f in files:
            if f.endswith(".gd"):
                path = os.path.join(root, f)
                with open(path, encoding="utf-8") as fh:
                    yield path, fh.readlines()

def tscn_files():
    """Yield (path, content) for every .tscn file under SCENES_DIR."""
    for root, _, files in os.walk(SCENES_DIR):
        for f in files:
            if f.endswith(".tscn"):
                path = os.path.join(root, f)
                with open(path, encoding="utf-8") as fh:
                    yield path, fh.read()

def load_json(name: str):
    path = os.path.join(DATAS_DIR, name)
    if not os.path.exists(path):
        return None
    with open(path, encoding="utf-8") as fh:
        try:
            return json.load(fh)
        except json.JSONDecodeError as e:
            fail(f"{name} invalid JSON: {e}")
            return None

# -- T01: project structure ----------------------------------------------------

def test_project_structure():
    required = [
        "project.godot", "README.md", "CONVENTION.md", "export_presets.cfg",
        os.path.join(DATAS_DIR, "settings.json"),
        os.path.join(DATAS_DIR, "strings_fr.json"),
        os.path.join(DATAS_DIR, "strings_en.json"),
        os.path.join(SCENES_DIR, "core", "main.tscn"),
    ]
    # Every node is built by code (CONVENTION.md): main.tscn is the only scene.
    for name in ("game_manager", "input_manager", "sfx_manager", "space_grid",
                 "effects", "bullet_field", "shots", "gravity_field", "spawner",
                 "combat", "upgrades"):
        required.append(os.path.join(SCRIPTS_DIR, "core", f"{name}.gd"))
    for name in ("hud", "screens"):
        required.append(os.path.join(SCRIPTS_DIR, "ui", f"{name}.gd"))
    for name in ("player", "enemy_base", "enemy_drone", "enemy_gunner",
                 "enemy_spinner", "enemy_lancer", "enemy_brute", "enemy_mine",
                 "boss_guardian", "boss_singularity"):
        required.append(os.path.join(SCRIPTS_DIR, "entities", f"{name}.gd"))
    for path in required:
        if not os.path.exists(path):
            fail(f"T01 missing required file: {path}")

# -- T02: settings.json schema and consistency ---------------------------------

def test_settings_json():
    data = load_json("settings.json")
    if data is None:
        fail("T02 settings.json missing or unreadable")
        return
    if "convention_version" not in data.get("meta", {}):
        fail("T02 settings.json missing meta.convention_version")
    gameplay = data.get("gameplay", {})
    for key in ("player_speed", "player_hp", "fire_interval", "bullet_speed",
                "flux_max", "flux_drain", "flux_regen", "pull_radius",
                "capture_radius", "orbit_capacity", "sling_speed", "sling_damage",
                "shockwave_radius", "crash_speed", "enemy_bullet_speed",
                "chain_window", "chain_per_multiplier", "multiplier_max"):
        if key not in gameplay:
            fail(f"T02 settings.json missing gameplay key: {key}")
    enemies = data.get("enemies", {})
    gd_dir = os.path.join(SCRIPTS_DIR, "entities")
    for kind, stats in enemies.items():
        for key in ("hp", "mass", "radius", "speed", "points", "color"):
            if key not in stats:
                fail(f"T02 enemy '{kind}' missing key: {key}")
        script = f"enemy_{kind}.gd" if os.path.exists(os.path.join(gd_dir, f"enemy_{kind}.gd")) else f"boss_{kind}.gd"
        if not os.path.exists(os.path.join(gd_dir, script)):
            fail(f"T02 enemy '{kind}' has no script in {gd_dir}")
    waves = data.get("waves", [])
    if not waves:
        fail("T02 settings.json has no waves")
    for i, wave in enumerate(waves, 1):
        if "boss" in wave and wave["boss"] not in enemies:
            fail(f"T02 wave {i} boss '{wave['boss']}' is not an enemy type")
        if not wave.get("groups") and "boss" not in wave:
            fail(f"T02 wave {i} has no enemies")
        for group in wave.get("groups", []):
            if group.get("type") not in enemies:
                fail(f"T02 wave {i} unknown enemy type: {group.get('type')}")
            if int(group.get("count", 0)) < 1:
                fail(f"T02 wave {i} group with no enemies: {group}")
    with open(os.path.join(SCRIPTS_DIR, "core", "upgrades.gd"), encoding="utf-8") as fh:
        upgrades_gd = fh.read()
    for up in data.get("upgrades", []):
        if f'"{up}"' not in upgrades_gd:
            fail(f"T02 upgrade '{up}' is not handled in upgrades.gd")

# -- T03: strings complete in both languages -----------------------------------

def test_strings_json():
    tables = {}
    for lang in ("fr", "en"):
        data = load_json(f"strings_{lang}.json")
        if data is None:
            fail(f"T03 strings_{lang}.json missing or unreadable")
            return
        tables[lang] = data
    fr, en = tables["fr"], tables["en"]
    for section in fr:
        for key in fr[section]:
            if key not in en.get(section, {}):
                fail(f"T03 strings_en.json missing {section}.{key}")
    for section in en:
        for key in en[section]:
            if key not in fr.get(section, {}):
                fail(f"T03 strings_fr.json missing {section}.{key}")
    # Every text("section", "key") call in the scripts must exist.
    call = re.compile(r'(?:text|_tx)\(\s*"(\w+)"\s*,\s*"(\w+)"\s*[,)]')
    for path, lines in gd_files():
        for i, line in enumerate(lines, 1):
            for section, key in call.findall(line):
                for lang, table in tables.items():
                    if key not in table.get(section, {}):
                        fail(f"T03 {path}:{i} uses {section}.{key}, missing in strings_{lang}.json")
    settings = load_json("settings.json") or {}
    for up in settings.get("upgrades", []):
        for prefix in ("name_", "desc_"):
            for lang, table in tables.items():
                if prefix + up not in table.get("upgrades", {}):
                    fail(f"T03 strings_{lang}.json missing upgrades.{prefix}{up}")
    # The web export font only covers Latin-1; the texts carry no "!".
    for lang, table in tables.items():
        for section, entries in table.items():
            for key, value in entries.items():
                if any(ord(ch) > 255 for ch in value):
                    fail(f"T03 strings_{lang}.json {section}.{key} has a glyph outside Latin-1")
                if "!" in value:
                    fail(f"T03 strings_{lang}.json {section}.{key} contains '!'")

# -- T04: no duplicate functions -----------------------------------------------

def test_duplicate_functions():
    for path, lines in gd_files():
        # Top-level functions only: an inner class has its own _ready or _draw.
        names = [m.group(1) for m in (re.match(r"^(?:static )?func (\w+)\(", l) for l in lines) if m]
        for name, count in Counter(names).items():
            if count > 1:
                fail(f"T04 duplicate function '{name}' in {path}")

# -- T05: return types declared ------------------------------------------------

def test_return_types():
    pattern = re.compile(r"^(static )?func \w+\([^)]*\)\s*:")
    for path, lines in gd_files():
        for i, line in enumerate(lines, 1):
            if pattern.match(line.strip()):
                fail(f"T05 missing return type at {path}:{i}: {line.strip()}")

# -- T06: no dead signals ------------------------------------------------------

def test_dead_signals():
    for path, lines in gd_files():
        content = "".join(lines)
        for sig in re.findall(r"^signal (\w+)", content, re.MULTILINE):
            if f"{sig}.emit(" not in content:
                fail(f"T06 dead signal '{sig}' in {path} (declared, never emitted)")

# -- T07: no Godot 3 signal syntax ---------------------------------------------

def test_godot3_syntax():
    for path, lines in gd_files():
        for i, line in enumerate(lines, 1):
            if "emit_signal(" in line:
                fail(f"T07 deprecated emit_signal() at {path}:{i}")
            if re.search(r'\.connect\s*\(\s*"', line):
                fail(f"T07 deprecated string connect() at {path}:{i}")

# -- T08: unused parameters without _ prefix -----------------------------------

def test_unused_params():
    func_pattern = re.compile(r"^(?:static )?func (\w+)\(([^)]*)\)\s*(->.*)?:", re.MULTILINE)
    for path, lines in gd_files():
        content = "".join(lines)
        for m in func_pattern.finditer(content):
            for param in m.group(2).split(","):
                param = param.strip().split(":")[0].split("=")[0].strip()
                if not param or param.startswith("_"):
                    continue
                if len(re.findall(rf"\b{re.escape(param)}\b", content)) <= 1:
                    warn(f"T08 param '{param}' possibly unused in {path}")

# -- T09: no add_child in physics callbacks ------------------------------------

def test_physics_add_child():
    physics = ("area_entered", "body_entered", "area_exited", "body_exited")
    for path, lines in gd_files():
        in_callback = False
        for i, line in enumerate(lines, 1):
            stripped = line.strip()
            if line.startswith("func "):
                in_callback = any(sig in stripped for sig in physics)
            if in_callback and "add_child(" in stripped and "call_deferred" not in stripped:
                fail(f"T09 add_child() in physics callback at {path}:{i}: use call_deferred")

# -- T10: mouse_filter on UI controls ------------------------------------------

def test_mouse_filter():
    # The HUD and the screens are drawn by code: they must not eat the clicks
    # meant for the upgrade cards (screens.gd handles them itself).
    path = os.path.join(SCRIPTS_DIR, "ui", "hud.gd")
    with open(path, encoding="utf-8") as fh:
        if "MOUSE_FILTER_IGNORE" not in fh.read():
            fail(f"T10 {path} does not set mouse_filter to MOUSE_FILTER_IGNORE")

# -- T11: main.tscn and the tree built by game_manager.gd ----------------------

def test_main_tscn():
    tscn_path = os.path.join(SCENES_DIR, "core", "main.tscn")
    if not os.path.exists(tscn_path):
        fail("T11 missing scenes/core/main.tscn")
        return
    with open(tscn_path, encoding="utf-8") as fh:
        if "game_manager.gd" not in fh.read():
            fail("T11 main.tscn does not reference game_manager.gd")
    gm_path = os.path.join(SCRIPTS_DIR, "core", "game_manager.gd")
    with open(gm_path, encoding="utf-8") as fh:
        gm_content = fh.read()
    for required in ("World", "UI", "HUD", "Transitions"):
        if f'"{required}"' not in gm_content:
            fail(f"T11 game_manager.gd does not build the node: {required}")
    with open("project.godot", encoding="utf-8") as fh:
        project = fh.read()
    if 'run/main_scene="res://scenes/core/main.tscn"' not in project:
        fail("T11 project.godot main scene is not scenes/core/main.tscn")

# -- T12: twist_activated signal -----------------------------------------------

def test_twist_activated():
    if not any("twist_activated.emit(" in "".join(lines) for _, lines in gd_files()):
        fail("T12 twist_activated.emit() not found in any script")

# -- T13: no hardcoded display strings -----------------------------------------

def test_no_hardcoded_strings():
    suspicious = re.compile(r'(?:draw_string\([^"]*|\.text\s*=\s*)"[A-Za-z]+ [A-Za-z ]+"')
    for path, lines in gd_files():
        for i, line in enumerate(lines, 1):
            if suspicious.search(line):
                warn(f"T13 possible hardcoded display string at {path}:{i}: {line.strip()}")

# -- T14: folder names free of brace expansion artifacts -----------------------

def test_folder_names():
    bad = re.compile(r"[{},]")
    for root, dirs, _ in os.walk("."):
        for d in dirs:
            if bad.search(d):
                fail(f"T14 invalid folder name (brace expansion artifact?): {os.path.join(root, d)}")

# -- run all tests -------------------------------------------------------------

if __name__ == "__main__":
    for t in (test_project_structure, test_settings_json, test_strings_json,
              test_duplicate_functions, test_return_types, test_dead_signals,
              test_godot3_syntax, test_unused_params, test_physics_add_child,
              test_mouse_filter, test_main_tscn, test_twist_activated,
              test_no_hardcoded_strings, test_folder_names):
        t()
    if warnings:
        print("\n-- WARNINGS (informational) --")
        for w in warnings:
            print(w)
    if fails:
        print("\n-- FAILURES --")
        for f in fails:
            print(f)
        print(f"\n{len(fails)} FAIL(s)")
        sys.exit(1)
    print("\nALL TESTS PASSED")
    sys.exit(0)
