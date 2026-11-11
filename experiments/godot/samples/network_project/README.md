# Network Shader – Godot 4

Port du shader WebGL « Network » vers Godot 4.

## Fichiers

| Fichier | Rôle |
|---|---|
| `project.godot` | Configuration du projet |
| `Main.tscn` | Scène principale (ColorRect + UI) |
| `Main.gd` | Script GDScript (souris, sliders, uniforms) |
| `network.gdshader` | Shader canvas_item (port fidèle du GLSL WebGL) |

## Installation

1. Ouvre **Godot 4.2+** → « Import » → sélectionne ce dossier.
2. Lance la scène `Main.tscn` (F5 ou ▶).

## Comportement

- **Grille** de points fixes en fond.
- **Hub central** qui suit la souris avec inertie douce.
- **N branches** rayonnant du hub vers les intersections de la grille.
- **Glow** bleu/blanc sur les lignes et les nœuds.

## Contrôles UI (en bas de fenêtre)

| Slider | Effet |
|---|---|
| Branches | Nombre de branches (3 – 20) |
| Vitesse | Vitesse d'animation (0 – 3.0) |
| Glow | Intensité du halo (0.1 – 3.0) |

## Notes techniques

- Le shader tourne en **canvas_item** sur un `ColorRect` 512×512.
- Le paramètre `u_mouse` est en espace normalisé `[-1, 1]`,
  identique à l'original WebGL.
- La boucle de branches est fixée à **max = 20 itérations** (limite GLSL),
  avec un `break` conditionnel sur `u_n`.
- Pour redimensionner le canvas, modifie `SZ` dans `Main.gd`
  et ajuste `offset_right / offset_bottom` de `ColorRect` dans la scène.
