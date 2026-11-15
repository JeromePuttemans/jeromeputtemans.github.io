# Les Clés du Gouffre : roguelike Godot 4

Un roguelike au tour par tour, piloté par les données. Vous descendez cinq étages générés
procéduralement. L'escalier de chaque étage est fermé par une grille, et sa clé est entre les
mains d'un chapardeur qui erre dans l'étage et s'enfuit dès qu'il vous voit : il faut
l'entendre, suivre ses traces, le coincer ou l'atteindre à la dague. Au dernier étage, c'est
le Gardien qui porte la clé du portail de sortie. La mort est définitive : chaque partie
repart de zéro, sur un donjon différent. Une partie dure de 10 à 20 minutes.

Le template ne contient aucun fichier graphique ni sonore. Les créatures, les objets et le
décor sont du pixel art 16 × 16 décrit en texte dans `data/sprites.json` et transformé en
textures au démarrage ; les dalles et les murs sont peints par code avec les couleurs de
l'étage ; les bruitages sont synthétisés par l'autoload `Sfx`. Toutes les valeurs de jeu
vivent dans les fichiers JSON du dossier `data/`.

---

## Comment jouer

| Action | Clavier | Souris |
| :--- | :--- | :--- |
| Se déplacer (8 directions) | Flèches, pavé numérique, ou le bloc ZQSD + AEWC (WASD + QEZC en QWERTY) | |
| Attaquer | Se déplacer vers l'ennemi | |
| Briser un tonneau | Se déplacer vers le tonneau | |
| Lancer une dague | `F` : vise le chapardeur s'il est à portée, sinon l'ennemi le plus proche | Clic droit sur un ennemi |
| Attendre un tour (se reposer) | `Espace`, `5` du pavé numérique | |
| Utiliser un objet | `1` à `6` | Clic sur la case de l'inventaire |
| Poser un objet au sol | `Maj` + `1` à `6` | Clic droit sur la case de l'inventaire |
| Descendre l'escalier, prendre le portail | `Entrée`, debout sur la case, grille ouverte | |
| Observer une case | | Survol |
| Couper le son | `M` | Bouton haut-parleur |
| Rejouer après la fin | `R` | Bouton **Rejouer** |

Les lettres et les chiffres sont lus par position physique : sur un clavier AZERTY, le bloc de
déplacement est ZQSD et les touches `1` à `6` marchent sans `Maj`. L'aide en bas du panneau
affiche les lettres de votre clavier. Maintenir une touche répète l'action : on traverse une
salle ou on se repose en gardant la touche enfoncée.

Le déroulé d'un étage :

1. Explorez. Le journal en bas de l'écran raconte chaque événement, en couleur : blanc pour
   vos coups, rouge pour ceux que vous recevez, vert pour les soins, or pour le butin, violet
   pour les niveaux, orange pour les alertes, cyan pour les indications.
2. Ramassez les objets en marchant dessus. Les améliorations (pierre à aiguiser, plaque
   d'armure, cristal de vie) et les dagues s'appliquent tout de suite ; les autres objets vont
   dans l'inventaire, limité à 6 places.
3. Trouvez le chapardeur et tuez-le : il lâche la clé. Ramassez-la en marchant dessus.
4. Marchez sur l'escalier avec la clé : la grille se lève. Appuyez ensuite sur `Entrée` pour
   descendre. Marcher sur l'escalier ne fait pas descendre : vous pouvez finir d'explorer.
5. À l'étage 5, l'escalier est remplacé par le portail de sortie, et le Gardien en porte la
   clé. Le prendre termine la partie par une victoire.

Le panneau de droite affiche les barres de PV, d'énergie et d'XP, le niveau, l'attaque (ATT),
la défense (DEF) et le numéro du tour. Juste en dessous, la ligne de la clé dit où en est
votre recherche (« Clé : des clés tintent vers l'est. », « Clé en poche. À l'escalier. ») et
le compteur de dagues (« 2/5 »). Suivent l'inventaire, la case observée et la minicarte.
Survolez un ennemi pour voir ses PV, ses caractéristiques et ce qu'il fait ; survolez la ligne
de la clé ou les dagues pour en lire les règles.

---

## Trouver la clé

### Le chapardeur

Sur les étages 1 à 4, un chapardeur part d'une salle éloignée du départ (au moins 40 % de la
plus longue marche de l'étage), jamais celle de l'escalier. Il a 8 PV, 2 d'attaque et 0 de
défense à l'étage 1, et rapporte 10 XP. Il porte une petite clé dorée au-dessus de la tête.

| Son état | Ce qu'il fait | Ce que vous voyez |
| :--- | :--- | :--- |
| Il erre | Il marche de salle en salle et s'arrête souvent (4 tours sur 10). | Rien de spécial. Il ne dort jamais. |
| Il fuit | Dès qu'il vous voit à 7 cases ou moins, il détale vers les couloirs qui offrent une sortie. | Un « ! » violet, le message « Le chapardeur vous voit et détale. » |
| Il est épuisé | Après 9 pas de fuite, il reste sur place 4 tours. Il vous frappe si vous êtes au contact. | Des gouttes de sueur, le message « Le chapardeur est hors d'haleine. » |

Le compte des pas de fuite ne repart pas de zéro quand il vous perd de vue : il baisse de 1
par tour où il ne vous voit pas. Le surprendre souvent l'épuise donc plus vite qu'une seule
longue poursuite.

Tant qu'il n'est pas épuisé, il esquive une dague sur deux (« Esquive » s'affiche au-dessus de
lui). Une fois épuisé, il ne peut plus esquiver. C'est le moment de frapper : il ne se défend
qu'au contact, avec 2 points d'attaque.

### Les trois indices

| Indice | Quand | Où le lire |
| :--- | :--- | :--- |
| Les clés qui tintent | Le chapardeur est hors de vue et à 18 pas ou moins, comptés à pied (les murs étouffent le son : une salle voisine à travers un mur épais peut être à 30 pas). | Une petite clé et des ondes autour de vous, tournées vers lui, plus vives quand il est proche ; un tintement tous les 3 tours ; la ligne de la clé (« des clés tintent vers le nord-est ») ; un message dans le journal la première fois. |
| Les traces de pas | Chaque pas du chapardeur laisse une empreinte qui s'efface en 40 tours. | Des empreintes violettes pâles sur le sol des cases que vous voyez. Survolez-en une : « Le chapardeur est passé ici il y a 12 tours, vers l'ouest. » |
| La vue | Il est dans votre champ de vision. | Le sprite encapuchonné avec sa clé, en violet sur la minicarte. |

### Les dagues

Vous partez avec 2 dagues et pouvez en porter 5. Une dague atteint un ennemi visible à 6 cases
ou moins, sans mur entre vous. Elle frappe avec votre attaque moins 2, puis la formule de
combat habituelle s'applique (voir plus bas). Elle tombe là où elle frappe : ramassez-la en
marchant dessus. Lancer une dague coûte un tour.

Exemple à l'étage 1 : avec ATT 5, une dague frappe à 3, soit 2 à 4 dégâts contre le
chapardeur. Il faut 2 à 4 dagues qui touchent pour ses 8 PV, et il en esquive une sur deux.
Au corps à corps, vos coups font 4 à 6 dégâts : deux suffisent. Les dagues servent surtout à
l'affaiblir pendant qu'il fuit, puis à l'achever quand il est épuisé.

Sans dague en main, `F` affiche « Plus de dagues : ramassez celles que vous avez lancées. » et
le tour n'est pas joué. Sans cible à portée, même chose avec « Aucun ennemi visible à 6 cases
ou moins. »

### La clé et la grille

Le chapardeur lâche la clé en mourant, sur sa case ou sur la case libre la plus proche. Un
rayon doré la signale, elle clignote en or sur la minicarte. Marcher sur l'escalier avec la
clé l'utilise : la grille se lève, la ligne de la clé passe au vert (« Grille ouverte. Entrée
pour descendre. ») et l'escalier devient doré sur la minicarte.

Au dernier étage, il n'y a pas de chapardeur : le Gardien porte la clé du portail. Il faut
donc l'abattre pour sortir.

---

## Vocabulaire

| Terme | Sens dans ce projet | Exemple |
| :--- | :--- | :--- |
| Tour | Une action du joueur, suivie de la réponse de tous les ennemis. | Marcher, attaquer, lancer une dague, attendre, boire une potion. |
| Case | Une cellule de la grille, 32 px de côté (`tile_size`). | La carte fait 50 × 30 cases. |
| Distance de Tchebychev | `max(|dx|, |dy|)` : le nombre de pas de roi aux échecs. Un pas en diagonale vaut un pas droit. | Un ennemi en diagonale est à distance 1, donc au contact. |
| Distance à pied | Le nombre de pas pour atteindre une case en contournant les murs et les tonneaux. | Deux salles séparées par un mur sont proches à vol d'oiseau, loin à pied. |
| Champ de vision | Les cases que le joueur voit ce tour-ci, dans un rayon de 8 cases, murs exclus. | Un ennemi hors du champ n'est pas dessiné. |
| Case explorée | Une case vue au moins une fois sur l'étage. Elle reste dessinée, en bleu sombre. | Le plan reste affiché ; les ennemis qui s'y déplacent n'y apparaissent plus. |
| Vigilance | Un ennemi est endormi (un « z » flotte au-dessus) ou vous traque (un « ! » apparaît quand il vous repère). | Un orc endormi ne bouge pas tant qu'il ne vous voit pas. |
| Points d'action | Réserve qui détermine combien de fois un ennemi agit par tour. | Une chauve-souris agit 2 fois par tour, un troll 1 tour sur 2. |
| Grille | La herse qui ferme l'escalier (ou le portail) tant que vous n'avez pas la clé de l'étage. | Appuyer sur `Entrée` grille fermée affiche « La grille est fermée. Il faut la clé du chapardeur. » |
| Carte de fuite | La carte de distances qui guide le chapardeur loin de vous (voir les principes algorithmiques). | Il préfère un couloir qui mène ailleurs à un cul-de-sac plus éloigné. |

---

## Les ennemis

Huit ennemis ordinaires, le chapardeur et un boss. Chaque type ordinaire n'apparaît qu'entre
deux étages (`min_floor`, `max_floor`) ; un poids (`weight`) règle sa fréquence parmi les types
autorisés. Chaque créature est un sprite de pixel art, tourné dans le sens de sa marche.

| Ennemi | Étages | PV | ATT | DEF | XP | Particularité |
| :--- | :---: | ---: | ---: | ---: | ---: | :--- |
| Rat | 1-2 | 6 | 3 | 0 | 2 | |
| Chauve-souris | 1-3 | 4 | 2 | 0 | 2 | Rapide (2 actions par tour), vol erratique |
| Archer gobelin | 2-5 | 8 | 2 | 0 | 5 | Tire à 5 cases (3 dégâts) s'il vous voit |
| Orc | 2-5 | 14 | 5 | 1 | 6 | |
| Gelée | 2-5 | 12 | 3 | 0 | 3 | Se divise quand un coup ne la tue pas |
| Squelette | 3-5 | 13 | 6 | 1 | 8 | Se relève de ses os |
| Troll | 3-5 | 26 | 8 | 2 | 14 | Lent (1 action tous les 2 tours) : on peut le distancer |
| Chapardeur | 1-4 | 8 | 2 | 0 | 10 | Un par étage, porte la clé, fuit (voir plus haut) |
| Le Gardien | 5 | 80 | 12 | 3 | 50 | Boss, posté près du portail, porte la clé du portail |

**La gelée.** Quand un coup la laisse en vie avec 4 PV ou plus, la moitié de ses PV (arrondie
à l'entier inférieur) part dans une nouvelle gelée, sur une case libre voisine. Exemple : une
gelée à 12 PV prend 4 dégâts ; il lui reste 8 PV, elle se divise en deux gelées de 4 PV. Une
gelée à 3 PV ne se divise plus. Chaque petite gelée rapporte la moitié de l'XP de sa mère.

**Le squelette.** Il laisse un tas d'os en mourant. Sept tours plus tard, il se relève avec 60
% de ses PV max, une seule fois. Marchez sur les os avant pour les briser. Les os remuants
luisent en vert et tremblent quand il ne reste que 2 tours ; survolez-les pour lire le compte
(« Le squelette se relève dans 3 tours. »). Une créature debout sur les os retarde le réveil.

Les valeurs du tableau sont celles de l'étage 1. Plus bas, chaque ennemi ordinaire (chapardeur
compris) gagne 12 % de ses PV de base et 1 point d'attaque par étage, arrondi à l'entier
inférieur (`enemy_hp_per_floor`, `enemy_attack_per_floor`) :

| Ennemi | Étage 3 | Étage 5 |
| :--- | :--- | :--- |
| Orc | 17 PV, ATT 7 | 21 PV, ATT 9 |
| Squelette | 16 PV, ATT 8 | 19 PV, ATT 10 |
| Troll | 32 PV, ATT 10 | 38 PV, ATT 12 |
| Archer gobelin | 10 PV, tir 5 | 12 PV, tir 7 |
| Chapardeur | 10 PV, ATT 4 | sans objet (pas de chapardeur à l'étage 5) |

Le Gardien n'est pas concerné : ses valeurs sont réglées directement dans `enemies.json`.

Le nombre d'ennemis augmente aussi avec la profondeur : chaque salle (sauf la salle de départ)
en reçoit de 0 à 2, plus 0,5 par étage au-delà du premier. La partie fractionnaire est une
chance : à l'étage 2, le bonus de 0,5 ajoute un ennemi dans une salle sur deux. À l'étage 5, le
bonus vaut 2 : chaque salle reçoit de 2 à 4 ennemis. Aucun ennemi n'apparaît à moins de 6 cases
du point de départ.

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
| Dague de lancer | Dague | Une dague de plus, jusqu'à 5 | 1+ | 3 |
| Clé | Clé | Ouvre la grille de l'étage | lâchée par le porteur | 0 |

Les trois parchemins partagent un dessin ; seul le sceau change de couleur (bleu pour la
foudre, violet pour la téléportation, beige pour la carte).

Utiliser un objet coûte un tour. Un objet qui n'aurait aucun effet n'est pas consommé : une
potion bue à PV pleins, une ration mangée sans faim, un parchemin de foudre sans ennemi à
portée restent dans l'inventaire, et le tour n'est pas joué.

Quand l'inventaire est plein, l'objet reste au sol. Posez-en un autre (`Maj` + chiffre) pour
faire de la place : c'est là que la limite de six cases oblige à choisir. Une dague au sol
reste aussi en place quand vous en portez déjà 5.

---

## Le décor

| Élément | Nombre | Rôle |
| :--- | :--- | :--- |
| Tonneau | 4 à 8 par étage, contre le mur d'une salle | Bloque le passage. Foncez dedans pour le briser (un tour). Dans 30 % des cas il contient un objet : ration (45 % de ces cas), dague (25 %), potion (15 %) ou un objet tiré dans la table de l'étage (15 %). |
| Torche murale | Une dans 3 salles sur 4, deux dans les salles d'au moins 7 cases de large | Éclaire la salle à 4,5 cases, sans traverser les murs. |
| Ossements | 5 à 10 par étage | Décor seul. Rien à voir avec les os d'un squelette abattu, qui luisent en vert. |

Un tonneau n'est jamais posé à côté d'un couloir, et le générateur vérifie qu'aucune case du
sol ne devient inaccessible sans le briser.

---

## Ressources : PV, énergie, niveaux

### L'énergie, horloge de nourriture

L'énergie part de 100. Elle baisse de 1 tous les 5 tours : sans manger, elle tient 500 tours.

- Tant qu'elle est au-dessus de 0, vous regagnez 1 PV tous les 5 tours.
- À 0, vous ne regagnez plus rien et perdez 1 PV tous les 4 tours.
- À 25 ou moins, le journal vous prévient et la barre passe à l'orange.

Se reposer soigne, mais coûte de la nourriture. Exemple : attendre 50 tours rend 10 PV et
consomme 10 points d'énergie, soit un sixième de ration. Une partie dure environ 1 500 tours,
donc 300 points d'énergie : la réserve de départ et 3 ou 4 rations suffisent. La chasse au
chapardeur prend du temps (une centaine de tours par étage pour le bot de test) : une
poursuite qui s'éternise se paie en nourriture.

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
`max(1, jet - DEF de la cible)`. Vos coups, dagues comprises, ont 10 % de chances d'être
critiques : les dégâts sont alors doublés, après la DEF.

Exemples : avec ATT 5, vous infligez 4 à 6 dégâts à un rat (DEF 0), qui tombe en un ou deux
coups. Un orc de l'étage 5 (ATT 9) vous inflige 4 à 6 dégâts si vous avez 4 de DEF. Le minimum
de 1 garantit qu'un combat avance toujours.

---

## Comment ces valeurs ont été réglées

Les valeurs ont été ajustées en faisant jouer des parties complètes à un bot, dans le jeu
lui-même (sans affichage), avec des graines aléatoires fixes. Le bot explore jusqu'aux zones
inconnues, ramasse les objets, boit une potion sous 40 % de PV, mange sous 15 d'énergie, se
repose hors combat sous 60 % de PV, utilise la foudre contre deux ennemis proches et la
téléportation en danger. Pour la clé, il poursuit le chapardeur quand il le voit ou l'entend,
suit les traces fraîches, lance ses dagues sur lui, et sur les autres ennemis à 2 cases ou plus
quand il en a au moins deux. Il brise les os des squelettes et la moitié des tonneaux qu'il
longe.

Quand il entend les clés, le bot cherche son chemin vers le chapardeur à travers les cases
qu'il n'a pas encore vues : c'est une approximation de ce que fait un joueur qui suit le son,
un peu plus efficace que lui.

| Mesure | Version précédente (sans clé) | Premier jet avec la clé | Valeurs actuelles |
| :--- | ---: | ---: | ---: |
| Parties jouées | 40 | 20 | 40 |
| Victoires | 18 | 20 | 25 |
| Durée moyenne | 1 501 tours | 1 484 tours | 1 481 tours |
| Niveau en fin de partie gagnée | 8 à 10 | 9 à 12 | 10 à 12 |
| Tours pour obtenir une clé (moyenne) | sans objet | 92 | 104 |
| Morts causées par le Gardien | 4 | 0 | 5 |

Au premier jet, le bot gagnait toutes ses parties. Trois choses le rendaient trop fort : les
dagues, qui reviennent après chaque combat (environ 90 lancers par partie) ; le butin des
tonneaux, qui sortait dans 45 % des cas ; les gelées et les squelettes, plus faciles que les
orcs et les archers qu'ils remplacent en partie dans la table de tirage. Les corrections :
esquive d'une dague sur deux pour le chapardeur qui n'est pas épuisé, dagues à ATT - 2 au lieu
de ATT - 1, butin des tonneaux à 30 %, potions plus rares dans les tonneaux, 0,5 ennemi
supplémentaire par salle et par étage au lieu de 0,25, 1 point d'attaque ennemie par étage au
lieu de 0,75.

Ce qu'il faut en retenir : les 15 défaites des 40 parties se concentrent à l'étage 5 (11), avec
des causes variées : le Gardien 5, les archers 3, les orcs 2, les squelettes 2, la faim 2, un
troll. Aucun étage ne bloque le bot : il n'est jamais resté coincé faute de trouver le
chapardeur (une sécurité arrêtait la partie au-delà de 2 500 tours sur un étage). Il gagne plus
souvent que la version précédente parce qu'il dispose des dagues et qu'il triche un peu en
suivant le son ; un joueur qui casse la ligne de vue des archers et combat dans les couloirs
fait mieux que lui.

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
   créent des boucles : on peut tourner autour d'un troll, et le chapardeur aussi peut vous
   échapper en tournant en rond.
4. Le joueur part du centre de la première salle. L'escalier va au centre de la salle la plus
   éloignée **à pied**, mesurée par un parcours en largeur depuis le départ : chaque étage
   doit être traversé.
5. Les ennemis, le chapardeur (ou le Gardien au dernier étage) et les objets sont posés sur des
   cases libres, jamais deux sur la même case.
6. Le décor vient en dernier : tonneaux, torches, ossements. Chaque tonneau posé déclenche un
   parcours en largeur depuis le départ ; si une case du sol devient inaccessible, le tonneau
   est retiré.

Le générateur est une fonction pure : il reçoit la configuration, le numéro d'étage, un
générateur aléatoire et deux fonctions de tirage (`Callable`), et rend un `DungeonData`. Il ne
dépend d'aucun autoload, ce qui permet de le tester seul.

### 2. Champ de vision : lancer de rayons de Bresenham

Pour chaque case à 8 cases ou moins (distance euclidienne), `FOVSystem` trace une ligne de
Bresenham depuis le joueur. Si une case intermédiaire est un mur, la cible n'est pas visible ;
sinon elle l'est, même si c'est un mur (on en voit la face). Les tonneaux ne bloquent pas la
vue. Le coût est d'environ 200 cibles × 8 pas par tour, négligeable.

Deux couches : `visible[x][y]`, recalculé à chaque tour, et `explored[x][y]`, qui garde tout
ce qui a été vu sur l'étage. `FOVSystem.has_los()` sert aussi aux archers et aux dagues : un
tir ne part que si aucun mur ne sépare le tireur de sa cible.

### 3. La machine à tours

`GameState.player_action(direction)` résout une action complète :

1. l'action du joueur : déplacement, attaque si un ennemi occupe la case visée, bris d'un
   tonneau, attente ; `throw_dagger()` et `use_item()` passent par le même chemin ;
2. les besoins : énergie, régénération ou faim (`_tick_needs`) ;
3. le nouveau champ de vision ;
4. le tour de chaque ennemi, puis le réveil des squelettes et l'écoute des clés ;
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
frappé. Le tour où il vous repère, il ne fait qu'afficher son « ! » : vous avez toujours un
tour pour réagir à une nouvelle menace. Quand il vous perd de vue, il continue de vous traquer
pendant 8 tours (`alert_memory_turns`), puis se rendort.

**Carte de distances (« Dijkstra map », popularisée par Brogue).** Au début de chaque tour
ennemi, un seul parcours en largeur part du joueur et calcule, pour chaque case accessible, sa
distance à pied (8 directions). Pour se rapprocher, un ennemi fait un pas vers la case voisine
la plus basse qui n'est pas occupée. Ce calcul unique sert à tous les ennemis : ils
contournent les murs, prennent les couloirs, et se répartissent autour du joueur au lieu de
se bloquer l'un derrière l'autre.

**Carte de fuite (même source).** Fuir en maximisant simplement la distance mène au coin le
plus éloigné, souvent un cul-de-sac où la proie se fait coincer. `DijkstraMap.flee()` part de
la carte de distances, multiplie chaque valeur par -1,2, puis relâche la carte pour qu'aucune
case ne dépasse sa voisine la plus basse de plus de 1. En descendant cette carte, le chapardeur
s'éloigne de vous, mais préfère un couloir qui continue à un cul-de-sac un peu plus lointain.
Le facteur 1,2 règle ce compromis. À 1, la carte serait la simple inversion des distances et
le mènerait au point le plus éloigné, souvent un cul-de-sac. Au-delà de 1, la relaxation crée
des pentes vers les passages qui débouchent ailleurs, quitte à le faire passer un peu plus
près de vous ; plus le facteur est grand, plus il prend ce risque.

**Comportements** (champ `ai`) :

| Valeur | Comportement |
| :--- | :--- |
| `melee` | Descend la carte de distances, attaque au contact |
| `erratic` | Une action sur deux est un pas au hasard, les autres comme `melee` |
| `ranged` | Tire si le joueur est à portée et en ligne de vue, sinon se rapproche |
| `thief` | Géré par `GameState._thief_act` : erre vers des centres de salle tirés au hasard (sa propre carte de distances, recalculée à chaque nouvelle destination), fuit par la carte de fuite, s'épuise, laisse des traces |

### 6. Index spatial

`enemy_positions` associe chaque case occupée à son ennemi : savoir si une case est libre se
fait en une lecture. L'invariant : cet index reflète exactement la liste `enemies`, mis à jour
à chaque déplacement, à chaque mort, à chaque division de gelée et à chaque squelette relevé.

### 7. Graine aléatoire

Tout le hasard de la logique (génération, combat, IA, butin) passe par un seul
`RandomNumberGenerator`. `GameState.new_game(graine)` avec une graine fixe rejoue exactement la
même partie pour les mêmes actions : c'est ce qui a permis de comparer les réglages sur les
mêmes donjons.

### 8. Logique instantanée, rendu qui rattrape

`GameState` résout un tour entier en un appel, puis émet un signal par événement :
`entity_moved`, `entity_attacked`, `entity_died`, `projectile_fired`, `enemy_alerted`,
`item_picked`, `item_used`, `spell_hit`, `player_leveled`, `wall_bumped`, `key_dropped`,
`key_picked`, `stairs_unlocked`, `stairs_refused`, `dagger_thrown`, `dagger_dodged`,
`barrel_broken`, `enemy_split`, `bones_crushed`, `skeleton_rose`, `thief_panicked`,
`thief_tired`, `keys_heard`. `DungeonView` garde pour chaque créature une position dessinée,
qui rejoint la position logique par lissage exponentiel, et transforme chaque signal en
animation, particules, son et secousse. Les animations ne bloquent jamais la saisie : on peut
enchaîner les touches, le rendu suit.

### 9. Pixel art et lumière

`PixelArt` lit `data/sprites.json` : chaque dessin est une grille de 16 lignes de 16
caractères, un caractère par pixel, « . » pour le transparent. Au premier usage, chaque image
devient une texture, plus une silhouette blanche de même forme pour l'éclair d'un coup reçu.
Un dessin à une seule image reçoit une seconde image calculée : tout ce qui est au-dessus des
pieds descend d'un pixel, ce qui donne la respiration. Les textures sont dessinées à 32 × 32
avec un filtrage au plus proche : chaque pixel reste un carré net de 2 × 2.

`TileArt` peint à chaque étage quatre variantes de dalles, le dessus des murs et la face des
murs avec les quatre couleurs du thème (`floor_themes`). La variante d'une dalle dépend d'un
hachage de sa position : le sol ne montre aucune répétition visible, et chaque case garde la
même dalle d'une image à l'autre.

Chaque case visible est teintée par deux sources : la torche du joueur, qui baisse avec la
distance, et les torches murales, dont la carte de lumière est calculée une fois par étage
(une case n'est éclairée que si la torche la voit). Les cases explorées hors de vue sont
dessinées en bleu sombre.

### 10. Défauts corrigés de la version initiale

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
| Glissement et petit saut des déplacements | `DungeonView._process` | Le mouvement, sans saut de case en case. L'ombre reste au sol pendant le saut ; un écrasement marque l'atterrissage. Une téléportation se fait d'un coup, avec deux éclats violets. |
| Sprites tournés dans le sens de la marche, respiration | `Entity.facing`, `PixelArt` | Qui regarde qui. Les ailes de la chauve-souris et la gelée ont deux images dessinées à la main. |
| Fente, recul, flash blanc, chiffres de dégâts | `DungeonView._on_entity_attacked` | Qui frappe qui, et que le coup porte. Un critique s'affiche en or, plus gros, avec une onde. |
| Tremblement d'écran par « trauma » | `GameCamera.gd` | La gravité d'un coup reçu : l'amplitude dépend de la part des PV perdue. Petites secousses aussi pour un tonneau brisé ou une mort. |
| Vignettage rouge | `GameHUD._setup_vignette` | Un coup reçu (flash), puis des PV bas (pulsation à 30 % des PV max ou moins). |
| Lumière de torche, torches murales | `DungeonView._tile_mod`, `_draw_torch` | Le rayon de vision, la chaleur des salles éclairées. Les flammes vacillent, des étincelles montent. |
| Ondes et clé autour du joueur, tintement | `DungeonView._draw_key_hint`, `Sfx` « jingle » | D'où vient le son des clés et à quelle distance. |
| Empreintes qui pâlissent | `DungeonView._draw_footprints` | Le passage du chapardeur, et depuis combien de temps. |
| Clé au-dessus du porteur, réticule de visée | `_draw_enemy_marks`, `_draw_aim` | Qui porte la clé ; quel ennemi `F` va viser (réticule doré sur le chapardeur). |
| Dague en vol, « Esquive », gouttes de sueur | `_draw_missile`, `_on_dagger_dodged` | Le lancer, l'esquive du chapardeur, son épuisement. |
| Rayon doré, grille qui se lève et tremble | `_on_key_dropped`, `_draw_stairs` | La clé tombée ; l'escalier qui s'ouvre, ou qui refuse sans clé. |
| Os qui luisent et tremblent | `_draw_floor_things` | Le squelette va se relever, et bientôt. |
| Thèmes d'étage | `config.json`, `floor_themes` | La profondeur : caves bleues, grottes brunes, crypte violette, forge rouge, salle du trône dorée. |
| « z » et « ! » | `_draw_enemy_marks`, `_on_enemy_alerted` | La vigilance de chaque ennemi. |
| Barre de vie retardée | `GameHUD.StatBar` | La partie blanche montre ce que le dernier coup a coûté. |
| Bannière et fondu d'étage | `GameHUD._on_dungeon_ready` | L'arrivée à un nouvel étage et son nom. |
| Sons synthétisés | `Sfx.gd` | Pas, coups, critique, alerte, flèche, potion, foudre, niveau, escalier, boss, clés, grille, dague, tonneau, gelée, os. |

---

## Architecture

```
roguelike/
├── data/
│   ├── config.json        réglages globaux et thèmes d'étage
│   ├── enemies.json       types d'ennemis
│   ├── items.json         objets et améliorations
│   ├── sprites.json       pixel art : palettes et images 16 × 16
│   ├── strings_en.json    textes en anglais
│   └── strings_fr.json    textes en français
├── autoloads/
│   ├── ConfigManager.gd   lit config.json
│   ├── StringManager.gd   traductions, signal language_changed
│   ├── EnemyDatabase.gd   lit enemies.json, tirage par étage
│   ├── ItemDatabase.gd    lit items.json, tirage, noms et descriptions
│   ├── Sfx.gd             synthèse et lecture des bruitages
│   └── GameState.gd       machine à tours, clé et chapardeur, objets, signaux
├── scripts/               logique pure, sans node (sauf Fx et GameCamera)
│   ├── DungeonData.gd     grille, cases explorées, objets, tonneaux, torches, traces
│   ├── DungeonGenerator.gd
│   ├── DijkstraMap.gd     carte de distances et carte de fuite
│   ├── Entity.gd / PlayerEntity.gd / EnemyEntity.gd
│   ├── FOVSystem.gd       champ de vision, ligne de vue
│   ├── CombatSystem.gd    formule de dégâts
│   ├── AISystem.gd        décision des ennemis (sauf le chapardeur)
│   ├── PixelArt.gd        textures des sprites à partir de sprites.json
│   ├── TileArt.gd         dalles et murs peints selon le thème de l'étage
│   ├── Sprites.gd         police grasse, portail de sortie animé
│   ├── Fx.gd              particules, ondes, traînées, textes flottants
│   └── GameCamera.gd      caméra qui suit le joueur, secousses
└── scenes/
	├── Main.tscn / Main.gd   saisie, caméra, fin de partie
	└── ui/
		├── DungeonView.gd    rendu, lumière et animations
		├── HUD.gd            panneau latéral, ligne de la clé, bannière, écran de fin (classe GameHUD)
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

`Main.gd` appelle aussi `throw_dagger()` sur `F` et `throw_dagger(case)` sur un clic droit
dans la carte.

Signaux d'état de `GameState`, qui rafraîchissent l'affichage : `run_started`,
`dungeon_ready`, `turn_ended`, `stats_changed`, `message_added(texte, nature)`,
`player_died`, `player_won`.

---

## Modifier les données

### config.json

| Clé | Effet | Valeur |
| :--- | :--- | ---: |
| `default_language` | Langue au démarrage | `"fr"` |
| `dungeon_width`, `dungeon_height` | Taille de la carte en cases | 50, 30 |
| `tile_size` | Côté d'une case en pixels (gardez un multiple de 16 pour le pixel art) | 32 |
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
| `enemies_bonus_per_floor` | Ennemis ajoutés par salle et par étage | 0,5 |
| `enemy_hp_per_floor` | Hausse des PV ennemis par étage | 0,12 |
| `enemy_attack_per_floor` | Hausse de l'attaque ennemie par étage | 1 |
| `enemy_safe_radius` | Aucun ennemi à cette distance du départ | 6 |
| `items_per_floor_min`, `items_per_floor_max` | Objets par étage | 3, 5 |
| `alert_memory_turns` | Tours de traque après avoir perdu le joueur de vue | 8 |
| `thief_flee_range` | Distance à laquelle le chapardeur vous voit et fuit | 7 |
| `thief_flee_steps` | Pas de fuite avant l'épuisement | 9 |
| `thief_tired_turns` | Tours de repos une fois épuisé | 4 |
| `thief_dodge_chance` | Part des dagues esquivées quand il n'est pas épuisé | 0,5 |
| `key_hear_distance` | Distance à pied à laquelle on entend ses clés | 18 |
| `footprint_turns` | Durée de vie d'une empreinte en tours | 40 |
| `daggers_start`, `daggers_max` | Dagues au départ, dagues portées au plus | 2, 5 |
| `dagger_range` | Portée d'une dague en cases | 6 |
| `dagger_attack_bonus` | Ajouté à votre ATT pour une dague | -2 |
| `barrels_per_floor_min`, `barrels_per_floor_max` | Tonneaux par étage | 4, 8 |
| `barrel_loot_chance` | Chance qu'un tonneau contienne un objet | 0,3 |
| `torch_chance_per_room` | Chance qu'une salle ait une torche | 0,75 |
| `torch_light_radius` | Rayon de lumière d'une torche en cases | 4,5 |
| `slime_split_min_hp` | PV restants à partir desquels une gelée se divise | 4 |
| `skeleton_revive_turns` | Tours avant qu'un squelette se relève | 7 |
| `skeleton_revive_ratio` | Part des PV max avec laquelle il se relève | 0,6 |
| `shake_decay`, `shake_max_offset` | Tremblement d'écran | 2,2, 9 |
| `sfx_volume_db` | Volume des bruitages | -8 |
| `floor_themes` | Une entrée par étage : `name_key`, `wall`, `wall_top`, `floor`, `floor_alt`, `light` | |

### enemies.json

| Champ | Sens |
| :--- | :--- |
| `id` | Identifiant ; clé de traduction `enemy_<id>`, qui contient l'article (« l'orc ») |
| `display_name`, `sprite`, `color` | Nom de secours, dessin dans `sprites.json`, couleur des particules et de la barre de vie |
| `hp`, `attack`, `defense`, `xp` | Caractéristiques à l'étage 1, XP rapportée |
| `speed` | Actions par tour (1, 2, 0,5…) |
| `ai` | `melee`, `erratic`, `ranged` ou `thief` |
| `chase_range` | Distance à laquelle il peut vous repérer |
| `range`, `ranged_attack` | Portée et attaque du tir (`ranged` seulement) |
| `min_floor`, `max_floor`, `weight` | Étages autorisés et fréquence ; un poids de 0 exclut le type du tirage |
| `boss` | `true` : jamais tiré au hasard, posé près de la sortie du dernier étage, sans progression par étage |
| `key_carrier` | `true` : lâche la clé de l'étage en mourant (chapardeur, Gardien) |
| `split` | `true` : se divise quand un coup ne le tue pas (gelée) |
| `revive` | `true` : se relève de ses os (squelette) |

### items.json

| Champ | Sens |
| :--- | :--- |
| `id` | Identifiant ; clés de traduction `item_<id>_name` et `item_<id>_desc` |
| `effect` | `heal_ratio`, `energy`, `thunder`, `blink`, `reveal`, `attack`, `defense`, `max_hp`, `dagger`, `key` |
| `value`, `radius` | Valeur de l'effet ; rayon pour `thunder`. Les descriptions affichent ces valeurs : les modifier met le texte à jour. |
| `instant` | `true` : appliqué au ramassage, sans passer par l'inventaire |
| `sprite`, `color` | Dessin dans `sprites.json` et couleur (halo, particules, sceau des parchemins) |
| `min_floor`, `weight` | Premier étage et fréquence |

### sprites.json

```json
{
 "outline": "1b1424",
 "sprites": {
  "key": {
   "palette": {"g": "ffd24d", "G": "fff2a0", "d": "c08a1a", "D": "8a5a10"},
   "frames": [["................", "...", "16 lignes de 16 caractères"]]
  }
 }
}
```

| Champ | Sens |
| :--- | :--- |
| `outline` | Couleur du caractère `k`, le contour sombre commun à tous les dessins |
| `palette` | Un caractère par couleur, valeur hexadécimale sans `#` |
| `frames` | Une ou deux images ; chacune compte 16 lignes de 16 caractères, « . » pour le transparent. Avec une seule image, la respiration est calculée. |
| `scale` | Taille par rapport à une case, arrondie à un multiple de 16 px (troll 1,3 et Gardien 1,45 sont dessinés à 48 px) |
| `tint` | Caractère repeint avec la couleur de l'objet (le sceau du parchemin) |

Les sprites regardent vers la droite ; le jeu les retourne quand la créature marche vers la
gauche. Pour un nouvel ennemi, ajoutez son dessin ici et donnez son nom dans le champ `sprite`
de `enemies.json`.

### Ajouter une langue

1. Copiez `data/strings_en.json` en `data/strings_<code>.json` et traduisez les valeurs. Les
   noms d'ennemis (`enemy_<id>`) contiennent leur article, en minuscule : le jeu met la
   majuscule quand le nom commence une phrase (`{Name}`). Les directions (`dir_n`,
   `dir_ne`…) s'insèrent après « vers » : en français elles portent leur article (« le nord »,
   « l'est »).
2. Ajoutez le code au tableau `langs` de `GameHUD._on_lang_pressed()`.
