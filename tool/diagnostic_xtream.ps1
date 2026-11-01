# Affiche l'état du compte renvoyé par un panneau Xtream, essaie d'ouvrir un flux
# direct et un film, puis cherche par quel chemin il livre son catalogue.
#
# Le compte est lu dans le coffre de l'application, déchiffré pour la session
# Windows en cours. Il n'est ni affiché ni écrit sur le disque.
#
# Usage : powershell -ExecutionPolicy Bypass -File tool\diagnostic_xtream.ps1 [-Servers adresse1,adresse2]

param(
    [string] $Servers,
    [string] $VaultFile
)

. "$PSScriptRoot\common.ps1"

Add-Type -AssemblyName System.Security

if (-not (Test-Path (Join-Path $DistDir 'xtream_probe.exe'))) {
    throw 'dist\xtream_probe.exe manque : voir le README pour le compiler.'
}

if (-not $VaultFile) {
    $vault = Join-Path $env:APPDATA 'Aero IPTV\Aero IPTV\vault'
    if (-not (Test-Path $vault)) { throw "Aucune playlist enregistrée dans $vault." }
    $VaultFile = (Get-ChildItem $vault -Filter 'source_*.bin' |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
    if (-not $VaultFile) { throw 'Aucune playlist enregistrée.' }
}

$clear = [Security.Cryptography.ProtectedData]::Unprotect(
    [IO.File]::ReadAllBytes($VaultFile), $null, 'CurrentUser')

# Ces variables n'existent que pour ce processus et le diagnostic qu'il lance.
$env:AERO_PROBE_ACCOUNT = [Convert]::ToBase64String($clear)
$env:AERO_PROBE_SERVERS = $Servers
[Array]::Clear($clear, 0, $clear.Length)
try {
    'Essais en cours, comptez environ deux minutes...'
    & (Join-Path $DistDir 'xtream_probe.exe')
    Assert-Success 'diagnostic'
} finally {
    Remove-Item Env:AERO_PROBE_ACCOUNT
    Remove-Item Env:AERO_PROBE_SERVERS -ErrorAction SilentlyContinue
}
