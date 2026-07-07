# Wrap external mcp-cli.exe (zai-vision) with hard timeout.
# Usage: vision.ps1 -Tool analyze_image -Json '{"image_source":"C:/path/s.png","prompt":"..."}'
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Tool,
    [Parameter(Mandatory=$true)][string]$Json,
    [int]$TimeoutSec = 90
)

$ErrorActionPreference = "Stop"

# Resolve mcp-cli path without hardcoding personal user paths. Honour the
# MCP_CLI_PATH env var if set; otherwise look in standard bun bin locations.
$_mcp_candidates = @(
	$env:MCP_CLI_PATH,
	([System.IO.Path]::Combine($env:USERPROFILE, ".bun", "bin", "mcp-cli.exe")),
	([System.IO.Path]::Combine($env:LOCALAPPDATA, ".bun", "bin", "mcp-cli.exe"))
) | Where-Object { $_ -and (Test-Path $_) }
$mcp = if ($_mcp_candidates) { $_mcp_candidates[0] } else { "" }
if ($mcp -eq "") {
	Write-Error "mcp-cli.exe not found. Set `$env:MCP_CLI_PATH or install via 'bun install -g mcp-cli'."
	exit 2
}

# Refresh PATH for Bun/Node etc.
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","User") + ";" + [System.Environment]::GetEnvironmentVariable("Path","Machine")

Write-Host "[vision] call zai-vision.$Tool (timeout=${TimeoutSec}s)" -ForegroundColor Cyan

$startTime = Get-Date
$proc = Start-Process -FilePath $mcp -ArgumentList @("call", "zai-vision", $Tool, $Json) -NoNewWindow -PassThru -RedirectStandardOutput "$env:TEMP\vision_$($Tool).out" -RedirectStandardError "$env:TEMP\vision_$($Tool).err"

try {
    if (-not $proc.WaitForExit($TimeoutSec * 1000)) {
        Write-Warning "[vision] TIMEOUT after ${TimeoutSec}s — killing"
        try { $proc.Kill($true) } catch {}
        Start-Sleep -Seconds 1
        Write-Output '{"error":"timeout","tool":"' + $Tool + '","timeout_sec":' + $TimeoutSec + '}'
        exit 124
    }
    $code = $proc.ExitCode
} catch {
    Write-Error "[vision] failed: $_"
    exit 1
}

$elapsed = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 1)

if (Test-Path "$env:TEMP\vision_$($Tool).out") {
    Get-Content "$env:TEMP\vision_$($Tool).out" -Raw
}
if (Test-Path "$env:TEMP\vision_$($Tool).err") {
    $errText = Get-Content "$env:TEMP\vision_$($Tool).err" -Raw
    if ($errText -and $errText.Trim().Length -gt 0) {
        Write-Host "[vision] stderr: $errText" -ForegroundColor DarkYellow
    }
}

Write-Host "[vision] done in ${elapsed}s exit=$code" -ForegroundColor DarkGray
exit $code
