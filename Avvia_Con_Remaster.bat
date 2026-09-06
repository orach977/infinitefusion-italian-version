@echo off
title Pokemon Infinite Fusion - Remaster Mode
cd /d "%~dp0"

echo =========================================================================
echo       POKEMON INFINITE FUSION - GRAPHIC REMASTER LAUNCHER
echo =========================================================================
echo.

:: 1. Verifica e avvio di Magpie (integrato nella cartella di gioco)
echo [1/2] Verifica motore di upscaling Magpie...
tasklist /FI "IMAGENAME eq Magpie.exe" 2>NUL | find /I /N "Magpie.exe">NUL
if %ERRORLEVEL%==0 (
    echo [OK] Magpie e' gia' in esecuzione.
) else (
    echo [..] Avvio di Magpie integrato...
    start "" "%~dp0Magpie\Magpie.exe"
    ping 127.0.0.1 -n 3 >NUL
    echo [OK] Magpie avviato correttamente!
)

:: 2. Avvio del gioco
echo.
echo [2/2] Avvio del gioco Pokemon Infinite Fusion...
start "" "%~dp0Game.exe"
echo [OK] Gioco avviato!

echo.
echo =========================================================================
echo GUIDA ALL'USO DEL REMASTER GRAFICO:
echo =========================================================================
echo 1. Assicurati che nel gioco le opzioni video siano:
echo    - Dimensioni schermo: M (1x) oppure XL (2x)  [NON 'Full']
echo.
echo 2. Per attivare la grafica Remaster Fullscreen:
echo    - Premi ALT + F11 mentre sei nella finestra del gioco.
echo    OPPURE
echo    - Clicca sul pulsante 'Ridimensiona' dentro Magpie e poi clicca sul gioco.
echo.
echo 3. Per tornare alla finestra normale:
echo    - Premi nuovamente ALT + F11 oppure premi ESC.
echo =========================================================================
echo.
echo Premi un tasto per chiudere questo prompt (il gioco rimarra' aperto).
pause >NUL

