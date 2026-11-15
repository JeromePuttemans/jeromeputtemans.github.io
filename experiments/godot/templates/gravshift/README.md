# Gravshift : prototype de shoot'em up gravitationnel pour Godot 4

Un shoot'em up en arène où votre vaisseau est un puits de gravité : il aspire les balles
ennemies, les fait tourner autour de lui, puis les renvoie sur leurs tireurs. Le projet ne
contient aucun fichier graphique ni sonore : les formes, la grille d'espace-temps, les effets,
les bruitages et la musique sont produits par le code.

---

## Twist

**Le vaisseau ne tire presque rien de lui-même : sa vraie arme est le feu ennemi, capturé en
orbite puis renvoyé.**

Le moment où le joueur le comprend : au premier secteur, un Artilleur lui envoie un éventail de
trois balles orange. Il maintient Espace, la grille se creuse autour du vaisseau, les balles
s'incurvent et se mettent à tourner autour de lui. « Balle capturée : relâchez pour la
renvoyer » s'affiche au-dessus du vaisseau. Il relâche : les trois balles partent en tête
chercheuse sur les ennemis les plus proches et font trois fois les dégâts de son tir normal.

Le puits attire aussi les ennemis. Un Drone happé par le puits puis projeté sur un autre ennemi
se brise : le joueur découvre qu'il peut se servir des ennemis comme de projectiles.

Plus tard, la jauge de **Nova** se remplit. Le joueur appuie sur E au milieu d'une pluie de
balles : pendant 1,2 s, le vaisseau devient un trou noir qui aspire toutes les balles de l'écran,
puis les renvoie d'un seul coup.

---

## Comment jouer

| Action | Clavier et souris | Manette |
| :--- | :--- | :--- |
| Se déplacer | Bloc ZQSD en AZERTY (WASD en QWERTY), ou les flèches | Stick gauche ou croix |
| Ouvrir le puits (maintenir), renvoyer (relâcher) | `Espace`, `J`, `Maj` ou clic gauche | `A`, gâchette haute droite ou gâchette droite |
| Déclencher la Nova (jauge pleine) | `E`, `K` ou clic droit | `X`, gâchette haute gauche ou gâchette gauche |
| Pause | `Échap` ou `P` | `Start` |
| Choisir dans un menu | Haut et bas, puis `Espace` ou `Entrée` ; ou survol et clic | Croix puis `A` |
| Choisir une amélioration | Gauche et droite puis `Espace`, ou `1` `2` `3`, ou un clic sur la carte | Croix puis `A` |
| Abandonner la partie (en pause) | `Q`, ou le menu **ABANDONNER** | |
| Revenir à l'écran titre (après une partie) | `Échap`, ou le menu **ÉCRAN TITRE** | `Start` |
| Changer de langue, couper les bruitages (écran titre) | `L`, `M`, ou les lignes du menu | |

Le tir est automatique : vous n'avez pas de touche de tir. Les touches de lettres sont lues par
leur position sur le clavier : le bloc ZQSD d'un clavier AZERTY fonctionne sans réglage. Le jeu
se met en pause tout seul quand la fenêtre perd le focus.

Chaque écran ignore les touches pendant un court instant après son ouverture : 0,45 s pour le
choix d'une amélioration, 1 s pour l'écran de fin. Sans ce délai, un Espace martelé pour le puits
au moment où le secteur se termine choisirait une carte au hasard.

### Les règles

1. **Le tir automatique.** Toutes les 0,2 s, le vaisseau tire un trait de 1 point de dégâts
   vers l'ennemi le plus proche, à 820 px/s, légèrement guidé. Il suffit contre les Drones
   (3 points de vie) ; contre une Tourelle (24 points de vie), il lui faut près de 5 s.
2. **Le puits de gravité.** Tant que vous maintenez Espace, le puits est ouvert : il attire les
   balles orange dans un rayon de 230 px et capture celles qui arrivent à moins de 74 px. Une
   balle capturée tourne en orbite autour du vaisseau. L'orbite garde 12 balles au plus. Puits
   ouvert, le vaisseau avance à 60 % de sa vitesse (198 px/s au lieu de 330).
3. **Le flux.** Le puits consomme 28 points de flux par seconde, sur une réserve de 100 :
   ouvert à vide, il tient 3,6 s. Chaque balle capturée rend 5 points. Le puits ne s'ouvre pas
   sous 12 points. Fermé, il se recharge de 22 points par seconde après 0,35 s d'attente : de 0
   à 100 en 4,9 s. Si le flux tombe à 0 puits ouvert, le puits s'effondre (« PUITS ÉPUISÉ ») et
   renvoie tout de force.
4. **Le renvoi.** Relâchez Espace : chaque balle en orbite repart à 780 px/s en tête chercheuse,
   avec 3 points de dégâts. Les balles se répartissent entre les ennemis les plus proches : 6
   balles face à 3 ennemis donnent 2 balles par ennemi. Le relâchement émet aussi une onde de
   130 px qui repousse les balles ennemies et les ennemis proches.
5. **L'orbite frappe.** Une balle en orbite qui touche un ennemi lui fait 1 point de dégâts et
   disparaît. Un Drone attiré dans votre orbite s'y use donc tout seul.
6. **Les collisions entre ennemis.** Le puits ouvert attire aussi les ennemis, d'autant moins
   qu'ils sont lourds (la masse de chaque ennemi est dans le tableau suivant). Deux ennemis qui
   se rencontrent à plus de 150 px/s l'un par rapport à l'autre prennent chacun 3 × vitesse ÷ 150
   points de dégâts. Exemple : un Drone projeté à 300 px/s sur un Artilleur arrêté leur fait
   6 points chacun ; le Drone (3 points de vie) est détruit, l'Artilleur (10) garde 4 points.
7. **Les orbes lourdes.** Les orbes rouges à pointes (Colosse, Gardien, Singularité) ignorent la
   gravité : le puits ne les capture pas et l'onde ne les repousse pas. Il faut les esquiver,
   ou déclencher la Nova, qui les avale.
8. **La coque.** Le vaisseau a 3 points de coque. Une balle, une orbe ou un contact avec un
   ennemi en retire un ; le vaisseau clignote ensuite et reste invulnérable 1,6 s. Seul son
   cœur blanc (7 px de rayon) compte pour les touches : puits ouvert, un fin cercle blanc le
   rappelle. Au dernier point de coque, les bords de l'écran battent en rouge au rythme d'un cœur.
9. **Les éclats.** Chaque ennemi détruit lâche des éclats bleus : un pour 40 points de sa valeur,
   entre 1 et 14 (un Drone en lâche 1, un Artilleur 4, un Colosse 13, un boss 40). Un éclat à moins
   de 120 px du vaisseau est attiré vers lui ; puits ouvert, l'aimant porte à 1,3 × le rayon
   d'attraction (299 px). Ramassé, un éclat rapporte 10 points × le multiplicateur et 1,4 point
   de Nova. Un éclat disparaît au bout de 7 s, en clignotant pendant sa dernière seconde et demie.
   Contre un boss, chaque renvoi qui le touche a 15 chances sur 100 de lui arracher un éclat.
10. **Le frôlement.** Une balle qui passe tout près du cœur sans le toucher (jusqu'à 24 px au-delà
    de la distance de touche) compte comme un frôlement : 25 points × le multiplicateur et de la
    Nova. Une orbe lourde frôlée donne 5 points de Nova et affiche « FRÔLÉ » ; une balle orange
    en donne 1,5, et seulement puits fermé (ouvert, il l'aurait capturée). Le frôlement est
    compté quand la balle ressort de la zone : une balle qui finit par toucher ne rapporte rien.
11. **La Nova.** La jauge compte 100 points : environ 72 éclats, ou 20 orbes frôlées. Pleine,
    elle s'illumine et E déclenche la Nova. Pendant 1,2 s, le puits couvre toute l'arène : toutes
    les balles orange sont aspirées (l'orbite en garde jusqu'à 60), les orbes lourdes à moins de
    260 px sont avalées, les ennemis sont attirés 1,5 fois plus fort et ceux qui touchent le
    vaisseau sont broyés (les boss exceptés). Le flux ne baisse pas et le vaisseau reste
    intouchable jusqu'à 0,6 s après la fin. Puis tout part d'un coup : les renvois de la Nova font
    1,5 fois les dégâts d'un renvoi normal (4,5 points), traversent un ennemi de plus, et l'onde
    porte à 286 px en étourdissant les ennemis 1 s.
12. **Les réparations.** Chaque ennemi détruit a 6 chances sur 100 de lâcher une croix verte
    quand la coque n'est pas pleine. Ramassée (elle est aimantée comme les éclats), elle répare un
    point (« +1 COQUE »). Elle disparaît au bout de 9 s.
13. **Les secteurs.** La partie compte 10 secteurs. Un chevron clignote au bord de l'arène 0,9 s
    avant chaque arrivée d'ennemi, à l'endroit où il va entrer. Un secteur est terminé quand tous
    ses ennemis sont détruits ; vous choisissez alors une amélioration parmi trois tirées au
    hasard. Le secteur 5 se termine par le Gardien, le secteur 10 par la Singularité. Vaincre la
    Singularité gagne la partie.
14. **Le score.** Chaque ennemi détruit rapporte ses points × le multiplicateur. Chaque
    destruction allonge la chaîne et relance son minuteur de 2,5 s. Multiplicateur = 1 + chaîne
    ÷ 5, arrondi à l'entier inférieur, au plus ×8. Exemple : à la 10e destruction d'affilée, le
    multiplicateur vaut ×3 et un Artilleur (150 points) en rapporte 450. Quand le minuteur
    s'épuise, le multiplicateur perd un cran (de ×3 à ×2, puis ×1 si rien ne tombe encore
    pendant 2,5 s). Une touche sur la coque remet la chaîne à zéro.
15. **La fronde multiple.** Un renvoi qui détruit au moins 2 ennemis dans les 1,3 s ajoute un
    bonus de 60 × n², n étant le nombre d'ennemis détruits : 4 ennemis donnent 960 points
    (« 4 D'UN COUP »). Le meilleur score et le meilleur secteur sont enregistrés.

### Les ennemis

| Ennemi | Aspect | Points de vie | Masse | Points | Comportement | Dès le secteur |
| :--- | :--- | :---: | :---: | :---: | :--- | :---: |
| Drone | Carré rose qui tourne | 3 | 1 | 50 | Fonce sur le vaisseau. Le puits l'emporte sans effort, dans l'orbite ou sur ses voisins | 1 |
| Artilleur | Flèche orange | 10 | 2 | 150 | Tourne autour du vaisseau à 300 px environ et tire un éventail de 3 balles visées toutes les 1,7 s : votre principale source de munitions. Sa bouche s'allume pendant la dernière demi-seconde avant chaque tir | 1 |
| Essaim | Fléchette vert citron, en nuée | 1 | 0,5 | 30 | Arrive en nuée de 8 à 14 par un même point du bord. Chacune tourne autour du vaisseau à 190 px pendant 2 à 3,5 s, puis plonge droit sur lui pendant 0,9 s. Pendant qu'elles tournent, le puits ouvert attire toute la nuée dans l'orbite ou les unes contre les autres | 2 |
| Tourelle | Hexagone jaune | 24 | 3 | 250 | Se poste dans la moitié haute et arrose l'arène d'une spirale à trois bras, une salve toutes les 0,13 s. Dangereuse, mais elle remplit une orbite en quelques secondes | 2 |
| Lancier | Triangle violet | 6 | 1,6 | 120 | Approche, vise 0,6 s (une ligne clignotante qui s'épaissit montre sa trajectoire), puis fonce à 560 px/s en laissant des images rémanentes. Le puits courbe sa charge : vous pouvez l'envoyer sur ses alliés | 3 |
| Mine | Cercle vert à piquants | 4 | 1,2 | 80 | Dérive vers le vaisseau. Détruite, ou au bout de 6 s (l'arc intérieur montre le temps qui reste), elle éclate en un anneau de 12 balles. Détruite de loin, c'est un cadeau pour le puits | 4 |
| Siphon | Disque noir cerclé d'indigo | 32 | 6 | 400 | Un puits ennemi. Il se tient à 340 px du vaisseau et attire les balles orange libres à moins de 170 px, puis les absorbe (24 au plus) : il gonfle et vous prive de munitions. Toutes les 5 s, s'il en garde au moins 6, il les crache toutes sur vous en éventail. Détruit, il éclate : ses balles plus 8 autres partent en anneau, de quoi remplir une orbite | 4 |
| Colosse | Grand octogone rouge | 45 | 9 | 500 | Avance lentement et tire 3 orbes lourdes toutes les 2,6 s ; son cœur rougit pendant les 0,8 s qui précèdent. Le puits le déplace à peine | 6 |

| Boss | Points de vie | Points | Secteur | Attaques |
| :--- | :---: | :---: | :---: | :--- |
| Gardien | 600 | 6 000 | 5 | Patrouille en haut de l'arène derrière trois arcs de bouclier tournants qui arrêtent vos tirs et vos renvois : visez les trouées, ou laissez le guidage les trouver. Tire des anneaux de balles percés de deux trouées (son cœur s'allume 0,4 s avant) et des salves de 3 orbes lourdes. Sous la moitié de sa vie, « PHASE 2 » s'affiche : il ajoute une spirale et appelle deux Drones toutes les 7 s |
| Singularité | 1 500 | 20 000 | 10 | Un puits contraire : elle attire le vaisseau vers son cœur partout dans l'arène, plus fort à chaque tiers de vie perdu. Au-dessus des deux tiers de sa vie, deux spirales ; jusqu'au dernier tiers, des anneaux de 18 balles et des salves de 3 orbes lourdes ; au dernier tiers, tout à la fois, plus une Mine et deux Drones toutes les 6 s. Chaque changement de phase est annoncé |

Contre les deux boss, le tir automatique ne suffit pas : il faut capturer leurs propres balles
et les leur renvoyer. Les balles orange des boss sont capturables comme les autres, et chaque
renvoi qui touche un boss peut lui arracher un éclat : la Nova se recharge pendant le combat.

### Les améliorations

Après chaque secteur, trois cartes sont tirées au hasard parmi les douze améliorations, sans
jamais proposer une amélioration déjà à son niveau maximal. Chaque carte indique « NOUVEAU » ou
le niveau qu'elle donne, et une rangée de points montre les niveaux déjà pris et ceux qui restent.

| Amélioration | Effet par niveau | Niveaux |
| :--- | :--- | :---: |
| Orbite élargie | L'orbite garde 6 balles de plus | 3 |
| Horizon | Le puits attire et capture 20 % plus loin | 3 |
| Fronde | Les balles renvoyées font 40 % de dégâts en plus | 3 |
| Réservoir | +30 de flux, recharge 25 % plus rapide | 3 |
| Canon jumeau | Un trait automatique de plus, cadence +15 % | 3 |
| Coque renforcée | +1 point de coque maximum, et une réparation | 3 |
| Éclats | Les balles renvoyées éclatent à l'impact : 1 point de dégâts aux ennemis voisins (à moins de 55 px de leur bord) | 1 |
| Perforation | Les balles renvoyées traversent un ennemi de plus | 2 |
| Broyeur | Les balles en orbite ne disparaissent plus en frappant | 1 |
| Contrecoup | L'onde du relâchement porte 60 % plus loin (208 px) et étourdit les ennemis 1 s | 1 |
| Aimant | L'aimant des éclats porte 120 px plus loin (240 px au niveau 1, 360 px au niveau 2), et chaque éclat ou frôlement charge la Nova 50 % de plus | 2 |
| Supernova | La Nova dure 0,48 s de plus (1,68 s au niveau 1, 2,16 s au niveau 2) et ses renvois font 50 % de dégâts en plus | 2 |

### Lire l'écran

| Zone | Contenu |
| :--- | :--- |
| En haut à gauche | Le score, qui défile vers sa valeur, avec les derniers gains en doré à sa droite. Dessous, la pastille du multiplicateur (x1 à x8) : son anneau est le minuteur de la chaîne, elle grossit quand le multiplicateur monte et vire du cyan au rose ; à côté, la longueur de la chaîne |
| En haut au centre | Le secteur (SECTEUR 3/10), une pastille par secteur (les secteurs de boss sont des hexagones roses), une barre qui avance à mesure que le secteur se vide et le nombre d'ennemis restants. Pendant un combat de boss : son nom et sa barre de vie, avec un cran par changement de phase et une barre blanche qui suit les dégâts avec retard |
| En haut à droite | La coque : un petit vaisseau par point. Au dernier point, il bat en rouge |
| En bas au centre | La jauge de **FLUX** (elle vire au rouge sous la moitié), le nombre de balles en **ORBITE** sur la capacité, et la jauge de **NOVA**, qui s'illumine et affiche « NOVA PRÊTE : E » quand elle est pleine |
| En bas à gauche | Les améliorations prises pendant la partie, avec un point doré par niveau |
| Au centre | Les annonces : début de secteur, alerte de boss (nom et conseil), changement de phase, secteur nettoyé |
| Autour du vaisseau | Un arc de couleur : le flux restant. Un arc blanc : le remplissage de l'orbite. Six arcs violets qui tournent : la Nova est prête. Puits fermé, un cercle de points montre la portée de la légère attraction permanente ; puits ouvert, le cercle de capture, les bras de la spirale et le cercle d'attraction |
| Au bord de l'arène | Les chevrons d'arrivée, aux couleurs de l'ennemi annoncé |
| La grille | Elle se creuse là où la gravité agit : autour du vaisseau quand le puits est ouvert, autour d'un Siphon et de la Singularité, et elle ondule après une explosion ou un renvoi. Sa teinte change à chaque secteur, du bleu froid du secteur 1 au magenta du secteur 10 |

### Les écrans

| Écran | Contenu |
| :--- | :--- |
| Titre | Le logo, avec des balles qui tournent autour de lui, et le menu : **JOUER**, **COMMENT JOUER**, **LANGUE**, **BRUITAGES**, **MUSIQUE**. Dessous, le meilleur score et les commandes |
| Comment jouer | Quatre panneaux numérotés (Capturer, Renvoyer, Projeter, Nova), chacun avec une petite animation qui rejoue la règle en boucle, puis la règle des orbes lourdes et les commandes. Échap, Espace ou un clic ramènent au menu |
| Pause | **REPRENDRE** ou **ABANDONNER**, et la liste des améliorations prises, avec leur niveau sur le niveau maximal. La musique est assourdie |
| Amélioration | Le bilan du secteur (ennemis détruits, balles capturées, points gagnés) et les trois cartes. La carte choisie s'envole vers la rangée d'améliorations du HUD |
| Fin | Le titre se pose, le score défile, le rang est tamponné, les statistiques apparaissent une à une (secteur, ennemis détruits, balles capturées, meilleure fronde, frôlements, Novas, durée), puis le menu **REJOUER** ou **ÉCRAN TITRE** |

Le rang dépend du score final :

| Rang | Score minimal |
| :---: | ---: |
| S | 180 000 |
| A | 110 000 |
| B | 70 000 |
| C | 30 000 |
| D | 0 |

### Ce que mesure le bot de test

Un bot de test se tient à distance des ennemis, esquive les orbes lourdes, ouvre le puits dès
que trois balles approchent et relâche quand l'orbite est pleine ou que plus rien n'arrive. Il
déclenche la Nova quand la jauge est pleine et que la situation le justifie : au moins 14 balles
près de lui, plus de 40 à l'écran, un boss en vue ou le dernier point de coque. Contre la
Singularité, il tourne autour d'elle à 330 px. Il a joué 8 parties complètes dans chacune de ses
deux versions :

| Version du bot | Victoires | Touches encaissées par partie | Où il perd | Score | Novas par partie | Durée |
| :--- | :---: | :---: | :--- | :--- | :---: | :--- |
| Réflexes parfaits : il voit chaque balle et corrige sa course à chaque image | 8 sur 8 | 0 à 2 | nulle part | 134 835 à 196 455 (rang A ou S) | 3 à 7 | 5 min 22 s à 7 min 14 s |
| Temps de réaction de 0,2 s : ses décisions ne changent que toutes les 0,2 s | 3 sur 8 | 3 à 7 | 3 fois contre le Gardien, à qui il restait environ la moitié de sa vie ; une fois au secteur 6, une fois au secteur 7 | 48 955 à 83 040 en cas de défaite (rang C ou B), 131 885 à 176 130 en cas de victoire (rang A) | 1 à 5 | 3 min 13 s à 6 min 30 s |

La première version montre que tout est esquivable et que la partie se termine : elle gagne à
chaque fois en encaissant au plus 2 touches. La seconde ressemble davantage à un joueur humain,
qui voit moins bien et réagit plus lentement. Pour elle, le Gardien est le premier vrai mur. Viennent
ensuite les secteurs 6 et 7, où Colosses, Siphons et nuées d'Essaim arrivent ensemble. Si vous
mourez souvent au secteur 5, ramassez les éclats pour arriver devant le Gardien avec la Nova
prête : elle avale ses orbes lourdes et lui renvoie ses anneaux.

---

## Genre & systèmes clés

Un shoot'em up en arène fixe (twin-stick sans second stick) : le vaisseau se déplace librement,
des vagues d'ennemis arrivent par les bords, et le danger vient des balles qui remplissent
l'écran. Le genre repose sur la lecture des trajectoires, le placement et un score à
multiplicateur qui récompense les destructions enchaînées. Ici, le tir est automatique et
faible : la puissance de feu vient des balles ennemies, qu'il faut aller chercher au plus près
du danger pour les capturer. Les frôlements et la Nova récompensent aussi la prise de risque :
plus vous passez près des balles, plus vite vous chargez l'arme qui nettoie l'écran.

---

## Systèmes implémentés

### Puits, flux et orbite (`gravity_field.gd`, `bullet_field.gd`)

Le puits suit le vaisseau. Fermé, il exerce une légère attraction permanente sur les ennemis
dans un rayon de 1,2 × 230 = 276 px (120 ÷ masse, décroissante avec la distance) : la position
du vaisseau courbe déjà leurs trajectoires. Ouvert, il accélère les balles orange vers le
vaisseau (1 400 × (1 − distance ÷ 230) px/s²) et les ennemis (900 ÷ masse × (1 − distance ÷
230)). Une balle capturée glisse de sa position vers l'orbite puis tourne autour du vaisseau.
Les orbites s'empilent par anneaux de 12 balles (de 48 à 62 px, puis 10 px plus loin à chaque
anneau), les anneaux extérieurs tournant plus lentement. `bullet_field.gd` stocke toutes les
balles ennemies dans des tableaux compacts (position, vitesse, type, âge, état de frôlement) :
des centaines de balles ne coûtent qu'un nœud.

### Nova (`gravity_field.gd`, `game_manager.gd`)

`GravityField.add_nova()` remplit la jauge (multipliée par le bonus de l'amélioration Aimant) et
prévient `game_manager.on_nova_ready()` quand elle est pleine. `start_nova()` vide la jauge et
ouvre le puits pour la durée de la Nova. Pendant ce temps, `pull_radius()` renvoie 1 500 px,
`bullet_pull()` renvoie `nova_pull`, `swallow_radius()` autorise `bullet_field.gd` à tirer les
orbes lourdes et à les détruire au rayon de capture, et `current_capacity()` passe à 60. À la
fin, `release(false, true)` lance des tirs de type `NOVA` (violets) et `on_release()` applique
l'onde élargie. La première fois que la jauge se remplit depuis le lancement du jeu, « Nova
prête : appuyez sur E » s'affiche au-dessus du vaisseau.

### Éclats et réparations (`pickups.gd`)

Les objets à ramasser vivent dans des tableaux compacts, comme les balles. Chaque image, un
objet dans le rayon d'aimant est accéléré vers le vaisseau de 2 400 × (0,35 + 0,65 × (1 −
distance ÷ rayon)) px/s², les autres ralentissent et rebondissent sur les bords. À moins de
20 px du vaisseau, l'objet appelle `game_manager.collect_pickup()`. Le son du ramassage monte d'un
cran à chaque éclat pris moins de 0,35 s après le précédent : une pluie d'éclats sonne comme une
gamme qui grimpe.

### Frôlement (`bullet_field.gd`, `combat.gd`)

Chaque balle a un état : jamais approchée, dans l'anneau de frôlement, déjà comptée.
`bullet_field.graze()` fait passer une balle de l'un à l'autre et renvoie celles qui viennent de
quitter l'anneau. `combat.gd` ne les transmet à `game_manager.on_graze()` que si le vaisseau
n'est pas invulnérable : un frôlement sans risque ne compte pas.

### Renvoi et onde (`gravity_field.gd`, `shots.gd`, `game_manager.gd`)

`GravityField.release()` trie les ennemis par distance et lance chaque balle de l'orbite vers
l'un d'eux, à tour de rôle. Les renvois sont des tirs guidés (`shots.gd`, types `SLING` et
`NOVA`) qui peuvent traverser des ennemis avec Perforation. `game_manager.on_release()` applique
l'onde (balles repoussées, ennemis poussés de 320 ÷ masse px/s, 520 après une Nova), déforme la
grille et ouvre la fenêtre de 1,3 s qui compte la fronde multiple.

### Combat (`combat.gd`)

Une passe par image, en tests de cercles sur les distances au carré : tirs contre ennemis (les
arcs du Gardien arrêtent les tirs), orbite contre ennemis, ennemis entre eux, balles et ennemis
contre le vaisseau, frôlements. Les collisions entre ennemis séparent les deux corps selon leurs
masses et les font rebondir ; au-delà de 150 px/s de vitesse relative, elles infligent des
dégâts. Pendant la Nova, un ennemi qui touche le vaisseau est broyé.

### Ennemis (`enemy_base.gd` et un script par ennemi)

Chaque image, l'ennemi choisit une vitesse souhaitée (`_behave`), le puits ajoute son
attraction divisée par la masse, puis l'ennemi se déplace. Les ennemis naissent hors de
l'arène ; une fois entrés, ils rebondissent sur ses bords. Un tir qui touche repousse l'ennemi
de (30 + 25 × dégâts) ÷ masse px/s. Les caractéristiques (points de vie, masse, rayon, vitesse,
points, couleur, cadence) viennent de `settings.json`. `charge()` donne l'avancement du
rechargement : l'Artilleur, le Colosse, le Siphon et le Gardien s'en servent pour annoncer leur
tir. Le Siphon expose `sink()`, que `game_manager.gravity_sinks()` transmet à `bullet_field.gd`.

### Secteurs (`spawner.gd`)

Un secteur est une liste de groupes `{type, count, edge, delay, interval, flock}` : `count`
ennemis de type `type` arrivent un par un toutes les `interval` secondes, `delay` secondes après
le début du secteur, par le bord `edge` (`top`, `bottom`, `left`, `right`, `sides`, `corners` ou
`random`). Avec `flock: true`, tout le groupe entre par un même point du bord, à 40 px près :
c'est ainsi qu'arrivent les nuées d'Essaim. Le point d'entrée de chaque ennemi est tiré 0,9 s à
l'avance pour afficher son chevron ; tout le calendrier est décalé d'autant.

| Secteur | Ennemis | Composition |
| :---: | :---: | :--- |
| 1 | 23 | 18 Drones, 5 Artilleurs |
| 2 | 33 | 16 Essaim (2 nuées), 8 Drones, 8 Artilleurs, 1 Tourelle |
| 3 | 32 | 12 Drones, 10 Essaim, 4 Artilleurs, 4 Lanciers, 2 Tourelles |
| 4 | 30 | 8 Mines, 8 Essaim, 6 Lanciers, 5 Artilleurs, 2 Tourelles, 1 Siphon |
| 5 | 12 + Gardien | 8 Drones, 4 Artilleurs, plus les Drones qu'il appelle |
| 6 | 27 | 12 Essaim, 6 Artilleurs, 6 Mines, 2 Colosses, 1 Siphon |
| 7 | 36 | 10 Essaim, 8 Lanciers, 8 Mines, 5 Artilleurs, 3 Tourelles, 2 Siphons |
| 8 | 48 | 24 Essaim (2 nuées), 12 Drones, 8 Lanciers, 2 Tourelles, 2 Colosses |
| 9 | 39 | 14 Essaim, 10 Lanciers, 8 Artilleurs, 3 Tourelles, 2 Colosses, 2 Siphons |
| 10 | Singularité | ses renforts seulement |

### Score, chaîne et améliorations (`game_manager.gd`, `upgrades.gd`)

`game_manager.add_score()` ajoute les points et les inscrit dans la liste des gains récents que
le HUD affiche. `enemy_destroyed()` allonge la chaîne ; `_decay_chain()` fait perdre un cran au
multiplicateur quand le minuteur s'épuise. `upgrades.gd` tire les trois cartes (`offer`) et
applique l'amélioration choisie au puits, au vaisseau ou aux objets à ramasser (`apply`).

### Rendu (`space_grid.gd`, `effects.gd`, entités)

La grille d'espace-temps est un réseau de points reliés à leur position de repos par des
ressorts. Le puits ouvert, la Nova, les Siphons et la Singularité les attirent ; les explosions et
les renvois leur donnent une impulsion vers l'extérieur. Chaque sommet prend une couleur selon son
déplacement : la grille s'allume là où la gravité travaille. Chaque secteur a ses deux couleurs
de grille et sa teinte de nébuleuse, atteintes en deux secondes environ. Derrière la grille,
trois nébuleuses dérivent lentement et 150 étoiles scintillent.

Deux familles d'objets se distinguent à l'œil. Tout ce qui brille (balles, orbite, tirs, puits,
éclats) est dessiné en mélange additif avec une texture de halo générée au lancement. Les
ennemis sont des corps pleins et sombres sous un contour lumineux, en mélange normal : ils
masquent la grille au lieu de s'y fondre. Les couleurs suivent une règle : le froid (cyan, bleu,
vert) est à vous, le chaud (orange, rouge) est à l'ennemi. Un ennemi détruit se brise en
segments de son contour qui tournent sur eux-mêmes en s'éloignant.

Le vaisseau penche dans les virages (l'aile intérieure raccourcit), s'écrase un instant à chaque
renvoi, laisse une traînée en ruban et porte deux flammes qui grandissent avec sa vitesse.

### Post-traitement (`post_fx.gd`)

Un seul shader plein écran, posé entre le monde et le HUD, relit l'image du monde et la déforme :

| Effet | Quand | Rendu |
| :--- | :--- | :--- |
| Onde de choc | Renvoi, Nova, grande explosion, touche, changement de phase, mort d'un boss | Un anneau qui s'élargit depuis le point d'impact et pousse les pixels sur son passage. Quatre anneaux au plus en même temps. La Nova commence par une onde inversée, qui aspire |
| Aberration chromatique | Touche, Nova, changement de phase, mort d'un boss, fronde de 5 ennemis ou plus | Le rouge et le bleu s'écartent du centre vers les bords, puis se recalent en moins d'une demi-seconde |
| Vignette | Toujours | Les coins sont assombris ; au dernier point de coque, ils battent en rouge |

Le HUD est dessiné au-dessus du shader : les chiffres ne se déforment jamais.

### Musique (`music.gd`)

La musique est synthétisée au lancement, quelques milliers d'échantillons par image pour que
l'écran titre reste fluide : 8 mesures à 126 battements par minute en la mineur (accords la
mineur, fa, do, sol, joués deux fois), soit une boucle de 15,2 s. Elle compte deux couches de
même longueur qui tournent ensemble :

| Couche | Instruments | Volume |
| :--- | :--- | :--- |
| Calme | Nappe de dents de scie désaccordées, basse triangulaire sur les temps 1 et 3, charleston léger à contretemps | Toujours présente |
| Combat | Grosse caisse sur chaque temps, claquement sur 2 et 4, charleston en croches, basse pincée qui alterne fondamentale et octave, arpège aux mesures 5 à 8 | Muette sur l'écran titre ; pendant le jeu, 0,35 + balles ÷ 90 + ennemis ÷ 24, plafonné à 1 ; à fond contre un boss |

En pause et sur l'écran d'amélioration, la musique est assourdie : sur ordinateur par un filtre
passe-bas, dans la version web par une baisse de volume de 9 dB. Le navigateur joue les sons du
jeu comme des échantillons Web Audio : un bus audio créé pendant la partie y coupe tous les sons
et les effets de bus n'y fonctionnent pas. La version web garde donc la musique sur le bus
principal. Le menu **MUSIQUE** coupe la musique sans toucher aux bruitages.

### Game feel (`effects.gd`, `post_fx.gd`, `game_manager.gd`, `sfx_manager.gd`)

| Moment | Effets |
| :--- | :--- |
| Arrivée d'un ennemi | Chevron clignotant au bord, petit bip |
| Capture | Son dont la hauteur monte avec chaque balle de l'orbite, étincelles, le cercle de capture s'illumine |
| Renvoi | Onde visible et onde de choc à l'écran, grille qui ondule, vaisseau écrasé un instant, tremblement proportionnel au nombre de balles, son de fronde |
| Collision entre ennemis | « COLLISION », gerbe d'étincelles, arrêt sur image de 0,025 s |
| Touche sur un ennemi | Flash blanc, recul, étincelles projetées du côté de l'impact |
| Destruction | Explosion et débris aux couleurs de l'ennemi, points flottants, éclats ; pour un gros ennemi, onde de choc et arrêt sur image de 0,035 s |
| Palier de multiplicateur | Bip montant, la pastille grossit |
| Ramassage d'éclats | Notes qui montent tant que les éclats s'enchaînent |
| Frôlement | Souffle, étincelles blanches, « FRÔLÉ » pour une orbe lourde |
| Nova | Anneau qui se referme, flash violet, onde aspirante, spirale et particules aspirées pendant 1,2 s ; au relâchement, explosion de lumière, grande onde, aberration, tremblement fort |
| Touche sur la coque | Arrêt sur image de 0,08 s, flash rouge, aberration, fort tremblement ; au dernier point, battement de cœur et bords rouges |
| Changement de phase d'un boss | Annonce « PHASE 2 », flash, anneau, onde, arrêt sur image de 0,12 s |
| Mort d'un boss | Ralenti de 1,4 s, flash blanc, grande onde, toutes les balles ennemies éclatent, 40 éclats |
| Écrans | Le logo tombe lettre par lettre, les cartes montent l'une après l'autre, la carte choisie s'envole vers le HUD, le score de fin défile, le rang est tamponné |

Les 36 bruitages sont synthétisés au lancement (`sfx_manager.gd`), avec une légère variation de
hauteur à chaque lecture et un écart minimal entre deux lectures du même son.

### Interface (`ui_kit.gd`, `hud.gd`, `screens.gd`)

`ui_kit.gd` réunit ce que le HUD et les écrans partagent : la police du moteur épaissie par
`FontVariation` en trois graisses (le projet n'a pas de fichier de police), le texte détouré,
les panneaux aux coins coupés, les jauges à crans et les douze icônes animées des améliorations.
Le HUD vit sur la couche 2, au-dessus du shader ; les écrans sur la couche 3. Les écrans gèrent
eux-mêmes la souris (survol et clic sur les menus et les cartes) ; le clavier et la manette
passent par `game_manager.gd`.

### Saisie et sauvegarde (`input_manager.gd`, `game_manager.gd`)

`input_manager.gd` crée les actions au démarrage, avec les codes physiques des touches et les
boutons de souris. `game_manager.gd` enregistre le meilleur score, le meilleur secteur, la
langue, les bruitages et la musique dans `user://gravshift_save.json`.

---

## Architecture

`main.tscn` ne contient que le nœud racine avec `game_manager.gd` ; tout le reste est construit
par `game_manager._build_scene()`, comme l'exige `CONVENTION.md`.

```
Main (Node2D, game_manager.gd)        toujours actif, même en pause
├── InputManager (Node, input_manager.gd)
├── SfxManager (Node, sfx_manager.gd)
├── Music (Node, music.gd)             deux couches en boucle (bus « Music » sur ordinateur)
├── World (Node2D)                     secoué par les tremblements
│   ├── SpaceGrid (space_grid.gd)      grille, nébuleuses, étoiles
│   ├── Pickups (pickups.gd)           éclats et réparations
│   ├── Enemies                        ennemis (enemy_*.gd, boss_*.gd)
│   ├── Shots (shots.gd)               tirs et renvois du vaisseau
│   ├── EnemyBullets (bullet_field.gd) balles et orbes ennemies
│   ├── GravityField (gravity_field.gd) puits, orbite et Nova, mélange additif
│   ├── Player (player.gd)
│   └── Effects (effects.gd)           particules, débris, anneaux, chevrons, textes
├── Spawner (Node, spawner.gd)
├── Combat (Node, combat.gd)
├── PostFX (CanvasLayer 1)
│   └── Distortion (ColorRect, post_fx.gd)  ondes, aberration, vignette
├── UI (CanvasLayer 2)
│   └── HUD (Control, hud.gd)
└── Transitions (CanvasLayer 3)
    └── Screens (Control, screens.gd)  titre, aide, pause, améliorations et fin
```

| Dossier | Contenu |
| :--- | :--- |
| `datas/` | `settings.json` (réglages, ennemis, secteurs, rangs), `strings_fr.json` et `strings_en.json` (textes) |
| `scenes/core/` | `main.tscn` |
| `scripts/core/` | `game_manager.gd`, `input_manager.gd`, `sfx_manager.gd`, `music.gd`, `post_fx.gd`, `space_grid.gd`, `effects.gd`, `bullet_field.gd`, `shots.gd`, `gravity_field.gd`, `pickups.gd`, `spawner.gd`, `combat.gd`, `upgrades.gd` |
| `scripts/entities/` | `player.gd`, `enemy_base.gd`, `enemy_drone.gd`, `enemy_gunner.gd` (Artilleur), `enemy_swarm.gd` (Essaim), `enemy_spinner.gd` (Tourelle), `enemy_lancer.gd` (Lancier), `enemy_mine.gd`, `enemy_siphon.gd` (Siphon), `enemy_brute.gd` (Colosse), `boss_guardian.gd` (Gardien), `boss_singularity.gd` (Singularité) |
| `scripts/ui/` | `ui_kit.gd`, `hud.gd`, `screens.gd` |

Les états de jeu sont `TITLE`, `PLAYING`, `PAUSED`, `UPGRADE` (choix d'une amélioration entre
deux secteurs), `GAME_OVER` et `WIN`. L'écran « Comment jouer » est une page de l'état `TITLE`
(`help_open`). Quand la coque est détruite, le jeu reste 1,6 s en `PLAYING` avant de passer en
`GAME_OVER`.

---

## Signaux et flux de données

| Signal | Émetteur | Paramètres | Abonnés |
| :--- | :--- | :--- | :--- |
| `game_state_changed` | game_manager | `state: int` | hud (affiche ou masque le HUD), screens (relance l'animation d'entrée, active la souris sur les menus et les cartes) |
| `twist_activated` | gravity_field, à la première capture de la partie | aucun | game_manager (affiche l'astuce au-dessus du vaisseau) |

Les sous-systèmes appellent directement game_manager, qui les a créés et leur a donné une
référence (`gm`). Le flux d'une Nova :

1. Les éclats ramassés (`collect_pickup()`) et les frôlements (`on_graze()`) appellent
   `GravityField.add_nova()`. Quand la jauge atteint 100, `on_nova_ready()` joue le carillon.
2. Vous appuyez sur E : `game_manager._try_nova()` appelle `start_nova()`, rend le vaisseau
   intouchable et lance les effets d'ouverture.
3. Pendant 1,2 s, `bullet_field.step()` aspire toutes les balles orange vers l'orbite et les
   orbes lourdes proches vers `swallow()` ; `combat.gd` broie les ennemis qui touchent le vaisseau.
4. Le minuteur s'épuise : `release(false, true)` crée un tir `NOVA` par balle en orbite et
   appelle `on_release(..., true)`, qui applique la grande onde, l'aberration et le son.
5. Les impacts suivent le chemin d'un renvoi normal : `combat.gd`, `enemy_hit()`,
   `enemy_destroyed()`, puis le bonus de fronde multiple après 1,3 s.

---

## Comment tester le twist

1. **La première capture.** Choisissez **JOUER** et attendez le premier Artilleur (flèche
   orange, vers la 6e seconde ; un chevron orange annonce son entrée). Quand son éventail de
   trois balles arrive, maintenez Espace : les balles s'incurvent vers le vaisseau et se mettent
   en orbite. L'astuce « Balle capturée : relâchez pour la renvoyer » s'affiche, et le compteur
   **ORBITE** passe à 3/12.
2. **Le renvoi.** Relâchez Espace : les trois balles partent vers les ennemis les plus proches.
   Un Artilleur (10 points de vie) touché par les trois perd 9 points, ce que le tir
   automatique met près de 2 s à faire.
3. **La projection.** Au secteur 2, une nuée d'Essaim tourne autour de vous : ouvrez le puits,
   la nuée est aspirée, ses fléchettes se percutent ou s'usent dans l'orbite. « COLLISION »
   s'affiche à chaque choc assez rapide.
4. **La Nova.** Ramassez les éclats bleus que lâchent les ennemis. Quand la jauge de **NOVA**
   affiche « NOVA PRÊTE : E », attendez qu'une Tourelle remplisse l'écran de balles, puis
   appuyez sur E : toutes les balles sont aspirées, puis renvoyées d'un coup.
5. **Le Siphon.** Au secteur 4, un disque noir aspire les balles orange avant vous. Détruisez-le
   quand il est plein : ses balles partent en anneau et remplissent votre orbite.

---

## Paramètres configurables

Tout se règle dans `datas/settings.json`, sans toucher au code.

| Clé (`gameplay`) | Valeur | Effet |
| :--- | :---: | :--- |
| `player_speed`, `player_acceleration` | 330, 2 600 | Vitesse du vaisseau (px/s) et accélération (px/s²) |
| `well_speed_factor` | 0,6 | Part de la vitesse gardée puits ouvert |
| `player_radius` | 7 | Rayon du cœur touchable du vaisseau (px) |
| `player_hp`, `invulnerability_time` | 3, 1,6 | Points de coque au départ, invulnérabilité après une touche (s) |
| `fire_interval`, `bullet_speed`, `bullet_damage`, `bullet_homing` | 0,2, 820, 1, 5 | Tir automatique : intervalle (s), vitesse, dégâts, force du guidage |
| `flux_max`, `flux_drain`, `flux_regen`, `flux_regen_delay` | 100, 28, 22, 0,35 | Réserve de flux, consommation et recharge par seconde, attente avant recharge (s) |
| `flux_per_capture`, `flux_min_to_open` | 5, 12 | Flux rendu par capture, flux minimum pour ouvrir le puits |
| `pull_radius`, `capture_radius` | 230, 74 | Rayons d'attraction et de capture (px) |
| `bullet_pull`, `enemy_pull`, `passive_pull` | 1 400, 900, 120 | Forces d'attraction sur les balles, sur les ennemis (puits ouvert) et attraction permanente |
| `orbit_capacity`, `orbit_radius`, `orbit_speed` | 12, 48, 4,2 | Capacité de l'orbite, rayon (px), vitesse de rotation (rad/s) |
| `sling_speed`, `sling_damage`, `sling_homing` | 780, 3, 7 | Renvois : vitesse, dégâts, force du guidage |
| `shockwave_radius` | 130 | Rayon de l'onde du relâchement (px) |
| `crash_speed`, `crash_damage` | 150, 3 | Vitesse relative minimale d'une collision entre ennemis, dégâts à cette vitesse |
| `enemy_bullet_speed`, `heavy_bullet_speed` | 190, 150 | Vitesse des balles orange et des orbes lourdes |
| `chain_window`, `chain_per_multiplier`, `multiplier_max` | 2,5, 5, 8 | Minuteur de la chaîne (s), destructions par cran, multiplicateur maximal |
| `multikill_bonus` | 60 | Bonus de fronde multiple, multiplié par n² |
| `shard_life`, `shard_magnet`, `shard_pull` | 7, 120, 2 400 | Durée de vie d'un éclat (s), rayon de l'aimant (px), accélération vers le vaisseau (px/s²) |
| `shard_points`, `shard_nova` | 10, 1,4 | Points et charge de Nova par éclat |
| `shards_per_points`, `shards_max`, `boss_shards`, `boss_shard_chance` | 40, 14, 40, 0,15 | Un éclat par tranche de points, plafond par ennemi, éclats d'un boss, probabilité d'arracher un éclat à un boss par renvoi |
| `nova_max`, `nova_duration`, `nova_capacity` | 100, 1,2, 60 | Taille de la jauge, durée de la Nova (s), capacité de l'orbite pendant la Nova |
| `nova_pull`, `nova_swallow_radius` | 2 600, 260 | Attraction des balles pendant la Nova, rayon où les orbes lourdes sont avalées (px) |
| `nova_damage_mult`, `nova_shockwave_mult` | 1,5, 2,2 | Multiplicateurs des dégâts des renvois et du rayon de l'onde à la fin de la Nova |
| `graze_radius`, `graze_points` | 24, 25 | Largeur de l'anneau de frôlement (px), points par frôlement |
| `graze_nova_pellet`, `graze_nova_heavy` | 1,5, 5 | Charge de Nova par balle orange et par orbe lourde frôlée |
| `repair_drop_chance`, `repair_life` | 0,06, 9 | Probabilité de lâcher une réparation, durée de vie de la croix (s) |
| `music_volume_db` | −15 | Volume de la musique (dB) |
| `shake_decay`, `shake_pixels` | 2,4, 14 | Amortissement et amplitude maximale du tremblement |

La section `enemies` donne pour chaque ennemi `hp`, `mass`, `radius`, `speed`, `points`,
`color` et, selon le cas, `fire_interval`, `fuse` (Mine), `pull_radius` et `store_max` (Siphon).
La section `waves` décrit les 10 secteurs (voir **Secteurs**), `upgrades` la liste des
améliorations proposées et `ranks` les seuils de rang, du meilleur au moins bon.

---

## Lancement

1. Ouvrez le dossier `gravshift` dans Godot 4.4 ou plus récent (testé avec 4.4.1 et 4.7).
2. Lancez la scène principale (`F5`) : elle est déjà réglée sur `scenes/core/main.tscn`.
3. Pour la version web, utilisez le préréglage d'export **Web** : il écrit dans le dossier `web`
   du projet, vers lequel pointe la page html.

Le test fonctionnel vérifie la structure du projet, la cohérence de `settings.json`, la présence
de chaque texte dans les deux langues et plusieurs règles de la convention :

```
python test_functional.py
```
