@echo off
start python -m http.server 8000
start "" "C:\Program Files\Mozilla Firefox\firefox.exe" "http://localhost:8000/index.html"
pause