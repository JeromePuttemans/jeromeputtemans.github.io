# Roguelite Puzzle 3D : prototype Godot 4

Un puzzle d'exploration dans un dédale de cubes en trois dimensions. Les salles n'existent pas
avant que vous y entriez : votre propre chemin construit le labyrinthe. Il faut aller chercher
le noyau d'énergie puis le rapporter au téléporteur, avant d'être à court d'énergie. Les
fragments gagnés sont conservés d'une partie à l'autre et achètent des améliorations
permanentes : chaque nouvelle partie va plus loin.

Le projet ne contient aucun fichier graphique : les salles, le joueur et l'interface sont
construits en code. Les bruitages sont synthétisés au démarrage (`scripts/Sfx.gd`).

---

## Comment jouer

| Action | Touches |
| :--- | :--- |
| Avancer, reculer, gauche, droite | Bloc ZQSD en AZERTY (WASD en QWERTY), ou les flèches |
| Monter, descendre | `E` et `A` en AZERTY (`E` et `Q` en QWERTY), ou `PgPréc` et `PgSuiv` |
| Poser une bombe | `Espace` |
| Zoomer | Molette de la souris |
| Commencer, rejouer | `Entrée` |

Les touches de lettres sont lues par position physique : elles tombent au même endroit sur
tous les claviers. Autour du joueur, six flèches indiquent les directions avec leur touche :
vertes quand le passage est ouvert, rouges et pâles quand un mur le bloque. Une flèche dorée
pointe vers l'objectif, avec sa distance en salles.

Le déroulé d'un niveau :

1. Vous partez du téléporteur (anneau bleu) avec l'énergie au maximum : 20 au départ.
2. Chaque déplacement coûte 1 énergie, y compris dans une salle déjà visitée.
3. Entrer dans une case vide crée une salle. Ses faces sont ouvertes ou murées au hasard,
   sauf celles qu'elle partage avec une salle existante, qui reprennent l'état de leur voisine.
4. Une salle peut contenir un cristal d'énergie (vert : +5 énergie, +1 fragment) ou un piège
   (rouge : -5 énergie). Elle devient ensuite une salle neutre.
5. Prenez le noyau d'énergie (sphère jaune), puis revenez au téléporteur : le niveau est
   terminé, l'énergie est rechargée, et vous gagnez 2 fragments par niveau atteint (2 au
   niveau 1, 4 au niveau 2…).

Coincé dans une impasse ? La bombe (6 énergie au départ) détruit toutes les salles du bloc de
3 × 3 × 3 cases autour de vous, sauf le téléporteur et le noyau, et ouvre tous les murs de
votre salle. Les cases détruites seront recréées, avec de nouveaux murs, quand vous y
entrerez.

La partie s'arrête quand l'énergie tombe à 0, ou quand vous êtes emmuré sans assez d'énergie
pour une bombe.

---

## Progression d'une partie à l'autre

| Amélioration | Effet par niveau | Niveaux |
| :--- | :--- | :---: |
| Réserve | Énergie max +4 | 6 |
| Détonateur | Coût de la bombe -1 (minimum 2) | 6 |
| Prospecteur | Probabilité de cristal +3 % | 6 |

Prix des niveaux successifs : 3, 5, 8, 12, 17 et 23 fragments. Les fragments, les
améliorations et le meilleur niveau sont enregistrés dans `user://roguelite_save.json` (dans
le navigateur, le stockage local du site).

La difficulté monte avec les niveaux : le noyau s'éloigne de 2 salles par niveau (3 au
niveau 1, 5 au niveau 2…) et peut se trouver un étage au-dessus ou au-dessous à partir du
niveau 2. La probabilité de mur passe de 30 % à 50 % (+2 % par niveau) et celle de piège de
6 % à 10 % au niveau 5.

Un bot de test qui avance vers l'objectif et pose une bombe quand il est bloqué, puis achète
l'amélioration la moins chère après chaque partie, atteint les niveaux 2 à 3 lors de ses
premières parties et le niveau 5 une fois toutes les améliorations achetées (12 parties).

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

### Lisibilité en 3D

La caméra est tournée de 32° autour de l'axe vertical et inclinée de 38° : à l'écran, les
trois axes du monde ne se superposent jamais. Les flèches de direction sont calculées en
projetant la position du joueur et celle d'un point voisin avec
`Camera3D.unproject_position()` : elles restent justes quel que soit le zoom.

---

## Architecture

```
roguelite/
├── data/config.json        réglages : énergie, probabilités, coûts, prix des améliorations
├── scenes/Main.tscn        GridManager, Player, CameraRig/Camera3D, HUD
└── scripts/
    ├── GameManager.gd      autoload : état de la partie, améliorations, sauvegarde
    ├── Strings.gd          autoload : textes anglais et français
    ├── Sfx.gd              autoload : bruitages synthétisés
    ├── Main.gd             environnement 3D, caméra, enchaînement des parties
    ├── GridManager.gd      dédale : masques de murs, génération, bombe, noyau
    ├── Cube.gd             RoomCube : rendu d'une salle (arêtes, murs, décor)
    ├── Player.gd           saisie, déplacement, effets des salles, fin de partie
    └── HUD.gd              panneau d'état, flèches de direction, écrans de début et de fin
```

Ordre des autoloads : `Strings`, `Sfx`, `GameManager`.

## Réglages (`data/config.json`)

| Clé | Effet | Valeur |
| :--- | :--- | ---: |
| `energy_base`, `energy_per_upgrade` | Énergie max de départ, gain par niveau de Réserve | 20, 4 |
| `move_cost` | Énergie dépensée par déplacement | 1 |
| `wall_chance_base`, `wall_chance_per_level`, `wall_chance_max` | Probabilité de mur par face | 0,3, 0,02, 0,5 |
| `resource_chance_base`, `resource_chance_per_upgrade` | Probabilité de cristal | 0,1, 0,03 |
| `resource_energy`, `resource_fragments` | Gains d'un cristal | 5, 1 |
| `trap_chance_base`, `trap_chance_per_level`, `trap_damage` | Pièges | 0,06, 0,01, 5 |
| `bomb_cost_base`, `bomb_cost_min` | Coût de la bombe | 6, 2 |
| `core_distance_base`, `core_distance_per_level` | Distance du noyau en salles | 3, 2 |
| `level_fragments` | Fragments par niveau terminé, multipliés par le numéro du niveau | 2 |
| `upgrade_costs`, `upgrade_max_level` | Prix des améliorations, niveau maximal | 3…23, 6 |
