<#
.SYNOPSIS
  BOOKWAR disk-cleanup — reclaim space taken by regenerable test/build cruft.

.DESCRIPTION
  Two independent rules (see AGENTS.md "Сleanup"):
  * Screenshots (the "new session" rule): clear tests/screenshots/ and
    tests/e2e/screenshots/ so a fresh session starts empty and fills them
    with its own captures. Old shots are regenerable test output — no value
    in keeping them across sessions.
  * Android tooling: clear gradle build intermediates and caches
    (android/build/build, .gradle, the debug test_project's gradle output,
    emulator screenshots, stray debug zips). KEEPS the build RESULT
    (builds/android/*.apk), server source, and the gradle template skeleton
    (libs/, src/, gradle/wrapper, *.gradle) so the next gradle build is fast.

  Default mode is a DRY-RUN report (shows what would be freed). Re-run with
  -Apply to actually delete.

.EXAMPLE
  scripts/dev/cleanup.ps1                       # dry-run: screenshots only
  scripts/dev/cleanup.ps1 -Apply                # session-start: clear old shots
  scripts/dev/cleanup.ps1 -Android              # dry-run: Android cruft
  scripts/dev/cleanup.ps1 -Android -Apply       # reclaim Android disk
  scripts/dev/cleanup.ps1 -All -Apply           # everything
#>
[CmdletBinding()]
param(
    [switch]$Screenshots,
    [switch]$Android,
    [switch]$All,
    [switch]$Apply
)

$ErrorActionPreference = "SilentlyContinue"
$root = (Get-Location).Path

if ($All) { $Screenshots = $true; $Android = $true }
# Default: no mode = screenshots (the light session-start rule).
if (-not ($Screenshots -or $Android)) { $Screenshots = $true }

function Get-DirSize([string]$p) {
    if (-not (Test-Path -LiteralPath $p)) { return [int64]0 }
    return (Get-ChildItem -LiteralPath $p -Recurse -Force -ErrorAction SilentlyContinue |
            Measure-Object -Property Length -Sum).Sum
}

function Clean-Path([string]$p, [string]$label) {
    if (-not (Test-Path -LiteralPath $p)) {
        Write-Host ("    skip (absent): {0}" -f $label) -ForegroundColor DarkGray
        return [int64]0
    }
    $sz = Get-DirSize $p
    if ($Apply) {
        Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host ("    [-] {0,9:N1} MB  {1}" -f ($sz / 1MB), $label) -ForegroundColor Green
    } else {
        Write-Host ("    [?] {0,9:N1} MB  {1}" -f ($sz / 1MB), $label) -ForegroundColor Yellow
    }
    return [int64]$sz
}

$action = if ($Apply) { "DELETING" } else { "dry-run (would free)" }
Write-Host "`n[cleanup] $action  (root: $root)`n" -ForegroundColor Cyan

$total = [int64]0

if ($Screenshots) {
    Write-Host "== Screenshots (new-session rule) ==" -ForegroundColor White
    $total += Clean-Path (Join-Path $root "tests\screenshots")               "tests/screenshots/"
    $total += Clean-Path (Join-Path $root "tests\e2e\screenshots")           "tests/e2e/screenshots/"
    $total += Clean-Path (Join-Path $root "ANDROID_VERSION\tests")           "ANDROID_VERSION/tests/ (emulator shots)"
    # Recreate empty dirs so tests have somewhere to write this session.
    if ($Apply) {
        foreach ($d in @("tests\screenshots", "tests\e2e\screenshots")) {
            $full = Join-Path $root $d
            if (-not (Test-Path -LiteralPath $full)) { New-Item -ItemType Directory -Path $full -Force | Out-Null }
        }
        Write-Host "    recreated empty screenshot dirs" -ForegroundColor DarkGray
    }
    Write-Host ""
}

if ($Android) {
    Write-Host "== Android tooling cruft (keep APK + sources) ==" -ForegroundColor White
    # Gradle build intermediates + caches — regenerate via `gradle build` / Godot export.
    $total += Clean-Path (Join-Path $root "android\build\build")             "android/build/build/ (gradle intermediates)"
    $total += Clean-Path (Join-Path $root "android\build\.gradle")           "android/build/.gradle/ (cache)"
    # Debug test_project — keep its tiny source, nuke its 1.3 GB gradle/.godot output.
    $total += Clean-Path (Join-Path $root "ANDROID_VERSION\test_project\android") "test_project/android/ (gradle)"
    $total += Clean-Path (Join-Path $root "ANDROID_VERSION\test_project\.godot")  "test_project/.godot/"
    $total += Clean-Path (Join-Path $root "ANDROID_VERSION\test_project\test.apk") "test_project/test.apk (debug build)"
    # Stray debug zips.
    Get-ChildItem -Path (Join-Path $root "ANDROID_VERSION") -Filter "testandroid_*.zip" -File -ErrorAction SilentlyContinue |
        ForEach-Object { $total += Clean-Path $_.FullName ("debug zip: " + $_.Name) }
    # Confirm the RESULT survives.
    $apk = Join-Path $root "builds\android\bookwar.apk"
    if (Test-Path -LiteralPath $apk) {
        Write-Host ("    keep RESULT: builds/android/bookwar.apk ({0:N1} MB)" -f ((Get-Item $apk).Length / 1MB)) -ForegroundColor DarkGreen
    }
    Write-Host ""
}

Write-Host ("[cleanup] {0}: {1:N1} MB ({2:N2} GB)" -f $(if ($Apply) { "freed" } else { "would free" }), ($total / 1MB), ($total / 1GB)) -ForegroundColor Magenta
if (-not $Apply) { Write-Host "[cleanup] dry-run only — re-run with -Apply to delete.`n" -ForegroundColor DarkYellow }
else { Write-Host "" }
