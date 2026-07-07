# Vision MCP wrapper for Android screenshots. Hard timeout to avoid hangs.
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][ValidateSet("analyze_image","extract_text_from_screenshot","diagnose_error_screenshot","ui_diff_check")]
    [string]$Tool,
    [Parameter(Mandatory=$true)][string]$Json,
    [int]$TimeoutSec = 90,
    [switch]$UseBuiltin
)

$ErrorActionPreference = "Stop"
$startTime = Get-Date

Write-Host "[vision] tool=$Tool timeout=${TimeoutSec}s" -ForegroundColor Cyan

# Method 1: builtin opencode tool (preferred per AGENTS.md §12.6) — handled by caller
# Method 2: external mcp-cli.exe (fallback) — path resolved via env or standard locations.
$_mcli_candidates = @(
	$env:MCP_CLI_PATH,
	([System.IO.Path]::Combine($env:USERPROFILE, ".bun", "bin", "mcp-cli.exe"))
) | Where-Object { $_ -and (Test-Path $_) }
$mcli = if ($_mcli_candidates) { $_mcli_candidates[0] } else { "" }
if ($mcli -eq "") {
	Write-Warning "[vision] mcp-cli.exe not found. Set `$env:MCP_CLI_PATH or install via 'bun install -g mcp-cli'."
	Write-Host "[vision] Use builtin opencode tools (zai-mcp-server_analyze_image etc.) instead" -ForegroundColor Yellow
	exit 2
}

# Update PATH for Bun
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","User") + ";" + [System.Environment]::GetEnvironmentVariable("Path","Machine")

$proc = Start-Process -FilePath $mcli -ArgumentList @("call", "zai-vision", $Tool, $Json) -PassThru -NoNewWindow -RedirectStandardOutput "$env:TEMP\bookwar_vision.log" -RedirectStandardError "$env:TEMP\bookwar_vision.err"
if (-not $proc.WaitForExit($TimeoutSec * 1000)) {
    Write-Warning "[vision] TIMEOUT after ${TimeoutSec}s — killing mcp-cli"
    try { $proc.Kill($true) } catch {}
    exit 124
}

$exitCode = $proc.ExitCode
$elapsed = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 1)

if (Test-Path "$env:TEMP\bookwar_vision.log") {
    Write-Host "[vision] --- result (${elapsed}s, exit=$exitCode) ---" -ForegroundColor $(if ($exitCode -eq 0){"Green"}else{"Yellow"})
    Get-Content "$env:TEMP\bookwar_vision.log" | ForEach-Object { Write-Host "  $_" }
}
if (Test-Path "$env:TEMP\bookwar_vision.err") {
    $err = Get-Content "$env:TEMP\bookwar_vision.err" -ErrorAction SilentlyContinue
    if ($err) {
        Write-Host "[vision] --- stderr ---" -ForegroundColor Yellow
        $err | Select-Object -Last 10 | ForEach-Object { Write-Host "  $_" }
    }
}

exit $exitCode
