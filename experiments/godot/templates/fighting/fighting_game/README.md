# Rouages : jeu de combat entre automates (Godot 4)

Trois automates mécaniques s'affrontent en duel, un contre un, en deux manches gagnantes. Le jeu reprend les règles des jeux de combat d'arcade : durées comptées en images, enchaînements, garde haute et basse, projections, contres et jauge de super.

Le projet ne contient aucune image ni aucun son : les automates sont des squelettes articulés dessinés par le code, les décors aussi, et les bruitages sont synthétisés au lancement. Les personnages et leurs coups sont décrits dans `data/fighters.json`, les réglages du match et de l'ordinateur dans `data/config.json`, les textes dans `data/strings_fr.json` et `data/strings_en.json`.

Testé avec Godot 4.4.1 (export web) et 4.7.

---

## Modes

| Mode | Déroulé |
| :--- | :--- |
| **Arcade** | Vous choisissez un automate et une difficulté (Facile, Normal, Difficile), puis affrontez les deux autres dans un ordre tiré au sort, et enfin votre double, un niveau plus fort. Une victoire en arcade est enregistrée sur la carte du personnage. |
| **Versus** | Deux joueurs sur le même clavier ou avec deux manettes. Le joueur 1 choisit, puis le joueur 2 avec ses propres touches. |
| **Entraînement** | Sans chrono. Votre jauge reste pleine, la santé revient dès qu'un enchaînement est fini. La touche Tab change le comportement du mannequin : immobile, en garde, en garde une fois sur deux, accroupi, qui saute. Le bas de l'écran affiche le démarrage du dernier coup et son avantage en images. |

---

## Commandes

| Action | Joueur 1 (clavier) | Joueur 2 (clavier) | Manette |
| :--- | :--- | :--- | :--- |
| Se déplacer | Z Q S D (W A S D en QWERTY), et les flèches quand vous jouez seul | Flèches | Croix ou stick |
| Sauter | Haut | Haut | Haut ou A |
| Léger | J | 1 du pavé numérique | X |
| Fort | K | 2 du pavé numérique | Y |
| Spécial | L | 3 du pavé numérique | B |
| Pause | Échap ou P | Échap ou P | Start |

En versus, la première manette joue le joueur 1 et la deuxième le joueur 2.

### Les gestes de base

| Geste | Commande |
| :--- | :--- |
| Garde debout | Maintenir la direction opposée à l'adversaire. Bloque les coups moyens et les coups sautés. |
| Garde accroupie | Bas + arrière. Bloque les coups moyens et les coups bas. |
| Course, recul | Avant avant, arrière arrière. Le recul est invulnérable pendant ses premières images. |
| Projection | Léger + Fort ensemble, de près. Impossible à bloquer ; l'adversaire peut se dégager en appuyant à son tour sur Léger + Fort dans les 8 images. |
| Coups spéciaux | Spécial seul, ou avec avant, bas ou arrière (voir les personnages). |
| Super | Fort + Spécial ensemble, jauge pleine. L'écran se fige un instant, le coup est invulnérable au départ. |
| Enchaînement | Léger, puis Fort, puis Spécial : quand un coup touche ou est bloqué, le suivant peut l'interrompre. |

La liste des coups de votre automate est disponible dans le menu de pause.

---

## Les automates

| | Brio | Colosse | Libellule |
| :--- | :--- | :--- | :--- |
| Rôle | Équilibré | Lutteur blindé, lent et puissant | Rapide et léger |
| Santé | 1 000 | 1 030 | 970 |
| Marche avant / arrière (px par image) | 4,2 / 3,4 | 2,8 / 2,5 | 5,4 / 4,6 |
| Particularité | Garde réactive | Armure sur deux coups spéciaux | Double saut |

### Coups spéciaux

| Commande | Brio | Colosse | Libellule |
| :--- | :--- | :--- | :--- |
| Spécial | **Trait de vapeur** : projectile | **Onde de choc** : onde au sol, à bloquer accroupi | **Lame volante** : projectile rapide |
| Avant + Spécial | **Engrenage** : ruée en deux coups | **Charge blindée** : charge qui encaisse deux coups | **Trait d'éclair** : fonce et traverse l'adversaire |
| Bas + Spécial | **Ressort** : uppercut invulnérable 8 images | **Étau** : prise de près, ni bloquable ni dégageable | **Vrille** : coup de pied tournoyant invulnérable 6 images |
| Arrière + Spécial | **Contre** : posture de 22 images qui riposte si l'adversaire frappe | **Rugissement** : +30 de jauge, encaisse les coups | **Esquive** : recul invulnérable |
| Fort + Spécial | **Grand ressort** : cinq coups puis envol | **Séisme** : frappe l'adversaire où qu'il soit au sol, imparable | **Nuée de lames** : sept entailles en avançant |

### Frame data des coups normaux

Une image dure 1/60 de seconde. Le démarrage est le nombre d'images avant que le coup puisse toucher, les images actives sont celles où il touche, la récupération celles où l'automate reste vulnérable.

| Coup | Brio | Colosse | Libellule |
| :--- | :--- | :--- | :--- |
| Léger debout | 4 / 3 / 8, 35 dégâts | 6 / 3 / 10, 45 | 3 / 3 / 7, 32 |
| Fort debout | 9 / 4 / 17, 85 | 14 / 5 / 22, 95 | 8 / 4 / 16, 78 |
| Léger accroupi (bas) | 5 / 3 / 8, 30 | 6 / 3 / 10, 40 | 4 / 2 / 8, 28 |
| Fort accroupi (bas, chute) | 10 / 4 / 22, 75 | 13 / 4 / 24, 90 | 9 / 6 / 20, 72 |
| Léger sauté (haut) | 5 / 8 / 4, 40 | 6 / 7 / 5, 50 | 4 / 8 / 4, 35 |
| Fort sauté (haut) | 8 / 6 / 6, 80 | 10 / 6 / 8, 95 | 6 / 6 / 6, 78 |
| Projection | 120 | 140 | 105 |

Lecture : « 4 / 3 / 8 » signifie 4 images de démarrage, 3 actives, 8 de récupération. Le léger debout de Brio inflige 14 images d'étourdissement en touche et 10 en garde : il laisse Brio en avance de quelques images s'il touche, à égalité s'il est bloqué.

---

## Règles du combat

- **Manches** : 60 secondes, deux manches gagnantes. À la fin du chrono, la plus haute part de santé restante l'emporte. Une manche gagnée sans perdre de santé est annoncée « PARFAIT ».
- **Hauteurs** : un coup bas se bloque accroupi, un coup sauté se bloque debout, un coup moyen se bloque des deux façons.
- **Usure** : les coups spéciaux bloqués retirent un peu de santé, sans jamais pouvoir mettre K.O.
- **Contre** : un coup qui touche un adversaire pendant le démarrage de son propre coup inflige 25 % de dégâts en plus et 6 images d'étourdissement de plus.
- **Atténuation** : à partir du troisième coup d'un enchaînement, chaque coup perd 12 % de sa force, sans descendre sous 30 %. Exemple : le cinquième coup d'un enchaînement inflige 52 % de ses dégâts.
- **Jongles** : un adversaire projeté en l'air peut être frappé à nouveau ; au-delà de trois reprises, il devient invulnérable jusqu'à son atterrissage.
- **Chute et relevé** : après une chute, l'automate reste au sol 34 images puis se relève, invulnérable pendant 18 images.
- **Jauge** : elle se remplit en attaquant, en touchant et en encaissant. Pleine (100), elle permet un super.

---

## L'ordinateur

L'ordinateur voit son adversaire tel qu'il était quelques images plus tôt, jamais ses touches. Chaque décision est tirée une fois par événement (une fois par attaque adverse, par saut, par ouverture) : une chance de bloquer de 60 % bloque environ six attaques sur dix.

| Réglage | Facile | Normal | Difficile | Double final |
| :--- | :--- | :--- | :--- | :--- |
| Temps de réaction (images) | 22 | 14 | 9 | un niveau au-dessus |
| Garde | 30 % | 60 % | 82 % | |
| Anti-aérien | 20 % | 50 % | 80 % | |
| Punition d'un coup raté | 25 % | 55 % | 85 % | |
| Poursuite d'un enchaînement | 35 % | 70 % | 92 % | |

En dehors de ces réactions, il garde une intention pendant un moment : avancer, reculer, attendre accroupi, lancer un projectile de loin, frapper à mi-distance, jouer léger ou projeter de près, sauter de temps en temps. Il saute par-dessus le Séisme de Colosse avec la même probabilité que ses anti-aériens.

### Équilibre mesuré

Les réglages des trois automates ont été ajustés en faisant s'affronter l'ordinateur contre lui-même, au même niveau (Difficile), 6 matchs par affiche et par côté, soit 12 matchs par paire :

| Paire | Victoires |
| :--- | :--- |
| Brio contre Colosse | 4 - 8 |
| Brio contre Libellule | 6 - 6 |
| Colosse contre Libellule | 5 - 7 |
| Total sur 36 matchs | Colosse 13, Libellule 13, Brio 10 |

Ces chiffres mesurent l'ordinateur plus que les personnages : un joueur humain qui exploite la vitesse de Libellule ou la portée de Brio changera la donne. Avec 12 matchs par paire, un écart de deux ou trois victoires reste dans le bruit.

---

## Principes techniques

### Squelette et poses

Chaque automate est un squelette : bassin, torse, tête, deux bras et deux jambes en deux segments. Une pose donne l'angle de chaque membre ; le coude est placé à partir de l'épaule, la main à partir du coude, et ainsi de suite. Le bassin descend jusqu'à ce que le pied le plus bas touche le sol, si bien qu'une pose accroupie n'a besoin que de jambes pliées. L'animation passe d'une pose à l'autre par interpolation : préparation pendant le démarrage, pose tendue pendant les images actives, retour pendant la récupération.

### Zones de coup tirées de la pose

La zone qui frappe est la boîte autour du segment qui frappe (avant-bras ou tibia) dans la pose active : elle se trouve exactement sur le poing ou le pied dessiné. La zone qui reçoit est la boîte du corps dans la pose affichée, plus le membre tendu pendant les images actives et la récupération : un coup raté peut être puni sur le bras ou la jambe qui traîne.

### Simulation image par image

Le match avance 60 fois par seconde dans un ordre fixe : les deux automates lisent leurs commandes et avancent, puis les projectiles, puis les corps se repoussent, puis les zones de coup sont testées sur l'état de la même image (deux coups simultanés s'échangent), puis le déroulé de la manche, puis la caméra. Les appuis sont mémorisés 6 images : un coup demandé un peu trop tôt part dès qu'il devient possible.

### Sensations

- **Arrêt sur impact** : les deux automates se figent de 6 à 14 images selon la force du coup (plus sur un contre).
- **Super** : l'écran se fige 40 images avec un éclair à la couleur du personnage.
- **K.O.** : ralenti (une image sur trois) pendant 80 images, éclair blanc, tremblement.
- **Caméra** : elle se place entre les deux automates et zoome quand ils se rapprochent (jusqu'à 1,7 fois), monte quand l'un saute haut, et tremble sur les coups lourds.
- **Effets** : gerbes d'étincelles orientées dans le sens du coup, bouclier hexagonal en garde, traînées fantômes pendant les courses et les supers, poussière à l'atterrissage, barre de vie avec une traînée rouge des dégâts récents.

### Décors

Trois arènes dessinées par couches en parallaxe : l'atelier d'horloger de Brio (engrenages géants, horloges, lampes qui se balancent), la fonderie de Colosse (fours rougeoyants, chaînes, braises) et la serre de Libellule (lune, plantes, lucioles). L'arène est celle de l'adversaire.

### Sauvegarde

Les victoires en arcade, la langue et le son sont écrits dans `user://rouages_save.json` (dans un navigateur, le stockage local du site). Après une mise à jour du jeu, un rechargement forcé de la page (Ctrl+F5) évite que le navigateur garde l'ancienne version en cache.

---

## Organisation des fichiers

| Dossier | Contenu |
| :--- | :--- |
| `autoloads/` | `ConfigManager`, `SaveManager`, `StringManager`, `Sfx` (bruitages), `GameState` (mode, personnages, échelle d'arcade) |
| `scripts/` | `Match` (manches, coups, projectiles, caméra), `Fighter` (états, frame data, garde, animation), `Rig` (squelette), `Poses`, `AI`, `Inputs` (joueur et mannequin), `Projectile`, `Stage`, `Effects`, `WorldLabels`, `Fx`, `InputSetup` |
| `scenes/` | `Main.tscn` (un seul nœud) et `Main.gd` ; `scenes/ui/` pour l'écran titre, la sélection, le HUD, les annonces, les menus |
| `data/` | Personnages et coups, réglages, textes |
