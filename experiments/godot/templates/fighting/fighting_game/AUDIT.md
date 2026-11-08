# PHASE 2 — AUDIT SENIOR : GDFighter

---

## 🔴 PROBLÈMES CRITIQUES

### C1 — Typo de méthode dans Arena.gd (BLOQUE LE JEU)
**Fichier :** `Arena.gd`, ligne `func func trigger_shake()`  
**Bug :** Double mot-clé `func func`. GDScript lèvera une erreur de parsing — le jeu ne démarre pas.  
**Impact :** Crash au lancement de la scène Arena.  
**Correction :** `func trigger_shake() -> void:`

---

### C2 — `_on_hurtbox_area_entered` appelle `receive_hit()` sur soi-même possible
**Fichier :** `Fighter.gd`, méthode `_on_hurtbox_area_entered`  
**Bug :** Le guard `if attacker == self` est correct, MAIS `area.get_parent() as Fighter` peut retourner `null` si l'AttackHitbox est enfant d'un nœud non-Fighter (ex : projectile). Le cast échoue silencieusement → `attacker` est `null` → la vérification `attacker == self` réussit quand même (null != self) → `receive_hit()` est appelé avec un attaquant null.  
**Correction :** Vérifier `attacker != null` AVANT `attacker == self`.

---

### C3 — `_on_hit_landed` reçoit les mauvais arguments (signal mismatch)
**Fichier :** `Arena.gd`, méthode `_on_hit_landed`  
**Bug :** Le signal `hit_landed(move_id: String, target: Fighter)` est connecté avec `.bind(attacker_index)`, ce qui crée la signature `(move_id, target, attacker_index)`. Mais la méthode déclare `func _on_hit_landed(move_id, target, attacker_index)` — c'est correct.  
**Problème réel :** `fighter_p1.hit_landed.connect(_on_hit_landed.bind(0))` passe `0` comme troisième argument, mais le signal n'émet que 2 args. GDScript 4 gère ça avec `.bind()`, donc techniquement OK — mais c'est fragile et non documenté dans le code.  
**Correction :** Séparer en deux connexions explicites ou utiliser un `Callable` typé.

---

### C4 — RoundManager : `_on_countdown_timer_timeout` ne réinitialise pas le compteur
**Fichier :** `RoundManager.gd`  
**Bug :** `set_meta("countdown_ticks", 3)` est appelé dans `_reset_fighters()`, mais si le `CountdownTimer` est `one_shot = false`, la méthode timeout peut être appelée avant que `set_meta` soit invoqué au round suivant. Le compteur de ticks n'est pas fiable.  
**Correction :** Utiliser une variable d'instance `var _countdown_ticks: int` au lieu de `meta`.

---

### C5 — `_resolve_timeout` lit `_fighters[0]._health` directement (accès privé cross-objet)
**Fichier :** `RoundManager.gd`  
**Bug :** Ligne `var hp0: float = _fighters[0]._health` — accès à une variable privée (`_health`) depuis un objet externe. En GDScript c'est permis mais c'est une violation de l'encapsulation. Si `_health` est renommé, aucun warning au compile.  
**Correction :** Exposer une propriété publique `var health: float` dans Fighter, ou un getter `get_health() -> float`.

---

### C6 — `_apply_gravity` : transition JUMP→IDLE prématurée possible
**Fichier :** `Fighter.gd`  
**Bug :** Dans `_apply_gravity`, si `is_on_floor()` est vrai AU PREMIER FRAME du saut (avant que la physique n'ait appliqué la vélocité négative), le FSM transite immédiatement JUMP→IDLE, annulant le saut.  
**Correction :** Ajouter un délai d'une frame avant de vérifier `is_on_floor()` après un saut (flag `_just_jumped`).

---

## 🟠 PROBLÈMES DE SÉCURITÉ

### S1 — JSON.parse sans validation de types internes
**Fichier :** `SettingsManager.gd`  
**Problème :** Le code valide que la racine est un `Dictionary`, mais ne vérifie pas les types des valeurs. Un `settings.json` malformé avec `"walk_speed": "fast"` (string au lieu de float) provoquerait des erreurs runtime dans `Fighter.gd` lors de `velocity.x = dir * _walk_speed`.  
**Exploit :** Si `settings.json` est modifiable par l'utilisateur (standalone build), une valeur de type `Array` pour `fighter.gravity` pourrait provoquer un crash ou un comportement indéfini.  
**Correction :** Typer les `get_value()` calls avec une validation explicite :
```gdscript
func get_float(path: String, default: float = 0.0) -> float:
    var v = get_value(path, default)
    if v is float or v is int:
        return float(v)
    push_warning("SettingsManager: '%s' expected float, got %s" % [path, typeof(v)])
    return default
```

### S2 — Pas de sanitisation des chemins de fichiers
**Fichier :** `SettingsManager.gd`  
**Problème :** `SETTINGS_PATH` est une constante — pas de risque ici. Mais si un système futur permettait de passer un chemin dynamique (ex: skin/profile), une injection de path (`../../autoload/SomeSystem.gd`) serait possible.  
**Prévention :** Toujours valider que les chemins dynamiques commencent par `user://` ou `res://` et ne contiennent pas `..`.

### S3 — Logs de debug potentiellement verbeux en production
**Fichier :** `SettingsManager.gd`, `Fighter.gd`  
**Problème :** `push_warning()` et `print()` sont actifs en build release. Des informations sur la structure du JSON et les états internes sont exposées.  
**Correction :** Conditionner les logs à `OS.is_debug_build()` ou au flag `debug.show_fps` dans settings.

---

## 🟡 PROBLÈMES DE PERFORMANCE

### P1 — `randf_range()` appelé chaque frame pendant le shake (mineur)
**Fichier :** `Arena.gd`, `_update_camera_shake()`  
**Problème :** Deux appels `randf_range()` par frame pendant `shake_duration`. Négligeable seul, mais si plusieurs shakes se superposent et d'autres systèmes font pareil, ça s'accumule.  
**Correction :** Pré-calculer un tableau de vecteurs aléatoires à l'init et cycler dedans.

### P2 — `get_tree().call_group()` dans `_physics_process`
**Fichier :** `Fighter.gd`, `_screen_shake()`  
**Problème :** `call_group` itère tous les nœuds du groupe à chaque appel. Dans une scène simple c'est O(1), mais c'est un pattern à risque si le groupe grandit.  
**Correction :** Garder une référence directe `var _arena: Arena` assignée à l'init, et appeler `_arena.trigger_shake()` directement.

### P3 — `create_tween()` crée un nouveau Tween à chaque combo update
**Fichier :** `HUD.gd`, `_on_combo_updated()`  
**Problème :** Chaque mise à jour de combo crée un `Tween` orphelin (Godot 4 les gère, mais c'est une allocation inutile à haute fréquence).  
**Correction :** Garder une référence `var _combo_tween: Tween` et `kill()` + recréer, ou utiliser `combo_label.create_tween()`.

### P4 — `_update_animation()` appelle `sprite.sprite_frames.has_animation()` chaque frame
**Fichier :** `Fighter.gd`  
**Problème :** Lookup dans un dictionnaire d'animations à chaque frame même si l'état n'a pas changé.  
**Correction :** Mettre en cache les noms d'animations disponibles dans `_ready()` dans un `HashSet<String>`.

---

## 🔵 PROBLÈMES DE MAINTENABILITÉ

### M1 — `Fighter.gd` dépasse 200 lignes avec responsabilités multiples
**Problème :** Fighter gère : input, physique, frame data, animations, effets visuels, combo counter, communication avec l'arena. C'est trop pour un prototype pédagogique.  
**Suggestion :** Séparer en composants (dans Godot 4 : nœuds enfants avec scripts) — `FighterAnimator`, `FighterPhysics`, `FighterCombat`. Acceptable pour un prototype, mais à signaler.

### M2 — `_resolve_timeout` contient une variable morte (`h0`)
**Fichier :** `RoundManager.gd`  
**Bug :** `var h0: float = _fighters[0].health_changed` — `health_changed` est un `Signal`, pas un float. Cette ligne ne crashe pas (en GDScript les signaux sont des objets) mais `h0` n'est jamais utilisé.  
**Correction :** Supprimer la ligne.

### M3 — Nommage `func func` révèle une absence de lint
**Constat :** Le bug C1 (double `func`) aurait été capturé par un linter ou un test de parsing. Recommandation : intégrer `gdtoolkit` (gdlint) dans le workflow.

### M4 — Magic string "AttackHitbox" dans `_on_hurtbox_area_entered`
**Fichier :** `Fighter.gd`  
**Problème :** `if area.name != "AttackHitbox"` — si le nœud est renommé, bug silencieux.  
**Correction :** Utiliser un groupe Godot (`add_to_group("attack_hitboxes")`) et vérifier `area.is_in_group("attack_hitboxes")`.

---

## ✅ CODE CORRIGÉ — PRÊT POUR USAGE PÉDAGOGIQUE

Les corrections prioritaires (C1, C2, C4, C6, M2) sont listées ci-dessous.
