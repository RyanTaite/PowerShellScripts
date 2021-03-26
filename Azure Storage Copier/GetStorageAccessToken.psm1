function GetStorageAccessToken([pscredential]$credential, [string]$subscriptionName, [string]$resourceGroupName, [string]$storageAccountName, [string]$storageContainerName, [string]$permissions) {
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