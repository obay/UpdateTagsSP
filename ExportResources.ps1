<#
.SYNOPSIS
Export all resources and resource groups in Azure to a CSV file.

.DESCRIPTION
This script exports all resources and resource groups in Azure to a CSV file.

.PARAMETER CSVFilePath
The path of the CSV file.

.EXAMPLE
./ExportResources.ps1 csvFilePath /Users/user/Downloads/AzureResources.csv

.NOTES
File Name      : ExportResources.ps1
Author         : Ahmad Obay
Prerequisite   : PowerShell 7 or later
Copyright 2023 : Microsoft
#>


# Create a PowerShell script that exports all resources in Azure to a CSV file.
# The CSV file should contain the following columns: SUBSCRIPTION_NAME,SUBSCRIPTION_ID,RESOURCE_GROUP_NAME,RESOURCE_NAME,RESOURCE_TYPE
# The CSV file should contain the following tag columns: APPID, Application Name, Environment Type, Business Criticality, Data Classification, Primary Business Capability, Regulatory Controlled Information, Support Group, TIS Application Owner, TIS Portfolio Executive

# Set the output CSV file path
param (
    [string]$csvFilePath = "AzureResources.csv"
)

# Initialize an empty array to store resource information
$resourceInfo = @()

# Get all Azure subscriptions
$subscriptions = Get-AzSubscription

# Loop through each subscription
foreach ($subscription in $subscriptions) {
    $subscriptionName = $subscription.Name
    $subscriptionId = $subscription.Id

    # Set the current subscription context
    Set-AzContext -Subscription $subscriptionId

    # Get all resource groups in the current subscription
    $resourceGroups = Get-AzResourceGroup

    # Loop through each resource group
    foreach ($resourceGroup in $resourceGroups) {
        $resourceGroupName = $resourceGroup.ResourceGroupName

        # Add the resource group itself as a resource to the array
        $resourceInfo += [PSCustomObject]@{
            SUBSCRIPTION_NAME   = $subscriptionName
            SUBSCRIPTION_ID     = $subscriptionId
            RESOURCE_GROUP_NAME = $resourceGroupName
            RESOURCE_NAME       = $resourceGroupName  # Resource name is set to the resource group name
            RESOURCE_TYPE       = "ResourceGroup"     # Specify that it's a resource group
        }

        # Get all resources in the current resource group
        $resources = Get-AzResource -ResourceGroupName $resourceGroupName

        # Loop through each resource
        foreach ($resource in $resources) {
            $resourceName = $resource.Name
            $resourceType = $resource.ResourceType

            # Add the resource information to the array
            $resourceInfo += [PSCustomObject]@{
                SUBSCRIPTION_NAME   = $subscriptionName
                SUBSCRIPTION_ID     = $subscriptionId
                RESOURCE_GROUP_NAME = $resourceGroupName
                RESOURCE_NAME       = $resourceName
                RESOURCE_TYPE       = $resourceType
            }
        }
    }
}

# Export the resource information to a CSV file
$resourceInfo | Export-Csv -Path $csvFilePath -NoTypeInformation -Force

Write-Host "Azure resources exported to $csvFilePath"
