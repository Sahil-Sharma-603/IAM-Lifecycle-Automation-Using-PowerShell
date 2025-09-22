<# 
  Reads data/offboarding.csv and:
   - removes users from all groups
   - disables their accounts
   - writes CSV + HTML summary reports
#>

Param(
  [string]$ConfigPath = ".\config.psd1",
  [string]$OffboardCsv = ".\data\offboarding.csv"
)

$cfg       = Import-PowerShellDataFile $ConfigPath
$reportDir = $cfg.ReportDir
Import-Module "$PSScriptRoot\modules\Identity.psm1"  -Force
Import-Module "$PSScriptRoot\modules\Reporting.psm1" -Force

Ensure-Dir $reportDir
$rows    = Import-Csv $OffboardCsv
$summary = @()

foreach ($r in $rows) {
  $upn = $r.userPrincipalName
  try {
    $beforeGroups = (Get-UserGroups -UPN $upn) -join ';'
    Remove-UserFromAllGroups -UPN $upn | Out-Null
    $user = Disable-User -UPN $upn

    $summary += [pscustomobject]@{
      userPrincipalName = $upn
      removedGroups     = $beforeGroups
      finalStatus       = $user.status
      reason            = $r.reason
      lastDay           = $r.lastDay
      status            = 'Success'
    }
  }
  catch {
    $summary += [pscustomobject]@{
      userPrincipalName = $upn
      removedGroups     = ''
      finalStatus       = ''
      reason            = $r.reason
      lastDay           = $r.lastDay
      status            = "Failed: $($_.Exception.Message)"
    }
  }
}

$stamp   = Get-Date -Format "yyyyMMdd_HHmm"
$csvOut  = Join-Path $reportDir "offboarding_$stamp.csv"
$htmlOut = Join-Path $reportDir "offboarding_$stamp.html"
Write-CsvReport  -Data $summary -Path $csvOut   | Out-Null
Write-HtmlReport -Data $summary -Title "Offboarding Summary" -Path $htmlOut | Out-Null

"Offboarding finished. Reports created:"
$csvOut
$htmlOut

