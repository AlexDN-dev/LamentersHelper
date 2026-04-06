@echo off
powershell -NoProfile -ExecutionPolicy Bypass -Command "
$host.UI.RawUI.WindowTitle = 'LamentersHelper Updater'

Write-Host ''
Write-Host '  ================================' -ForegroundColor DarkRed
Write-Host '    LAMENTERS HELPER  -  Updater  ' -ForegroundColor White
Write-Host '  ================================' -ForegroundColor DarkRed
Write-Host ''

# ── Mot de passe (verifie en ligne) ───────────────────────────────────────────
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $expectedHash = (Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/AlexDN-dev/LamentersHelper/main/auth.cfg' -UseBasicParsing -ErrorAction Stop).Content.Trim()
} catch {
    Write-Host '  [ERREUR] Impossible de verifier le mot de passe (pas de connexion ?).' -ForegroundColor Red
    Write-Host ''
    Read-Host '  Appuie sur Entree pour fermer'
    exit 1
}

$secure = Read-Host '  Mot de passe' -AsSecureString
$plain  = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
              [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))
$hash   = [System.BitConverter]::ToString(
              [System.Security.Cryptography.SHA256]::Create().ComputeHash(
                  [System.Text.Encoding]::UTF8.GetBytes($plain)
              )).Replace('-','').ToLower()

if ($hash -ne $expectedHash) {
    Write-Host ''
    Write-Host '  Mot de passe incorrect.' -ForegroundColor Red
    Write-Host ''
    Read-Host '  Appuie sur Entree pour fermer'
    exit 1
}

Write-Host ''

# ── Detection WoW ─────────────────────────────────────────────────────────────
$wowBase = $null

try {
    $reg = Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\Blizzard Entertainment\World of Warcraft' -ErrorAction Stop
    if ($reg.InstallPath -and (Test-Path $reg.InstallPath)) {
        $wowBase = $reg.InstallPath.TrimEnd('\')
    }
} catch {}

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
    Write-Host '  Deplace ce fichier dans ton dossier AddOns et relance.' -ForegroundColor Yellow
    Write-Host ''
    Read-Host '  Appuie sur Entree pour fermer'
    exit 1
}

$lhPath = \"$wowBase\_retail_\Interface\AddOns\LamentersHelper\"

if (-not (Test-Path $lhPath)) {
    Write-Host '  [ERREUR] LamentersHelper non installe.' -ForegroundColor Red
    Write-Host '  Installe l addon une premiere fois avant de mettre a jour.' -ForegroundColor Yellow
    Write-Host ''
    Read-Host '  Appuie sur Entree pour fermer'
    exit 1
}

Write-Host \"  WoW detecte : $wowBase\" -ForegroundColor Green
Write-Host '  LamentersHelper trouve.' -ForegroundColor Green
Write-Host ''
Write-Host '  Telechargement de la derniere version...' -ForegroundColor Cyan

# ── Telechargement ────────────────────────────────────────────────────────────
$zipUrl = 'https://github.com/AlexDN-dev/LamentersHelper/archive/refs/heads/main.zip'
$tmpZip = \"\$env:TEMP\LamentersHelper_update.zip\"
$tmpDir = \"\$env:TEMP\LamentersHelper_update\"

try {
    Invoke-WebRequest -Uri $zipUrl -OutFile $tmpZip -UseBasicParsing -ErrorAction Stop
} catch {
    Write-Host ''
    Write-Host \"  [ERREUR] Telechargement echoue : \$_\" -ForegroundColor Red
    Read-Host '  Appuie sur Entree pour fermer'
    exit 1
}

# ── Mise a jour des fichiers ───────────────────────────────────────────────────
Write-Host '  Mise a jour des fichiers...' -ForegroundColor Cyan

if (Test-Path $tmpDir) { Remove-Item $tmpDir -Recurse -Force }
Expand-Archive -Path $tmpZip -DestinationPath $tmpDir -Force

$srcPath = \"$tmpDir\LamentersHelper-main\"

Get-ChildItem -Path $srcPath -Recurse | ForEach-Object {
    $relative = $_.FullName.Substring($srcPath.Length + 1)
    $dest     = Join-Path $lhPath $relative
    if ($_.PSIsContainer) {
        if (-not (Test-Path $dest)) { New-Item -ItemType Directory -Path $dest | Out-Null }
    } else {
        $destDir = Split-Path $dest
        if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir | Out-Null }
        Copy-Item -Path $_.FullName -Destination $dest -Force
    }
}

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
