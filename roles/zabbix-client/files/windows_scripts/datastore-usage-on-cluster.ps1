param (
	[Parameter(Mandatory=$true)][string]$username,
	[Parameter(Mandatory=$true)][string]$password,
	[string]$show = "allocated",
	[string]$outputas = "bytes"
)

## Load vsphere plugin
Add-PsSnapin VMware.VimAutomation.Core -ea "SilentlyContinue"
$powercliconfig = Set-PowerCLIConfiguration -DisplayDeprecationWarnings:$false  -Scope:Session -confirm:$false

$total_allocated = 0
$total_used	= 0

$viserver = "localhost"
Function Percentcal {
    param(
    [parameter(Mandatory = $true)]
    [int]$InputNum1,
    [parameter(Mandatory = $true)]
    [int]$InputNum2)
    $InputNum1 / $InputNum2*100
}


$viconnection = Connect-VIServer $viserver -User $username -Password $password -AllLinked:$false -ErrorAction Continue -WarningAction 0
	
	$datastores = Get-Datastore | Sort Name
	ForEach ($ds in $datastores)
	{
	    if ($ds.Type -match “VMFS”)
	    {
	        $PercentFree = Percentcal $ds.FreeSpaceMB $ds.CapacityMB
	        $PercentFree = “{0:N2}” -f $PercentFree
	        $ds | Add-Member -type NoteProperty -name PercentFree -value $PercentFree
			$total_allocated += $ds.CapacityGB
			$ds_used = $ds.CapacityGB - $ds.FreeSpaceGB
			$total_used += $ds_used
	    }
	}
	
	#$filename =  $csvoutputdirectory + "\datastores-" + $viserver + ".csv"
	#$datastores | Select Name,@{N=”UsedSpaceGB”;E={[Math]::Round(($_.ExtensionData.Summary.Capacity – $_.ExtensionData.Summary.FreeSpace)/1GB,0)}},@{N=”TotalSpaceGB”;E={[Math]::Round(($_.ExtensionData.Summary.Capacity)/1GB,0)}} ,PercentFree | Export-Csv $filename -NoTypeInformation
	$total_u = [math]::Round($total_used)
	$total_a = [math]::Round($total_allocated)
	$total_u_bytes = [math]::Round($total_used * 1073741824)
	$total_a_bytes = [math]::Round($total_allocated * 1073741824)

	$viconnection = Disconnect-VIServer $viserver -Confirm:$false

switch ($show)
	 { 
        "used" 
		{	
				Write-Host $total_u_bytes
		} 
        "allocated" 
		{
			Write-Host $total_a_bytes
		} 
     
    }
