<#
.SYNOPSIS
    Builds a Google Play release of the Nucleus One Android app following the
    procedure documented at:
    https://docs.google.com/document/d/1UcqNCU3RzF26TniPqjo7KNThGnF5FWgaBtnkGlNc19c

.DESCRIPTION
    1. Verifies no GPL-based dependencies are in use.
    2. Runs `flutter clean`.
    3. Builds a release App Bundle with --obfuscate and --split-debug-info so
       Dart stack traces in Crashlytics / Play vitals can be deobfuscated and
       the binary doesn't ship readable symbol names.
    4. Creates `native-debug-symbols.zip` from the per-ABI .so files Flutter
       drops in build/app/intermediates/flutter/prodRelease (arm64-v8a,
       armeabi-v7a, x86_64).

    After the script finishes, the artifacts to upload are:
    - build/app/outputs/bundle/prodRelease/app-prod-release.aab
    - build/app/outputs/bundle/prodRelease/native-debug-symbols.zip

    The .aab goes into the new Production release in Play Console. The
    native-debug-symbols.zip is uploaded via App bundle explorer ->
    Downloads tab -> "Native debug symbols" (only needed if Play does not
    already show "native debug symbols" as attached to the bundle; newer
    Flutter + AGP usually embeds them automatically).

    REMEMBER TO BUMP versionCode in android/app/build.gradle and version in
    pubspec.yaml BEFORE running this script. The script will refuse to build
    if versionCode hasn't been incremented since the last build output.
#>

[CmdletBinding()]
Param (
    [switch] $SkipLicenseCheck,
    [switch] $SkipClean
)

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot
Write-Host "Repo: $repoRoot" -ForegroundColor Cyan

# --- 1. License check ---
if (-not $SkipLicenseCheck) {
    Write-Host "`n[1/4] Verifying no GPL-based dependencies..." -ForegroundColor Cyan
    & pwsh -NoProfile (Join-Path $PSScriptRoot 'dependency_license_check.ps1')
    if ($LASTEXITCODE -ne 0) {
        throw "dependency_license_check.ps1 failed. Aborting release per release doc."
    }
}

# --- 2. flutter clean ---
if (-not $SkipClean) {
    Write-Host "`n[2/4] flutter clean..." -ForegroundColor Cyan
    & flutter clean
    if ($LASTEXITCODE -ne 0) { throw "flutter clean failed." }
}

# --- 3. Build the App Bundle ---
Write-Host "`n[3/4] flutter build appbundle (obfuscated, with split debug info)..." -ForegroundColor Cyan
$debugInfo = Join-Path $repoRoot 'build/app/outputs/debug-info'
& flutter build appbundle `
    --obfuscate `
    --split-debug-info=$debugInfo `
    --flavor prod `
    -t lib/main_prod.dart
if ($LASTEXITCODE -ne 0) { throw "flutter build appbundle failed." }

$aab = Join-Path $repoRoot 'build/app/outputs/bundle/prodRelease/app-prod-release.aab'
if (-not (Test-Path $aab)) { throw "Expected output not found: $aab" }

# --- 4. Native debug symbols ZIP ---
Write-Host "`n[4/4] Packaging native debug symbols ZIP..." -ForegroundColor Cyan
$nativeDir = Join-Path $repoRoot 'build/app/intermediates/flutter/prodRelease'
$abis = @('arm64-v8a', 'armeabi-v7a', 'x86_64')
$abiPaths = $abis | ForEach-Object { Join-Path $nativeDir $_ }
foreach ($p in $abiPaths) {
    if (-not (Test-Path $p)) { throw "Expected native libs dir not found: $p" }
}
$zip = Join-Path $repoRoot 'build/app/outputs/bundle/prodRelease/native-debug-symbols.zip'
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path $abiPaths -DestinationPath $zip -CompressionLevel Optimal

# --- Summary ---
Write-Host "`nBuild complete." -ForegroundColor Green
Write-Host "  App Bundle:           $aab" -ForegroundColor Green
Write-Host "  Native debug symbols: $zip" -ForegroundColor Green
Write-Host "  Dart debug info:      $debugInfo" -ForegroundColor Green
Write-Host "`nNext steps (manual, in Play Console):"
Write-Host "  1. Test and release -> Production -> Create new release"
Write-Host "  2. Upload the .aab above"
Write-Host "  3. App bundle explorer -> Downloads tab -> Upload native debug symbols if not already attached"
Write-Host "  4. Fill in release notes and roll out"
