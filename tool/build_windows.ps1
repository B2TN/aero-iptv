# Compile l'application Windows et prépare sa distribution.
#
# Le fichier .exe ne fonctionne pas seul : il a besoin de ses DLL et du dossier
# data. Le script produit donc une archive prête à décompresser et, si Inno Setup
# est installé, un installeur en un seul fichier .exe.
#
# Usage : powershell -ExecutionPolicy Bypass -File tool\build_windows.ps1

. "$PSScriptRoot\common.ps1"
Use-Workshop

$version = Get-AppVersion
$secrets = Get-SecretArguments
$packageName = "aero_iptv-$version-windows-x64"
$packageDir = Join-Path $DistDir $packageName

# À vérifier avant tout : le dossier est vidé plus bas, et seuls les fichiers
# verrouillés survivraient sous une application ouverte.
$packagedExe = Join-Path $packageDir 'aero_iptv.exe'
if (Get-Process -Name 'aero_iptv' -ErrorAction SilentlyContinue |
        Where-Object { $_.Path -eq $packagedExe }) {
    throw "Aero IPTV est ouvert depuis $packageDir : fermez-le, puis relancez."
}

Push-Location $AppDir
try {
    flutter pub get
    Assert-Success 'résolution des dépendances'

    Push-Location (Join-Path $ProjectRoot 'packages\iptv_data')
    try {
        dart run build_runner build
        Assert-Success 'génération Drift'
    } finally { Pop-Location }

    # Une exécution de débogage laisse ici kernel_blob.bin : ce code de 80 Mio
    # finirait dans le paquet, car le build de version ne fait pas le ménage.
    $assets = Join-Path $AppDir 'build\flutter_assets'
    if (Test-Path $assets) { Remove-Item $assets -Recurse -Force }

    flutter build windows --release @secrets
    Assert-Success 'compilation Windows'
} finally { Pop-Location }

if (Test-Path $packageDir) { Remove-Item $packageDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path $packageDir | Out-Null
Copy-Item (Join-Path $AppDir 'build\windows\x64\runner\Release\*') $packageDir -Recurse

if (Test-Path (Join-Path $packageDir 'data\flutter_assets\kernel_blob.bin')) {
    throw 'Code de débogage présent dans le paquet : distribution annulée.'
}

# Bibliothèques Visual C++ embarquées, pour fonctionner sur un PC qui ne les a
# pas : c'est le déploiement « application-local » recommandé par Flutter.
foreach ($library in 'msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll') {
    Copy-Item (Join-Path $env:WINDIR "System32\$library") $packageDir
}

$archive = "$packageDir.zip"
if (Test-Path $archive) { Remove-Item $archive -Force }
Compress-Archive -Path "$packageDir\*" -DestinationPath $archive -CompressionLevel Optimal
'{0}  {1:N1} Mio' -f $archive, ((Get-Item $archive).Length / 1MB)

$compiler = @(
    (Get-Command ISCC.exe -ErrorAction SilentlyContinue).Source,
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1

if ($compiler) {
    & $compiler "/DAppVersion=$version" "/DSourceDir=$packageDir" "/O$DistDir" `
        (Join-Path $PSScriptRoot 'windows_installer.iss')
    Assert-Success 'création de l''installeur'
} else {
    Write-Warning 'Inno Setup absent : seule l''archive a été produite.'
}
