# Start Android emulator (AVD) headless with timeout. Returns when boot completed.
[CmdletBinding()]
param(
    [string]$AvdName = "Test_API34",
    [string]$Sdk = $env:ANDROID_HOME,
    [int]$BootTimeoutSec = 180,
    [switch]$Headless,
    [switch]$KillExisting
)

$ErrorActionPreference = "Stop"
$emu = Join-Path $Sdk "emulator\emulator.exe"
$adb = Join-Path $Sdk "platform-tools\adb.exe"

if (-not (Test-Path $emu)) { Write-Error "Emulator not found: $emu"; exit 2 }
if (-not (Test-Path $adb)) { Write-Error "adb not found: $adb"; exit 2 }

# Kill any existing emulator
if ($KillExisting) {
    Write-Host "[emu] killing existing emulators..." -ForegroundColor DarkCyan
    & $adb emu kill 2>&1 | Out-Null
    Start-Sleep -Seconds 3
    Get-Process -Name "qemu*" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
}

$startTime = Get-Date
Write-Host "[emu] starting AVD '$AvdName' (boot timeout=${BootTimeoutSec}s)" -ForegroundColor Cyan

$argList = @("-avd", $AvdName, "-no-snapshot-save", "-no-boot-anim", "-gpu", "host", "-netdelay", "none", "-netfast")
if ($Headless) { $argList += @("-no-window", "-no-audio") }

$proc = Start-Process -FilePath $emu -ArgumentList $argList -PassThru -WindowStyle Hidden
Write-Host "[emu] pid=$($proc.Id)" -ForegroundColor DarkCyan

# Wait for device + boot completed
$booted = $false
$dead = $false
$waitUntil = (Get-Date).AddSeconds($BootTimeoutSec)

& $adb wait-for-device 2>&1 | Out-Null

while ((Get-Date) -lt $waitUntil) {
    if ($proc.HasExited) { $dead = $true; break }
    $prop = & $adb shell getprop sys.boot_completed 2>$null
    if ($prop -match "1") { $booted = $true; break }
    Start-Sleep -Seconds 3
}

$elapsed = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 1)

if ($dead) {
    Write-Error "[emu] process died after ${elapsed}s"
    exit 3
}
if (-not $booted) {
    Write-Warning "[emu] boot TIMEOUT after ${elapsed}s — killing"
    try { $proc.Kill($true) } catch {}
    exit 124
}

# Unlock screen + dismiss keyguard
& $adb shell input keyevent 82 2>&1 | Out-Null
& $adb shell input keyevent 4 2>&1 | Out-Null

Write-Host "[emu] booted in ${elapsed}s, ready" -ForegroundColor Green
return $proc.Id
