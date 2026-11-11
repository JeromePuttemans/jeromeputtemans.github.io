# Gnomon : exploration à la première personne (Godot 4)

Vous explorez un archipel d'îles suspendues au-dessus d'une mer de nuages. Vous tenez la course du
soleil dans votre main, et l'ombre des pierres noires est solide : on marche dessus. Pour passer
d'une île à l'autre, il faut trouver l'heure où une ombre forme le chemin.

Un gnomon est la tige d'un cadran solaire, celle dont l'ombre marque l'heure. Le jeu en a fait son
titre et son but : rapporter trois sceaux au grand gnomon du Cadran pour qu'il se relève.

Le projet ne contient aucune image ni aucun son : îles, pierres, ciel et ombres sont produits par
le code et par des shaders, les bruitages sont synthétisés au lancement. Les réglages sont dans
`data/config.json`, l'archipel dans `data/world.json`, les textes dans `data/strings_fr.json` et
`data/strings_en.json`.

Testé avec Godot 4.4.1 (export web) et 4.7.

---

## Twist

**Les ombres des pierres noires sont solides, et c'est vous qui déplacez le soleil.**

Le moment où le joueur le comprend : sur la première île, à midi, l'ombre du mur noir n'est qu'une
flaque à ses pieds. Une astuce lui dit de maintenir une touche pour faire reculer le soleil. Le
ciel rosit, le soleil descend vers l'est, et l'ombre du mur s'étire vers l'ouest au-dessus du vide
jusqu'à toucher l'île suivante. Il pose le pied sur cette ombre : elle le porte.

---

## Commandes

| Action | Clavier | Manette |
| :--- | :--- | :--- |
| Se déplacer | Z Q S D sur un clavier AZERTY (W A S D en QWERTY), ou les flèches | Stick gauche |
| Regarder | Souris | Stick droit |
| Sauter | Espace | A |
| Courir | Maj, maintenue | Clic du stick gauche ou B |
| Faire reculer le soleil | A en AZERTY (Q en QWERTY), maintenue, ou molette vers le bas | Gâchette haute ou gâchette gauche |
| Faire avancer le soleil | E, maintenue, ou molette vers le haut | Gâchette haute ou gâchette droite |
| Pause et réglages | Échap ou P | Start |

Les touches de lettres sont lues par leur position sur le clavier : elles tombent sous les mêmes
doigts sur un clavier AZERTY ou QWERTY. L'écran titre affiche les lettres de votre clavier ; dans
le navigateur, qui ne donne pas la disposition du clavier, il affiche les lettres AZERTY quand le
jeu est en français et les lettres QWERTY en anglais.

Dans le navigateur, un clic sur l'écran titre lance la partie et capture la souris. La touche
Échap libère la souris et ouvre la pause ; « Reprendre » la capture de nouveau.

---

## Les règles

### Le soleil

- L'heure va de **7 h** à **17 h**. Le soleil se lève à l'est, culmine au sud à 65 degrés
  au-dessus de l'horizon, et se couche à l'ouest.
- Une touche maintenue fait tourner l'heure de plus en plus vite : 0,6 heure par seconde au départ,
  2,2 heures par seconde au bout de 0,9 seconde. Une pression brève déplace donc l'heure de
  quelques minutes, une pression longue balaie la journée en 5 secondes. Un cran de molette déplace
  l'heure d'un quart d'heure. Un tic d'horloge sonne à chaque quart d'heure.
- Le cadran en haut de l'écran et l'astrolabe tenu en main montrent l'heure : 7 h à gauche, midi en
  haut, 17 h à droite.

### Les ombres

- Seules les **pierres noires**, reconnaissables à leurs lignes dorées, portent une ombre. Les
  colonnes et murets de marbre blanc n'en portent pas.
- Une ombre s'étend sur le plan horizontal qui passe par le pied de sa pierre, et elle est
  **solide**. Elle part du pied de la pierre et s'éloigne du soleil : vers l'ouest le matin, vers le
  nord à midi, vers l'est le soir. Elle est longue quand le soleil est bas. Exemple : le mur du
  Seuil mesure 5,5 m de haut. Son ombre fait 2,6 m à midi et 23 m à 7 h.
- Une ombre a une épaisseur de 12 cm. Une ombre qui flotte à 2 m au-dessus d'un sol laisse donc
  passer le joueur (1,75 m) en dessous, et on peut sauter dessus depuis une marche.
- Quand le soleil bouge, une ombre sur laquelle vous vous tenez vous **emporte** avec elle. Sur une
  île, en revanche, le sol ne bouge pas, même si une ombre le recouvre.
- **Sous un nuage, aucune ombre ne tient.** Deux nuages balaient le pont de l'aube : là où passe leur
  ombre, la passerelle se creuse d'un trou bordé de lumière, et vous tombez si vous y êtes.

### Le vide, les éclats, les sceaux

- Tomber dans le vide ramène sur la dernière île visitée, avec l'heure du moment. Les chutes sont
  comptées.
- **20 éclats de soleil** flottent dans l'archipel. Un éclat vient vers vous dès que vous passez à
  moins de 2,6 m. Trois d'entre eux ne se trouvent que sous une ombre d'une heure précise ; les
  autres sont sur les chemins.
- **Trois sceaux** attendent au bout des trois branches de l'archipel : l'aube, le zénith et le
  crépuscule. Prendre un sceau fait apparaître une colonne de lumière qui ramène au Cadran, où le
  sceau se pose de lui-même sur son socle.
- Quand les trois sceaux sont posés, le grand gnomon passe de 2 à 28 m de haut en 7 secondes. Son
  ombre de midi mène à l'Observatoire, où la partie se termine : le soleil se couche, les étoiles
  apparaissent, puis le bilan s'affiche (temps, éclats, chutes, record).

### Le corps

| Réglage | Valeur | Effet |
| :--- | :--- | :--- |
| Vitesse | 5 m/s en marchant, 7,5 m/s en courant | Accélération franche au sol, contrôle réduit en l'air |
| Saut | 1,4 m de haut | Environ 3,5 m de long en marchant et 5 m en courant |
| Tolérances | 0,12 s | Un saut reste possible 0,12 s après avoir quitté un bord, et une pression faite 0,12 s avant d'atterrir est retenue |
| Saut court | | Relâcher Espace tôt raccourcit le saut |

---

## L'archipel

| Île | Hauteur | Rôle |
| :--- | :---: | :--- |
| Le Seuil | 0 m | Départ. Le mur noir y mène au Cadran le matin et à la Marche le soir |
| Le Cadran | 0 m | Île centrale : le grand gnomon, les trois socles, un petit cadran solaire au sol |
| La Dalle, Le Répit, Le Cap de l'aube | 0 m | Branche de l'aube, à l'ouest |
| La Marche, La Tour du soir | 0 m, puis 2 m | Branche du crépuscule, à l'est |
| Le Gué, Le Belvédère, Le Zénith | 0,6 m, 1,2 m, 1,2 m | Branche du zénith, au nord-est |
| L'Observatoire | 0 m | Fin de la partie, au nord du Cadran |

Le petit cadran solaire au sol du Cadran sert de leçon : ses lignes dorées, numérotées de VII à
XVII, montrent où tombe l'ombre de son aiguille à chaque heure.

### Les passages (solution)

Chaque passage n'existe qu'à certaines heures. Les plages ci-dessous ont été calculées sur la
géométrie du niveau, puis vérifiées par le bot de test, qui joue avec les vraies commandes.

| Passage | Pierre | Heures | Ce qu'il faut faire |
| :--- | :--- | :--- | :--- |
| Seuil vers Cadran | Mur du Seuil | 7 h 00 à 7 h 15 | Faire reculer le soleil jusqu'à la butée de 7 h, contourner le mur, suivre son ombre vers l'ouest |
| Cadran vers Dalle | Obélisque du Cadran | 7 h 00 à 7 h 30 | Même geste, depuis l'ouest du Cadran |
| Dalle vers Répit, puis Cap de l'aube | Dalle (10 m) | Répit jusqu'à 8 h 12, Cap de 7 h 00 à 7 h 12 | Le pont le plus long : plus de 30 m au-dessus du vide. Attendre qu'un nuage s'éloigne avant de courir, souffler sur le Répit, recommencer pour le second nuage |
| Seuil vers Marche | Mur du Seuil | 16 h 36 à 17 h 00 | Pousser le soleil jusqu'à la butée de 17 h, partir vers l'est |
| Marche vers Tour du soir | Tour du soir | De 8 h 15 à 9 h 10 environ | L'ombre de la tour flotte à 2 m au-dessus de la Marche. Monter sur la marche de pierre (0,9 m), puis sauter sur l'ombre et la suivre jusqu'à la tour |
| Cadran vers Gué, puis Belvédère | Aucune | Toute heure | Deux sauts : 0,6 m, puis 0,6 m de plus |
| Belvédère vers Zénith | Monolithe suspendu | Embarquer de 7 h 15 à 8 h 33, débarquer de 15 h 18 à 16 h 48 | Le monolithe flotte : son ombre est une plateforme isolée qui glisse d'ouest en est quand l'heure avance. Monter dessus, faire avancer l'heure sans bouger, descendre sur le Zénith |
| Cadran vers Observatoire | Grand gnomon levé | 11 h 27 à 12 h 33 | Se placer à midi, contourner le gnomon par l'est, suivre son ombre vers le nord |

Les trois éclats qui demandent une heure précise : à l'ouest du Cadran au-dessus du vide (ombre de
l'obélisque, de 7 h 33 à 9 h 42), au nord-ouest de la Dalle (ombre de la dalle, de 8 h 06 à
9 h 39), à l'est de la Tour du soir (ombre de la tour, de 15 h 54 à 16 h 48). Deux autres flottent
sur le trajet du monolithe et se ramassent pendant la traversée.

### Ce que mesure le bot de test

Le bot de test suit la solution ci-dessus avec les vraies commandes (déplacement, course, saut,
touches du soleil) et la vraie physique, à 60 images par seconde. Il termine la partie en
1 min 36 s de jeu, sans chute, avec 17 éclats sur 20 : il laisse les trois éclats qui demandent une
heure précise. Ce temps est celui d'un joueur qui connaît déjà chaque passage ; la découverte prend
bien plus longtemps.

---

## Principes techniques

### Les ombres (`ShadowSystem.gd`)

Une pierre noire est une boîte (largeur, hauteur, profondeur, rotation autour de la verticale). Ses
huit coins sont projetés sur le plan de son pied le long des rayons du soleil :
`p = c - dir × (c.y - plan) / dir.y`, où `dir` pointe vers le soleil. L'ombre est l'enveloppe
convexe de ces points. Pour une pierre posée, elle part de son pied ; pour le monolithe, qui flotte
à 6 m, c'est une plaque séparée qui voyage avec le soleil.

Chaque ombre a un maillage de remplissage juste au-dessus du plan, un liseré doré, de petites faces
latérales pour qu'on la voie comme une dalle depuis le dessous, et un corps statique sur la couche
de collision 2, de forme `ConvexPolygonShape3D`, dont le dessus affleure le plan. Tout est
reconstruit quand le soleil bouge ou qu'une pierre change de hauteur.

Le transport sur une ombre : le rayon qui part des pieds vers l'ancien soleil touche la pierre en
un point q ; les pieds vont à la projection de q selon le nouveau soleil. Un joueur debout au milieu
de l'ombre du monolithe glisse ainsi d'une vingtaine de mètres pendant que l'heure passe de 8 h à
16 h.

Les nuages : le shader des ombres découpe un disque de 5,5 m sous chaque nuage, et le joueur ignore
la couche 2 tant que ses pieds sont dans ce disque.

### Le soleil (`Sun.gd`)

Avec t = (heure - 6) / 12 × π et φ = 65 degrés, la direction du soleil vaut
(cos t, sin t sin φ, sin t cos φ). La couleur et l'intensité de la lumière, le ciel, le brouillard,
la lumière ambiante et la mer de nuages suivent la hauteur du soleil : blanc bleuté à midi, or et
rose le matin, orange et pourpre le soir. Le moteur ne calcule aucune ombre : seules celles des
pierres noires existent, dessinées par `ShadowSystem.gd`.

### Le corps et la caméra (`Player.gd`, `CameraRig.gd`)

Le corps est un `CharacterBody3D` en capsule. La caméra est un nœud à part, hors de l'interpolation
physique : elle suit la position interpolée du corps à chaque image affichée et tourne tout de suite
avec la souris, sans latence quel que soit l'écran. L'affaissement à l'atterrissage est un ressort
calculé par petits pas fixes : calculé d'un seul pas, il divergeait sous 10 images par seconde et
envoyait la caméra hors du monde, ce que le test dans le navigateur a révélé.

### Sensations

| Moment | Effets |
| :--- | :--- |
| Marche | Balancement de la tête calé sur les pas, pas sonores différents sur l'herbe, la pierre et l'ombre (une note creuse et vitrée) |
| Course | Champ de vision élargi de 74 à 80 degrés |
| Saut et atterrissage | Petit élan de la caméra au saut, affaissement à ressort à l'atterrissage, proportionnel à la vitesse de chute, poussière après une grande chute |
| Pas de côté | Légère inclinaison de la caméra |
| Heure qui tourne | Astrolabe levé et perle solaire plus brillante, liserés des ombres plus vifs au démarrage, tic à chaque quart d'heure |
| Éclat | Note de cloche, plus aiguë à chaque éclat ramassé dans les 3 secondes, gerbe dorée |
| Sceau | Arpège, gerbe colorée, secousse ; au socle, un gong grave |
| Grand gnomon | Grondement de pierre chaque seconde, poussière, secousse continue pendant 7 secondes |
| Chute | Sifflement, vent qui forcit, fondu blanc, retour sur la dernière île |
| Ambiance | Vent continu en boucle, cloche lointaine toutes les 9 à 16 secondes |

### Rendu

Tout est construit par le code. Les îles sont des disques d'herbe posés sur des cônes de roche aux
bords déchiquetés, générés avec `SurfaceTool`. Les shaders donnent le ciel (dégradé, disque solaire,
nuages, étoiles), l'herbe, la roche en strates, le basalte des pierres noires avec ses lignes dorées
lumineuses, le verre indigo des ombres et la mer de nuages. Des îles lointaines, le brouillard et
le bloom donnent la profondeur.

### Sauvegarde

`user://gnomon_save.json` garde la partie en cours (éclats, sceaux, gnomon levé, chutes, temps,
dernière île visitée, heure, astuces déjà vues), la meilleure partie terminée et les réglages
(langue, son, sensibilité de la souris, axe vertical inversé). La partie est enregistrée à chaque
nouvelle île, chaque éclat, chaque sceau et à la pause.

---

## Organisation des fichiers

| Dossier | Contenu |
| :--- | :--- |
| `autoloads/` | `ConfigManager` (réglages), `SaveManager` (sauvegarde), `StringManager` (textes), `Sfx` (sons synthétisés, vent), `GameState` (partie en cours) |
| `data/` | `config.json`, `world.json` (îles, pierres, marches, décor, éclats, sceaux, socles, observatoire, nuages), `strings_fr.json`, `strings_en.json` |
| `scenes/` | `Main.tscn` et `Main.gd` (construction de la scène et phases de jeu) |
| `scenes/ui/` | `UiTheme`, `Hud`, `TitleScreen`, `PauseMenu`, `EndScreen`, `Fade` |
| `scripts/` | `Sun`, `ShadowSystem`, `World`, `Player`, `CameraRig`, `Effects3D`, `InputSetup` |
| `shaders/` | `sky`, `grass`, `rock`, `basalt`, `shadow`, `sea`, `beam` et `noise.gdshaderinc` |

### Modifier l'archipel

Une île de `world.json` donne son centre (`x`, `z`), sa hauteur `y`, son rayon `r`, la profondeur
de sa roche, son point de réapparition `spawn` et l'astuce montrée à la première visite. Une pierre
noire donne son île (ou `base_y` et `lift` pour une pierre qui flotte), sa position, ses
dimensions `w`, `h`, `d` et sa rotation `yaw` en degrés. Un passage existe quand l'ombre d'une
pierre touche une autre île de même hauteur : déplacer une pierre d'un mètre peut ouvrir ou fermer
un passage, ou en décaler l'heure. Une pierre posée au ras du bord de son île laisse un angle vide
entre l'île et son ombre ; reculez-la d'un mètre vers l'intérieur.

---

## Lancement

1. Ouvrez le dossier `first_person_explore` dans Godot 4.4 ou plus récent.
2. Lancez la scène principale (`F5`) : elle est déjà réglée sur `scenes/Main.tscn`.
3. Pour la version web, utilisez le préréglage d'export **Web** : il écrit dans le dossier `web`
   du projet, vers lequel pointe la page html.
