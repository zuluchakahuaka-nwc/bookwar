# HTML5 export with hard timeout. Kills hung Godot and reports error.
[CmdletBinding()]
param(
    [string]$GodotPath = "C:\Tools\Godot_v4.6.3-stable_win64.exe",
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

$args = @(
    "--headless",
    "--path", (Split-Path $Project -Parent),
    "--export-release", $Preset
)

$proc = Start-Process -FilePath $GodotPath -ArgumentList $args -PassThru -NoNewWindow -RedirectStandardOutput $logFile -RedirectStandardError "$logFile.err"

try {
    if (-not $proc.WaitForExit($TimeoutSec * 1000)) {
        Write-Warning "[build] TIMEOUT after ${TimeoutSec}s, killing Godot (PID=$($proc.Id))"
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
Write-Host "[build] finished in $([math]::Round($elapsed,1))s exit=$exitCode" -ForegroundColor $(if ($exitCode -eq 0) {"Green"} else {"Red"})

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
        Write-Warning "[build] exit=0 but $expected missing — treating as failure"
        $exitCode = 5
    } else {
        $size = (Get-Item $expected).Length
        Write-Host "[build] OK: $expected ($size bytes)" -ForegroundColor Green
    }
}

exit $exitCode
