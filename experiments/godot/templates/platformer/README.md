# Brindille : plateformer de précision (Godot 4)

Brindille, un petit esprit de la forêt, traverse cinq contrées jusqu'à la cime du grand arbre. Vous courez, sautez, rebondissez contre les murs, faites un double saut et jouez avec des blocs de couleur qui s'échangent à chaque saut.

Le projet ne contient aucune image ni aucun son : tout est dessiné par le code (`_draw()`) et les bruitages sont synthétisés au lancement. Les réglages sont dans `data/config.json`, les niveaux dans `data/levels.json`, les textes en français et en anglais dans `data/strings_fr.json` et `data/strings_en.json`.

Testé avec Godot 4.4.1 (export web) et 4.7.

---

## Commandes

| Action | Clavier | Manette |
| :--- | :--- | :--- |
| Courir | Flèches gauche et droite, ou Q et D (A et D sur un clavier QWERTY) | Croix ou stick gauche |
| Sauter | Espace, flèche haut, Z (W en QWERTY) ou K | Bouton A |
| Traverser une planche vers le bas | Bas + Saut | Bas + A |
| Chute rapide | Bas en l'air | Bas |
| Revenir à la dernière lanterne | R | Select |
| Pause | Échap ou P | Start |

Les lettres sont lues par leur position physique sur le clavier : la touche placée à gauche de E sert à sauter, qu'elle porte Z (AZERTY) ou W (QWERTY).

---

## Déroulement d'une partie

L'écran titre propose **Jouer** (ou **Continuer (niveau n)** dès qu'un niveau est terminé), **Niveaux**, le son et la langue. Un niveau se débloque quand le précédent est terminé.

Dans chaque niveau :

- **Les lucioles** sont les petits objets lumineux. Le compteur en haut à droite affiche « 12 / 30 ».
- **Les glands d'or** sont trois par niveau, souvent hors du chemin principal. Un gland déjà trouvé lors d'une partie précédente apparaît translucide : vous pouvez le reprendre, la sauvegarde garde l'ensemble des glands trouvés.
- **Les lanternes** servent de point de reprise. Après une chute (épines, ennemi, vide), Brindille réapparaît à la dernière lanterne allumée, en 0,6 seconde. Les lucioles et les glands ramassés restent acquis.
- **Les panneaux** marqués d'un point d'interrogation affichent une bulle d'aide quand vous vous en approchez. Chaque nouveauté est expliquée au moment où elle apparaît.

À l'arche de sortie, l'écran de bilan donne le temps (avec le record ou la mention **Nouveau record**), les lucioles, les glands d'or et le nombre de chutes. Après le cinquième niveau, l'écran **Fin du voyage** récapitule les records de tous les niveaux.

---

## Les cinq niveaux

| Niveau | Taille (cases) | Ce qu'il introduit | Lucioles | Lanternes |
| :--- | :--- | :--- | :--- | :--- |
| 1. Prairie | 150 x 20 | Course, saut long ou court, scarabées, planches, double saut, ressort | 30 | 1 |
| 2. Sous-bois | 170 x 24 | Glissade et saut contre les murs, épines, guêpes | 26 | 3 |
| 3. Canyon | 180 x 24 | Blocs fissurés, plateformes mobiles, plantes cracheuses | 26 | 2 |
| 4. Grotte de cristal | 170 x 24 | Blocs ambre et bleus échangés à chaque saut, hérissons | 23 | 2 |
| 5. Cime du grand arbre | 100 x 44 | Ascension verticale qui mélange tout | 21 | 2 |

Une case mesure 40 pixels. L'écran en montre 32 de large et 18 de haut.

---

## Le déplacement

Toutes les valeurs ci-dessous viennent de `data/config.json`. Les hauteurs et distances ont été mesurées en rejouant la physique du jeu.

| Mouvement | Réglage | Résultat |
| :--- | :--- | :--- |
| Course | `run_speed` 300 px/s, `ground_accel` 2 600 | Vitesse maximale atteinte en 7 images (0,12 s) |
| Saut maintenu | `jump_velocity` 800 | 3,46 cases de haut, 5,5 cases de long en courant |
| Saut tapé | `jump_cut` 0,45 | 1,39 case de haut : relâcher la touche en montée multiplie la vitesse verticale par 0,45 |
| Double saut au sommet | `air_jump_velocity` 700 | 6,1 cases de haut, 8,75 cases de long |
| Ressort | `spring_velocity` 1 250 | 8,5 cases de haut |
| Glissade contre un mur | `wall_slide_speed` 150 px/s | Chute freinée tant que vous poussez vers le mur |
| Saut mural | `wall_jump_velocity_x` 330, `wall_jump_velocity_y` 760 | Repousse du mur et rend le double saut |

Six aides rendent les commandes tolérantes :

1. **Temps de grâce au bord** (`coyote_time` 0,1 s) : le saut reste possible un dixième de seconde après avoir quitté une plateforme.
2. **Saut mémorisé** (`jump_buffer_time` 0,12 s) : un appui un peu trop tôt avant l'atterrissage déclenche le saut à l'arrivée.
3. **Correction de coin** (`corner_correction` 12 px) : si la tête accroche l'angle d'un plafond de 12 pixels ou moins en montée, Brindille glisse sur le côté au lieu de s'arrêter.
4. **Suspension au sommet** (`apex_gravity_multiplier` 0,5) : près du sommet du saut, touche maintenue, la gravité est divisée par deux pour viser l'atterrissage.
5. **Chute plus lourde** (`fall_gravity_multiplier` 1,65) : la descente est plus rapide que la montée, la trajectoire paraît nette.
6. **Zones de contact indulgentes** : la zone qui blesse Brindille est réduite de 4 pixels de chaque côté, et un ennemi est écrasé si les pieds sont au plus 12 pixels sous son sommet.

---

## Ennemis et éléments du décor

| Élément | Comportement |
| :--- | :--- |
| Scarabée | Patrouille et fait demi-tour au bord du vide ou contre un mur. S'écrase en sautant dessus. |
| Hérisson | Comme le scarabée, mais pique aussi par le dessus : il faut l'éviter. |
| Guêpe | Vole en va-et-vient horizontal ou vertical sur deux cases. S'écrase et rend le double saut, ce qui permet d'enchaîner. |
| Plante cracheuse | Crache une graine toutes les 2,2 s quand Brindille est à moins de 13 cases. Elle gonfle juste avant de tirer. S'écrase par le dessus. |
| Planche | Se traverse par en dessous ; Bas + Saut pour redescendre. |
| Bloc fissuré | Tombe 0,45 s après qu'on s'est posé dessus, revient 2,5 s plus tard. |
| Plateforme mobile | Fait l'aller-retour en ralentissant aux extrémités et emporte Brindille. |
| Blocs ambre et bleus | À chaque saut (au sol, contre un mur ou en l'air), la couleur solide change. Les blocs solides sont pleins, les autres en pointillés : vous voyez toujours ce qui sera solide après le prochain saut. Un double saut échange deux fois. |

Un bloc qui devient solide alors que Brindille est dedans reste traversable jusqu'à ce qu'elle en sorte : un échange ne peut jamais la coincer.

---

## Principes techniques

### Collisions contre la grille, sans moteur physique

Brindille est une boîte de 24 x 32 pixels déplacée un axe après l'autre. `Level.sweep_x` et `Level.sweep_y` parcourent les colonnes (ou les lignes) de cases que le bord avant traverse pendant l'image et arrêtent la boîte à la première case solide. La boîte ne peut donc jamais traverser un mur, même très vite. Les planches et les plateformes mobiles n'arrêtent qu'une boîte qui descend et dont le bas était au-dessus de leur dessus.

Toute la simulation avance à 60 images par seconde dans un ordre fixe (plateformes mobiles, transport du joueur, joueur, ennemis, projectiles, contacts, caméra). Les mêmes appuis donnent toujours le même résultat, à l'image près.

L'appui sur Saut est détecté comme un changement d'état de la touche entre deux images (relâchée puis enfoncée). Cette méthode donne le même résultat au clavier, à la manette et avec des appuis simulés.

### Niveaux en texte

Chaque niveau de `data/levels.json` est dessiné en caractères, une chaîne par ligne et un caractère par case :

| Caractère | Signification | Caractère | Signification |
| :--- | :--- | :--- | :--- |
| `#` | Sol | `P` | Départ |
| `=` | Planche | `E` | Arche de sortie |
| `:` | Fond de grotte (décor) | `K` | Lanterne |
| `^` `v` `<` `>` | Épines (vers le haut, le bas, la gauche, la droite) | `o` | Luciole |
| `c` | Bloc fissuré | `G` | Gland d'or |
| `a` `b` | Bloc ambre, bloc bleu | `s` | Ressort |
| `w` `h` | Scarabée, hérisson | `1` à `9` | Panneau (texte `sign_<niveau>_<n>`) |
| `f` `F` | Guêpe horizontale, verticale | `t` `T` | Plante tournée vers la gauche, la droite |

Les plateformes mobiles sont décrites à part dans `movers` : position et largeur en cases, déplacement (`dx`, `dy`), période en secondes et décalage de phase. Le champ `theme` règle les couleurs du ciel, du sol et des trois couches de fond.

### Vérification des niveaux

Chaque niveau a été vérifié par un planificateur qui rejoue la même physique que le jeu (course, sauts, double saut, sauts muraux, planches, ressorts, blocs de couleur). Il confirme que la sortie, toutes les lanternes, tous les glands d'or et toutes les lucioles sont atteignables. Pour les niveaux 1, 2 et 4, l'itinéraire trouvé a été rejoué image par image dans Godot (ennemis retirés) et atteint bien la sortie, en 23 s, 29 s et 24 s. Les plateformes mobiles sont approchées par trois positions fixes dans le planificateur : les passages des niveaux 3 et 5 qui les utilisent ont été conçus avec de la marge plutôt que rejoués.

### Rendu et sensations

- **Étirement et écrasement** : Brindille s'allonge au saut et s'aplatit à l'atterrissage selon la vitesse d'impact, puis revient à sa forme par un ressort amorti.
- **Gel d'image** : l'action se fige 3 à 5 images quand vous écrasez un ennemi, trouvez un gland d'or ou chutez.
- **Caméra** : elle regarde jusqu'à 90 pixels devant vous selon la vitesse, et ne suit la hauteur qu'à l'atterrissage ou quand vous montez nettement au-dessus de votre dernier appui, ce qui évite que l'écran sautille à chaque saut. Elle suit vite une longue chute et tremble lors des chocs.
- **Particules** : poussière de course, d'atterrissage et de glissade, feuilles à la chute, étincelles aux objets ramassés.
- **Fond en parallaxe** : ciel en dégradé, soleil, nuages, étoiles ou lucioles d'ambiance, et trois couches de silhouettes (collines, montagnes, sapins, forêt, mesas, cristaux) qui défilent à des vitesses différentes.
- **Sons** : une vingtaine de bruitages synthétisés. Les lucioles ramassées à la suite montent d'un demi-ton à chaque prise.

### Sauvegarde

La progression est écrite dans `user://brindille_save.json` (dans un navigateur, le stockage local du site) : niveaux débloqués, meilleur temps, moins de chutes, plus de lucioles et glands trouvés par niveau, langue et son. Après une mise à jour du jeu, un rechargement forcé de la page (Ctrl+F5) évite que le navigateur garde l'ancienne version en cache.

---

## Organisation des fichiers

| Dossier | Contenu |
| :--- | :--- |
| `autoloads/` | `ConfigManager`, `SaveManager`, `StringManager`, `Sfx` (bruitages), `GameState` (partie en cours) |
| `scripts/` | `Level` (construction, collisions, contacts), `LevelData` (lecture des niveaux), `Player`, `PlayerArt`, `GameCamera`, `Background`, `TileChunk` (dessin du terrain), `Effects`, `InputSetup` |
| `scripts/enemies/` | `Enemy`, `Walker` (scarabée et hérisson), `Flyer`, `Spitter`, `Seed` |
| `scripts/objects/` | Lucioles, glands, ressorts, lanternes, arche, panneaux, plateformes mobiles, blocs fissurés, blocs de couleur |
| `scenes/` | `Main.tscn` (un seul nœud), `Main.gd` qui construit l'arbre de scène ; `scenes/ui/` pour l'interface, entièrement créée par le code |
| `data/` | Réglages, niveaux, textes |
