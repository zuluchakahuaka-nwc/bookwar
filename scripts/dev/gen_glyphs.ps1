# Batch-generate letter glyphs via Pollinations, convert JPEG→PNG, prepare for Godot import.
[CmdletBinding()]
param(
    [int]$PauseSec = 6,
    [string]$OutDir = "D:\Projects\BOOKWAR\assets\sprites\letters",
    [string]$LettersJson = "D:\Projects\BOOKWAR\data\letters.json",
    [int]$StartPos = 1,
    [int]$EndPos = 33
)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }

# Read letter chars from letters.json
$letters = (Get-Content $LettersJson -Raw -Encoding UTF8 | ConvertFrom-Json).letters
$charByPos = @{}
foreach ($l in $letters) { $charByPos[[int]$l.position] = $l.char }

$results = @()
for ($pos = $StartPos; $pos -le $EndPos; $pos++) {
    $ch = $charByPos[$pos]
    if (-not $ch) { Write-Warning "no char for pos $pos, skip"; continue }
    $outFile = Join-Path $OutDir ("glyph_{0}.png" -f $pos)

    # Skip if already a valid PNG (first bytes 89 50 4E 47) to avoid re-downloading
    if (Test-Path $outFile) {
        $b = [System.IO.File]::ReadAllBytes($outFile)
        if ($b.Length -gt 8 -and $b[0] -eq 0x89 -and $b[1] -eq 0x50 -and $b[2] -eq 0x4E -and $b[3] -eq 0x47) {
            Write-Host "[glyph $pos ($ch)] already valid PNG, skip" -ForegroundColor DarkGray
            $results += [pscustomobject]@{pos=$pos; char=$ch; status="skip_ok"}
            continue
        }
    }

    $prompt = "ornate golden Slavic calligraphy letter $ch (Cyrillic), glowing on dark parchment, medieval manuscript card game glyph, intricate border, candle light, centered"
    $enc = [uri]::EscapeDataString($prompt)
    $seed = $pos
    $url = "https://image.pollinations.ai/prompt/$($enc)?width=128&height=128&nologo=true&seed=$seed"
    $tmpJpg = Join-Path $env:TEMP ("glyph_{0}.jpg" -f $pos)

    $ok = $false
    for ($attempt = 1; $attempt -le 2 -and -not $ok; $attempt++) {
        try {
            Invoke-WebRequest -Uri $url -OutFile $tmpJpg -TimeoutSec 60 -UseBasicParsing
            $img = [System.Drawing.Image]::FromFile($tmpJpg)
            if ($img.Width -gt 0) {
                $img.Save($outFile, [System.Drawing.Imaging.ImageFormat]::Png)
                $img.Dispose()
                $ok = $true
            }
        } catch {
            Write-Warning "[glyph $pos ($ch)] attempt $attempt failed: $_"
            Start-Sleep -Seconds 3
        }
    }
    Remove-Item $tmpJpg -Force -ErrorAction SilentlyContinue

    if ($ok) {
        Write-Host "[glyph $pos ($ch)] OK" -ForegroundColor Green
        $results += [pscustomobject]@{pos=$pos; char=$ch; status="ok"}
    } else {
        Write-Host "[glyph $pos ($ch)] FAILED" -ForegroundColor Red
        $results += [pscustomobject]@{pos=$pos; char=$ch; status="fail"}
    }
    Start-Sleep -Seconds $PauseSec
}

# Clean stale .import files so Godot reimports fresh valid textures
Get-ChildItem $OutDir -Filter "glyph_*.png.import" | ForEach-Object {
    $imp = Get-Content $_.FullName -Raw
    if ($imp -match "valid=false") {
        Remove-Item $_.FullName -Force
        Write-Host "[import] removed stale (valid=false): $($_.Name)" -ForegroundColor Yellow
    }
}

$okCount = ($results | Where-Object status -eq "ok").Count
$skipCount = ($results | Where-Object status -eq "skip_ok").Count
$failCount = ($results | Where-Object status -eq "fail").Count
Write-Host ""
Write-Host "=== GLYPH GENERATION SUMMARY ===" -ForegroundColor Cyan
Write-Host "Generated: $okCount | Skipped(valid): $skipCount | Failed: $failCount" -ForegroundColor Cyan
