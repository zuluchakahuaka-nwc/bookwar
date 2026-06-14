# Run jest e2e tests with timeouts. Auto-rerun flaky failures once.
[CmdletBinding()]
param(
    [string]$Suite = "",
    [int]$JestTimeoutMs = 120000,
    [int]$OverallTimeoutSec = 1500,
    [switch]$NoFlakeRetry,
    [switch]$ListOnly
)

$ErrorActionPreference = "Stop"
$e2e = "D:\Projects\BOOKWAR\tests\e2e"

if (-not (Test-Path "$e2e\node_modules\jest\bin\jest.js")) {
    Write-Host "[test] installing deps..." -ForegroundColor Cyan
    npm install --prefix $e2e --silent 2>&1 | Out-Null
}

if ($ListOnly) {
    node "$e2e\node_modules\jest\bin\jest.js" --listTests --config "$e2e\jest.config.js"
    exit 0
}

$args = @(
    "node_modules/jest/bin/jest.js",
    "--config", "jest.config.js",
    "--verbose",
    "--forceExit",
    "--testTimeout=$JestTimeoutMs"
)
if ($Suite -ne "") { $args += $Suite }

$startTime = Get-Date
$exitCode = 0

Write-Host "[test] running suite='$Suite' timeout=${OverallTimeoutSec}s flakeRetry=$(-not $NoFlakeRetry)" -ForegroundColor Cyan

$proc = Start-Process -FilePath "node" -ArgumentList $args -WorkingDirectory $e2e -NoNewWindow -PassThru
try {
    if (-not $proc.WaitForExit($OverallTimeoutSec * 1000)) {
        Write-Warning "[test] OVERALL TIMEOUT after ${OverallTimeoutSec}s — killing"
        try { $proc.Kill($true) } catch {}
        $exitCode = 124
    } else {
        $exitCode = $proc.ExitCode
    }
} catch {
    try { $proc.Kill($true) } catch {}
    $exitCode = 1
}

$elapsed = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 1)
Write-Host "[test] finished in ${elapsed}s exit=$exitCode" -ForegroundColor $(if ($exitCode -eq 0) {"Green"} else {"Red"})

# Auto-rerun on failure (flake handling)
if ($exitCode -ne 0 -and -not $NoFlakeRetry) {
    Write-Host "[test] retrying failed once for flake..." -ForegroundColor Yellow
    $proc2 = Start-Process -FilePath "node" -ArgumentList ($args + @("--onlyFailures")) -WorkingDirectory $e2e -NoNewWindow -PassThru
    if (-not $proc2.WaitForExit($OverallTimeoutSec * 1000)) {
        try { $proc2.Kill($true) } catch {}
        exit 124
    }
    $exitCode = $proc2.ExitCode
    if ($exitCode -eq 0) { Write-Host "[test] flake retry passed" -ForegroundColor Green }
}

exit $exitCode
