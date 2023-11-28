# Get all Azure subscriptions
$subscriptions = Get-AzSubscription

# Loop through each subscription
foreach ($subscription in $subscriptions) {
    Write-Host "Working in subscription: $($subscription.Name)" -ForegroundColor Green
    Select-AzSubscription -SubscriptionId $subscription.Id

    # Get all resource groups in the current subscription
    $resourceGroups = Get-AzResourceGroup

    # Loop through each resource group and remove tags
    foreach ($resourceGroup in $resourceGroups) {
        $resourceGroupId = $resourceGroup.ResourceId

        if ($resourceGroup.Tags.Count -gt 0) {
            Write-Host "Removing tags from resource group: $resourceGroupId" -ForegroundColor Yellow
            $resourceGroup.Tags.Clear()
            $resourceGroup | Set-AzResourceGroup
        } else {
            Write-Host "No tags to remove from resource group: $resourceGroupId" -ForegroundColor Green
        }
    }

    # Get all resources in the current subscription
    $resources = Get-AzResource

    # Loop through each resource and remove tags
    foreach ($resource in $resources) {
        $resourceId = $resource.ResourceId

        if ($resource.Tags.Count -gt 0) {
            Write-Host "Removing tags from resource: $resourceId" -ForegroundColor Yellow
            Set-AzResource -ResourceId $resourceId -Tag @{} -Confirm:$false -Force
        } else {
            Write-Host "No tags to remove from resource: $resourceId" -ForegroundColor Green
        }
    }
}

Write-Host "All tags removed from all Azure resources and resource groups in all subscriptions." -ForegroundColor Green
