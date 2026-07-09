# ci.ps1 — local CI: build → patch shell → serve → regression tests.
# Use before commits to verify nothing broke. Honors §0.14 (25-min hardcap).
#
# Usage:
#   & scripts/dev/ci.ps1                          # smoke only (default, ~30s)
#   & scripts/dev/ci.ps1 -Full                    # full regression (~6-8 min)
#   & scripts/dev/ci.ps1 -SkipBuild               # reuse existing build
#   & scripts/dev/ci.ps1 -Suite "regression_data" # specific suite
[CmdletBinding()]
param(
    [switch]$Full,
    [switch]$SkipBuild,
    [string]$Suite = "",
    [int]$TestTimeoutSec = 1200  # 20 min hardcap for tests
)

$ErrorActionPreference = "Stop"
# ci.ps1 is in scripts/dev/ — go up twice to reach project root.
$root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
Set-Location $root

function LogStep($msg) {
    $ts = Get-Date -Format "HH:mm:ss"
    Write-Host "[$ts] $msg" -ForegroundColor Cyan
}

function Stop-Port($port) {
    Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue | ForEach-Object {
        Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue
    }
}

$overallStart = Get-Date
$exitCode = 0

try {
    # ─── 1. CLEANUP ───
    LogStep "cleanup: kill leftover processes"
    Get-Process node,godot,java,gradle -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Stop-Port 3000
    Start-Sleep 2

    # ─── 2. BUILD ───
    if (-not $SkipBuild) {
        LogStep "build: HTML5 export"
        $buildStart = Get-Date
        & "$root\scripts\dev\build.ps1" -TimeoutSec 300
        if ($LASTEXITCODE -ne 0) { throw "build failed exit=$LASTEXITCODE" }
        LogStep ("build OK in {0:N1}s" -f ((Get-Date) - $buildStart).TotalSeconds)

        LogStep "patch: web shell"
        node "$root\scripts\dev\patch_web_shell.js" | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "patch_web_shell failed" }
    } else {
        LogStep "build: SKIPPED (-SkipBuild)"
    }

    # ─── 3. SERVE ───
    LogStep "serve: http-server :3000"
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c npx http-server $root\builds\html5 -p 3000 -c-1 --silent" -WindowStyle Hidden
    $serveStart = Get-Date
    $served = $false
    while (((Get-Date) - $serveStart).TotalSeconds -lt 30) {
        try {
            $r = Invoke-WebRequest -Uri "http://localhost:3000/" -UseBasicParsing -TimeoutSec 2 -NoProxy
            if ($r.StatusCode -eq 200) { $served = $true; break }
        } catch { Start-Sleep 1 }
    }
    # Fallback: check if port is listening (proxy bypass)
    if (-not $served) {
        $port = Get-NetTCPConnection -LocalPort 3000 -State Listen -ErrorAction SilentlyContinue
        if ($port) { $served = $true }
    }
    if (-not $served) { throw "http-server failed to start within 30s" }
    LogStep ("serve OK in {0:N1}s" -f ((Get-Date) - $serveStart).TotalSeconds)

    # ─── 4. TESTS ───
    Push-Location "$root\tests\e2e"
    try {
        if ($Suite -ne "") {
            LogStep "test: specific suite '$Suite'"
            $testStart = Get-Date
            npx jest --forceExit --runInBand "component/$Suite.test.js" --testTimeout $TestTimeoutSec
            $exitCode = $LASTEXITCODE
        } elseif ($Full) {
            LogStep "test: full regression (~6-8 min)"
            $testStart = Get-Date
            npx jest --forceExit --runInBand --testPathPattern="regression_" --testTimeout $TestTimeoutSec
            $exitCode = $LASTEXITCODE
        } else {
            LogStep "test: smoke only (~30s, default)"
            $testStart = Get-Date
            npx jest --forceExit --runInBand component/regression_smoke.test.js --testTimeout 60000
            $exitCode = $LASTEXITCODE
        }
        LogStep ("tests done in {0:N1}s exit={1}" -f ((Get-Date) - $testStart).TotalSeconds, $exitCode)
    } finally {
        Pop-Location
    }

    # ─── 5. SUMMARY ───
    $elapsed = [math]::Round(((Get-Date) - $overallStart).TotalSeconds, 1)
    if ($exitCode -eq 0) {
        Write-Host "=== CI PASS in ${elapsed}s ===" -ForegroundColor Green
    } else {
        Write-Host "=== CI FAIL in ${elapsed}s (exit=$exitCode) ===" -ForegroundColor Red
    }
} finally {
    # Always cleanup
    LogStep "cleanup: stop server + node"
    Stop-Port 3000
    Get-Process node -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}

exit $exitCode
