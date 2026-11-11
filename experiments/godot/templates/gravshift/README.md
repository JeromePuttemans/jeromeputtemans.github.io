# Gravshift : prototype de shoot'em up gravitationnel pour Godot 4

Un shoot'em up en arène où votre vaisseau est un puits de gravité : il aspire les balles
ennemies, les fait tourner autour de lui, puis les renvoie sur leurs tireurs. Le projet ne
contient aucun fichier graphique ni sonore : les formes, la grille d'espace-temps, les effets et
les bruitages sont produits par le code.

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

---

## Comment jouer

| Action | Clavier | Manette |
| :--- | :--- | :--- |
| Se déplacer | Bloc ZQSD en AZERTY (WASD en QWERTY), ou les flèches | Stick gauche ou croix |
| Ouvrir le puits (maintenir), renvoyer (relâcher) | `Espace`, `J` ou `Maj` | `A`, gâchette haute droite ou gâchette droite |
| Pause | `Échap` ou `P` | `Start` |
| Reprendre (en pause) | `Échap`, `P`, `Espace` ou `Entrée` | `Start` ou `A` |
| Abandonner la partie (en pause) | `Q` | |
| Commencer, rejouer | `Espace` ou `Entrée` | `A` |
| Choisir une amélioration | Gauche et droite puis `Espace`, ou `1` `2` `3`, ou un clic sur la carte | Croix puis `A` |
| Revenir à l'écran titre (après une partie) | `Échap` ou `P` | `Start` |
| Changer de langue, couper le son (écran titre) | `L`, `M` | |

Le tir est automatique : vous n'avez pas de touche de tir. Les touches de lettres sont lues par
leur position sur le clavier : le bloc ZQSD d'un clavier AZERTY fonctionne sans réglage. Le jeu
se met en pause tout seul quand la fenêtre perd le focus.

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
   gravité : le puits ne les capture pas et l'onde ne les repousse pas. Il faut les esquiver.
8. **La coque.** Le vaisseau a 3 points de coque. Une balle, une orbe ou un contact avec un
   ennemi en retire un ; le vaisseau clignote ensuite et reste invulnérable 1,6 s. Seul son
   cœur blanc (7 px de rayon) compte pour les touches. Chaque ennemi détruit a 6 chances sur 100
   de réparer un point (« +1 COQUE ») quand la coque n'est pas pleine.
9. **Les secteurs.** La partie compte 10 secteurs. Un secteur est terminé quand tous ses ennemis
   sont détruits ; vous choisissez alors une amélioration parmi trois tirées au hasard. Le
   secteur 5 se termine par le Gardien, le secteur 10 par la Singularité. Vaincre la Singularité
   gagne la partie.
10. **Le score.** Chaque ennemi détruit rapporte ses points × le multiplicateur. Chaque
    destruction allonge la chaîne et relance son minuteur de 2,5 s. Multiplicateur = 1 + chaîne
    ÷ 5, arrondi à l'entier inférieur, au plus ×8. Exemple : à la 10e destruction d'affilée, le
    multiplicateur vaut ×3 et un Artilleur (150 points) en rapporte 450. Quand le minuteur
    s'épuise, le multiplicateur perd un cran (de ×3 à ×2, puis ×1 si rien ne tombe encore
    pendant 2,5 s). Une touche sur la coque remet la chaîne à zéro.
11. **La fronde multiple.** Un renvoi qui détruit au moins 2 ennemis dans les 1,3 s ajoute un
    bonus de 60 × n², n étant le nombre d'ennemis détruits : 4 ennemis donnent 960 points
    (« 4 D'UN COUP »). Le meilleur score et le meilleur secteur sont enregistrés.

### Les ennemis

| Ennemi | Aspect | Points de vie | Masse | Points | Comportement | Dès le secteur |
| :--- | :--- | :---: | :---: | :---: | :--- | :---: |
| Drone | Carré rose qui tourne | 3 | 1 | 50 | Fonce sur le vaisseau. Le plus léger : le puits l'emporte sans effort, dans l'orbite ou sur ses voisins | 1 |
| Artilleur | Flèche orange | 10 | 2 | 150 | Tourne autour du vaisseau à 300 px environ et tire un éventail de 3 balles visées toutes les 1,7 s : votre principale source de munitions | 1 |
| Tourelle | Hexagone jaune | 24 | 3 | 250 | Se poste dans la moitié haute et arrose l'arène d'une spirale à trois bras, une salve toutes les 0,13 s. Dangereuse, mais elle remplit une orbite en quelques secondes | 2 |
| Lancier | Triangle violet | 6 | 1,6 | 120 | Approche, vise 0,6 s (une ligne clignotante montre sa trajectoire), puis fonce à 560 px/s en ligne droite. Le puits courbe sa charge : vous pouvez l'envoyer sur ses alliés | 3 |
| Mine | Cercle vert à piquants | 4 | 1,2 | 80 | Dérive vers le vaisseau. Détruite, ou au bout de 6 s, elle éclate en un anneau de 12 balles ; elle clignote vite pendant sa dernière seconde et demie. Détruite de loin, c'est un cadeau pour le puits | 4 |
| Colosse | Grand octogone rouge | 45 | 9 | 500 | Avance lentement et tire 3 orbes lourdes toutes les 2,6 s. Le puits le déplace à peine | 6 |

| Boss | Points de vie | Points | Secteur | Attaques |
| :--- | :---: | :---: | :---: | :--- |
| Gardien | 520 | 6 000 | 5 | Patrouille en haut de l'arène derrière trois arcs de bouclier tournants qui arrêtent vos tirs et vos renvois : visez les trouées, ou laissez le guidage les trouver. Tire des anneaux de balles percés de deux trouées et des salves de 3 orbes lourdes. Sous la moitié de sa vie, il ajoute une spirale et appelle deux Drones toutes les 7 s |
| Singularité | 1 250 | 20 000 | 10 | Un puits contraire : elle attire le vaisseau vers son cœur partout dans l'arène, plus fort à chaque tiers de vie perdu. Au-dessus des deux tiers de sa vie, deux spirales ; jusqu'au dernier tiers, des anneaux de 18 balles et des salves de 3 orbes lourdes ; au dernier tiers, tout à la fois, plus une Mine et deux Drones toutes les 6 s |

Contre les deux boss, le tir automatique ne suffit pas : il faut capturer leurs propres balles
et les leur renvoyer. Les balles orange des boss sont capturables comme les autres.

### Les améliorations

Après chaque secteur, trois cartes sont tirées au hasard parmi les dix améliorations, sans
jamais proposer une amélioration déjà à son niveau maximal.

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

### Lire l'écran

| Zone | Contenu |
| :--- | :--- |
| En haut à gauche | Score, multiplicateur (x1 à x8) et une barre : le temps qui reste avant que le multiplicateur perde un cran |
| En haut au centre | Secteur (SECTEUR 3/10) et ennemis restants ; pendant un combat de boss, son nom et sa barre de vie |
| En haut à droite | Points de coque (losanges) |
| En bas au centre | Barre de **FLUX** (elle vire au rouge sous la moitié) et nombre de balles en **ORBITE** sur la capacité |
| Autour du vaisseau | Un arc de couleur : le flux restant. Un arc blanc : le remplissage de l'orbite. Puits fermé, un cercle pointillé montre la portée de la légère attraction permanente ; puits ouvert, le cercle de capture, les bras de la spirale et le cercle d'attraction |
| La grille | Elle se creuse là où la gravité agit : autour du vaisseau quand le puits est ouvert, autour de la Singularité, et elle ondule après une explosion ou un renvoi |

### Ce que mesure le bot de test

Un bot de test se tient à distance des ennemis, esquive les orbes lourdes, ouvre le puits dès
que trois balles approchent et relâche quand l'orbite est pleine ou que plus rien n'arrive. Sur
6 parties complètes, il atteint le secteur 10 à chaque fois, en 5 à 7 minutes, avec des scores
de 120 000 à 138 000 points. Il bat la Singularité une fois. Les 5 autres fois, il meurt pendant
sa deuxième phase, quand il lui reste entre 38 et 59 % de sa vie. Le relevé de ses touches
montre pourquoi : il fuit le boss jusqu'à se coincer dans un coin de l'arène, où il ne peut plus
esquiver. Un joueur qui tourne autour de la Singularité garde de la place pour esquiver ; ce
dernier combat demande surtout de maîtriser la capture.

---

## Genre & systèmes clés

Un shoot'em up en arène fixe (twin-stick sans second stick) : le vaisseau se déplace librement,
des vagues d'ennemis arrivent par les bords, et le danger vient des balles qui remplissent
l'écran. Le genre repose sur la lecture des trajectoires, le placement et un score à
multiplicateur qui récompense les destructions enchaînées. Ici, le tir est automatique et
faible : la puissance de feu vient des balles ennemies, qu'il faut aller chercher au plus près
du danger pour les capturer.

---

## Systèmes implémentés

### Puits, flux et orbite (`gravity_field.gd`, `bullet_field.gd`)

Le puits suit le vaisseau. Fermé, il exerce une légère attraction permanente sur les ennemis
dans un rayon de 1,2 × 230 = 276 px (120 ÷ masse, décroissante avec la distance) : la position
du vaisseau courbe déjà leurs trajectoires. Ouvert, il accélère les balles orange vers le
vaisseau (1 400 × (1 − distance ÷ 230) px/s²) et les ennemis (900 ÷ masse × (1 − distance ÷
230)). Une balle capturée glisse de sa position vers l'orbite (48 à 62 px du vaisseau) puis
tourne à 4,2 rad/s. `bullet_field.gd` stocke toutes les balles ennemies dans des tableaux
compacts (position, vitesse, type, âge) : des centaines de balles ne coûtent qu'un nœud.

### Renvoi et onde (`gravity_field.gd`, `shots.gd`, `game_manager.gd`)

`GravityField.release()` trie les ennemis par distance et lance chaque balle de l'orbite vers
l'un d'eux, à tour de rôle. Les renvois sont des tirs guidés (`shots.gd`, type `SLING`) qui
peuvent traverser des ennemis avec Perforation. `game_manager.on_release()` applique l'onde
(balles repoussées, ennemis poussés de 320 ÷ masse px/s), déforme la grille et ouvre la fenêtre
de 1,3 s qui compte la fronde multiple.

### Combat (`combat.gd`)

Une passe par image, en tests de cercles sur les distances au carré : tirs contre ennemis (les
arcs du Gardien arrêtent les tirs), orbite contre ennemis, ennemis entre eux, balles et ennemis
contre le vaisseau. Les collisions entre ennemis séparent les deux corps selon leurs masses et
les font rebondir ; au-delà de 150 px/s de vitesse relative, elles infligent des dégâts.

### Ennemis (`enemy_base.gd` et un script par ennemi)

Chaque image, l'ennemi choisit une vitesse souhaitée (`_behave`), le puits ajoute son
attraction divisée par la masse, puis l'ennemi se déplace. Les ennemis naissent hors de
l'arène ; une fois entrés, ils rebondissent sur ses bords. Les caractéristiques (points de vie,
masse, rayon, vitesse, points, couleur, cadence) viennent de `settings.json`.

### Secteurs (`spawner.gd`)

Un secteur est une liste de groupes `{type, count, edge, delay, interval}` : `count` ennemis de
type `type` arrivent un par un toutes les `interval` secondes, `delay` secondes après le début
du secteur, par le bord `edge` (`top`, `bottom`, `left`, `right`, `sides`, `corners` ou
`random`). Les huit secteurs sans boss comptent de 23 à 43 ennemis. Le secteur 5 compte 12 ennemis en
plus du Gardien et des Drones qu'il appelle ; le secteur 10 n'a que la Singularité et ses
renforts.

### Score, chaîne et améliorations (`game_manager.gd`, `upgrades.gd`)

`game_manager.enemy_destroyed()` allonge la chaîne et ajoute les points ; `_decay_chain()` fait
perdre un cran au multiplicateur quand le minuteur s'épuise. `upgrades.gd` tire les trois
cartes (`offer`) et applique l'amélioration choisie au puits ou au vaisseau (`apply`).

### Rendu (`space_grid.gd`, `effects.gd`, entités)

La grille d'espace-temps est un réseau de points reliés à leur position de repos par des
ressorts. Le puits ouvert et la Singularité les attirent ; les explosions et les renvois leur
donnent une impulsion vers l'extérieur. Chaque sommet prend une couleur selon son déplacement :
la grille s'allume là où la gravité travaille. Derrière elle, trois nébuleuses dérivent
lentement et 150 étoiles scintillent. Tout ce qui brille (balles, orbite, tirs, puits) est
dessiné en mélange additif avec une texture de halo générée une fois au lancement.

### Game feel (`effects.gd`, `game_manager.gd`, `sfx_manager.gd`)

| Moment | Effets |
| :--- | :--- |
| Capture | Son dont la hauteur monte avec chaque balle de l'orbite, étincelles bleues |
| Renvoi | Onde visible, grille qui ondule, tremblement proportionnel au nombre de balles renvoyées, son de fronde |
| Collision entre ennemis | « COLLISION », gerbe d'étincelles, petit tremblement |
| Destruction | Explosion aux couleurs de l'ennemi, points flottants, impulsion dans la grille |
| Touche sur la coque | Arrêt sur image de 0,08 s, flash rouge, fort tremblement |
| Mort d'un boss | Ralenti de 1,4 s, flash blanc, toutes les balles ennemies éclatent |
| Écrans | Le logo ondule lettre par lettre, les cartes d'amélioration montent l'une après l'autre, le titre de fin se pose puis les statistiques apparaissent ligne par ligne |

Les 22 bruitages sont synthétisés au lancement (`sfx_manager.gd`), avec une légère variation de
hauteur à chaque lecture et un écart minimal entre deux lectures du même son.

### Saisie et sauvegarde (`input_manager.gd`, `game_manager.gd`)

`input_manager.gd` crée les actions au démarrage, avec les codes physiques des touches.
`game_manager.gd` enregistre le meilleur score, le meilleur secteur, la langue et le réglage du
son dans `user://gravshift_save.json`.

---

## Architecture

`main.tscn` ne contient que le nœud racine avec `game_manager.gd` ; tout le reste est construit
par `game_manager._build_scene()`, comme l'exige `CONVENTION.md`.

```
Main (Node2D, game_manager.gd)        toujours actif, même en pause
├── InputManager (Node, input_manager.gd)
├── SfxManager (Node, sfx_manager.gd)
├── World (Node2D)                     secoué par les tremblements
│   ├── SpaceGrid (space_grid.gd)      grille, nébuleuses, étoiles
│   ├── Enemies                        ennemis (enemy_*.gd, boss_*.gd)
│   ├── Shots (shots.gd)               tirs et renvois du vaisseau
│   ├── EnemyBullets (bullet_field.gd) balles et orbes ennemies
│   ├── GravityField (gravity_field.gd) puits et orbite, mélange additif
│   ├── Player (player.gd)
│   └── Effects (effects.gd)           particules, anneaux, textes flottants
├── Spawner (Node, spawner.gd)
├── Combat (Node, combat.gd)
├── UI (CanvasLayer 1)
│   └── HUD (Control, hud.gd)
└── Transitions (CanvasLayer 2)
    └── Screens (Control, screens.gd)  écrans titre, pause, améliorations et fin
```

| Dossier | Contenu |
| :--- | :--- |
| `datas/` | `settings.json` (réglages, ennemis, secteurs), `strings_fr.json` et `strings_en.json` (textes) |
| `scenes/core/` | `main.tscn` |
| `scripts/core/` | `game_manager.gd`, `input_manager.gd`, `sfx_manager.gd`, `space_grid.gd`, `effects.gd`, `bullet_field.gd`, `shots.gd`, `gravity_field.gd`, `spawner.gd`, `combat.gd`, `upgrades.gd` |
| `scripts/entities/` | `player.gd`, `enemy_base.gd`, `enemy_drone.gd`, `enemy_gunner.gd` (Artilleur), `enemy_spinner.gd` (Tourelle), `enemy_lancer.gd` (Lancier), `enemy_mine.gd`, `enemy_brute.gd` (Colosse), `boss_guardian.gd` (Gardien), `boss_singularity.gd` (Singularité) |
| `scripts/ui/` | `hud.gd`, `screens.gd` |

Les états de jeu sont `TITLE`, `PLAYING`, `PAUSED`, `UPGRADE` (choix d'une amélioration entre
deux secteurs), `GAME_OVER` et `WIN`. Quand la coque est détruite, le jeu reste 1,6 s en `PLAYING`
avant de passer en `GAME_OVER`.

---

## Signaux et flux de données

| Signal | Émetteur | Paramètres | Abonnés |
| :--- | :--- | :--- | :--- |
| `game_state_changed` | game_manager | `state: int` | hud (affiche ou masque le HUD), screens (relance l'animation d'entrée, active les clics sur les cartes) |
| `twist_activated` | gravity_field, à la première capture de la partie | aucun | game_manager (affiche l'astuce au-dessus du vaisseau) |

Les sous-systèmes appellent directement game_manager, qui les a créés et leur a donné une
référence (`gm`). Le flux d'un renvoi :

1. Vous relâchez Espace : `gravity_field.step()` voit le puits ouvert sans touche maintenue et
   appelle `release()`.
2. `release()` crée un tir guidé par balle en orbite (`shots.gd`), vide l'orbite et appelle
   `game_manager.on_release()`, qui applique l'onde, les effets et le son.
3. Aux images suivantes, `combat.gd` détecte les impacts et appelle `game_manager.enemy_hit()`,
   puis `enemy_destroyed()` pour chaque ennemi détruit : chaîne, points, explosion.
4. 1,3 s après le renvoi, `_close_volley()` compte les ennemis détruits par ce renvoi et ajoute
   le bonus de fronde multiple.

---

## Comment tester le twist

1. **La première capture.** Lancez une partie et attendez le premier Artilleur (flèche orange,
   vers la 5e seconde). Quand son éventail de trois balles arrive, maintenez Espace : les balles
   s'incurvent vers le vaisseau et se mettent en orbite. L'astuce « Balle capturée : relâchez
   pour la renvoyer » s'affiche, et le compteur **ORBITE** passe à 3/12.
2. **Le renvoi.** Relâchez Espace : les trois balles partent vers les ennemis les plus proches.
   Un Artilleur (10 points de vie) touché par les trois perd 9 points, ce que le tir
   automatique met près de 2 s à faire.
3. **La projection.** Quand plusieurs Drones vous poursuivent, ouvrez le puits : ils sont
   attirés, accélèrent vers vous et se percutent ou percutent un Artilleur. « COLLISION »
   s'affiche à chaque choc assez rapide.
4. **La fronde multiple.** Remplissez l'orbite près d'une Tourelle (secteur 2), puis relâchez
   au milieu d'un groupe de Drones : chaque renvoi qui en détruit plusieurs affiche « 3 D'UN
   COUP » (ou plus) avec son bonus.

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
| `repair_drop_chance` | 0,06 | Probabilité de réparation à chaque destruction |
| `shake_decay`, `shake_pixels` | 2,4, 14 | Amortissement et amplitude maximale du tremblement |

La section `enemies` donne pour chaque ennemi `hp`, `mass`, `radius`, `speed`, `points`,
`color` et, selon le cas, `fire_interval` ou `fuse`. La section `waves` décrit les 10 secteurs
(voir **Secteurs**), et `upgrades` la liste des améliorations proposées.

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
