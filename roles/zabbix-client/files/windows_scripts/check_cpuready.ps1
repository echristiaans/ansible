param (
	[Parameter(Mandatory=$true)][string]$username,
	[Parameter(Mandatory=$true)][string]$password,
	[Parameter(Mandatory=$true)][string]$Cluster,
	[int]$Threshold = 5,
	[int]$Hours = 24,
	[string]$checkresult = "highest"
)
#SCRIPT MAIN
clear
#Load the VMWare module and connect to vCenter
Add-PsSnapin VMware.VimAutomation.Core -ea "SilentlyContinue"
$powercliconfig = Set-PowerCLIConfiguration -DisplayDeprecationWarnings:$false  -Scope:Session -confirm:$false
$viserver = "localhost"
$viconnection = Connect-VIServer $viserver -User $username -Password $password -AllLinked:$false -ErrorAction Continue -WarningAction 0
$vm = Get-Cluster $cluster | Get-VM
$metric = "cpu.ready.summation"
$start = (Get-Date).AddDays(-$Days)
$counter=0
$highest = 0


$start = (Get-Date).AddHours(-$Hours)
foreach ($ThisVM in $vm){
    if ($ThisVM.PowerState -eq "PoweredOn"){
        if ($metric -eq "cpu.ready.summation"){
            foreach ($Report in $(Get-Stat -IntervalSecs 900 -Entity $ThisVM -Stat $metric -Start $start -Erroraction "silentlycontinue")){
                $ReadyPercentage = (($Report.Value/10)/$Report.IntervalSecs)
                $PerReadable =  [math]::Round($ReadyPercentage,2)
				if ($ReadyPercentage -gt $Threshold){
					$time = Get-Date
					$logstring = "$time - $($Report.Entity), $($Report.Timestamp), $PerReadable%"
					$Logfile = $PSScriptRoot + "\" + $Cluster +" _CPUready.log"
					Add-content $Logfile -value $logstring
					$counter++
					
					
					
                }
				if ($PerReadable -gt $highest)
					{
						$highest = $PerReadable
					}
            }
        }
        else{
            write-output "This script does not yet accomodate $metric"
        }
    }
}
if ($checkresult -eq "counter")
{
	write-output $counter
}
if ($checkresult -eq "highest")
{
	Write-Output $highest.ToString().replace(',','.')
}
$viconnection = Disconnect-VIServer $viserver -Confirm:$false
