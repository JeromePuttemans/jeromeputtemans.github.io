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
GENRE      : Roguelike

MECANIQUES : Déplacement case par case dans des donjons générés procéduralement.
             Combats au tour par tour. Mort permanente (permadeath).
             Progression par objets et améliorations trouvés en salle.
             Gestion de ressources (vie, énergie, inventaire limité).

REFERENCES : Dungeon Crawl Stone Soup, Caves of Qud, Brogue
```

## Contraintes spécifiques

```
CIBLE       : Desktop
SESSION     : 10-15 min par run
JOUEURS     : Solo
CONTRAINTES : Vue top-down sur grille. Pas de temps réel — chaque action
              du joueur fait avancer le monde d'un tick (tour par tour strict).
              L'interface doit rester lisible sans assets graphiques élaborés
              (formes géométriques et couleurs suffisent pour le prototype).
```

---

> Lance l'Étape 1 du `SYSTEM_PROMPT.md`. Ne produis aucun code avant d'avoir complété le bloc `TWIST RETENU`.
