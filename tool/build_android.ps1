# Compile les APK Android TV et Fire OS.
#
# Un APK par architecture, pour rester léger sur les sticks :
#   armeabi-v7a  Tous les Fire TV Stick, et la plupart des TV Android anciennes.
#   arm64-v8a    Boîtiers et TV Android récents.
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
        --target-platform android-arm,android-arm64 @secrets
    Assert-Success 'compilation Android'
} finally { Pop-Location }

New-Item -ItemType Directory -Force -Path $DistDir | Out-Null
$output = Join-Path $AppDir 'build\app\outputs\flutter-apk'
foreach ($abi in 'armeabi-v7a', 'arm64-v8a') {
    $target = Join-Path $DistDir "aero_iptv-$version-$abi.apk"
    Copy-Item (Join-Path $output "app-$abi-release.apk") $target -Force
    '{0}  {1:N1} Mio' -f $target, ((Get-Item $target).Length / 1MB)
}

if (-not $usesReleaseKey) {
    Write-Warning 'APK signés avec la clé de débogage : installables, mais non publiables.'
    Write-Warning 'Créez une clé avec tool\create_keystore.ps1 avant toute diffusion.'
}
