<# 
  Generates 3 reports:
   1) who has what access (user → groups)
   2) inactive users (no login >= DormantDaysThreshold days)
   3) toxic access combinations (e.g., Finance.Read + HR.PayrollAdmin)
#>

Param(
  [string]$ConfigPath = ".\config.psd1",
  [string]$LoginCsv   = ".\data\login_activity.csv",
  [string]$ToxicCsv   = ".\data\toxic_combos.csv"
)

$cfg       = Import-PowerShellDataFile $ConfigPath
$reportDir = $cfg.ReportDir
Import-Module "$PSScriptRoot\modules\Identity.psm1"  -Force
Import-Module "$PSScriptRoot\modules\Reporting.psm1" -Force

Ensure-Dir $reportDir

# load data
$users     = Get-Users
$groups    = Get-Groups
$members   = Get-Memberships
$logins    = (Test-Path $LoginCsv) ? (Import-Csv $LoginCsv) : @()
$toxics    = (Test-Path $ToxicCsv) ? (Import-Csv $ToxicCsv) : @()

# 1) who has what
$whoHas = foreach ($m in $members) {
  $u = $users | Where-Object userPrincipalName -eq $m.userPrincipalName
  if ($null -ne $u) {
    [pscustomobject]@{
      userPrincipalName = $u.userPrincipalName
      displayName       = $u.displayName
      department        = $u.department
      groupName         = $m.groupName
      addedDate         = $m.addedDate
      userStatus        = $u.status
    }
  }
}

# 2) inactive users
$dormantDays = [int]$cfg.DormantDaysThreshold
$today = Get-Date
$inactive = foreach ($u in $users) {
  $last = ($logins | Where-Object userPrincipalName -eq $u.userPrincipalName).lastLogin
  $days = if ($last) { (New-TimeSpan -Start (Get-Date $last) -End $today).Days } else { [int]::MaxValue }
  if ($u.status -eq 'Active' -and $days -ge $dormantDays) {
    [pscustomobject]@{
      userPrincipalName = $u.userPrincipalName
      displayName       = $u.displayName
      lastLogin         = $last ? $last : 'Never'
      daysSinceLogin    = $days -ne [int]::MaxValue ? $days : 'Never'
      flag              = 'Dormant'
    }
  }
}

# 3) toxic combos
function Test-Toxic {
  param([string[]]$UserGroups, [object[]]$Rules)
  foreach ($r in $Rules) {
    if ($UserGroups -contains $r.groupA -and $UserGroups -contains $r.groupB) {
      return "$($r.groupA) + $($r.groupB)"
    }
  }
  return $null
}
$violations = @()
foreach ($u in $users.userPrincipalName) {
  $ugs = Get-UserGroups -UPN $u
  if ($ugs) {
    $hit = Test-Toxic -UserGroups $ugs -Rules $toxics
    if ($hit) {
      $user = $users | Where-Object userPrincipalName -eq $u
      $violations += [pscustomobject]@{
        userPrincipalName = $u
        displayName       = $user.displayName
        toxicCombination  = $hit
        groups            = ($ugs -join ';')
      }
    }
  }
}

# write reports (CSV + HTML)
$stamp = Get-Date -Format "yyyyMMdd_HHmm"
$whoCsv  = Join-Path $reportDir "access_whohas_$stamp.csv"
$inCsv   = Join-Path $reportDir "access_inactive_$stamp.csv"
$toxCsv  = Join-Path $reportDir "access_toxic_$stamp.csv"

Write-CsvReport  -Data $whoHas     -Path $whoCsv  | Out-Null
Write-CsvReport  -Data $inactive   -Path $inCsv   | Out-Null
Write-CsvReport  -Data $violations -Path $toxCsv  | Out-Null

Write-HtmlReport -Data $whoHas     -Title "Access: Who Has What"    -Path ($whoCsv -replace '\.csv$','.html')  | Out-Null
Write-HtmlReport -Data $inactive   -Title "Access: Inactive Users"  -Path ($inCsv  -replace '\.csv$','.html')  | Out-Null
Write-HtmlReport -Data $violations -Title "Access: Toxic Combos"    -Path ($toxCsv -replace '\.csv$','.html')  | Out-Null

"Access review finished. Reports created:"
$whoCsv, $inCsv, $toxCsv

