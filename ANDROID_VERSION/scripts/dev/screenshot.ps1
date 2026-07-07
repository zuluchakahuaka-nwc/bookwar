# Capture screenshot from Android device via adb. Saves to tests/e2e/screenshots.
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Label,
    [string]$OutDir = "D:\Projects\BOOKWAR\ANDROID_VERSION\tests\e2e\screenshots",
    [string]$Sdk = $env:ANDROID_HOME,
    [int]$TimeoutSec = 30
)

$ErrorActionPreference = "Stop"
$adb = Join-Path $Sdk "platform-tools\adb.exe"

if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }

$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$safe = $Label -replace '[^\w\-]', '_'
$remote = "/sdcard/bookwar_${ts}_$safe.png"
$local = Join-Path $OutDir "bookwar_${ts}_$safe.png"

Write-Host "[shot] capturing '$Label'..." -ForegroundColor DarkCyan
$startTime = Get-Date

$p1 = Start-Process -FilePath $adb -ArgumentList @("shell", "screencap", "-p", $remote) -PassThru -NoNewWindow
if (-not $p1.WaitForExit($TimeoutSec * 1000)) { try { $p1.Kill($true) } catch {}; Write-Warning "[shot] screencap TIMEOUT" }

$p2 = Start-Process -FilePath $adb -ArgumentList @("pull", $remote, $local) -PassThru -NoNewWindow
if (-not $p2.WaitForExit($TimeoutSec * 1000)) { try { $p2.Kill($true) } catch {}; Write-Warning "[shot] pull TIMEOUT"; exit 124 }

# Cleanup remote
& $adb shell rm $remote 2>&1 | Out-Null

if (Test-Path $local) {
    $kb = [math]::Round((Get-Item $local).Length / 1KB, 1)
    $elapsed = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 1)
    Write-Host "[shot] OK $local ($kb KB) ${elapsed}s" -ForegroundColor Green
    return $local
} else {
    Write-Error "[shot] failed"
    exit 1
}
