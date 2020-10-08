# Get a Shard Access Signature from Azure Storage Emulator
# Use the URL version, replace the existing values
# First one is source
# Second is target
# I chose all permissions, it will overwrite files if it has to

function GetSASToken([pscredential]$credential, [string]$subscriptionName, [string]$resourceGroupName, [string]$storageAccountName, [string]$storageContainerName, [string]$permissions) {
    [Console]::WriteLine("*** Getting SAS Token for ${subscriptionName} / ${resourceGroupName} / ${storageContainerName}")
    # If we don't set this value to something it gets sent as part of the return. A "feature" or PowerShell apparently.
    $_ = Connect-AzAccount -Credential $credential -Subscription $subscriptionName

    $StorageAccountKey = $(Get-AzStorageAccountKey `
        -ResourceGroupName $resourceGroupName `
        -StorageAccountName $storageAccountName).Value[0]

    $StorageAccountContextShared = New-AzStorageContext `
        -StorageAccountName $storageAccountName `
        -StorageAccountKey $StorageAccountKey

    $StorageContainerSASToken = New-AzStorageContainerSASToken `
        -Context $StorageAccountContextShared `
        -Name $storageContainerName `
        -Permission $permissions `
        -FullUri

    [Console]::WriteLine("*** Done Getting SAS Token for ${subscriptionName} / ${resourceGroupName} / ${storageContainerName}")
    $StorageContainerSASToken
}

$Credential = Get-Credential -Message "Azure Portal Login"

# Both
$StorageAccountContainerName = "specsheets"

# Shared
$SubscriptionNameShared = "Menu Planner Dev Test UAT"
$ResourceGroupNameShared = "MenuPlanner-Shared"
$StorageAccountNameShared = "menuplannerblobshared"
$StorageAccountPermissionsShared = "rwdl"

# Prod
$SubscriptionNameProd = "Menu Planner Production"
$ResourceGroupNameProd = "MenuPlanner-Prod"
$StorageAccountNameProd = "menuplannerblobprod"
$StorageAccountPermissionsProd = "rl"

$StorageContainerSASTokenShared = GetSASToken `
    -credential $Credential `
    -subscriptionName $SubscriptionNameShared `
    -resourceGroupName $ResourceGroupNameShared `
    -storageAccountName $StorageAccountNameShared `
    -storageContainerName $StorageAccountContainerName `
    -permissions $StorageAccountPermissionsShared

$StorageContainerSASTokenProd = GetSASToken `
    -credential $Credential `
    -subscriptionName $SubscriptionNameProd `
    -resourceGroupName $ResourceGroupNameProd `
    -storageAccountName $StorageAccountNameProd `
    -storageContainerName $StorageAccountContainerName `
    -permissions $StorageAccountPermissionsProd



[Console]::WriteLine("*** Starting Az Copy")
.\azcopy.exe copy ${StorageContainerSASTokenProd} ${StorageContainerSASTokenShared} --recursive