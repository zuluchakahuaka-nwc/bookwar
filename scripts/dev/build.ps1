# HTML5 export with hard timeout. Kills hung Godot and reports error.
[CmdletBinding()]
param(
    [string]$GodotPath = "D:\Godot\Godot_v4.6.3-stable_win64.exe",
    [string]$Project = "D:\Projects\BOOKWAR\project.godot",
    [string]$Preset = "HTML5",
    [int]$TimeoutSec = 300
)

$ErrorActionPreference = "Stop"
$exitCode = 0

if (-not (Test-Path -LiteralPath $GodotPath)) {
    Write-Error "Godot binary not found: $GodotPath"
    exit 2
}

$logFile = Join-Path $env:TEMP "bookwar_build_$($_.pid)_$([int][double]::Parse((Get-Date -UFormat %s))).log"
$startTime = Get-Date

Write-Host "[build] starting Godot export (preset=$Preset timeout=${TimeoutSec}s)" -ForegroundColor Cyan

# Step 1: reimport assets
Write-Host "[build] reimporting assets (--import)..." -ForegroundColor DarkCyan
$impArgs = @("--headless", "--path", (Split-Path $Project -Parent), "--import")
$impProc = Start-Process -FilePath $GodotPath -ArgumentList $impArgs -PassThru -NoNewWindow -RedirectStandardOutput "$logFile.imp" -RedirectStandardError "$logFile.imp.err"
if (-not $impProc.WaitForExit(120000)) {
    Write-Warning "[build] import TIMEOUT, killing"
    try { $impProc.Kill($true) } catch {}
}

$expArgs = @(
    "--headless",
    "--path", (Split-Path $Project -Parent),
    "--export-release", $Preset
)

$proc = Start-Process -FilePath $GodotPath -ArgumentList $expArgs -PassThru -NoNewWindow -RedirectStandardOutput $logFile -RedirectStandardError "$logFile.err"

try {
    if (-not $proc.WaitForExit($TimeoutSec * 1000)) {
        Write-Warning "[build] TIMEOUT after ${TimeoutSec}s, killing Godot"
        try { $proc.Kill($true) } catch {}
        Start-Sleep -Seconds 2
        $exitCode = 3
    } else {
        $exitCode = $proc.ExitCode
    }
} catch {
    Write-Error "[build] failed to wait: $_"
    try { $proc.Kill($true) } catch {}
    $exitCode = 4
}

$elapsed = ((Get-Date) - $startTime).TotalSeconds
$color = if ($exitCode -eq 0) { "Green" } else { "Red" }
Write-Host "[build] finished in $([math]::Round($elapsed,1))s exit=$exitCode" -ForegroundColor $color

if (Test-Path $logFile) {
    Write-Host "[build] --- stdout tail ---" -ForegroundColor DarkGray
    Get-Content $logFile -Tail 20 -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }
}
if (Test-Path "$logFile.err") {
    $err = Get-Content "$logFile.err" -ErrorAction SilentlyContinue
    if ($err) {
        Write-Host "[build] --- stderr ---" -ForegroundColor Yellow
        $err | Select-Object -Last 30 | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
    }
}

if ($exitCode -eq 0) {
    $expected = "D:\Projects\BOOKWAR\builds\html5\index.html"
    if (-not (Test-Path $expected)) {
        Write-Warning "[build] exit=0 but output missing, treating as failure"
        $exitCode = 5
    } else {
        $fitem = Get-Item $expected
        $kb = [math]::Round($fitem.Length / 1024, 1)
        Write-Host "[build] OK: output is $kb KB" -ForegroundColor Green
    }
}

exit $exitCode
