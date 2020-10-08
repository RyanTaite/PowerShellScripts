function SetSubscription([pscredential]$Credential, [String]$SubscriptionName) {
    try {
        [Console]::WriteLine("*** Setting Subscription to ${SubscriptionName}")
        Set-AzContext -SubscriptionName $SubscriptionName
        $Subscriptions = Get-AzSubscription
        [Console]::WriteLine("*** Getting Tenant Id")
        $TenantId = $Subscriptions.Where({$_.Name -eq $SubscriptionName}).TenantId
        [Console]::WriteLine("*** Getting Subscription Id")
        $SubscriptionId = $Subscriptions.Where({$_.Name -eq $SubscriptionName}).Id
        $_ = Connect-AzAccount -Credential $Credential -Tenant $TenantId -SubscriptionId $SubscriptionId
        [Console]::WriteLine("*** Done Setting Subscription to ${SubscriptionName}")
    }
    catch {
        [Console]::WriteLine("!!! An error occured when setting the subscription! !!!")
        [Console]::WriteLine("If you are pretty sure your values are correct, you may need to reconnect to Azure. Run the command Connect-AzAccount then try again.")
        throw
    }
}