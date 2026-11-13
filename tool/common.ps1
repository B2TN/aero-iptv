# Environnement commun aux scripts de build.
#
# Chaque outil est cherché dans l'environnement, puis dans le dossier aero_outils
# du profil : les scripts fonctionnent ainsi sur ce poste comme sur une machine
# configurée autrement.

$ErrorActionPreference = 'Stop'

$script:ProjectRoot = Split-Path -Parent $PSScriptRoot
$script:AppDir = Join-Path $ProjectRoot 'app'
$script:DistDir = Join-Path $ProjectRoot 'dist'
$script:SecretsFile = Join-Path $ProjectRoot 'config\secrets.json'

$script:ToolsDir = Join-Path $env:USERPROFILE 'aero_outils'

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    $env:Path = "$(Join-Path $ToolsDir 'flutter\bin');$env:Path"
}
if (-not $env:JAVA_HOME) {
    $jdk = Get-ChildItem $ToolsDir -Directory -Filter 'jdk-17*' -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($jdk) { $env:JAVA_HOME = $jdk.FullName }
}
if (-not $env:ANDROID_HOME -and (Test-Path (Join-Path $ToolsDir 'android-sdk'))) {
    $env:ANDROID_HOME = Join-Path $ToolsDir 'android-sdk'
}

# Certains chemins de media_kit dépassent la limite de Windows. L'option vaut
# pour ce processus uniquement : la configuration Git globale n'est pas touchée.
$env:GIT_CONFIG_COUNT = '1'
$env:GIT_CONFIG_KEY_0 = 'core.longpaths'
$env:GIT_CONFIG_VALUE_0 = 'true'

# OneDrive marque ses dossiers en lecture seule, ce que `flutter gen-l10n` refuse,
# et enverrait dans le nuage des gigaoctets de fichiers générés. Un projet rangé
# dans OneDrive se compile donc dans une copie à part, et les paquets reviennent
# dans dist. Cette copie peut être supprimée à tout moment.
#
# Elle est rangée hors du profil : le chemin de compilation est inscrit dans les
# binaires, et celui du profil contient le nom de la session Windows.
function Use-Workshop {
    if ($ProjectRoot -notmatch '\\OneDrive') { return }
    $workshop = if ($env:AERO_WORKSHOP) { $env:AERO_WORKSHOP } else { Join-Path $env:PUBLIC 'aero_iptv_atelier' }
    robocopy $ProjectRoot $workshop /MIR /R:1 /W:1 /NFL /NDL /NJH /NJS /NP `
        /XD build .dart_tool .gradle .kotlin ephemeral dist .git /XF '*.g.dart' | Out-Null
    # Robocopy ne signale une erreur qu'à partir du code 8.
    if ($LASTEXITCODE -ge 8) { throw "Copie vers $workshop impossible (code $LASTEXITCODE)" }
    # Robocopy recopie aussi la lecture seule des dossiers.
    attrib -R "$workshop\*" /S /D | Out-Null
    $global:LASTEXITCODE = 0
    $script:ProjectRoot = $workshop
    $script:AppDir = Join-Path $workshop 'app'
}

# Stoppe le script si la dernière commande native a échoué.
function Assert-Success([string] $step) {
    if ($LASTEXITCODE -ne 0) { throw "Échec de l'étape : $step (code $LASTEXITCODE)" }
}

# Version de l'application, sans le numéro de build.
function Get-AppVersion {
    $line = Select-String -Path (Join-Path $AppDir 'pubspec.yaml') -Pattern '^version:\s*([^+\s]+)'
    return $line.Matches[0].Groups[1].Value
}

# Injecte les clés de services si elles sont renseignées.
function Get-SecretArguments {
    if (Test-Path $SecretsFile) { return @("--dart-define-from-file=$SecretsFile") }
    Write-Warning 'config\secrets.json absent : tendances TMDb et clé DeepL de compilation désactivées.'
    return @()
}
