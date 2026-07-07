# Full Android verification pipeline: build -> emulator -> install -> screenshot -> Vision.
[CmdletBinding()]
param(
    [int]$BuildTimeoutSec = 600,
    [int]$BootTimeoutSec = 180,
    [int]$InstallTimeoutSec = 120,
    [int]$VisionTimeoutSec = 90,
    [string]$AvdName = "Test_API34",
    [switch]$SkipBuild,
    [switch]$SkipEmulator,
    [switch]$SkipVision,
    [string]$ShotLabel = "main_menu"
)

$ErrorActionPreference = "Stop"
$root = "D:\Projects\BOOKWAR\ANDROID_VERSION"
$startTime = Get-Date

function Step($name, $script) {
    $t = Get-Date
    Write-Host "`n=== STEP: $name ===" -ForegroundColor Cyan
    & $script
    if ($LASTEXITCODE -ne 0) {
        Write-Host "=== STEP '$name' FAILED exit=$LASTEXITCODE ===" -ForegroundColor Red
        exit $LASTEXITCODE
    }
    $el = [math]::Round(((Get-Date) - $t).TotalSeconds, 1)
    Write-Host "=== STEP '$name' OK in ${el}s ===`n" -ForegroundColor Green
}

if (-not $SkipBuild) {
    Step "BUILD_APK" { & "$root\scripts\dev\build_apk.ps1" -TimeoutSec $BuildTimeoutSec }
}

if (-not $SkipEmulator) {
    # ensure emulator is running, boot if not
    $adb = Join-Path $env:ANDROID_HOME "platform-tools\adb.exe"
    $devs = & $adb devices
    if ($devs -notmatch "emulator-\d+\s+device") {
        Step "RUN_EMULATOR" { & "$root\scripts\dev\run_emulator.ps1" -AvdName $AvdName -BootTimeoutSec $BootTimeoutSec -Headless -KillExisting }
    } else {
        Write-Host "[pipe] emulator already running" -ForegroundColor DarkCyan
    }
}

Step "INSTALL_APK" { & "$root\scripts\dev\install_apk.ps1" -TimeoutSec $InstallTimeoutSec -Run }

Start-Sleep -Seconds 8

Step "SCREENSHOT" { & "$root\scripts\dev\screenshot.ps1" -Label $ShotLabel }

$shot = (Get-ChildItem "$root\tests\e2e\screenshots\*.png" | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName

if (-not $SkipVision) {
    $json = '{"image_source":"' + ($shot -replace '\\','/') + '","prompt":"Describe the Android game screenshot. Is the game running? Is Cyrillic text rendered correctly? Any black screen, crash dialog, or missing UI? Be concise."}'
    Step "VISION" { & "$root\scripts\dev\vision.ps1" -Tool analyze_image -Json $json -TimeoutSec $VisionTimeoutSec }
}

$total = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 1)
Write-Host "`n[pipe] ALL OK in ${total}s. Screenshot: $shot" -ForegroundColor Green
return $shot
