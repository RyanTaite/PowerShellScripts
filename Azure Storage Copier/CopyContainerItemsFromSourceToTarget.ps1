# Menu Planner Example, "$AzureCreds ..." and ".\CopyContainerItemsFromSourceToTarget.ps1 ..." are two separate commands:
# $AzureCreds = Get-Credential
# .\CopyContainerItemsFromSourceToTarget.ps1 `
# 	-AzureCredential $AzureCreds `
# 	-SourceSubscriptionName "Menu Planner Production" `
# 	-SourceResourceGroupName "MenuPlanner-Prod" `
# 	-SourceStorageAccountName "menuplannerblobprod" `
# 	-SourceStorageContainerName "specsheets" `
# 	-TargetSubscriptionName "Menu Planner Dev Test UAT" `
# 	-TargetResourceGroupName "MenuPlanner-Shared" `
# 	-TargetStorageAccountName "menuplannerblobshared" `
# 	-TargetStorageContainerName "specsheets"

# Meal Counter Example, "$AzureCreds ..." and ".\CopyContainerItemsFromSourceToTarget.ps1 ..." are two separate commands:
# .\CopyContainerItemsFromSourceToTarget.ps1 `
#  -AzureCredential $AzureCreds `
#  -SourceSubscriptionName "MealCounterProd" `
#  -SourceResourceGroupName "mc-prod-rg" `
#  -SourceStorageAccountName "mcprodstorageaccount" `
#  -SourceStorageContainerName "reports" `
#  -TargetSubscriptionName "MealCounterDevTestUAT" `
#  -TargetResourceGroupName "mc-shared" `
#  -TargetStorageAccountName "countersharedstorage" `
#  -TargetStorageContainerName "reports"

[CmdletBinding()]
param (
    [parameter(Mandatory=$true, HelpMessage="The secured Username and Password for Azure. Get this with Get-Credential")]
    [pscredential]
    $AzureCredential,

    #region Source
    [parameter(Mandatory=$true, HelpMessage="The source subscription name that contains the resource group with the Azure Storage Container you want to export. Ex: Menu Planner Production")]
    [ArgumentCompleter({ param( $commandName, $parameterName, $wordsToComplete, $commandAst)
        $possibleValues = (
            '"Menu Planner Dev Test UAT"',
            '"Menu Planner Production"',
            '"MealCounterDevTestUAT"',
            '"MealCounterProd"')
        $possibleValues | Where-Object { $_ -like "$wordToComplete*" }
    })]
    [string]
    $SourceSubscriptionName,

    [parameter(Mandatory=$true, HelpMessage="The source resource group name that contains the server and database(s) you want to export. Ex: MenuPlanner-Prod")]
    [ArgumentCompleter({ param( $commandName, $parameterName, $wordsToComplete, $commandAst)
        $possibleValues = (
            '"MenuPlanner-Dev"',
            '"MenuPlanner-Test"',
            '"MenuPlanner-UAT"',
            '"MenuPlanner-Prod"',
            '"MenuPlanner-Shared"',
            '"mc-dev-rg"',
            '"mc-test-rg"',
            '"mc-uat-rg"',
            '"mc-prod-rg"',
            '"mc-shared"')
        $possibleValues | Where-Object { $_ -like "$wordToComplete*" }
    })]
    [string]
    $SourceResourceGroupName,

    [parameter(Mandatory=$true, HelpMessage="The source storage account name that has the container we want to export. Ex: menuplannerblobprod")]
    [ArgumentCompleter({ param( $commandName, $parameterName, $wordsToComplete, $commandAst)
        $possibleValues = (
            '"menuplannerblobprod"',
            '"menuplannerblobshared"',
            '"mcprodstorageaccount"',
            '"mcdbexportstorage"',
            '"countersharedstorage"')
        $possibleValues | Where-Object { $_ -like "$wordToComplete*" }
    })]
    [string]
    $SourceStorageAccountName,

    [parameter(Mandatory=$true, HelpMessage="The source storage container name that has the items we want to export. Ex: specsheets")]
    [ArgumentCompleter({ param( $commandName, $parameterName, $wordsToComplete, $commandAst)
        $possibleValues = (
            '"dataimport"',
            '"specsheets"',
            '"tmp"',
            '"attachments"',
            '"reports"',
            '"db-exports"',
            "'exports'")
        $possibleValues | Where-Object { $_ -like "$wordToComplete*" }
    })]
    [string]
    $SourceStorageContainerName,
    #endregion Source

    #region Target
    [parameter(Mandatory=$true, HelpMessage="The target subscription name that contains the resource group with the Azure Storage Container you want to export. Ex: Menu Planner Production")]
    [ArgumentCompleter({ param( $commandName, $parameterName, $wordsToComplete, $commandAst)
        $possibleValues = (
            '"Menu Planner Dev Test UAT"',
            '"Menu Planner Production"',
            '"MealCounterDevTestUAT"',
            '"MealCounterProd"')
        $possibleValues | Where-Object { $_ -like "$wordToComplete*" }
    })]
    [string]
    $TargetSubscriptionName,

    [parameter(Mandatory=$true, HelpMessage="The target resource group name that contains the server and database(s) you want to export. Ex: MenuPlanner-Prod")]
    [ArgumentCompleter({ param( $commandName, $parameterName, $wordsToComplete, $commandAst)
        $possibleValues = (
            '"MenuPlanner-Dev"',
            '"MenuPlanner-Test"',
            '"MenuPlanner-UAT"',
            '"MenuPlanner-Prod"',
            '"MenuPlanner-Shared"',
            '"mc-dev-rg"',
            '"mc-test-rg"',
            '"mc-uat-rg"',
            '"mc-prod-rg"',
            '"mc-shared"')
        $possibleValues | Where-Object { $_ -like "$wordToComplete*" }
    })]
    [string]
    $TargetResourceGroupName,

    [parameter(Mandatory=$true, HelpMessage="The target storage account name that has the container we want to export. Ex: menuplannerblobprod")]
    [ArgumentCompleter({ param( $commandName, $parameterName, $wordsToComplete, $commandAst)
        $possibleValues = (
            '"menuplannerblobprod"',
            '"menuplannerblobshared"',
            '"mcprodstorageaccount"',
            '"mcdbexportstorage"',
            '"countersharedstorage"')
        $possibleValues | Where-Object { $_ -like "$wordToComplete*" }
    })]
    [string]
    $TargetStorageAccountName,

    [parameter(Mandatory=$true, HelpMessage="The target storage container name that has the items we want to export. Ex: specsheets")]
    [ArgumentCompleter({ param( $commandName, $parameterName, $wordsToComplete, $commandAst)
        $possibleValues = (
            '"dataimport"',
            '"specsheets"',
            '"tmp"',
            '"attachments"',
            '"reports"',
            '"db-exports"',
            "'exports'")
        $possibleValues | Where-Object { $_ -like "$wordToComplete*" }
    })]
    [string]
    $TargetStorageContainerName
    #endregion Target
)

# Required functions for this script
Import-Module .\GetStorageAccessToken.psm1

try {
    $SourceStorageAccountPermissions = "rl" # Limited since it should be read only
    $TargetStorageAccountPermissions = "rwdl" # Everything, able to overwrite same name files if needed

    $SourceSASToken = GetStorageAccessToken `
        -credential $AzureCredential `
        -subscriptionName $SourceSubscriptionName `
        -resourceGroupName $SourceResourceGroupName `
        -storageAccountName $SourceStorageAccountName `
        -storageContainerName $SourceStorageContainerName `
        -permissions $SourceStorageAccountPermissions

    $TargetSASToken = GetStorageAccessToken `
        -credential $AzureCredential `
        -subscriptionName $TargetSubscriptionName `
        -resourceGroupName $TargetResourceGroupName `
        -storageAccountName $TargetStorageAccountName `
        -storageContainerName $TargetStorageContainerName `
        -permissions $TargetStorageAccountPermissions

    [Console]::WriteLine("*** Starting Az Copy")
    .\azcopy.exe copy ${SourceSASToken} ${TargetSASToken} --recursive
}
catch {
    [Console]::WriteLine("!!! An error occurred, killing the script !!!")
    Write-Host $_ # Writes the error to the console so we don't squash it
    exit
}