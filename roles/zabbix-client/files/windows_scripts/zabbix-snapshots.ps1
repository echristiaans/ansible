param (
	[Parameter(Mandatory=$true)][string]$username,
	[Parameter(Mandatory=$true)][string]$password,
	[string]$vm,
	[string]$check,
	[string]$snapname
)

## Load vsphere plugin
Add-PsSnapin VMware.VimAutomation.Core -ea "SilentlyContinue"
$powercliconfig = Set-PowerCLIConfiguration -DisplayDeprecationWarnings:$false  -Scope:Session -confirm:$false
$viserver = "localhost"
$result = @{}
$result.data = @()

$viconnection = Connect-VIServer $viserver -Force -User $username -Password $password -AllLinked:$false -ErrorAction Continue  -WarningAction 0
If ($vm)#  -eq $Null -and $vm_check -eq '') 
{
	# return VM values
	$snap = Get-Snapshot -VM $vm -Name $snapname
	
	switch -exact ($check)
	{
		"size" { $check_value = [decimal]::round($snap.SizeMB * 1024 *1024) }
		"creationdate" { 
			$epochdate = Get-Date -Date "01/01/1970"
			$check_value =  [decimal]::round((New-TimeSpan -Start $epochdate -End $snap.Created).TotalSeconds)  
			}	
		"description" { $check_value = $snap.Description }
	}
	
	return $check_value	
	
}
else
{
	#return discovery
	foreach ($snap in Get-VM | Get-Snapshot)
	{

		$result.data += @{
	        "{#VMNAME}" = $snap.VM;
	        "{#SNAPNAME}" = $snap.name;
			"{#SNAPCREATED}" = $snap.Created
			"{#SNAPSIZE}" = [decimal]::round($snap.SizeMB)
	    }

		
	}
}
$viconnection = Disconnect-VIServer $viserver -Confirm:$false

$result | ConvertTo-Json
