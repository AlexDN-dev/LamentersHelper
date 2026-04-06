@echo off
powershell -NoProfile -ExecutionPolicy Bypass -Command "
$host.UI.RawUI.WindowTitle = 'LamentersHelper Updater'

Write-Host ''
Write-Host '  ================================' -ForegroundColor DarkRed
Write-Host '    LAMENTERS HELPER  -  Updater  ' -ForegroundColor White
Write-Host '  ================================' -ForegroundColor DarkRed
Write-Host ''

# ── Detection WoW ─────────────────────────────────────────────────────────────
$wowBase = $null

# 1. Registre Windows (Battle.net installe une cle)
try {
    $reg = Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\Blizzard Entertainment\World of Warcraft' -ErrorAction Stop
    if ($reg.InstallPath -and (Test-Path $reg.InstallPath)) {
        $wowBase = $reg.InstallPath.TrimEnd('\')
    }
} catch {}

# 2. Chemins courants si registre vide
if (-not $wowBase) {
    $candidates = @(
        'C:\Program Files (x86)\World of Warcraft',
        'C:\Program Files\World of Warcraft',
        'D:\World of Warcraft',
        'D:\Games\World of Warcraft',
        'E:\World of Warcraft',
        'E:\Games\World of Warcraft',
        'C:\Games\World of Warcraft',
        'D:\Program Files (x86)\World of Warcraft',
        'D:\Program Files\World of Warcraft'
    )
    foreach ($p in $candidates) {
        if (Test-Path \"$p\_retail_\Interface\AddOns\") {
            $wowBase = $p
            break
        }
    }
}

if (-not $wowBase) {
    Write-Host '  [ERREUR] World of Warcraft introuvable.' -ForegroundColor Red
    Write-Host ''
    Write-Host '  Modifie la variable wowBase en haut du script avec ton chemin.' -ForegroundColor Yellow
    Write-Host ''
    Read-Host '  Appuie sur Entree pour fermer'
    exit 1
}

$addonsPath = \"$wowBase\_retail_\Interface\AddOns\"
$lhPath     = \"$addonsPath\LamentersHelper\"

Write-Host \"  WoW detecte : $wowBase\" -ForegroundColor Green
Write-Host ''
Write-Host '  Telechargement de la derniere version...' -ForegroundColor Cyan

# ── Telechargement ────────────────────────────────────────────────────────────
$zipUrl  = 'https://github.com/AlexDN-dev/LamentersHelper/archive/refs/heads/main.zip'
$tmpZip  = \"\$env:TEMP\LamentersHelper_update.zip\"
$tmpDir  = \"\$env:TEMP\LamentersHelper_update\"

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $zipUrl -OutFile $tmpZip -UseBasicParsing -ErrorAction Stop
} catch {
    Write-Host ''
    Write-Host \"  [ERREUR] Impossible de telecharger : \$_\" -ForegroundColor Red
    Read-Host '  Appuie sur Entree pour fermer'
    exit 1
}

# ── Extraction + remplacement ─────────────────────────────────────────────────
Write-Host '  Installation...' -ForegroundColor Cyan

if (Test-Path $tmpDir) { Remove-Item $tmpDir -Recurse -Force }
Expand-Archive -Path $tmpZip -DestinationPath $tmpDir -Force

if (Test-Path $lhPath) { Remove-Item $lhPath -Recurse -Force }
Move-Item \"$tmpDir\LamentersHelper-main\" $lhPath

# ── Nettoyage ─────────────────────────────────────────────────────────────────
Remove-Item $tmpZip -Force -ErrorAction SilentlyContinue
Remove-Item $tmpDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ''
Write-Host '  ================================' -ForegroundColor DarkGreen
Write-Host '   Mise a jour reussie !' -ForegroundColor Green
Write-Host '   /reload en jeu pour appliquer.' -ForegroundColor White
Write-Host '  ================================' -ForegroundColor DarkGreen
Write-Host ''
Read-Host '  Appuie sur Entree pour fermer'
"
