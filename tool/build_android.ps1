# Compile l'APK unique d'Android TV et de Fire OS.
#
# Un seul APK 32 bits (armeabi-v7a) : il fonctionne sur tous les Fire TV Stick
# et sur les TV et boîtiers Android, 64 bits compris. L'APK 64 bits a été
# abandonné : il refusait de fonctionner sur des TV Android.
#
# --split-per-abi est gardé : il ajoute 1000 au numéro de version de l'APK
# 32 bits, et une mise à jour doit garder la numérotation déjà installée.
#
# Usage : powershell -ExecutionPolicy Bypass -File tool\build_android.ps1

. "$PSScriptRoot\common.ps1"
Use-Workshop

$version = Get-AppVersion
$secrets = Get-SecretArguments
$usesReleaseKey = Test-Path (Join-Path $AppDir 'android\key.properties')

Push-Location $AppDir
try {
    flutter pub get
    Assert-Success 'résolution des dépendances'

    Push-Location (Join-Path $ProjectRoot 'packages\iptv_data')
    try {
        dart run build_runner build
        Assert-Success 'génération Drift'
    } finally { Pop-Location }

    flutter build apk --release --split-per-abi `
        --target-platform android-arm @secrets
    Assert-Success 'compilation Android'
} finally { Pop-Location }

New-Item -ItemType Directory -Force -Path $DistDir | Out-Null
$output = Join-Path $AppDir 'build\app\outputs\flutter-apk'
$target = Join-Path $DistDir "aero_iptv-$version-armeabi-v7a.apk"
Copy-Item (Join-Path $output 'app-armeabi-v7a-release.apk') $target -Force
'{0}  {1:N1} Mio' -f $target, ((Get-Item $target).Length / 1MB)

if (-not $usesReleaseKey) {
    Write-Warning 'APK signé avec la clé de débogage : installable, mais non publiable.'
    Write-Warning 'Créez une clé avec tool\create_keystore.ps1 avant toute diffusion.'
}
