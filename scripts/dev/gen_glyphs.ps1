Add-Type -AssemblyName System.Web
$letters = @('A','B','V','G','D','E','YO','ZH','Z','I','Y','K','L','M','N','O','P','R','S','T','U','F','H','C','CH','SH','SCH','HZ','YI','MZ','E2','YU','YA')
$cyrillic = @('А','Б','В','Г','Д','Е','Ё','Ж','З','И','Й','К','Л','М','Н','О','П','Р','С','Т','У','Ф','Х','Ц','Ч','Ш','Щ','Ъ','Ы','Ь','Э','Ю','Я')
$outDir = "D:\Projects\BOOKWAR\assets\sprites\letters"
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }
$ok = 0; $fail = 0
for ($i = 0; $i -lt $cyrillic.Count; $i++) {
    $cyr = $cyrillic[$i]
    $out = Join-Path $outDir "glyph_$cyr.png"
    if ((Test-Path $out) -and ((Get-Item $out).Length -gt 1000)) { $ok++; continue }
    $prompt = [System.Web.HttpUtility]::UrlEncode("ornate golden Slavic calligraphy Cyrillic letter $cyr on dark parchment, medieval card game glyph, glowing intricate border, fantasy")
    $url = "https://image.pollinations.ai/prompt/$($prompt)?width=128&height=128&nologo=true&seed=$($i+1)"
    $done = $false
    for ($attempt = 0; ($attempt -lt 4) -and (-not $done); $attempt++) {
        try {
            Invoke-WebRequest -Uri $url -OutFile $out -TimeoutSec 50 -UseBasicParsing
            if ((Get-Item $out).Length -gt 1000) { $done = $true }
        } catch {}
        if (-not $done) { Start-Sleep -Seconds 8 }
    }
    if ($done) { $ok++; Write-Host "$cyr " -NoNewline }
    else { $fail++; Write-Host "${cyr}:X " -NoNewline }
    Start-Sleep -Seconds 4
}
Write-Host "`nDone: ok=$ok fail=$fail"
