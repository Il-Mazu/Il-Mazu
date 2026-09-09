# Run with PowerShell 7 from any directory to refresh the public language chart.
$ErrorActionPreference = 'Stop'
$owner = 'Il-Mazu'
$headers = @{ 'User-Agent' = 'Il-Mazu-profile'; Accept = 'application/vnd.github+json' }
$repos = @()
$page = 1
do {
    $batch = Invoke-RestMethod -Headers $headers -Uri "https://api.github.com/users/$owner/repos?per_page=100&page=$page"
    $repos += @($batch)
    $page++
} while ($batch.Count -eq 100)
$totals = @{}
$included = @($repos | Where-Object { -not $_.fork })
foreach ($repo in $included) {
    $languages = Invoke-RestMethod -Headers $headers -Uri $repo.languages_url
    foreach ($property in $languages.PSObject.Properties) {
        $totals[$property.Name] = [long]$totals[$property.Name] + [long]$property.Value
    }
}
$sorted = @($totals.GetEnumerator() | Sort-Object Value -Descending)
$total = ($sorted | Measure-Object Value -Sum).Sum
if (-not $total) { throw 'No language data returned; the previous chart has been preserved.' }
$date = [DateTime]::UtcNow.ToString('yyyy-MM-dd')
$height = 132 + 44 * $sorted.Count
$svg = [Collections.Generic.List[string]]::new()
$svg.Add("<svg xmlns='http://www.w3.org/2000/svg' width='900' height='$height' viewBox='0 0 900 $height' role='img' aria-labelledby='title desc'>")
$svg.Add("<title id='title'>Languages across $($included.Count) public original repositories</title><desc id='desc'>Share of code bytes reported by GitHub, updated $date. This measures repository composition, not proficiency.</desc>")
$svg.Add("<rect width='900' height='$height' rx='16' fill='#0d141b'/><g font-family='Consolas,monospace'><text x='32' y='40' font-size='20' fill='#f0f5f8'>WHAT I BUILD WITH</text><text x='32' y='66' font-size='12' fill='#a2b3c2'>GitHub code bytes / $($included.Count) public original repos / $date UTC</text>")
$colors = @('#9de6b3','#a2b8ff','#e5c07b','#ef9aba','#7ad9de','#c5a5ef','#a2b3c2')
$i = 0
foreach ($row in $sorted) {
    $y = 98 + 44 * $i
    $percent = 100.0 * $row.Value / $total
    $width = (540 * $percent / 100).ToString('0.0',[Globalization.CultureInfo]::InvariantCulture)
    $label = $percent.ToString('0.0',[Globalization.CultureInfo]::InvariantCulture)
    $name = [Security.SecurityElement]::Escape($row.Name)
    $color = $colors[$i % $colors.Count]
    $svg.Add("<text x='32' y='$($y+15)' fill='#dce6ed' font-size='15'>$name</text><rect x='170' y='$y' width='540' height='20' rx='4' fill='#24313b'/><rect x='170' y='$y' width='$width' height='20' rx='4' fill='$color'/><text x='735' y='$($y+15)' fill='#dce6ed' font-size='15'>$label%</text>")
    $i++
}
$svg.Add('</g></svg>')
New-Item -ItemType Directory -Force -Path "$PSScriptRoot/assets" | Out-Null
[IO.File]::WriteAllText("$PSScriptRoot/assets/languages.svg", ($svg -join "`n"), [Text.UTF8Encoding]::new($false))
@{updated_utc=$date;repositories=@($included.name);language_bytes=$totals} | ConvertTo-Json -Depth 5 | Set-Content "$PSScriptRoot/assets/languages.json" -Encoding utf8
Write-Output "Updated chart from $($included.Count) public original repositories."
