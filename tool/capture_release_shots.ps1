# Captures des notes de version et du README, avec votre playlist.
#
# L'application démarre dans un dossier temporaire, en anglais, et le supprime
# à la fin, coffre compris : votre profil d'Aero IPTV n'est ni lu ni modifié.
# Les identifiants ne sont demandés que dans cette console, puis passés au test
# par l'environnement de ce seul processus ; ils ne sont écrits nulle part.
# Aucune capture ne montre l'éditeur de playlist, seul écran où ils figurent.
#
# Usage, depuis la racine du projet :
#   powershell -ExecutionPolicy Bypass -File tool\capture_release_shots.ps1
#   powershell -ExecutionPolicy Bypass -File tool\capture_release_shots.ps1 -Version 0.2.0
#
# Sans -Version, le code actuel ; avec -Version 0.2.0, l'étiquette v0.2.0, la
# dernière version officielle, pour les captures « avant ». Les images arrivent dans docs\captures\<version>\.
# Titres recherchés : variables AERO_SERIES, AERO_MOVIE (plusieurs titres
# séparés par |) et AERO_CHANNEL (expression régulière), si vous voulez
# d'autres titres que Dexter, Dune et A&E.

param(
    [ValidateSet('current', '0.2.0')] [string] $Version = 'current'
)

. "$PSScriptRoot\common.ps1"

$repository = $ProjectRoot
$label = if ($Version -eq 'current') { Get-AppVersion } else { $Version }
$output = Join-Path $repository "docs\captures\$label"

Write-Host "Captures de la version $label, rangées dans $output"
$choice = Read-Host 'Playlist : 1 = compte Xtream, 2 = adresse M3U [1]'
try {
    if ($choice -eq '2') {
        $env:AERO_M3U_URL = Read-Host 'Adresse de la playlist M3U'
    } else {
        $env:AERO_XTREAM_SERVER = Read-Host 'Adresse du serveur (http://...)'
        $env:AERO_XTREAM_USER = Read-Host 'Utilisateur'
        $secure = Read-Host 'Mot de passe' -AsSecureString
        $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
        try {
            $env:AERO_XTREAM_PASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
        } finally {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
        }
    }

    if ($Version -eq 'current') {
        Use-Workshop
    } else {
        # Le code de l'étiquette, dans un dossier à part, avec le test de captures
        # d'aujourd'hui : il ne passe que par des fonctions communes aux deux.
        $workshop = Join-Path $env:PUBLIC "aero_iptv_atelier_$Version"
        if (Test-Path $workshop) { Remove-Item $workshop -Recurse -Force }
        New-Item -ItemType Directory -Path $workshop | Out-Null
        $archive = Join-Path $workshop 'source.zip'
        git -C $repository archive --format=zip -o $archive "v$Version"
        Assert-Success "export de v$Version"
        Expand-Archive $archive -DestinationPath $workshop
        Remove-Item $archive
        Copy-Item (Join-Path $repository 'app\integration_test\release_shots_test.dart') `
            (Join-Path $workshop 'app\integration_test\release_shots_test.dart') -Force
        $script:ProjectRoot = $workshop
        $script:AppDir = Join-Path $workshop 'app'
    }

    # Même jeton TMDB que les paquets publiés, et la version affichée.
    $defines = @("--dart-define=AERO_VERSION=$label")
    $token = $null
    if (Test-Path $SecretsFile) {
        $token = (Get-Content $SecretsFile -Raw | ConvertFrom-Json).TMDB_READ_TOKEN
    }
    if ($token) { $defines += "--dart-define=TMDB_READ_TOKEN=$token" }

    New-Item -ItemType Directory -Force -Path $output | Out-Null
    $env:AERO_SHOTS = $output

    Push-Location $AppDir
    try {
        flutter pub get
        Assert-Success 'résolution des dépendances'
        Push-Location (Join-Path $ProjectRoot 'packages\iptv_data')
        try {
            dart run build_runner build --delete-conflicting-outputs
            Assert-Success 'génération Drift'
        } finally { Pop-Location }
        flutter test integration_test\release_shots_test.dart -d windows @defines
        Assert-Success 'captures'
    } finally { Pop-Location }

    Write-Host ''
    Write-Host "Captures prêtes dans $output :"
    Get-ChildItem $output -Filter *.png | ForEach-Object { "  $($_.Name)" }
} finally {
    foreach ($name in 'AERO_M3U_URL', 'AERO_XTREAM_SERVER', 'AERO_XTREAM_USER',
        'AERO_XTREAM_PASSWORD', 'AERO_SHOTS') {
        Remove-Item "Env:$name" -ErrorAction SilentlyContinue
    }
}
