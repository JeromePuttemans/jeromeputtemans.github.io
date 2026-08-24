<!--
  ═══════════════════════════════════════════════════════════════
  NOTE UTILISATEUR

  1. Remplis les champs ci-dessous entre les backticks (sections ① à ⑧).
  2. Envoie les 4 fichiers à l'IA dans cet ordre :
       CONVENTION.md → SYSTEM_PROMPT.md → GAME_PROMPT.md
  3. Utilise ce message d'amorce :

  ─────────────────────────────────────────────────────────
  Voici les 3 fichiers de référence pour ce projet.
  Lis-les dans cet ordre : CONVENTION.md, SYSTEM_PROMPT.md, GAME_PROMPT.md.
  Puis exécute les instructions.
  ─────────────────────────────────────────────────────────

  L'IA exécutera d'abord l'invention du twist (section ⑨ de ce fichier),
  puis appliquera les directives de game feel (section ⑩) lors de l'implémentation.
  Ces deux sections sont exécutées par l'IA — elles ne sont pas à remplir.

  CHAMPS OBLIGATOIRES : TITRE, GENRE, ELEVATOR_PITCH, INTENTION_JOUEUR, MECANIQUES, REFERENCES,
                        CIBLE, SESSION, TYPE_SESSION, JOUEURS, PERIMETRE_MINIMAL,
                        GAMEPLAYS_SECONDAIRES_AUTORISES,
                        CONDITIONS_VICTOIRE, CONDITIONS_DEFAITE,
                        RETENTION,
                        PALETTE_MINIMALE

  CHAMPS OPTIONNELS   : SYNOPSIS, PUBLIC_VISE,
                        CAMERA, CHARACTER, CONTROLLER,
                        ONBOARDING, FIRST_SCREEN,
                        CONTRAINTES, TWIST_CONTRAINTE,
                        MOOD, INSPIRATIONS_GRAPHIQUES,
                        USP, ETUDE_MARCHE, INTERET_COMPARATIF,
                        ACCESSIBILITE,
                        SETTINGS_GAMEPLAY, STRINGS_GAMEPLAY, STRINGS_FEEDBACK

  Un champ optionnel absent → l'IA choisit ou déduit.
  Si PERIMETRE_MINIMAL est absent, l'IA le déduit et le formule
  explicitement avant d'explorer les twists.
  ═══════════════════════════════════════════════════════════════
-->

# GAME_PROMPT.md — Brief projet

---

## ① Fiche descriptive *(obligatoires sauf mention)*

```
TITRE          : <titre du jeu ou placeholder — ex: "Project Hollow", "Sans titre">

GENRE          : <genre principal — ex: platformer, tower_defense, roguelike, puzzle>

ELEVATOR_PITCH : <Pour la page Steam : une phrase commerciale qui résume l'expérience et donne envie.
                  Ex: "Un roguelike où chaque mort renforce les ennemis — pas le joueur.">

INTENTION_JOUEUR : <Pour l'IA : l'émotion ou la prise de conscience que le gameplay doit produire.
                    Ce n'est pas un résumé du jeu — c'est ce que le joueur doit ressentir en jouant.
                    Ex: "Sentiment de tension permanente — chaque décision doit sembler irréversible."
                    Ex: "Curiosité croissante — le joueur doit avoir envie de comprendre les règles cachées.">

SYNOPSIS       : <Contexte narratif minimal, peut être vide si le jeu est abstrait.
                  Ex: "Une IA rogue s'est emparée d'une station orbitale. Tu es le dernier ingénieur.">

JOUEURS        : <solo | local multi — et nombre si multi>

PUBLIC_VISE    : <profil du joueur cible — ex: "joueurs PC habitués aux roguelikes, 18-35 ans">
```

---

## ② Le jeu — Core Design *(obligatoires sauf mention)*

### Références *(obligatoire)*

> Les références servent à ancrer l'IA dans un registre précis. Ne pas les confondre avec des modèles
> de complexité à atteindre — elles définissent le style, les conventions du genre, et le scope attendu.
> **Indiquer au moins une référence par axe.**

```
REFERENCES :
  MECANIQUE  : <jeu dont la mécanique centrale est la plus proche — ex: Into the Breach (gestion d'espace)>
  FEEL       : <jeu dont le ressenti et le rythme sont proches — ex: Hades (fluidité, feedback immédiat)>
  SCOPE      : <jeu de taille comparable — ex: Vampire Survivors (loop simple, progression lisible)>
```

### Les 3C *(optionnel — l'IA déduit si vide)*

```
CAMERA     : <point de vue et comportement caméra.
              Ex: "Top-down fixe sur grille", "Vue de côté, scroll horizontal", "Isométrique">

CHARACTER  : <ce que le joueur incarne, ses capacités de base, ses contraintes de mobilité.
              Ex: "Personnage unique, déplacement case par case, pas de saut">

CONTROLLER : <schéma de contrôle attendu.
              Ex: "Clavier seul — ZQSD + Espace + une touche d'action"
              Ex: "Souris uniquement — clic gauche déplace, clic droit interagit">
```

### Mécaniques

```
MECANIQUES : <3 systèmes maximum, du plus central au plus secondaire.
              Toute mécanique au-delà de 3 doit aller dans GAMEPLAYS_SECONDAIRES_AUTORISES ou être abandonnée.
              Ex: 1. déplacement case par case  2. combat tour par tour  3. inventaire limité>
```

### Rétention et onboarding *(obligatoires)*

> Ces deux champs sont les plus souvent absents des briefs et les plus souvent responsables
> d'un prototype techniquement correct mais sans envie de rejouer.

```
RETENTION  : <En une phrase : pourquoi le joueur relance une partie après l'avoir terminée ou perdue.
              Ce n'est pas la même chose que CONDITIONS_VICTOIRE — c'est la motivation à rejouer.
              Ex: "Chaque run génère une combinaison d'objets jamais vue — le joueur cherche le build optimal."
              Ex: "La mort révèle une information sur le monde que la prochaine run pourra exploiter."
              Ex: "Le score est affiché et comparable — la pression sociale pousse à battre son record.">

ONBOARDING : <Optionnel mais recommandé. Si vide, l'IA propose un signal dans le champ SIGNAL_ONBOARDING
              et continue l'implémentation sans attendre.
              Si rempli : décrire le signal implicite — visuel, sonore ou situationnel — qui révèle la règle
              sans texte, sans tutoriel, sans README.
              Ex: "Premier ennemi se déplace vers le joueur avec une flèche d'intention visible —
                   le joueur comprend instinctivement qu'il peut anticiper."
              Ex: "La première mort est impossible à rater : le joueur marche droit sur le danger évident,
                   le game over arrive en 5 secondes, la règle est immédiatement lisible.">
```

### Conditions de victoire / défaite

```
CONDITIONS_VICTOIRE : <ce qui met fin à une partie en succès.
                       Ex: "Atteindre la sortie du niveau", "Survivre 10 vagues", "Score > 5000">

CONDITIONS_DEFAITE  : <ce qui met fin à une partie en échec.
                       Ex: "PV du joueur à 0", "Base détruite", "Temps écoulé">
```

### Gameplays secondaires autorisés *(obligatoire)*

> Ce champ fonctionne comme une **liste blanche** : tout ce qui n'est pas listé ici est interdit
> dans le périmètre minimal. Il remplace l'ancien champ optionnel "GAMEPLAYS_SECONDAIRES"
> pour éviter la sur-ingénierie ou les mécaniques orphelines.
> **En cas de conflit avec PERIMETRE_MINIMAL, PERIMETRE_MINIMAL prime toujours.**

```
GAMEPLAYS_SECONDAIRES_AUTORISES : <systèmes non centraux explicitement autorisés dans le prototype.
                                   Tout système absent de cette liste est hors périmètre.
                                   Laisser vide ou écrire "aucun" pour un prototype strict.
                                   Ex: "Inventaire limité à 3 objets (pas de crafting, pas de vente)"
                                   Ex: "Affichage du score uniquement — pas de leaderboard, pas de sauvegarde">
```

---

## ③ Contraintes de session *(obligatoires)*

```
CIBLE        : <plateforme visée — ex: desktop, mobile portrait, mobile paysage>

SESSION      : <durée de session typique — ex: 2 min, 5-10 min, illimitée>

TYPE_SESSION : <ce que représente une session pour le joueur — obligatoire pour cadrer l'architecture.
                Ex: "Une session = une run complète (mort = retour au début, pas de sauvegarde)"
                Ex: "Une session = un niveau parmi plusieurs (progression sauvegardée entre les niveaux)"
                Ex: "Une session = une partie sans fin (score croissant, pas de condition de victoire finale)">

CONTRAINTES  : <contraintes techniques ou de design — laisser vide si aucune.
                Ex: "vue top-down 2D sur grille"
                Ex: "affichage des intentions ennemies obligatoire"
                Ex: "pas d'animation complexe — lisibilité prioritaire">
```

---

## ④ Périmètre minimal du prototype *(obligatoire)*

> Ce champ borne l'implémentation. L'IA ne dépasse pas ce périmètre.
> Un twist non prototypable dans ce périmètre est invalide.

```
PERIMETRE_MINIMAL : <Ce qui doit fonctionner au minimum pour que le twist soit ressenti.
                     Préciser : nombre de salles/niveaux/vagues, types d'ennemis, types d'objets,
                     durée de run acceptable. Le prototype ne doit pas dépasser ce périmètre.

                     Ex roguelike  : "Une salle unique, 3 ennemis, 1 objet ramassable.
                                      Pas de connexion entre salles, pas de score, pas de sauvegarde."

                     Ex platformer : "5 plateformes, 1 obstacle mobile, 1 zone de fin.
                                      Pas de vies multiples."

                     Ex tower def  : "1 vague de 5 unités, 2 types de tours, 1 chemin fixe.
                                      Pas de menu entre les vagues.">
```

---

## ⑤ Contrainte de twist *(optionnel)*

```
TWIST_CONTRAINTE : <Orientation pour guider l'invention du twist. Laisser vide si aucune.

                    Ex: "Le twist doit créer un dilemme dès le premier mouvement"
                    Ex: "Le twist doit être lisible sans texte explicatif"
                    Ex: "Le twist doit fonctionner avec un seul bouton d'action supplémentaire"
                    Ex: "Le twist doit inverser une récompense attendue du genre">
```

---

## ⑥ Look & Feel

> La palette minimale est obligatoire même si le reste est laissé libre — c'est le seul champ
> visuel sur lequel une IA sans contrainte produit systématiquement un résultat générique.
> Les autres champs sont optionnels : vide = libre choix de l'IA dans les limites de la palette.

### Palette *(obligatoire)*

```
PALETTE_MINIMALE : <4 couleurs nommées ou hex — une par rôle.
                    Ces couleurs s'appliquent à toutes les entités sans exception.
                    Ex :
                      fond    : #0d0d0d  (noir profond)
                      joueur  : #f0f0f0  (blanc cassé)
                      ennemi  : #e05252  (rouge vif)
                      danger  : #f5c542  (jaune ambre)>
```

### Premier écran *(optionnel)*

> Ce champ distingue un prototype "pour tester" d'un prototype "montrable".
> Si vide, l'IA applique le comportement par défaut : lancement direct en PLAYING si pas d'écran titre,
> ou écran TITLE avec un bouton "Jouer" si TYPE_SESSION implique une boucle explicite.

```
FIRST_SCREEN : <Ce que le joueur voit et peut faire dans les 5 premières secondes après le lancement —
                avant toute action de jeu. Définit le ton et l'intention dès l'ouverture.
                Ex: "Fond noir, titre centré, une seule instruction en bas : 'Appuie sur Espace pour jouer'.
                     Pas d'animation, pas de musique — austérité volontaire."
                Ex: "Lancement direct dans la partie — pas d'écran titre, le twist est immédiatement actif.
                     Un texte d'une ligne en haut indique la règle centrale."
                Ex: "Écran titre minimaliste avec le score de la meilleure partie affiché —
                     rappel immédiat de la compétition contre soi-même.">
```

### Ambiance et inspirations *(optionnel)*

```
MOOD : <Ton général et identité visuelle au-delà de la palette.
         Ex: "Minimaliste — formes géométriques uniquement, pas de décor"
         Ex: "Lisibilité avant tout — chaque entité a une forme unique en plus d'une couleur unique"
         Ex: "Aucun asset externe — formes primitives uniquement.">

INSPIRATIONS_GRAPHIQUES : <Références visuelles qui appuient les intentions du jeu.
                            Ne pas citer comme modèles de complexité — uniquement pour le style.
                            Ex: "Palette désaturée façon Darkwood — renforce l'oppression."
                            Ex: "Minimalisme vectoriel de Thomas Was Alone — lisibilité max.">
```

### Accessibilité *(optionnel — défaut appliqué si vide)*

> Si ce champ est vide, l'IA applique les trois règles de base suivantes :
> contraste minimum 4.5:1 sur tout texte, taille de police minimum 14px, aucune information
> transmise par la couleur seule (toujours doublée d'une forme ou d'une icône).

```
ACCESSIBILITE : <Contraintes spécifiques au-delà des règles de base.
                 Ex: "Palette compatible daltonisme deutéranopie — pas de vert/rouge seuls"
                 Ex: "Taille de police minimum 18px — joueurs sur grand écran à distance"
                 Ex: "Aucun input simultané requis — jouabilité une main possible">
```

---

## ⑦ Positionnement marché *(optionnel)*

> Ces sections orientent la différenciation du projet. L'IA peut s'en servir
> pour affiner le twist ou valider la cohérence de l'USP.
> Les références mécaniques, feel et scope sont définies en section ②.

```
ETUDE_MARCHE : <Analyse rapide des jeux existants similaires — forces, limites, opportunités.
                Ex: "Into the Breach : excellent sur la lisibilité, faible rejouabilité narrative.
                     Slay the Spire : fort sur la construction de deck, mais pas de positionnement.">

USP : <Ce qui rend ce jeu unique par rapport aux références citées en section ②.
       Doit être cohérent avec INTERET_COMPARATIF si les deux sont renseignés.
       Ex: "La ressource principale se consomme aussi bien pour attaquer que pour se défendre."
       Ex: "Seul jeu du genre où le joueur subit les mêmes règles que les ennemis.">

INTERET_COMPARATIF : <En quoi ce projet comble un manque identifié dans l'ETUDE_MARCHE.
                       Ex: "Reprend la lisibilité d'Into the Breach en y ajoutant une rejouabilité narrative.">
```

---

## ⑧ Données spécifiques au genre *(optionnel)*

> Ces sections alimentent directement `settings.json`, `strings_fr.json`, `strings_en.json`.
> Si vides, l'IA définit ces valeurs dans le plan d'architecture (Étape 1 du SYSTEM_PROMPT).
> **Valeurs statiques uniquement** — aucune expression, aucune formule.

```
SETTINGS_GAMEPLAY :
  <10 clés maximum. Toute clé absente du PERIMETRE_MINIMAL ou des GAMEPLAYS_SECONDAIRES_AUTORISES
   sera ignorée par l'IA lors de l'implémentation.
   Clés sous "gameplay" dans settings.json.
   Format : cle : type = valeur  — description
   Ex :
     grid_cols       : int   = 18    — largeur de la grille en cases
     player_max_hp   : int   = 8     — points de vie max du joueur
     rng_seed        : int   = 0     — 0 = aléatoire à chaque run>

STRINGS_GAMEPLAY :
  <Textes d'interface sous "gameplay" dans strings_*.json.
   Format : cle : "texte FR" / "texte EN"
   Ex :
     hp        : "PV"     / "HP"
     turn      : "Tour"   / "Turn">

STRINGS_FEEDBACK :
  <Textes de feedback sous "feedback" dans strings_*.json.
   Format : cle : "texte FR" / "texte EN"
   Ex :
     player_death : "Vous êtes mort. Recommencer ?" / "You died. Try again?"
     item_picked  : "Objet récupéré."               / "Item collected.">
```

---

## ⑨ Invention du twist — instructions pour l'IA

> **Cette section est exécutée par l'IA, pas remplie par l'utilisateur.**
> Sur la base des paramètres renseignés dans les sections ① à ⑧, l'IA invente et documente
> un twist gameplay unique, puis enchaîne directement avec l'Étape 1 du `SYSTEM_PROMPT.md`.

---

### Définition opérationnelle

Un twist gameplay est **une règle unique qui modifie la relation fondamentale entre le joueur et le genre**. Il doit être exprimable en une phrase, émerger naturellement du genre, et produire des situations que le joueur n'anticipait pas.

Un twist n'est **pas** :
- Un thème visuel ou narratif ("le jeu se passe dans l'espace")
- Une difficulté accrue ("les ennemis sont plus rapides")
- Une fonctionnalité additionnelle ("tu peux aussi faire X")
- Une référence directe à un mécanisme d'un jeu commercial connu

**Contrainte de lisibilité :** Le twist doit être compris et ressenti dans les 30 premières secondes, sans lire le README. Si `ONBOARDING` est rempli, ce signal est le critère de validation — un twist incompatible avec ce signal est à rejeter. Si `ONBOARDING` est vide, l'IA propose un signal dans le champ `SIGNAL_ONBOARDING` ci-dessous. Si la `SESSION` est courte (≤ 5 min), le signal doit être encore plus direct.

**Contrainte de périmètre :** Un twist dont l'implémentation minimale dépasse le `PERIMETRE_MINIMAL` est à rejeter.

**Si `PERIMETRE_MINIMAL` est absent :** Déduire le périmètre minimal depuis `MECANIQUES` et `CONTRAINTES`, le formuler explicitement sous ce format avant le twist :

```
PERIMETRE_DEDUIT
  [Description du périmètre minimal inféré depuis MECANIQUES et CONTRAINTES]
  [Ce champ remplace PERIMETRE_MINIMAL pour la validation du twist et le GATE JOUABLE]
```

**Axe d'inversion :** Le twist doit subvertir une règle fondamentale du genre — temporalité, ressource, information, corps du joueur, ou règle du genre. Un twist qui naît de la tension entre deux contraintes du brief est préférable à un twist générique. Si `TWIST_CONTRAINTE` est défini, il oriente cet axe. Sinon, choisir l'axe le plus fort au regard de `INTENTION_JOUEUR`.

---

### Format du twist

```
TWIST
  Énoncé           : [La règle en une phrase, sans référence à un jeu existant]
  Axe              : [L'axe d'inversion exploité — ex: temporalité / ressource / information / corps / règle du genre]
  Mécanique        : [Ce que le joueur fait concrètement différemment à chaque action]
  Tension          : [Le dilemme irréductible que ça crée — doit être impossible à contourner]
  Moment aha       : [La situation précise où le joueur comprend la puissance du twist — décrire le contexte in-game]
  Prototypable     : [Ce qui doit fonctionner dans le périmètre minimal pour que le twist soit ressenti — être précis]
  Rétention        : [En quoi ce twist alimente la motivation à rejouer — cohérent avec RETENTION et TYPE_SESSION]
  SIGNAL_ONBOARDING: [Le signal implicite — visuel, sonore ou situationnel — qui révèle la règle sans texte
                      dans les 30 premières secondes. Cohérent avec ONBOARDING si défini.]
  GAME LOOP        : [5 étapes max décrivant une boucle complète avec le twist intégré à chaque étape]
  GATE JOUABLE     : [Situation minimale qui doit fonctionner pour que le twist soit ressenti —
                      strictement contenu dans le PERIMETRE_MINIMAL ou PERIMETRE_DEDUIT]
  ETATS_ETENDUS    : [États GameState supplémentaires nécessaires, ou "aucun" — chacun justifié en une phrase]
```

> Une fois ce bloc produit, enchaîne directement avec l'Étape 1 du `SYSTEM_PROMPT.md`.

---

## ⑩ Game feel — instructions pour l'IA

> **Cette section est exécutée par l'IA lors de l'implémentation, pas remplie par l'utilisateur.**
> Elle définit les exigences de ressenti et de conformité visuelle qui s'appliquent
> à tout le code produit à l'Étape 2 du `SYSTEM_PROMPT.md`.

---

### Game feel au service du twist — référence Steve Swink

Le game feel est la couche sensorielle qui rend le twist *lisible et physiquement satisfaisant* (d'après Steve Swink, *Game Feel: A Game Designer's Guide to Virtual Sensation*). Chaque retour sensoriel doit révéler la mécanique, pas seulement décorer :

- **Contrôle en temps réel** : réponse à chaque input dans la même frame — zéro input lag perceptible, les contrôles anticipent l'intention
- **Simulation spatiale** : le monde réagit aux actions du joueur de façon cohérente et prévisible (physique, collision, overlap)
- **Feedback immédiat et ciblé** : un signal visuel distinct pour chaque état du twist (couleur, forme, animation courte) — un effet qui révèle la mécanique vaut mieux que dix effets décoratifs
- **Texture du mouvement** : accélération/décélération, squash & stretch minimal, impulsion — rendre chaque déplacement *senti*, pas juste *exécuté*
- **Lisibilité des intentions** : l'état du monde (ennemis, ressources, zones de danger) doit être lisible d'un coup d'œil, sans lecture de texte
- **Juice minimal mais ciblé** : chaque feedback audio/visuel renforce la compréhension du twist — jamais purement cosmétique

---

### Conformité MOOD, palette et accessibilité

**Palette minimale (toujours appliquée) :**
- Les 4 couleurs définies dans `PALETTE_MINIMALE` s'appliquent à toutes les entités sans exception
- Le feedback du twist doit rester lisible dans cette palette
- Si `PALETTE_MINIMALE` est absent (champ omis par erreur), l'IA définit une palette de 4 couleurs avant d'écrire la première ligne de code et la documente dans le README

**Accessibilité (toujours appliquée) :**
- Contraste minimum 4.5:1 sur tout texte affiché
- Taille de police minimum 14px
- Aucune information transmise par la couleur seule — toujours doublée d'une forme, d'une icône ou d'une position
- Si `ACCESSIBILITE` définit des contraintes supplémentaires, elles s'ajoutent aux règles ci-dessus

**MOOD et inspirations graphiques (si définis) :**
- Appliquer les formes, contrastes et contraintes d'assets décrits dans `MOOD` à chaque entité
- Ne jamais substituer un asset externe à une forme primitive si `MOOD` l'interdit
- Les `INSPIRATIONS_GRAPHIQUES` servent de référence de style, pas de complexité
