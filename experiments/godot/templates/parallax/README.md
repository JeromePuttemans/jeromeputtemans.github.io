# PARALLAX — Shmup Prototype

> Un shoot'em up où tirer vous ralentit — chaque balle tirée est du temps volé à votre survie.

---

## Twist retenu

**Chaque projectile actif en vol réduit la vitesse du vaisseau.** La puissance de feu est empruntée sur la mobilité. Tirer trop longtemps = vaisseau trop lent = le scroll horizontal vous rattrape. Ne pas tirer = les ennemis vous atteignent. Chaque pression de la gâchette est un pari.

---

## Palette

| Rôle | Couleur | Code |
|---|---|---|
| Fond | Quasi-noir bleu nuit | `#06060f` |
| Joueur (repos) | Blanc bleuté | `#e8e8ff` |
| Ennemi | Rouge-rose vif | `#ff4455` |
| Danger / ralentissement | Jaune ambre | `#ffcc00` |

---

## Contrôles

| Touche | Action |
|---|---|
| Flèches / ZQSD | Déplacement 4 axes |
| Espace | Tirer / Lancer la partie |

---

## Mécaniques

1. **Tir → ralentissement** : chaque balle active réduit la vitesse de `fire_speed_penalty` pixels/sec (plancher : `player_speed_min`).
2. **Scroll mortel** : le défilement horizontal force le vaisseau vers la gauche. Sortie à gauche = mort.
3. **Ennemis** : deux types — trajectoire droite (losange rouge) et trajectoire sinusoïdale (triangle rouge).
4. **Score** : temps de survie en secondes, affiché en jeu et à la mort. Meilleur score de session sur l'écran titre.

---

## Boucle de jeu

```
TITLE → [Espace] → PLAYING → [mort] → GAME_OVER → [Espace] → TITLE
```

---

## Structure du projet

```
shmup/
├── project.godot
├── README.md
├── CONVENTION.md
├── datas/
│   ├── settings.json       — valeurs gameplay tunables
│   ├── strings_fr.json
│   └── strings_en.json
├── scenes/
│   ├── core/
│   │   ├── main.tscn
│   │   └── spawner.tscn    (intégré dans main.tscn)
│   ├── ui/
│   │   └── hud.tscn
│   └── entities/
│       ├── player.tscn
│       ├── bullet.tscn
│       ├── enemy_straight.tscn
│       └── enemy_sine.tscn
├── scripts/
│   ├── core/
│   │   ├── game_manager.gd
│   │   └── spawner.gd
│   ├── ui/
│   │   └── hud.gd
│   └── entities/
│       ├── player.gd
│       ├── bullet.gd
│       ├── enemy_straight.gd
│       └── enemy_sine.gd
├── assets/
│   ├── fonts/
│   ├── sounds/
│   └── textures/
├── addons/
└── test_functional.py
```

---

## Paramètres gameplay (`datas/settings.json`)

| Clé | Type | Valeur | Effet |
|---|---|---|---|
| `player_speed_base` | float | 220.0 | Vitesse sans tir |
| `player_speed_min` | float | 60.0 | Plancher vitesse sous tir continu |
| `fire_speed_penalty` | float | 8.0 | Malus par balle active (px/sec) |
| `bullet_speed` | float | 500.0 | Vitesse des projectiles |
| `scroll_speed` | float | 80.0 | Vitesse du scroll horizontal |
| `enemy_spawn_interval` | float | 2.0 | Intervalle entre ennemis (secondes) |
| `player_hp` | int | 1 | Vies (one-hit kill) |
| `bullet_lifetime` | float | 1.2 | Durée de vie d'un projectile |

---

## Lancement

Ouvrir le projet dans **Godot 4.2+** et lancer `scenes/core/main.tscn`.

---

## Référence technique

- Moteur : Godot 4.x, GDScript uniquement
- Convention : `CONVENTION.md` v2.0.0
- Résolution de référence : 1280×720, mode `canvas_items / expand`
- Aucun asset externe — formes primitives uniquement
