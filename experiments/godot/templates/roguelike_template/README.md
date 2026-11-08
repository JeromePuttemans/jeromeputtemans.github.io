# Roguelike : template Godot 4

Un roguelike au tour par tour, piloté par les données. Vous descendez cinq étages générés
procéduralement, ramassez des objets et des améliorations, gérez vos PV, votre énergie et un
inventaire de six places, puis affrontez le Gardien qui garde la sortie. La mort est
définitive : chaque partie repart de zéro, sur un donjon différent. Une partie dure de 10 à
15 minutes.

Le template ne contient aucun fichier graphique ni sonore. Chaque objet se dessine avec
`_draw()` (cercles, polygones, une lettre par créature), et les bruitages sont synthétisés au
démarrage par l'autoload `Sfx`. Toutes les valeurs de jeu vivent dans les fichiers JSON du
dossier `data/`.

---

## Comment jouer

| Action | Clavier | Souris |
| :--- | :--- | :--- |
| Se déplacer (8 directions) | Flèches, pavé numérique, ou le bloc ZQSD + AEWC (WASD + QEZC en QWERTY) | |
| Attaquer | Se déplacer vers l'ennemi | |
| Attendre un tour (se reposer) | `Espace`, `5` du pavé numérique | |
| Utiliser un objet | `1` à `6` | Clic sur la case de l'inventaire |
| Poser un objet au sol | `Maj` + `1` à `6` | Clic droit sur la case |
| Descendre l'escalier, prendre le portail | `Entrée`, debout sur la case | |
| Observer une case | | Survol |
| Couper le son | `M` | Bouton haut-parleur |
| Rejouer après la fin | `R` | Bouton **Rejouer** |

Les lettres et les chiffres sont lus par position physique : sur un clavier AZERTY, le bloc de
déplacement est ZQSD et les touches `1` à `6` marchent sans `Maj`. L'aide en bas du panneau
affiche les lettres de votre clavier. Maintenir une touche répète l'action : on traverse une
salle ou on se repose en gardant la touche enfoncée.

Le déroulé d'une partie :

1. Explorez l'étage. Le journal en bas de l'écran raconte chaque événement, en couleur :
   blanc pour vos coups, rouge pour ceux que vous recevez, vert pour les soins, or pour le
   butin, violet pour les niveaux, orange pour les alertes, cyan pour les indications.
2. Ramassez les objets en marchant dessus. Les améliorations (pierre à aiguiser, plaque
   d'armure, cristal de vie) s'appliquent tout de suite ; les autres objets vont dans
   l'inventaire, limité à 6 places.
3. Trouvez l'escalier, placez-vous dessus et appuyez sur `Entrée`. Marcher dessus ne suffit
   pas : vous pouvez finir d'explorer l'étage avant de descendre.
4. À l'étage 5, l'escalier est remplacé par le portail de sortie, gardé par le Gardien. Le
   prendre termine la partie par une victoire.

Le panneau de droite affiche les barres de PV, d'énergie et d'XP, le niveau, l'attaque (ATT),
la défense (DEF) et le numéro du tour, puis l'inventaire, la case observée et la minicarte.
Survolez la barre d'énergie pour lire ses règles ; survolez un ennemi pour voir ses PV, ses
caractéristiques et s'il vous a repéré.

---

## Vocabulaire

| Terme | Sens dans ce projet | Exemple |
| :--- | :--- | :--- |
| Tour | Une action du joueur, suivie de la réponse de tous les ennemis. | Marcher, attaquer, attendre, boire une potion. |
| Case | Une cellule de la grille, 32 px de côté (`tile_size`). | La carte fait 50 × 30 cases. |
| Distance de Tchebychev | `max(|dx|, |dy|)` : le nombre de pas de roi aux échecs. Un pas en diagonale vaut un pas droit. | Un ennemi en diagonale est à distance 1, donc au contact. |
| Champ de vision | Les cases que le joueur voit ce tour-ci, dans un rayon de 8 cases, murs exclus. | Un ennemi hors du champ n'est pas dessiné. |
| Case explorée | Une case vue au moins une fois sur l'étage. Elle reste dessinée, assombrie. | Le plan reste affiché ; les ennemis qui s'y déplacent n'y apparaissent plus. |
| Vigilance | Un ennemi est endormi (un « z » flotte au-dessus) ou vous traque (un « ! » apparaît quand il vous repère). | Un orc endormi ne bouge pas tant qu'il ne vous voit pas. |
| Points d'action | Réserve qui détermine combien de fois un ennemi agit par tour. | Une chauve-souris agit 2 fois par tour, un troll 1 tour sur 2. |

---

## Les ennemis

Cinq ennemis ordinaires et un boss. Chaque type n'apparaît qu'entre deux étages
(`min_floor`, `max_floor`) ; un poids (`weight`) règle sa fréquence parmi les types autorisés.

| Ennemi | Lettre | Étages | PV | ATT | DEF | XP | Particularité |
| :--- | :---: | :---: | ---: | ---: | ---: | ---: | :--- |
| Rat | `r` | 1-2 | 6 | 3 | 0 | 2 | |
| Chauve-souris | `b` | 1-3 | 4 | 2 | 0 | 2 | Rapide (2 actions par tour), vol erratique |
| Archer gobelin | `g` | 2-5 | 8 | 2 | 0 | 5 | Tire à 5 cases (3 dégâts) s'il vous voit |
| Orc | `o` | 2-5 | 14 | 5 | 1 | 6 | |
| Troll | `T` | 3-5 | 26 | 8 | 2 | 14 | Lent (1 action tous les 2 tours) : on peut le distancer |
| Le Gardien | `W` | 5 | 80 | 12 | 3 | 50 | Boss, posté à côté du portail de sortie |

Les valeurs du tableau sont celles de l'étage 1. Plus bas, chaque ennemi ordinaire gagne 12 %
de ses PV de base et 0,75 point d'attaque par étage, arrondi à l'entier inférieur
(`enemy_hp_per_floor`, `enemy_attack_per_floor`) :

| Ennemi | Étage 3 | Étage 5 |
| :--- | :--- | :--- |
| Orc | 17 PV, ATT 6 | 21 PV, ATT 8 |
| Troll | 32 PV, ATT 9 | 38 PV, ATT 11 |
| Archer gobelin | 10 PV, tir 4 | 12 PV, tir 6 |

Sans cette progression, le joueur, qui gagne des niveaux, écrasait les derniers étages. Le
Gardien n'est pas concerné : ses valeurs sont réglées directement dans `enemies.json`.

Le nombre d'ennemis augmente aussi avec la profondeur : chaque salle (sauf la salle de
départ) en reçoit de 0 à 2, plus 0,25 par étage. À l'étage 5, le bonus vaut 1 : chaque salle
reçoit de 1 à 3 ennemis. Aucun ennemi n'apparaît à moins de 6 cases du point de départ.

---

## Les objets

Chaque étage contient de 3 à 5 objets. Le premier est toujours une potion de soin : chaque
étage offre au moins un moyen de récupérer.

| Objet | Type | Effet | Étages | Poids |
| :--- | :--- | :--- | :---: | ---: |
| Potion de soin | Inventaire | Rend 40 % des PV max | 1+ | 6 |
| Ration | Inventaire | Rend 60 points d'énergie | 1+ | 4 |
| Parchemin de foudre | Inventaire | 10 dégâts à chaque ennemi visible à 4 cases ou moins, sans tenir compte de la DEF | 2+ | 2 |
| Parchemin de téléportation | Inventaire | Vous téléporte à 8 cases au moins de tout ennemi | 2+ | 1 |
| Parchemin de carte | Inventaire | Révèle le plan complet de l'étage | 1+ | 1 |
| Pierre à aiguiser | Amélioration | ATT +1, définitif | 1+ | 2 |
| Plaque d'armure | Amélioration | DEF +1, définitif | 1+ | 2 |
| Cristal de vie | Amélioration | PV max +5 | 2+ | 1 |

Utiliser un objet coûte un tour. Un objet qui n'aurait aucun effet n'est pas consommé : une
potion bue à PV pleins, une ration mangée sans faim, un parchemin de foudre sans ennemi à
portée restent dans l'inventaire, et le tour n'est pas joué.

Quand l'inventaire est plein, l'objet reste au sol. Posez-en un autre (`Maj` + chiffre) pour
faire de la place : c'est là que la limite de six cases oblige à choisir.

---

## Ressources : PV, énergie, niveaux

### L'énergie, horloge de nourriture

L'énergie part de 100. Elle baisse de 1 tous les 5 tours : sans manger, elle tient 500 tours.

- Tant qu'elle est au-dessus de 0, vous regagnez 1 PV tous les 5 tours.
- À 0, vous ne regagnez plus rien et perdez 1 PV tous les 4 tours.
- À 25 ou moins, le journal vous prévient et la barre passe à l'orange.

Se reposer soigne, mais coûte de la nourriture. Exemple : attendre 50 tours rend 10 PV et
consomme 10 points d'énergie, soit un sixième de ration. Une partie dure environ 1 500 tours,
donc 300 points d'énergie : la réserve de départ et 3 ou 4 rations suffisent, à condition de
ne pas se reposer après chaque combat.

### Les niveaux

Tuer un ennemi rapporte son XP. Passer du niveau L au niveau L+1 demande
`10 + 10 × (L - 1)` XP : 10 pour le niveau 2, 20 pour le niveau 3, 30 pour le niveau 4, et
ainsi de suite. Il faut 100 XP au total pour atteindre le niveau 5, 360 pour le niveau 9.

À chaque niveau : PV max +6, puis soin de 6 PV plus 30 % des PV max. Les niveaux pairs donnent
ATT +1, les niveaux multiples de 3 donnent DEF +1 (le niveau 6 donne les deux). La DEF monte
plus lentement exprès : avec trop de DEF, chaque coup ennemi tombe au minimum de 1 dégât et
le jeu n'offre plus aucun danger.

### Le combat

Chaque attaque tire un jet : `ATT + (-1, 0 ou +1)`. Les dégâts valent
`max(1, jet - DEF de la cible)`. Vos coups ont 10 % de chances d'être critiques : les dégâts
sont alors doublés, après la DEF.

Exemples : avec ATT 5, vous infligez 4 à 6 dégâts à un rat (DEF 0), qui tombe en un ou deux
coups. Un orc de l'étage 5 (ATT 8) vous inflige 3 à 5 dégâts si vous avez 4 de DEF. Le minimum
de 1 garantit qu'un combat avance toujours.

---

## Comment ces valeurs ont été réglées

Les valeurs ont été ajustées en faisant jouer 40 parties complètes à un bot, dans le jeu
lui-même (sans affichage, à 60 images par seconde), avec 40 graines aléatoires fixes. Le bot
explore jusqu'aux zones inconnues, ramasse les objets, boit une potion sous 40 % de PV, mange
sous 15 d'énergie, se repose hors combat sous 70 % de PV, utilise la foudre contre deux
ennemis proches et la téléportation en danger.

| Mesure | Premier jet | Valeurs actuelles |
| :--- | ---: | ---: |
| Victoires | 28 sur 40 | 18 sur 40 |
| Durée moyenne | 1 419 tours | 1 501 tours |
| Niveau en fin de partie gagnée | 10 à 12 | 8 à 10 |
| Morts causées par le Gardien | 0 | 4 |
| Morts par archer / orc / troll / faim | 6 / 0 / 1 / 5 | 7 / 5 / 2 / 4 |

Au premier jet, le joueur finissait avec 7 à 8 de DEF en moyenne (jusqu'à 12) et les
ennemis ne lui faisaient plus que 1 à 4 dégâts : le boss ne tuait personne. L'énergie baissait
tous les 3 tours, si bien qu'une partie d'environ 1 400 tours demandait environ 470 points
d'énergie pour environ 240 disponibles (la réserve de départ et 3 rations de 45). Les corrections :
progression des ennemis par étage, DEF tous les 3 niveaux, énergie tous les 5 tours, rations
à 60, moins d'ennemis supplémentaires par étage.

Ce qu'il faut en retenir : les défaites se concentrent maintenant aux étages 4 et 5 (20 sur
22), avec des causes variées, et le Gardien est une vraie menace. Les archers sont la première
cause de mort du bot, parce qu'il ne sait pas se cacher derrière un angle de mur ; un joueur
qui casse la ligne de vue les neutralise. Le bot ne sait pas non plus combattre dans un
couloir pour n'affronter qu'un ennemi à la fois : un joueur attentif fait mieux que lui.

---

## Principes algorithmiques

### 1. Génération d'un étage

`DungeonGenerator.generate()` part d'une grille remplie de murs.

1. Il tente de poser jusqu'à 14 salles rectangulaires de 4 à 9 cases de côté, en 56
   essais au plus. Une salle qui chevauche une salle existante (marge d'une case) est
   rejetée.
2. Chaque nouvelle salle est reliée à la précédente par un couloir en L, horizontal puis
   vertical ou l'inverse, au hasard : toutes les salles sont accessibles.
3. Deux couloirs supplémentaires relient des salles tirées au hasard (`extra_corridors`). Ils
   créent des boucles : on peut tourner autour d'un troll au lieu d'être coincé dans un
   cul-de-sac.
4. Le joueur part du centre de la première salle. L'escalier va au centre de la salle la plus
   éloignée **à pied**, mesurée par un parcours en largeur depuis le départ : chaque étage
   doit être traversé.
5. Les ennemis et les objets sont posés sur des cases libres, jamais deux sur la même case.

Le générateur est une fonction pure : il reçoit la configuration, le numéro d'étage, un
générateur aléatoire et deux fonctions de tirage (`Callable`), et rend un `DungeonData`. Il ne
dépend d'aucun autoload, ce qui permet de le tester seul.

### 2. Champ de vision : lancer de rayons de Bresenham

Pour chaque case à 8 cases ou moins (distance euclidienne), `FOVSystem` trace une ligne de
Bresenham depuis le joueur. Si une case intermédiaire est un mur, la cible n'est pas visible ;
sinon elle l'est, même si c'est un mur (on en voit la face). Le coût est d'environ 200 cibles
× 8 pas par tour, négligeable.

Deux couches : `visible[x][y]`, recalculé à chaque tour, et `explored[x][y]`, qui garde tout
ce qui a été vu sur l'étage. `FOVSystem.has_los()` sert aussi aux archers : ils ne tirent que
si aucun mur ne les sépare du joueur.

### 3. La machine à tours

`GameState.player_action(direction)` résout une action complète :

1. l'action du joueur : déplacement, attaque si un ennemi occupe la case visée, attente ;
2. les besoins : énergie, régénération ou faim (`_tick_needs`) ;
3. le nouveau champ de vision ;
4. le tour de chaque ennemi ;
5. les signaux de fin de tour.

Se cogner dans un mur, poser un objet et descendre l'escalier ne coûtent pas de tour.

### 4. Vitesse : les points d'action

À chaque tour ennemi, `points += vitesse`, puis l'ennemi agit tant que `points >= 1`, en
retirant 1 à chaque action. Une vitesse de 1 agit à chaque tour, 2 deux fois par tour (la
chauve-souris), 0,5 une fois tous les deux tours (le troll). Une seule règle couvre toutes les
vitesses, y compris 1,5 ou 0,25, sans cas particulier.

### 5. Intelligence artificielle

**Vigilance.** Un ennemi endormi ne fait rien. Il se réveille quand il entre dans le champ de
vision du joueur à une distance inférieure ou égale à son `chase_range`, ou quand il est
frappé. Le
tour où il vous repère, il ne fait qu'afficher son « ! » : vous avez toujours un tour pour
réagir à une nouvelle menace. Quand il vous perd de vue, il continue de vous traquer pendant 8
tours (`alert_memory_turns`), puis se rendort.

**Carte de distances (« Dijkstra map », popularisée par Brogue).** Au début de chaque tour
ennemi, un seul parcours en largeur part du joueur et calcule, pour chaque case accessible, sa
distance à pied (8 directions). Pour se rapprocher, un ennemi fait un pas vers la case voisine
la plus basse qui n'est pas occupée. Ce calcul unique sert à tous les ennemis : ils
contournent les murs, prennent les couloirs, et se répartissent autour du joueur au lieu de
se bloquer l'un derrière l'autre.

**Comportements** (champ `ai`) :

| Valeur | Comportement |
| :--- | :--- |
| `melee` | Descend la carte de distances, attaque au contact |
| `erratic` | Une action sur deux est un pas au hasard, les autres comme `melee` |
| `ranged` | Tire si le joueur est à portée et en ligne de vue, sinon se rapproche |

### 6. Index spatial

`enemy_positions` associe chaque case occupée à son ennemi : savoir si une case est libre se
fait en une lecture. L'invariant : cet index reflète exactement la liste `enemies`, mis à jour
à chaque déplacement et à chaque mort.

### 7. Graine aléatoire

Tout le hasard (génération, combat, IA) passe par un seul `RandomNumberGenerator`.
`GameState.new_game(graine)` avec une graine fixe rejoue exactement la même partie pour les
mêmes actions : c'est ce qui a permis de comparer les réglages sur les mêmes 40 donjons.

### 8. Logique instantanée, rendu qui rattrape

`GameState` résout un tour entier en un appel, puis émet un signal par événement :
`entity_moved`, `entity_attacked`, `entity_died`, `projectile_fired`, `enemy_alerted`,
`item_picked`, `item_used`, `spell_hit`, `player_leveled`, `wall_bumped`. `DungeonView` garde
pour chaque créature une position dessinée, qui rejoint la position logique par lissage
exponentiel, et transforme chaque signal en animation, particules, son et secousse. Les
animations ne bloquent jamais la saisie : on peut enchaîner les touches, le rendu suit.

### 9. Défauts corrigés de la version initiale

| Défaut | Correction |
| :--- | :--- |
| Deux ennemis pouvaient apparaître sur la même case ; l'index n'en gardait qu'un et l'autre devenait un fantôme | Les cases occupées sont réservées pendant la génération |
| Tous les types d'ennemis apparaissaient dès l'étage 1, y compris le troll, qui tuait le joueur en 6 coups quand il en fallait 7 pour l'abattre, sans aucun soin | Tables de tirage par étage, potions, régénération |
| Les ennemis poursuivaient le joueur à travers les murs, sur la seule distance | Vigilance liée au champ de vision |
| Sans recherche de chemin, ils se bloquaient dans les couloirs | Carte de distances partagée |
| Marcher sur l'escalier faisait descendre aussitôt | Descente sur `Entrée` |
| WASD et QEZC lus par lettre, donc mal placés en AZERTY | Lecture par position physique |
| Le brief demandait objets, énergie et inventaire limité ; aucun n'existait | Objets, améliorations, énergie, inventaire de 6 places |

---

## Game feel

| Effet | Où | Ce qu'il communique |
| :--- | :--- | :--- |
| Glissement des déplacements | `DungeonView._process` | Le mouvement sans saut de case en case. Une téléportation se fait d'un coup, avec deux éclats violets. |
| Fente vers la cible | `DungeonView._on_entity_attacked` | Qui frappe qui. |
| Flash blanc, chiffres de dégâts | idem | Chaque coup porte. Un critique s'affiche en or, plus gros, avec une onde. |
| Tremblement d'écran par « trauma » | `GameCamera.gd` | La gravité d'un coup reçu : l'amplitude dépend de la part des PV perdue. |
| Vignettage rouge | `GameHUD._setup_vignette` | Un coup reçu (flash), puis des PV bas (pulsation à 30 % des PV max ou moins). |
| Éclairage de torche | `DungeonView._light_at` | Le rayon de vision : la lumière baisse avec la distance et scintille légèrement. |
| Thèmes d'étage | `config.json`, `floor_themes` | La profondeur : caves bleues, grottes brunes, crypte violette, forge rouge, salle du trône dorée. |
| « z » et « ! » | `DungeonView._draw_enemy`, `_on_enemy_alerted` | La vigilance de chaque ennemi. |
| Barre de vie retardée | `GameHUD.StatBar` | La partie blanche montre ce que le dernier coup a coûté. |
| Bannière et fondu d'étage | `GameHUD._on_dungeon_ready` | L'arrivée à un nouvel étage et son nom. |
| Particules et textes flottants | `Fx.gd` | Mort, butin, soin, foudre, montée de niveau. |
| Sons synthétisés | `Sfx.gd` | Pas, coups, critique, alerte, flèche, potion, foudre, niveau, escalier, boss. |

---

## Architecture

```
roguelike_template/
├── data/
│   ├── config.json        réglages globaux et thèmes d'étage
│   ├── enemies.json       types d'ennemis
│   ├── items.json         objets et améliorations
│   ├── strings_en.json    textes en anglais
│   └── strings_fr.json    textes en français
├── autoloads/
│   ├── ConfigManager.gd   lit config.json
│   ├── StringManager.gd   traductions, signal language_changed
│   ├── EnemyDatabase.gd   lit enemies.json, tirage par étage
│   ├── ItemDatabase.gd    lit items.json, tirage, noms et descriptions
│   ├── Sfx.gd             synthèse et lecture des bruitages
│   └── GameState.gd       machine à tours, besoins, objets, signaux
├── scripts/               logique pure, sans node (sauf Fx et GameCamera)
│   ├── DungeonData.gd     grille, cases explorées, objets au sol
│   ├── DungeonGenerator.gd
│   ├── DijkstraMap.gd     carte de distances partagée par les ennemis
│   ├── Entity.gd / PlayerEntity.gd / EnemyEntity.gd
│   ├── FOVSystem.gd       champ de vision, ligne de vue
│   ├── CombatSystem.gd    formule de dégâts
│   ├── AISystem.gd        décision des ennemis
│   ├── Sprites.gd         dessin des créatures, objets, escalier, portail
│   ├── Fx.gd              particules, ondes, traînées, textes flottants
│   └── GameCamera.gd      caméra qui suit le joueur, secousses
└── scenes/
    ├── Main.tscn / Main.gd   saisie, caméra, fin de partie
    └── ui/
        ├── DungeonView.gd    rendu et animations
        ├── HUD.gd            panneau latéral, bannière, écran de fin (classe GameHUD)
        ├── MessageLog.gd     journal coloré
        └── Minimap.gd        minicarte
```

Ordre des autoloads : `ConfigManager`, `StringManager`, `EnemyDatabase`, `ItemDatabase`,
`Sfx`, `GameState`.

L'interface ne modifie jamais le jeu. Elle émet des intentions que `Main.gd` transmet à
`GameState` :

| Signal de `GameHUD` | Appel dans `GameState` |
| :--- | :--- |
| `item_use_requested(slot)` | `use_item(slot)` |
| `item_drop_requested(slot)` | `drop_item(slot)` |
| `restart_requested()` | `new_game()` |

Signaux d'état de `GameState`, qui rafraîchissent l'affichage : `run_started`,
`dungeon_ready`, `turn_ended`, `stats_changed`, `message_added(texte, nature)`,
`player_died`, `player_won`.

---

## Modifier les données

### config.json

| Clé | Effet | Valeur |
| :--- | :--- | ---: |
| `default_language` | Langue au démarrage | `"en"` |
| `dungeon_width`, `dungeon_height` | Taille de la carte en cases | 50, 30 |
| `tile_size` | Côté d'une case en pixels | 32 |
| `max_rooms` | Nombre maximal de salles | 14 |
| `room_min_size`, `room_max_size` | Taille des salles en cases | 4, 9 |
| `extra_corridors` | Couloirs supplémentaires (boucles) | 2 |
| `fov_radius` | Rayon de vision en cases | 8 |
| `total_floors` | Nombre d'étages ; le dernier a le portail et le boss | 5 |
| `player_hp_max`, `player_attack`, `player_defense` | Caractéristiques de départ | 30, 5, 1 |
| `player_crit_chance` | Chance de coup critique | 0,1 |
| `inventory_size` | Places d'inventaire | 6 |
| `energy_max` | Énergie maximale | 100 |
| `energy_drain_every` | Tours entre deux pertes d'un point d'énergie | 5 |
| `hp_regen_every` | Tours entre deux regains d'un PV (énergie > 0) | 5 |
| `starve_damage_every` | Tours entre deux pertes d'un PV (énergie à 0) | 4 |
| `hungry_threshold` | Seuil de l'alerte de faim | 25 |
| `xp_base`, `xp_growth` | XP du niveau L à L+1 = base + croissance × (L - 1) | 10, 10 |
| `level_hp_gain` | PV max gagnés par niveau | 6 |
| `level_heal_ratio` | Part des PV max rendue à chaque niveau | 0,3 |
| `enemies_per_room_min`, `enemies_per_room_max` | Ennemis par salle | 0, 2 |
| `enemies_bonus_per_floor` | Ennemis ajoutés par salle et par étage | 0,25 |
| `enemy_hp_per_floor` | Hausse des PV ennemis par étage | 0,12 |
| `enemy_attack_per_floor` | Hausse de l'attaque ennemie par étage | 0,75 |
| `enemy_safe_radius` | Aucun ennemi à cette distance du départ | 6 |
| `items_per_floor_min`, `items_per_floor_max` | Objets par étage | 3, 5 |
| `alert_memory_turns` | Tours de traque après avoir perdu le joueur de vue | 8 |
| `shake_decay`, `shake_max_offset` | Tremblement d'écran | 2,2, 9 |
| `sfx_volume_db` | Volume des bruitages | -8 |
| `floor_themes` | Une entrée par étage : `name_key`, `wall`, `wall_top`, `floor`, `floor_alt`, `light` | |

### enemies.json

| Champ | Sens |
| :--- | :--- |
| `id` | Identifiant ; clé de traduction `enemy_<id>`, qui contient l'article (« l'orc ») |
| `display_name`, `glyph`, `color` | Nom de secours, lettre sur le pion, couleur |
| `hp`, `attack`, `defense`, `xp` | Caractéristiques à l'étage 1, XP rapportée |
| `speed` | Actions par tour (1, 2, 0,5…) |
| `ai` | `melee`, `erratic` ou `ranged` |
| `chase_range` | Distance à laquelle il peut vous repérer |
| `range`, `ranged_attack` | Portée et attaque du tir (`ranged` seulement) |
| `min_floor`, `max_floor`, `weight` | Étages autorisés et fréquence |
| `boss` | `true` : jamais tiré au hasard, posé près de la sortie du dernier étage, sans progression par étage |

### items.json

| Champ | Sens |
| :--- | :--- |
| `id` | Identifiant ; clés de traduction `item_<id>_name` et `item_<id>_desc` |
| `effect` | `heal_ratio`, `energy`, `thunder`, `blink`, `reveal`, `attack`, `defense`, `max_hp` |
| `value`, `radius` | Valeur de l'effet ; rayon pour `thunder`. Les descriptions affichent ces valeurs : les modifier met le texte à jour. |
| `instant` | `true` : appliqué au ramassage, sans passer par l'inventaire |
| `shape`, `color` | Dessin (`potion`, `ration`, `scroll`, `gem`, `shield`, `heart`) et couleur |
| `min_floor`, `weight` | Premier étage et fréquence |

### Ajouter une langue

1. Copiez `data/strings_en.json` en `data/strings_<code>.json` et traduisez les valeurs. Les
   noms d'ennemis (`enemy_<id>`) contiennent leur article, en minuscule : le jeu met la
   majuscule quand le nom commence une phrase (`{Name}`).
2. Ajoutez le code au tableau `langs` de `GameHUD._on_lang_pressed()`.
