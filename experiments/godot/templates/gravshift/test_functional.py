#!/usr/bin/env python3
"""
test_functional.py — Gravshift functional test suite
Convention v2.3.0 — T01–T14 adapted for this project.
Run from the gravshift/ root directory.
"""

import os
import re
import sys
import json

fails: list = []
warnings: list = []

SCRIPTS_DIR = "scripts"
SCENES_DIR = "scenes"
DATAS_DIR = "datas"

REQUIRED_DIRS = [
    "datas",
    "scenes/core",
    "scenes/ui",
    "scenes/entities",
    "scripts/core",
    "scripts/ui",
    "scripts/entities",
    "assets/fonts",
    "assets/sounds",
    "assets/textures",
    "addons",
]

REQUIRED_SCRIPTS = [
    "scripts/core/game_manager.gd",
    "scripts/core/spawner.gd",
    "scripts/core/gravity_field.gd",
    "scripts/ui/hud.gd",
    "scripts/entities/player.gd",
    "scripts/entities/bullet.gd",
    "scripts/entities/enemy_linear.gd",
    "scripts/entities/enemy_wave.gd",
    "scripts/entities/enemy_bullet.gd",
]

REQUIRED_SETTINGS_GAMEPLAY_KEYS = [
    "scroll_speed",
    "player_speed",
    "gravity_radius",
    "gravity_strength",
    "bullet_speed",
    "enemy_bullet_speed",
    "wave_count",
    "enemies_per_wave",
]

REQUIRED_STRINGS_GAMEPLAY_KEYS = ["wave", "best", "press_start"]
REQUIRED_STRINGS_FEEDBACK_KEYS = ["player_death", "wave_clear", "run_complete"]


def fail(msg: str) -> None:
    fails.append(f"FAIL  {msg}")


def warn(msg: str) -> None:
    warnings.append(f"WARN  {msg}")


def gd_files():
    for root, _dirs, files in os.walk(SCRIPTS_DIR):
        for fname in files:
            if fname.endswith(".gd"):
                path = os.path.join(root, fname)
                with open(path, encoding="utf-8") as fh:
                    lines = fh.readlines()
                yield path, lines


def tscn_files():
    for root, _dirs, files in os.walk(SCENES_DIR):
        for fname in files:
            if fname.endswith(".tscn"):
                path = os.path.join(root, fname)
                with open(path, encoding="utf-8") as fh:
                    content = fh.read()
                yield path, content


# ── T01 — project structure ───────────────────────────────────────────────────

def test_project_structure() -> None:
    for d in REQUIRED_DIRS:
        if not os.path.isdir(d):
            fail(f"T01 missing required directory: {d}")
    for s in REQUIRED_SCRIPTS:
        if not os.path.isfile(s):
            fail(f"T01 missing required script: {s}")
    if not os.path.isfile("project.godot"):
        fail("T01 missing project.godot")
    if not os.path.isfile("README.md"):
        fail("T01 missing README.md")
    if not os.path.isfile("CONVENTION.md"):
        fail("T01 missing CONVENTION.md at project root")
    if not os.path.isfile("scenes/core/main.tscn"):
        fail("T01 missing scenes/core/main.tscn")


# ── T02 — settings.json structure ────────────────────────────────────────────

def test_settings_json() -> None:
    path = os.path.join(DATAS_DIR, "settings.json")
    if not os.path.isfile(path):
        fail("T02 missing datas/settings.json")
        return
    with open(path, encoding="utf-8") as fh:
        try:
            data = json.load(fh)
        except json.JSONDecodeError as e:
            fail(f"T02 settings.json is not valid JSON: {e}")
            return
    if "meta" not in data:
        fail("T02 settings.json missing 'meta' key")
    else:
        if "convention_version" not in data["meta"]:
            fail("T02 settings.json meta missing 'convention_version'")
    if "gameplay" not in data:
        fail("T02 settings.json missing 'gameplay' section")
    else:
        for key in REQUIRED_SETTINGS_GAMEPLAY_KEYS:
            if key not in data["gameplay"]:
                fail(f"T02 settings.json gameplay missing key: {key}")


# ── T03 — strings json ────────────────────────────────────────────────────────

def test_strings_json() -> None:
    for lang in ["fr", "en"]:
        path = os.path.join(DATAS_DIR, f"strings_{lang}.json")
        if not os.path.isfile(path):
            fail(f"T03 missing datas/strings_{lang}.json")
            continue
        with open(path, encoding="utf-8") as fh:
            try:
                data = json.load(fh)
            except json.JSONDecodeError as e:
                fail(f"T03 strings_{lang}.json invalid JSON: {e}")
                continue
        gameplay = data.get("gameplay", {})
        feedback = data.get("feedback", {})
        for key in REQUIRED_STRINGS_GAMEPLAY_KEYS:
            if key not in gameplay:
                fail(f"T03 strings_{lang}.json gameplay missing key: {key}")
        for key in REQUIRED_STRINGS_FEEDBACK_KEYS:
            if key not in feedback:
                fail(f"T03 strings_{lang}.json feedback missing key: {key}")
        # Check no empty values
        for section_name, section in [("gameplay", gameplay), ("feedback", feedback)]:
            for k, v in section.items():
                if not str(v).strip():
                    fail(f"T03 strings_{lang}.json {section_name}.{k} is empty")


# ── T04 — duplicate functions ─────────────────────────────────────────────────

def test_duplicate_functions() -> None:
    for path, lines in gd_files():
        seen: dict = {}
        func_pat = re.compile(r"^func (\w+)\s*\(")
        for i, line in enumerate(lines, 1):
            m = func_pat.match(line.strip())
            if m:
                name = m.group(1)
                if name in seen:
                    fail(f"T04 duplicate function '{name}' at {path}:{i} (first at line {seen[name]})")
                else:
                    seen[name] = i


# ── T05 — return types on all functions ──────────────────────────────────────

def test_return_types() -> None:
    func_pat = re.compile(r"^func \w+\([^)]*\)\s*:")
    for path, lines in gd_files():
        for i, line in enumerate(lines, 1):
            stripped = line.strip()
            if func_pat.match(stripped) and not stripped.startswith("#"):
                fail(f"T05 function missing return type at {path}:{i}: {stripped}")


# ── T06 — dead signals (declared but never emitted) ──────────────────────────

def test_dead_signals() -> None:
    for path, lines in gd_files():
        content = "".join(lines)
        sig_decl_pat = re.compile(r"^signal (\w+)", re.MULTILINE)
        for m in sig_decl_pat.finditer(content):
            sig_name = m.group(1)
            if f"{sig_name}.emit(" not in content:
                fail(f"T06 signal '{sig_name}' declared but never emitted in {path}")


# ── T07 — deprecated Godot 3 syntax ──────────────────────────────────────────

def test_godot3_syntax() -> None:
    for path, lines in gd_files():
        for i, line in enumerate(lines, 1):
            if re.search(r'\bemit_signal\s*\(', line):
                fail(f"T07 deprecated emit_signal() at {path}:{i}")
            if re.search(r'\.connect\s*\(\s*"', line):
                fail(f"T07 deprecated string connect() at {path}:{i}")


# ── T08 — unused parameters without _ prefix ─────────────────────────────────

def test_unused_params() -> None:
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


# ── T09 — add_child in physics callbacks ─────────────────────────────────────

def test_physics_add_child() -> None:
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

def test_mouse_filter() -> None:
    # This project builds UI by code — containers have mouse_filter set in scripts.
    # Check that hud.gd sets mouse_filter = MOUSE_FILTER_IGNORE on non-interactive nodes.
    path = "scripts/ui/hud.gd"
    if not os.path.isfile(path):
        fail("T10 missing scripts/ui/hud.gd")
        return
    with open(path, encoding="utf-8") as fh:
        content = fh.read()
    if "MOUSE_FILTER_IGNORE" not in content:
        warn("T10 hud.gd may be missing MOUSE_FILTER_IGNORE on layout containers")


# ── T11 — main.tscn hierarchy ────────────────────────────────────────────────

def test_main_tscn() -> None:
    path = os.path.join(SCENES_DIR, "core", "main.tscn")
    if not os.path.exists(path):
        fail("T11 missing scenes/core/main.tscn")
        return
    with open(path, encoding="utf-8") as fh:
        content = fh.read()
    # PATTERN 25: main.tscn must be minimal (no sub_resource, no instance=, no uid=)
    if "sub_resource" in content:
        fail("T11 main.tscn contains sub_resource — violates PATTERN 25")
    if "instance=" in content:
        fail("T11 main.tscn contains instance= — violates PATTERN 25")
    # Must reference game_manager script
    if "game_manager.gd" not in content:
        fail("T11 main.tscn does not reference game_manager.gd")
    # Check that game_manager.gd builds the hierarchy (GameManager, World, UI, HUD, Transitions)
    gm_path = "scripts/core/game_manager.gd"
    if os.path.isfile(gm_path):
        with open(gm_path, encoding="utf-8") as fh:
            gm_content = fh.read()
        for required in ("World", "UI", "HUD", "Transitions"):
            if f'"{required}"' not in gm_content and f"name = \"{required}\"" not in gm_content:
                fail(f"T11 game_manager.gd does not build node: {required}")


# ── T12 — twist_activated signal ─────────────────────────────────────────────

def test_twist_activated() -> None:
    found_emit = False
    for path, lines in gd_files():
        content = "".join(lines)
        if "twist_activated.emit(" in content:
            found_emit = True
            break
    if not found_emit:
        fail("T12 twist_activated.emit() not found in any script")


# ── T13 — no hardcoded display strings ───────────────────────────────────────

def test_no_hardcoded_strings() -> None:
    suspicious = re.compile(r'(?:add_text|text\s*=\s*|label\.text\s*=\s*)"[A-Za-z ]{4,}"')
    for path, lines in gd_files():
        for i, line in enumerate(lines, 1):
            if suspicious.search(line) and "strings[" not in line and "[" not in line:
                # Allow "GRAVSHIFT" title and structural names — warn only
                warn(f"T13 possible hardcoded display string at {path}:{i}: {line.strip()}")


# ── T14 — folder names free of bash brace expansion artifacts ────────────────

def test_folder_names() -> None:
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
