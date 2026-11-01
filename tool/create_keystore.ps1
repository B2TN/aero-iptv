# Crée la clé de signature Android et son fichier key.properties.
#
# Conservez la clé et ses mots de passe en lieu sûr, hors du dépôt : sans elle,
# aucune mise à jour de l'application installée ne sera possible.
#
# Usage : powershell -ExecutionPolicy Bypass -File tool\create_keystore.ps1

. "$PSScriptRoot\common.ps1"

$keystoreDir = Join-Path $env:USERPROFILE '.aero_iptv'
$keystore = Join-Path $keystoreDir 'aero_iptv_release.jks'
$properties = Join-Path $AppDir 'android\key.properties'

if (Test-Path $keystore) {
    throw "Une clé existe déjà : $keystore. Elle n'a pas été remplacée."
}

$bytes = New-Object byte[] 24
[Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
$password = -join ($bytes | ForEach-Object { $_.ToString('x2') })

New-Item -ItemType Directory -Force -Path $keystoreDir | Out-Null
& (Join-Path $env:JAVA_HOME 'bin\keytool.exe') -genkeypair -v `
    -keystore $keystore -storetype PKCS12 -alias aero_iptv `
    -keyalg RSA -keysize 4096 -validity 10000 `
    -storepass $password -keypass $password `
    -dname 'CN=Aero IPTV, O=Aero IPTV'
Assert-Success 'création de la clé'

@(
    "storeFile=$($keystore -replace '\\', '/')"
    "storePassword=$password"
    'keyAlias=aero_iptv'
    "keyPassword=$password"
) | Set-Content -Path $properties -Encoding ascii

"Clé créée : $keystore"
"Configuration : $properties"
