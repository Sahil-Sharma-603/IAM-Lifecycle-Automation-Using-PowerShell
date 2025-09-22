# Identity.psm1
# Simple file-backed “directory”. No real AD needed.
# Stores/reads everything from ./data/*.csv so it runs anywhere.

# figure out project root and data paths (module sits in ./modules)
$ProjectRoot   = Split-Path $PSScriptRoot -Parent
$UsersCsv      = Join-Path $ProjectRoot 'data/users.csv'
$GroupsCsv     = Join-Path $ProjectRoot 'data/groups.csv'
$MembersCsv    = Join-Path $ProjectRoot 'data/memberships.csv'

function Import-CsvSafe {
    param([string]$Path)
    if (Test-Path $Path) {@( Import-Csv -Path $Path) } else { @() }
}

function Save-Csv {
    param([object[]]$Data, [string]$Path)
    $dir = Split-Path $Path
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
    $Data | Export-Csv -NoTypeInformation -Path $Path
}

function Get-Users { Import-CsvSafe $UsersCsv }
function Get-Groups { Import-CsvSafe $GroupsCsv }
function Get-Memberships { Import-CsvSafe $MembersCsv }

function Get-User {
    param([Parameter(Mandatory)][string]$UPN)
    (Get-Users | Where-Object userPrincipalName -eq $UPN)
}

function New-RandomPassword {
    param([int]$Length = 12)
    # very simple random password generator
    $letters = (65..90 + 97..122) | ForEach-Object {[char]$_}
    $digits  = 0..9
    $symbols = "!@#$%^&*?".ToCharArray() 
    $pool    = $letters + $digits + $symbols
    -join (1..$Length | ForEach-Object { $pool | Get-Random })
}

function New-User {
    <#
      creates a new user row in users.csv
      returns the new user object (including temp password)
    #>
    param(
        [Parameter(Mandatory)][string]$UPN,
        [Parameter(Mandatory)][string]$GivenName,
        [Parameter(Mandatory)][string]$Surname,
        [Parameter(Mandatory)][string]$Department,
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][string]$ManagerUPN,
        [int]$PasswordLength = 12
    )
    $users = Get-Users
    if ($users.userPrincipalName -contains $UPN) { throw "User '$UPN' already exists." }

    $temp = New-RandomPassword -Length $PasswordLength
    $row = [pscustomobject]@{
        userPrincipalName = $UPN
        displayName       = "$GivenName $Surname"
        givenName         = $GivenName
        surname           = $Surname
        department        = $Department
        title             = $Title
        managerUPN        = $ManagerUPN
        status            = 'Active'
        tempPassword      = $temp
        createdDate       = (Get-Date).ToString('yyyy-MM-dd')
    }
   # Save-Csv -Data ($users + $row) -Path $UsersCsv
	$all = @()
	if ($users) { $all += @($users) }
	$all += $row
	Save-Csv -Data $all -Path $UsersCsv
    return $row
}

function Disable-User {
    <# marks user as Disabled in users.csv #>
    param([Parameter(Mandatory)][string]$UPN)
    $users = Get-Users
    $found = $false
    foreach ($u in $users) {
        if ($u.userPrincipalName -eq $UPN) { $u.status = 'Disabled'; $found = $true }
    }
    if (-not $found) { throw "User '$UPN' not found." }
    Save-Csv -Data $users -Path $UsersCsv
    Get-User -UPN $UPN
}

function Add-UserToGroup {
    <# adds user↔group in memberships.csv (if not already present) #>
    param([string]$UPN, [string]$GroupName, [string]$Source = 'Script')
    if (-not (Get-User -UPN $UPN)) { throw "User '$UPN' not found." }
    if (-not (Get-Groups | Where-Object groupName -eq $GroupName)) { throw "Group '$GroupName' not found." }

    $m = Get-Memberships
    $exists = $m | Where-Object { $_.userPrincipalName -eq $UPN -and $_.groupName -eq $GroupName }
    if ($exists) { return $exists } # already linked

    $row = [pscustomobject]@{
        userPrincipalName = $UPN
        groupName         = $GroupName
        addedDate         = (Get-Date).ToString('yyyy-MM-dd')
        source            = $Source
    }
	$all = @()
	if ($m) { $all += @($m) }
	$all += $row
	Save-Csv -Data $all -Path $MembersCsv    
#Save-Csv -Data ($m + $row) -Path $MembersCsv
    $row
}

function Remove-UserFromAllGroups {
    <# deletes all user↔group rows for this UPN #>
    param([string]$UPN)
    $m = Get-Memberships
    $kept = $m | Where-Object { $_.userPrincipalName -ne $UPN }
    Save-Csv -Data $kept -Path $MembersCsv
}

function Get-UserGroups {
    param([string]$UPN)
    (Get-Memberships | Where-Object userPrincipalName -eq $UPN).groupName
}

Export-ModuleMember -Function *-User, *-Users, *-Groups, *-Memberships, Add-UserToGroup, Remove-UserFromAllGroups, Get-UserGroups, New-RandomPassword

