# Taken from https://docs.microsoft.com/en-us/azure/sql-database/scripts/sql-database-import-from-bacpac-powershell

Import-Module .\SetSubscription.psm1
Import-Module .\GetImportExportStatus.psm1

try {
    # TODO: Stop the related web apps before importing into them, the turn them back on after the import.
    #   Will also need to re-index them.
    # TODO: Support passing in the database names ahead of time

    # Connect to Azure
    [Console]::WriteLine("*** Logging into Azure")
    $AzureLogin = Get-Credential -Message "Azure Portal Login"
    Connect-AzAccount -Credential $AzureLogin
    [Console]::WriteLine("*** Done Logging into Azure")

    # TODO: Check if we are logged in (somehow?), if we didn't, bail out with an error/warning message

    # Connect to the Menu Planner Dev Test UAT Subscription (contains the Shared Resouce Group)
    $SharedSubscriptionName = "Menu Planner Dev Test UAT"
    SetSubscription -Credential $AzureLogin -SubscriptionName $SharedSubscriptionName

    # Shared Storage Credentials
    $SharedResourceGroupName = "MenuPlanner-Shared"
    $SharedStorageAccountName = "menuplannerblobshared"
    $StorageContainerName = "dataimport"

    $StorageKeytype = "StorageAccessKey" # Portal -> Resource Group -> Storage -> Access keys -> key1/2 -> key
    [Console]::WriteLine("*** Getting Storage Key for " + ($SharedResourceGroupName, $SharedStorageAccountName, $StorageContainerName) -join " ")
    $StorageKey = $(Get-AzStorageAccountKey -ResourceGroupName $SharedResourceGroupName -StorageAccountName $SharedStorageAccountName).Value[0]
    [Console]::WriteLine("*** Done Getting Storage Key for " + ($SharedResourceGroupName, $SharedStorageAccountName, $StorageContainerName) -join " ")

    [Console]::WriteLine("*** Getting Storage Context for " + ($SharedResourceGroupName, $SharedStorageAccountName, $StorageContainerName) -join " ")
    $StorageContext = New-AzStorageContext -StorageAccountName $SharedStorageAccountName -StorageAccountKey $StorageKey
    [Console]::WriteLine("*** Done Getting Storage Context for " + ($SharedResourceGroupName, $SharedStorageAccountName, $StorageContainerName) -join " ")

    # TODO: Check if we got the storage key, if we didn't, bail out with an error/warning message

    $AllBacpacs = Get-AzStorageBlob -Container $StorageContainerName -Context $StorageContext
    # Get Auth Db File Name
    $AuthDbBacpacFileName = $AllBacpacs | Sort-Object LastModified -Descending | Where-Object Name -Like auth* | Select-Object -ExpandProperty Name
    # Get Management Db File Name
    $ManagementDbBacpacFileName = $AllBacpacs | Sort-Object LastModified -Descending | Where-Object Name -Like management* | Select-Object -ExpandProperty Name
    # Get Menu Planner Db File Name
    $MenuPlannerDbBacpacFileName = $AllBacpacs | Sort-Object LastModified -Descending | Where-Object Name -Like menuplanner* | Select-Object -ExpandProperty Name

    ## Server Creds and target
    # Get an admin login and password for the Dev server
    $MenuPlannerDevResourceGroupName = "MenuPlanner-Dev"
    $MenuPlannerDevServerUserName = "menuplanner-dev"

    [Console]::WriteLine("*** Getting Dev Server Password From Key Vault")
    $MenuPlannerDevServerPassword = (Get-AzKeyVaultSecret -VaultName "menuplannerkvdev" -Name "SqlServerPassword").SecretValue
    # TODO: Check if we got the password, if we didn't, bail out with an error/warning message
    [Console]::WriteLine("*** Done Getting Dev Server Password From Key Vault")

    $MenuPlannerDevServerName = "menuplanner-dbserver-dev"
    $Date = Get-Date -Format "MM-dd-yyyy--HH-mm"

    # TODO: Pass in the environment name
    #   Or, pass in the full name and delete/rename any existing dbs with that name
    # Auth Db
    $MenuPlannerDevAuthDatabaseName = "auth-db-dev_" + $Date
    # Management Db
    $MenuPlannerDevManagementDatabaseName = "management-db-dev_" + $Date
    # Menu Planner Db
    $MenuPlannerDevMenuPlannerDatabaseName = "menuplanner-db-dev_" + $Date

    [Console]::WriteLine("*** Stopping Dev Web Apps")
    $AllWebAppNames = Get-AzWebApp | Select-Object -ExpandProperty Name # Gets All Dev, Test, and UAT web app names. Will be useful when I decided to import to more than just Dev.
    $AllDevWebAppNames = $AllWebAppNames | Where-Object {$_ -match "menuplanner-(auth-service|management-api|api)-dev"} # Change "-dev" to "-(dev|test|uat)" when you want to expand the environments
    foreach($WebAppName in $AllDevWebAppNames) {
        [Console]::WriteLine("+++ Stopping " + $WebAppName)
        Stop-AzWebApp -ResourceGroupName $MenuPlannerDevResourceGroupName -Name $WebAppName
    }
    [Console]::WriteLine("*** Done Stopping Dev Web Apps")

    # TODO: Check if the db exists first, if it does, bail out with an error/warning message
    # Import bacpac to database with an S3 performance level
    [Console]::WriteLine("*** Importing")
    $importAuthRequest = New-AzSqlDatabaseImport -ResourceGroupName $MenuPlannerDevResourceGroupName `
        -ServerName $MenuPlannerDevServerName `
        -DatabaseName $MenuPlannerDevAuthDatabaseName `
        -DatabaseMaxSizeBytes "262144000" `
        -StorageKeyType $StorageKeytype `
        -StorageKey $StorageKey `
        -StorageUri "https://$SharedStorageAccountName.blob.core.windows.net/$StorageContainerName/$AuthDbBacpacFileName" `
        -Edition "Standard" `
        -ServiceObjectiveName "S3" `
        -AdministratorLogin $MenuPlannerDevServerUserName `
        -AdministratorLoginPassword $MenuPlannerDevServerPassword

    $importManagementRequest = New-AzSqlDatabaseImport -ResourceGroupName $MenuPlannerDevResourceGroupName `
        -ServerName $MenuPlannerDevServerName `
        -DatabaseName $MenuPlannerDevManagementDatabaseName `
        -DatabaseMaxSizeBytes "262144000" `
        -StorageKeyType $StorageKeytype `
        -StorageKey $StorageKey `
        -StorageUri "https://$SharedStorageAccountName.blob.core.windows.net/$StorageContainerName/$ManagementDbBacpacFileName" `
        -Edition "Standard" `
        -ServiceObjectiveName "S3" `
        -AdministratorLogin $MenuPlannerDevServerUserName `
        -AdministratorLoginPassword $MenuPlannerDevServerPassword

    $importMenuPlannerRequest = New-AzSqlDatabaseImport -ResourceGroupName $MenuPlannerDevResourceGroupName `
        -ServerName $MenuPlannerDevServerName `
        -DatabaseName $MenuPlannerDevMenuPlannerDatabaseName `
        -DatabaseMaxSizeBytes "262144000" `
        -StorageKeyType $StorageKeytype `
        -StorageKey $StorageKey `
        -StorageUri "https://$SharedStorageAccountName.blob.core.windows.net/$StorageContainerName/$MenuPlannerDbBacpacFileName" `
        -Edition "Standard" `
        -ServiceObjectiveName "S3" `
        -AdministratorLogin $MenuPlannerDevServerUserName `
        -AdministratorLoginPassword $MenuPlannerDevServerPassword

    # Prints the details of the export. Won't update the status text, but that's okay, we just want the info. Could select off it to reduce how much info?
    $importAuthRequest
    $importManagementRequest
    $importMenuPlannerRequest

    # Used to track progress
    $importAuthDone = 0
    $importManagementDone = 0
    $importMenuPlannerDone = 0

    #TODO: Could I make this a foreach loop to support a varying number of imports?
    # Display current status for all until they all pass.
    Do {
        if ($importAuthDone -eq 0) {
            # Auth
            $importAuthDone = GetImportExportStatus -request $importAuthRequest -activityMessage ("Importing " + $MenuPlannerDevAuthDatabaseName) -writeProgressId 1
        }
        if ($importManagementDone -eq 0) {
            # Management
            $importManagementDone = GetImportExportStatus -request $importManagementRequest -activityMessage ("Importing " + $MenuPlannerDevManagementDatabaseName) -writeProgressId 2
        }
        if ($importMenuPlannerDone -eq 0) {
            # Menu Planner
            $importMenuPlannerDone = GetImportExportStatus -request $importMenuPlannerRequest -activityMessage ("Importing " + $MenuPlannerDevMenuPlannerDatabaseName) -writeProgressId 3
        }

        Start-Sleep -s 1
    }
    While ($importAuthDone -eq 0 -or $importManagementDone -eq 0 -or $importMenuPlannerDone -eq 0)
    [Console]::WriteLine("*** Done Importing")

    # Would like to make this use Write-Progress but they don't have an easily accessible status to check, so waiting for them to finish on their own is fine for now.
    [Console]::WriteLine("*** Scaling Down " + $MenuPlannerDevAuthDatabaseName)
    # Scale down to Basic after import is complete
    Set-AzSqlDatabase -ResourceGroupName $MenuPlannerDevResourceGroupName `
        -ServerName $MenuPlannerDevServerName `
        -DatabaseName $MenuPlannerDevAuthDatabaseName  `
        -Edition "Basic" `
        -RequestedServiceObjectiveName "Basic"

    [Console]::WriteLine("*** Scaling Down " + $MenuPlannerDevManagementDatabaseName)
    Set-AzSqlDatabase -ResourceGroupName $MenuPlannerDevResourceGroupName `
        -ServerName $MenuPlannerDevServerName `
        -DatabaseName $MenuPlannerDevManagementDatabaseName  `
        -Edition "Basic" `
        -RequestedServiceObjectiveName "Basic"

    [Console]::WriteLine("*** Scaling Down " + $MenuPlannerDevMenuPlannerDatabaseName)
    # Scale down to S1 (20 DTUs) after import is complete
    Set-AzSqlDatabase -ResourceGroupName $MenuPlannerDevResourceGroupName `
        -ServerName $MenuPlannerDevServerName `
        -DatabaseName $MenuPlannerDevMenuPlannerDatabaseName  `
        -Edition "Standard" `
        -RequestedServiceObjectiveName "S1"
    [Console]::WriteLine("*** Done Scaling")

    [Console]::WriteLine("*** Starting Dev Web Apps")
    foreach($WebAppName in $AllDevWebAppNames) {
        [Console]::WriteLine("+++ Starting " + $WebAppName)
        Start-AzWebApp -ResourceGroupName $MenuPlannerDevResourceGroupName -Name $WebAppName
    }
    [Console]::WriteLine("*** Done Starting Dev Web Apps")
}
catch {
    [Console]::Error("!!! An error occured, killing the script !!!")
    Write-Host $_ # Writes the error to the console so we don't squash it
    exit
}