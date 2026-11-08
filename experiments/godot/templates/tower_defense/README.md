# Tower Defense : template Godot 4

Un tower defense complet et piloté par les données. Les ennemis suivent un chemin fixe
vers une base ; vous placez des tours sur les cases libres pour les arrêter avant qu'ils
l'atteignent. Une partie compte 10 vagues et dure de 5 à 10 minutes.

Le template ne contient aucun fichier graphique ni sonore. Chaque objet se dessine avec
`_draw()`, et les bruitages sont synthétisés au démarrage par l'autoload `Sfx`. Toutes les
valeurs de jeu vivent dans les fichiers JSON du dossier `data/`.

---

## Comment jouer

| Action | Souris | Clavier |
| :--- | :--- | :--- |
| Choisir une tour à construire | Clic sur une carte de la boutique | `1`, `2`, `3` |
| Construire | Clic gauche sur une case d'herbe libre | |
| Annuler la construction ou la sélection | Clic droit | `Échap` |
| Sélectionner une tour posée | Clic gauche sur la tour | |
| Améliorer la tour sélectionnée | Bouton **Améliorer** | `U` |
| Vendre la tour sélectionnée | Bouton **Vendre** | `S` ou `Suppr` |
| Changer de mode de ciblage | Bouton **Cible : …** | `T` |
| Lancer la vague suivante | Bouton **Lancer la vague** | `Espace` |
| Vitesse x1 / x2 | Bouton `x1` | `F` |
| Pause | Bouton pause | `P` ou `Échap` |
| Couper le son | Bouton haut-parleur | `M` |
| Rejouer après la fin | Bouton **Rejouer** | `R` |

Les touches `1` à `3` sont lues par position physique : elles fonctionnent aussi sur un
clavier AZERTY, sans `Maj`.

Chaque carte de la boutique affiche le prix de la tour et ses caractéristiques au niveau 1,
chacune précédée d'une icône de couleur : dégâts (épée rouge), portée en cases (cible bleue),
cadence en tirs par seconde (éclair jaune) et, pour le Mortier, rayon d'explosion en cases
(éclat orange). Survolez une carte pour lire les mêmes valeurs avec leur nom. La fiche d'une
tour posée reprend ces icônes et indique en vert le gain de la prochaine amélioration.

Le déroulé d'une partie :

1. Vous commencez avec 200 or et 20 vies. Aucune vague ne part tant que vous n'avez pas
   cliqué sur **Lancer la vague** : construisez d'abord.
2. Chaque ennemi tué rapporte de l'or. Chaque ennemi qui atteint le cristal de la base vous
   retire des vies (1 pour un Soldat, 3 pour une Brute).
3. Une vague repoussée rapporte un bonus, puis un compte à rebours de 12 secondes lance la
   suivante. Si vous la lancez avant la fin du compte à rebours, vous gagnez 1 or par seconde
   restante : à 8 secondes du départ, le bouton affiche **Lancer +8**. Le bonus de fin de vague
   vaut 20 or après la vague 1 et augmente de 20 à chaque vague (200 après la vague 10).
4. Vous pouvez construire, améliorer et vendre à tout moment, y compris pendant une vague.
5. La partie est perdue à 0 vie, gagnée après la vague 10.

---

## Vocabulaire

| Terme | Sens dans ce projet | Exemple |
| :--- | :--- | :--- |
| Case | Une cellule de la grille, 60 px de côté (`tile_size`). Les distances des fichiers JSON sont exprimées en cases. Dans ce document, colonnes et lignes sont numérotées à partir de 0, comme dans `maps.json`. | Une portée de 2,3 cases vaut 138 px. La case « colonne 0, ligne 0 » est en haut à gauche. |
| Chemin | Polyligne passant par les points de passage (`waypoints`) de `maps.json`. | 8 points, 31 cases de long. |
| Progression | Distance déjà parcourue par un ennemi sur le chemin, en pixels. | Le mode de ciblage **Premier** vise la plus grande. |
| Armure | Valeur retranchée de chaque coup reçu, avec un minimum de 1 dégât. | Une Brute d'armure 6 touchée pour 10 perd 4 PV. |
| Cadence | Nombre de tirs par seconde (`fire_rate`). | 2,5 tirs/s, soit un tir toutes les 0,4 s. |
| Mode de ciblage | Règle de choix de la cible parmi les ennemis à portée. | Premier, Dernier, Plus fort, Plus proche. |

---

## Les tours et les ennemis

Le jeu compte trois tours et trois ennemis. Leur rapport de forces repose sur une seule
règle, l'armure : **dégâts subis = max(1, dégâts - armure)**.

| Tour | Coût | Attaque | Dégâts | Portée | Cadence | Rôle |
| :--- | ---: | :--- | ---: | ---: | ---: | :--- |
| Gatling | 50 | Balles à tête chercheuse | 10 | 2,3 | 2,5/s | Beaucoup de petits coups, efficace contre les Coureurs |
| Railgun | 100 | Rayon instantané | 60 | 4,0 | 0,45/s | Un gros coup, l'armure compte peu |
| Mortier | 100 | Obus en cloche, dégâts de zone | 35 | 3,0 | 0,55/s | Rayon d'explosion de 1 case, efficace contre les groupes |

| Ennemi | PV (vague 1) | Vitesse | Armure | Récompense | Vies retirées |
| :--- | ---: | ---: | ---: | ---: | ---: |
| Soldat | 70 | 1,25 case/s | 0 | 6 | 1 |
| Coureur | 38 | 2,3 cases/s | 0 | 5 | 1 |
| Brute | 360 | 0,7 case/s | 6 | 18 | 3 |

Deux calculs montrent pourquoi l'armure oblige à mélanger les tours :

- Une Gatling de niveau 1 contre une Brute : 10 - 6 = 4 dégâts par balle, soit 40 % de sa
  puissance. Il lui faut 90 balles, 36 secondes de tir, pour une Brute de vague 1.
- Un Railgun de niveau 1 contre la même Brute : 60 - 6 = 54 dégâts, soit 90 % de sa puissance.
  Sept tirs suffisent.

À l'inverse, le Railgun tire une fois toutes les 2,2 s : contre un groupe de Coureurs à
38 PV, chaque tir en tue un seul et gaspille 22 dégâts, alors que le Mortier en touche
plusieurs à la fois.

Les PV augmentent à chaque vague de 58 % des PV de base (`hp_scale_per_wave`) : un Soldat a
70 PV à la vague 1, 111 à la vague 2 et 435 à la vague 10 (70 × 6,22). Les récompenses ne
suivent pas cette hausse ; l'or supplémentaire vient du bonus de fin de vague, qui grandit.
Il faut donc améliorer ses tours pour tenir les dernières vagues.

Chaque tour s'améliore deux fois. Le niveau est visible sur le socle (une pastille dorée par
niveau), et la tourelle grossit un peu à chaque niveau. La revente rend 70 % de tout l'or
investi, améliorations comprises : une Gatling achetée 50 et améliorée pour 45 se revend 66.

### Comment ces valeurs ont été réglées

Les valeurs ont été ajustées en faisant jouer des parties complètes par des bots, à deux
niveaux :

- dans le simulateur Python `tools/balance_sim.py` (voir la section
  [Simulateur d'équilibrage](#simulateur-déquilibrage)), dont les bots choisissent à chaque
  instant l'achat le plus rentable et les cases qui couvrent le plus de chemin ;
- dans le jeu lui-même, à 60 images par seconde, avec des bots qui suivent une liste d'achats
  fixe sur des cases choisies à la main.

Résultats du simulateur avec les valeurs actuelles :

| Bot du simulateur | Résultat | Durée |
| :--- | :--- | ---: |
| Défense mixte, vagues lancées à la fin du compte à rebours (`balanced`) | Victoire, 14 vies restantes | 8,6 min |
| Défense mixte, chaque vague lancée immédiatement (`balanced_greedy`) | Victoire, 20 vies restantes | 6,5 min |
| Gatling uniquement, améliorées (`gun_only`) | Victoire, 6 vies restantes | 8,8 min |
| Railgun uniquement, améliorés (`sniper_only`) | Victoire, 9 vies restantes | 8,3 min |
| Mortiers uniquement, améliorés (`mortar_only`) | Défaite à la vague 6 | 4,7 min |
| Gatling uniquement, jamais améliorées (`cheap_spam`) | Défaite à la vague 8 | 7,1 min |
| Défense mixte limitée à 4 tours (`weak`) | Défaite à la vague 8 | 6,0 min |

Résultats dans le jeu :

| Bot dans Godot | Résultat | Durée |
| :--- | :--- | ---: |
| Défense mixte bien placée, sans lancer les vagues en avance | Victoire, 5 vies restantes | 8,8 min |
| Défense mixte, tours éparpillées sur toute la carte | Défaite à la vague 10 | 9,4 min |
| Quatre tours seulement (2 Gatling, 1 Mortier, 1 Railgun), améliorées | Défaite à la vague 4 | 2,4 min |
| Vingt Gatling, sans amélioration | Défaite à la vague 7, quand les Brutes arrivent | 5,8 min |

Les bots du jeu cessent d'investir quand leur liste est épuisée : le bot éparpillé finit la
vague 9 avec 645 or non dépensés. Un joueur qui dépense son or au fil de la partie fait mieux
qu'eux à placement égal.

Ce qu'il faut en retenir :

- **Mélanger les tours est la stratégie la plus sûre.** La défense mixte garde 14 vies ; une
  défense d'un seul type garde au mieux 9 vies (Railgun), 6 vies (Gatling), ou perd (Mortier).
- **Les améliorations sont indispensables.** Les mêmes Gatling gagnent avec améliorations et
  perdent sans, dès que les Brutes et leur armure arrivent.
- **Le placement compte autant que l'or dépensé.** Une Gatling couvre 8,5 cases de chemin
  depuis la meilleure case (colonne 9, ligne 3, entre deux tronçons), 3,1 depuis le coin en bas
  à droite (colonne 12, ligne 9) et aucune depuis la colonne 1, ligne 5. Pour le même prix, la
  première garde chaque ennemi à portée 2,7 fois plus longtemps que la deuxième.
- **Lancer les vagues en avance rapporte beaucoup.** Le bot qui lance chaque vague
  immédiatement ne perd aucune vie et finit 2 minutes plus tôt. Si vous voulez rendre cette
  stratégie plus risquée, baissez `early_call_gold_per_sec`.

Les meilleurs emplacements sont les cases d'herbe entourées de chemin sur plusieurs côtés.
Exemple : la poche de 3 × 5 cases (colonnes 5 à 7, lignes 2 à 6) est bordée par le chemin sur trois côtés,
la descente de la colonne 4, le passage de la ligne 7 et la remontée de la colonne 8. Un
Mortier posé en colonne 6, ligne 5, est à 2 cases de chacun de ces trois tronçons : sa portée
de 3 cases les couvre tous, soit 12,5 des 31 cases du chemin.

---

## Principes algorithmiques

### 1. Grille et placement

`maps.json` décrit la carte ligne par ligne : `B` pour une case constructible, `P` pour le
chemin, `X` pour des rochers. `TDGrid.grid_to_world(col, row)` donne le centre d'une case
en pixels, `world_to_grid(pos)` fait l'inverse et renvoie `(-1, -1)` hors de la carte.

Les tours posées sont rangées dans un tableau `_towers[row][col]` : savoir si une case est
libre, ou retrouver la tour sous la souris, se fait en une lecture, sans parcourir l'arbre
de scène.

### 2. Suivi du chemin par distance

Chaque image, un ennemi dispose d'un budget de distance égal à `vitesse × delta`. Il le
dépense segment par segment : si le prochain point de passage est plus proche que le budget,
il s'y place, retranche cette longueur et continue sur le segment suivant.

Cette méthode remplace l'ancienne règle « avancer vers le point, s'y accrocher à moins de
4 px ». Un Coureur avance de 138 px/s ; à vitesse x2 sur une machine qui tient 30 images par
seconde (cas courant dans un navigateur), il parcourt 9,2 px par image. Avec l'ancienne règle,
il pouvait dépasser le point et osciller autour. Avec le budget de distance, il ne dépasse
jamais, quelle que soit la vitesse.

### 3. Progression et ciblage

La distance dépensée s'additionne dans `_traveled` : `Enemy.progress()` la renvoie sans
calcul. Chaque tour parcourt les ennemis une fois, écarte ceux hors de portée (distances
comparées au carré, sans racine), et garde le meilleur score selon son mode :

| Mode | Score | Usage |
| :--- | :--- | :--- |
| Premier | progression la plus grande | Défaut : l'ennemi le plus près de la base |
| Dernier | progression la plus petite | Finir les traînards, répartir les tirs |
| Plus fort | PV restants les plus élevés | Railgun contre les Brutes |
| Plus proche | distance la plus petite | Garder la tourelle sur ce qui passe devant |

### 4. Visée et cadence

La tourelle pivote vers sa cible à 12 rad/s (`rotate_toward`). Les Gatling et Railgun ne
tirent que lorsque le canon est à moins de 0,25 rad de la cible : changer de cible coûte un
court instant, ce qui rend le mode de ciblage utile et le mouvement lisible. Le Mortier
tire sans attendre.

La cadence est un simple compteur `_cooldown` décrémenté à chaque image et remis à
`1 / fire_rate` après un tir : aucune node `Timer` par tour.

### 5. Trois façons de tirer

- **Balle (Gatling)** : elle se dirige chaque image vers la position actuelle de sa cible.
  Si la cible meurt en route, la balle termine son vol jusqu'à la dernière position connue
  et s'y éteint ; le joueur voit toujours où est parti le tir.
- **Rayon (Railgun)** : les dégâts sont appliqués immédiatement, et une traînée lumineuse
  s'efface en 0,2 s.
- **Obus (Mortier)** : le tir vise la position *future* de la cible. `Enemy.predict_position(t)`
  parcourt le reste du chemin sur `vitesse × t` pixels ; contrairement à une extrapolation en
  ligne droite, la prédiction reste juste dans les virages. L'obus suit une parabole
  (hauteur = 4 × arc × k × (1 - k)), son ombre rétrécit quand il monte, et un cercle grandit
  au sol à l'endroit de l'impact. À l'arrivée, tous les ennemis dans le rayon d'explosion
  prennent les dégâts.

### 6. Vagues

`waves.json` décrit chaque vague en blocs `{type, count, interval, delay}`. Au lancement,
`WaveManager` les aplatit en une file d'entrées `{type, wait}`, où `wait` est l'attente avant
l'apparition de cette entrée :

| Entrée | Attente |
| :--- | :--- |
| Premier ennemi du premier bloc | `delay` du bloc |
| Premier ennemi d'un bloc suivant | `interval` du bloc précédent + `delay` |
| Ennemis suivants | `interval` du bloc |

Un seul compteur flottant consomme la file. Une boucle `while` fait apparaître plusieurs
entrées dans la même image si `delta` est grand (vitesse x2).

La vague est terminée quand trois conditions sont vraies : aucun ennemi vivant, file vide,
apparitions arrêtées. Le drapeau `_spawning` passe à `false` au moment même où la dernière
entrée apparaît ; s'il attendait l'image suivante, la condition ne serait jamais remplie.

### 7. Ordre des événements quand un ennemi atteint la base

L'ennemi retire d'abord les vies (`GameState.enemy_reached_exit`), puis prévient le
`WaveManager`. Dans l'ordre inverse, le dernier ennemi d'une vague terminerait la vague
avant que ses dégâts soient comptés, et la vie perdue serait ignorée. L'ancienne version du
template avait ce défaut.

### 8. Phases de la partie

`GameState` porte la phase : `BUILD` entre deux vagues, `WAVE` pendant une vague,
`GAME_OVER` et `VICTORY` en fin de partie. La phase ne sert qu'au déroulé des vagues ;
construire, améliorer et vendre restent possibles en `BUILD` comme en `WAVE`.

### 9. `free()` ou `queue_free()`

| Contexte | Méthode | Raison |
| :--- | :--- | :--- |
| Vente d'une tour | `free()` | La case doit être libre immédiatement |
| Nettoyage au redémarrage | `free()` | Aucun objet fantôme à l'image suivante |
| Mort ou sortie d'un ennemi | `queue_free()` | Appelé pendant l'émission d'un signal |
| Fin de vol d'un projectile | `queue_free()` | Appelé pendant `_process` |

---

## Game feel

Les effets suivent les principes de Steve Swink (*Game Feel*) et de la conférence
« Juicing your cameras » de Squirrel Eiserloh (GDC 2016).

| Effet | Où | Ce qu'il communique |
| :--- | :--- | :--- |
| Tremblement d'écran par « trauma » | `ShakeCamera.gd` | L'intensité d'un impact. Le trauma décroît linéairement et l'amplitude vaut trauma², donc un petit choc se sent à peine et une fuite secoue fort. |
| Ralenti à la défaite | `Main._on_game_over` | Le temps passe à 25 % pendant 1,4 s : le joueur voit la percée. |
| Confettis à la victoire | `Main._on_game_won` | La fin de partie réussie. |
| Recul, flash de bouche, rotation de tourelle | `Tower.gd` | Quelle tour tire, et sur qui. |
| Apparition « pop » des tours | `Tower._ease_out_back` | La construction et l'amélioration (rebond à mi-course). |
| Flash blanc, barre de vie retardée | `Enemy.gd` | Chaque coup porte ; la partie blanche de la barre montre les dégâts du dernier coup. |
| Étincelles grises et son métallique | `Enemy.take_damage` | Un coup en grande partie absorbé par l'armure. |
| Textes flottants | `Fx.text` | Or gagné, dépensé, raison d'un refus (« Il manque 30 or »). |
| Chevrons animés sur le chemin | `PathMarkers.gd` | Le sens de marche, avant même la première vague. |
| Cristal de la base | `PathMarkers.gd` | Les vies restantes : il passe du cyan au rouge, clignote sous 30 % et émet une onde à chaque fuite. |
| Tour fantôme et portée | `PlacementPreview.gd` | La couverture exacte avant de payer, en vert si possible, en rouge sinon. |
| Vignettage rouge | `GameHUD._setup_vignette` | Une vie perdue (flash), puis des vies basses (pulsation à 5 vies ou moins). |
| Compteur d'or roulant, « pop » des valeurs | `GameHUD._process`, `_pop` | Les gains et dépenses. |
| Bannières de vague | `GameHUD.show_banner` | Le début d'une vague, la dernière vague, le bonus de fin de vague. |
| Sons synthétisés | `Sfx.gd` | Chaque tir, impact, mort, construction et événement de vague. Un délai minimum par son évite la cacophonie quand dix tours tirent ensemble. |

Les effets passent par deux API statiques : `Fx.burst / ring / tracer / text` et
`ShakeCamera.add_trauma`. Elles ne font rien si leur node n'est pas dans l'arbre, donc le
code de jeu ne dépend jamais de la couche d'effets.

---

## Architecture

```
tower_defense/
├── data/
│   ├── config.json       constantes globales de jeu
│   ├── towers.json       types de tours et leurs améliorations
│   ├── enemies.json      types d'ennemis
│   ├── waves.json        composition des 10 vagues
│   ├── maps.json         grille et points de passage
│   ├── strings_en.json   textes de l'interface en anglais
│   └── strings_fr.json   textes de l'interface en français
├── autoloads/
│   ├── ConfigManager.gd  lit config.json
│   ├── StringManager.gd  traductions, signal language_changed
│   ├── GameState.gd      or, vies, score, phase, compte à rebours
│   ├── TowerDatabase.gd  lit towers.json
│   ├── EnemyDatabase.gd  lit enemies.json
│   └── Sfx.gd            synthèse et lecture des bruitages
├── scripts/
│   ├── TDGrid.gd         grille, placement, dessin statique de la carte
│   ├── PathMarkers.gd    chevrons, portail d'apparition, cristal de la base
│   ├── PlacementPreview.gd  survol, tour fantôme, cercles de portée
│   ├── Tower.gd          ciblage, visée, tir, améliorations, dessin
│   ├── Enemy.gd          suivi du chemin, armure, dessin
│   ├── Projectile.gd     balle à tête chercheuse ou obus balistique
│   ├── WaveManager.gd    file d'apparition, fin de vague
│   ├── Fx.gd             particules, ondes, traînées, textes flottants
│   └── ShakeCamera.gd    caméra et tremblement d'écran
├── scenes/
│   ├── Main.tscn / Main.gd
│   └── ui/
│       ├── HUD.gd        interface (classe GameHUD)
│       └── HudIcon.gd    icônes vectorielles de l'interface
└── tools/
    ├── .gdignore         fait ignorer le dossier par Godot (ni importé ni exporté)
    └── balance_sim.py    simulateur d'équilibrage en Python
```

Ordre des autoloads : `ConfigManager`, `StringManager`, `GameState`, `TowerDatabase`,
`EnemyDatabase`, `Sfx`.

Arbre de la scène principale :

```
Main (ALWAYS)
├── Camera          ShakeCamera (PAUSABLE)
├── World (PAUSABLE)
│   ├── GridMap     TDGrid
│   ├── PathMarkers
│   ├── Towers
│   ├── Enemies
│   ├── Projectiles
│   ├── Fx
│   └── Preview     PlacementPreview
├── WaveManager     créé par Main.gd (PAUSABLE)
└── UI (CanvasLayer, ALWAYS)
    ├── Vignette
    └── HUD         GameHUD
```

`Main` et l'interface tournent en mode `ALWAYS` : les menus et les touches répondent pendant
la pause. `World` et `WaveManager` sont en `PAUSABLE` : `get_tree().paused` ne gèle que le
jeu.

L'interface ne touche jamais au monde. Elle émet des signaux d'intention que `Main.gd`
traite, et `Main.gd` appelle ses méthodes publiques :

| Signal de `GameHUD` | Traitement dans `Main.gd` |
| :--- | :--- |
| `tower_type_requested(type_id)` | Entre en mode construction |
| `upgrade_requested()` | Améliore la tour sélectionnée |
| `sell_requested()` | Vend la tour sélectionnée |
| `target_cycle_requested()` | Change le mode de ciblage |
| `wave_requested()` | Lance la vague (avec bonus d'avance) |
| `speed_toggled()` | Bascule la vitesse x1 / x2 |
| `pause_toggled()` | Met en pause ou reprend |
| `restart_requested()` | Relance une partie |

Les signaux de `GameState` (`gold_changed`, `lives_changed`, `phase_changed`, `wave_cleared`,
`life_lost`, `early_bonus_awarded`, `game_over`, `game_won`…) alimentent l'affichage.

---

## Modifier les données

### config.json

| Clé | Effet | Valeur |
| :--- | :--- | ---: |
| `default_language` | Langue au démarrage, `"en"` ou `"fr"` | `"en"` |
| `tile_size` | Côté d'une case en pixels | 60 |
| `starting_gold` | Or de départ | 200 |
| `starting_lives` | Vies de départ | 20 |
| `wave_between_delay` | Compte à rebours entre deux vagues, en secondes | 12 |
| `early_call_gold_per_sec` | Or gagné par seconde de compte à rebours restante | 1 |
| `wave_clear_bonus_base` | Bonus de la vague 1 | 20 |
| `wave_clear_bonus_step` | Bonus ajouté à chaque vague | 20 |
| `spawn_interval` | Intervalle d'apparition par défaut, en secondes | 0,8 |
| `hp_scale_per_wave` | Hausse des PV par vague, en part des PV de base (0,58 = +58 %) | 0,58 |
| `sell_refund_ratio` | Part de l'or investi rendue à la vente | 0,7 |
| `projectile_speed` | Vitesse d'un projectile si la tour n'en précise pas, en cases/s | 8 |
| `enemy_reach_damage` | Vies retirées si l'ennemi ne précise pas `lives_damage` | 1 |
| `low_lives_threshold` | Seuil du vignettage pulsé et du compteur de vies en rouge | 5 |
| `shake_decay` | Décroissance du trauma par seconde | 1,8 |
| `shake_max_offset` | Amplitude maximale du tremblement, en pixels | 10 |
| `sfx_volume_db` | Volume des bruitages | -8 |

### towers.json

| Champ | Sens |
| :--- | :--- |
| `id` | Identifiant ; sert aussi aux clés de traduction `tower_<id>_name` et `tower_<id>_desc` |
| `display_name` | Nom affiché si aucune traduction n'existe |
| `attack` | `bullet` (balle), `beam` (rayon) ou `shell` (obus) |
| `cost` | Prix de construction |
| `damage`, `range`, `fire_rate` | Dégâts par coup, portée en cases, tirs par seconde |
| `splash_radius` | Rayon d'explosion en cases (obus uniquement) |
| `projectile_speed` | Vitesse du projectile en cases/s (0 = valeur de `config.json`) |
| `color` | Couleur hexadécimale sans `#` |
| `upgrades` | Niveaux 2 et 3 : `cost` plus les seuls champs qui changent |

Exemple : le niveau 2 de la Gatling est `{ "cost": 45, "damage": 15, "range": 2.5, "fire_rate": 3.0 }`.
Un champ absent garde la valeur du niveau précédent.

### enemies.json

| Champ | Sens |
| :--- | :--- |
| `id`, `display_name` | Identifiant (clé de traduction `enemy_<id>`) et nom de secours |
| `shape` | Dessin : `blob` (Soldat), `dart` (Coureur), `armored` (Brute) |
| `hp`, `speed`, `armor` | PV de base, vitesse en cases/s, armure |
| `reward` | Or gagné à la mort (le score gagne 10 fois cette valeur) |
| `lives_damage` | Vies retirées en atteignant la base |
| `color`, `size` | Couleur hexadécimale, rayon en cases |

### waves.json

Chaque vague : `{ "wave": N, "spawns": [ {"type": "grunt", "count": 8, "interval": 1.0, "delay": 0}, ... ] }`.
`interval` et `delay` sont facultatifs (valeurs par défaut : `spawn_interval` et 0).

### maps.json

`cols`, `rows`, `waypoints` (liste de `[col, row]` dans l'ordre de marche) et `grid` (une
chaîne par ligne). Placez le premier et le dernier point de passage sur un bord de la grille :
le portail apparaît sur le premier, le cristal de la base sur le dernier. La carte est
centrée automatiquement dans l'espace laissé libre par l'interface.

### Ajouter une langue

1. Copiez `data/strings_en.json` en `data/strings_<code>.json` et traduisez les valeurs.
2. Ajoutez le code au tableau `langs` de `GameHUD._on_lang_pressed()`.

---

## Simulateur d'équilibrage

`tools/balance_sim.py` fait jouer des bots sur les fichiers JSON du dossier `data/` et
affiche le déroulé de chaque vague. Il permet de juger une modification des données en
2 secondes, avant de la confirmer en jouant. Il n'a besoin que de Python 3 et de sa
bibliothèque standard (testé avec Python 3.14).

Le simulateur reproduit les règles du code GDScript : déplacement par distance, armure,
hausse des PV par vague, file d'apparition de `WaveManager.gd`, rotation des tourelles,
balles perdues quand la cible meurt, obus visant la position prédite, bonus de vague et
bonus d'avance. Trois simplifications le distinguent du jeu : les projectiles partent du
centre de la tour (du bout du canon dans le jeu), les tours visent toujours le **Premier**
ennemi, et les tourelles ne tournent pas sur elles-mêmes quand elles n'ont pas de cible.

### Lancer une simulation

Depuis le dossier du template :

```
python tools/balance_sim.py --quiet
```

Résultat avec les valeurs actuelles :

```
  balanced         VICTORY (lives 14)       8.6 min  towers: G33333 S3331 M331
  balanced_greedy  VICTORY (lives 20)       6.5 min  towers: G33333 S3332 M322
  cheap_spam       GAME OVER at wave 8      7.1 min  towers: G1111111111111111111111111111111
  gun_only         VICTORY (lives 6)        8.8 min  towers: G3333333333333321
  sniper_only      VICTORY (lives 9)        8.3 min  towers: S3333332222
  mortar_only      GAME OVER at wave 6      4.7 min  towers: M222211
  weak             GAME OVER at wave 8      6.0 min  towers: G333 M3
```

La colonne `towers` décrit les tours possédées en fin de partie : une lettre par type (la
première lettre de son `id` : `G` pour `gun`, `S` pour `sniper`, `M` pour `mortar`), puis un
chiffre par tour, égal à son niveau. `G33333 S3331 M331` se lit : cinq Gatling de niveau 3,
quatre Railgun (trois de niveau 3, un de niveau 1) et trois Mortiers (deux de niveau 3, un
de niveau 1).

### Les bots

| Bot | Comportement |
| :--- | :--- |
| `balanced` | Mélange les types : tours à balles d'abord, une tour à obus dès 2 tours posées, tours à rayon dès qu'un ennemi blindé apparaît dans les vagues annoncées. Laisse les comptes à rebours aller à leur terme. |
| `balanced_greedy` | Comme `balanced`, mais lance chaque vague dès que possible pour toucher le bonus d'avance. |
| `cheap_spam` | Ne construit que la tour la moins chère (la Gatling) et ne l'améliore jamais. |
| `gun_only`, `sniper_only`, `mortar_only` | Un seul type de tour, améliorations permises. Le script crée un bot `<id>_only` par tour de `towers.json`. |
| `weak` | Comme `balanced`, mais s'arrête à 4 tours : le joueur qui construit trop peu. |

Tous les bots décident de la même manière, toutes les 0,25 seconde. Ils estiment la valeur
de chaque achat possible (dégâts par seconde après armure, pondérés par la composition des
vagues à venir, multipliés par la racine de la longueur de chemin couverte), divisent par son
prix et prennent le meilleur. Quand le meilleur est trop cher, ils achètent le meilleur achat
abordable s'il vaut au moins 70 % du meilleur ; sinon ils économisent.

Les bots reconnaissent les tours par leur champ `attack` (`bullet`, `beam`, `shell`) et les
ennemis blindés par leur champ `armor` : renommer une tour ou en ajouter une ne demande aucune
modification du script.

### Lire le déroulé d'une partie

`python tools/balance_sim.py --bot balanced` affiche le tableau de chaque vague. Extrait :

```
  W | lives | gold | towers (levels)             | kill/leak (types)   | dur s
  6 |    20 |  120 | G333 S22 M2                  |   26/0              |  40.2
  7 |    17 |  160 | G333 S33 M2                  |   16/1   (1B)       |  50.7
 10 |    14 |  281 | G33333 S3331 M331            |   49/1   (1B)       |  74.1
  useful damage: gun 39155 dmg / 875 gold = 44.7 dmg/gold; sniper 31801 dmg / 1015 gold = 31.3 dmg/gold; mortar 26691 dmg / 750 gold = 35.6 dmg/gold
```

| Colonne | Sens |
| :--- | :--- |
| `W` | Numéro de la vague |
| `lives` | Vies restantes à la fin de la vague |
| `gold` | Or disponible au début de la phase de construction qui précède la vague, bonus compris |
| `towers` | Tours possédées à la fin de la vague, même notation que ci-dessus |
| `kill/leak` | Ennemis tués / ennemis passés, avec le type des passés : `(1B)` = une Brute |
| `dur s` | Durée de la vague, en secondes |

La ligne `useful damage` donne, par type de tour, les dégâts réellement infligés divisés par
l'or investi. Dans cet extrait, la Gatling rapporte 44,7 dégâts par or et le Railgun 31,3.
Le Railgun est moins rentable en moyenne, mais ses gros coups perdent peu face à l'armure des
Brutes : au niveau 3, l'armure retire 6 points sur 160 à un tir de Railgun, et 6 sur 22 à
une balle de Gatling.

Ce qu'on en conclut : le bot ne perd des vies qu'aux vagues 7 et 10, chaque fois à cause
d'une Brute. La vague 7 est la première à compter cinq Brutes, la vague 10 en compte dix :
les pics de difficulté tombent sur ces deux vagues, comme le prévoit `waves.json`.

### Tester une modification sans toucher aux fichiers

L'option `--set CHEMIN=VALEUR`, répétable, modifie une copie des données. Le script joue
d'abord les données actuelles, puis les données modifiées, et affiche les deux résultats.

| Chemin | Ce qu'il modifie | Exemple |
| :--- | :--- | :--- |
| `config.<clé>` | Une clé de `config.json` | `config.hp_scale_per_wave=0.45` |
| `towers.<id>.<champ>` | Le coût ou une caractéristique de niveau 1 | `towers.mortar.cost=90` |
| `towers.<id>.up<N>.<champ>` | Une amélioration : `up1` pour le niveau 2, `up2` pour le niveau 3 | `towers.sniper.up2.damage=200` |
| `enemies.<id>.<champ>` | Une caractéristique d'ennemi | `enemies.brute.armor=8` |
| `waves.<vague>.<bloc>.<champ>` | Un bloc de `waves.json`, vagues et blocs numérotés à partir de 1 | `waves.10.3.count=12` |

Exemple :

```
python tools/balance_sim.py --quiet --set config.hp_scale_per_wave=0.45 --set towers.sniper.up2.damage=200
```

Avec ces deux changements, `balanced` gagne avec 20 vies au lieu de 14 et `weak` tient
jusqu'à la vague 9 au lieu de 8 : le jeu devient plus facile. Pour garder la modification,
reportez les valeurs dans les fichiers JSON.

Une faute de frappe arrête le script avec la liste des noms valides, par exemple :
`unknown tower 'snipr' (known: gun, sniper, mortar)`.

### Deux analyses plus longues

**`--robust`** (environ 20 secondes) rejoue chaque bot dans 9 variantes : temps de réaction
de 0,25, 0,5 ou 1 seconde, et seuil d'économie de 60, 70 ou 80 %. Une conclusion qui tient
dans les 9 variantes ne dépend pas des détails du bot. Avec les valeurs actuelles, `balanced`
gagne 9 fois sur 9 avec 11 à 14 vies, `cheap_spam` et `weak` perdent toujours à la vague 8,
`mortar_only` à la vague 5 ou 6.

**`--bench`** (environ 15 secondes) calcule, pour chaque type et chaque niveau de tour, l'or
minimum qu'il faut dépenser dans ce seul type pour qu'aucun ennemi d'une vague ne passe, les
tours étant posées sur les cases qui couvrent le plus de chemin. La ligne `gold available`
donne l'or cumulé au début de chaque vague si tous les ennemis précédents ont été tués.
Extrait :

```
  wave                1     2     3     4     5     6     7     8     9    10
  gold available    200   268   388   544   714   930  1220  1510  1886  2294
  gun    L1         100   250   300   500  1100  1300     -     -     -     -
  gun    L3         175   350   350   350   525  1050  1400  1400  1925  2800
  sniper L3         305   305   610   610   610   915  1220  1525  1525  2440
  mortar L3         325   325   650   650   650   975  1950  1300  1950  2600
```

Un tiret signifie que même 40 tours de ce type et de ce niveau laissent passer des ennemis :
les Gatling de niveau 1 ne tiennent plus aucune vague à partir de la vague 7, la première
avec cinq Brutes. À la vague 10, chaque type seul demande au moins 2 440 or pour ne rien
laisser passer. Or, au début de la vague 10, le joueur a gagné en tout 2 294 or depuis le
début de la partie (or de départ compris), ou 2 402 s'il a lancé chaque vague dès la fin de
la précédente (12 or de bonus d'avance par vague) : aucun type
seul ne tient la dernière vague sans perte, alors que le bot `balanced_greedy` la tient avec
une défense mixte.

### Quand s'en servir

1. Modifiez une valeur dans `data/`, ou testez-la d'abord avec `--set`.
2. Lancez `python tools/balance_sim.py --quiet` et comparez avec le tableau ci-dessus.
3. Confirmez en jouant. Les bots posent leurs tours sur les cases qui couvrent le plus de
   chemin et réévaluent leurs achats toutes les 0,25 seconde ; un joueur réel fait en général
   moins bien sur ces deux points, donc perd plus de vies qu'eux.
