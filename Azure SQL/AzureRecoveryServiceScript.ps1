#$PSVersionTable.PSVersion
#Get-Command *azrecoveryservices*

##Connect to our account
Connect-AzAccount -EnvironmentName AzureUSGovernment

##Get the vault ID
$resourceGroupName = "YOUR RESOURCE GROUP NAME"
$vaultName = "YOUR VAULT NAME"
$vaultID = Get-AzRecoveryServicesVault -ResourceGroupName $resourceGroupName -Name $vaultName | Select-Object -ExpandProperty ID
#$vaultID
 
##Get all of the DB's being backed up to the console
Get-AzRecoveryServicesBackupItem -BackupManagementType AzureWorkload -WorkloadType MSSQL -VaultId $vaultID

##Get all of the DB's being backed up and the filter out the one that we want
## MODIFY THE FILTER FOR THE DB YOU WANT TO RESTORE AND BE SURE TO KEEP THE PRECEDING "*" -------------------------------------------------------------VVVVVVVVVVVVVVV
$bkpItem = Get-AzRecoveryServicesBackupItem -BackupManagementType AzureWorkload -WorkloadType MSSQL -VaultId $vaultID  | Where-Object { $_.Name -like '*______' }
#$bkpItem

##Get all of the recovery points for the DB then sort them and grab the ID from latest one 
$startDate = (Get-Date).AddDays(-7).ToUniversalTime()
$endDate = (Get-Date).ToUniversalTime()
$LatestRecoveryPointID = Get-AzRecoveryServicesBackupRecoveryPoint -Item $bkpItem -VaultId $vaultID -StartDate $startdate -EndDate $endDate |  Sort-Object RecoveryPointTime -Descending | Select-Object -First 1 | Select-Object -ExpandProperty RecoveryPointID


##Get the Full Recovery Point
$FullRP = Get-AzRecoveryServicesBackupRecoveryPoint -Item $bkpItem -VaultId $vaultID -RecoveryPointId $LatestRecoveryPointID
#$FullRP

##List the full list of protected servers
##Get-AzRecoveryServicesBackupProtectableItem -WorkloadType MSSQL -ItemType SQLInstance -VaultId $vaultID

##Set the instance we are restoring to
$sqlInstanceName = "sqlinstance;mssqlserver"
$serverName = "YOUR SERVER NAME"
$TargetInstance = Get-AzRecoveryServicesBackupProtectableItem -WorkloadType MSSQL -ItemType SQLInstance -Name $sqlInstanceName -ServerName $serverName -VaultId $vaultID
#$TargetInstance

##Set everything up for the actual restore
$AnotherInstanceWithFullConfig = Get-AzRecoveryServicesBackupWorkloadRecoveryConfig -RecoveryPoint $FullRP -TargetItem $TargetInstance -AlternateWorkloadRestore -VaultId $vaultID
$AnotherInstanceWithFullConfig.OverwriteWLIfpresent = "Yes"
$AnotherInstanceWithFullConfig | Format-List

##Kick off the actual restore
Restore-AzRecoveryServicesBackupItem -WLRecoveryConfig $AnotherInstanceWithFullConfig -VaultId $vaultID

## Get the Log chain (in case we want to do point in time in the future)
##Get-AzRecoveryServicesBackupRecoveryLogChain -Item $bkpItem -VaultId $vaultID
##$AnotherInstanceWithLogConfig = Get-AzRecoveryServicesBackupWorkloadRecoveryConfig -PointInTime $PointInTime -Item $bkpItem -AlternateWorkloadRestore -VaultId $targetVault.ID
