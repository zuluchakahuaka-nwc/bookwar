# Install APK on connected device/emulator with timeout. Reinstall replaces existing.
[CmdletBinding()]
param(
    [string]$ApkPath = "",
    [int]$TimeoutSec = 120,
    [string]$Sdk = $env:ANDROID_HOME,
    [switch]$Run
)

$ErrorActionPreference = "Stop"
$adb = Join-Path $Sdk "platform-tools\adb.exe"

if ($ApkPath -eq "") {
    $ApkPath = (Get-ChildItem "D:\Projects\BOOKWAR\builds\android\*.apk" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
}
if (-not (Test-Path $ApkPath)) { Write-Error "APK not found: $ApkPath"; exit 2 }

Write-Host "[install] waiting for device (timeout=${TimeoutSec}s)..." -ForegroundColor Cyan
$waitProc = Start-Process -FilePath $adb -ArgumentList @("wait-for-device") -PassThru -NoNewWindow
if (-not $waitProc.WaitForExit($TimeoutSec * 1000)) {
    try { $waitProc.Kill($true) } catch {}
    Write-Error "[install] no device after ${TimeoutSec}s"
    exit 3
}

$startTime = Get-Date
Write-Host "[install] installing $ApkPath" -ForegroundColor Cyan

$proc = Start-Process -FilePath $adb -ArgumentList @("install", "-r", "-d", "-t", "--no-incremental", $ApkPath) -PassThru -NoNewWindow -RedirectStandardOutput "$env:TEMP\bookwar_install.log" -RedirectStandardError "$env:TEMP\bookwar_install.err"
if (-not $proc.WaitForExit($TimeoutSec * 1000)) {
    Write-Warning "[install] TIMEOUT, killing adb"
    try { $proc.Kill($true) } catch {}
    exit 124
}

$exitCode = $proc.ExitCode
$elapsed = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 1)

if (Test-Path "$env:TEMP\bookwar_install.log") {
    Get-Content "$env:TEMP\bookwar_install.log" -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }
}

if ($exitCode -ne 0) {
    Write-Host "[install] FAILED in ${elapsed}s exit=$exitCode" -ForegroundColor Red
    exit $exitCode
}

Write-Host "[install] OK in ${elapsed}s" -ForegroundColor Green

if ($Run) {
    Write-Host "[install] launching org.bookwar.game..." -ForegroundColor Cyan
    & $adb shell monkey -p org.bookwar.game -c android.intent.category.LAUNCHER 1 2>&1 | Out-Null
    Start-Sleep -Seconds 5
    Write-Host "[install] launched" -ForegroundColor Green
}

exit 0
