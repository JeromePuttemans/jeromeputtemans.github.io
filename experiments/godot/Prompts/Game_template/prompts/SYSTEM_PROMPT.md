# SYSTEM_PROMPT.md
SYSTEM_PROMPT.md — Le contrat de processus
Ce fichier décrit comment l'IA doit travailler : les 3 étapes obligatoires (plan d'architecture → implémentation → revue senior), l'ordre d'implémentation, les contraintes techniques transversales (Godot 4, résolution adaptative, commentaires en anglais), et les 8 axes de la revue de code avec leurs critères détaillés. Il ne décrit pas quoi faire dans un jeu en particulier, mais comment le construire rigoureusement.

## Contrat permanent Godot Prototype

> Ces instructions s'appliquent à **tous** les prototypes générés, sans exception.
> Elles sont complétées à chaque projet par un `GAME_PROMPT.md` qui fournit les paramètres spécifiques.
> **Hiérarchie de priorité en cas de conflit :**
> `CONVENTION.md` > `SYSTEM_PROMPT.md` > `GAME_PROMPT.md`
> En cas de conflit avec `CONVENTION.md` sur la structure des fichiers ou les règles GDScript, `CONVENTION.md` prime.
> En cas de conflit entre ce fichier et `GAME_PROMPT.md`, ce fichier prime.

---

## Ordre d'exécution obligatoire

```
ETAPE 1 → Plan d'architecture

ETAPE 2 → Implémentation   ← PHASE 1  [tests fonctionnels intégrés]
ETAPE 3 → Revue senior     ← PHASE 2  [8 axes, correctifs, .zip]
```

---

## ETAPE 1 — PLAN D'ARCHITECTURE

Avant d'écrire la moindre ligne de code, produis un plan d'architecture complet. Ce plan est le contrat qui gouverne toute l'implémentation — toute divergence à l'Étape 2 doit être justifiée.

### 1.1 — Scènes et scripts

Liste exhaustive des fichiers à créer, avec leur responsabilité unique :

```
SCENES
  scenes/core/main.tscn          — [responsabilité]
  scenes/core/[systeme].tscn     — [responsabilité]
  scenes/ui/hud.tscn             — [responsabilité]
  scenes/entities/[entite].tscn  — [responsabilité]
  …

SCRIPTS
  scripts/core/game_manager.gd   — [responsabilité unique]
  scripts/core/[systeme].gd      — [responsabilité unique]
  scripts/ui/hud.gd              — [responsabilité unique]
  scripts/entities/[entite].gd   — [responsabilité unique]
  …
```

**Règle :** Si deux scripts partagent une responsabilité décrite de manière identique, ils doivent être fusionnés ou l'un doit être supprimé. Un script sans responsabilité unique claire ne doit pas être créé.

### 1.2 — Hiérarchie de main.tscn

Schéma texte complet de la hiérarchie de nœuds, conforme à `CONVENTION.md` :

```
Main (Node2D)
├── GameManager (Node)
├── World (Node2D)
│   └── …
├── UI (CanvasLayer)
│   └── HUD (Control)
│       └── …
└── Transitions (CanvasLayer)
```

### 1.3 — Signaux et flux de données

Tableau complet des signaux avant implémentation :

| Signal | Émetteur | Paramètres | Abonnés | Rôle dans le twist |
|---|---|---|---|---|
| `game_state_changed` | `game_manager` | `state: int` | `hud` | — |
| `twist_activated` | `[systeme]` | — | `game_manager`, `hud` | **Obligatoire** |
| … | … | … | … | … |

**Règle :** Tout signal listé ici doit être émis ET connecté dans l'implémentation. Aucun signal fantôme.

### 1.4 — Clés de données

Liste des clés à ajouter dans `settings.json` et les fichiers de traduction. Intégrer **toutes** les valeurs définies dans `SETTINGS_GAMEPLAY`, `STRINGS_GAMEPLAY` et `STRINGS_FEEDBACK` du `GAME_PROMPT.md` — aucune omission.

```
SETTINGS gameplay
  [cle]  : [type] = [valeur par défaut]  — [effet]
  …

STRINGS gameplay
  [cle]  : [texte FR]  /  [texte EN]
  …

STRINGS feedback
  [cle]  : [texte FR]  /  [texte EN]
  …
```

### 1.5 — États de jeu

Enum `GameState` complet, avec justification des extensions si présentes :

```gdscript
enum GameState {
    TITLE,
    PLAYING,
    [EXTENSION_1],   # justification : …
    PAUSED,
    GAME_OVER,
    WIN
}
```

Diagramme de transitions (texte) :
```
TITLE → PLAYING → GAME_OVER → TITLE
PLAYING → PAUSED → PLAYING
PLAYING → WIN → TITLE
[EXTENSION_1] → PLAYING  (si applicable)
```

### 1.6 — Risques et décisions d'architecture

```
RISQUES
  [Aspect technique potentiellement difficile] → [Approche retenue et pourquoi]
  …

DECISIONS
  [Choix d'architecture non évident] → [Justification]
  …
```

> Valide que le plan est cohérent avec le GATE JOUABLE défini dans le bloc `TWIST RETENU` du `GAME_PROMPT.md`.

---

## ETAPE 2 — IMPLÉMENTATION  *(Phase 1)*

Le prototype a un seul objectif : **faire ressentir le twist retenu le plus directement possible.**
Supprime toute fonctionnalité qui ne sert pas cet objectif.
Le périmètre d'implémentation est borné par le `PERIMETRE_MINIMAL` du `GAME_PROMPT.md` — ne pas le dépasser sans raison explicite liée au twist.

### Ordre d'implémentation obligatoire

1. Arborescence (un `mkdir -p` par dossier, un dossier par ligne — pas d'expansion d'accolades bash)
2. Fichiers de données : `datas/settings.json`, `datas/strings_fr.json`, `datas/strings_en.json`
3. `main.tscn` — structure de scène conforme au plan d'architecture
4. `game_manager.gd` — machine à états, signaux, initialisation
5. Système central du twist (`[systeme].gd` + `.tscn`)
6. Entités (`[entite].gd` + `.tscn`)
7. HUD (`hud.gd` + `hud.tscn`)
8. `README.md`
9. `test_functional.py` (template fourni dans `CONVENTION.md`, adapté au projet)
10. Copier `CONVENTION.md` à la racine du projet

### Contraintes techniques

- Godot 4.x — GDScript uniquement
- **Commentaires dans les scripts : anglais uniquement, sans exception**
- **Résolution adaptative obligatoire** : ancres, viewports et CanvasLayer configurés pour fonctionner à toutes les résolutions cibles (desktop 16:9, 16:10, 32:9 ultra-wide, 4:3)
- Structure de fichiers : respecter intégralement `CONVENTION.md`
- `datas/settings.json` : clés genre-spécifiques sous `"gameplay"` uniquement, fallback `settings.get("cle", valeur_neutre)` systématique
- `datas/strings_fr.json` + `strings_en.json` : clés `"gameplay"` et `"feedback"` remplies avec les valeurs du plan d'architecture — jamais vides
- **Respecter intégralement la section "Règles GDScript obligatoires" de `CONVENTION.md`** avant d'écrire la première ligne de code
- **Syntaxe signaux Godot 4 obligatoire :** `signal_name.emit(args)` et `signal.connect(callable)` — aucun `emit_signal()` ni `connect("name", ...)` dépréciés
- Toute divergence par rapport au plan d'architecture est signalée et justifiée en commentaire inline

### Livrables Phase 1

- Arborescence complète
- Tous les fichiers du projet (scripts, scènes, datas)
- `README.md` avec structure complète (voir `CONVENTION.md`)
- `test_functional.py` adapté au projet

---

## ETAPE 2.5 — TESTS FONCTIONNELS

Immédiatement après la Phase 1, exécuter `test_functional.py` depuis la racine du projet :

```bash
python3 test_functional.py
```

- Si des **FAIL** apparaissent : corriger chaque point, relancer jusqu'à `ALL TESTS PASSED`
- Les **WARNINGS** sont informatifs — les examiner mais ils ne bloquent pas
- **Ne jamais passer à l'Étape 3 avec des FAIL en cours**

Le script couvre automatiquement la majorité des patterns (T01–T14). L'Étape 3 complète les vérifications que le script ne peut pas automatiser (logique métier, jouabilité du twist, cas limites).

---

## ETAPE 3 — REVUE SENIOR  *(Phase 2)*

La Phase 2 est une revue de code systématique menée sur 8 axes, dans l'ordre ci-dessous. Chaque problème trouvé est **corrigé immédiatement** — ne pas lister les problèmes sans les résoudre.

**Ordre obligatoire des axes** (les corrections amont ne masquent pas les corrections aval) :
1. Doublons de fonctions → 2. Signaux morts → 3. Chemins @onready → 4. Ordre d'instanciation → 5. Synchronisation initiale → 6. Paramètres inutilisés → 7. add_child physique → 8. Tous les autres patterns

---

### 3.0 — Conformité CONVENTION.md

> Cette checklist est synchronisée avec la "Checklist de conformité" de `CONVENTION.md`.
> En cas de divergence entre les deux, la version de `CONVENTION.md` fait foi.

- [ ] `test_functional.py` retourne `ALL TESTS PASSED` avant tout autre audit
- [ ] Nom du dossier racine en `snake_case`
- [ ] Arborescence vérifiée — aucun nom de dossier/fichier avec `{`, `}`, `,`, espace
- [ ] `CONVENTION.md` copié à la racine — `meta.convention_version` dans `settings.json` correspond
- [ ] `datas/settings.json` — toutes les clés obligatoires + clés `gameplay` du plan d'architecture
- [ ] `datas/strings_fr.json` et `strings_en.json` — sections `gameplay` et `feedback` remplies
- [ ] Aucun texte affiché en dur dans les scripts ou scènes
- [ ] Aucune valeur numérique de gameplay en dur dans les scripts
- [ ] `main.tscn` respecte la hiérarchie définie dans `CONVENTION.md` et le plan d'architecture
- [ ] Signal `twist_activated` émis — syntaxe `twist_activated.emit()`
- [ ] Enum `GameState` utilisé pour tous les états — extensions justifiées dans README
- [ ] `README.md` suit la structure complète, y compris "Signaux et flux de données"
- [ ] Résolution adaptative : ancres et CanvasLayer fonctionnels sur toutes les résolutions cibles
- [ ] Toutes les fonctions déclarent leur type de retour (`-> Type` ou `-> void`)
- [ ] Aucun `:=` sur un accès indexé `Array`/`Dictionary` ou une fonction à retour `Variant`
- [ ] Tout accès indexé sur `Array`/`Dictionary` non typé est casté (`as Type`)
- [ ] `Array[Type]` utilisé en priorité sur `Array` + cast quand le type est homogène
- [ ] Tous les paramètres de fonction sont typés
- [ ] Toutes les variables `@export` sont typées explicitement
- [ ] Aucune continuation de ligne par `\` — expressions multi-lignes entre parenthèses
- [ ] Aucune fonction déclarée en doublon
- [ ] Tout signal déclaré est émis dans la même classe — aucun signal mort
- [ ] Syntaxe Godot 4 : `signal_name.emit(args)` — aucun `emit_signal()`
- [ ] Syntaxe Godot 4 : `signal.connect(callable)` — aucun `connect("name", ...)`
- [ ] `is_instance_valid()` vérifié avant tout accès à un nœud stocké en variable de classe
- [ ] Chaque chemin `@onready` vérifié contre la hiérarchie de la `.tscn` associée
- [ ] `add_child()` toujours appelé avant `setup()` ou toute méthode sur l'instance
- [ ] Aucun accès au scene tree dans `setup()` — uniquement dans `_ready()`
- [ ] Aucune position souris d'un contexte UI utilisée comme coordonnée monde
- [ ] Curseur monde initialisé à une valeur sentinelle neutre à l'activation du mode
- [ ] Rendu et actions bloqués tant que la sentinelle est active
- [ ] Tous les containers UI (`HBoxContainer`, `VBoxContainer`, etc.) ont `mouse_filter = 2`
- [ ] Tous les `Label` et nœuds décoratifs ont `mouse_filter = 2`
- [ ] Seuls les boutons interactifs gardent `mouse_filter` par défaut
- [ ] Aucun bouton d'action ponctuelle avec `toggle_mode = true`
- [ ] Signaux de fin d'état émis sur toutes les sorties
- [ ] Prototype jouable immédiatement à l'ouverture — `start_game()` dans `_ready()` si aucun écran titre
- [ ] Tout nœud abonné à un manager synchronise son état initial après connexion des signaux
- [ ] Tout paramètre jamais lu est préfixé `_`
- [ ] Aucun `add_child()` depuis un signal physique — `call_deferred("add_child", node)`
- [ ] Aucun signal de collision (`body_entered`, `area_entered`, etc.) connecté sur un `CharacterBody2D`, `RigidBody2D` ou `StaticBody2D` — ces signaux n'existent que sur `Area2D` (PATTERN 23)
- [ ] Aucun `PackedVector2Array(val1, val2, ...)` avec arguments positionnels — utiliser `PackedVector2Array([val1, val2, ...])` (PATTERN 24)
- [ ] `main.tscn` contient exactement 6 lignes — toute hiérarchie construite dans `game_manager._build_scene()` (PATTERN 25)
- [ ] Commentaires en anglais uniquement
- [ ] Aucune variable ou fonction abrégée (`spd`, `tmp`, `obj`, `upd`, `tgt`, `idx`)
- [ ] Toute fonction > 30 lignes découpée en sous-fonctions nommées explicitement
- [ ] Aucune logique dans les fichiers JSON

Corriger tout point non coché avant de poursuivre.

---

### AXE 1 — Logique métier

- La logique correspond-elle au twist retenu ? Les règles du jeu sont-elles correctement implémentées ?
- Le `GATE JOUABLE` défini dans le bloc `TWIST RETENU` du `GAME_PROMPT.md` est-il fonctionnel ?
- Le joueur ressent-il le twist dans les 30 premières secondes sans lire le README ?
- Erreurs d'unités, de priorités d'exécution, de conditions aux bornes ?
- Cas limites où l'algorithme produit un comportement absurde (spawn sur position invalide, division par zéro, états contradictoires) ?
- L'implémentation reste-t-elle dans le `PERIMETRE_MINIMAL` ? Toute fonctionnalité hors périmètre est retirée ou justifiée.

---

### AXE 2 — Robustesse

- Chaque accès à un nœud externe est précédé d'un `is_instance_valid()` ?
- Chaque lecture de `settings.json` utilise un fallback neutre via `.get("cle", valeur_neutre)` ?
- Comportement si `settings.json` est absent, vide ou malformé ?
- Les inputs joueur sont validés (spam, valeurs hors plage) ?
- Toute déconnexion de signal en cours de jeu (nœud libéré) est gérée proprement ?
- Les systèmes gameplay (spawner, IA, score) démarrent-ils bien au lancement — pas de système silencieux causé par un signal initial perdu (PATTERN 20) ?

---

### AXE 3 — Sécurité

- Parsing JSON avec validation du schéma avant usage ?
- Aucun chemin de fichier construit depuis une entrée joueur ?
- Aucune donnée sensible dans les logs de debug ?
- Aucun `eval()` ou équivalent ?

---

### AXE 4 — Performance

- Aucune allocation d'objet dans `_process` ou `_physics_process` ?
- Les opérations coûteuses sont faites hors frame (cache, précalcul) ?
- Signaler toute boucle en O(n²) ou pire sur des collections > 100 éléments
- Aucun nœud instancié/détruit dans une boucle chaude — utiliser un pool si nécessaire
- Aucun `find_child()` ou `get_node()` dynamique dans `_process`

---

### AXE 5 — Sur-ingénierie

> L'objectif est un prototype minimal. La complexité inutile est un défaut, pas une qualité.

- Y a-t-il des abstractions, classes, ou systèmes qui n'existent que pour anticiper des besoins futurs non définis dans le `PERIMETRE_MINIMAL` ? → Les supprimer.
- Y a-t-il des patterns de design (Observer, Strategy, Factory) appliqués là où une simple variable d'état suffirait ? → Les simplifier.
- Y a-t-il plus de scripts que nécessaire pour le périmètre défini ? → Fusionner.
- La règle est : **tout code qui ne sert pas le GATE JOUABLE est du code en trop**.

---

### AXE 6 — Maintenabilité

- Aucun nom de variable abrégé ou ambigu (`spd`, `tmp`, `obj`, `tgt`, `idx`, `mgr`, `upd`, `cnt`, `val`)
- Toute fonction > 30 lignes est découpée en sous-fonctions nommées explicitement
- Logique métier, rendu et I/O dans des fonctions séparées
- Les constantes numériques ont un nom explicite (`MAX_ENEMIES`, pas `3`)
- Le flux de données est lisible : en lisant `_ready()`, l'ordre d'initialisation est clair

---

### AXE 7 — Validité de l'API Godot 4

> Cet axe est critique. GDScript ne détecte pas les méthodes inexistantes à la compilation — uniquement au runtime.

Vérifier ligne par ligne que chaque méthode, propriété et signal appelés existent dans l'API Godot 4 :

- Aucune méthode Godot 3 dépréciée ou supprimée (`set_process_input` → `set_process_unhandled_input`, `get_used_cells_by_id` → `get_used_cells`, etc.)
- Aucune méthode inventée ou confondue (`Node2D.move_and_slide()` n'existe pas — c'est `CharacterBody2D`)
- Aucun `emit_signal("name")` — remplacer par `signal_name.emit()`
- Aucun `connect("name", ...)` avec string — remplacer par `signal.connect(callable)`
- Les propriétés d'animation (`AnimationPlayer.play()` vs `AnimationTree`) utilisées correctement
- Les types de nœuds UI (`Control`, `Button`, `Label`) ont les bonnes propriétés selon Godot 4
- **Signaux de collision (`body_entered`, `area_entered`, etc.) connectés uniquement sur `Area2D`** — jamais sur `CharacterBody2D`, `RigidBody2D`, `StaticBody2D` qui ne les déclarent pas (Parse Error immédiate)
- **`PackedVector2Array` (et tout `Packed*Array`) initialisé avec `PackedXxxArray([...])`, jamais `PackedXxxArray(val1, val2, ...)`** (Parse Error immédiate)
- **Aucun `instance=ExtResource(...)` dans un `.tscn` produit manuellement** — les UIDs sont assignés par Godot à l'import, pas par l'IA. Nœuds permanents inlinés dans `main.tscn`, entités dynamiques chargées par `load()`. Champ `uid=` omis de l'en-tête (PATTERN 25)

**Scan de typage GDScript — patterns interdits :**

```python
# Exécuter ce scan Python sur le dossier scripts/ pour confirmer l'absence de patterns interdits
import os, re

SAFE_RHS = [
    r'\w+\.new\(\)', r'create_tween\(\)', r'Vector2[i]?\(',
    r'Color\(', r'Rect2i\(', r'preload\(', r'rng\.randi', r'randf_range\(',
    r'mini\(', r'maxi\(', r'clampi\(', r'Time\.', r'get_tree\(\)',
    r'get_viewport\(\)', r'get_node_or_null\(', r'duplicate\(', r'"res://', r'\{$',
]

issues = []
for root, _, files in os.walk("scripts"):
    for fname in files:
        if not fname.endswith(".gd"):
            continue
        path = os.path.join(root, fname)
        for i, line in enumerate(open(path, encoding="utf-8").readlines()):
            s = line.strip()
            if s.startswith("#"): continue
            if re.match(r"var \w+:\s*\w", s): continue
            if re.match(r"const \w+", s): continue
            if ":=" not in s: continue
            if any(re.search(p, s) for p in SAFE_RHS): continue
            issues.append(f"{fname}:{i+1}: {s}")

for iss in issues: print(iss)
print("OK" if not issues else f"{len(issues)} pattern(s) interdit(s)")
```

**Patterns de typage à corriger :**

```
PATTERN 1 — Inférence sur accès indexé
  var x := array[i]        → var x: Type = array[i] as Type
  var x := dict[key]       → var x: Type = dict[key] as Type

PATTERN 2 — Inférence sur fonction à retour Variant ou non annoté
  var x := foo()           → var x: Type = foo()

PATTERN 3 — Inférence sur ternaire de littéraux
  var x := "a" if b else "c"   → var x: String = "a" if b else "c"

PATTERN 4 — Itération sur Array non typé
  for item in my_array:    → for item_v in my_array:
                                var item: Type = item_v as Type
  Exception : Array[Type] — l'itération directe est correcte, pas de cast nécessaire

PATTERN 5 — Tableau vide sans type
  var x := []              → var x: Array = []  (ou Array[Type] si type connu)

PATTERN 6 — Fonction sans type de retour
  func foo():              → func foo() -> ReturnType:

PATTERN 7 — Paramètre non typé
  func foo(x, y):          → func foo(x: TypeX, y: TypeY) -> void:

PATTERN 8 — Continuation de ligne invalide
  return a == B \           → return (a == B
      or a == C                  or a == C)
```

**Autres patterns à vérifier :**

```
PATTERN 9  — Signal déclaré mais jamais émis
PATTERN 10 — Chemin @onready ne correspondant pas à la scène .tscn
PATTERN 11 — Accès au scene tree avant add_child
PATTERN 12 — Fonction déclarée en doublon (Parser Error garanti)
PATTERN 13 — Position souris UI utilisée comme coordonnée monde
PATTERN 14 — toggle_mode sur bouton d'action ponctuelle
PATTERN 15 — Signal de fin d'état émis sur chemin partiel seulement
PATTERN 16 — Control UI absorbant les clics (mouse_filter manquant)
PATTERN 17 — Syntaxe de signal Godot 3 dépréciée
PATTERN 18 — Variable ou fonction mal nommée (abréviation)
PATTERN 19 — Logique ou expression dans un fichier JSON
PATTERN 20 — Nœud abonné à un manager sans synchronisation initiale
             Correction : après connexion, lire immédiatement l'état courant
             _game_manager.game_state_changed.connect(_on_game_state_changed)
             _on_game_state_changed(_game_manager.current_state)  # sync explicite
PATTERN 21 — Paramètre jamais lu sans préfixe _
PATTERN 22 — add_child() dans callback physique → call_deferred("add_child", node)
PATTERN 23 — Signal de collision connecté sur un nœud qui ne le déclare pas
             body_entered / area_entered n'existent que sur Area2D.
             CharacterBody2D, RigidBody2D, StaticBody2D n'ont AUCUN signal de collision.
             Correction : ajouter un nœud Area2D enfant (Hitbox) et connecter body_entered sur lui,
             OU lire get_slide_collision_count() / get_slide_collision() après move_and_slide().
             Produit une Parse Error au chargement du script — jamais au runtime.
PATTERN 24 — Constructeur Packed*Array avec arguments positionnels
             PackedVector2Array(Vector2(...), Vector2(...)) → Parse Error garanti.
             Correction : PackedVector2Array([Vector2(...), Vector2(...)])  (tableau Array en argument)
             S'applique à PackedVector3Array, PackedFloat32Array, PackedInt32Array, PackedColorArray, etc.
PATTERN 25 — Tout .tscn complexe produit manuellement
             Les UIDs Godot sont gérés par l'éditeur — jamais inventables manuellement.
             Tout .tscn avec sub_resource, instance=, uid= ou nœuds enfants peut provoquer
             "Error while parsing file" ou "Load failed due to missing dependencies".
             Règle définitive : main.tscn = 6 lignes exactement (format=3, ext_resource Script, node Main).
             Toute la hiérarchie est construite par code dans game_manager._build_scene().
             Aucune autre .tscn ne contient de nœuds, scripts ou ressources.
```

---

### AXE 8 — Cas limites

| Scénario | Comportement attendu |
|---|---|
| `settings.json` absent ou malformé | Jeu démarre avec toutes les valeurs fallback |
| Résolution 4:3 (1024×768) | UI lisible, aucun élément hors écran |
| Résolution 32:9 ultra-wide | Aucun étirement, marges gérées |
| Spam d'inputs (60/sec) | Aucun crash, aucun état incohérent |
| Ouverture à froid | Ressources et états affichés correctement dès la première frame |
| Clic sur bouton UI puis action dans le monde | Curseur monde à la position monde, pas du bouton UI |
| Bouton d'action pressé deux fois | Aucun double-déclenchement, aucun état incohérent |
| Complétion d'un mode interactif | UI revient à l'état idle — signal de fin d'état émis |
| Valeurs d'état initiales | Reflètent l'état réel même si les signaux d'init ont été émis avant la connexion |
| Clic sur la grille hors boutons | Zone couverte par container UI — l'action monde doit fonctionner |
| Nœud libéré en cours de jeu | `is_instance_valid()` empêche tout accès — aucun crash |
| Drop ou spawn depuis une collision | Aucune erreur "Can't change this state while flushing queries" |
| Partie complète jouée | État final cohérent, retour à TITLE fonctionnel, relance sans rechargement |
| Systèmes gameplay au démarrage | Spawner, IA et tous les systèmes non-UI démarrent bien — pas de système silencieux |

### Livrables Phase 2

Après tous les correctifs, si `test_functional.py` retourne `ALL TESTS PASSED` :

```bash
zip -r [nom_du_genre].zip [nom_du_genre]/ --exclude "*/.godot/*" --exclude "*/.DS_Store"
```

Vérifier que `project.godot` est bien présent dans l'archive avant de livrer.
