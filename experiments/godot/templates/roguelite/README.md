# Roguelite Puzzle 3D : prototype Godot 4

Un puzzle d'exploration dans un dédale de cubes en trois dimensions. Les salles n'existent pas
avant que vous y entriez : votre propre chemin construit le labyrinthe. Il faut aller chercher
le noyau d'énergie puis le rapporter au téléporteur, avant d'être à court d'énergie. Chaque
noyau rapporté vous fait choisir une amélioration, conservée d'une partie à l'autre : chaque
nouvelle partie va plus loin.

Le projet ne contient aucun fichier graphique : les salles, le joueur et l'interface sont
construits en code. Les bruitages sont synthétisés au démarrage (`scripts/Sfx.gd`).

---

## Comment jouer

| Action | Touches |
| :--- | :--- |
| Avancer, reculer, gauche, droite | Bloc ZQSD en AZERTY (WASD en QWERTY), ou les flèches |
| Monter, descendre | `E` et `A` en AZERTY (`E` et `Q` en QWERTY), ou `PgPréc` et `PgSuiv` |
| Poser une bombe | `Espace` |
| Tourner la caméra autour du joueur | Faire glisser la souris, bouton enfoncé (gauche, droit ou milieu) |
| Zoomer | Molette de la souris |
| Revenir à l'angle de départ | `R` |
| Choisir une amélioration, après un noyau rapporté | `1`, `2` ou `3` (rangée des chiffres ou pavé numérique), ou un clic sur le bouton de la carte |
| Commencer, rejouer | `Entrée` |

Les touches de lettres et la rangée des chiffres sont lues par leur position sur le clavier :
elles fonctionnent sur tous les claviers sans réglage. En AZERTY, pas besoin de `Maj` pour
`1`, `2` et `3`. Les lettres affichées à l'écran suivent la disposition de
votre clavier, détectée automatiquement (voir [Disposition du clavier](#disposition-du-clavier)).

Autour du joueur, six flèches en relief indiquent les directions, chacune avec sa touche :

- une flèche verte traverse l'ouverture et entre dans la salle voisine : le passage est
  libre ;
- une flèche rouge, courte et pâle, s'arrête avant le mur : le passage est bloqué.

Une flèche dorée pointe vers l'objectif, avec sa distance en salles. Elle disparaît quand
l'objectif se trouve dans une salle qui touche la vôtre, même en diagonale : il est alors sous
vos yeux, et la flèche le recouvrirait. La distance reste affichée en haut de l'écran
(« Objectif : prendre le noyau d'énergie (à 2 salles) »).

Avancer, reculer, gauche et droite suivent la caméra. « Avancer » va toujours vers l'axe
horizontal du monde le plus proche de la direction où regarde la caméra. Faites glisser la
souris vers la gauche jusqu'à tourner la vue d'un quart de tour : la touche `Z` (`W` en QWERTY)
mène désormais là où menait `Q` (`A`). Les étiquettes des flèches changent en même temps :
elles donnent toujours la bonne touche. Monter et descendre ne dépendent jamais de la caméra.

Le déroulé d'un niveau :

1. Vous partez du téléporteur (anneau bleu) avec l'énergie au maximum : 20 au départ.
2. Chaque déplacement coûte 1 énergie, y compris dans une salle déjà visitée.
3. Entrer dans une case vide crée une salle. Ses faces sont ouvertes ou murées au hasard,
   sauf celles qu'elle partage avec une salle existante, qui reprennent l'état de leur voisine.
4. Une salle peut contenir un cristal d'énergie (vert : +5 énergie) ou un piège (rouge :
   -5 énergie). Elle devient ensuite une salle neutre.
5. Prenez le noyau d'énergie (sphère jaune), puis revenez au téléporteur : le niveau est
   terminé. Choisissez une amélioration (voir [Améliorations](#améliorations)) ; le niveau
   suivant commence aussitôt, avec l'énergie au maximum.

Coincé dans une impasse ? La bombe (6 énergie au départ) détruit toutes les salles du bloc de
3 × 3 × 3 cases autour de vous, sauf le téléporteur et le noyau, et ouvre tous les murs de
votre salle. Les cases détruites seront recréées, avec de nouveaux murs, quand vous y
entrerez.

La partie s'arrête quand l'énergie tombe à 0, ou quand vous êtes emmuré sans assez d'énergie
pour une bombe.

### Disposition du clavier

Le jeu lit les touches de lettres par leur position, quelle que soit la lettre imprimée
dessus. La touche qui porte `Z` sur un clavier AZERTY est celle qui porte `W` sur un clavier
QWERTY : elle fait avancer dans les deux cas. La disposition ne change donc que les lettres
affichées, sur les flèches autour du joueur et dans la ligne d'aide en bas de l'écran.

Le jeu détecte la disposition au démarrage, puis la corrige à la première touche de
déplacement pressée. Si les lettres affichées ne correspondent pas à votre clavier, choisissez
la bonne dans la liste **Clavier**, en bas à gauche de l'écran :

| Choix | Lettres affichées (avancer, reculer, gauche, droite, monter, descendre) |
| :--- | :--- |
| Automatique | Celles de la disposition détectée, indiquée entre parenthèses : « Automatique (AZERTY) » |
| AZERTY | `Z` `S` `Q` `D` `E` `A` |
| QWERTY | `W` `S` `A` `D` `E` `Q` |

Avec une autre disposition (Dvorak, par exemple), la liste affiche « Automatique » sans
parenthèses, et les lettres affichées sont celles que votre clavier produit. Le choix est
enregistré avec la progression.

### Salles proches et salles éloignées

Quand le dédale grandit, des salles se superposent à l'écran. Pour garder la lecture claire,
seules les salles proches du joueur sont dessinées normalement. Les autres s'estompent.

La distance se compte en déplacements possibles, à travers les passages ouverts. Une salle
collée à la vôtre mais séparée par un mur, qu'il faut contourner en 5 déplacements, est donc
estompée : elle ne vous sert pas dans l'immédiat.

Deux curseurs, en bas à gauche de l'écran, règlent cet affichage :

| Curseur | Effet | Plage | Au premier lancement |
| :--- | :--- | :--- | :--- |
| **Rayon de proximité** | Nombre de déplacements en dessous duquel une salle reste nette | 1 à 10 salles | 3 salles |
| **Salles éloignées** | Opacité des salles au-delà de ce rayon | 0 % à 100 %, par pas de 5 % | 15 % |

Avec un rayon de 1, seules votre salle et celles où vous pouvez entrer directement restent
nettes : c'est le réglage le plus lisible dans un dédale dense. Avec un rayon de 10, presque
tout le dédale exploré reste net. À 0 % d'opacité, les salles éloignées disparaissent
complètement. Le téléporteur et le noyau gardent leur éclat à tout réglage : vous savez
toujours où ils sont. Les deux réglages sont enregistrés avec la progression.

---

## Améliorations

Chaque fois que vous rapportez le noyau au téléporteur, le jeu s'arrête sur l'écran « Niveau 1
terminé » (avec le numéro du niveau) et vous propose trois cartes, une par amélioration.
Chaque carte dit ce que fait l'amélioration et chiffre ce que vous gagnez. Choisissez-en une :
cliquez sur son bouton **Choisir**, ou pressez `1`, `2` ou `3`. Le niveau suivant commence
aussitôt, avec l'énergie au maximum.

| Touche | Amélioration | Effet de chaque niveau | Gain affiché sur la carte, au premier choix | Niveaux |
| :---: | :--- | :--- | :--- | :---: |
| `1` | Réserve | Énergie maximale +4 au début de chaque niveau | Énergie maximale de 20 à 24 | 6 |
| `2` | Détonateur | La bombe coûte 1 énergie de moins | Coût de la bombe de 6 à 5 énergie | 4 |
| `3` | Prospecteur | Part des nouvelles salles qui contiennent un cristal d'énergie : +3 points | Salles avec cristal de 10 % à 13 % | 6 |

Les améliorations agissent toutes seules : il n'y a rien à activer pendant la partie. Elles
sont gratuites et permanentes, et la mort ne les retire pas. L'écran de fin n'en propose
aucune : il résume la partie et rappelle celles que vous gardez (« Vos améliorations sont
conservées : Réserve 2/6 · Détonateur 1/4 »).

Le Détonateur s'arrête au niveau 4, car la bombe atteint alors son coût minimal de
2 énergie : un cinquième niveau ne changerait rien. Une carte au maximum affiche **Maximum
atteint** et ne peut plus être choisie. Quand les trois améliorations sont au maximum
(16 choix en tout), les niveaux s'enchaînent sans écran de choix.

### Le Prospecteur

Le Prospecteur agit sur le contenu des salles que vous créez ensuite. Quand vous entrez dans
une case vide, le jeu tire au sort le contenu de la nouvelle salle. Au départ, 10 % des
nouvelles salles contiennent un cristal d'énergie (vert), qui rend 5 énergie quand vous y
entrez. Chaque niveau de Prospecteur ajoute 3 points : 13 % au niveau 1, 28 % au niveau 6.

Sur un niveau où vous créez 30 salles, vous trouvez en moyenne 3 cristaux (15 énergie) sans
Prospecteur, et 8,4 cristaux (42 énergie) avec le Prospecteur au niveau 6. La ligne
**Cristaux** du panneau d'état, en haut à gauche, affiche la valeur en cours : « Cristaux :
13 % des nouvelles salles ».

### Sauvegarde et difficulté

Les améliorations, le meilleur niveau et les réglages **Rayon de proximité**, **Salles
éloignées** et **Clavier** sont enregistrés dans `user://roguelite_save.json` (dans le
navigateur, le stockage local du site).

Une sauvegarde de la version précédente du jeu, où les améliorations s'achetaient avec des
fragments, repart avec ses améliorations à zéro ; le meilleur niveau et les réglages sont
conservés. Sans cette remise à zéro, une sauvegarde où tout avait été acheté sauterait l'écran
de choix dès le premier noyau rapporté. Le fichier porte un numéro de version (`"version": 2`)
qui permet de reconnaître l'ancien format.

La difficulté monte avec les niveaux : le noyau s'éloigne de 2 salles par niveau (3 au
niveau 1, 5 au niveau 2…) et peut se trouver un étage au-dessus ou au-dessous à partir du
niveau 2. La probabilité de mur passe de 30 % à 50 % (+2 % par niveau) et celle de piège de
6 % à 10 % au niveau 5.

Un bot de test avance vers l'objectif, pose une bombe quand il est bloqué et choisit
l'amélioration de plus bas niveau après chaque noyau rapporté. Il meurt au niveau 3 lors de
ses premières parties. Toutes ses améliorations sont au maximum après 6 à 8 parties ; il
meurt ensuite entre les niveaux 3 et 5.

---

## Principes algorithmiques

### Murs par masque de bits

Chaque salle stocke un entier de 6 bits, un par face, dans l'ordre de `GridManager.DIRS` :
devant, derrière, gauche, droite, haut, bas. Un bit à 1 est un mur. Passer de la salle A à la
salle B n'est permis que si A n'a pas de mur vers B et si B, quand elle existe, n'a pas de mur
vers A.

### Génération à l'entrée

Une salle est créée au moment où le joueur entre dans sa case (`GridManager.enter`). Pour
chaque face, si une salle voisine existe, la face reprend l'état de la face qu'elles
partagent ; sinon elle devient un mur avec la probabilité `wall_chance`. Les murs restent
donc cohérents des deux côtés. Le type de la salle (cristal, piège, neutre) est tiré au même
moment.

### Bombe

`GridManager.bomb` supprime les salles du bloc de 3 × 3 × 3 cases (distance de Tchebychev de
1) autour du joueur, sauf le téléporteur et le noyau. Elle remet ensuite le masque de la salle
du joueur à 0 et retire, chez les salles restantes adjacentes, le mur qui faisait face au
joueur.

### Choix d'amélioration

`GameManager.complete_level()` passe au niveau suivant sans le démarrer : il met
`awaiting_choice` à vrai et émet `upgrade_offered`, que le HUD affiche sous forme de cartes.
Tant que le choix est ouvert, `can_act()` est faux : le joueur ne peut ni bouger ni poser de
bombe, et les flèches de direction sont masquées. `choose_upgrade()` augmente l'amélioration,
enregistre la sauvegarde, puis démarre le niveau suivant, dont l'énergie maximale tient compte
de la Réserve. Les cartes calculent leurs chiffres avec `upgrade_value(id, niveau)` pour le
niveau actuel et le suivant.

### Caméra orbitale

Au départ, la caméra est tournée de 32° autour de l'axe vertical et inclinée de 38° : à
l'écran, les trois axes du monde ne se superposent jamais. Faire glisser la souris change ces
deux angles de 0,35° par pixel. La rotation autour de l'axe vertical est libre ; l'inclinaison
reste entre 12° et 85°, pour ne jamais passer sous le dédale. `R` ramène les deux angles à leur
valeur de départ en 0,35 seconde, par le plus court chemin.

### Flèches de direction en 3D

Les flèches sont de vrais objets 3D (`DirectionGizmo`, enfant du joueur), avec une tige et une
pointe éclairées. Leur taille est exprimée en unités du monde : une salle mesure 1, la flèche
verte va de 0,27 à 0,79 depuis le centre du joueur et dépasse donc la face de la salle, placée
à 0,5. La flèche rouge s'arrête à 0,46, juste avant le mur.

La perspective de la caméra les traite comme les salles. Une flèche qui pointe vers la caméra
paraît courte, une flèche couchée en travers de la vue paraît longue, et tourner la caméra les
fait pivoter avec le dédale. Des flèches 2D de longueur fixe à l'écran perdraient ce
raccourcissement, et leur direction deviendrait instable dès qu'un axe s'aligne avec la vue.

Les murs des salles sont semi-transparents. Les flèches passent après eux dans le rendu (même
passe transparente, priorité plus haute) : les murs ne les teintent jamais. Elles écrivent la
profondeur, donc elles se masquent correctement entre elles.

Les lettres des touches et la distance de l'objectif restent du texte 2D, que le HUD place sur
la projection d'un point situé au-delà de chaque pointe (`Camera3D.unproject_position()`). Le
texte le plus éloigné de la caméra est écrit en premier. Une lettre qui arrive à moins de
26 pixels du joueur à l'écran s'efface progressivement, et disparaît sous 10 pixels : c'est le
cas des touches de montée et de descente quand la caméra regarde presque à la verticale.

### Touches relatives à la caméra

`Main.gd` transmet à chaque image la rotation de la caméra au joueur (`PlayerPawn.view_yaw`).
`view_quarter()` l'arrondit au quart de tour le plus proche, entre 0 et 3, et `to_world()`
tourne la direction de la touche d'autant de quarts de tour. Un quart de tour transforme
(x, z) en (z, -x). Deux exemples :

| Rotation de la caméra | Quarts de tour | « Avancer » (0, 0, -1) devient |
| :--- | :---: | :--- |
| 32° (angle de départ) | 0 | (0, 0, -1) : inchangé |
| 100° | 1 | (-1, 0, 0) : la gauche du monde |

`to_relative()` fait l'opération inverse : le HUD s'en sert pour afficher sur chaque flèche la
touche qui mène dans cette direction.

### Détection de la disposition du clavier

Le joueur lit `physical_keycode`, la position de la touche, nommée d'après la touche QWERTY
américaine placée au même endroit : `KEY_W` désigne la touche qui imprime `Z` en AZERTY.
L'autoload `Keyboard` décide seulement des lettres à afficher. Il part d'une estimation, puis
l'affine avec chaque source disponible :

| Moment | Source | Résultat |
| :--- | :--- | :--- |
| Démarrage | Langue du système ou du navigateur (`OS.get_locale()`) | AZERTY pour le français, sauf au Canada, en Suisse et au Luxembourg, et pour le néerlandais de Belgique ; QWERTY sinon. `fr_FR` et `nl_BE` donnent AZERTY, `fr_CA` donne QWERTY. |
| Démarrage, sur ordinateur | Disposition active du système (`DisplayServer.keyboard_get_keycode_from_physical()`) | La lettre de chacune des six touches |
| Démarrage, dans le navigateur | API Keyboard (`navigator.keyboard.getLayoutMap()`), offerte par les navigateurs basés sur Chromium (Chrome, Edge, Opera) | La lettre de chacune des six touches. La réponse arrive de façon asynchrone : `Keyboard` l'attend jusqu'à 3 secondes. |
| Chaque touche de déplacement pressée | Caractère produit (`keycode`) comparé à la position (`physical_keycode`) | Voir ci-dessous |

La dernière source corrige les autres en cours de partie, par exemple après un changement de
disposition dans le système. Trois touches portent une lettre différente selon la
disposition : `W`/`Z`, `A`/`Q` et `Q`/`A`. Presser l'une d'elles bascule les six lettres d'un
coup. Si la touche en position `W` produit `Z`, le clavier est en AZERTY, et la touche en
position `A` affichera aussitôt `Q`. Les touches `S`, `D` et `E` sont identiques dans les deux
dispositions : elles ne changent rien. Si l'API Keyboard est absente (Firefox, Safari) ou
refusée, la langue et les touches pressées suffisent.

Certains claviers virtuels envoient une touche sans position (`physical_keycode` vaut
`KEY_NONE`). `Player.gd` retrouve alors la direction d'après la lettre produite, avec la
disposition en cours (`Keyboard.dir_from_keycode()`).

### Focus par parcours en largeur

Après chaque déplacement et chaque bombe, `GridManager.update_focus()` part de la salle du
joueur et parcourt le graphe des salles en largeur, en ne franchissant que les passages
permis par `can_move()`. Le parcours s'arrête au rayon choisi avec le curseur **Rayon de
proximité** (`GameManager.focus_radius`, 3 déplacements par défaut). Les salles atteintes sont
proches ; toutes les autres sont éloignées. Déplacer ce curseur relance le même parcours
depuis la salle du joueur.

Une salle éloignée utilise la variante « far » de ses matériaux. Il existe une seule variante
par sorte de pièce (arête, mur, décor) et par type de salle, partagée par toutes les salles
éloignées. Son opacité vaut l'opacité normale multipliée par le réglage du curseur **Salles
éloignées**. Avec le réglage de départ à 15 %, une arête colorée passe de 0,75 à 0,11 et une
arête de salle neutre de 0,4 à 0,06. Déplacer ce curseur ne modifie donc que ces quelques
matériaux partagés, quel que soit le nombre de salles. À 0 %, les salles éloignées sont masquées au lieu d'être
dessinées transparentes.

---

## Architecture

```
roguelite/
├── data/config.json        réglages : énergie, probabilités, coûts, niveaux des améliorations
├── scenes/Main.tscn        GridManager, Player, CameraRig/Camera3D, HUD
└── scripts/
    ├── GameManager.gd      autoload : état de la partie, choix des améliorations, sauvegarde
    ├── Strings.gd          autoload : textes anglais et français
    ├── Keyboard.gd         autoload : disposition du clavier, lettre affichée pour chaque touche
    ├── Sfx.gd              autoload : bruitages synthétisés
    ├── Main.gd             environnement 3D, caméra orbitale, enchaînement des parties
    ├── GridManager.gd      dédale : masques de murs, génération, bombe, noyau, focus
    ├── Cube.gd             RoomCube : rendu d'une salle (arêtes, murs, décor, variante éloignée)
    ├── Player.gd           saisie relative à la caméra, déplacement, effets des salles, fin de partie
    ├── DirectionGizmo.gd   flèches de direction et flèche de l'objectif en 3D, autour du joueur
    └── HUD.gd              panneau d'état, lettres des flèches, panneau d'options, écrans de début, de choix et de fin
```

Ordre des autoloads : `Strings`, `Keyboard`, `Sfx`, `GameManager`. `Keyboard` doit précéder
`GameManager`, qui lui transmet le choix enregistré au chargement de la sauvegarde.

## Réglages (`data/config.json`)

| Clé | Effet | Valeur |
| :--- | :--- | ---: |
| `energy_base`, `energy_per_upgrade` | Énergie max de départ, gain par niveau de Réserve | 20, 4 |
| `move_cost` | Énergie dépensée par déplacement | 1 |
| `wall_chance_base`, `wall_chance_per_level`, `wall_chance_max` | Probabilité de mur par face | 0,3, 0,02, 0,5 |
| `resource_chance_base`, `resource_chance_per_upgrade` | Probabilité de cristal | 0,1, 0,03 |
| `resource_energy` | Énergie rendue par un cristal | 5 |
| `trap_chance_base`, `trap_chance_per_level`, `trap_damage` | Pièges | 0,06, 0,01, 5 |
| `bomb_cost_base`, `bomb_cost_min` | Coût de la bombe | 6, 2 |
| `core_distance_base`, `core_distance_per_level` | Distance du noyau en salles | 3, 2 |
| `upgrade_max_level` | Niveau maximal de la Réserve et du Prospecteur. Celui du Détonateur vaut `bomb_cost_base - bomb_cost_min`. | 6 |
| `focus_radius_default` | Réglage du curseur **Rayon de proximité** au premier lancement, remplacé ensuite par la valeur enregistrée. Le curseur va de 1 à 10 (`GameManager.FOCUS_RADIUS_MIN` et `FOCUS_RADIUS_MAX`). | 3 |
| `far_opacity_default` | Réglage du curseur **Salles éloignées** au premier lancement, remplacé ensuite par la valeur enregistrée | 0,15 |
