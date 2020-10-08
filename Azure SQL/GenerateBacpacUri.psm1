function GenerateBacpacUri([string]$DatabaseName, [string]$StorageAccountName, [string]$StorageContainerName) {
    [Console]::WriteLine("*** Getting Bacpac file name for ${DatabaseName}")
    $Date = Get-Date -Format "MM-dd-yyyy--HH-mm"
    $StorageFolder = "https://${StorageAccountName}.blob.core.windows.net/${StorageContainerName}/"
    $DatedDatabaseName = "${DatabaseName}_${Date}.bacpac"
    $BacpacUri = $StorageFolder + $DatedDatabaseName
    [Console]::WriteLine("*** Done Getting Bacpac file name for ${DatabaseName}: ${BacpacUri}")
    return $BacpacUri
}