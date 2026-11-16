# Gnomon : exploration à la première personne (Godot 4)

Vous parcourez un archipel d'architecture blanche suspendu au-dessus de la brume : dalles de béton,
garde-corps vitrés, pilotis qui disparaissent dans le vide. Vous tenez la course du soleil dans
votre main, et l'ombre des pierres noires est solide : on marche dessus. Pour passer d'une
plateforme à l'autre, il faut trouver l'heure où une ombre forme le chemin, puis s'y lancer.

Un gnomon est la tige d'un cadran solaire, celle dont l'ombre marque l'heure. Le jeu en a fait son
titre et son but : rapporter trois sceaux au grand gnomon du Cadran pour qu'il se relève.

Le projet ne contient aucune image ni aucun son : plateformes, pierres, ciel et ombres sont produits
par le code et par des shaders, les bruitages et la musique sont synthétisés au lancement. Les
réglages sont dans `data/config.json`, l'archipel dans `data/world.json`, les textes dans
`data/strings_fr.json` et `data/strings_en.json`.

Testé avec Godot 4.4.1 (export web) et 4.7.

---

## Twist

**Les ombres des pierres noires sont solides, et c'est vous qui déplacez le soleil.**

Le moment où le joueur le comprend : sur la première plateforme, à midi, l'ombre du mur noir n'est
qu'une flaque à ses pieds. Une astuce lui dit de maintenir une touche pour faire reculer le soleil.
La lumière se réchauffe, le soleil descend vers l'est, et l'ombre du mur s'étire vers l'ouest
au-dessus du vide jusqu'à toucher le Cadran. Il pose le pied sur cette bande sombre hachurée : elle
le porte.

---

## Direction artistique

Le monde reprend les codes d'une maquette d'architecte contemporaine.

| Élément | Traitement |
| :--- | :--- |
| Plateformes | Dalles de béton blanc de 0,80 m d'épaisseur : disques, rectangles percés de trémies (le Cadran), anneau autour d'un puits (l'Oculus). Joints de coffrage tous les 2,40 × 1,20 m et trous de banches, qui s'effacent avec la distance |
| Pierres noires | Seuls volumes sombres du monde, en graphite mat. On les reconnaît sans repère supplémentaire |
| Ombres solides | Bandes graphite hachurées comme une ombre portée sur un plan, bordées d'un liseré clair qui passe à la couleur d'accent quand l'heure tourne |
| Architecture blanche | Garde-corps en verre sans montants, murs, bancs, portiques, pilotis élancés, tour de l'Oculus qui plonge dans la brume. Le blanc ne porte aucune ombre : c'est la règle du monde |
| Silhouettes | Figures grises immobiles, pour donner l'échelle comme dans une maquette |
| Lumière | Presque sans couleur : blanc à midi, à peine chaude à l'aube et au crépuscule. Dessus des volumes blancs, côtés gris, sous-faces plus sombres |
| Couleur d'accent | Un seul orange, réservé à ce qui se ramasse (éclats, sceaux), aux repères (colonnes de lumière) et à ce qui demande attention (bord d'un nuage qui troue une ombre) |
| Interface | Encre graphite sur papier blanc, angles droits, titres en capitales espacées, cotes de niveau comme sur une coupe (« niv. +4,00 ») |

---

## Commandes

| Action | Clavier et souris | Manette |
| :--- | :--- | :--- |
| Se déplacer | Z Q S D sur un clavier AZERTY (W A S D en QWERTY), ou les flèches | Stick gauche |
| Regarder | Souris | Stick droit |
| Sauter | Espace | A |
| Élan, puis course tant que la touche reste enfoncée | Maj ou clic droit | B, X ou clic du stick gauche |
| Faire reculer le soleil | A en AZERTY (Q en QWERTY), maintenue, ou molette vers le bas | Gâchette haute ou gâchette gauche |
| Faire avancer le soleil | E, maintenue, ou molette vers le haut | Gâchette haute ou gâchette droite |
| Revenir sur la dernière plateforme | R | Y |
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

- L'heure va de **7 h** à **17 h** et commence à midi. Le soleil se lève à l'est, culmine au sud à
  65 degrés au-dessus de l'horizon, et se couche à l'ouest.
- Une touche maintenue fait tourner l'heure de plus en plus vite : 0,7 heure par seconde au départ,
  2,8 heures par seconde au bout de 0,7 seconde. Une pression brève déplace l'heure de quelques
  minutes, une pression longue balaie la journée en moins de 4 secondes. Un cran de molette déplace
  l'heure d'un quart d'heure. Un tic d'horloge sonne à chaque quart d'heure.
- L'arc en haut de l'écran et le cadran de poche tenu en main montrent l'heure : 7 h à gauche, midi
  en haut, 17 h à droite.

### Les ombres

- Seules les **pierres noires** portent une ombre. Tout ce qui est blanc n'en porte aucune.
- Une ombre s'étend sur le plan horizontal qui passe par le pied de sa pierre, et elle est
  **solide**. Elle part du pied de la pierre et s'éloigne du soleil : vers l'ouest le matin, vers le
  nord à midi, vers l'est le soir. Elle est longue quand le soleil est bas. Exemple : le mur du
  Seuil mesure 7 m de haut. Son ombre fait 3,3 m à midi et 29 m à 7 h.
- Une ombre a une épaisseur de 12 cm. Une ombre qui flotte à 4 m au-dessus d'un sol laisse donc
  passer le joueur (1,75 m) en dessous.
- Une ombre qui bouge (parce que l'heure tourne ou parce que sa pierre se déplace) **emporte** le
  joueur qui se tient dessus au-dessus du vide. Sur une plateforme, en revanche, le sol ne bouge
  pas, même si une ombre le recouvre : pour embarquer sur une ombre mobile, il faut y faire un pas
  au moment où elle quitte le bord.
- **Sous un nuage, aucune ombre ne tient.** Deux nuages balaient le pont de l'aube : là où passe
  leur ombre, la passerelle se creuse d'un trou bordé d'orange, et vous tombez si vous y êtes.

### Les pierres cinétiques

Deux pierres noires bougent d'elles-mêmes. L'heure ne les met pas en mouvement, mais elle décide
où tombe leur ombre.

| Pierre | Mouvement | Ce que fait son ombre |
| :--- | :--- | :--- |
| La flèche, sur la Tour du soir | Une poutre noire de 24 m portée par un mât blanc, 7 m au-dessus de la plateforme, qui fait un tour en 15 secondes | Une barre qui balaie un cercle au-dessus du vide comme une aiguille. Le centre du cercle est l'ombre du sommet du mât : il glisse vers l'est quand l'heure avance |
| Le bac, au-dessus du Belvédère | Un bloc noir suspendu à un rail blanc, 6 m au-dessus du plan du Belvédère. Il parcourt 27 m vers l'est, se repose 1,5 seconde, revient : 18 secondes l'aller-retour | Un radeau qui traverse le vide tout seul. Le trajet du radeau se décale vers l'ouest le matin et vers l'est l'après-midi |

### Le corps

| Réglage | Valeur | Effet |
| :--- | :--- | :--- |
| Vitesse | 6,5 m/s en marchant, 8,5 m/s en courant | La course s'obtient en gardant enfoncée la touche d'élan |
| Saut | 1,38 m de haut | Relâcher Espace tôt raccourcit le saut. Un saut reste possible 0,1 s après avoir quitté un bord, et une pression faite 0,12 s avant d'atterrir est retenue |
| Élan | 16 m/s pendant 0,14 s, à plat, au sol comme en l'air | La chute s'interrompt pendant l'élan. Une seule charge, rendue au contact du sol (0,25 s après l'élan précédent) ou par un éclat de soleil, même en plein vol |
| Prise de rebord | Un rebord situé entre 0,30 m et 1,10 m au-dessus des pieds | Sauter vers un rebord en avançant suffit : le corps s'y hisse en 0,22 s. Le bord d'une ombre suspendue se prend aussi. Les garde-corps, les silhouettes, les murs et les portiques ne se prennent pas |
| Lancer | Jusqu'à 12 m/s | Sauter d'une ombre qui bouge, ou en descendre, garde sa vitesse. En l'air, une vitesse supérieure à la course n'est pas freinée par la direction : elle s'use de 4 m/s par seconde |

Au total, le corps monte au plus 2,48 m au-dessus de son point d'appel (1,38 m de saut et 1,10 m de
prise). Le vérificateur de niveau calcule la portée maximale, élan et temps de grâce compris :
11,8 m à niveau égal, 10,9 m pour monter de 0,80 m, 8,7 m pour monter de 2 m. Tous les passages qui
demandent une ombre sont plus larges.

### Le vide, les éclats, les sceaux

- Tomber dans le vide ramène sur la dernière plateforme visitée, avec l'heure du moment. Les chutes
  sont comptées. La touche R ramène aussi sur la dernière plateforme, sans compter de chute.
- **30 éclats de soleil** flottent dans l'archipel. Un éclat vient vers vous dès que vous passez à
  moins de 2,8 m, et il recharge l'élan. La plupart sont sur les chemins ; quelques-uns demandent
  une heure précise, un lancer ou le bon rayon sur la flèche.
- **Trois sceaux** attendent au bout des trois branches de l'archipel : le cercle de l'aube, le
  carré du zénith et le triangle du crépuscule. Prendre un sceau fait apparaître une colonne de
  lumière qui ramène au Cadran, où le sceau se pose de lui-même sur son socle.
- Quand les trois sceaux sont posés, le grand gnomon passe de 2 à 40 m de haut en 5,5 secondes. Son
  ombre de midi mène à l'Oculus, où la partie se termine : le soleil se couche, les étoiles
  apparaissent, puis le bilan s'affiche.

### Le chrono et le rang

- Le chrono, au dixième de seconde, s'affiche en haut à droite.
- À la première arrivée sur chaque plateforme, son nom et le temps s'affichent, avec l'écart sur la
  meilleure partie terminée : en orange quand vous êtes en avance, en gris quand vous êtes en
  retard.
- Le bilan donne un rang d'après le temps comparé au temps de référence (`par_time`, 5 minutes) :

| Rang | Temps |
| :---: | :--- |
| S | 5 min ou moins |
| A | 8 min ou moins |
| B | 12 min 30 ou moins |
| C | Au-delà |

Trouver les 30 éclats fait monter le rang d'un cran (un B devient un A). Le bilan compte aussi les
chutes, les élans et les lancers.

---

## L'archipel

| Plateforme | Forme | Niveau | Rôle |
| :--- | :--- | :---: | :--- |
| Le Seuil | Disque de 6 m de rayon | 0 m | Départ. Le mur noir y mène au Cadran le matin et à la Marche le soir |
| Le Cadran | Rectangle de 22 × 20 m percé de deux trémies de 4 × 3 m | 0 m | Plateforme centrale : le grand gnomon, les trois socles, l'obélisque, un petit cadran solaire au sol |
| La Dalle, Le Répit, Le Cap de l'aube | Rectangle de 9 × 8 m, disques de 2 m et 5 m | 0 m | Branche de l'aube, à l'ouest |
| Le Gué, Le Belvédère, Le Zénith | Disques de 1,8 m et 3,5 m, rectangle de 9 × 8 m | 0,8 m, 2 m, 2 m | Branche du zénith, au nord-est |
| La Marche, La Tour du soir, La Vigie | Disques de 5 m, 5 m et 3 m | 0 m, 4 m, 4 m | Branche du crépuscule, à l'est. La Marche porte un emmarchement de deux blocs (1,2 m et 2,4 m) |
| L'Oculus | Anneau de 6 m de rayon autour d'un puits de 2 m | 0 m | Fin de la partie, au nord du Cadran |

Le petit cadran solaire au sol du Cadran sert de leçon : ses lignes graphite, numérotées de VII à
XVII, montrent où tombe l'ombre de son aiguille à chaque heure.

### Les passages (solution)

Chaque passage n'existe qu'à certaines heures. Les plages ci-dessous sont calculées par le
vérificateur de niveau sur la géométrie du jeu, à la minute près (au quart d'heure près pour les
pierres cinétiques), puis jouées par le bot de test avec les vraies commandes.

| Passage | Pierre | Heures | Ce qu'il faut faire |
| :--- | :--- | :--- | :--- |
| Seuil vers Cadran | Mur du Seuil | 7 h 00 à 7 h 33 | Faire reculer le soleil vers 7 h, contourner le mur par le sud, suivre son ombre vers l'ouest |
| Cadran vers Dalle | Obélisque du Cadran | 7 h 00 à 7 h 42 | Même geste, depuis l'ouest du Cadran |
| Dalle vers Répit, puis Cap de l'aube | Dalle (12 m) | Répit jusqu'à 8 h 02, Cap de 7 h 00 à 7 h 18 | Le pont le plus long : plus de 40 m au-dessus du vide. Attendre qu'un nuage s'éloigne avant de courir, souffler sur le Répit, recommencer pour le second nuage |
| Cadran vers Gué, puis Belvédère | Aucune | Toute heure | Le Gué est à 6 m du coin nord-est du Cadran et 0,8 m plus haut : un saut en courant n'y suffit pas, il faut un élan en l'air. Puis un saut de 3,3 m vers le Belvédère, 1,2 m plus haut |
| Belvédère vers Zénith | Le bac | 8 h 30 à 11 h 30 | À midi, le radeau passe trop à l'est pour toucher le Belvédère. Ramener l'heure vers 11 h, attendre le bac au bord sud-est, faire un pas sur son ombre quand il repart, se laisser porter |
| Seuil vers Marche | Mur du Seuil | 16 h 36 à 17 h 00 | Pousser le soleil jusqu'à la butée de 17 h, partir vers l'est |
| Marche vers Tour du soir | Tour du soir (6 m) | Possible de 7 h 00 à 9 h 22, confortable de 7 h 00 à 7 h 42 | L'ombre de la tour flotte à 4 m au-dessus de la Marche, et son bord passe toujours à 40 cm au sud de l'emmarchement : l'heure ne règle que sa longueur. Monter les deux blocs, sauter vers le bord de l'ombre pour s'y hisser, la suivre jusqu'à la tour |
| Tour du soir vers Vigie | La flèche | 14 h 45 à 15 h 30 | Vers 15 h, le cercle balayé par la flèche touche les deux plateformes. Attendre la barre au bord sud-est de la Tour, faire un pas dessus quand elle quitte la plateforme, se laisser porter un demi-tour |
| Cadran vers Oculus | Grand gnomon levé (40 m) | 11 h 31 à 12 h 29 | Se placer à midi, contourner le gnomon, suivre son ombre vers le nord |

Les éclats qui demandent une heure précise :

| Éclat | Ombre | Heures |
| :--- | :--- | :--- |
| Au-dessus du vide à l'ouest du Cadran | Obélisque | 8 h 15 à 9 h 32 |
| Au nord-ouest de la Dalle | Dalle | 9 h 02 à 9 h 46 |
| Au nord-ouest du Cadran, loin dans le vide | Grand gnomon levé | 9 h 24 à 10 h 25 |
| Deux éclats sur le cercle de la flèche | La flèche | Vers 15 h, en se tenant à 9 m environ du centre du cercle |

### Ce que mesure le bot de test

Le bot suit la solution ci-dessus avec les vraies commandes (déplacement, course, élan, saut,
touches du soleil) et la vraie physique, à 60 images par seconde. Il vise en tournant la caméra,
comme le ferait la souris, et rejoue une étape depuis la dernière plateforme en cas de chute.

| Version de Godot | Résultat |
| :--- | :--- |
| 4.4.1, temps réel | Partie terminée en 1 min 38,6 s de jeu, sans chute ni étape rejouée, 22 éclats sur 30, 11 élans |
| 4.4.1, accéléré 4 fois, six parties | Six parties terminées entre 1 min 38 s et 1 min 46 s. Une seule étape rejouée sur les six : une chute à l'embarquement sur la flèche, réussi au deuxième essai |
| 4.7, accéléré 4 fois | 1 min 38 s de jeu, sans chute, 22 éclats sur 30 |

Ce temps est celui d'un joueur qui connaît déjà chaque passage et ne cherche pas les éclats ; la
découverte prend bien plus longtemps. L'embarquement sur la flèche est le geste le plus exigeant :
la barre ne couvre un point fixe qu'un tiers de seconde. Le bot ne lance pas : le lancer a été vérifié à part (posé sur
l'ombre du mur à 7 h, le joueur est emporté à 7 m/s quand l'heure avance, saute à 7,6 m/s et retombe
sur le Seuil).

---

## Principes techniques

### Les ombres (`ShadowSystem.gd`)

Une pierre noire est une boîte (largeur, hauteur, profondeur, rotation autour de la verticale). Ses
huit coins sont projetés sur le plan de son pied le long des rayons du soleil :
`p = c - dir × (c.y - plan) / dir.y`, où `dir` pointe vers le soleil. L'ombre est l'enveloppe
convexe de ces points. Pour une pierre posée, elle part de son pied ; pour une pierre qui flotte
(la flèche, le bac), c'est une plaque séparée qui voyage avec le soleil.

Chaque ombre a un maillage de remplissage juste au-dessus du plan, un liseré, de petites faces
latérales pour qu'on la voie comme une dalle depuis le dessous, et un corps statique sur la couche
de collision 2, de forme `ConvexPolygonShape3D`, dont le dessus affleure le plan. Les ombres des
pierres fixes sont reconstruites quand le soleil bouge ; celles des pierres cinétiques, à chaque
pas de physique.

Le transport sur une ombre : le rayon qui part des pieds vers l'ancien soleil touche la pierre, à
son ancienne place, en un point q. Ce point suit la pierre jusqu'à sa nouvelle place (rotation de
la flèche, glissement du bac), puis les pieds vont à sa projection selon le nouveau soleil. Le même
calcul couvre donc le soleil qui tourne et la pierre qui bouge. La vitesse mesurée du transport est
gardée : c'est elle que le saut ajoute au corps (le lancer).

Les nuages : le shader des ombres découpe un disque de 5,5 m sous chaque nuage, et le joueur ignore
la couche 2 tant que ses pieds sont dans ce disque.

### Le soleil (`Sun.gd`)

Avec t = (heure - 6) / 12 × π et φ = 65 degrés, la direction du soleil vaut
(cos t, sin t sin φ, sin t cos φ). La couleur et l'intensité de la lumière, le ciel, le brouillard,
la lumière ambiante et la brume suivent la hauteur du soleil, dans une palette presque sans couleur.
Le moteur ne calcule aucune ombre : seules celles des pierres noires existent, dessinées par
`ShadowSystem.gd`.

### Le corps et la caméra (`Player.gd`, `CameraRig.gd`)

Le corps est un `CharacterBody3D` en capsule. La prise de rebord cherche, 0,55 m puis 0,80 m devant
les pieds, une surface horizontale à portée, et vérifie que la capsule tient au-dessus du rebord et
à côté de lui avant de monter. Elle n'attend pas le haut du saut : en attendant, la tête butait sous
l'ombre suspendue de la Tour avant que son bord arrive à portée.

La caméra est un nœud à part, hors de l'interpolation physique : elle suit la position interpolée
du corps à chaque image affichée et tourne tout de suite avec la souris. L'affaissement à
l'atterrissage est un ressort calculé par petits pas fixes : calculé d'un seul pas, il divergeait
sous 10 images par seconde.

### Sensations

| Moment | Effets |
| :--- | :--- |
| Marche et course | Balancement de la tête calé sur les pas, pas sonores différents sur le béton, la pierre et l'ombre (une note creuse et vitrée), champ de vision élargi de 78 à 84 degrés en courant |
| Élan | Coup de champ de vision, souffle bref, traînée graphite, lignes de vitesse sur les bords de l'écran, deux traits autour du réticule qui s'éteignent puis se rallument en orange à la recharge |
| Prise de rebord | Plongée de la caméra, son de prise |
| Lancer | Champ de vision qui suit la vitesse, son montant, légère secousse |
| Heure qui tourne | Cadran levé et perle orange plus vive, liserés des ombres qui passent à l'orange, tic à chaque quart d'heure |
| Éclat | Note de cloche, plus aiguë à chaque éclat ramassé dans les 3 secondes, gerbe orange, élan rechargé |
| Sceau | Arpège, gerbe, secousse ; au socle, un gong grave |
| Grand gnomon | Grondement de pierre chaque seconde, poussière, secousse continue |
| Chute | Sifflement, vent qui forcit, fondu blanc de 0,3 s, retour sur la dernière plateforme |
| Ambiance | Vent continu en boucle, cloche lointaine toutes les 9 à 16 secondes, piano génératif |

### La musique (`Music.gd`)

Une note de piano synthétisée (une fondamentale et deux harmoniques qui s'éteignent chacune à leur
rythme) est transposée sur une gamme pentatonique de do majeur, sur deux octaves. À chaque croche, à
84 battements par minute, une note peut sonner avec une probabilité qui suit l'intensité du jeu :
7 % immobile, 62 % en plein vol. L'intensité vient de la vitesse du corps, des sauts, des élans, des
éclats et de l'heure qui tourne. Une nappe de deux accords (do majeur et la mineur, huit mesures
chacun) tient le fond.

### Rendu

Tout est construit par le code. Le tonemapping est linéaire et la lumière réglée pour que les dessus
des volumes blancs touchent le blanc pur, comme sur un rendu d'architecte, pendant que leurs côtés
restent gris. Le shader du béton assombrit les faces tournées vers le bas, celui du puits de
l'Oculus noircit ses parois à quelques mètres sous le bord. Des volumes blancs lointains (tours,
dalles flottantes), le brouillard blanc et la brume donnent la profondeur. Les particules et les
colonnes de lumière sont mélangées et non ajoutées : un effet additif disparaît sur un fond blanc.

### Sauvegarde

`user://gnomon_save.json` (version 2) garde la partie en cours (éclats, sceaux, gnomon levé, chutes,
élans, lancers, temps, dernière plateforme, heure, temps intermédiaires, astuces déjà vues), la
meilleure partie terminée avec ses temps intermédiaires, et les réglages (langue, son, sensibilité
de la souris, axe vertical inversé). Une sauvegarde de la version précédente est ignorée, puisque la
carte a changé. La partie est enregistrée à chaque nouvelle plateforme, chaque éclat, chaque sceau
et à la pause.

---

## Tests

Trois outils se lancent en ajoutant des arguments après `--` sur la ligne de commande de Godot.

| Commande | Ce qu'elle fait |
| :--- | :--- |
| `godot --headless --path . -- --check` | Le vérificateur de niveau (`tests/LevelCheck.gd`) : fenêtres horaires de chaque passage, éclats à heure précise, portée du corps, et recherche de raccourcis. Il signale toute plateforme atteignable sans ombre alors que la carte ne le prévoit pas. Code de sortie 1 en cas de problème |
| `godot --headless --path . -- --bot` | Le bot de test (`tests/TestBot.gd`) joue toute la partie. Ajouter `--fast` pour jouer 4 fois plus vite, `--trace` pour afficher la position du corps |
| `godot --path . -- --shot=all --out=DOSSIER --hud` | Des captures depuis des points de vue fixés (`tests/Shots.gd`) : le titre, chaque passage, une vue aérienne, une vue axonométrique, la pause et le bilan. Demande une fenêtre ; une extension `.jpg` dans `--out` écrit un JPEG |

Le vérificateur simule le corps avec les valeurs de `config.json` : modifier la vitesse, le saut ou
l'élan change les portées, et il faut le relancer pour vérifier qu'aucun passage n'est devenu un
raccourci. Le bot et les captures écrivent dans la sauvegarde du jeu.

---

## Organisation des fichiers

| Dossier | Contenu |
| :--- | :--- |
| `autoloads/` | `ConfigManager` (réglages), `SaveManager` (sauvegarde), `StringManager` (textes), `Sfx` (sons synthétisés, vent), `Music` (piano génératif), `GameState` (partie en cours) |
| `data/` | `config.json`, `world.json` (plateformes, pierres, blocs, mobilier, éclats, sceaux, socles, Oculus, nuages), `strings_fr.json`, `strings_en.json` |
| `scenes/` | `Main.tscn` et `Main.gd` (construction de la scène, phases de jeu, modes de test) |
| `scenes/ui/` | `UiTheme`, `Hud`, `TitleScreen`, `PauseMenu`, `EndScreen`, `Fade` |
| `scripts/` | `Sun`, `ShadowSystem`, `World`, `Player`, `CameraRig`, `Effects3D`, `InputSetup` |
| `shaders/` | `concrete`, `stone`, `shadow`, `sky`, `mist`, `beam` et `noise.gdshaderinc` |
| `tests/` | `LevelCheck`, `TestBot`, `Shots` |

### Modifier l'archipel

Une plateforme de `world.json` donne sa forme (`disc`, `rect` ou `ring`), son centre (`x`, `z`), son
niveau `y`, son rayon `r` ou ses dimensions `w` et `d`, son point de réapparition `spawn` et
l'astuce montrée à la première visite. Options : `holes` (trémies d'un rectangle, en coordonnées du
monde), `rails` (garde-corps entre deux points), `rail_arcs` (garde-corps le long du bord d'un
disque, entre deux angles : 0 à l'est, 90 au sud), `pilotis` (colonnes sous la dalle, décalées du
centre).

Une pierre noire donne sa plateforme (ou `base_y`), sa position, ses dimensions `w`, `h`, `d`, sa
rotation `yaw` en degrés et, si elle flotte, sa hauteur `lift`. Une pierre cinétique ajoute
`motion` : `spin` (avec `spin` en degrés par seconde ; `x` et `z` donnent alors l'axe) ou `slide`
(avec `to`, `period` et `pause`).

Un passage existe quand l'ombre d'une pierre touche une autre plateforme de même niveau : déplacer
une pierre d'un mètre peut ouvrir ou fermer un passage, ou en décaler l'heure. Relancez le
vérificateur après chaque modification : il redonne les plages horaires et signale les raccourcis.

---

## Lancement

1. Ouvrez le dossier `first_person_explore` dans Godot 4.4 ou plus récent.
2. Lancez la scène principale (`F5`) : elle est déjà réglée sur `scenes/Main.tscn`.
3. Pour la version web, utilisez le préréglage d'export **Web** : il écrit dans le dossier `web`
   du projet, vers lequel pointe la page html.
