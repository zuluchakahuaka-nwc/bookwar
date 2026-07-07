# Build Android debug APK with hard timeout. Kills hung Godot/Gradle on timeout.
[CmdletBinding()]
param(
    [string]$GodotPath = "D:\Godot\Godot_v4.6.3-stable_win64.exe",
    [string]$Project = "D:\Projects\BOOKWAR\project.godot",
    [string]$Preset = "Android",
    [int]$TimeoutSec = 600,
    [switch]$Release
)

$ErrorActionPreference = "Stop"
$exitCode = 0
$ts = [int][double]::Parse((Get-Date -UFormat %s))
$logFile = Join-Path $env:TEMP "bookwar_apk_${ts}.log"
$startTime = Get-Date

if (-not (Test-Path -LiteralPath $GodotPath)) { Write-Error "Godot not found: $GodotPath"; exit 2 }

# Pre-flight: ensure android/build template exists
$projDir = Split-Path $Project -Parent
$buildTemplate = "$projDir\android\build\gradlew.bat"
if (-not (Test-Path $buildTemplate)) {
    Write-Host "[apk] FATAL: android/build template missing. Run install_template first." -ForegroundColor Red
    Write-Host "[apk] Expected: $buildTemplate" -ForegroundColor Yellow
    exit 6
}

# Ensure local gradle distribution is configured in wrapper properties
$wrapperProps = "$projDir\android\build\gradle\wrapper\gradle-wrapper.properties"
$localZip = "$projDir\android\build\gradle\wrapper\gradle-8.12-all.zip"
$studioZip = "D:\AndroidStudioData\gradle\wrapper\dists\gradle-8.12-all\ejduaidbjup3bmmkhw3rie4zb\gradle-8.12-all.zip"
if ((Test-Path $wrapperProps) -and (Test-Path $studioZip) -and -not (Test-Path $localZip)) {
    Write-Host "[apk] copying local gradle dist to wrapper..." -ForegroundColor DarkCyan
    Copy-Item -LiteralPath $studioZip -Destination $localZip -Force
    $fileUri = "file:///" + ($localZip -replace '\\','/')
    "distributionBase=GRADLE_USER_HOME`ndistributionPath=wrapper/dists`ndistributionUrl=$fileUri`nzipStoreBase=GRADLE_USER_HOME`nzipStorePath=wrapper/dists" | Set-Content -Path $wrapperProps -Encoding ASCII
    Write-Host "[apk] wrapper uses local gradle 8.12" -ForegroundColor DarkCyan
}

Write-Host "[apk] starting Godot Android export (preset=$Preset timeout=${TimeoutSec}s)" -ForegroundColor Cyan

# Step 1: import (refresh .godot cache)
Write-Host "[apk] reimporting assets (--import)..." -ForegroundColor DarkCyan
$impArgs = @("--headless", "--path", $projDir, "--import")
$impProc = Start-Process -FilePath $GodotPath -ArgumentList $impArgs -PassThru -NoNewWindow -RedirectStandardOutput "$logFile.imp" -RedirectStandardError "$logFile.imp.err"
if (-not $impProc.WaitForExit(120000)) {
    Write-Warning "[apk] import TIMEOUT 120s, killing"
    try { $impProc.Kill($true) } catch {}
}

# Step 2: export
$cmd = if ($Release) { "--export-release" } else { "--export-debug" }
$outDir = "$projDir\builds\android"
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }
$outApk = "$outDir\bookwar.apk"
$expArgs = @("--headless", "--path", $projDir, $cmd, $Preset, $outApk)
$proc = Start-Process -FilePath $GodotPath -ArgumentList $expArgs -PassThru -NoNewWindow -RedirectStandardOutput $logFile -RedirectStandardError "$logFile.err"

try {
    if (-not $proc.WaitForExit($TimeoutSec * 1000)) {
        Write-Warning "[apk] TIMEOUT after ${TimeoutSec}s — killing Godot + Gradle"
        try { $proc.Kill($true) } catch {}
        Get-Process -Name "gradle*","java*","adb*" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        $exitCode = 3
    } else {
        $exitCode = $proc.ExitCode
    }
} catch {
    try { $proc.Kill($true) } catch {}
    $exitCode = 4
}

$elapsed = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 1)
$color = if ($exitCode -eq 0) { "Green" } else { "Red" }
Write-Host "[apk] finished in ${elapsed}s exit=$exitCode" -ForegroundColor $color

if (Test-Path $logFile) {
    Write-Host "[apk] --- stdout tail ---" -ForegroundColor DarkGray
    Get-Content $logFile -Tail 25 -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }
}
if (Test-Path "$logFile.err") {
    $err = Get-Content "$logFile.err" -ErrorAction SilentlyContinue
    if ($err) {
        Write-Host "[apk] --- stderr ---" -ForegroundColor Yellow
        $err | Select-Object -Last 40 | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
    }
}

if (Test-Path $outApk) {
    $mb = [math]::Round((Get-Item $outApk).Length / 1MB, 2)
    Write-Host "[apk] OK: $outApk ($mb MB)" -ForegroundColor Green
    return $outApk
} else {
    $apk = Get-ChildItem "$outDir\*.apk" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($apk) {
        $mb = [math]::Round($apk.Length / 1MB, 2)
        Write-Host "[apk] OK: $($apk.FullName) ($mb MB)" -ForegroundColor Green
        return $apk.FullName
    }
    Write-Warning "[apk] no APK produced"
    exit $(if ($exitCode -eq 0) { 5 } else { $exitCode })
}
