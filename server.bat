@echo off
echo Lancement du serveur Python sur le port 8000...

:: Lance le serveur Python en arrière-plan sans bloquer le script
start /b python -m http.server 8000

:: Attend 2 petites secondes pour laisser le temps au serveur de démarrer
timeout /t 2 /nobreak >nul

echo Ouverture de Google Chrome...
:: Lance Google Chrome directement sur l'adresse locale
start chrome http://localhost:8000

echo Serveur actif. Fermez cette fenetre pour l'arreter.