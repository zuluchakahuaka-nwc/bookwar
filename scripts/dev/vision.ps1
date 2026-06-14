# Wrap external mcp-cli.exe (zai-vision) with hard timeout.
# Usage: vision.ps1 -Tool analyze_image -Json '{"image_source":"C:/path/s.png","prompt":"..."}'
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Tool,
    [Parameter(Mandatory=$true)][string]$Json,
    [int]$TimeoutSec = 90
)

$ErrorActionPreference = "Stop"

$mcp = "~\.bun\bin\mcp-cli.exe"
if (-not (Test-Path $mcp)) {
    Write-Error "mcp-cli.exe not found at $mcp"
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
