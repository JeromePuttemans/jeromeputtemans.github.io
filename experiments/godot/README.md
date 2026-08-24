# Intention
Projet expérimental d'exploration de Godot assisté par IA.
Le but est de générer rapidement des prototypes/templates minimalistes de jeux vidéo via quelques prompts IA, pour :
- Observer ce que l'IA propose comme bases minimales selon les genres
- Comprendre et expliquer la structure algorithmique des systèmes générés
- Produire des bases pédagogiques réutilisables

# Structure du projet
## Les dossiers

- builds : 
Contient les build des projets

- Prompts : 
Le dossier contient les fichiers nécessaires pour la génération des projet par IA. 
Principalement : CONVENTION.md, SYSTEM_PROMPT.md, GAME_PROMPT.md, GAME_PROMPT_Template.md

1. `CONVENTION.md` — règles et conventions du projet
2. `SYSTEM_PROMPT.md` — prompt système pour l'IA génératrice de code
3. `GAME_PROMPT_Template.md` — template vierge à remplir par genre
4. `GAME_PROMPT.md` — exemple concret rempli, qui sera réellement utilisé

- template-images : 
Contient un screenshot du jeu pour l'afficher sur la page html.

- templates : 
Contient les protos générés par IA.
