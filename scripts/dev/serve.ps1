# Serve builds/html5 on http://localhost:3000 with auto-restart.
[CmdletBinding()]
param(
    [string]$Root = "D:\Projects\BOOKWAR\builds\html5",
    [int]$Port = 3000,
    [int]$MaxRestarts = 20,
    [switch]$Once
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $Root)) {
    Write-Error "Build dir not found: $Root (run build.ps1 first)"
    exit 2
}

# Install http-server locally if missing
$hsModule = "D:\Projects\BOOKWAR\tests\e2e\node_modules\.bin\http-server.cmd"
if (-not (Test-Path $hsModule)) {
    Write-Host "[serve] installing http-server..." -ForegroundColor Cyan
    npm install --prefix "D:\Projects\BOOKWAR\tests\e2e" http-server --silent --no-save 2>&1 | Out-Null
    $hsModule = "D:\Projects\BOOKWAR\tests\e2e\node_modules\.bin\http-server.cmd"
}

$restarts = 0
$startTime = Get-Date

while ($true) {
    Write-Host "[serve] start #$($restarts+1) on port $Port (root=$Root)" -ForegroundColor Cyan
    $proc = Start-Process -FilePath $hsModule -ArgumentList @($Root, "-p", $Port, "-c-1", "--cors") -PassThru -NoNewWindow

    # Give it 5s to come up
    Start-Sleep -Seconds 3
    $alive = -not $proc.HasExited

    if (-not $alive) {
        Write-Warning "[serve] http-server exited immediately (code=$($proc.ExitCode))"
        if ($Once) { exit 1 }
    } else {
        Write-Host "[serve] up at http://localhost:$Port (pid=$($proc.Id))" -ForegroundColor Green
        if ($Once) { return $proc }
    }

    if ($Once) { exit 0 }

    # Watchdog: poll every 5s, restart if dead
    while (-not $proc.HasExited) {
        Start-Sleep -Seconds 5
    }
    $restarts++
    if ($restarts -ge $MaxRestarts) {
        Write-Error "[serve] exceeded $MaxRestarts restarts, giving up"
        exit 3
    }
    Write-Warning "[serve] crashed after $([math]::Round(((Get-Date)-$startTime).TotalMinutes,1))m, restarting in 2s..."
    Start-Sleep -Seconds 2
}
