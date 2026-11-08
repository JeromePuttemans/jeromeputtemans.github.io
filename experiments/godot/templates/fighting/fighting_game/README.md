# GDFighter — Prototype Fighting Game (Godot 4.x)

## Genre : Combat / Fighting
Duels techniques en 2D, combos, versus local (P1 vs P2).  
Références : Street Fighter II, Guilty Gear, Skullgirls.

---

## Arborescence du projet

```
fighting_game/
├── project.godot              ← Configuration Godot 4, input map, autoloads
├── settings.json              ← Source de vérité unique pour tous les paramètres
├── scenes/
│   ├── MainMenu.tscn          ← Écran d'accueil
│   └── Arena.tscn             ← Scène de combat principale
├── scripts/
│   ├── SettingsManager.gd     ← Autoload : lecture/validation de settings.json
│   ├── FighterStateMachine.gd ← FSM du personnage (enum explicite)
│   ├── InputBuffer.gd         ← Ring buffer d'input (30 frames)
│   ├── Fighter.gd             ← Contrôleur principal du combattant
│   ├── RoundManager.gd        ← Gestion des rounds et du match
│   ├── HUD.gd                 ← Affichage (barres de vie, timer, combos)
│   └── MainMenu.gd            ← Menu principal
├── translations/
│   └── translations.csv       ← Textes EN + FR
└── assets/
    ├── sounds/                ← Placeholders audio (à remplir)
    └── sprites/               ← Sprites animés (AnimatedSprite2D)
```

---

## Systèmes implémentés — explication pédagogique

### 1. SettingsManager (Autoload Singleton)
**Pattern :** Singleton via Autoload Godot  
**Pourquoi :** Centralise tous les paramètres en un seul fichier JSON externe. Le jeu ne contient aucun "magic number". Modifier la vitesse de marche ou les dégâts ne nécessite aucune recompilation.  
**Structure algorithmique :** Traversal de dictionnaire par chemin point-séparé (`"fighter.walk_speed"`). Validation JSON avant usage (sécurité).

### 2. FighterStateMachine (FSM Enum)
**Pattern :** Finite State Machine à enum explicite  
**Pourquoi :** Dans un jeu de combat, les transitions d'état doivent être déterministes et auditables. Un enum FSM rend les transitions illégales visibles au compilateur et évite les bugs de "doubly-entered states".  
**États :** `IDLE → WALK → JUMP → ATTACK → BLOCK → HITSTUN → BLOCKSTUN → DASH → KO`  
**Guard rules :** KO est terminal. HITSTUN/BLOCKSTUN ne peuvent quitter que vers IDLE.

### 3. InputBuffer (Ring Buffer)
**Pattern :** Circular buffer (anneau)  
**Pourquoi :** Les jeux de combat ont besoin d'un historique d'input pour :
- La "leniency" (tolérance de timing sur les coups)
- La détection de motions (↓↘→ = Hadouken)
- L'anti-spam (vérifier si une action a été pressée dans les N dernières frames)  
**Complexité :** O(1) insertion, O(N) vérification de motion (N = fenêtre en frames).  
**Mémoire :** Pré-allouée à l'init — aucune allocation en boucle.

### 4. Frame Data System (Fighter.gd)
**Concept clé du genre :** Chaque attaque a 3 phases :
- **Startup** : frames avant que la hitbox soit active (anticipation)
- **Active** : frames où la hitbox peut toucher (fenêtre de hit)
- **Recovery** : frames de vulnérabilité après l'attaque

Ces valeurs sont dans `settings.json` et converties en durées via `frames / target_fps`.  
**Implémentation :** Timer one-shot Godot (`FrameDataTimer`), changement de phase sur `timeout`.

### 5. Hitstop (Game Feel)
**Référence :** Steve Swink — "Game Feel", chapitre sur la réponse temporelle  
**Implémentation :** Quand un coup touche, les deux combattants "gèlent" pendant `hitstop` secondes (valeur dans `settings.json`). En `_physics_process`, si `_hitstop_remaining > 0`, on décrémente et on `return` immédiatement.  
**Effet :** Le joueur perçoit l'impact physiquement — c'est le cœur du "punch feel".

### 6. Système de Collision (Hitbox/Hurtbox)
**Layers Godot :**
- Layer 2 = Hitbox (corps physique)  
- Layer 4 = AttackHitbox (hitbox d'attaque, active seulement pendant les frames actives)  
- Hurtbox écoute sur mask 4 → reçoit les AttackHitbox adverses

**Séparation intentionnelle :** Hitbox ≠ Hurtbox ≠ AttackHitbox. Cela permet du "proximity blocking" et des invincibilités partielles dans une extension.

### 7. RoundManager (Flow du match)
**Pattern :** State machine linéaire + Observer (signaux)  
**Séquence :** Countdown → FIGHTING → (KO ou timeout) → round suivant → MATCH_OVER  
**Découplement :** Le RoundManager ne touche jamais le HUD directement — il émet des signaux. L'Arena fait le câblage. Le HUD est une vue pure.

### 8. Camera Shake (Steve Swink)
**Implémentation :** Interpolation exponentielle de la déviation caméra sur `shake_duration` secondes. `t = 1 - elapsed/duration` → force décroissante. Random offset par frame.  
**Communication :** Fighter appelle `get_tree().call_group("arena", "trigger_shake")` — couplage zéro.

### 9. HUD (Pure View)
**Pattern :** Observer / MVP (Model-View)  
**Principe :** Le HUD reçoit des données via des callbacks de signaux, ne lit jamais l'état du jeu. Lerp sur les barres de vie (lissage visuel via `ui.health_bar_lerp_speed`). Squash/stretch sur les annonces (Tween Godot).

---

## Schéma de l'architecture des scènes et des signaux

```
[Autoload]
  SettingsManager
        │ get_value()
        ▼
[Arena (Node2D)]
  ├── Camera2D
  ├── RoundManager
  │     ├── signal round_started ──────────► HUD._on_round_started()
  │     ├── signal round_ended  ──────────► HUD._on_round_ended()
  │     ├── signal match_ended  ──────────► Arena._on_match_ended()
  │     ├── signal timer_updated ─────────► HUD._on_timer_updated()
  │     └── signal countdown_tick ────────► HUD._on_countdown_tick()
  │
  ├── FighterP1 (CharacterBody2D)
  │     ├── FighterStateMachine
  │     ├── InputBuffer
  │     ├── signal health_changed ────────► HUD._on_p1_health_changed()
  │     ├── signal died ─────────────────► RoundManager._on_fighter_died(0)
  │     └── signal hit_landed ───────────► Arena._on_hit_landed()
  │
  ├── FighterP2 (CharacterBody2D)
  │     └── [mêmes signaux → P2]
  │
  └── HUD (CanvasLayer)
        └── [Pure View — aucun signal sortant]
```

---

## Contrôles

| Action         | Joueur 1 | Joueur 2     |
|----------------|----------|--------------|
| Gauche/Droite  | A / D    | ← / →        |
| Sauter         | W        | ↑            |
| Baisser        | S        | ↓            |
| Light Punch    | U        | Num 7        |
| Heavy Punch    | I        | Num 8        |
| Light Kick     | J        | Num 4        |
| Heavy Kick     | K        | Num 5        |
| Spécial / Dash | L        | Num 6        |
| Bloquer        | Y        | Num 2        |

---

## Paramètres configurables (settings.json)

Tous les paramètres de jeu sont externalisés. Exemples clés :

| Clé                              | Défaut | Effet                              |
|----------------------------------|--------|------------------------------------|
| `fighter.walk_speed`             | 220.0  | Vitesse de marche                  |
| `fighter.jump_velocity`          | -600.0 | Puissance du saut                  |
| `fighter.hitstun_duration`       | 0.25   | Durée de stun après un coup        |
| `fighter.attack_startup_frames`  | 4      | Frames d'anticipation d'attaque    |
| `fighter.attack_active_frames`   | 6      | Frames où la hitbox est active     |
| `moves.heavy_punch.damage`       | 18     | Dégâts du heavy punch              |
| `moves.heavy_punch.hitstop`      | 0.10   | Durée du freeze sur impact         |
| `camera.shake_strength`          | 8.0    | Amplitude du shake caméra          |
| `match.rounds_to_win`            | 2      | Rounds pour gagner le match        |

---

## Pistes d'extension

1. **Motion inputs** (QCF, DP) : Étendre `InputBuffer.check_motion()` avec une table de directions 8-way et une reconnaissance de séquences temporelles strictes.
2. **Système de combo avancé** : Chaînes d'annulation (cancel system) — permettre d'annuler la recovery d'une attaque légère en attaque lourde si elle touche.
3. **Super/Ultras** : Ajouter une jauge de "super" qui se remplit sur hit/block, déclenchement sur combinaison de boutons.
4. **Réseau (netcode)** : Implémenter du rollback netcode via la librairie GDRollback ou un client UDP manuel — le InputBuffer est déjà la fondation.
5. **AI** : BehaviorTree simple ou MCTS pour un adversaire CPU.
6. **Projectiles** : Ajouter une `ObjectPool<Projectile>` pour les Hadoukens — évite les instanciations répétées.
7. **Character select screen** : Scène intermédiaire entre menu et arena, avec des `Resource` Fighter définissant stats + sprites.
8. **Replays** : Enregistrer l'`InputBuffer` de chaque frame → rejouer déterministiquement.
