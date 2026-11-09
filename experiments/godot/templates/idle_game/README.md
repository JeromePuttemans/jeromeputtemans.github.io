# Cœur de cristal : modèle de jeu incrémental pour Godot 4

Un jeu incrémental (idle game) : vous frappez un cœur de cristal pour en détacher des éclats,
puis vous achetez des générateurs qui en produisent pour vous, même quand vous ne jouez pas.
Toutes les valeurs du jeu sont dans des fichiers JSON : régler l'équilibre ne demande aucune
modification du code. Le projet ne contient aucun fichier graphique ni sonore : le cristal, les
icônes et les bruitages sont produits par le code.

---

## Comment jouer

| Action | Commande |
| :--- | :--- |
| Frapper le cristal | Clic sur le cristal, ou `Espace` |
| Acheter un générateur | Bouton **Acheter** de sa carte |
| Choisir combien en acheter | Boutons **×1**, **×10**, **×100** et **MAX** au-dessus des générateurs |
| Acheter une amélioration | Clic sur sa tuile ; le survol affiche son effet exact |
| Attraper un météore | Clic sur le météore qui traverse l'écran |
| Cristalliser | Bouton **Cristalliser** en bas à gauche |
| Langue, son, sauvegarde, remise à zéro | Boutons en haut à droite |

### Le déroulé d'une partie

1. **Frapper.** Chaque frappe rapporte 1 éclat au départ. Une frappe sur 20 en moyenne est
   critique et en rapporte 5 fois plus, avec une gerbe dorée.
2. **Acheter des générateurs.** Huit générateurs produisent des éclats chaque seconde. Chacun
   coûte 15 % de plus que le précédent du même type : la 1re Glaneuse coûte 12 éclats, la 10e
   42. Un générateur apparaît dans la liste quand vous avez produit la moitié de son prix ;
   le suivant est montré en silhouette, avec le seuil à atteindre.
3. **Atteindre les paliers.** À 25, 50, 100, 150, 200, 300, 400 et 500 exemplaires, la
   production du générateur double. La barre sous son nom montre la progression vers le palier
   suivant.
4. **Acheter des améliorations.** Elles apparaissent dans la boutique quand leur condition est
   remplie (voir le tableau plus bas). Les tuiles dorées sont à votre portée.
5. **Faire surchauffer le cristal.** Chaque frappe remplit la jauge qui entoure le cristal de
   3 % : 34 frappes rapides la remplissent. Une seconde sans frapper, elle se vide de 12 % par
   seconde. Pleine, le cristal surchauffe 8 secondes : la production et les frappes sont
   doublées.
6. **Attraper les météores.** Le premier passe après 30 secondes, puis un toutes les 60 à
   120 secondes ; il reste 7 secondes à l'écran. Un météore bleu offre une pluie d'éclats :
   30 secondes de production d'un coup (au moins la valeur de 30 frappes). Un météore orange
   déclenche une éruption : production triplée pendant 12 secondes.
7. **Cristalliser.** Voir la section suivante.

En votre absence, vos générateurs continuent à moitié de leur rythme, jusqu'à 8 heures. Si
vous revenez après plus d'une minute, une fenêtre vous dit combien ils ont produit. La partie
est sauvegardée toutes les 15 secondes, quand la fenêtre se ferme ou perd le focus (un onglet
masqué dans le navigateur, par exemple), et après chaque cristallisation.

### La cristallisation

Cristalliser efface vos éclats, vos générateurs et vos améliorations. En échange, vous gagnez
des prismes, que vous gardez pour toujours : chaque prisme ajoute 10 % à votre production et à
vos frappes.

Le nombre de prismes dépend de tous les éclats produits depuis le début, toutes parties
confondues : `prismes = racine cubique (éclats produits ÷ 1 million)`, arrondi à l'entier
inférieur.

| Éclats produits au total | Prismes | Bonus |
| ---: | ---: | ---: |
| 1 million | 1 | +10 % |
| 8 millions | 2 | +20 % |
| 1 milliard | 10 | +100 % |
| 1 000 milliards | 100 | +1 000 % |

Le bouton indique combien de prismes une cristallisation vous donnerait maintenant ; sans
prisme à gagner, il indique le total à atteindre pour le prochain. Une fenêtre de confirmation
rappelle ce qui sera effacé.

### Les générateurs

| Générateur | Prix du premier | Production d'un exemplaire |
| :--- | ---: | ---: |
| Glaneuse | 12 | 0,15 éclat/s |
| Foreuse | 110 | 1,2 éclat/s |
| Tailleur | 1 200 | 9 éclats/s |
| Raffinerie | 13 000 | 62 éclats/s |
| Résonateur | 150 000 | 420 éclats/s |
| Forge stellaire | 1,7 million | 2 800 éclats/s |
| Lentille orbitale | 21 millions | 19 000 éclats/s |
| Cœur jumeau | 260 millions | 130 000 éclats/s |

### Les améliorations

| Amélioration | Condition | Prix | Effet |
| :--- | :--- | :--- | :--- |
| Rodage (I) de chaque générateur | 1 exemplaire | 10 × le prix de base du générateur | Sa production ×2 |
| Affûtage (II) | 15 exemplaires | 100 × le prix de base | Sa production ×2 |
| Harmonisation (III) | 40 exemplaires | 2 000 × le prix de base | Sa production ×2 |
| Transcendance (IV) | 80 exemplaires | 60 000 × le prix de base | Sa production ×2 |
| Frappe nette | 100 éclats produits | 150 | Valeur de base des frappes ×2 |
| Écho | 2 000 éclats produits | 3 000 | Chaque frappe rapporte en plus 2 % de la production par seconde |
| Frappe lourde | 60 000 éclats produits | 80 000 | Valeur de base des frappes ×3 |
| Écho profond | 1,5 million produits | 2 millions | +3 % de la production par frappe |
| Grand écho | 50 millions produits | 60 millions | +5 % de la production par frappe |
| Lumière d'aube | 50 000 produits | 80 000 | Toute la production ×1,5 |
| Plein midi | 5 millions produits | 8 millions | Toute la production ×1,5 |
| Zénith | 500 millions produits | 800 millions | Toute la production ×2 |

Les « éclats produits » des conditions sont comptés depuis la dernière cristallisation. Les
échos gardent les frappes utiles tard dans la partie : avec 10 000 éclats/s de production et
les trois échos achetés (10 %), une frappe rapporte 1 000 éclats de plus.

### Lire l'écran

| Zone | Contenu |
| :--- | :--- |
| En haut à gauche | Vos éclats (le nombre défile vers sa valeur), la production par seconde avec le bonus actif (surchauffe, éruption), la valeur d'une frappe |
| Au centre à gauche | Le cristal, la jauge de surchauffe autour, et un anneau par type de générateur possédé, avec jusqu'à 12 petites gemmes de sa forme |
| En bas à gauche | Vos prismes, leur bonus et le bouton de cristallisation |
| En haut à droite | Les améliorations disponibles, de la moins chère à la plus chère |
| En bas à droite | Les générateurs : nombre possédé, production et part du total, palier suivant, bouton d'achat. Bouton vert : à votre portée ; sinon une barre bleue montre la progression vers le prix |

### Équilibre mesuré

Un bot de test frappe 4 fois par seconde pendant les 10 premières minutes, attrape chaque
météore, puis achète toujours ce qui rapporte le plus de production par éclat dépensé.

| Repère | Première partie | Deuxième partie, avec 9 prismes |
| :--- | ---: | ---: |
| Première Raffinerie | 5 min 24 s | 2 min 45 s |
| Première Forge stellaire | 21 min 25 s | 8 min 57 s |
| Premier Cœur jumeau | 53 min 37 s | 34 min 18 s |
| 1 million produits (premier prisme) | 15 min 53 s | 7 min 06 s |
| Prismes à gagner au bout d'une heure | 10 | 48 |

---

## Principes algorithmiques

### 1. Le tick : le temps comme moteur de production

À chaque image, `GameManager._process(delta)` ajoute `production par seconde × delta` aux
éclats. `delta` est la durée écoulée depuis l'image précédente (environ 0,016 s à 60 images par
seconde) : en une seconde, les `delta` font toujours 1, quelle que soit la cadence. La
production ne dépend donc pas du nombre d'images par seconde.

La production hors ligne applique la même formule à un seul grand intervalle : le temps depuis
la dernière sauvegarde (8 heures au plus) × la production × 0,5.

### 2. La courbe de coût exponentielle

```
prix = prix de base × 1,15 ^ nombre possédé
```

La production croît de façon linéaire avec le nombre possédé, le prix de façon exponentielle.
C'est cet écart qui entretient l'envie d'un achat de plus : le suivant semble toujours proche,
mais la courbe repousse sans cesse le défi.

Acheter N exemplaires d'un coup est une série géométrique, calculée sans boucle
(`Producer.get_bulk_cost`) :

```
prix de N = prix actuel × (1,15 ^ N − 1) / (1,15 − 1)
```

Le mode **MAX** inverse cette formule pour trouver le plus grand N payable avec un budget B
(`Producer.max_affordable`) :

```
N = partie entière de log(1 + B × 0,15 / prix actuel) / log(1,15)
```

Exemple : avec 12 Glaneuses (prochaine à 64,2 éclats) et 1 000 éclats, N vaut 8, pour
881 éclats.

### 3. La pile de production

```
production d'un générateur = production de base × nombre × améliorations × paliers
production de base         = somme des générateurs × améliorations globales × prismes
production totale          = production de base × surchauffe × éruption
valeur d'une frappe        = (1 × améliorations de frappe + part d'écho × production de base)
                             × prismes × surchauffe
```

Les multiplicateurs se composent par multiplication. Exemple : 50 Foreuses avec Rodage et
Affûtage produisent `1,2 × 50 × 4 (améliorations) × 4 (paliers 25 et 50) = 960` éclats/s.

### 4. Les conditions de déblocage

- **OWNED_COUNT** (nombre possédé) : vérifiée après chaque achat de générateur.
- **RESOURCE_TOTAL** (éclats produits) : vérifiée à chaque signal `total_produced_changed`, donc
  à chaque image pendant la production.

Un dictionnaire `_signaled_upgrades` garantit que `upgrade_unlocked` n'est émis qu'une fois par
amélioration et par partie, même si le seuil est franchi plusieurs fois.

### 5. Les bonus temporaires

`BoostManager` gère deux minuteurs indépendants : la jauge de surchauffe (remplie par les
frappes, vidée après une seconde d'inactivité) et le calendrier des météores (intervalle tiré au
hasard entre deux bornes). Il expose seulement deux multiplicateurs,
`production_multiplier()` et `click_multiplier()`, que `ProducerManager` applique en bout de
pile : le reste du jeu ignore d'où viennent les bonus.

### 6. La sérialisation : sauvegarder un système en marche

Seul l'état irréductible est sauvegardé : les éclats (actuels, produits pendant la partie,
produits depuis le début), le nombre de chaque générateur, la liste des améliorations achetées,
les prismes, les statistiques, la langue et le mode d'achat.

Les valeurs dérivées (multiplicateurs, production) ne sont **jamais** sauvegardées : au
chargement, `ProducerManager.from_dict()` remet tout à zéro, puis rejoue les améliorations
achetées et recalcule les paliers. Restaurer directement un multiplicateur sauvegardé le
doublerait à chaque chargement. La sauvegarde porte un numéro de version : un fichier de
l'ancien modèle (version 1, économie en or) est ignoré.

### 7. Le graphe de signaux : découpler la production de l'affichage

```
GameManager._process(delta)
  -> ProducerManager.tick(delta)
       -> ResourceManager.add(ressource, quantité)
            -> resource_changed        -> l'interface met à jour les nombres
            -> total_produced_changed  -> ProducerManager vérifie déblocages et apparitions
                 -> upgrade_unlocked   -> la boutique se reconstruit
                 -> producer_revealed  -> la liste montre le générateur
```

La logique du jeu ne connaît pas l'interface : les générateurs produisent même sans aucun nœud
d'affichage. `Main.gd` écoute les signaux (`producer_purchased`, `milestone_reached`,
`frenzy_started`, `meteor_caught`, `prestige_done`…) et y répond par des sons, des
particules, des notifications et des fenêtres.

### 8. L'affichage des grands nombres

`Utils.format_number()` garde trois chiffres significatifs et un suffixe par puissance de 1 000.
En anglais : K, M, B (milliard), T, Qa, Qi, Sx, Sp, Oc, No, Dc. En français, l'échelle longue :
k, M, Md (milliard), Bn (billion, 10^12), Bd, Tn, Td. Au-delà, la notation scientifique
(2,30e25). Exemple : 1 500 000 000 s'affiche « 1,5 Md » en français et « 1.5B » en anglais.

---

## Architecture

```
idle_game/
├── data/
│   ├── config.json        réglages du jeu (voir plus bas)
│   ├── producers.json     les 8 générateurs : prix, production, couleur, forme
│   ├── upgrades.json      les 40 améliorations : condition, prix, effet
│   ├── strings_fr.json    textes en français
│   └── strings_en.json    textes en anglais
├── autoloads/             logique du jeu, sans interface
│   ├── ConfigManager.gd   lit config.json, lecture des fichiers JSON
│   ├── StringManager.gd   textes, langue (française si le système l'est), language_changed
│   ├── Sfx.gd             bruitages synthétisés au démarrage
│   ├── ResourceManager.gd éclats actuels, produits pendant la partie, produits depuis le début
│   ├── PrestigeManager.gd prismes et cristallisation
│   ├── BoostManager.gd    surchauffe et météores
│   ├── ProducerManager.gd générateurs, améliorations, paliers, pile de production
│   ├── Utils.gd           formatage des nombres et des durées
│   ├── SaveManager.gd     sauvegarde JSON versionnée
│   └── GameManager.gd     boucle, frappes, production hors ligne, sauvegarde automatique
├── resources/
│   ├── Producer.gd        classe de données : courbe de coût, achat en lot, paliers
│   └── Upgrade.gd         classe de données : condition et effet
└── scenes/
    ├── Main.tscn          nœud racine seul
    ├── Main.gd            construit l'interface et transforme les événements en retours
    └── ui/                UiTheme, Background, CrystalView, ResourceDisplay, ProducerList,
                           ProducerCard, ProducerIcon, UpgradeShop, UpgradeTile, Tooltip,
                           PrestigePanel, Popup, FxLayer, Toasts, Meteor
```

Toute l'interface est construite par le code, dans `Main.gd` et les scripts de `scenes/ui/`.

**Ordre des autoloads** : `ConfigManager`, `StringManager`, `Sfx`, `ResourceManager`,
`PrestigeManager`, `BoostManager`, `ProducerManager`, `Utils`, `SaveManager`, `GameManager`.
`GameManager` vient en dernier, car son `_ready()` charge la sauvegarde, qui touche tous les
autres.

---

## Modifier les données

Tous les réglages se font dans `data/`, sans toucher au code.

### config.json

| Clé | Effet | Valeur |
| :--- | :--- | ---: |
| `default_language` | Langue de départ : `auto` (française si le système l'est), `fr` ou `en` | auto |
| `auto_save_interval_seconds` | Intervalle de la sauvegarde automatique (s) | 15 |
| `offline_cap_hours`, `offline_factor` | Absence prise en compte au plus (h), part de la production gagnée hors ligne | 8, 0,5 |
| `offline_min_seconds` | Absence minimale pour afficher la fenêtre de retour (s) | 60 |
| `click_base_value` | Éclats d'une frappe avant les améliorations | 1 |
| `crit_chance`, `crit_multiplier` | Probabilité et multiplicateur d'une frappe critique | 0,05, 5 |
| `milestones`, `milestone_multiplier` | Nombres d'exemplaires qui déclenchent un palier, et son effet | 25…500, 2 |
| `reveal_ratio` | Part du prix de base à produire pour qu'un générateur apparaisse | 0,5 |
| `heat_per_click`, `heat_decay_delay`, `heat_decay_per_second` | Jauge de surchauffe : remplissage par frappe, délai avant refroidissement (s), refroidissement par seconde | 0,03, 1, 0,12 |
| `frenzy_duration`, `frenzy_multiplier` | Durée (s) et multiplicateur de la surchauffe | 8, 2 |
| `meteor_first_delay`, `meteor_interval_min`, `meteor_interval_max`, `meteor_lifetime` | Météores : premier passage, intervalle minimal et maximal, durée à l'écran (s) | 30, 60, 120, 7 |
| `meteor_rain_seconds`, `meteor_rain_min_clicks` | Pluie d'éclats : secondes de production offertes, minimum en frappes | 30, 30 |
| `meteor_eruption_multiplier`, `meteor_eruption_duration` | Éruption : multiplicateur et durée (s) | 3, 12 |
| `prestige_threshold`, `prestige_exponent`, `prestige_bonus_per_prism` | Cristallisation : éclats pour le premier prisme, exposant (1/3 = racine cubique), bonus par prisme | 1 M, 0,333, 0,1 |

### producers.json

| Champ | Effet |
| :--- | :--- |
| `id` | Identifiant ; le nom et la description viennent de `producer_<id>_name` et `producer_<id>_desc` dans les fichiers de textes |
| `base_cost`, `cost_growth_rate` | Prix du premier exemplaire, multiplicateur de prix par exemplaire (1,15) |
| `base_production` | Éclats par seconde d'un exemplaire |
| `color`, `sides` | Couleur et nombre de côtés de sa gemme (icône, orbite) |

### upgrades.json

| Champ | Effet |
| :--- | :--- |
| `name_key`, `name_producer` | Clé du nom dans les textes ; `{producer}` y est remplacé par le nom du générateur indiqué |
| `unlock_type` | `OWNED_COUNT` (nombre possédé de `unlock_producer_id`) ou `RESOURCE_TOTAL` (éclats produits pendant la partie) |
| `unlock_threshold` | Seuil de la condition |
| `effect_type` | `MULTIPLY_PRODUCER` (un générateur, `effect_producer_id`), `MULTIPLY_ALL`, `MULTIPLY_CLICK` ou `CLICK_RPS_SHARE` (part de la production ajoutée à chaque frappe) |
| `effect_value` | Multiplicateur, ou part de la production pour `CLICK_RPS_SHARE` (0,02 = 2 %) |

### Ajouter une langue

1. Copiez `data/strings_en.json` en `data/strings_<code>.json` et traduisez chaque valeur ; les
   clés ne changent pas.
2. Ajoutez le code à `LANGUAGES` dans `StringManager.gd`.

Une clé absente de la nouvelle langue s'affiche en anglais ; absente partout, elle s'affiche
`[clé]`, ce qui rend l'oubli visible. Les textes n'utilisent que des caractères présents dans la
police intégrée de Godot : dans la version web, il n'existe pas de police de secours, et un
caractère manquant (une flèche, par exemple) s'afficherait comme un carré.
