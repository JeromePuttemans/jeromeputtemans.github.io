# VR Path Recorder — Godot 4 / Meta Quest 2

Records the 3D movement of both controllers, exports the paths as **JSON**
(points + pressure + timestamps) and as a **GLB** mesh (tube + caps) ready
to import in Blender.

---

## Project structure

```
vr_path_recorder/
├── project.godot
├── export_presets.cfg
├── scenes/
│   └── Main.tscn
└── scripts/
	├── GameManager.gd   — state machine, buttons, countdown
	├── PathRecorder.gd  — 30 Hz path capture
	├── TubeRenderer.gd  — dynamic tube mesh + spherical caps
	└── ExportManager.gd — JSON + GLB export
```

---

## Controls (Meta Quest 2)

| Action | Button |
|---|---|
| Start countdown (3 s) → record | **A** or **B** — right controller |
| Save session | **Y** — left controller |
| Reset (discard, keep files) | Hold **X** 1 s — left controller |

Trigger pressure controls tube radius:
- **Pressure 0** → maximum radius (5 cm)
- **Pressure max** → point not recorded

---

## Requirements

1. **Godot 4.2+** with the **Android build template** installed
2. **Android SDK** (API level 29+)
3. **Meta Quest Developer Hub** or `adb` for sideloading
4. In Godot → Project Settings → XR → OpenXR: **enabled**

---

## Build & deploy

```bash
# Export APK from Godot editor:
# Project → Export → Android (Meta Quest 2) → Export Project

# Sideload via adb:
adb install VRPathRecorder.apk

# Retrieve exported files from the headset:
adb pull /sdcard/Android/data/com.yourname.vrpathrecorder/files/ ./exports/
```

---

## Output files

Each saved session produces two files in `user://` (internal Quest storage):

| File | Description |
|---|---|
| `session_001.json` | Raw points: position, rotation (quaternion), pressure, timestamp — for both controllers |
| `session_001.glb`  | Tube meshes + spherical caps — import directly into Blender |

Session numbers auto-increment; existing files are never overwritten.

---

## Importing into Blender

**GLB:**
`File → Import → glTF 2.0 (.glb)` — geometry arrives immediately, Y-up, 1 unit = 1 m.

**JSON (optional — for custom re-generation):**
Use a Python script in Blender's scripting workspace.
Each entry in `left` / `right` is:
```json
{
  "position":  [x, y, z],
  "rotation":  [qx, qy, qz, qw],
  "pressure":  0.42,
  "timestamp": 1.233
}
```

---

## Tuning

| Constant | File | Default | Effect |
|---|---|---|---|
| `MAX_RADIUS` | TubeRenderer.gd | `0.05` (5 cm) | Tube radius at pressure 0 |
| `TUBE_SIDES` | TubeRenderer.gd | `10` | Polygon resolution |
| `SAMPLE_RATE` | PathRecorder.gd | `30` Hz | Recording frequency |
| `LONG_PRESS_SEC` | GameManager.gd | `1.0` s | Reset hold duration |
