# Parallax : prototype de shoot'em up pour Godot 4

Un shoot'em up à défilement horizontal où chaque balle encore en vol ralentit votre vaisseau,
pendant qu'un courant le pousse vers le vide. Le projet ne contient aucun fichier graphique ni
sonore : les formes, les effets et les bruitages sont produits par le code.

---

## Twist

**Chaque balle en vol réduit la vitesse du vaisseau, alors qu'un courant le pousse vers le
bord gauche de l'écran, qui le détruit.**

Le moment où le joueur le comprend : il maintient Espace depuis la gauche de l'écran, et le
vaisseau se met à reculer alors même qu'il pousse vers la droite. La jauge **VITESSE** passe
sous le repère **COURANT**, « TROP LENT : CESSEZ LE FEU OU PURGEZ » clignote, et une astuce
s'affiche une fois par session : « Vos balles en vol vous freinent. Visez juste, cessez le feu
ou purgez avec Maj. »

---

## Comment jouer

| Action | Clavier | Manette |
| :--- | :--- | :--- |
| Se déplacer | Bloc ZQSD en AZERTY (WASD en QWERTY), ou les flèches | Stick gauche ou croix |
| Tirer | `Espace`, maintenu (ou clic gauche) | `A` ou gâchette haute droite |
| Purger | `Maj` (ou clic droit) | `B` ou gâchette haute gauche |
| Pause | `Échap` ou `P` | `Start` |
| Décoller, rejouer | `Espace` ou `Entrée` | `A` |
| Revenir à l'écran titre (après une partie) | `Échap` | `Back` |
| Changer de langue (écran titre) | `L` | |

Les touches de lettres sont lues par leur position sur le clavier : elles fonctionnent sans
réglage sur tous les claviers, et l'écran titre affiche les lettres de votre clavier.

### Les règles

1. **Le courant et le vide.** Un courant pousse le vaisseau vers la gauche à 90 px/s. Le bord
   gauche de l'écran est le vide : le franchir détruit le vaisseau, même avec sa coque intacte.
   Le bord rougeoie et « LE VIDE » clignote quand vous vous en approchez, avec un bip de plus en
   plus rapide.
2. **Chaque balle en vol vous freine.** Vitesse du vaisseau = 300 − 24 × nombre de balles en
   vol, jamais moins de 60 px/s. Avec 5 balles en vol, vous allez à 180 px/s ; avec 10, à
   60 px/s, plus lentement que le courant : même en poussant vers la droite, le vaisseau recule
   de 30 px/s.
3. **Une balle reste en vol jusqu'à toucher un ennemi ou sortir de l'écran à droite.** Le tir
   part toutes les 0,1 s à 900 px/s. Tirée depuis x = 320, une balle vole 1,1 s : en tir continu,
   11 balles sont en vol, et le vaisseau recule. Tirée depuis le centre (x = 640), elle vole
   0,7 s : 7 balles en vol, 132 px/s, le vaisseau tient. Tirée depuis la limite droite
   (x = 1 210), elle sort en 0,1 s : une seule balle en vol, 276 px/s. Au premier secteur, un tir
   continu n'est donc tenable qu'à partir du milieu de l'écran environ, plus près des ennemis.
   Une balle qui touche disparaît aussitôt : viser juste libère de la vitesse.
4. **La purge.** `Maj` efface toutes vos balles en vol : la vitesse revient d'un coup, avec en
   plus une poussée de 60 % pendant 0,5 s. Elle se recharge en 4 s (jauge **PURGE**, en bas à
   gauche, brillante quand elle est prête).
5. **La coque.** Le vaisseau a 3 points de coque. Un contact avec un ennemi ou une orbe ennemie
   en retire un, puis le vaisseau clignote et reste invulnérable 1,5 s. La croix verte, lâchée par
   le Bastion une fois sur deux, répare un point ; coque pleine, elle rapporte 500 points ×
   multiplicateur.
6. **Le score.** Vous gagnez 10 points par seconde de survie, plus les points de chaque ennemi
   détruit multipliés par le multiplicateur. Chaque destruction allonge la chaîne ; elle se rompt
   après 2,5 s sans destruction ou quand la coque est touchée. Multiplicateur = 1 + chaîne ÷ 4,
   arrondi à l'entier inférieur, au plus ×8. Exemple : à la 9e destruction d'affilée, le
   multiplicateur vaut ×3 et un Lancer (250 points) en rapporte 750. Le meilleur score est
   enregistré.
7. **Les secteurs.** Un nouveau secteur commence toutes les 40 s. Le courant accélère de 10 px/s
   (jusqu'à 150 px/s au secteur 7), les vagues se rapprochent (2 s d'intervalle au secteur 1,
   0,22 s de moins par secteur, jamais moins de 0,7 s) et de nouveaux ennemis apparaissent.

### Les ennemis

| Ennemi | Aspect | Points de vie | Points | Comportement | À partir du secteur |
| :--- | :--- | :---: | :---: | :--- | :---: |
| Dériveur | Losange rouge | 1 | 100 | Traverse l'écran en ligne droite, seul, en file, en colonne ou en V | 1 |
| Ondulant | Triangle rose | 1 | 150 | Traverse l'écran en ondulant (90 px d'amplitude) : difficile à viser de loin | 1 |
| Lancer | Flèche orange | 2 | 250 | S'arrête près du bord droit, vise 0,9 s (une ligne clignotante montre sa trajectoire), puis fonce à 640 px/s. La visée se fige 0,25 s avant l'élan : s'écarter au dernier moment l'esquive | 2 |
| Sentinelle | Carré magenta | 4 | 350 | Stationne 9 s près du bord droit et tire une orbe visée toutes les 1,5 s ; son noyau s'illumine juste avant le tir | 3 |
| Bastion | Grand hexagone cramoisi | 14 | 900 | Avance lentement et tire une gerbe de 3 orbes toutes les 2,6 s ; un anneau montre ses points de vie restants | 4 |

Le Bastion résume le dilemme du jeu : le détruire demande une longue rafale, pendant laquelle le
vaisseau ralentit.

### Lire l'écran

| Zone | Contenu |
| :--- | :--- |
| En haut à gauche | Score, multiplicateur (×2, ×3…) et une barre dorée : le temps qui reste avant que la chaîne se rompe |
| En haut à droite | Secteur, temps de la partie, record |
| En bas à gauche | Points de coque (chevrons) et jauge de purge |
| En bas au centre | Jauge **VITESSE** : la barre est votre vitesse, le trait blanc **COURANT** la vitesse du courant. Barre bleue : à l'aise ; dorée : proche du courant ; rouge : sous le courant, le vaisseau recule |
| Autour du vaisseau | Un fil relie le vaisseau à chacune de ses balles en vol : ce sont elles qui le retiennent. Le vaisseau passe du blanc au doré puis au rouge quand il ralentit |

Un bot de test qui tire seulement quand il est aligné sur un ennemi survit une centaine de
secondes en médiane (13 parties, de 35 à 112 s, jusqu'au secteur 3) et meurt sous les coups des
ennemis. Le même bot qui tire sans arrêt finit avalé par le vide à chacune de ses 10 parties,
entre 59 et 82 s, avec 3 à 7 % de précision.

---

## Genre & systèmes clés

Un shoot'em up à défilement horizontal : le vaisseau se déplace librement dans l'écran, tire
vers l'avant, et affronte des vagues d'ennemis aux trajectoires reconnaissables. Le genre repose
sur la lecture des menaces, le placement, la cadence de tir et un score à multiplicateur qui
récompense les destructions enchaînées. Ici, le défilement est un courant qui pousse le vaisseau,
et la cadence de tir a un coût en vitesse.

---

## Systèmes implémentés

### Courant et vide (`player.gd`, `game_manager.gd`)

La vitesse visée du vaisseau est `direction × vitesse − courant` sur l'axe horizontal : sans
appui, il dérive vers la gauche. La vitesse réelle rejoint la vitesse visée avec une
accélération de 2 600 px/s², ce qui rend le pilotage souple. Le vaisseau est détruit dès que son
centre passe sous x = 0 ; il ne peut pas sortir par la droite (70 px de marge). Le courant de
chaque secteur est calculé par `game_manager._apply_current_speed()`.

### Traînée des balles, le twist (`player.gd`, `bullet.gd`)

`player.compute_speed()` compte les enfants du nœud `World/Bullets` : chaque balle présente retire
24 px/s. Une balle quitte ce nœud en touchant un ennemi (`combat.gd`), en sortant de l'écran ou
au bout de 1,6 s (sécurité). Comme la durée de vol dépend de la distance au bord droit, la
position du vaisseau devient un choix : à gauche, loin des ennemis mais tir coûteux ; à droite,
tir bon marché mais menaces plus proches. `twist_activated` est émis la première fois, dans une
partie, que la vitesse passe sous le courant pendant un tir.

### Purge (`player.gd`)

Sur `Maj`, toutes les balles quittent `World/Bullets` d'un coup, la vitesse est multipliée par
1,6 pendant 0,5 s, et la purge se recharge en 4 s. `player_purged` transmet la position des
balles effacées pour l'effet visuel.

### Combat (`combat.gd`)

Chaque entité est un cercle (position et rayon). Une fois par image physique, après le
déplacement de toutes les entités (`process_physics_priority = 10`), `combat.gd` teste les
paires balle-ennemi, vaisseau-ennemi, vaisseau-orbe et vaisseau-bonus par distance. Aucun corps
physique n'est configuré. Le rayon de collision du vaisseau (9 px) est plus petit que son dessin,
pour que les frôlements soient pardonnés.

### Vagues (`spawner.gd`)

Chaque vague de `gameplay.waves` décrit un motif (`single`, `line`, `column`, `pair`, `vee`), un
type d'ennemi, un nombre, le premier secteur où elle peut sortir, un poids pour le tirage et un
coût. Quand le minuteur expire, une vague est tirée au sort parmi celles autorisées, selon leur
poids ; la suivante arrive après `intervalle × coût` secondes. La première vague de chaque partie
est un seul Dériveur lent au milieu de l'écran, pour essayer le tir sans danger.

### Score, chaîne et secteurs (`game_manager.gd`)

Le score cumule les points de survie et les destructions multipliées. La chaîne, le
multiplicateur et les secteurs suivent les règles décrites plus haut. À chaque secteur,
`sector_changed` affiche une bannière, le courant accélère et le spawner raccourcit son
intervalle.

### Rendu (`starfield.gd`, `effects.gd`, entités)

Tout est dessiné dans des fonctions `_draw()`. Le fond compte trois couches d'étoiles qui
défilent à 12 %, 40 % et 100 % de la vitesse du courant, et quelques nébuleuses encore plus
lentes. Chaque couche se décale aussi verticalement selon la hauteur du vaisseau, d'autant plus
qu'elle est proche : c'est la parallaxe qui donne son nom au jeu. Balles, orbes et effets
utilisent un mélange additif, qui fait briller les couleurs.

### Game feel (`effects.gd`, `game_manager.gd`, entités)

- **Tremblement d'écran** par « trauma » : chaque impact ajoute du trauma (de 0 à 1), le décalage
  appliqué à `World` vaut `aléatoire × trauma² × 16 px`, et le trauma décroît. Le carré garde les
  petits chocs discrets et les gros violents.
- **Arrêt sur image** : `Engine.time_scale` tombe brièvement près de 0 (0,12 s quand la coque est
  touchée, 0,09 s à la destruction d'un Bastion).
- **Ralenti à la mort** : 1,1 s à 30 % de la vitesse avant l'écran de fin.
- **Retours visuels** : flash blanc et recul de l'ennemi touché, explosions de particules, anneaux
  de choc, points flottants, flash de bouche du canon, flamme du réacteur qui raccourcit quand le
  vaisseau ralentit, inclinaison du vaisseau selon sa vitesse verticale, flash rouge de l'écran
  quand la coque est touchée.
- **Sons** synthétisés au démarrage (`sfx_manager.gd`) : tir, impact, explosions, coque touchée,
  purge, visée du Lancer, tir ennemi, bip du vide, bonus, nouveau secteur, début et fin de partie.

### Saisie et sauvegarde (`input_manager.gd`, `game_manager.gd`)

Les actions sont créées par code au démarrage, avec les lettres liées à leur position physique et
les commandes de manette. Le meilleur score et la langue sont enregistrés dans
`user://parallax_save.json`.

---

## Architecture

`main.tscn` ne contient que le nœud racine avec `game_manager.gd` ; tout le reste est construit
par `game_manager._build_scene()`, comme l'exige `CONVENTION.md`.

```
Main (Node2D, game_manager.gd)        toujours actif, même en pause
├── SfxManager (Node, sfx_manager.gd)
├── World (Node2D)                     mis en pause ; secoué par effects.gd
│   ├── Starfield (starfield.gd)       fond en parallaxe
│   ├── Pickups                        croix de réparation (pickup_repair.gd)
│   ├── Enemies                        ennemis (enemy_*.gd, base enemy_base.gd)
│   ├── Shots                          orbes ennemies (enemy_shot.gd), mélange additif
│   ├── Bullets                        balles du joueur (bullet.gd), mélange additif
│   ├── Player (player.gd)
│   ├── Spawner (Node, spawner.gd)
│   ├── Combat (Node, combat.gd)
│   └── Effects (effects.gd)           particules, anneaux, textes, bord du vide
├── UI (CanvasLayer)
│   └── HUD (Control, hud.gd)
└── Transitions (CanvasLayer)
    └── Screens (Control, screens.gd)  écrans titre, pause et fin
```

| Dossier | Contenu |
| :--- | :--- |
| `datas/` | `settings.json` (réglages), `strings_fr.json` et `strings_en.json` (textes) |
| `scenes/core/` | `main.tscn` |
| `scripts/core/` | `game_manager.gd`, `spawner.gd`, `combat.gd`, `effects.gd`, `starfield.gd`, `sfx_manager.gd`, `input_manager.gd` |
| `scripts/entities/` | `player.gd`, `bullet.gd`, `enemy_base.gd`, `enemy_straight.gd` (Dériveur), `enemy_sine.gd` (Ondulant), `enemy_charger.gd` (Lancer), `enemy_gunner.gd` (Sentinelle), `enemy_tank.gd` (Bastion), `enemy_shot.gd`, `pickup_repair.gd` |
| `scripts/ui/` | `hud.gd`, `screens.gd` |

Les états de jeu sont ceux de la convention : `TITLE`, `PLAYING`, `PAUSED`, `GAME_OVER` (`WIN`
n'est pas utilisé). Quand le vaisseau meurt, le jeu reste 1,1 s en `PLAYING`, au ralenti, avant
de passer en `GAME_OVER`.

---

## Signaux et flux de données

| Signal | Émetteur | Paramètres | Abonnés |
| :--- | :--- | :--- | :--- |
| `game_state_changed` | game_manager | `state: int` | hud, screens |
| `score_changed` | game_manager | `score: int, multiplier: int, chain_ratio: float, elapsed: float` | hud |
| `sector_changed` | game_manager | `sector: int` | hud |
| `danger_changed` | game_manager | `intensity: float` | hud |
| `language_changed` | game_manager | aucun | hud, screens |
| `twist_activated` | player, relayé une fois par session par game_manager | aucun | game_manager (depuis player), hud (depuis game_manager) |
| `player_fired` | player | aucun | game_manager |
| `player_hull_changed` | player | `hull: int, hull_max: int` | hud |
| `player_died` | player | `cause: String` (`destroyed` ou `void`) | game_manager |
| `player_purged` | player | `bullet_positions: PackedVector2Array` | game_manager |
| `player_status_changed` | player | `speed: float, current_speed: float, purge_ratio: float` | hud |
| `enemy_destroyed` | combat | `enemy: EnemyBase` | game_manager |
| `enemy_damaged` | combat | `enemy: EnemyBase, impact: Vector2` | game_manager |
| `player_struck` | combat | `impact: Vector2` | game_manager |
| `pickup_collected` | combat | `kind: String, at: Vector2` | game_manager |
| `shot_fired` | enemy_base | `origin: Vector2, velocity: Vector2` | spawner |

Le flux principal, quand une balle touche un ennemi :

1. `combat.gd` détecte le contact, retire la balle de `World/Bullets` (sa traînée disparaît dès
   l'image suivante) et appelle `enemy.hit()`.
2. S'il reste des points de vie à l'ennemi, `enemy_damaged` part : game_manager lance les
   étincelles et le son d'impact. Sinon, `enemy_destroyed` part : game_manager allonge la chaîne,
   ajoute les points multipliés, déclenche l'explosion, les points flottants, le tremblement et
   le son, et peut lâcher une réparation.
3. game_manager émet `score_changed` à chaque image ; le HUD met à jour le score, le
   multiplicateur et la barre de chaîne.

---

## Comment tester le twist

1. **Tir continu.** Au début d'une partie (le vaisseau part de x = 320), maintenez Espace et la
   flèche droite. En une seconde, la jauge **VITESSE** passe sous le repère **COURANT** et
   l'astuce s'affiche : le vaisseau cale vers x = 410. Il ne gagne ensuite que 10 à 20 pixels par
   seconde, et approche x = 500 au bout de 8 s, un peu avant le milieu de l'écran : là, ses
   balles volent juste assez peu de temps pour que sa vitesse égale le courant. Relâchez Espace :
   il file vers la droite.
2. **Tir près du bord droit.** Avancez jusqu'à la limite droite et maintenez Espace : une seule
   balle est en vol à la fois, la vitesse reste à 276 px/s, bien au-dessus du courant.
   Déplacez-vous en diagonale en tirant depuis le milieu : la composante horizontale baisse et le
   vaisseau recule.
3. **Rafales visées.** Alignez-vous sur un Dériveur et tirez par rafales courtes : les balles qui
   touchent disparaissent, la jauge remonte aussitôt.
4. **Purge de secours.** Laissez le vaisseau reculer près du vide en tirant, puis pressez `Maj` :
   les balles s'effacent, la vitesse revient avec une poussée, et le vaisseau s'éloigne du bord.

---

## Paramètres configurables

Toutes les valeurs sont dans `datas/settings.json`, section `gameplay`.

| Clé | Effet | Valeur |
| :--- | :--- | ---: |
| `player_speed_base` | Vitesse du vaisseau sans balle en vol (px/s) | 300 |
| `player_speed_min` | Vitesse minimale, quel que soit le nombre de balles (px/s) | 60 |
| `fire_speed_penalty` | Vitesse retirée par balle en vol (px/s) | 24 |
| `player_acceleration` | Accélération vers la vitesse visée (px/s²) | 2 600 |
| `player_hp` | Points de coque | 3 |
| `invulnerability_time` | Invulnérabilité après un coup (s) | 1,5 |
| `player_radius` | Rayon de collision du vaisseau (px) | 9 |
| `right_margin`, `vertical_margin` | Marges que le vaisseau ne peut pas franchir (px) | 70, 34 |
| `fire_interval` | Délai entre deux tirs (s) | 0,1 |
| `bullet_speed`, `bullet_lifetime` | Vitesse (px/s) et durée de vie maximale (s) d'une balle | 900, 1,6 |
| `bullet_damage`, `bullet_radius` | Dégâts et rayon d'une balle | 1, 5 |
| `purge_cooldown` | Recharge de la purge (s) | 4 |
| `purge_boost`, `purge_boost_time` | Multiplicateur de vitesse après une purge, et sa durée (s) | 1,6, 0,5 |
| `scroll_speed`, `scroll_speed_per_sector`, `scroll_speed_max` | Vitesse du courant au secteur 1, gain par secteur, maximum (px/s) | 90, 10, 150 |
| `danger_zone_width` | Distance au bord gauche où commence l'alerte du vide (px) | 260 |
| `sector_duration` | Durée d'un secteur (s) | 40 |
| `enemy_spawn_interval`, `enemy_spawn_interval_per_sector`, `enemy_spawn_interval_min` | Intervalle entre deux vagues au secteur 1, réduction par secteur, minimum (s) | 2, 0,22, 0,7 |
| `first_wave_delay` | Délai avant la première vague (s) | 1,2 |
| `enemy_shot_speed`, `enemy_shot_radius` | Vitesse (px/s) et rayon des orbes ennemies | 300, 6 |
| `contact_damage_to_enemy` | Dégâts subis par un ennemi qui percute le vaisseau | 3 |
| `survival_points_per_second` | Points par seconde de survie | 10 |
| `chain_window`, `chain_per_multiplier`, `multiplier_max` | Délai avant rupture de la chaîne (s), destructions par cran de multiplicateur, multiplicateur maximal | 2,5, 4, 8 |
| `repair_points_when_full`, `pickup_radius` | Points d'une réparation coque pleine, rayon du bonus | 500, 14 |
| `enemies` | Points de vie, vitesse, rayon, points et réglages propres à chaque ennemi | voir le fichier |
| `waves` | Liste des vagues : motif, ennemi, nombre, secteur minimal, poids, coût | voir le fichier |

Le volume des sons est `audio.master_volume × audio.sfx_volume` (1 × 0,8).

---

## Lancement

Ouvrez le dossier dans Godot 4.4 ou plus récent et lancez le projet (`F5`). Le rendu utilise le
mode Compatibility, aussi celui de la version web publiée dans le dossier `web` du projet.
`test_functional.py` vérifie la conformité à `CONVENTION.md` : lancez-le depuis ce dossier avec
`python test_functional.py`.
