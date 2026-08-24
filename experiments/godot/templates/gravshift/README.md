# GRAVSHIFT

> Un shmup spatial où ta position courbe les trajectoires ennemies en temps réel.

---

## Concept

Dans GRAVSHIFT, le vaisseau joueur est lui-même une force physique : se déplacer génère un champ gravitationnel qui attire les ennemis à portée. Le joueur ne contrôle pas de tir séparé — il contrôle uniquement sa position. Mais sa position **redessine les trajectoires de tout ce qui l'entoure**.

**Le twist :** Se déplacer DOIT avoir un effet systémique sur les ennemis, indépendamment du tir. Le joueur qui ne bouge pas est en désavantage structurel.

---

## Comment jouer

| Action | Touche |
|---|---|
| Déplacement | ZQSD ou Flèches directionnelles |
| Lancer / Recommencer | Espace |

Le tir est automatique et continu — vous ne contrôlez que votre position.

---

## Palette

| Rôle | Couleur | Hex |
|---|---|---|
| Fond | Noir spatial | `#080818` |
| Joueur + champ | Cyan électrique | `#00e5ff` |
| Ennemis + projectiles | Rouge vif | `#ff4444` |
| UI + étoiles | Blanc cassé | `#e8e8e8` |

---

## Architecture technique

**Moteur :** Godot 4.2 — GDScript uniquement
**Résolution de base :** 1152×648 (16:9) — adaptative toutes résolutions
**Convention :** CONVENTION.md v2.3.0

### Hiérarchie de scène (construite par code — PATTERN 25)

```
Main (Node2D)  ← game_manager.gd
├── Background (ColorRect)
├── Stars (Node2D × 30 ColorRect)
├── World (Node2D)
│   ├── Bullets (Node2D)
│   ├── Enemies (Node2D)
│   ├── EnemyBullets (Node2D)
│   └── Player (CharacterBody2D)
├── Spawner (Node)
├── GravityField (Node)
├── UI (CanvasLayer layer=1)
│   └── HUD (Control)
└── Transitions (CanvasLayer layer=2)
    └── WaveTransition (Control)
```

### Signaux principaux

| Signal | Émetteur | Abonnés |
|---|---|---|
| `game_state_changed(state)` | game_manager | hud |
| `wave_started(wave_number)` | game_manager | hud, spawner |
| `player_died` | player | game_manager |
| `wave_cleared` | spawner | game_manager |
| `twist_activated` | gravity_field | game_manager, hud |
| `enemy_destroyed` | enemy_* | spawner |
| `best_wave_updated(best)` | game_manager | hud |

---

## États de jeu

```
TITLE → PLAYING → WAVE_TRANSITION → PLAYING (vague suivante)
                                  → WIN (toutes vagues complètes)
      → GAME_OVER → TITLE
```

---

## Périmètre prototype

- 3 vagues (paramétrable via `datas/settings.json`)
- 2 types d'ennemis : losange (linéaire) et chevron (oscillant)
- Champ gravitationnel actif — aura de 3 anneaux concentriques cyan
- Mort instantanée au contact — retour écran titre
- Affichage vague courante + meilleure vague sur écran titre
- Pas de score, pas de power-up, pas de boss, pas de musique

---

## Paramètres (datas/settings.json)

| Clé | Type | Défaut | Effet |
|---|---|---|---|
| `scroll_speed` | float | 60.0 | Vitesse défilement fond (non utilisé dans proto — étoiles statiques) |
| `player_speed` | float | 220.0 | Vitesse joueur px/s |
| `gravity_radius` | int | 180 | Rayon champ gravitationnel px |
| `gravity_strength` | float | 0.35 | Coefficient déviation ennemis |
| `bullet_speed` | float | 400.0 | Vitesse projectiles joueur px/s |
| `enemy_bullet_speed` | float | 180.0 | Vitesse projectiles ennemis px/s |
| `wave_count` | int | 3 | Nombre de vagues |
| `enemies_per_wave` | int | 6 | Ennemis par vague (base) |

---

## Lancer le projet

```bash
godot --path gravshift/
```

Ou ouvrir `gravshift/project.godot` dans l'éditeur Godot 4.
