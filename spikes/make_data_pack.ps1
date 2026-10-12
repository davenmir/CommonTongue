# Generates spikes/CTSpike_Data/Pack1..4.lua: ~1 MB of synthetic phrase data
# shaped like a real language pack (id, match patterns, render template).
# Non-ASCII words are built from code points because Windows PowerShell 5
# reads BOM-less scripts as ANSI.

param([int]$BytesPerFile = 262144)

$ErrorActionPreference = "Stop"
$outDir = Join-Path $PSScriptRoot "CTSpike_Data"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$rng = New-Object System.Random(42)

function FromCodepoints([int[]]$cps) {
    ($cps | ForEach-Object { [char]::ConvertFromUtf32($_) }) -join ""
}

$words = @(
    "lfm", "lfg", "tank", "heal", "dps", "wts", "wtb", "pst", "inv", "pull",
    "ready", "boss", "trash", "key", "run", "gold", "price", "need", "for", "and",
    "suche", "danke", "bitte", "gruppe", "busco", "gracias", "grupo", "cherche",
    "merci", "cerco", "grazie", "procuro", "obrigado",
    (FromCodepoints @(0x00FC, 0x0062, 0x0065, 0x0072)),                # über
    (FromCodepoints @(0x0073, 0x0061, 0x006E, 0x0061, 0x0064, 0x006F, 0x0072)),
    (FromCodepoints @(0x043F, 0x0440, 0x0438, 0x0432, 0x0435, 0x0442)), # привет
    (FromCodepoints @(0x0442, 0x0430, 0x043D, 0x043A)),                 # танк
    (FromCodepoints @(0x0441, 0x043F, 0x0430, 0x0441, 0x0438, 0x0431, 0x043E)),
    (FromCodepoints @(0xD0F1, 0xCEE4)),                                 # 탱커
    (FromCodepoints @(0xAC10, 0xC0AC, 0xD569, 0xB2C8, 0xB2E4)),
    (FromCodepoints @(0x5766, 0x514B)),                                 # 坦克
    (FromCodepoints @(0x8C22, 0x8C22)),
    (FromCodepoints @(0x6C42, 0x7EC4))
)
$slots = @("{roles}", "{activity}", "{item}", "{price}", "{number}")

function Phrase([int]$min, [int]$max) {
    $n = $rng.Next($min, $max + 1)
    $parts = for ($i = 0; $i -lt $n; $i++) {
        if ($rng.Next(5) -eq 0) { $slots[$rng.Next($slots.Count)] }
        else { $words[$rng.Next($words.Count)] }
    }
    $parts -join " "
}

$id = 0
for ($file = 1; $file -le 4; $file++) {
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("CTSpike_DataPack = CTSpike_DataPack or { chunks = {}, bytes = 0 }")
    [void]$sb.AppendLine("local chunk = {")
    while ($utf8.GetByteCount($sb.ToString()) -lt $BytesPerFile) {
        for ($k = 0; $k -lt 100; $k++) {
            $id++
            $patterns = (1..3 | ForEach-Object { '"' + (Phrase 2 6) + '"' }) -join ", "
            $line = '    {{ id = "PHRASE_{0:D5}", match = {{ {1} }}, render = "{2}" }},' -f $id, $patterns, (Phrase 3 8)
            [void]$sb.AppendLine($line)
        }
    }
    [void]$sb.AppendLine("}")
    [void]$sb.AppendLine("CTSpike_DataPack.chunks[#CTSpike_DataPack.chunks + 1] = chunk")
    $body = $sb.ToString()
    $bytes = $utf8.GetByteCount($body)
    $body += "CTSpike_DataPack.bytes = CTSpike_DataPack.bytes + $bytes`n"
    $path = Join-Path $outDir "Pack$file.lua"
    [System.IO.File]::WriteAllText($path, $body, $utf8)
    Write-Host ("Pack{0}.lua: {1:N0} bytes" -f $file, $bytes)
}
Write-Host "Total entries: $id"
