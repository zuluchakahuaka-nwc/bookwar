# End-to-end verification: ensure server up on :3000, run smoke tests, vision-analyze main screenshot.
[CmdletBinding()]
param(
    [int]$TimeoutSec = 300,
    [int]$Port = 3000
)

$ErrorActionPreference = "Stop"

Write-Host "[verify] probing http://localhost:$Port..." -ForegroundColor Cyan
$up = $false
$deadline = (Get-Date).AddSeconds($TimeoutSec)
while ((Get-Date) -lt $deadline) {
    try {
        $r = Invoke-WebRequest -Uri "http://localhost:$Port/" -UseBasicParsing -TimeoutSec 3
        if ($r.StatusCode -eq 200) { $up = $true; break }
    } catch {
        Start-Sleep -Seconds 2
    }
}
if (-not $up) {
    Write-Error "[verify] server not responding on :$Port after ${TimeoutSec}s — start serve.ps1 first"
    exit 1
}
Write-Host "[verify] server OK" -ForegroundColor Green

# Run regression smoke only (fast)
$smoke = "D:\Projects\BOOKWAR\scripts\dev\test.ps1"
& $smoke -Suite "component/regression_smoke" -OverallTimeoutSec 600
$code = $LASTEXITCODE
if ($code -ne 0) {
    Write-Error "[verify] regression_smoke failed (exit=$code)"
    exit $code
}

# Find latest screenshot and run vision on it
$shotDir = "D:\Projects\BOOKWAR\tests\e2e\screenshots"
$latest = Get-ChildItem -Path $shotDir -Filter "*.png" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($latest) {
    $path = $latest.FullName -replace '\\','/'
    Write-Host "[verify] vision analyzing $($latest.Name)..." -ForegroundColor Cyan
    $json = '{"image_source":"' + $path + '","prompt":"Это скриншот RPG-игры BOOKWAR (мрачное средневековье, Godot HTML5). Опиши что видно: главное меню, игровое поле, инвентарь, бой, диалог? Есть ли ошибки рендера (чёрный экран, отсутствие UI)? Оцени играбельность."}'
    & "D:\Projects\BOOKWAR\scripts\dev\vision.ps1" -Tool analyze_image -Json $json -TimeoutSec 90
} else {
    Write-Warning "[verify] no screenshots found in $shotDir"
}

exit 0
