#Attempt to sort elevation
#if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit }

import-module storage

#Mount MSSQL 2014
    $imagepath = "C:\Scripts\SW_DVD9_SQL_Svr_Standard_Edtn_2014w_SP1_64Bit_English_-2_MLF_X20-29010.iso"
    $Image = Mount-DiskImage -ImagePath $imagepath -NoDriveLetter -PassThru
    $Vol = Get-Volume -DiskImage $Image
    $Drive = Get-WmiObject win32_volume -Filter "Label = '$($Vol.FileSystemLabel)'" -ErrorAction Stop
    
    new-item -ItemType directory C:\Scripts\mount | out-null
    $Drive.AddMountPoint('C:\scripts\mount') | out-null

#write-host "Image mounted ?"
#    gci c:\scripts\mount
#    get-volume | ft ; pause

### Install SQL 2014 here

$command="c:\scripts\mount\setup.exe /ConfigurationFile=`"c:\scripts\SQL-2014.ini`" /IACCEPTSQLSERVERLICENSETERMS=true"
#$command="copy -force `"c:\scripts\mount\setup.exe`" `"C:\Scripts\setup.exe`""
$msg=Invoke-Expression -command $command -ErrorAction SilentlyContinue
#pause
#$msg=Invoke-Expression -command $command
#$Msg


$dismount = dismount-diskimage -imagepath $imagepath
#    write-host "Image Dismounted ?"
#get-volume | ft ; pause
$path = "C:\scripts\mount"
[System.IO.Directory]::Delete($Path,$true)
