[CmdletBinding()] 
Param 
(
    $sqlInstance,
    $dbname,
    $type
)

if($sqlInstance -eq ""){ $sqlServer = "localhost"; }else {$sqlServer = "localhost\$sqlInstance";}


# Build up the SQL Connection
$query = "SELECT msdb.dbo.backupset.database_name, CONVERT(varchar(23), MAX(msdb.dbo.backupset.backup_finish_date), 120) as last_backup,
			CASE msdb..backupset.type WHEN 'D' THEN 'Database' WHEN 'L' THEN 'Log' END AS backup_type
            FROM msdb.dbo.backupset, master.dbo.sysdatabases
            WHERE msdb.dbo.backupset.type = 'D' AND master.dbo.sysdatabases.name = msdb.dbo.backupset.database_name
                 AND msdb.dbo.backupset.database_name <> 'tempdb' AND msdb.dbo.backupset.database_name <> 'model' 
                 AND msdb.dbo.backupset.database_name <> 'msdb' AND msdb.dbo.backupset.database_name <> 'master'
            GROUP BY msdb.dbo.backupset.database_name, msdb.dbo.backupset.type
        UNION  
          SELECT master.dbo.sysdatabases.NAME AS database_name, '1970-01-01 00:00:00' AS [last_backup],
		    CASE msdb..backupset.type WHEN 'D' THEN 'Database' WHEN 'L' THEN 'Log' END AS backup_type
            FROM master.dbo.sysdatabases LEFT JOIN msdb.dbo.backupset ON master.dbo.sysdatabases.name = msdb.dbo.backupset.database_name 
            WHERE msdb.dbo.backupset.database_name IS NULL AND master.dbo.sysdatabases.name <> 'tempdb' AND master.dbo.sysdatabases.name <> 'model' 
                 AND master.dbo.sysdatabases.name <> 'msdb' AND master.dbo.sysdatabases.name <> 'master'
            ORDER BY msdb.dbo.backupset.database_name";
   
$conn = New-Object System.Data.SqlClient.SqlConnection; 
$connstring = "Server=$sqlServer;Database=msdb;Integrated Security=True";

$conn.ConnectionString = $connString; 
$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
$SqlCmd.CommandText = $query;
$SqlCmd.Connection = $conn;

$SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter;
$SqlAdapter.SelectCommand = $SqlCmd;

try{   # The SQL connection
    $DataSet = New-Object System.Data.DataSet;
    $ResultCount = $SqlAdapter.Fill($DataSet);
    $Conn.Close()
}
catch{  # SQL conenction failed
    return @{"error" = $_.Exception.Message} | ConvertTo-Json
}

if($dbname -and $type){
    $last_backup = $DataSet.Tables[0] | ? { $_.database_name -eq $dbname -and $_.backup_type -eq $type } | select -ExpandProperty last_backup
    $epochdate = Get-Date -Date "01/01/1970"
    $check_value =  [decimal]::round((New-TimeSpan -Start $epochdate -End $last_backup).TotalSeconds)
    $check_value
}else{
    $zabbix_discovery = @{}
    $zabbix_discovery.data = @()
    $DataSet.Tables[0] | foreach {
        $zabbix_discovery.data += @{"{#DBNAME}" = $_.database_name; 
                                    "{#TYPE}" = $_.backup_type;
                                    "{#LASTBACKUP}" = $_.last_backup }
    }
  $zabbix_discovery | ConvertTo-Json
}