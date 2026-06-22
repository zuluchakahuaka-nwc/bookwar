# Generate intro story illustrations (landscape) + region splashes via Pollinations.
[CmdletBinding()]
param([int]$PauseSec = 6)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$dir = "D:\Projects\BOOKWAR\assets\sprites\splash"
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

# 7 story beats (id, prompt, text shown in-game)
$scenes = @(
    @{ id="intro_1_world"; prompt="bright medieval fantasy world of words and books, people writing and singing, glowing golden letters floating in a sunny green valley, warm light, painterly storybook art"; text="Когда-то в мире звучала речь. Люди писали книги, называли вещи по имени, пели песни. Буквы жили в каждом доме, в каждом слове." },
    @{ id="intro_2_wizard"; prompt="dark evil sorcerer wizard keeper of the ban, casting a curse, ominous dark magic, swirling black clouds, medieval dark fantasy, dramatic painting"; text="Но пришёл Хранитель Запрета — древняя сущность, рождённая из страха перед силой слова. Он наложил проклятье." },
    @{ id="intro_3_scatter"; prompt="golden slavic letters scattered across dark stormy lands, runes flying away into darkness, cursed world, dark fantasy landscape, melancholic"; text="Буквы были разбросаны по тёмным землям, за пределы Светлой Долины. Способность говорить и писать была утрачена." },
    @{ id="intro_4_chaos"; prompt="chaos of people unable to speak, silent crowd in dark medieval town, confusion and despair, muted colors, dark fantasy"; text="Люди перестали понимать друг друга. Нет языка, нет слов — только хаос и молчание." },
    @{ id="intro_5_lies"; prompt="sinister false teachers whispering lies, shadowy figures manipulating, broken books and torn pages, dark propaganda, grimdark fantasy"; text="Приспешники колдуна используют только выгодные им буквы, придают им свои значения. Проверить невозможно — все книги разрушены." },
    @{ id="intro_6_doom"; prompt="dark world drowning in shadow and lies, hopeless medieval realm consumed by darkness, ominous eclipse, epic dark fantasy"; text="Мир погрязнет во лжи — если герой не соберёт буквы, победу одержат лицемеры и лжецы." },
    @{ id="intro_7_hero"; prompt="lone hero with glowing golden letter walking into dark lands, hopeful silhouette against darkness, journey beginning, epic dark fantasy, light versus dark"; text="Ты — герой. Отправляешься вернуть алфавит, восстановить правду. Буквы — это истина. Собери их все." }
)

function Save-Img($url, $outFile) {
    $tmp = Join-Path $env:TEMP ([IO.Path]::GetRandomFileName())
    for ($a = 1; $a -le 2; $a++) {
        try {
            Invoke-WebRequest -Uri $url -OutFile $tmp -TimeoutSec 90 -UseBasicParsing
            $img = [System.Drawing.Image]::FromFile($tmp)
            if ($img.Width -gt 0) { $img.Save($outFile, [System.Drawing.Imaging.ImageFormat]::Png); $img.Dispose(); return $true }
        } catch { Start-Sleep -Seconds 3 }
    }
    return $false
}

foreach ($s in $scenes) {
    $outFile = Join-Path $dir ($s.id + ".png")
    if (Test-Path $outFile) {
        $b = [System.IO.File]::ReadAllBytes($outFile)
        if ($b.Length -gt 8 -and $b[0] -eq 0x89 -and $b[1] -eq 0x50) { Write-Host "[$($s.id)] skip (valid)"; continue }
    }
    $enc = [uri]::EscapeDataString($s.prompt)
    $url = "https://image.pollinations.ai/prompt/$($enc)?width=1024&height=576&nologo=true&seed=42"
    $ok = Save-Img $url $outFile
    if ($ok) { Write-Host "[$($s.id)] OK" -ForegroundColor Green } else { Write-Host "[$($s.id)] FAILED" -ForegroundColor Red }
    Start-Sleep -Seconds $PauseSec
}
Write-Host "=== intro splash generation done ===" -ForegroundColor Cyan
Get-ChildItem $dir -Filter "intro_*.png" | Select-Object Name, Length
