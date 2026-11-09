# Autobattler : modèle de jeu pour Godot 4

Un autobattler sur grille : vous achetez des unités, vous les placez sur votre moitié de
l'arène, puis elles combattent seules l'équipe adverse. Trois unités identiques fusionnent en
une unité plus forte, et les classes et origines communes activent des synergies. Il faut
survivre aux 15 manches, dont trois contre un boss. Toutes les valeurs du jeu sont dans des
fichiers JSON. Le projet ne contient aucun fichier graphique ni sonore : unités, effets et
bruitages sont produits par le code.

---

## Comment jouer

| Action | Commande |
| :--- | :--- |
| Acheter une unité | Clic sur sa carte dans la boutique ; elle arrive sur le banc |
| Placer, déplacer, échanger | Glisser une unité du banc vers une case de votre moitié (en bas), ou d'une case à l'autre |
| Vendre | Clic droit sur l'unité, ou la glisser sur la boutique |
| Rafraîchir la boutique | Bouton **Rafraîchir** ou touche `D` (2 or) |
| Acheter un niveau | Bouton **Niveau +1** ou touche `F` |
| Lancer le combat, puis changer de vitesse | Bouton **COMBATTRE** ou `Espace` ; pendant le combat, vitesse ×1 ou ×2 |
| Voir les détails d'une unité | Survol (boutique, banc, plateau, ennemis) |
| Rejouer après la fin | Bouton **Nouvelle partie** ou `R` |

### Le déroulé d'une manche

1. **Préparation.** L'équipe ennemie de la manche est déjà visible, estompée, sur la moitié
   haute de l'arène : placez vos unités en conséquence. Achetez, vendez, rafraîchissez la
   boutique, montez de niveau.
2. **Combat.** Vos unités et les ennemis se battent seuls. Le combat s'arrête quand une équipe
   n'a plus d'unité, ou au bout de 40 secondes (le temps écoulé compte comme une défaite).
3. **Résultat.** Une victoire rapporte 1 or de bonus à la manche suivante. Une défaite coûte
   des points de vie : `2 + 1 par ennemi survivant + 1 par étape` (étape 1 pour les manches 1 à
   5, 2 pour les manches 6 à 10, 3 ensuite). Exemple : perdre la manche 12 face à 3 survivants
   coûte 2 + 3 + 3 = 8 points de vie.

Vous commencez avec 36 points de vie. À 0, la partie est perdue ; si vous en avez encore après
la manche 15, elle est gagnée.

### L'économie

- **Revenu.** Chaque manche à partir de la deuxième rapporte 5 or, plus les intérêts : 1 or par
  tranche de 10 or gardés, 5 au plus. Avec 23 or en poche, vous recevez 5 + 2 = 7 or. La barre
  du haut affiche ce revenu à l'avance.
- **Prix.** Une unité coûte son coût (1, 2 ou 3 or). La revendre rend toute sa valeur : 1 copie
  d'une unité de coût 2 rend 2 or, une unité deux étoiles (3 copies) rend 6 or.
- **Niveau.** Il fixe le nombre d'unités autorisées sur le plateau : 3 au départ, 8 au plus.
  Chaque niveau coûte 4, 6, 8, 10 puis 12 or, et améliore les chances d'unités chères dans la
  boutique :

| Niveau | Coût 1 | Coût 2 | Coût 3 |
| ---: | ---: | ---: | ---: |
| 3 | 75 % | 25 % | 0 % |
| 4 | 60 % | 35 % | 5 % |
| 5 | 45 % | 40 % | 15 % |
| 6 | 30 % | 45 % | 25 % |
| 7 | 20 % | 45 % | 35 % |
| 8 | 15 % | 40 % | 45 % |

### Les fusions

Trois unités identiques de même niveau d'étoiles fusionnent aussitôt en une seule, d'une étoile
de plus. L'unité gardée est celle qui était déjà sur le plateau, s'il y en avait une. Chaque
étoile multiplie les points de vie et l'attaque par 1,8, et la puissance de la capacité par 1,5 :
une Garde de braise deux étoiles a 1 170 PV au lieu de 650. Vous pouvez acheter avec un banc plein
si l'unité achetée complète une fusion. Sur la carte de boutique, deux pastilles dorées
indiquent combien de copies vous possédez déjà : les deux allumées, l'achat suivant fusionne.

### Les synergies

Chaque unité a une classe et une origine. Une synergie compte les **types** d'unités différents
qui la portent sur le plateau : deux copies de la même unité comptent pour une. Ses effets
s'additionnent d'un palier à l'autre.

| Synergie | Paliers | Premier palier | Second palier |
| :--- | :---: | :--- | :--- |
| Gardien (classe) | 2, 3 | Gardiens : +30 d'armure | Toute l'équipe : +30 d'armure (Gardiens : +60) |
| Lame (classe) | 2, 3 | Lames : +20 % de chances de coup critique | 40 % en tout |
| Arcane (classe) | 2, 3 | Arcanes : commencent avec la moitié de leur mana | Commencent avec tout leur mana |
| Tireur (classe) | 2, 3 | Tireurs : +25 % de vitesse d'attaque | +56 % en tout |
| Braise (origine) | 2, 4 | Unités de braise : +20 % de dégâts | +45 % en tout |
| Givre (origine) | 2, 4 | Ennemis : -15 % de vitesse d'attaque | -28 % en tout |
| Sève (origine) | 2, 4 | Toute l'équipe : récupère 1,5 % de ses PV par seconde | 3 % par seconde |

Le panneau **Synergies** liste celles du plateau et l'effet du prochain palier. L'équipe ennemie
profite elle aussi de ses synergies.

### Les unités

| Unité | Coût | Classe, origine | PV | Attaque | Coups/s | Portée | Armure | Mana | Capacité (mana plein) |
| :--- | :---: | :--- | ---: | ---: | ---: | ---: | ---: | ---: | :--- |
| Garde de braise | 1 | Gardien, Braise | 650 | 45 | 0,6 | 1 | 35 | 80 | Bouclier de 220 sur elle-même |
| Lame de givre | 1 | Lame, Givre | 520 | 55 | 0,8 | 1 | 20 | 60 | Coup à 240 % de l'attaque |
| Adepte de sève | 1 | Arcane, Sève | 420 | 38 | 0,65 | 3 | 10 | 70 | Soigne de 220 l'allié le plus blessé |
| Archère de braise | 1 | Tireur, Braise | 440 | 48 | 0,75 | 4 | 10 | 70 | Salve sur les 2 ennemis les plus proches, 160 % chacun |
| Rempart de givre | 2 | Gardien, Givre | 850 | 55 | 0,6 | 1 | 45 | 90 | 150 dégâts et 1,5 s d'étourdissement |
| Lame de sève | 2 | Lame, Sève | 680 | 68 | 0,85 | 1 | 25 | 70 | Bond sur l'ennemi le plus faible, coup à 220 % |
| Pyromancienne | 2 | Arcane, Braise | 520 | 48 | 0,65 | 3 | 10 | 80 | Boule de feu : 230 dégâts sur la cible et les cases autour |
| Arbalétrier de givre | 2 | Tireur, Givre | 560 | 62 | 0,7 | 4 | 15 | 70 | Coup à 300 % de l'attaque |
| Colosse de sève | 3 | Gardien, Sève | 1 150 | 70 | 0,55 | 1 | 55 | 100 | Bouclier de 160 pour toute l'équipe |
| Faucheur de braise | 3 | Lame, Braise | 820 | 90 | 0,9 | 1 | 30 | 80 | Tourbillon : 260 dégâts aux ennemis autour de lui |
| Oracle de givre | 3 | Arcane, Givre | 640 | 58 | 0,65 | 3 | 15 | 90 | Nova : 240 dégâts autour de la cible, 1 s d'étourdissement |
| Traqueuse de sève | 3 | Tireur, Sève | 700 | 82 | 0,8 | 4 | 15 | 80 | Salve sur les 4 ennemis les plus proches, 150 % chacun |
| Golem d'obsidienne (boss) | | | 2 600 | 110 | 0,5 | 1 | 60 | 100 | Séisme : 260 dégâts autour de lui, 1,2 s d'étourdissement |

Sur le plateau, la couleur d'une unité donne son origine (orange : braise, cyan : givre, vert :
sève), son icône sa classe (bouclier, épée, étoile, arc), l'anneau son camp (bleu : vous,
rouge : l'ennemi) et les losanges dorés ses étoiles.

### Les ennemis

Les ennemis viennent de la même liste d'unités que les vôtres. À la manche r, l'équipe adverse
compte `2 + partie entière((r - 1) × 0,4)` unités : 2 à la manche 1, 7 à la manche 14. Leur coût
suit les chances du niveau `3 + partie entière((r - 1) / 2,5)`, des unités deux étoiles
apparaissent à partir de la manche 6 (6 % de chances de plus par manche), trois étoiles à partir
de la manche 15, et toutes gagnent 1,2 % de PV et d'attaque par manche. Aux manches 5, 10 et 15,
le golem d'obsidienne mène l'attaque (PV et attaque ×1, ×1,4 puis ×1,8) et prend la place de trois unités.

### Lire l'écran

| Zone | Contenu |
| :--- | :--- |
| Barre du haut | Manche (et BOSS), points de vie, or, revenu de la manche suivante, niveau et unités placées |
| À gauche | L'arène : ennemis en haut, vous en bas ; le banc dessous ; une ligne d'aide ou d'erreur |
| Au centre | Les synergies du plateau |
| À droite | La boutique (chances par coût, rafraîchissement, niveau), le bouton de combat, la fiche de l'unité survolée |

Pendant le combat, chaque unité porte une barre de PV (le bouclier en blanc) et une barre de
mana bleue. Les dégâts s'affichent en blanc, les coups critiques en doré, les capacités en
violet, les soins en vert et les boucliers en bleu clair.

### Équilibre mesuré

Un bot de test achète en priorité les unités qui complètent une fusion ou une synergie, monte de
niveau dès qu'il le peut à partir de la manche 3, place les unités de mêlée devant et les
tireurs derrière, puis combat. Sur 12 parties, il en gagne 10, avec 1 à 30 points de vie à
la fin.

| Manches | Combats gagnés par le bot |
| :--- | :--- |
| 1 à 5 (dont le premier boss) | 12 sur 12 |
| 6 à 11 (dont le deuxième boss) | 10 ou 11 sur 12 |
| 12 à 14 | 4 à 6 sur 12 |
| 15 (boss final) | 2 sur 12 |

---

## Principes algorithmiques

### 1. La machine à états : PREP, BATTLE, RESULT

`RoundManager` enchaîne trois phases : préparation, combat, résultat (2,2 s de bandeau), puis la
manche suivante. `GAME_OVER` et `VICTORY` sont terminales ; seul `new_game()` en sort. Après
l'attente du résultat, une garde (`if phase != Phase.RESULT: return`) empêche une partie
relancée entre-temps d'être avancée par l'ancienne attente.

### 2. Une simulation à pas fixe, découplée de l'affichage

`BattleSimulator` est un objet de données, sans nœud. `RoundManager._process()` l'avance par pas
fixes de 1/30 s (multipliés par la vitesse ×1 ou ×2) et transmet ses événements (`move`,
`attack`, `projectile`, `damage`, `heal`, `shield`, `ability`, `death`, `end`) par le signal
`battle_event`. `BoardView` les transforme en animations. La simulation n'attend jamais
l'affichage : elle reste testable sans scène, comme le montre le bot.

### 3. Ciblage et déplacement sur la grille

À chaque pas, une unité vise l'ennemi vivant le plus proche, en distance de Tchebychev (une
diagonale compte pour 1), puis le moins de PV, puis le plus petit identifiant (déterministe).
À portée, elle attaque toutes les `1 / vitesse d'attaque` secondes. Hors de portée, elle avance
vers la case libre voisine la plus proche de sa cible ; la case est réservée aussitôt, si bien
que deux unités ne partagent jamais une case. Si aucune case ne la rapproche, elle attend.

### 4. Les dégâts

```
dégâts = attaque × (1 + bonus de dégâts) × 2 si critique × 100 / (100 + armure)
```

Exemple : 100 d'attaque contre 50 d'armure font 100 × 100 / 150 = 67 dégâts. Un bouclier absorbe
les dégâts en premier. Les coups de mêlée portent aussitôt ; les tirs volent à 9 cases par
seconde et ratent une cible morte entre-temps. Une unité gagne 10 de mana par attaque et 5 par
coup reçu ; mana plein, elle lance sa capacité au lieu d'attaquer.

### 5. Les synergies comptent des types d'unités

`TraitSystem.count()` ne compte qu'une fois chaque type d'unité, puis `apply()` additionne les
effets de chaque palier atteint, sur la synergie, sur l'équipe ou sur l'ennemi selon leur
portée. Les bonus sont écrits dans l'état de combat de chaque unité, recalculé à chaque combat :
une unité commence toujours un combat à neuf.

### 6. La fusion

Après chaque achat, `RoundManager._merge_from()` cherche les copies de même type et de même
étoile. À trois, il garde celle du plateau (sinon la première), retire les deux autres, ajoute
une étoile, puis recommence avec l'étoile suivante : trois deux étoiles donnent une trois
étoiles dans la foulée.

### 7. Des ennemis connus à l'avance

`EnemyFactory` tire l'équipe adverse avec un générateur aléatoire initialisé par la graine de la
partie et le numéro de manche. L'équipe montrée pendant la préparation est donc exactement celle
qui combat, et une même partie rejouée avec la même graine donne les mêmes ennemis.

### 8. Le plateau en dictionnaire

`Board.cells` associe une case `Vector2i(colonne, ligne)` à une unité : recherche en O(1), cases
vides sans entrée. Le banc est un tableau de taille fixe. Un emplacement est
`{"zone": "board", "cell": ...}` ou `{"zone": "bench", "index": ...}`, et un déplacement vers un
emplacement occupé échange les deux unités. En combat, la ligne r du plateau devient la ligne
`4 + r` de l'arène.

### 9. Le graphe de signaux

```
RoundManager
  -> phase_changed      -> bandeaux, bouton de combat, panneaux
  -> gold_changed       -> barre du haut, boutique
  -> hp_changed         -> barre du haut (pulsation rouge)
  -> board_changed      -> plateau, synergies
  -> unit_merged        -> éclat doré sur le plateau
  -> battle_event       -> animations et sons du plateau
  -> battle_finished    -> bandeau victoire ou défaite
  -> feedback           -> ligne d'erreur sous le banc
```

---

## Architecture

```
autobattler/
├── data/
│   ├── config.json          réglages (voir plus bas)
│   ├── units.json           les 12 unités et le boss
│   ├── traits.json          les 7 synergies : paliers et effets
│   ├── strings_fr.json      textes en français
│   └── strings_en.json      textes en anglais
├── autoloads/
│   ├── ConfigManager.gd     lit config.json, lecture des fichiers JSON
│   ├── StringManager.gd     textes, langue (française si le système l'est)
│   ├── UnitDatabase.gd      unités, synergies, tirage selon les chances de la boutique
│   ├── Sfx.gd               bruitages synthétisés au démarrage
│   └── RoundManager.gd      phases, économie, boutique, niveau, fusions, pilotage du combat
├── scripts/                 classes de données, sans nœud
│   ├── Unit.gd              type, étoiles, état de combat
│   ├── Board.gd             cases du plateau et banc
│   ├── TraitSystem.gd       comptage et application des synergies
│   ├── BattleSimulator.gd   le combat pas à pas
│   └── EnemyFactory.gd      l'équipe adverse de chaque manche
└── scenes/
    ├── Main.tscn            nœud racine seul
    ├── Main.gd              construit l'écran, relie les événements aux retours
    └── ui/                  UiTheme, UnitPainter, BoardView, ShopPanel, ShopCard,
                             TraitsPanel, InfoPanel, TopBar, Banner, EndScreen
```

Toute l'interface est construite par le code. **Ordre des autoloads** : `ConfigManager`,
`StringManager`, `UnitDatabase`, `Sfx`, `RoundManager`.

---

## Modifier les données

### config.json

| Clé | Effet | Valeur |
| :--- | :--- | ---: |
| `board_cols`, `board_rows`, `bench_size` | Taille de votre moitié de plateau et du banc | 7, 4, 8 |
| `player_hp_start`, `rounds_total` | Points de vie de départ, nombre de manches | 36, 15 |
| `boss_rounds`, `boss_hp_multipliers`, `boss_slots` | Manches de boss, multiplicateur de PV de chacun, places d'escorte qu'il prend | 5, 10, 15 ; 1, 1,4, 1,8 ; 3 |
| `income_base`, `interest_step`, `interest_cap`, `win_bonus` | Revenu, or par tranche d'intérêt, intérêts maximaux, bonus de victoire | 5, 10, 5, 1 |
| `shop_size`, `reroll_cost` | Offres de la boutique, prix du rafraîchissement | 5, 2 |
| `start_level`, `max_level`, `level_costs` | Niveau de départ, niveau maximal, prix des niveaux suivants | 3, 8, 4…12 |
| `shop_odds` | Chances de chaque coût par niveau (en %) | voir le tableau plus haut |
| `merge_count`, `star_stat_multiplier`, `star_ability_multiplier` | Copies pour une fusion, multiplicateurs par étoile | 3, 1,8, 1,5 |
| `damage_base`, `damage_per_survivor`, `damage_per_stage` | Points de vie perdus après une défaite | 2, 1, 1 |
| `battle_timeout`, `result_delay` | Durée maximale d'un combat, durée du bandeau de résultat (s) | 40, 2,2 |
| `move_time`, `projectile_speed` | Temps pour changer de case (s), vitesse des tirs (cases/s) | 0,42, 9 |
| `mana_per_attack`, `mana_per_hit`, `crit_multiplier` | Mana par attaque et par coup reçu, multiplicateur critique | 10, 5, 2 |
| `enemy_count_base`, `enemy_count_per_round` | Taille de l'équipe adverse | 2, 0,4 |
| `enemy_level_step`, `enemy_stat_growth` | Manches par niveau ennemi, croissance des statistiques par manche | 2,5, 0,012 |
| `enemy_star2_start`, `enemy_star2_per_round`, `enemy_star3_start`, `enemy_star3_per_round` | Apparition des ennemis deux et trois étoiles | 5, 0,06, 14, 0,08 |

### units.json

| Champ | Effet |
| :--- | :--- |
| `id`, `tier` | Identifiant (le nom vient de `unit_<id>` dans les textes), coût |
| `traits` | Classe et origine |
| `hp`, `attack`, `attack_speed`, `range`, `armor`, `mana` | Statistiques une étoile |
| `ability` | `type` (`strike`, `shield_self`, `shield_team`, `heal_ally`, `volley`, `aoe`, `nova`, `stun`, `whirl`, `slam`, `dash`), `value`, et selon le type `count` ou `duration` |
| `boss` | `true` pour le boss, absent de la boutique |

### traits.json

| Champ | Effet |
| :--- | :--- |
| `kind`, `color` | `class` ou `origin`, couleur de l'icône |
| `thresholds` | Nombres de types d'unités pour chaque palier |
| `effects` | Un effet par palier : `stat` (`armor`, `crit`, `mana_start`, `attack_speed`, `damage`, `enemy_attack_speed`, `regen`), `value`, `scope` (`trait`, `team`, `enemies`) |

Les textes des effets de synergie (`trait_<id>_1`, `trait_<id>_2`) sont dans les fichiers de
textes : pensez à les mettre à jour si vous changez les valeurs. Les textes n'utilisent que des
caractères présents dans la police intégrée de Godot : dans la version web, il n'existe pas de
police de secours, et un caractère manquant s'afficherait comme un carré. C'est pourquoi les
étoiles des unités sont dessinées, jamais écrites.
