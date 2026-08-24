<!-- 
NOTE UTILISATEUR — non lue par l'IA
Remplis les paramètres ci-dessous, puis envoie les trois fichiers à l'IA :
SYSTEM_PROMPT.md + CONVENTION.md + ce fichier.
Toutes les règles d'exécution sont dans SYSTEM_PROMPT.md et CONVENTION.md.

MESSAGE D'AMORCE — copie-colle ce texte avec les 3 fichiers à chaque nouvelle conversation :
─────────────────────────────────────────────────────────
Voici les 3 fichiers de référence pour ce projet.
Lis-les dans cet ordre : CONVENTION.md, SYSTEM_PROMPT.md, GAME_PROMPT.md.
Puis exécute les instructions.
─────────────────────────────────────────────────────────
-->

# GAME_PROMPT.md — Brief projet

## Paramètres du projet

```
GENRE      : Tower Defense

MECANIQUES : Vagues d'ennemis suivant un chemin prédéfini vers une base à défendre.
             Placement de tours sur des emplacements fixes en dehors du chemin.
             Chaque tour a une portée, une cadence de tir et des dégâts propres.
             Ressources gagnées en éliminant des ennemis, dépensées pour placer
             ou améliorer des tours. Défaite si un ennemi atteint la base.

REFERENCES : Bloons TD, Defense Grid, Gemcraft
```

## Contraintes spécifiques

```
CIBLE       : Desktop
SESSION     : 5-10 min par partie
JOUEURS     : Solo
CONTRAINTES : Vue top-down 2D sur grille.
              3 types de tours maximum pour le prototype.
              3 types d'ennemis maximum (vitesse et résistance variables).
              Le chemin des ennemis est fixe et visible dès le départ.
              Pas d'animation complexe — lisibilité des portées et des
              trajectoires de tir prioritaire sur l'esthétique.
```

---

> Lance l'Étape 1 du `SYSTEM_PROMPT.md`. Ne produis aucun code avant d'avoir complété le bloc `TWIST RETENU`.
