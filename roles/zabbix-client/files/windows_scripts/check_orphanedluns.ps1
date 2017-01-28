param (
	[Parameter(Mandatory=$true)][string]$username,
	[Parameter(Mandatory=$true)][string]$password,
	[Parameter(Mandatory=$true)][string]$Cluster,
	[string]$output = "count"
)
##########################################################
## Author: Rick van Vliet 
## Version: 0.1
## Function: Return the number of orphaned luns per cluster
## Date: 17-10-2016
## You need some extra permissions in vsphere host.config.storage
## the script will return the highest number of orphaned luns per host in the cluster

#SCRIPT MAIN
clear
#Load the VMWare module and connect to vCenter
Add-PsSnapin VMware.VimAutomation.Core -ea "SilentlyContinue"
$filepath = $PSScriptRoot

$viserver = "localhost"
$viconnection = Connect-VIServer $viserver -User $username -Password $password -AllLinked:$false -ErrorAction Continue -WarningAction 0

#$startTime = Get-Date
#Write-Host "The script was started $startTime"
$outputstring = @()
$vmhosts = Get-Cluster $cluster | Get-VMHOST

$orphanedlun_count = 0
foreach ($vmhost in $vmhosts)
{	
	$orphanedlun_currenthost = 0
	#Write-Host "Collecting Free SCSI LUN(Non-RDM/VMFS) details from host $vmHost ...."
	(get-view (get-vmhost -name $vmHost | Get-View ).ConfigManager.DatastoreSystem).QueryAvailableDisksForVmfs($null) | %{
		$naaid = $_.CanonicalName
		#Write-Host "Orphaned LUN: " +  $naaid + " Vendor: " + $DiskTemp.Vendor
		#insert-obj -esxHost $vmHost -cnName $naaid -rnName $DiskTemp.RuntimeName -Type FREE -CapacityGB $DiskTemp.CapacityGB -ArrayName LUNDetails
		$orphanedlun_currenthost++
		
		$time = Get-Date
		$logstring = "$time - $vmhost - OrphanedLun: $naaid"
		$outputstring += $logstring
		
	}
	
	if ($orphanedlun_currenthost -gt $orphanedlun_count)
	{
		$orphanedlun_count = $orphanedlun_currenthost
	}
	
	
	
}`
#	$endTime = Get-Date
#	Write-Host "The script was started $endTime"
	
if ($output -eq "count")
{
	Write-Host $orphanedlun_count
}
else
{
	
	foreach ($line in $outputstring)
	{
		Write-Host $line
	}
}


