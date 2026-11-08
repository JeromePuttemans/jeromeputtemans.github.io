#!/usr/bin/env python3
"""Functional tests — run from the shmup project root directory."""

import os
import re
import json
import sys
from collections import Counter

GENRE = os.path.basename(os.getcwd())  # inferred from current directory
SCRIPTS_DIR = "scripts"
SCENES_DIR  = "scenes"
DATAS_DIR   = "datas"

fails    = []
warnings = []

# ── helpers ───────────────────────────────────────────────────────────────────

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

# ── T01 — project structure ───────────────────────────────────────────────────

def test_project_structure():
    required = [
        "project.godot", "README.md", "CONVENTION.md",
        os.path.join(DATAS_DIR, "settings.json"),
        os.path.join(DATAS_DIR, "strings_fr.json"),
        os.path.join(DATAS_DIR, "strings_en.json"),
        os.path.join(SCRIPTS_DIR, "core", "game_manager.gd"),
        os.path.join(SCRIPTS_DIR, "core", "spawner.gd"),
        os.path.join(SCRIPTS_DIR, "ui", "hud.gd"),
        os.path.join(SCRIPTS_DIR, "entities", "player.gd"),
        os.path.join(SCRIPTS_DIR, "entities", "bullet.gd"),
        os.path.join(SCRIPTS_DIR, "entities", "enemy_straight.gd"),
        os.path.join(SCRIPTS_DIR, "entities", "enemy_sine.gd"),
        os.path.join(SCENES_DIR, "core", "main.tscn"),
        os.path.join(SCENES_DIR, "ui", "hud.tscn"),
        os.path.join(SCENES_DIR, "entities", "player.tscn"),
        os.path.join(SCENES_DIR, "entities", "bullet.tscn"),
        os.path.join(SCENES_DIR, "entities", "enemy_straight.tscn"),
        os.path.join(SCENES_DIR, "entities", "enemy_sine.tscn"),
    ]
    for path in required:
        if not os.path.exists(path):
            fail(f"T01 missing required file: {path}")

# ── T02 — settings.json schema ────────────────────────────────────────────────

def test_settings_json():
    path = os.path.join(DATAS_DIR, "settings.json")
    if not os.path.exists(path):
        fail("T02 settings.json missing")
        return
    with open(path, encoding="utf-8") as fh:
        try:
            data = json.load(fh)
        except json.JSONDecodeError as e:
            fail(f"T02 settings.json invalid JSON: {e}")
            return

    gameplay_keys = [
        "player_speed_base", "player_speed_min", "fire_speed_penalty",
        "bullet_speed", "scroll_speed", "enemy_spawn_interval",
        "player_hp", "bullet_lifetime"
    ]
    gameplay = data.get("gameplay", {})
    for key in gameplay_keys:
        if key not in gameplay:
            fail(f"T02 settings.json missing gameplay key: {key}")

    meta = data.get("meta", {})
    if "convention_version" not in meta:
        fail("T02 settings.json missing meta.convention_version")

# ── T03 — strings json completeness ──────────────────────────────────────────

def test_strings_json():
    for lang in ("strings_fr.json", "strings_en.json"):
        path = os.path.join(DATAS_DIR, lang)
        if not os.path.exists(path):
            fail(f"T03 {lang} missing")
            continue
        with open(path, encoding="utf-8") as fh:
            try:
                data = json.load(fh)
            except json.JSONDecodeError as e:
                fail(f"T03 {lang} invalid JSON: {e}")
                continue
        gameplay = data.get("gameplay", {})
        feedback = data.get("feedback", {})
        for key in ("score", "score_unit", "best", "press_start"):
            if key not in gameplay:
                fail(f"T03 {lang} missing gameplay key: {key}")
        for key in ("game_over", "new_best"):
            if key not in feedback:
                fail(f"T03 {lang} missing feedback key: {key}")
        # Sections must not be empty
        if not gameplay:
            fail(f"T03 {lang} gameplay section is empty")
        if not feedback:
            fail(f"T03 {lang} feedback section is empty")

# ── T04 — no duplicate functions ──────────────────────────────────────────────

def test_duplicate_functions():
    for path, lines in gd_files():
        func_names = [
            re.match(r"^func (\w+)\(", l.strip()).group(1)
            for l in lines
            if re.match(r"^func (\w+)\(", l.strip())
        ]
        counts = Counter(func_names)
        for name, count in counts.items():
            if count > 1:
                fail(f"T04 duplicate function '{name}' in {path}")

# ── T05 — return types declared ───────────────────────────────────────────────

def test_return_types():
    pattern = re.compile(r"^func \w+\([^)]*\)\s*:")
    for path, lines in gd_files():
        for i, line in enumerate(lines, 1):
            if pattern.match(line.strip()):
                fail(f"T05 missing return type at {path}:{i}: {line.strip()}")

# ── T06 — no dead signals ─────────────────────────────────────────────────────

def test_dead_signals():
    for path, lines in gd_files():
        content = "".join(lines)
        declared = re.findall(r"^signal (\w+)", content, re.MULTILINE)
        for sig in declared:
            if f"{sig}.emit(" not in content:
                fail(f"T06 dead signal '{sig}' in {path} (declared, never emitted)")

# ── T07 — no deprecated Godot 3 signal syntax ────────────────────────────────

def test_godot3_syntax():
    for path, lines in gd_files():
        for i, line in enumerate(lines, 1):
            if "emit_signal(" in line:
                fail(f"T07 deprecated emit_signal() at {path}:{i}")
            if re.search(r'\.connect\s*\(\s*"', line):
                fail(f"T07 deprecated string connect() at {path}:{i}")

# ── T08 — unused parameters without _ prefix ─────────────────────────────────

def test_unused_params():
    func_pattern = re.compile(r"^func (\w+)\(([^)]*)\)\s*(->.*)?:")
    for path, lines in gd_files():
        content = "".join(lines)
        for m in func_pattern.finditer(content):
            params_raw = m.group(2)
            if not params_raw.strip():
                continue
            for param in params_raw.split(","):
                param = param.strip().split(":")[0].strip()
                if not param or param.startswith("_"):
                    continue
                uses = len(re.findall(rf"\b{re.escape(param)}\b", content))
                if uses <= 1:
                    warn(f"T08 param '{param}' possibly unused in {path} — prefix with _ if intentional")

# ── T09 — no add_child in physics callbacks ───────────────────────────────────

def test_physics_add_child():
    physics_signals = ("area_entered", "body_entered", "area_exited", "body_exited")
    for path, lines in gd_files():
        in_physics = False
        depth = 0
        for i, line in enumerate(lines, 1):
            stripped = line.strip()
            if any(f"_{sig}" in stripped or f"on_{sig}" in stripped for sig in physics_signals):
                in_physics = True
                depth = 0
            if in_physics:
                depth += stripped.count("{") + stripped.count(":")
                depth -= stripped.count("}")
                if "add_child(" in stripped and "call_deferred" not in stripped:
                    fail(f"T09 add_child() in physics callback at {path}:{i} — use call_deferred")
                if depth <= 0 and i > 1:
                    in_physics = False

# ── T10 — mouse_filter on UI containers ──────────────────────────────────────

def test_mouse_filter():
    container_types = ("HBoxContainer", "VBoxContainer", "GridContainer",
                       "Label", "RichTextLabel", "ColorRect")
    for path, content in tscn_files():
        if "UI/HUD" not in content and "CanvasLayer" not in content:
            continue
        for node_type in container_types:
            pattern = re.compile(
                rf'\[node[^\]]*type="{node_type}"[^\]]*\]([^\[]*)',
                re.DOTALL
            )
            for m in pattern.finditer(content):
                block = m.group(1)
                if "mouse_filter = 2" not in block:
                    warn(f"T10 {node_type} in {path} may be missing mouse_filter = 2")

# ── T11 — main.tscn hierarchy ────────────────────────────────────────────────

def test_main_tscn():
    # Architecture: nodes are built by code in game_manager.gd, not in main.tscn.
    # T11 verifies main.tscn exists and references game_manager.gd,
    # then checks game_manager.gd builds the required nodes.
    tscn_path = os.path.join(SCENES_DIR, "core", "main.tscn")
    if not os.path.exists(tscn_path):
        fail("T11 missing scenes/core/main.tscn")
        return
    with open(tscn_path, encoding="utf-8") as fh:
        tscn_content = fh.read()
    if "game_manager.gd" not in tscn_content:
        fail("T11 main.tscn does not reference game_manager.gd")
    gm_path = os.path.join(SCRIPTS_DIR, "core", "game_manager.gd")
    if not os.path.exists(gm_path):
        fail("T11 missing scripts/core/game_manager.gd")
        return
    with open(gm_path, encoding="utf-8") as fh:
        gm_content = fh.read()
    for required in ("World", "UI", "HUD", "Transitions"):
        if required not in gm_content:
            fail(f"T11 game_manager.gd missing node construction: {required}")

# ── T12 — twist_activated signal ─────────────────────────────────────────────

def test_twist_activated():
    found_emit = False
    for path, lines in gd_files():
        content = "".join(lines)
        if "twist_activated.emit(" in content:
            found_emit = True
            break
    if not found_emit:
        fail("T12 twist_activated.emit() not found in any script")

# ── T13 — no hardcoded display strings ───────────────────────────────────────

def test_no_hardcoded_strings():
    suspicious = re.compile(r'(?:add_text|text\s*=\s*|label\.text\s*=\s*)"[A-Za-z ]{4,}"')
    for path, lines in gd_files():
        for i, line in enumerate(lines, 1):
            if suspicious.search(line) and "strings[" not in line and "[" not in line:
                warn(f"T13 possible hardcoded display string at {path}:{i}: {line.strip()}")

# ── T14 — folder names free of bash brace expansion artifacts ────────────────

def test_folder_names():
    bad = re.compile(r"[{},]")
    for root, dirs, _ in os.walk("."):
        for d in dirs:
            if bad.search(d):
                fail(f"T14 invalid folder name (brace expansion artifact?): {os.path.join(root, d)}")

# ── run all tests ─────────────────────────────────────────────────────────────

if __name__ == "__main__":
    tests = [
        test_project_structure,
        test_settings_json,
        test_strings_json,
        test_duplicate_functions,
        test_return_types,
        test_dead_signals,
        test_godot3_syntax,
        test_unused_params,
        test_physics_add_child,
        test_mouse_filter,
        test_main_tscn,
        test_twist_activated,
        test_no_hardcoded_strings,
        test_folder_names,
    ]
    for t in tests:
        t()

    if warnings:
        print("\n── WARNINGS (informational) ──")
        for w in warnings:
            print(w)

    if fails:
        print("\n── FAILURES ──")
        for f in fails:
            print(f)
        print(f"\n{len(fails)} FAIL(s) — fix before producing the .zip")
        sys.exit(1)
    else:
        print("\nALL TESTS PASSED")
        sys.exit(0)
