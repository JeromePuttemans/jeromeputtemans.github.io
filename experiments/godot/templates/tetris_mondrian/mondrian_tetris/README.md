# Composition : jeu de rectangles d'après Mondrian (Godot 4)

Des rectangles rouges, jaunes, bleus, blancs et noirs tombent sur une toile. On les range pour
compléter des lignes, comme dans tout jeu de blocs qui tombent, mais chaque partie peint aussi un
tableau dans le style de Piet Mondrian : des aplats de couleur séparés par d'épais traits noirs.
À la fin, la toile est accrochée au mur avec son cartel de musée, puis rangée dans une galerie.

Le projet ne contient aucune image ni aucun son : l'écran, les pièces et les tableaux sont dessinés
par le code, la musique et les bruitages sont synthétisés au lancement. Les réglages sont dans
`data/config.json`, les textes dans `data/strings_fr.json` et `data/strings_en.json`.

Testé avec Godot 4.4.1 (export web) et 4.7.

---

## Twist

**Deux pièces de même couleur qui forment ensemble un rectangle fusionnent en un seul aplat, et
une ligne qui traverse un aplat rapporte beaucoup plus.**

Le moment où le joueur le comprend : il pose un rectangle bleu de 2 sur 1 juste au-dessus d'un
autre rectangle bleu de même largeur. Le trait noir qui les séparait s'efface, le nouvel aplat de
2 sur 2 s'illumine, un arpège de piano monte et « Aplat 2 x 2 » s'affiche avec ses points. Quand
il complète ensuite une ligne qui passe à travers cet aplat, « Aplat traversé » ajoute 80 points
par niveau. Le joueur se met alors à construire de grands aplats avant de les effacer.

---

## Commandes

| Action | Clavier | Manette |
| :--- | :--- | :--- |
| Déplacer | Flèches gauche et droite, ou Q et D sur un clavier AZERTY (A et D en QWERTY) | Croix gauche et droite |
| Descendre plus vite | Flèche bas ou S | Croix bas |
| Tourner | Flèche haut, X, ou Z en AZERTY (W en QWERTY) | A |
| Lâcher d'un coup | Espace | Croix haut ou Y |
| Mettre en réserve | C ou Maj | Gâchettes hautes ou B |
| Pause | Échap ou P | Start |

Les menus se pilotent au clavier (flèches et Entrée), à la manette ou à la souris. Après une
partie : Entrée pour une nouvelle toile, G pour la galerie, Échap pour l'écran titre.

---

## Les règles

### Les pièces

Toutes les pièces sont des rectangles, comme les cases des toiles de Mondrian ; tourner une pièce
échange sa largeur et sa hauteur. Les tailles sortent d'un sac de dix, mélangé puis vidé avant
d'être rempli de nouveau : deux 2 x 1, deux 3 x 1, un 4 x 1, deux 2 x 2, un 3 x 2, un 3 x 3 et un
1 x 1. Le 1 x 1 est toujours noir, comme les petits carrés noirs des tableaux. Les couleurs des
autres sortent d'un sac de sept : rouge, jaune et bleu deux fois chacun, blanc une fois. Ainsi,
une taille ne peut jamais manquer plus de 18 pièces de suite.

La toile mesure 12 cases de large sur 20 de haut. Les trois pièces suivantes sont affichées, et
la réserve garde une pièce de côté (une seule fois par pièce tombée).

### La chute

| Réglage | Valeur |
| :--- | :--- |
| Chute d'une case | 0,8 s au niveau 1, puis 0,7, 0,6, 0,5, 0,42, 0,35, 0,28, 0,22, 0,17, 0,13, 0,1, 0,08, 0,065, 0,05 et 0,04 s à partir du niveau 15 |
| Descente rapide | 20 fois plus vite |
| Verrouillage | 0,5 s après avoir touché le sol ; déplacer ou tourner la pièce relance ce délai, 15 fois au plus |
| Déplacement continu | Une touche maintenue répète le déplacement toutes les 0,05 s après 0,17 s |

### Les aplats

Deux blocs de même couleur qui partagent un côté entier fusionnent : même largeur et posés l'un
sur l'autre, ou même hauteur et côte à côte. Le nouvel aplat peut fusionner à son tour avec un
voisin. Exemple : un 3 x 1 jaune posé sur un 3 x 2 jaune donne un aplat 3 x 3, qui fusionne avec
un 3 x 3 jaune voisin de même hauteur pour former un aplat 6 x 3. La vérification a lieu après
chaque pièce posée et après chaque ligne effacée, car les lignes qui se resserrent peuvent aligner
de nouvelles paires. Un bloc en L ne fusionne jamais, puisqu'il ne forme pas un rectangle.

### Les lignes grises

Toutes les 14 pièces posées, une ligne grise percée d'un trou monte du bas et pousse toute la pile
d'une case vers le haut. La cadence augmente d'une pièce tous les deux niveaux : 14 pièces aux
niveaux 1 et 2, 13 aux niveaux 3 et 4, et ainsi de suite jusqu'à 7 pièces à partir du niveau 15.
Deux fois sur trois, le trou se place au-dessus du précédent : les trous forment un puits, qu'une
pièce 4 x 1 debout efface d'un coup. Le bandeau sous la toile se remplit d'un segment noir à
chaque pièce posée ; son dernier segment clignote en rouge juste avant la montée.

Sans cette pression, une partie de rectangles pourrait durer indéfiniment : avant que ces lignes
grises existent, un bot qui joue sans erreur dépassait 600 lignes sans perdre. Les lignes grises ne
fusionnent jamais, puisque le joueur ne les a pas peintes.

### Le score

Tous les gains sont multipliés par le niveau.

| Événement | Points |
| :--- | :--- |
| Descente rapide | 1 par case |
| Lâcher d'un coup | 2 par case parcourue |
| Fusion | 5 par case du nouvel aplat |
| Lignes | 100 pour une, 300 pour deux, 500 pour trois, 800 pour quatre |
| Épure | Une ligne effacée qui ne compte que deux couleurs au plus double sa part des points de lignes |
| Aplat traversé | 20 par case de chaque aplat d'au moins 4 cases touché par les lignes effacées |
| Boogie | 50 x le nombre de pièces d'affilée qui effacent des lignes, à partir de la deuxième |
| Toile blanche | 2 000 quand la toile est entièrement vide après un effacement |

Exemple au niveau 3 : deux lignes effacées (300 x 3 = 900), dont une ne compte que du gris et du
bleu (Épure : la moitié des 900, soit 450), à travers un aplat rouge de 2 x 3, soit 6 cases
(6 x 20 x 3 = 360). La pièce rapporte 1 710 points, plus le Boogie si la pièce précédente avait
aussi effacé une ligne.

Le niveau augmente toutes les 10 lignes. La partie s'arrête quand une nouvelle pièce ne peut plus
apparaître, ou quand une ligne grise pousse une case hors du haut de la toile.

### La fin et la galerie

La toile finale est accrochée sur un mur sombre, dans un cadre noir et un passe-partout blanc, à
côté d'un cartel : « Composition n° 12 », ses couleurs rangées par surface (« en jaune, bleu et
rouge »), ses dimensions, puis le score, les lignes, le niveau et le nombre d'aplats créés. La
galerie garde les huit dernières toiles.

---

## L'écran

L'écran entier est une composition : des panneaux séparés par d'épais traits noirs.

| Panneau | Contenu |
| :--- | :--- |
| Blanc, en haut à gauche | Réserve |
| Jaune | Score qui défile jusqu'à sa valeur, record |
| Rouge | Niveau, avec dix cases qui se remplissent ligne après ligne jusqu'au niveau suivant |
| Bleu | Lignes effacées |
| Blanc, en haut à droite | Les trois pièces suivantes |
| Blanc, à droite | Les derniers événements et leurs points ; au début de la partie, les commandes |
| Bandeau sous la toile | Compte à rebours de la prochaine ligne grise |
| Panneau en bas à droite et bandeau au-dessus de la toile | Des voies jaunes où de petits carrés rouges, bleus et gris avancent à chaque temps de la musique, d'après *Broadway Boogie Woogie* |
| Les autres panneaux | Des aplats décoratifs, repeints un à un à chaque nouveau niveau |

---

## Ce que mesure le bot de test

Un bot évalue chaque position possible de la pièce (hauteur de la pile, trous, relief, lignes,
fusions) et joue avec les vraies règles et la vraie gravité, une action toutes les 0,12 à 0,15 s.

| Bot | Parties | Durée | Niveau atteint | Lignes |
| :--- | :---: | :--- | :--- | :--- |
| Se trompe une fois sur cinq (choisit l'un des trois coups suivants) | 8 | De 3 min 08 à 6 min 31 | De 9 à 21, 14,5 en médiane | De 86 à 207 |
| Ne se trompe jamais | 3 | De 9 min 28 à 11 min 08 | De 40 à 49 | De 396 à 482 |

Dans ces parties, le bot qui se trompe crée de 53 à 90 aplats et obtient l'Épure de 12 à 51 fois.
Un joueur humain, plus lent à décider, s'arrêtera en général plus tôt.

---

## Principes techniques

### Les règles (`Board.gd`)

La grille compte 12 colonnes et 23 lignes, dont 3 cachées au-dessus de la toile. Chaque case garde
une couleur et le numéro du bloc auquel elle appartient. Un bloc est toujours un rectangle : une
pièce posée, ou un aplat issu de plusieurs. Quand des lignes disparaissent, les parties restantes
d'un bloc se resserrent et forment encore un rectangle. `Board.gd` ne dessine rien : il émet des
signaux (pièce posée, fusion, lignes effacées, ligne grise, niveau, fin) que le reste du jeu
traduit en images et en sons. Le bot de test s'en sert directement.

### L'affichage (`Frame.gd`, `BoardView.gd`, `Painting.gd`)

Chaque bloc est dessiné comme un aplat entouré d'un trait noir de 6 pixels, si bien que la toile
ressemble à tout moment à un Mondrian en cours. `Painting.gd` dessine une toile terminée à partir
de la liste de ses rectangles, pour l'écran de fin et la galerie. L'écran titre compose un nouveau
tableau toutes les dix secondes en coupant l'écran en deux, encore et encore, entre 30 et 70 %
de la longueur.

### La musique (`Sfx.gd`)

Mondrian aimait le boogie-woogie. Une basse joue un blues de 12 mesures en do (I I I I IV IV I I V
IV I V), huit croches balancées par mesure (longue puis courte, dans un rapport de 2 pour 1), sur
le motif boogie 0 4 7 9 10 9 7 4 demi-tons à partir de la fondamentale de la mesure. Le tempo
vaut 112 battements par minute au niveau 1, gagne 6 par niveau jusqu'à 172, et descend à 94 sur
l'écran titre. Chaque ligne effacée joue au piano l'accord de septième de la mesure en cours, avec
une note de plus par ligne : effacer des lignes revient à jouer avec l'orchestre.

Le piano et la basse sont deux notes synthétisées une fois (quatre harmoniques qui s'éteignent de
plus en plus vite) ; toutes les autres notes sont ces échantillons transposés.

### Sensations

| Moment | Effets |
| :--- | :--- |
| Chute | La pièce glisse d'une case à l'autre au lieu de sauter |
| Rotation | La pièce enfle brièvement, double clic boisé |
| Pose | La pièce s'écrase un instant, petits carrés de sa couleur |
| Lâcher d'un coup | Traînée de couleur, secousse proportionnelle à la hauteur de chute, la toile s'enfonce et rebondit |
| Fusion | Le trait noir s'efface, l'aplat s'illumine, arpège, gerbe de carrés, points flottants |
| Lignes | Chaque ligne s'illumine et se referme, les lignes du dessus descendent en glissant, ses cases s'envolent en carrés de couleur, accord de piano, secousse à partir de trois lignes |
| Ligne grise | Toute la pile remonte en glissant, grondement sourd |
| Danger | Le haut de la toile rougit et pulse quand la pile en approche |
| Nouveau niveau | Les panneaux décoratifs se repeignent un à un, le tempo accélère |

### Sauvegarde

`user://composition_save.json` garde le record, le nombre de parties terminées (qui numérote les
compositions), la galerie des huit dernières toiles et les réglages (langue, son, musique).

---

## Organisation des fichiers

| Dossier | Contenu |
| :--- | :--- |
| `autoloads/` | `ConfigManager` (réglages), `SaveManager` (record, galerie, réglages), `StringManager` (textes), `Sfx` (sons, piano, musique) |
| `data/` | `config.json`, `strings_fr.json`, `strings_en.json` |
| `scenes/` | `Main.tscn` et `Main.gd` (écrans et enchaînement) |
| `scenes/ui/` | `UiTheme`, `TitleScreen`, `PauseMenu`, `EndScreen`, `Gallery` |
| `scripts/` | `Pieces` (formes, couleurs, sacs), `Board` (règles), `Game` (commandes et réactions), `BoardView` (toile animée), `Frame` (composition de l'écran), `Effects2D` (carrés et points), `Painting` (tableaux) |

---

## Réglages

| Clé de `config.json` | Valeur | Effet |
| :--- | :---: | :--- |
| `cols`, `rows`, `hidden_rows`, `cell` | 12, 20, 3, 32 | Taille de la toile, lignes cachées au-dessus, taille d'une case en pixels |
| `gravity` | 0,8 à 0,04 | Temps de chute d'une case pour chaque niveau |
| `lines_per_level` | 10 | Lignes à effacer pour passer un niveau |
| `soft_drop_factor` | 20 | Accélération de la descente rapide |
| `lock_delay`, `lock_resets` | 0,5, 15 | Délai avant verrouillage, relances permises |
| `das`, `arr` | 0,17, 0,05 | Délai avant répétition du déplacement, intervalle de répétition |
| `next_count` | 3 | Pièces suivantes affichées |
| `rise_start`, `rise_min` | 14, 7 | Pièces entre deux lignes grises au départ, et au plus vite |
| `score_lines` | 0, 100, 300, 500, 800 | Points de base par nombre de lignes |
| `score_soft_drop`, `score_hard_drop` | 1, 2 | Points par case de descente |
| `score_fusion_per_cell` | 5 | Points par case d'un nouvel aplat |
| `score_aplat_per_cell`, `aplat_min_area` | 20, 4 | Points par case d'aplat traversé, taille minimale de l'aplat |
| `sober_multiplier` | 2 | Multiplicateur de l'Épure |
| `score_combo`, `score_perfect` | 50, 2 000 | Boogie par pièce d'affilée, Toile blanche |
| `music_bpm`, `music_bpm_per_level`, `music_bpm_max` | 112, 6, 172 | Tempo de la musique |

---

## Lancement

1. Ouvrir le dossier `mondrian_tetris` dans Godot 4.4 ou plus récent.
2. Lancer la scène principale (`F5`) : elle est déjà réglée sur `scenes/Main.tscn`.
3. Pour la version web, utiliser le préréglage d'export **Web** : il écrit dans
   `experiments/godot/builds/tetris_mondrian/`.
