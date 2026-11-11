# Aurore : shoot'em up vertical (Godot 4)

Vous pilotez le chasseur Aurore à travers le secteur de Kepler : des vagues d'ennemis, un mini-boss, puis le vaisseau amiral et ses trois phases. Le tir est automatique ; vous gérez le placement, le mode concentré, les bombes et le score.

Le projet ne contient aucune image ni aucun son : vaisseaux, balles et décor sont dessinés par le code, les bruitages sont synthétisés au lancement. Les réglages sont dans `data/config.json`, les ennemis et les boss dans `data/enemies.json`, l'étape dans `data/stage.json`, les textes dans `data/strings_fr.json` et `data/strings_en.json`.

Testé avec Godot 4.4.1 (export web) et 4.7.

---

## Commandes

| Action | Clavier | Manette |
| :--- | :--- | :--- |
| Déplacer | Flèches, ou Z Q S D (W A S D sur un clavier QWERTY) | Croix ou stick gauche |
| Mode concentré | Maj ou Espace, maintenu | A ou gâchette haute droite |
| Bombe | X ou B | B ou X |
| Pause | Échap ou P | Start |

Les lettres sont lues par leur position physique : les touches de déplacement sont celles placées sous les doigts, quelle que soit la disposition du clavier.

---

## L'écran

La zone de jeu fait 540 x 720 pixels au centre de l'écran. Les deux panneaux latéraux affichent :

| Panneau gauche | Panneau droit |
| :--- | :--- |
| Score et meilleur score de la difficulté choisie | Vies de réserve (petits vaisseaux) |
| Chaîne (multiplicateur) et sa barre de temps | Bombes |
| Nombre de frôlements | Puissance de 1 à 4 |
| Progression de l'étape, avec un repère par boss | Difficulté et rappel des touches |

Pendant un boss, une barre en haut de la zone donne son nom, ses points de vie pour la phase en cours, un point par phase restante et le temps restant.

---

## Le vaisseau

| Réglage | Valeur | Effet |
| :--- | :--- | :--- |
| `player_speed` | 330 px/s | Vitesse normale |
| `player_focus_speed` | 150 px/s | Vitesse en mode concentré, pour se glisser entre les balles |
| `player_hitbox` | 3,5 px de rayon | La seule partie qui compte : le dessin du vaisseau est bien plus grand |
| `graze_radius` | 26 px | Distance de frôlement |
| `shot_interval` | 0,066 s | Une salve 15 fois par seconde |

Le déplacement est immédiat, sans accélération : le vaisseau s'arrête exactement où vous lâchez la touche. En mode concentré, un point blanc cerclé de rouge montre la zone de touche et un cercle discret montre la distance de frôlement.

### Les deux tirs

- **Tir large** (normal) : deux flux droits, auxquels la puissance ajoute des flux obliques. Il couvre l'écran contre les petits ennemis.
- **Lance** (mode concentré) : des flux resserrés devant le vaisseau, à 1,6 de dégâts au lieu de 1. C'est le tir contre les gros ennemis et les boss.

| Puissance | Ce qui s'ajoute |
| :--- | :--- |
| 1 | Deux flux |
| 2 | Deux flux à 10 degrés et deux satellites |
| 3 | Deux flux à 22 degrés (tir large) ou deux flux de plus (lance) |
| 4 | Deux satellites de plus |

Les satellites s'écartent en tir large et se resserrent devant le vaisseau en mode concentré. La puissance monte avec les capsules **P**, lâchées par les cargos jaunes et le mini-boss. Une vie perdue fait descendre la puissance d'un niveau et relâche une capsule P que vous pouvez reprendre.

### Bombes et vies

Une bombe dure 1,2 seconde : une onde part du vaisseau, transforme chaque balle touchée en éclat, inflige 60 points de dégâts par seconde aux ennemis (40 % de cela aux boss) et rend le vaisseau invulnérable 2,5 secondes. Vous en avez au moins 2 à chaque nouvelle vie, au maximum 5. Les cargos verts et le mini-boss lâchent une capsule **B**.

Vous commencez avec 3 vies. Une vie supplémentaire est accordée à 600 000 puis à 1 500 000 points. Après une vie perdue, le vaisseau revient par le bas, invulnérable 2,5 secondes, et la chronologie de l'étape attend son retour.

---

## Le score

| Source | Points de base |
| :--- | :--- |
| Ennemi détruit | De 100 (dard) à 2 500 (cargo), 30 000 pour le mini-boss, 120 000 pour le boss final |
| Gemme (lâchée par les ennemis) | 100 |
| Éclat (balle annulée) | 20 |
| Frôlement | 20 |
| Phase de boss brisée à temps | 15 000 x numéro de la phase (mini-boss), 30 000 x numéro de la phase (boss final) |
| Capsule P à puissance maximale | 5 000 |

Ces points sont multipliés par la **chaîne**. Chaque destruction l'augmente (de 0,1 pour un petit ennemi, de 0,5 pour un gros) et chaque frôlement de 0,02, jusqu'à x8. Elle tient 2 secondes après le dernier gain, puis baisse de 1 par seconde. Une vie perdue la remet à x1.

Exemple : à x4, une gemme rapporte 400 points ; à x1, elle en rapporte 100. Enchaîner les destructions avant de ramasser les gemmes paie.

Les objets montent un peu puis tombent lentement. Ils sont attirés vers le vaisseau dans un rayon de 70 px (120 px en mode concentré), ou partout si le vaisseau monte dans le quart haut de l'écran, au-dessus de la ligne de collecte placée à 190 px du bord. Une bombe ou une phase de boss brisée attire tout ce qui est à l'écran.

**Annulation de balles :** quand un gros ennemi est détruit, ses propres balles deviennent des éclats. Quand une phase de boss est brisée, toutes les balles de l'écran deviennent des éclats.

**Bonus de fin**, si l'étape est terminée : 50 000 par vie de réserve, 20 000 par bombe restante, 100 000 sans aucune vie perdue. Les cinq meilleurs scores de chaque difficulté sont gardés, avec la meilleure chaîne ; une étoile marque une partie terminée.

---

## L'étape

La chronologie de `data/stage.json` compte 58 événements sur 176 secondes d'horloge. L'horloge s'arrête pendant les boss et pendant le retour du vaisseau après une vie perdue. Une partie complète dure environ 6 minutes.

| Moment | Ce qui arrive |
| :--- | :--- |
| 0 à 80 s | Formations de dards et de guêpes, premières canonnières, deux cargos (capsules P), mines, lanciers |
| 80 s | Mini-boss **Sentinelle**, 2 phases |
| 83 à 172 s | Vagues plus denses, tourelles à spirales, cargo P, cargo B, murs de mines |
| 172 s | Alerte : le décor accélère, une sirène retentit |
| 176 s | Boss final **Couronne écarlate**, 3 phases |

Le ciel passe du bleu au violet puis au rouge à mesure que l'on approche du boss, et une planète traverse le milieu de l'étape.

### Ennemis

| Ennemi | Points de vie | Comportement |
| :--- | :--- | :--- |
| Dard | 3 | Suit une trajectoire en formation, tire parfois une balle visée |
| Guêpe | 5 | Formation plus lente, éventail de 3 balles vers le bas |
| Lancier | 10 | Descend, vise une demi-seconde, fonce vers vous en tirant 3 balles |
| Mine | 8 | Dérive vers le bas ; détruite, elle libère un anneau de 10 balles |
| Canonnière | 70 | Se place, tire des anneaux et des salves visées pendant 6 s, repart |
| Tourelle | 110 | Comme la canonnière, avec une spirale à 5 bras |
| Cargo jaune | 90 | Dérive lentement en spirale, lâche une capsule P |
| Cargo vert | 90 | Tire des anneaux, lâche une capsule B |

### Boss

| Boss | Phase | Points de vie | Temps | Motifs |
| :--- | :--- | :--- | :--- | :--- |
| Sentinelle | 1 | 950 | 30 s | Salves visées en éventail, anneaux tournants |
| Sentinelle | 2 | 1 100 | 32 s | Spirale à 4 bras, murs avec une brèche visée |
| Couronne écarlate | 1 | 1 700 | 40 s | Anneaux qui jaillissent puis ralentissent, éventails de 7 balles |
| Couronne écarlate | 2 | 2 200 | 45 s | Deux spirales en sens opposés aux balles courbes, rafales de grosses balles |
| Couronne écarlate | 3 | 2 600 | 50 s | Murs à brèche, tirs rapides visés, anneaux de grosses balles |

Une phase brisée avant la fin de son temps rapporte son bonus. À la fin du temps, la phase passe sans bonus ; à la dernière phase, le boss explose sans rapporter ses points.

### Difficultés

| Réglage | Normal | Difficile |
| :--- | :--- | :--- |
| Vitesse des balles | x1 | x1,25 |
| Cadence de tir des ennemis | x1 | x1,55 |
| Points de vie des ennemis | x1 | x1,15 |

---

## Principes techniques

### Balles en tableaux

Les balles ennemies ne sont pas des nœuds : chacune est une case dans des tableaux parallèles (position, vitesse, accélération, rotation, type, couleur, propriétaire, frôlée ou non). Retirer une balle copie la dernière à sa place, sans allocation. Chaque image, la vitesse tourne de `turn` radians par seconde (bras courbes des spirales) et sa norme varie de `accel` entre deux bornes (balles qui jaillissent puis ralentissent).

Le dessin se fait en trois passes (halo, corps coloré, cœur blanc), chacune avec une seule texture générée au lancement : le moteur regroupe les centaines de quadrilatères en quelques appels de dessin. Le test de touche utilise 70 % du rayon visible plus la zone du vaisseau : une balle paraît plus grosse qu'elle ne blesse, ce qui rend les motifs denses lisibles et justes.

Les tirs du joueur sont volontairement fins et translucides : même à pleine puissance, les balles ennemies restent visibles.

### Motifs de tir

Chaque ennemi porte une liste de motifs dans `data/enemies.json` : `aimed` (éventail visé), `fan` (éventail fixe), `ring` (anneau qui tourne à chaque salve), `spiral` (bras qui tournent à chaque tir), `burst` (gerbe aléatoire) et `wall` (anneau avec une brèche visée sur le joueur). Les clés communes sont la cadence, le délai initial, la vitesse, le type de balle, la couleur, les rafales, l'accélération et la courbure. Les ennemis ne tirent que dans les trois quarts haut de l'écran : rien ne tire à bout portant depuis le bas.

### Trajectoires

Les formations suivent des courbes nommées de `stage.json`. Les points de contrôle (en fractions de la zone de jeu) sont reliés par une spline de Catmull-Rom, échantillonnée en ligne brisée ; le vaisseau avance le long de sa longueur cumulée, donc à vitesse constante. Un événement peut inverser la courbe gauche-droite (`mirror`) ou lancer les deux côtés à la fois (`pair`).

### Sensations

- **Gel d'image** : l'action se fige quelques centièmes de seconde sur les grosses destructions et sur une vie perdue.
- **Ralenti** : le boss final explose à 35 % de la vitesse pendant 1,6 seconde.
- **Tremblement** : chaque impact ajoute du « trauma » entre 0 et 1 ; le décalage vaut trauma au carré x 12 pixels, les petits chocs restent discrets.
- **Lumière** : étincelles, éclairs et anneaux sont dessinés en mélange additif, les couleurs s'additionnent comme de la lumière.
- **Sons** : une vingtaine de bruitages synthétisés ; les gemmes ramassées à la suite montent en hauteur.

### Vérification

Un bot de test se place sous les ennemis et esquive les balles par répulsion, avec une connaissance parfaite de leur position : un joueur humain trouvera la partie plus difficile que lui.

| Difficulté | Parties | Résultat |
| :--- | :--- | :--- |
| Normal | 2 | Étape terminée les deux fois, en 6 min 1 s et 6 min 15 s, avec 0 et 1 vie perdue |
| Difficile | 3 | Étape terminée deux fois (1 et 2 vies perdues, 4 et 5 bombes), une partie perdue après 3 vies |

### Sauvegarde

Les meilleurs scores, la langue et le son sont écrits dans `user://aurore_save.json` (dans un navigateur, le stockage local du site). Après une mise à jour du jeu, un rechargement forcé de la page (Ctrl+F5) évite que le navigateur garde l'ancienne version en cache.

---

## Organisation des fichiers

| Dossier | Contenu |
| :--- | :--- |
| `autoloads/` | `ConfigManager`, `SaveManager`, `StringManager`, `Sfx` (bruitages), `GameState` (score, vies, bombes, chaîne) |
| `scripts/` | `Game` (zone de jeu, collisions, score, bombes, boss), `Stage` (chronologie), `Player`, `Enemy`, `Emitter` (motifs), `Bullets`, `Shots`, `Items`, `Effects`, `Popups`, `Background`, `Tex` (textures générées), `InputSetup` |
| `scenes/` | `Main.tscn` (un seul nœud) et `Main.gd`, qui construit l'arbre de scène ; `scenes/ui/` pour les panneaux, la barre de boss, les bandeaux et les écrans |
| `data/` | Réglages, ennemis, étape, textes |
