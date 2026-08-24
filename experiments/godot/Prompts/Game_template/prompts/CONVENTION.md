# CONVENTION.md — 
CONVENTION.md — Le standard technique universel
Ce sont les règles fondamentales qui s'appliquent à tous les projets sans exception. Il définit l'arborescence des fichiers, les règles de nommage (dossiers, scripts, assets), les règles GDScript obligatoires (typage, signaux, patterns interdits) et la checklist de conformité pré-livraison. Il prime sur tout le reste en cas de conflit. Une copie est même incluse physiquement dans chaque projet généré.

## Structure commune des prototypes Godot
<!-- VERSION : 2.3.0 — mise à jour avec ce fichier à chaque modification -->

> Ce document définit la structure de référence applicable à **tous les prototypes générés**, sans exception.
> Chaque projet Godot doit respecter cette convention.
> **Hiérarchie de priorité en cas de conflit :**
> `CONVENTION.md` > `SYSTEM_PROMPT.md` > `GAME_PROMPT.md`
> Cette convention prime sur toute instruction de `SYSTEM_PROMPT.md` ou `GAME_PROMPT.md`
> concernant la structure des fichiers, les règles GDScript et les nommages.
> **La version du document est tracée dans l'en-tête ci-dessus et dans `settings.json` (`meta.convention_version`).**

---

## Arborescence racine

```
[nom_du_genre]/                  # Nom en snake_case, ex: platformer, roguelike
├── project.godot
├── README.md
├── CONVENTION.md                # Copie de ce fichier (référence locale)
│
├── datas/
│   ├── settings.json
│   ├── strings_fr.json
│   └── strings_en.json
│
├── scenes/
│   ├── core/                    # main.tscn, game_over.tscn, title_screen.tscn
│   │                            # + scènes de systèmes propres au genre (grid.tscn, spawner.tscn…)
│   ├── ui/                      # hud.tscn et tout overlay UI autonome
│   └── entities/                # player.tscn, ennemis, objets interactifs
│
├── scripts/
│   ├── core/                    # game_manager.gd + scripts de systèmes propres au genre
│   ├── ui/                      # hud.gd et scripts d'overlays
│   └── entities/                # player.gd, scripts d'entités
│
├── assets/
│   ├── fonts/
│   ├── sounds/
│   └── textures/
│
├── addons/                      # Vide si inutilisé, toujours présent
└── test_functional.py           # Script de tests fonctionnels pré-livraison (obligatoire)
```

**Règle de placement des scènes systèmes :**
Toute scène propre à la mécanique centrale du genre (`grid.tscn`, `spawner.tscn`, `map.tscn`, `dungeon.tscn`…) va dans `scenes/core/`. Son script associé va dans `scripts/core/`. Ne jamais créer de dossier `misc/`, `systems/`, ou `other/`.

---

## Règles de nommage

### Dossiers
- `snake_case` uniquement
- Jamais de dossier `misc/`, `other/`, `temp/` — tout fichier a une place définie

### Fichiers de scènes (`.tscn`)
| Rôle | Convention | Exemple |
|---|---|---|
| Scène racine du jeu | `main.tscn` | `main.tscn` |
| Interface principale | `hud.tscn` | `hud.tscn` |
| Écran titre | `title_screen.tscn` | `title_screen.tscn` |
| Écran game over | `game_over.tscn` | `game_over.tscn` |
| Entité joueur | `player.tscn` | `player.tscn` |
| Entité générique | `[entite]_[variante].tscn` | `unit_fast.tscn`, `obstacle_moving.tscn` |
| Système propre au genre | `[nom_systeme].tscn` → `scenes/core/` | `grid.tscn`, `dungeon.tscn`, `spawner.tscn` |

### Fichiers de scripts (`.gd`)
- Même nom que la scène associée : `player.tscn` → `player.gd`
- Scripts sans scène : `[nom_systeme]_manager.gd`

### Nommage des variables et fonctions GDScript
- Variables de classe privées : préfixe `_` (ex : `_current_wave`, `_enemy_count`)
- Variables publiques / @export : sans préfixe (ex : `speed`, `damage`)
- Constantes : `UPPER_SNAKE_CASE` (ex : `MAX_TOWERS`, `BASE_HP`)
- Fonctions : `snake_case` — jamais abrégées (`_update_score()` pas `_upd_sc()`)
- Aucun nom de variable abrégé ou ambigu : `speed` pas `spd`, `target` pas `tgt`, `index` pas `idx`

### Assets
| Type | Convention | Exemple |
|---|---|---|
| Texture | `[sujet]_[etat].png` | `player_idle.png`, `unit_hit.png` |
| Son | `sfx_[action].wav` | `sfx_jump.wav`, `sfx_impact.wav` |
| Musique | `bgm_[contexte].ogg` | `bgm_gameplay.ogg` |
| Police | `font_[usage].ttf` | `font_ui.ttf`, `font_title.ttf` |

---

## Règles GDScript obligatoires

Ces règles s'appliquent à **chaque ligne de code produite**, sans exception.
Elles éliminent les erreurs de parsing et de runtime les plus fréquentes avant l'exécution.

### Typage explicite — règle absolue

**Toujours déclarer le type explicitement** (`var x: Type = …`) dans les cas suivants.
Ne jamais utiliser l'inférence (`:=`) quand la valeur de droite est de type `Variant` :

| Cas | Interdit | Obligatoire |
|---|---|---|
| Accès indexé sur `Array` non typé | `var x := arr[i]` | `var x: Type = arr[i] as Type` |
| Accès indexé sur `Dictionary` | `var x := dict[key]` | `var x: Type = dict[key] as Type` |
| Fonction sans type de retour déclaré | `var x := foo()` | `var x: Type = foo()` |
| Opérateur ternaire sur littéraux | `var x := "a" if b else "c"` | `var x: String = "a" if b else "c"` |
| Littéral tableau vide non typé | `var x := []` | `var x: Array = []` |
| Itération sur `Array` non typé | `for item in array:` | `for item_v in array:` puis `var item: Type = item_v as Type` |

L'inférence (`:=`) est **autorisée uniquement** quand le type de droite est non ambigu :
```gdscript
var tween := create_tween()          # OK — retourne Tween
var pos := Vector2(10.0, 20.0)       # OK — littéral typé
var count := rng.randi_range(0, 10)  # OK — retourne int
```

### Tableaux typés — forme préférée en Godot 4

Godot 4 supporte les tableaux génériques `Array[Type]`. Cette forme est **préférée** à `Array` + cast :
elle garantit le type à la compilation, supprime les casts en itération, et signale les erreurs de type
plus tôt.

```gdscript
# Forme de base — acceptable si le type varie dynamiquement
var waypoints: Array = []
var point: Vector2 = waypoints[i] as Vector2

# Forme préférée — Array[Type] garanti à la compilation
var waypoints: Array[Vector2] = []
for point in waypoints:          # point est déjà typé Vector2 — pas de cast nécessaire
    draw_line(point, ...)

# Déclaration d'un Array[Type] vide
var enemies: Array[Node2D] = []
```

**Règle de choix :**
- Si le type des éléments est connu et homogène → utiliser `Array[Type]`
- Si le tableau est hétérogène ou vient d'une source non typée (JSON, `get_children()`) → utiliser `Array` avec cast

### Type de retour obligatoire sur toutes les fonctions

Chaque fonction déclare son type de retour, sans exception :

```gdscript
# Interdit
func get_position():
    return Vector2(0.0, 0.0)

# Obligatoire
func get_position() -> Vector2:
    return Vector2(0.0, 0.0)

# Fonctions sans retour
func _ready() -> void:
    pass
```

### Cast explicite sur les accès à Array et Dictionary non typés

Tout accès indexé sur un `Array` ou `Dictionary` non typé doit être casté :

```gdscript
# Array de Vector2
var point: Vector2 = waypoints[i] as Vector2

# Dictionary String -> Node
var actor: Node2D = actors[id] as Node2D

# Array générique retourné par une fonction
var candidate: int = values[index] as int
```

### Continuations multi-lignes

Les expressions multi-lignes utilisent **exclusivement les parenthèses** comme délimiteur de continuation. La barre oblique inversée (`\`) n'est pas un opérateur de continuation valide en GDScript. Cette règle s'applique à tout opérateur réparti sur plusieurs lignes : `or`, `and`, `+`, `==`, `!=`, etc.

```gdscript
# Interdit
return state == STATE_IDLE \
    or state == STATE_WIN

# Obligatoire
return (state == STATE_IDLE
    or state == STATE_WIN)
```

### Typage des paramètres de fonction

Tous les paramètres sont typés :

```gdscript
# Interdit
func setup(pos, type):
    pass

# Obligatoire
func setup(pos: Vector2, type: String) -> void:
    pass
```

### Typage des variables exportées (@export)

Toute variable exportée doit être typée explicitement. Ne jamais utiliser `@export` sans annotation de type :

```gdscript
# Interdit
@export var speed = 100.0
@export var label_text = "Hello"

# Obligatoire
@export var speed: float = 100.0
@export var label_text: String = "Hello"
@export var target_node: NodePath = NodePath("")
```

### Signaux — déclaration, émission et syntaxe Godot 4

Tout signal déclaré dans une classe doit être émis dans cette même classe. Un signal déclaré mais jamais émis est supprimé — il indique soit du code mort, soit une émission manquante.

**En Godot 4, la syntaxe native d'émission est `signal_name.emit(args)`.** La fonction dépréciée `emit_signal("name", args)` (Godot 3) fonctionne encore mais ne doit pas être utilisée dans les nouveaux fichiers.

```gdscript
# Interdit — signal déclaré mais jamais émis dans la classe
signal entity_destroyed(score_value: int)

# Interdit — syntaxe Godot 3 dépréciée
signal entity_destroyed(score_value: int)
# ...
emit_signal("entity_destroyed", score_value)

# Obligatoire — syntaxe Godot 4, signal déclaré ET émis dans la même classe
signal entity_destroyed(score_value: int)
# ...
entity_destroyed.emit(score_value)
```

### Validité des nœuds avant accès — is_instance_valid()

Avant tout accès à un nœud référencé en dehors de l'arbre de scène (stocké dans une variable de classe, passé en paramètre, retourné par une fonction), vérifier sa validité avec `is_instance_valid()`. Les nœuds peuvent être libérés (`queue_free`) entre deux frames.

```gdscript
# Interdit — accès direct sans vérification
func _on_timer_timeout() -> void:
    _target_node.take_damage(10)

# Obligatoire — vérification avant accès
func _on_timer_timeout() -> void:
    if not is_instance_valid(_target_node):
        return
    _target_node.take_damage(10)
```

**Exception :** Les nœuds obtenus par `@onready` dans la même scène ne nécessitent pas de vérification — ils sont garantis valides tant que la scène est dans l'arbre.

### Chemins @onready — correspondance avec la scène

Chaque chemin utilisé dans un `@onready` doit correspondre exactement à la hiérarchie de la scène `.tscn` associée. Vérifier le chemin complet depuis la racine de la scène jusqu'au nœud cible, en incluant tous les nœuds intermédiaires.

```gdscript
# Interdit — Label est enfant de Container, pas de Panel directement
@onready var label_score: Label = $Panel/Label

# Obligatoire — chemin complet reflétant la hiérarchie réelle
@onready var label_score: Label = $Panel/Container/Label
```

### Fonctions en doublon — une seule déclaration par nom

Chaque fonction ne peut être déclarée qu'une seule fois par classe. GDScript émet un Parser Error si deux fonctions portent le même nom. Lors de toute modification ou ajout de fonction (en particulier `_ready`, `_process`, `_input`), vérifier qu'aucune déclaration du même nom n'existe déjà dans le fichier avant d'écrire la nouvelle.

```gdscript
# Interdit — doublon de _ready, Parser Error garanti
func _ready() -> void:
    queue_redraw()

func _ready() -> void:
    _load_config()

# Obligatoire — une seule fonction _ready fusionnant tout le contenu
func _ready() -> void:
    _load_config()
    queue_redraw()
```

### Ordre d'instanciation — add_child avant setup

Appeler `add_child()` avant toute méthode sur l'instance instanciée. Ne jamais accéder au scene tree (chemins absolus `/root/...`, `get_node_or_null`) depuis `setup()` ou toute méthode appelée avant `add_child()` — le nœud n'est pas encore dans l'arbre et les chemins ne résolvent pas.

Placer systématiquement les accès au scene tree dans `_ready()`, qui est appelé par Godot après `add_child()`.

```gdscript
# Interdit — setup() avant add_child(), le scene tree est inaccessible
var entity: Node2D = _entity_scene.instantiate() as Node2D
entity.call("setup", data)
_parent_node.add_child(entity)

# Obligatoire — add_child() en premier
var entity: Node2D = _entity_scene.instantiate() as Node2D
_parent_node.add_child(entity)
entity.call("setup", data)
```

```gdscript
# Interdit — accès au scene tree dans setup()
func setup(data: Dictionary) -> void:
    var manager: Node = get_node_or_null("/root/Main/Manager")

# Obligatoire — accès au scene tree dans _ready() uniquement
func _ready() -> void:
    var manager: Node = get_node_or_null("/root/Main/Manager")

func setup(data: Dictionary) -> void:
    _data = data   # stockage uniquement, pas d'accès au scene tree
```

### Coordonnées UI vs coordonnées monde — espaces distincts

Un `CanvasLayer` (UI, HUD) a un espace de coordonnées indépendant du `World` (Node2D). Une position souris capturée lors d'un clic sur un bouton UI n'est pas utilisable comme coordonnée monde. Ne jamais initialiser un état monde depuis une position souris provenant d'un contexte UI.

La position souris est valide pour le monde uniquement quand elle provient d'un `InputEventMouseMotion` ou `InputEventMouseButton` reçu par un Node2D du monde via `_unhandled_input` — pas d'un handler de bouton UI.

```gdscript
# Interdit — le clic sur le bouton UI donne une position dans l'espace UI,
# pas dans l'espace monde
func _on_action_button_pressed() -> void:
    _cursor_cell = world_to_cell(get_viewport().get_mouse_position())

# Obligatoire — curseur monde initialisé à une valeur sentinelle neutre,
# mis à jour uniquement via _unhandled_input sur un événement monde
func activate_mode(mode_type: String) -> void:
    _mode_active = true
    _cursor_cell = Vector2i(-1, -1)   # sentinelle : pas encore de position monde valide
    _cursor_valid = false
```

### Curseur monde — valeur sentinelle et garde obligatoires

Toute variable représentant une position dans le monde (cellule, index, coordonnée) doit être initialisée à une valeur sentinelle neutre à l'activation d'un mode interactif. Le rendu et les actions déclenchées depuis cette variable doivent tester la sentinelle et s'interrompre si elle est active.

```gdscript
# Valeur sentinelle selon le type
var _cursor_cell: Vector2i = Vector2i(-1, -1)   # cellule : x < 0 = invalide
var _selected_index: int = -1                    # index : -1 = rien de sélectionné
var _target_node: Node2D = null                  # nœud : null = aucune cible

# Dans _draw() ou toute fonction de rendu
func _draw() -> void:
    if _cursor_cell.x < 0:
        return   # pas de position monde valide, ne rien dessiner

# Dans toute fonction d'action
func _try_action() -> void:
    if _cursor_cell.x < 0:
        return   # pas de position monde valide, bloquer l'action
```

### Nœuds Control UI — mouse_filter obligatoire sur les containers

Par défaut, tout `Control` (y compris `HBoxContainer`, `VBoxContainer`, `Panel`, etc.) a `mouse_filter = MOUSE_FILTER_STOP` (valeur 0). Cela signifie qu'il absorbe **tous** les événements souris sur sa surface, même si aucun bouton n'est sous le curseur. Le résultat : `_unhandled_input` dans les nœuds du monde ne reçoit jamais ces événements.

Règle : tout nœud `Control` qui n'a pas lui-même besoin de répondre aux clics (containers de mise en page, labels, overlays inactifs) doit avoir `mouse_filter = MOUSE_FILTER_IGNORE` (valeur 2) dans la scène `.tscn`. Seuls les nœuds interactifs (`Button`, `LineEdit`, etc.) gardent la valeur par défaut.

```
# Interdit — le HBoxContainer absorbe tous les clics, _unhandled_input ne les reçoit pas
[node name="BottomBar" type="HBoxContainer" parent="UI/HUD"]
layout_mode = 1

# Obligatoire — le container laisse passer les clics vers le monde
[node name="BottomBar" type="HBoxContainer" parent="UI/HUD"]
layout_mode = 1
mouse_filter = 2

# Les boutons gardent le comportement par défaut (STOP = 0) — ne pas ajouter mouse_filter
[node name="ActionButton" type="Button" parent="UI/HUD/BottomBar"]
layout_mode = 2
```

**Checklist des nœuds qui doivent avoir `mouse_filter = 2` :**
- Nœud `Control` racine du HUD
- Tous les `HBoxContainer`, `VBoxContainer`, `GridContainer` de mise en page
- Tous les `Label`, `RichTextLabel`
- Les `ColorRect` et `Panel` décoratifs inactifs

**Nœuds qui ne doivent PAS avoir `mouse_filter = 2` :**
- `Button`, `CheckBox`, `OptionButton` — interactifs par nature
- `LineEdit`, `TextEdit`, `SpinBox`
- Les overlays (Game Over, Win) — doivent bloquer les clics pendant leur affichage

### Boutons UI — toggle_mode réservé aux états binaires persistants

`toggle_mode = true` sur un Button fait émettre le signal `pressed` deux fois : une à l'enfoncement, une au relâchement. Ne jamais l'utiliser sur un bouton qui déclenche une action ponctuelle. Le réserver exclusivement aux boutons représentant un état persistant activé/désactivé (son, plein écran, option).

```
# Interdit — toute action ponctuelle avec toggle_mode
[node name="ActionButton" type="Button"]
toggle_mode = true

# Obligatoire — bouton d'action ponctuelle sans toggle_mode
[node name="ActionButton" type="Button"]
```

### Signaux de fin d'état — émission sur toutes les sorties

Un signal marquant la fin d'un état doit être émis sur **toutes** les sorties possibles de cet état : complétion réussie, annulation, timeout, erreur. Ne jamais l'émettre uniquement sur certains chemins de sortie — les abonnés (UI, managers) ne sauront pas que l'état a changé.

```gdscript
# Interdit — signal émis seulement sur un chemin de sortie
func cancel_mode() -> void:
    _mode_active = false
    mode_ended.emit()

func complete_mode() -> void:
    _mode_active = false
    # mode_ended jamais émis ici — les abonnés restent dans l'état "actif"

# Obligatoire — émis sur toutes les sorties
func cancel_mode() -> void:
    _mode_active = false
    mode_ended.emit()

func complete_mode() -> void:
    _mode_active = false
    mode_ended.emit()
```

### État initial garanti — jouabilité immédiate

Un prototype sans écran titre doit être jouable dès l'ouverture, sans aucune action préalable. Le `game_manager.gd` appelle la fonction d'initialisation du gameplay directement dans `_ready()`. Ne jamais laisser le jeu dans un état non jouable (ressources à zéro, boutons inactifs) si aucun écran titre n'est implémenté.

```gdscript
# Interdit — le jeu reste en état TITLE, aucune ressource, rien ne fonctionne
func _ready() -> void:
    _load_settings()
    _load_strings()

# Obligatoire — démarrage immédiat pour un prototype sans écran titre
func _ready() -> void:
    _load_settings()
    _load_strings()
    start_game()
```

### Ordre d'initialisation — synchronisation après connexion des signaux

Dans Godot, les `_ready()` s'exécutent dans l'ordre de l'arbre de scène, de haut en bas. Un nœud placé plus haut dans l'arbre (ex : `GameManager`) a déjà exécuté son `_ready()` — et donc émis ses signaux initiaux — quand les nœuds plus bas (ex : `Spawner`, `HUD`, tout système gameplay) connectent leurs récepteurs. Ces signaux initiaux sont définitivement perdus.

Cette règle s'applique à tout nœud abonné à un manager : scripts UI, systèmes gameplay, spawners, entités — sans exception.

Règle : tout script qui dépend de l'état initial d'un nœud plus haut dans l'arbre doit lire cet état directement après avoir connecté ses signaux. Ne jamais supposer que les émissions initiales ont été reçues.

```gdscript
# Interdit — le signal a pu partir avant que la connexion soit établie.
func _ready() -> void:
    _game_manager.game_state_changed.connect(_on_game_state_changed)
    # spawner ne démarre jamais si PLAYING a été émis avant cette ligne

# Obligatoire — lecture directe de l'état courant après connexion
func _ready() -> void:
    _game_manager.game_state_changed.connect(_on_game_state_changed)
    # Synchronisation explicite : lire l'état courant sans compter sur le signal initial
    _on_game_state_changed(_game_manager.current_state)
```

### Paramètres de fonction inutilisés — préfixe obligatoire

Tout paramètre de fonction qui n'est pas lu dans le corps de la fonction doit être préfixé par `_`. GDScript émet un warning pour chaque paramètre non préfixé jamais lu.

```gdscript
# Interdit — Godot émet un warning "parameter never used"
func on_enemy_died(kill_position: Vector2, enemy: Node2D) -> void:
    _enemies_alive -= 1

# Obligatoire — préfixe _ sur les paramètres intentionnellement ignorés
func on_enemy_died(_kill_position: Vector2, _enemy: Node2D) -> void:
    _enemies_alive -= 1
```

### Décomposition des fonctions longues

Toute fonction dépassant 30 lignes doit être découpée en sous-fonctions nommées explicitement.
Chaque sous-fonction exprime une responsabilité unique lisible dans son nom.

```gdscript
# Interdit — _ready() de 60 lignes faisant tout
func _ready() -> void:
    # 60 lignes mélangant init, connexions, UI, données...

# Obligatoire — _ready() délègue à des sous-fonctions nommées
func _ready() -> void:
    _load_settings()
    _connect_signals()
    _init_ui()
    start_game()
```

### add_child interdit dans les callbacks physiques — call_deferred obligatoire

Godot interdit de modifier l'arbre de scène (ajouter ou supprimer des nœuds) pendant le flush des requêtes physiques. Tout code appelé depuis `area_entered`, `body_entered`, `area_exited` ou tout autre signal physique de `Area2D` / `RigidBody2D` est exécuté pendant ce flush.

Appeler `add_child()` directement depuis un tel callback produit l'erreur runtime :
`Can't change this state while flushing queries. Use call_deferred() or set_deferred() to change monitoring state instead.`

```gdscript
# Interdit — add_child() dans la chaîne d'appel d'un signal physique
func _on_area_entered(area: Area2D) -> void:
    var fx: Node2D = _effect_scene.instantiate() as Node2D
    add_child(fx)   # erreur runtime garantie

# Obligatoire — différer l'ajout hors du flush physique
func _on_area_entered(area: Area2D) -> void:
    var fx: Node2D = _effect_scene.instantiate() as Node2D
    call_deferred("add_child", fx)
```

### Signaux de collision — correspondance obligatoire signal / type de nœud

Les signaux de détection de collision ne sont **pas interchangeables entre les types de nœuds physiques**. Utiliser un signal sur un nœud qui ne le déclare pas produit une `Parse Error` au chargement du script, avant même que le jeu ne tourne.

| Signal | Nœud qui le déclare | Nœuds qui ne le déclarent PAS |
|---|---|---|
| `body_entered(body)` | `Area2D` | `CharacterBody2D`, `RigidBody2D`, `StaticBody2D` |
| `area_entered(area)` | `Area2D` | tous les `Body2D` |
| `body_exited(body)` | `Area2D` | tous les `Body2D` |
| `area_exited(area)` | `Area2D` | tous les `Body2D` |

**`CharacterBody2D`, `RigidBody2D` et `StaticBody2D` n'ont aucun signal de collision.**
Pour détecter les contacts d'un `CharacterBody2D`, deux approches valides :

```gdscript
# Approche 1 — Nœud Area2D enfant avec son propre signal (préférée pour les entités joueur/ennemi)
# Dans la scène .tscn : CharacterBody2D > Area2D (Hitbox) > CollisionShape2D
# Dans le script du CharacterBody2D :
@onready var _hitbox: Area2D = $Hitbox

func _ready() -> void:
    _hitbox.body_entered.connect(_on_hitbox_body_entered)

func _on_hitbox_body_entered(body: Node2D) -> void:
    if body.is_in_group("enemies"):
        _take_damage()

# Approche 2 — Lecture des collisions après move_and_slide() (préférée pour la physique directe)
func _physics_process(_delta: float) -> void:
    move_and_slide()
    for i in get_slide_collision_count():
        var collision: KinematicCollision2D = get_slide_collision(i)
        var collider: Object = collision.get_collider()
        if collider is Node2D and (collider as Node2D).is_in_group("enemies"):
            _take_damage()
```

**Règle :** Avant de connecter un signal de collision, vérifier dans la documentation Godot 4 que ce signal appartient effectivement à la classe du nœud cible. Ne jamais supposer qu'un signal de collision est universel.

---

### Constructeurs de types Packed — syntaxe obligatoire

Les types `PackedVector2Array`, `PackedFloat32Array`, `PackedInt32Array`, etc. ne s'initialisent pas avec des arguments positionnels. Le constructeur n'accepte qu'un `Array` comme argument ou aucun argument.

```gdscript
# Interdit — Parse Error garanti
var points: PackedVector2Array = PackedVector2Array(Vector2(0.0, 0.0), Vector2(10.0, 5.0))

# Obligatoire — tableau Array passé en argument
var points: PackedVector2Array = PackedVector2Array([Vector2(0.0, 0.0), Vector2(10.0, 5.0)])

# Obligatoire — initialisé vide puis alimenté
var points: PackedVector2Array = PackedVector2Array()
points.append(Vector2(0.0, 0.0))
points.append(Vector2(10.0, 5.0))
```

Cette règle s'applique identiquement à :
- `PackedVector3Array([Vector3(...), ...])`
- `PackedFloat32Array([0.0, 1.0, ...])`
- `PackedInt32Array([0, 1, 2, ...])`
- `PackedColorArray([Color(...), ...])`
- `PackedStringArray(["a", "b"])`

**Règle :** Toute initialisation inline d'un type `Packed*Array` avec des valeurs utilise obligatoirement la syntaxe `PackedXxxArray([...])` — jamais `PackedXxxArray(val1, val2, ...)`.

---

### Hiérarchie de scène construite par code — règle fondamentale

Les fichiers `.tscn` produits manuellement (sans l'éditeur Godot) sont une source d'erreurs **non détectables avant l'ouverture dans Godot** : UIDs invalides, dépendances manquantes, erreurs de parsing silencieuses. La seule approche fiable est de **réduire les `.tscn` à leur strict minimum et de construire toute la hiérarchie par code**.

**Règle absolue :**

> `main.tscn` contient **uniquement** le nœud racine `Node2D` avec `game_manager.gd` attaché. C'est le seul fichier `.tscn` que l'IA produit. Toute la hiérarchie (World, Player, UI, HUD, Transitions…) est construite dans `game_manager._build_scene()`.

**`main.tscn` — format obligatoire, immuable :**

```
[gd_scene format=3]

[ext_resource type="Script" path="res://scripts/core/game_manager.gd" id="1"]

[node name="Main" type="Node2D"]
script = ExtResource("1")
```

Ce fichier ne doit jamais contenir autre chose. Pas de `load_steps`, pas de `uid=`, pas de `sub_resource`, pas de nœuds enfants, pas d'`instance=ExtResource`.

**`game_manager.gd` — responsabilité étendue :**

En plus de gérer les états, `game_manager.gd` (qui étend `Node2D`) contient une fonction `_build_scene()` appelée dans `_ready()`. Cette fonction construit l'intégralité de l'arbre de nœuds par code :

```gdscript
extends Node2D

func _ready() -> void:
    _load_strings()
    _build_scene()      # construit World, Player, UI, HUD, Transitions
    _connect_signals()
    _set_state(GameState.TITLE)

func _build_scene() -> void:
    _build_world()      # crée World, Spawner, Bullets, Player
    _build_ui()         # crée CanvasLayer > HUD > labels, barres
    _build_transitions() # crée TitleScreen, GameOverScreen

func _build_player() -> CharacterBody2D:
    var player: CharacterBody2D = CharacterBody2D.new()
    player.name = "Player"
    # Ajouter tous les enfants AVANT de set_script
    # → quand player entre dans l'arbre, @onready de player.gd résout correctement
    var body: Polygon2D = Polygon2D.new()
    body.name = "Body"
    player.add_child(body)
    # ... autres enfants ...
    player.set_script(load("res://scripts/entities/player.gd"))
    return player
```

**Ordre obligatoire dans `_build_*` :**

```gdscript
# 1. Créer le nœud parent
var node: SomeType = SomeType.new()
node.name = "NodeName"

# 2. Créer et ajouter TOUS les enfants
var child: ChildType = ChildType.new()
node.add_child(child)

# 3. Attacher le script EN DERNIER (après les enfants)
node.set_script(load("res://scripts/..."))

# 4. Ajouter dans l'arbre (déclenche _ready() bottom-up)
parent.add_child(node)
```

Quand `parent.add_child(node)` est appelé et `parent` est dans l'arbre, Godot appelle `_ready()` de bas en haut : enfants d'abord, puis `node`. Les `@onready` du script de `node` résolvent donc correctement, car tous les enfants existent déjà.

**Scènes d'entités dynamiques (bullets, ennemis) :**

Les fichiers `.tscn` d'entités spawnable sont chargés par `load()` dans les scripts — jamais référencés depuis un autre `.tscn`.

```gdscript
# Dans spawner.gd — chargement par code
var _enemy_scene: PackedScene = null

func _ready() -> void:
    _enemy_scene = load("res://scenes/entities/enemy_straight.tscn") as PackedScene

func _spawn_enemy() -> void:
    var enemy: Node2D = _enemy_scene.instantiate() as Node2D
    get_parent().add_child(enemy)
```

Ces `.tscn` d'entités peuvent contenir des `sub_resource` (shapes, etc.) mais **jamais** de `instance=ExtResource(...)` ni de `uid=` dans l'en-tête.

---




| Script | Responsabilité unique |
|---|---|
| `game_manager.gd` | États du jeu, score, progression |
| `hud.gd` | Affichage UI, mise à jour depuis signaux |
| `[systeme].gd` | Mécanique propre au genre ou au twist |

**Règle stricte : un script = une responsabilité.**

### Pas de logique dans les fichiers de données

Les fichiers `settings.json` et `strings_*.json` contiennent exclusivement des valeurs statiques.
Aucune expression GDScript, aucune référence de nœud, aucune logique conditionnelle n'est acceptée dans ces fichiers.

---

## Signaux — convention de nommage

```
[emetteur]_[evenement]
```

| Exemple | Signification |
|---|---|
| `game_state_changed(state: int)` | Changement d'état global |
| `[entite]_[evenement]` | Événement propre à une entité du genre |
| `twist_activated` | La mécanique du twist s'est déclenchée |

Le signal `twist_activated` est **obligatoire** dans tout prototype — il marque le moment central du twist.
Tous les autres signaux sont définis par le prompt selon le genre.

**Documentation des signaux dans le README :**
Le README doit inclure une section "Signaux et flux de données" listant chaque signal avec : son émetteur, ses paramètres, et les abonnés qui le reçoivent.

```
# Format attendu dans le README
| Signal | Émetteur | Paramètres | Abonnés |
|---|---|---|---|
| game_state_changed | game_manager | state: int | hud |
| twist_activated | [systeme] | — | game_manager, hud |
```

---

## États de jeu — valeurs autorisées

Le `game_manager.gd` gère un état global dont les valeurs sont :

```gdscript
enum GameState {
    TITLE,
    PLAYING,
    PAUSED,
    GAME_OVER,
    WIN
}
```

**États étendus pour certains genres :**
Certains genres nécessitent des phases intermédiaires (ex : `DRAFT` pour un deckbuilder, `BUILD` pour un tower defense, `LEVELUP` pour un roguelike). Ces états supplémentaires sont autorisés à condition d'être justifiés dans le README sous la section "États de jeu étendus", avec leur rôle et leurs transitions entrantes/sortantes.

```gdscript
# Exemple pour un roguelike
enum GameState {
    TITLE,
    PLAYING,
    LEVELUP,    # Extension — sélection d'amélioration entre deux salles
    PAUSED,
    GAME_OVER,
    WIN
}
# → Justification dans README : "LEVELUP : état bloquant déclenché à chaque
#   montée de niveau. Transitions : PLAYING → LEVELUP → PLAYING."
```

---

## Structure de `settings.json`

Toutes les clés sont obligatoires. Valeurs par défaut neutres si inapplicables au genre.
**La clé `meta.convention_version` doit correspondre à la version de ce fichier CONVENTION.md.**

```json
{
  "meta": {
    "genre": "",
    "version": "0.1.0",
    "convention_version": "2.0.0",
    "language": "fr"
  },
  "display": {
    "base_width": 1280,
    "base_height": 720,
    "fullscreen": false
  },
  "gameplay": {
    "difficulty": 1.0
  },
  "audio": {
    "master_volume": 1.0,
    "sfx_volume": 1.0,
    "bgm_volume": 0.8
  },
  "debug": {
    "show_hitboxes": false,
    "god_mode": false,
    "verbose_logs": false
  }
}
```

**Règles d'usage dans le code :**
- Toujours lire via `settings.get("cle", valeur_neutre)`
- Ne jamais écrire de valeur numérique de gameplay en dur dans un script si elle est dans `settings.json`
- Toutes les clés spécifiques au genre s'ajoutent sous `"gameplay"` uniquement — jamais de nouvelle section racine
- Les clés spécifiques sont définies par le `GAME_PROMPT.md` sous la section `SETTINGS_GAMEPLAY`

---

## Structure des fichiers de traduction

```json
{
  "ui": {
    "start":     "Démarrer",
    "quit":      "Quitter",
    "pause":     "Pause",
    "resume":    "Reprendre",
    "game_over": "Game Over"
  },
  "gameplay": {},
  "feedback":  {}
}
```

**Règles d'usage :**
- Aucun texte affiché à l'écran ne doit être écrit en dur dans un script ou une scène
- Clé absente → afficher la clé elle-même entre crochets : `[cle_manquante]`
- Les clés `"gameplay"` et `"feedback"` sont définies par le `GAME_PROMPT.md` — elles ne doivent pas rester vides dans le prototype livré
- Aucune clé ne doit être ajoutée à `"ui"` sauf si elle est universelle à tout jeu

---

## Structure des scènes

### `main.tscn` — scène racine obligatoire
```
Main (Node2D)
├── GameManager (Node)          # script: game_manager.gd
├── World (Node2D)              # contenu gameplay
├── UI (CanvasLayer)            # script: hud.gd
│   └── HUD (Control)
└── Transitions (CanvasLayer)   # overlays, fades
```

### Hiérarchie des scripts

| Script | Responsabilité unique |
|---|---|
| `game_manager.gd` | États du jeu, score, progression |
| `hud.gd` | Affichage UI, mise à jour depuis signaux |
| `[systeme].gd` | Mécanique propre au genre ou au twist |

---

## README.md — structure obligatoire

```markdown
# [Nom du genre] — Prototype Godot

## Twist
[Énoncé en une phrase]
[Moment aha : situation précise où le joueur le comprend]

## Genre & systèmes clés
[Description du genre et de ses systèmes clés attendus dans ce genre]

## Systèmes implémentés
[Explication pédagogique par système : ce que fait le système, pourquoi il existe,
comment il est structuré dans le code]

## Architecture
[Schéma texte scènes + hiérarchie]

## Signaux et flux de données
[Tableau : Signal | Émetteur | Paramètres | Abonnés]
[Description du flux principal : quel signal déclenche quoi, dans quel ordre]

## Comment tester le twist
1. [Scénario 1]
2. [Scénario 2]
3. [Scénario 3]

## Paramètres configurables
[Tableau : clé settings.json | effet | valeur par défaut]

## États de jeu étendus *(si applicable)*
[Tableau : État | Rôle | Transitions entrantes | Transitions sortantes]
```

---

## Checklist de conformité

> **Note de synchronisation :** Cette checklist est la source de vérité. La section 4.0 de `SYSTEM_PROMPT.md`
> doit rester identique à cette liste. Toute modification ici doit être reportée dans `SYSTEM_PROMPT.md`.

Avant de livrer un prototype, vérifie chaque point :

- [ ] Nom du dossier racine en `snake_case`
- [ ] Arborescence vérifiée avec `find . -type d | sort` — aucun nom de dossier ne contient `{`, `}`, `,` ou espace
- [ ] `CONVENTION.md` copié à la racine du projet — version identique à la convention utilisée
- [ ] `meta.convention_version` dans `settings.json` correspond à la version de ce fichier
- [ ] `datas/settings.json` contient toutes les clés obligatoires, y compris les clés `gameplay` définies par le GAME_PROMPT
- [ ] `datas/strings_fr.json` et `strings_en.json` présents — sections `gameplay` et `feedback` remplies (non vides)
- [ ] Aucun texte affiché en dur dans les scripts ou scènes
- [ ] Aucune valeur numérique de gameplay en dur dans les scripts
- [ ] `main.tscn` respecte la hiérarchie définie
- [ ] Signal `twist_activated` émis au bon moment — syntaxe `twist_activated.emit()`
- [ ] Enum `GameState` utilisé pour tous les états (extensions justifiées dans README)
- [ ] `README.md` suit la structure complète, y compris la section "Signaux et flux de données"
- [ ] Résolution adaptative : ancres, viewports et CanvasLayer configurés pour toutes les résolutions cibles
- [ ] Toutes les fonctions déclarent leur type de retour (`-> Type` ou `-> void`)
- [ ] Aucun `:=` sur un accès indexé `Array`/`Dictionary` ou une fonction à retour `Variant`
- [ ] Tout accès indexé sur `Array`/`Dictionary` non typé est casté (`as Type`)
- [ ] `Array[Type]` utilisé en priorité sur `Array` + cast quand le type est homogène et connu
- [ ] Tous les paramètres de fonction sont typés
- [ ] Toutes les variables `@export` sont typées explicitement
- [ ] Aucune continuation de ligne par `\` — toutes les expressions multi-lignes entre parenthèses
- [ ] Aucune fonction déclarée en doublon — une seule déclaration par nom par classe
- [ ] Tout signal déclaré est émis dans la même classe — aucun signal mort
- [ ] Tous les signaux utilisent la syntaxe Godot 4 : `signal_name.emit(args)` — aucun `emit_signal()`
- [ ] Toutes les connexions de signaux utilisent la syntaxe Godot 4 : `signal.connect(callable)`
- [ ] `is_instance_valid()` vérifié avant tout accès à un nœud stocké en variable de classe
- [ ] Chaque chemin `@onready` vérifié contre la hiérarchie de la `.tscn` associée
- [ ] `add_child()` toujours appelé avant `setup()` ou toute méthode sur l'instance
- [ ] Aucun accès au scene tree dans `setup()` — uniquement dans `_ready()`
- [ ] Aucune position souris d'un contexte UI utilisée comme coordonnée monde
- [ ] Curseur monde initialisé à une valeur sentinelle neutre à l'activation du mode
- [ ] Rendu et actions bloqués tant que la sentinelle est active
- [ ] Tous les containers UI (`HBoxContainer`, `VBoxContainer`, etc.) ont `mouse_filter = 2` dans la `.tscn`
- [ ] Tous les `Label` et nœuds décoratifs ont `mouse_filter = 2`
- [ ] Seuls les boutons interactifs gardent `mouse_filter` par défaut (STOP)
- [ ] Aucun bouton d'action ponctuelle avec `toggle_mode = true`
- [ ] Signaux de fin d'état émis sur toutes les sorties, pas seulement l'annulation
- [ ] Prototype jouable immédiatement à l'ouverture — `start_game()` dans `_ready()` si aucun écran titre
- [ ] Tout nœud abonné à un manager synchronise son état initial par lecture directe après connexion des signaux
- [ ] Aucune variable ou fonction abrégée ou ambiguë (`spd`, `tmp`, `obj`, `upd`) — noms explicites obligatoires
- [ ] Toute fonction > 30 lignes découpée en sous-fonctions nommées explicitement
- [ ] Aucune logique ou expression dans les fichiers JSON (`settings.json`, `strings_*.json`)
- [ ] Tout paramètre de fonction jamais lu dans son corps est préfixé `_` — aucun warning "parameter never used"
- [ ] Aucun `add_child()` appelé directement depuis un signal physique ou sa chaîne d'appel — `call_deferred("add_child", node)` à la place
- [ ] Commentaires dans les scripts en anglais uniquement
- [ ] Chaque signal de collision (`body_entered`, `area_entered`, etc.) connecté uniquement sur un nœud `Area2D` — jamais sur un `CharacterBody2D`, `RigidBody2D` ou `StaticBody2D`
- [ ] Toute initialisation inline d'un `PackedVector2Array` (ou autre `Packed*Array`) utilise la syntaxe `PackedXxxArray([...])` — jamais `PackedXxxArray(val1, val2, ...)`
- [ ] `main.tscn` contient exactement 6 lignes : `[gd_scene format=3]`, ext_resource vers `game_manager.gd`, nœud racine `Main` avec script — rien d'autre
- [ ] Toute la hiérarchie de scène est construite par code dans `game_manager._build_scene()` — aucun autre `.tscn` ne contient de nœuds, scripts ou ressources
- [ ] `test_functional.py` exécuté et retourne `ALL TESTS PASSED` — aucun FAIL présent
- [ ] Archive `.zip` produite avec : `zip -r [nom_du_genre].zip [nom_du_genre]/ --exclude "*/.godot/*" --exclude "*/.DS_Store"` — `project.godot` bien présent dans l'archive

---

## Tests fonctionnels pré-livraison

Chaque prototype doit inclure un fichier `test_functional.py` à sa racine.
Ce script est exécuté **obligatoirement** après la Phase 1 (Étape 3) et avant la production du `.zip`.
Si le script retourne un exit code non nul (au moins un FAIL), le zip ne doit pas être produit.

**Commande d'exécution** (depuis le dossier racine du projet) :

```bash
python3 test_functional.py
```

Le test doit afficher `ALL TESTS PASSED` avant de poursuivre vers l'Étape 4.
Les WARNINGS sont informatifs — ils ne bloquent pas la livraison mais doivent être examinés.

### Template test_functional.py

Copier et adapter ce template pour chaque prototype. Remplacer `GENRE` par le nom du dossier racine.

```python
#!/usr/bin/env python3
"""Functional tests - run from the project root directory."""

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

# ── helpers ──────────────────────────────────────────────────────────────────

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
    ]
    for path in required:
        if not os.path.exists(path):
            fail(f"T01 missing file: {path}")

# ── T02 — settings.json structure ────────────────────────────────────────────

def test_settings_json():
    path = os.path.join(DATAS_DIR, "settings.json")
    if not os.path.exists(path):
        return
    with open(path, encoding="utf-8") as fh:
        try:
            data = json.load(fh)
        except json.JSONDecodeError as exc:
            fail(f"T02 settings.json invalid JSON: {exc}")
            return
    for section in ("meta", "display", "gameplay", "audio", "debug"):
        if section not in data:
            fail(f"T02 settings.json missing section: {section}")
    meta = data.get("meta", {})
    for key in ("genre", "version", "convention_version", "language"):
        if key not in meta:
            fail(f"T02 settings.json missing meta.{key}")

# ── T03 — strings_*.json structure ───────────────────────────────────────────

def test_strings_json():
    for lang in ("fr", "en"):
        path = os.path.join(DATAS_DIR, f"strings_{lang}.json")
        if not os.path.exists(path):
            fail(f"T03 missing strings_{lang}.json")
            continue
        with open(path, encoding="utf-8") as fh:
            try:
                data = json.load(fh)
            except json.JSONDecodeError as exc:
                fail(f"T03 strings_{lang}.json invalid JSON: {exc}")
                continue
        for section in ("ui", "gameplay", "feedback"):
            if section not in data:
                fail(f"T03 strings_{lang}.json missing section: {section}")
        if not data.get("gameplay"):
            fail(f"T03 strings_{lang}.json gameplay section is empty")
        if not data.get("feedback"):
            fail(f"T03 strings_{lang}.json feedback section is empty")

# ── T04 — duplicate functions ────────────────────────────────────────────────

def test_duplicate_functions():
    for path, lines in gd_files():
        names = [
            re.match(r"^func (\w+)\(", l.strip()).group(1)
            for l in lines if re.match(r"^func (\w+)\(", l.strip())
        ]
        for name, count in Counter(names).items():
            if count > 1:
                fail(f"T04 duplicate func '{name}' in {path}")

# ── T05 — missing return types ────────────────────────────────────────────────

def test_return_types():
    pattern = re.compile(r"^func \w+\([^)]*\)\s*(?!->):")
    for path, lines in gd_files():
        for i, line in enumerate(lines, 1):
            if pattern.match(line.strip()):
                fail(f"T05 missing return type at {path}:{i}: {line.strip()}")

# ── T06 — dead signals (declared but never emitted) ──────────────────────────

def test_dead_signals():
    for path, lines in gd_files():
        content = "".join(lines)
        for line in lines:
            m = re.match(r"^signal (\w+)", line.strip())
            if m:
                sig = m.group(1)
                if f"{sig}.emit(" not in content:
                    fail(f"T06 dead signal '{sig}' in {path} (declared, never emitted)")

# ── T07 — deprecated Godot 3 signal syntax ───────────────────────────────────

def test_godot3_syntax():
    for path, lines in gd_files():
        for i, line in enumerate(lines, 1):
            if "emit_signal(" in line:
                fail(f"T07 deprecated emit_signal() at {path}:{i}")
            if re.search(r'\.connect\s*\(\s*"', line):
                fail(f"T07 deprecated string connect() at {path}:{i}")

# ── T08 — unused parameters without _ prefix ─────────────────────────────────

def test_unused_params():
    func_pattern   = re.compile(r"^func (\w+)\(([^)]*)\)\s*(->.*)?:")
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
                # 1 occurrence = declaration only
                if uses <= 1:
                    warn(f"T08 param '{param}' possibly unused in {path} — prefix with _ if intentional")

# ── T09 — add_child in physics callbacks ─────────────────────────────────────

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
    path = os.path.join(SCENES_DIR, "core", "main.tscn")
    if not os.path.exists(path):
        fail("T11 missing scenes/core/main.tscn")
        return
    with open(path, encoding="utf-8") as fh:
        content = fh.read()
    for required in ("GameManager", "World", "UI", "HUD", "Transitions"):
        if required not in content:
            fail(f"T11 main.tscn missing node: {required}")

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
```

---

## Règles de livraison

Le prototype est livré sous forme d'une archive `.zip` unique, produite après la validation complète de la checklist ci-dessus.

**Commande obligatoire** (exécutée depuis le dossier parent du projet) :

```bash
zip -r [nom_du_genre].zip [nom_du_genre]/ --exclude "*/.godot/*" --exclude "*/.DS_Store"
```

**Règles :**
- Le nom du `.zip` correspond exactement au nom du dossier racine (`snake_case`)
- L'archive contient le dossier racine du projet à sa racine — pas les fichiers à plat
- La commande `zip` est exécutée après la Phase 2 complète — jamais avant
- Ne jamais utiliser `--exclude "*.godot*"` — ce pattern exclut aussi `project.godot`

---

## Règles de création de l'arborescence

Créer chaque dossier avec une commande `mkdir -p` distincte, **un dossier par ligne** :

```bash
mkdir -p [nom_du_genre]
mkdir -p [nom_du_genre]/datas
mkdir -p [nom_du_genre]/scenes/core
mkdir -p [nom_du_genre]/scenes/ui
mkdir -p [nom_du_genre]/scenes/entities
mkdir -p [nom_du_genre]/scripts/core
mkdir -p [nom_du_genre]/scripts/ui
mkdir -p [nom_du_genre]/scripts/entities
mkdir -p [nom_du_genre]/assets/fonts
mkdir -p [nom_du_genre]/assets/sounds
mkdir -p [nom_du_genre]/assets/textures
mkdir -p [nom_du_genre]/addons
```

**Ne jamais utiliser l'expansion d'accolades bash** (`{a,b,c}`) en une seule commande.

```bash
# Interdit
mkdir -p [nom_du_genre]/{datas,scenes/{core,ui},scripts}
```

---

## Changelog

| Version | Modifications |
|---|---|
| 2.3.0 | Règle définitive "Hiérarchie construite par code" — `main.tscn` réduit à 6 lignes, tout construit dans `game_manager._build_scene()`. Remplacement des stratégies A/B par la règle absolue. |
| 2.2.0 | Règle "Interdiction de `instance=ExtResource`" (PATTERN 25) — remplacée par 2.3.0. |
| 2.1.0 | Règle "Signaux de collision — correspondance signal/type de nœud" (PATTERN 23). Règle "Constructeurs Packed*Array — syntaxe obligatoire" (PATTERN 24). Deux entrées ajoutées dans la checklist de conformité. |
| 2.0.0 | Ajout du template complet `test_functional.py` (14 tests, T01–T14). Ajout règle "résolution adaptative" dans checklist. Ajout règle "commentaires en anglais". Nettoyage des sections dupliquées. |
| 1.7.0 | Ajout section "Tests fonctionnels pré-livraison" (script référencé mais non fourni). |
| 1.6.0 | Règle "Paramètres de fonction inutilisés". Règle "add_child dans callbacks physiques". |
| 1.5.0 | Généralisation règle "Ordre d'initialisation". Précision commande zip. |
| 1.4.0 | Règle "Pas de logique dans les fichiers de données". |
| 1.3.0 | Règle nommage variables/fonctions. Règle décomposition fonctions > 30 lignes. |
| 1.2.0 | Syntaxe signaux Godot 4. Array[Type]. @export typé. is_instance_valid(). |
| 1.1.0 | Règles mouse_filter, sentinelle curseur, toggle_mode, synchronisation UI. |
| 1.0.0 | Version initiale. |
