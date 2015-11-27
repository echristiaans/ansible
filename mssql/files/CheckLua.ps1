$res = Get-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\policies\system' | select -expandproperty EnableLua
if ($res -like "0") {write-host "SUCCESS: UAC is disabled on this host" ;exit } 
	else 
{write-host "FAILED: UAC is enabled this playbook will not succeed"}
