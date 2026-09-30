# Batch GLM-4.6V analysis of tour screenshots. Args: prompt (single-quoted), then file paths.
param(
  [Parameter(Mandatory=$true)][string]$Prompt,
  [Parameter(Mandatory=$true)][string[]]$Files,
  [int]$TimeoutSec = 90
)
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","User") + ";" + [System.Environment]::GetEnvironmentVariable("Path","Machine")
$mcp = Join-Path $env:USERPROFILE ".bun\bin\mcp-cli.exe"
$results = @()
foreach ($f in $Files) {
  if (-not (Test-Path $f)) { Write-Output ("{0}`tMISSING" -f (Split-Path $f -Leaf)); continue }
  $json = '{"image_source":"' + ($f -replace '\\','/') + '","prompt":"' + $Prompt.Replace('"','\"') + '"}'
  $out = & $mcp call zai-vision analyze_image $json 2>&1
  $text = ($out | Out-String)
  $verdict = "?"
  if ($text -match 'VERDICT:\s*(OK[a-zA-Zа-яА-Я .,;:!?0-9ёЁ-]*)') { $verdict = $Matches[1].Trim() }
  elseif ($text -match 'Main Response') { $verdict = "NO_VERDICT_LINE" }
  elseif ($text -match 'error|timeout') { $verdict = "CALL_ERROR" }
  Write-Output ("{0}`t{1}" -f (Split-Path $f -Leaf), $verdict)
  $results += $verdict
}
$bad = ($results | Where-Object { $_ -notmatch '^OK' }).Count
Write-Output ("SUMMARY: {0}/{1} OK" -f ($results.Count - $bad), $results.Count)
