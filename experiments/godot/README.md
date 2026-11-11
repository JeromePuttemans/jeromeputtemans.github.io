# Intention
Projet expérimental d'exploration de Godot assisté par IA.
Le but est de générer rapidement des prototypes/templates minimalistes de jeux vidéo via quelques prompts IA, pour :
- Observer ce que l'IA propose comme bases minimales selon les genres
- Comprendre et expliquer la structure algorithmique des systèmes générés
- Produire des bases pédagogiques réutilisables

# Structure du projet
## Les dossiers

- Prompts : 
Le dossier contient les fichiers nécessaires pour la génération des projet par IA. 
Principalement : CONVENTION.md, SYSTEM_PROMPT.md, GAME_PROMPT.md, GAME_PROMPT_Template.md

1. `CONVENTION.md` — règles et conventions du projet
2. `SYSTEM_PROMPT.md` — prompt système pour l'IA génératrice de code
3. `GAME_PROMPT_Template.md` — template vierge à remplir par genre
4. `GAME_PROMPT.md` — exemple concret rempli, qui sera réellement utilisé

- templates : 
Contient les protos générés par IA, jouables dans un navigateur. Chaque dossier de jeu contient le projet Godot et un dossier `web` : la version exportée pour le navigateur, vers laquelle pointe la page html, et la vignette qu'elle affiche (`vignette.jpg`, ou `vignette.png` pour un jeu). Un fichier `.gdignore` dans `web` empêche Godot d'importer ces fichiers dans le projet et de les remettre dans l'export suivant.

- samples : 
Contient des projets qui ne sont pas des protos de la page html :
  - `city_builder` : le Starter Kit City Builder, un exemple de jeu de construction de ville en 3D, avec sa version web dans `web` ;
  - `network_project` : le portage vers Godot 4 du shader WebGL « Network » ;
  - `vr` : les protos de réalité virtuelle (Meta Quest), qui ne se jouent pas dans un navigateur : le projet Godot, son archive zip, l'APK à installer sur le casque (dossier `builds`) et une capture.
