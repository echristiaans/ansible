PARAM (
	[PARAMETER(MANDATORY=$TRUE)][STRING]$USERNAME,
	[PARAMETER(MANDATORY=$TRUE)][STRING]$PASSWORD,
	[STRING]$CHECKENTITY = "DISCOVERY",
	[STRING]$CHECKENTITYTYPE
)
#SCRIPT MAIN
clear
#Load the VMWare module and connect to vCenter
Add-PsSnapin VMware.VimAutomation.Core -ea "SilentlyContinue"

$viserver = "localhost"

$viconnection = Connect-VIServer $viserver -User $username -Password $password -AllLinked:$false -ErrorAction Continue -WarningAction 0
$rootFolder = Get-Folder -Server $viserver "Datacenters"
$result = @{}
$result.data = @()

$red = 0
$yellow = 0



#VirtualMachine - VirtualMachine.Config.Rename
#Datacenter - Datacenter.Rename
#Folder - Folder.Rename
#VirtualApp - VApp.Rename
#ResourcePool - Resource.RenamePool
#ClusterComputeResource - Host.Inventory.RenameCluster
#DistributedVirtualSwitch - DVSwitch.Modify
#DistributedVirtualPortgroup - DVPortgroup.Modify
#Datastore - Datastore.Rename
#Network - System.Read
 
	foreach ($ta in $rootFolder.ExtensionData.TriggeredAlarmState) {

		$entity = Get-View -Server $vc $ta.Entity
		$alarmentity = (Get-View -Server $vc $ta.Alarm).Info.Name
		$entitytype = (Get-View -Server $vc $ta.Entity).GetType().Name
		$entity = (Get-View -Server $vc $ta.Entity).Name
		$time = $ta.Time
		$acknowledged = $ta.Acknowledged
			
		
		
		if ($checkentity -eq "discovery")
		{
			
			if (!$acknowledged -and $entitytype -ne "VirtualMachine")
				{
					$result.data += @{
				        "{#ENTITY}" = $entity;
				        "{#ALARMENTITY}" = $ta.Alarm
						"{#ALARMENTITYNAME}" = $alarmentity
						"{#ENTITYTYPE}" = $entitytype
						"{#TIME}" = $ta.Time
						"{#COLOR}" = $ta.OverallStatus
			    	}
				}



		}
		
		if ($checkentity -eq $entity -and $checkentitytype -eq $entitytype)
		{
			$viconnection = Disconnect-VIServer $viserver -Confirm:$false

			return $ta.OverallStatus.value__
			
		}
		
	}
	
if ($checkentity -eq "discovery")
{
	$viconnection = Disconnect-VIServer $viserver -Confirm:$false

	return $result | ConvertTo-Json
}

