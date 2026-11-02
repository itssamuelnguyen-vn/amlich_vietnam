# Builds the release APKs and copies them to build\apk with short names stamped with the build time, so several builds
# of the same version stay apart: amlich-<version>-<yyyyMMdd-HHmm>.apk (arm64, for almost every phone) and
# -arm32 / -x86_64 for the others.
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)

$version = (Select-String -Path pubspec.yaml -Pattern '^version:\s*([^+\s]+)').Matches[0].Groups[1].Value
$stamp = Get-Date -Format 'yyyyMMdd-HHmm'

flutter build apk --release --split-per-abi
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$out = 'build\apk'
New-Item -ItemType Directory -Force -Path $out | Out-Null
$names = @{
  'app-arm64-v8a-release.apk'   = "amlich-$version-$stamp.apk"
  'app-armeabi-v7a-release.apk' = "amlich-$version-$stamp-arm32.apk"
  'app-x86_64-release.apk'      = "amlich-$version-$stamp-x86_64.apk"
}
foreach ($from in $names.Keys) {
  Copy-Item "build\app\outputs\flutter-apk\$from" (Join-Path $out $names[$from]) -Force
}

Write-Host ""
Write-Host "APK: $(Resolve-Path (Join-Path $out "amlich-$version-$stamp.apk"))"
