@echo off
setlocal enabledelayedexpansion
title LamentersHelper Updater
color 0F

echo.
echo   ================================
echo     LAMENTERS HELPER  -  Updater
echo   ================================
echo.

set "CURL=%SystemRoot%\System32\curl.exe"
set "TAR=%SystemRoot%\System32\tar.exe"

if not exist "%CURL%" ( echo   [ERREUR] curl introuvable. Mets a jour Windows 10. & pause & exit /b 1 )
if not exist "%TAR%"  ( echo   [ERREUR] tar introuvable. Mets a jour Windows 10. & pause & exit /b 1 )

set "WOWBASE="

rem 1. Registre Windows
for /f "tokens=2*" %%a in ('reg query "HKLM\SOFTWARE\WOW6432Node\Blizzard Entertainment\World of Warcraft" /v InstallPath 2^>nul ^| findstr /i "REG_SZ"') do set "WOWBASE=%%b"
if defined WOWBASE (
    if "!WOWBASE:~-1!"=="\" set "WOWBASE=!WOWBASE:~0,-1!"
    if not exist "!WOWBASE!\_retail_\Interface\AddOns\" set "WOWBASE="
)

rem 2. Scan disques C a Z
if not defined WOWBASE (
    for %%D in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
        if not defined WOWBASE if exist "%%D:\" (
            if exist "%%D:\World of Warcraft\_retail_\Interface\AddOns\" set "WOWBASE=%%D:\World of Warcraft"
            if not defined WOWBASE if exist "%%D:\Games\World of Warcraft\_retail_\Interface\AddOns\" set "WOWBASE=%%D:\Games\World of Warcraft"
            if not defined WOWBASE if exist "%%D:\Jeux\World of Warcraft\_retail_\Interface\AddOns\" set "WOWBASE=%%D:\Jeux\World of Warcraft"
            if not defined WOWBASE if exist "%%D:\Program Files\World of Warcraft\_retail_\Interface\AddOns\" set "WOWBASE=%%D:\Program Files\World of Warcraft"
            if not defined WOWBASE if exist "%%D:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\" set "WOWBASE=%%D:\Program Files (x86)\World of Warcraft"
        )
    )
)

rem 3. Dossiers utilisateur
if not defined WOWBASE if exist "%USERPROFILE%\Documents\World of Warcraft\_retail_\Interface\AddOns\" set "WOWBASE=%USERPROFILE%\Documents\World of Warcraft"
if not defined WOWBASE if exist "%USERPROFILE%\Documents\Games\World of Warcraft\_retail_\Interface\AddOns\" set "WOWBASE=%USERPROFILE%\Documents\Games\World of Warcraft"
if not defined WOWBASE if exist "%USERPROFILE%\Documents\Jeux\World of Warcraft\_retail_\Interface\AddOns\" set "WOWBASE=%USERPROFILE%\Documents\Jeux\World of Warcraft"
if not defined WOWBASE if exist "%USERPROFILE%\Desktop\World of Warcraft\_retail_\Interface\AddOns\" set "WOWBASE=%USERPROFILE%\Desktop\World of Warcraft"
if not defined WOWBASE if exist "%USERPROFILE%\Downloads\World of Warcraft\_retail_\Interface\AddOns\" set "WOWBASE=%USERPROFILE%\Downloads\World of Warcraft"
if not defined WOWBASE if exist "%USERPROFILE%\World of Warcraft\_retail_\Interface\AddOns\" set "WOWBASE=%USERPROFILE%\World of Warcraft"

rem 4. Saisie manuelle
if not defined WOWBASE (
    echo   [ERREUR] World of Warcraft introuvable automatiquement.
    echo.
    echo   Entre le chemin manuellement.
    echo   Exemple : C:\World of Warcraft
    echo.
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

set "TMPZIP=%TEMP%\LH_update.zip"
set "TMPDIR=%TEMP%\LH_update"

"%CURL%" -L -s --ssl-no-revoke -o "%TMPZIP%" "https://github.com/AlexDN-dev/LamentersHelper/archive/refs/heads/main.zip"
if errorlevel 1 ( echo   [ERREUR] Telechargement echoue. Verifie ta connexion. & pause & exit /b 1 )

echo   Mise a jour des fichiers...

if exist "%TMPDIR%" rmdir /s /q "%TMPDIR%"
mkdir "%TMPDIR%"

"%TAR%" -xf "%TMPZIP%" -C "%TMPDIR%" >nul 2>nul
if errorlevel 1 ( echo   [ERREUR] Extraction echouee. & pause & exit /b 1 )

robocopy "%TMPDIR%\LamentersHelper-main" "%LHPATH%" /E /IS /IT /NFL /NDL /NJH /NJS /NC /NS /NP /LOG:nul

del /q "%TMPZIP%" 2>nul
rmdir /s /q "%TMPDIR%" 2>nul

echo.
echo   ================================
echo    Mise a jour reussie !
echo    /reload en jeu pour appliquer.
echo   ================================
echo.
pause
