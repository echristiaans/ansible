param (
	[Parameter(Mandatory=$true)][string]$username,
	[Parameter(Mandatory=$true)][string]$password,
	[Parameter(Mandatory=$true)][string]$color
)
#SCRIPT MAIN
clear
#Load the VMWare module and connect to vCenter
Add-PsSnapin VMware.VimAutomation.Core -ea "SilentlyContinue"
$viserver = "localhost"
$powercliconfig = Set-PowerCLIConfiguration -DisplayDeprecationWarnings:$false  -Scope:Session -confirm:$false
$viconnection = Connect-VIServer $viserver -User $username -Password $password -AllLinked:$false -ErrorAction Continue -WarningAction 0
$rootFolder = Get-Folder -Server $viserver "Datacenters"

$red = 0
$yellow = 0

#get all alarms 
	foreach ($ta in $rootFolder.ExtensionData.TriggeredAlarmState) {
		#check if alarm is acked
		if ((Get-View -Server $vc $ta.Entity).GetType().Name -ne "VirtualMachine")
		{
			if ($ta.Acknowledged -eq $false)
			{
				# check alarm color
				switch ($ta.OverallStatus)
				{
					"yellow" { $yellow += 1 }
					"red" { $red += 1 }
				}
			}
		}
	}

	#return alarm count
switch ($color)
		{
			"yellow" { return $yellow }
			"red" { return $red }
		}

	


$viconnection = Disconnect-VIServer $viserver -Confirm:$false
