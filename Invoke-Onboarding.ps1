<# 
  Reads data/new_hires.csv and:
   - creates users with temp passwords
   - assigns a primary group
   - writes CSV + HTML summary reports to ./reports
#>

Param(
  [string]$ConfigPath = ".\config.psd1",
  [string]$NewHiresCsv = ".\data\new_hires.csv"
)

# load config + modules
$cfg       = Import-PowerShellDataFile $ConfigPath
$reportDir = $cfg.ReportDir
Import-Module "$PSScriptRoot\modules\Identity.psm1"  -Force
Import-Module "$PSScriptRoot\modules\Reporting.psm1" -Force

Ensure-Dir $reportDir
$newHires = Import-Csv $NewHiresCsv
$summary  = @()

foreach ($h in $newHires) {
  # simple username: first initial + last name
  $upn = ("{0}{1}@corp.local" -f $h.givenName.Substring(0,1).ToLower(), $h.surname.ToLower())

  try {
    $user = New-User -UPN $upn `
      -GivenName $h.givenName -Surname $h.surname `
      -Department $h.department -Title $h.title -ManagerUPN $h.managerUPN `
      -PasswordLength $cfg.PasswordLength

    if ($h.primaryGroup) {
      Add-UserToGroup -UPN $upn -GroupName $h.primaryGroup -Source 'Onboarding' | Out-Null
    }

    $summary += [pscustomobject]@{
      userPrincipalName = $upn
      action            = 'Created'
      primaryGroup      = $h.primaryGroup
      tempPassword      = $user.tempPassword  # demo only; secure delivery in real life
      status            = 'Success'
    }
  }
  catch {
    $summary += [pscustomobject]@{
      userPrincipalName = $upn
      action            = 'Created'
      primaryGroup      = $h.primaryGroup
      tempPassword      = ''
      status            = "Failed: $($_.Exception.Message)"
    }
  }
}

$stamp   = Get-Date -Format "yyyyMMdd_HHmm"
$csvOut  = Join-Path $reportDir "onboarding_$stamp.csv"
$htmlOut = Join-Path $reportDir "onboarding_$stamp.html"
Write-CsvReport  -Data $summary -Path $csvOut   | Out-Null
Write-HtmlReport -Data $summary -Title "Onboarding Summary" -Path $htmlOut | Out-Null

"Onboarding finished. Reports created:"
$csvOut
$htmlOut

