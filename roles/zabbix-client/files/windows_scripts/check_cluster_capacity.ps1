param (
	[Parameter(Mandatory=$true)][string]$username,
	[Parameter(Mandatory=$true)][string]$password,
	[Parameter(Mandatory=$true)][string]$Cluster,
	[Parameter(Mandatory=$true)][string]$check,
	[string]$target = "vm"
)

Function Get-Increment([float] $value, [int] $increment=5){    
    if($value -gt 1)
    {
      [Math]::Ceiling($value / $increment) * $increment;
    }
    else
    {
      [math]::Ceiling($value)    
    }    
}

#$username = "wc\scr_vcenter"
#$password = "ad0ma2aa3Giichah"
#$cluster = "sen-vmnimg-c02-R630"
#$target = "host"
#$check = "memory"

#SCRIPT MAIN
clear
#Load the VMWare module and connect to vCenter
Add-PsSnapin VMware.VimAutomation.Core -ea "SilentlyContinue"
$powercliconfig = Set-PowerCLIConfiguration -DisplayDeprecationWarnings:$false  -Scope:Session -confirm:$false
$viserver = "localhost"

$cpu_count = 0
$mem_gb = 0
$mem_usage_gb = 0
$hd_gb = 0
$hd_used_gb = 0
$vm_count

$filepath = $PSScriptRoot
$hostfile = $filepath + "\host_$cluster.log"
$vmfile = $filepath + "\vm_$cluster.log"

if ($check -eq "get_data")
{
	$viconnection = Connect-VIServer $viserver -User $username -Password $password -AllLinked:$false -ErrorAction Continue -WarningAction 0
	$vms = Get-Cluster $cluster | Get-VM  | Select Name,NumCPU,PowerState,MemoryGB,UsedSpaceGB,@{N="HDs";E={$_ | Get-HardDisk}}
	$vms | Export-Clixml $vmfile
	
	$VMhosts = Get-Cluster $cluster | Get-VMHost | select Name,HyperthreadingActive,MemoryTotalGB,MemoryUsageGB,ExtensionData
	$VMhosts | Export-Clixml $hostfile
	
	return 1
		#Disconnect from vcenter
	$viconnection = Disconnect-VIServer $viserver -Confirm:$false

}



if ($target -eq "vm")
{

	if (Test-Path $vmfile)
	{
		$vms = Import-Clixml $vmfile
	}
	else
	{
		return "unable to find $vmfile"
	}
	
	foreach ($vm in $vms)
	{
		$vmcount++
		$cpu_count += $vm.NumCpu
		$mem_gb += $vm.MemoryGB
		
		#$HDs = $vm | Get-HardDisk
		if ($check -eq "harddisks")
		{
			foreach ($HD in $vm.HDs)
			{
				$hd_gb += $HD.CapacityGB
			}
		}
		$hd_used_gb += $vm.UsedSpaceGB
	}

}
if ($target -eq "host")
{
	
	if (Test-Path $hostfile)
	{
		$VMhosts = Import-Clixml $hostfile
	}
	else
	{
		return "unable to find $hostfile"
	
	}
	
	foreach ($VMhost in $VMhosts)
	{
		#$VMView = $VMhost | Get-View	
		if ($VMhost.HyperthreadingActive)
			{
				$hyperthreading = 2
			}
			else
			{
				$hyperthreading = 1
			}
			
		#$cpu_count = $VMview.hardware.cpuinfo.numCpuCores * $hyperthreading
		$cpu_count = $VMhost.ExtensionData.Summary.Hardware.NumCpuThreads
		$mem_gb += $VMhost.MemoryTotalGB
		$mem_usage_gb +=  $VMhost.MemoryUsageGB
	}

}


switch ($check)
{
	"vmcount" {return $vmcount } # target vm and host
	"cpu" {return $cpu_count } # target vm and host
	"memory" {return [math]::Round($mem_gb *1073741824) } #target vm and host
	"memory_usage" { return [math]::Round($mem_usage_gb * 1073741824) } # target "host" only
	"harddisks" { return [math]::Round($hd_gb*1073741824) } # target vm only
	"harddisks_used" { return [math]::Round($hd_used_gb*1073741824)} # target vm only


}
