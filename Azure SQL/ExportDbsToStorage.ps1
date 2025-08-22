# Example, "$AzureCreds ..." and ".\ExportDbsToStorage.ps1 ..." are two seperate commands:
# $AzureCreds = Get-Credential
# .\ExportDbsToStorage.ps1 `
# 	-AzureCredential $AzureCreds `
# 	-SourceSubscriptionName "Your Subscription" `
# 	-SourceResourceGroupName "Resource-Group-Name" `
# 	-SourceServerName "YOUR-SOURCE-SERVER" `
# 	-SourceDbNames ("menuplanner-db", "auth-db", "management-db") `
# 	-SourceServerUserName "menuplanner-prod" `
# 	-SourceKeyVaultName "menuplannerkv" `
# 	-TargetSubscriptionName "Menu Planner Dev Test UAT" `
# 	-TargetResourceGroupName "MenuPlanner-Shared" `
# 	-TargetStorageAccountName "menuplannerblobshared" `
# 	-TargetStorageContainerName "dataimport"

# Meal Counter Example, "$AzureCreds ..." and ".\ExportDbsToStorage.ps1 ..." are two seperate commands:
# $AzureCreds = Get-Credential
# .\ExportDbsToStorage.ps1 `
# 	-AzureCredential $AzureCreds `
# 	-SourceSubscriptionName "MealCounterProd" `
# 	-SourceResourceGroupName "mc-prod-rg" `
# 	-SourceServerName "mealcounter-db-prod" `
# 	-SourceDbNames ("MealCounter-Prod") `
# 	-SourceServerUserName "Developer" `
# 	-SourceKeyVaultName "mealcounter-kv-prod" ` 
# 	-TargetSubscriptionName "MealCounterDevTestUAT" `
# 	-TargetResourceGroupName "mc-shared" `
# 	-TargetStorageAccountName "mcdbexportstorage" `
# 	-TargetStorageContainerName "db-exports"

#Requires -Modules Az.Accounts
#Requires -Modules Az.Storage
#Requires -Modules Az.KeyVault
#Requires -Modules Az.Sql
#Requires -Modules Microsoft.PowerShell.Utility

# Export re-write using params to handle both Menu Planner and Meal Counter (or any other project in Azure with a similar setup)
param(
    # General
    [parameter(Mandatory=$true, HelpMessage="The secured Username and Password for Azure. Get this with Get-Credential")]
    [pscredential] $AzureCredential,

    # Source
    [parameter(Mandatory=$true, HelpMessage="The source subscription name that contains the resource group with the server and database(s) you want to export. Ex: Menu Planner Production")]
    [ArgumentCompleter({ param( $commandName, $parameterName, $wordsToComplete, $commndAst)
        $possibleValues = ('"Menu Planner Dev Test UAT"', '"Menu Planner Production"',
        '"MealCounterDevTestUAT"', '"MealCounterProd"')
        $possibleValues | Where-Object { $_ -like "$wordToComplete*" }
    })]
    [string] $SourceSubscriptionName,

    [parameter(Mandatory=$true, HelpMessage="The source resource group name that contains the server and database(s) you want to export. Ex: MenuPlanner-Prod")]
    [ArgumentCompleter({ param( $commandName, $parameterName, $wordsToComplete, $commndAst)
        $possibleValues = ('"MenuPlanner-Dev"', '"MenuPlanner-Test"','"MenuPlanner-UAT"', '"MenuPlanner-Prod"', '"MenuPlanner-Shared"',
        '"mc-dev-rg"', '"mc-test-rg"', '"mc-uat-rg"', '"mc-prod-rg"', '"mc-shared"')
        $possibleValues | Where-Object { $_ -like "$wordToComplete*" }
    })]
    [string] $SourceResourceGroupName,

    [parameter(Mandatory=$true, HelpMessage="The source server name that contains the databases we want to export. Ex: menuplanner-dbserver")]
    [ArgumentCompleter({ param( $commandName, $parameterName, $wordsToComplete, $commndAst)
        $possibleValues = ('"menuplanner-dbserver-dev"', '"menuplanner-dbserver-test"', '"menuplanner-dbserver-uat"', '"menuplanner-dbserver"',
        '"mealcounter-db-dev"', '"mealcounter-db-test"', '"mealcounter-db-uat"', '"mealcounter-db-prod"')
        $possibleValues | Where-Object { $_ -like "$wordToComplete*" }
    })]
    [string] $SourceServerName,

    [parameter(Mandatory=$true, HelpMessage="The source database name(s) to export. Ex: menuplanner-db, auth-db, etc.")]
    [ArgumentCompleter({ param( $commandName, $parameterName, $wordsToComplete, $commndAst)
        $possibleValues = ('("menuplanner-db-dev", "auth-db-dev", "management-db-dev")', '("menuplanner-db-test", "auth-db-test", "management-db-test")', '("menuplanner-db-uat", "auth-db-uat", "management-db-uat")', '("menuplanner-db", "auth-db", "management-db")',
        '("MealCounter-Dev")', '("MealCounter-Test")', '("MealCounter-UAT")', '("MealCounter-Prod")')
        $possibleValues | Where-Object { $_ -like "$wordToComplete*" }
    })]
    [string[]] $SourceDbNames,

    [parameter(Mandatory=$true, HelpMessage="The source server username to login in with. Ex: menuplanner-prod")]
    [ArgumentCompleter({ param( $commandName, $parameterName, $wordsToComplete, $commndAst)
        $possibleValues = ('"I am not telling you that, dude"')
        $possibleValues | Where-Object { $_ -like "$wordToComplete*" }
    })]
    [string] $SourceServerUserName,

    [parameter(Mandatory=$true, HelpMessage="The source key vault that has the SqlServerPassword secret. This will be used to sign into the Source Server. Ex: menuplannerkv")]
    [ArgumentCompleter({ param( $commandName, $parameterName, $wordsToComplete, $commndAst)
        $possibleValues = ('"menuplannerkvdev"', '"menuplannerkvtest"','"menuplannerkvuat"', '"menuplannerkv"',
        '"mealcounter-kv-dev"', '"mealcounter-kv-test"', '"mealcounter-kv-uat"', '"mealcounter-kv-prod"')
        $possibleValues | Where-Object { $_ -like "$wordToComplete*" }
    })]
    [string] $SourceKeyVaultName,

    # Target
    [parameter(Mandatory=$true, HelpMessage="The target subscription name that contains the resource group with the storage account you want to export to. Ex: Menu Planner Dev Test UAT")]
    [ArgumentCompleter({ param( $commandName, $parameterName, $wordsToComplete, $commndAst)
        $possibleValues = ('"Menu Planner Dev Test UAT"', '"Menu Planner Production"',
        '"MealCounterDevTestUAT"', '"MealCounterProd"')
        $possibleValues | Where-Object { $_ -like "$wordToComplete*" }
    })]
    [string] $TargetSubscriptionName,

    [parameter(Mandatory=$true, HelpMessage="The target resource group name that contains the storage account you want to export to. Ex: MenuPlanner-Shared")]
    [ArgumentCompleter({ param( $commandName, $parameterName, $wordsToComplete, $commndAst)
        $possibleValues = ('"MenuPlanner-Dev"', '"MenuPlanner-Test"','"MenuPlanner-UAT"', '"MenuPlanner-Shared"',
        '"mc-dev-rg"', '"mc-test-rg"', '"mc-uat-rg"', '"mc-shared"')
        $possibleValues | Where-Object { $_ -like "$wordToComplete*" }
    })]
    [string] $TargetResourceGroupName,

    [parameter(Mandatory=$true, HelpMessage="The target storage account name you want to export to. Ex: menuplannerblobshared")]
    [ArgumentCompleter({ param( $commandName, $parameterName, $wordsToComplete, $commndAst)
        $possibleValues = ('"menuplannerblobshared"', '"mcdbexportstorage"')
        $possibleValues | Where-Object { $_ -like "$wordToComplete*" }
    })]
    [string] $TargetStorageAccountName,

    [parameter(Mandatory=$true, HelpMessage="The target storage container name you want to export to. Ex: dataimport")]
    [ArgumentCompleter({ param( $commandName, $parameterName, $wordsToComplete, $commndAst)
        $possibleValues = ('"dataimport"', '"db-exports"')
        $possibleValues | Where-Object { $_ -like "$wordToComplete*" }
    })]
    [string] $TargetStorageContainerName
)

# Required functions for this script
Import-Module .\GenerateBacpacUri.psm1
Import-Module .\SetSubscription.psm1
Import-Module .\GetImportExportStatus.psm1

try {
    # Connect to the Target Subscription to get it's Storage Key below
    SetSubscription -Credential $AzureCredential -SubscriptionName $TargetSubscriptionName

    # Get the Storage Key for the target container
    $StorageKeytype = "StorageAccessKey" # Portal -> Resource Group -> Storage -> Access keys -> key1/2 -> key. Used in the export
    [Console]::WriteLine("*** Getting Storage Key for ${TargetResourceGroupName} ${TargetStorageAccountName}")
    $StorageKey = $(Get-AzStorageAccountKey -ResourceGroupName $TargetResourceGroupName -StorageAccountName $TargetStorageAccountName).Value[0]
    [Console]::WriteLine("*** Done Getting Storage Key for ${TargetResourceGroupName} ${TargetStorageAccountName}")

    # Now that we have the storage key we can work on exporting from Source
    SetSubscription -Credential $AzureCredential -SubscriptionName $SourceSubscriptionName

    # Get the Server password from the source keyvault, SqlServerPassword secret (someone has to add this manually to the keyvault!)
    [string] $SourceKeyVaultSecretName = "SqlServerPassword"
    [Console]::WriteLine("*** Getting Source Server Password From Key Vault ${SourceKeyVaultName} secret ${SourceKeyVaultSecretName}")
    $SourceServerPassword = (Get-AzKeyVaultSecret -VaultName $SourceKeyVaultName -Name $SourceKeyVaultSecretName).SecretValue
    [Console]::WriteLine("*** Done Getting Source Server Password From Key Vault ${SourceKeyVaultName} secret ${SourceKeyVaultSecretName}")

    # Create a Hashtable for the db names and their respective bacpac uris
    $DbNamesAndBacpacsUris = @{}
    $SourceDbNames | ForEach-Object -Process {
        $Value = GenerateBacpacUri `
            -DatabaseName $_ `
            -StorageAccountName $TargetStorageAccountName `
            -StorageContainerName $TargetStorageContainerName
        $DbNamesAndBacpacsUris.Add($_, $Value)
    }

    [Console]::WriteLine("*** Exporting")
    # Create an export request for each database
    $DbNamesAndExportRequests = @{}
    foreach ($db in $DbNamesAndBacpacsUris.GetEnumerator()) {
        $exportRequest = New-AzSqlDatabaseExport `
            -ResourceGroupName $SourceResourceGroupName `
            -ServerName $SourceServerName `
            -DatabaseName $db.Name `
            -StorageKeytype $StorageKeytype `
            -StorageKey $StorageKey `
            -StorageUri $db.Value `
            -AdministratorLogin $SourceServerUserName `
            -AdministratorLoginPassword $SourceServerPassword

        $DbNamesAndExportRequests.Add($db.Name, $exportRequest)

        # Prints the details of the export. Won't update the status text, but that's okay.
        $exportRequest
    }

    # Create a hashtable of the export statuses. All start at 0.
    $DbNamesAndExportStatus = @{}
    $SourceDbNames | ForEach-Object -Process {
        $Value = 0
        $DbNamesAndExportStatus.Add($_, $Value)
    }

    Do {
        $writeProgressId = 0 # Reset to zero on each loop

        foreach ($dbName in $SourceDbNames) {
            $writeProgressId += 1 # Increase by one for each db name so they stay on the same line
            if ($DbNamesAndExportStatus[$dbName] -eq 0) {
                $DbNamesAndExportStatus[$dbName] = GetImportExportStatus `
                    -request $DbNamesAndExportRequests[$dbName] `
                    -activityMessage "Exporting ${dbName}" `
                    -writeProgressId $writeProgressId
            }
        }

        # Refresh every second
        Start-Sleep -s 1
    }
    While ($DbNamesAndExportStatus.ContainsValue(0)) # Do while any of the export statuses are still 0

    [Console]::WriteLine("*** Done Exporting")
}
catch {
    [Console]::WriteLine("!!! An error occured, killing the script !!!")
    Write-Host $_ # Writes the error to the console so we don't squash it
    exit
}