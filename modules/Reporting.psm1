# Reporting.psm1
# Helpers to write CSV and simple HTML summaries

function Ensure-Dir {
    param([string]$Path)
    if (-not (Test-Path $Path)) { New-Item -ItemType Directory -Path $Path | Out-Null }
}

function Write-CsvReport {
    param([object[]]$Data, [string]$Path)
    $Data | Export-Csv -NoTypeInformation -Path $Path
    $Path
}

function Write-HtmlReport {
    param([object[]]$Data, [string]$Title, [string]$Path)
    $html = $Data | ConvertTo-Html -PreContent "<h2>$Title</h2>" | Out-String
    Set-Content -Path $Path -Value $html
    $Path
}

Export-ModuleMember -Function Ensure-Dir, Write-CsvReport, Write-HtmlReport

