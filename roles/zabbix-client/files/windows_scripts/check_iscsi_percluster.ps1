param (
	[Parameter(Mandatory=$true)][string]$username,
	[Parameter(Mandatory=$true)][string]$password,
	[Parameter(Mandatory=$true)][string]$Cluster
)
#SCRIPT MAIN
clear
#Load the VMWare module and connect to vCenter
Add-PsSnapin VMware.VimAutomation.Core -ea "SilentlyContinue"
$powercliconfig = Set-PowerCLIConfiguration -DisplayDeprecationWarnings:$false  -Scope:Session -confirm:$false
$viserver = "localhost"
#$viserver = "sen-vcenter-g1.wc.sentia.org"
$viconnection = Connect-VIServer $viserver -User $username -Password $password -AllLinked:$false -ErrorAction Continue -WarningAction 0
$vmhosts = Get-Cluster $cluster | Get-VMHOST
$iscsi_count = 0
foreach ($vmhost in $vmhosts)
{
	$hosthbas = $vmhost | Get-VMHostHba
	foreach ($hosthba in $hosthbas)
	{
		if ($hosthba.Status -eq "online")
		{
			if ($hosthba.ScsiLunUids.count -gt $iscsi_count) 
			{
				$iscsi_count = $hosthba.ScsiLunUids.count
			}
			
			Write-Host $iscsi_count
			return
		}
	}


}
$viconnection = Disconnect-VIServer $viserver -Confirm:$false

Write-Host $iscsi_count

