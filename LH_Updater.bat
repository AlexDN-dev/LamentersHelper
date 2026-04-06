@echo off
setlocal enabledelayedexpansion
title LamentersHelper Updater
color 0F

echo.
echo   ================================
echo     LAMENTERS HELPER  -  Updater
echo   ================================
echo.

:: ── Verification outils requis (Windows 10+) ─────────────────────────────────
where curl >nul 2>&1
if errorlevel 1 (
    echo   [ERREUR] curl introuvable. Mets a jour Windows 10.
    echo.
    pause & exit /b 1
)
where tar >nul 2>&1
if errorlevel 1 (
    echo   [ERREUR] tar introuvable. Mets a jour Windows 10.
    echo.
    pause & exit /b 1
)

:: ── Detection WoW ─────────────────────────────────────────────────────────────
set "WOWBASE="

:: 1. Registre Windows (le plus fiable)
for /f "tokens=2*" %%a in ('reg query "HKLM\SOFTWARE\WOW6432Node\Blizzard Entertainment\World of Warcraft" /v InstallPath 2^>nul ^| findstr /i "REG_SZ"') do set "WOWBASE=%%b"
if defined WOWBASE (
    if "!WOWBASE:~-1!"=="\" set "WOWBASE=!WOWBASE:~0,-1!"
    if not exist "!WOWBASE!\_retail_\Interface\AddOns\" set "WOWBASE="
)

:: 2. Scan tous les disques (C a Z) avec chemins courants
if not defined WOWBASE (
    for %%D in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
        if not defined WOWBASE if exist "%%D:\" (
            for %%P in (
                "World of Warcraft"
                "Games\World of Warcraft"
                "Jeux\World of Warcraft"
                "Program Files\World of Warcraft"
                "Program Files (x86)\World of Warcraft"
                "Battle.net Games\World of Warcraft"
            ) do (
                if not defined WOWBASE (
                    if exist "%%D:\%%~P\_retail_\Interface\AddOns\" (
                        set "WOWBASE=%%D:\%%~P"
                    )
                )
            )
        )
    )
)

:: 3. Dossiers utilisateur (Documents, Desktop, etc.)
if not defined WOWBASE (
    for %%P in (
        "%USERPROFILE%\Documents\World of Warcraft"
        "%USERPROFILE%\Documents\Games\World of Warcraft"
        "%USERPROFILE%\Documents\Jeux\World of Warcraft"
        "%USERPROFILE%\Desktop\World of Warcraft"
        "%USERPROFILE%\Downloads\World of Warcraft"
        "%USERPROFILE%\World of Warcraft"
        "%PUBLIC%\Documents\World of Warcraft"
        "%PROGRAMFILES%\World of Warcraft"
        "%PROGRAMFILES(X86)%\World of Warcraft"
    ) do (
        if not defined WOWBASE (
            if exist "%%~P\_retail_\Interface\AddOns\" (
                set "WOWBASE=%%~P"
            )
        )
    )
)

:: 4. Introuvable
if not defined WOWBASE (
    echo   [ERREUR] World of Warcraft introuvable automatiquement.
    echo.
    echo   Entre le chemin manuellement (ex: C:\World of Warcraft)
    set /p "WOWBASE=  Chemin WoW : "
    if not exist "!WOWBASE!\_retail_\Interface\AddOns\" (
        echo.
        echo   Chemin invalide. Contacte Kydra pour de l aide.
        echo.
        pause & exit /b 1
    )
)

set "LHPATH=%WOWBASE%\_retail_\Interface\AddOns\LamentersHelper"

if not exist "%LHPATH%\" (
    echo   [ERREUR] LamentersHelper non installe.
    echo   Installe l addon une premiere fois avant de mettre a jour.
    echo.
    pause & exit /b 1
)

echo   WoW detecte : %WOWBASE%
echo   LamentersHelper trouve.
echo.
echo   Telechargement de la derniere version...

:: ── Telechargement ────────────────────────────────────────────────────────────
set "TMPZIP=%TEMP%\LH_update.zip"
set "TMPDIR=%TEMP%\LH_update"

curl -L -s --ssl-no-revoke -o "%TMPZIP%" "https://github.com/AlexDN-dev/LamentersHelper/archive/refs/heads/main.zip"
if errorlevel 1 (
    echo   [ERREUR] Telechargement echoue. Verifie ta connexion internet.
    echo.
    pause & exit /b 1
)

:: ── Extraction ────────────────────────────────────────────────────────────────
echo   Mise a jour des fichiers...

if exist "%TMPDIR%" rmdir /s /q "%TMPDIR%"
mkdir "%TMPDIR%"

tar -xf "%TMPZIP%" -C "%TMPDIR%" >nul 2>&1
if errorlevel 1 (
    echo   [ERREUR] Extraction echouee.
    echo.
    pause & exit /b 1
)

:: ── Copie dans le dossier addon ───────────────────────────────────────────────
robocopy "%TMPDIR%\LamentersHelper-main" "%LHPATH%" /E /IS /IT /NFL /NDL /NJH /NJS /NC /NS /NP /LOG:nul

:: ── Nettoyage ─────────────────────────────────────────────────────────────────
del /q "%TMPZIP%" 2>nul
rmdir /s /q "%TMPDIR%" 2>nul

echo.
echo   ================================
echo    Mise a jour reussie !
echo    /reload en jeu pour appliquer.
echo   ================================
echo.
pause
