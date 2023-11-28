<#
.SYNOPSIS
Update tags of all resources in Azure based on the CSV file.

.DESCRIPTION
This script updates the tags of all resources in Azure based on the CSV file.

.PARAMETER TenantId
The Tenant ID for the Azure account.

.PARAMETER AppId
The Application ID for the Azure service principal.

.PARAMETER Password
The password for the Azure service principal.

.PARAMETER CSVFilePath
The path of the CSV file containing the resource tags to update.

.EXAMPLE
./UpdateTags.ps1 -TenantId "xxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" -AppId "yyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy" -Password "p@$$w0rd" -CSVFilePath "./tags.csv"

.NOTES
File Name      : UpdateTags.ps1
Author         : Ahmad Obay (ahmadobay@microsoft.com)
Prerequisite   : PowerShell 7.3.6 or later
Copyright 2023 : Microsoft
#>

param(
    [Parameter(Mandatory)]
    [string]$TenantId,

    [Parameter(Mandatory)]
    [string]$AppId,

    [Parameter(Mandatory)]
    [string]$Password,

    [Parameter(Mandatory)]
    [string]$CSVFilePath
)


# Create a function that takes $CSV_ROW and returns hashtable of the tag name and tag values
# Tag columns in the row are: APPID, Application Name, Environment Type, Business Criticality, Data Classification, Primary Business Capability, Regulatory Controlled Information, Support Group, TIS Application Owner, TIS Portfolio Executive
function Get-Tag {
    param(
        [object]$CSV_ROW
    )

    $ROW_RESOURCE_TAGS = @{}
    $ROW_RESOURCE_TAGS.Add("APPID", $CSV_ROW."APPID")
    $ROW_RESOURCE_TAGS.Add("Application Name", $CSV_ROW."Application Name")
    $ROW_RESOURCE_TAGS.Add("Environment Type", $CSV_ROW."Environment Type")
    $ROW_RESOURCE_TAGS.Add("Business Criticality", $CSV_ROW."Business Criticality")
    $ROW_RESOURCE_TAGS.Add("Data Classification", $CSV_ROW."Data Classification")
    $ROW_RESOURCE_TAGS.Add("Primary Business Capability", $CSV_ROW."Primary Business Capability")
    $ROW_RESOURCE_TAGS.Add("Regulatory Controlled Information", $CSV_ROW."Regulatory Controlled Information")
    $ROW_RESOURCE_TAGS.Add("Support Group", $CSV_ROW."Support Group")
    $ROW_RESOURCE_TAGS.Add("TIS Application Owner", $CSV_ROW."TIS Application Owner")
    $ROW_RESOURCE_TAGS.Add("TIS Portfolio Executive", $CSV_ROW."TIS Portfolio Executive")
    return $ROW_RESOURCE_TAGS
}

# $tenantId = (Get-AzContext).Tenant.Id
$securePassword = ConvertTo-SecureString $password -AsPlainText -Force
$cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $AppId, $securePassword

Connect-AzAccount -ServicePrincipal -Credential $cred -Tenant $TenantId

$securePassword = ConvertTo-SecureString $password -AsPlainText -Force
$cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $AppId, $securePassword


# Import CSV file
$CSVFileContent = Get-Content $CSVFilePath | ConvertFrom-Csv

# Create a hashtable to store unique resources
$UniqueResources = @{}

# Get all resources in Azure from all subscriptions
$subscriptions = Get-AzSubscription

# Iterate through each subscription
write-host "Getting resources from all subscriptions..." -ForegroundColor Yellow
foreach ($subscription in $subscriptions) {
    Set-AzContext -Subscription $subscription.Id

    # List all resource groups in the current subscription
    $resourceGroups = Get-AzResourceGroup

    # Add resource groups to $UniqueResources hashtable
    foreach ($resourceGroup in $resourceGroups) {
        $UniqueResources[$resourceGroup.ResourceId] = $resourceGroup
    }

    # List all resources in the current subscription
    $resources = Get-AzResource

    # Add resources to $UniqueResources hashtable
    foreach ($resource in $resources) {
        $UniqueResources[$resource.ResourceId] = $resource
    }
}
write-host "Getting resources from all subscriptions... Done" -ForegroundColor Green
write-host
write-host

# Convert the hashtable values back to an array
$AZURE_RESOURCES = $UniqueResources.Values

# Initialize arrays to capture exit statuses for successful and failed updates
$SuccessfulUpdates = @()
$FailedUpdates = @()

Write-Host "Updating tags..." -ForegroundColor Yellow
# Iterate through each row in the CSV file
foreach ($CSV_ROW in $CSVFileContent) {
    # Build the resource ID
    # if $CSV_ROW.RESOURCE_TYPE is resourceGroup, format will be /subscriptions/e894a046-1234-4aa8-8ce1-bcbe235dc486/resourceGroups/othersub-rg
    if ($CSV_ROW.RESOURCE_TYPE -eq "resourceGroup") {
        $ROW_RESOURCE_ID = "/subscriptions/" + $CSV_ROW.SUBSCRIPTION_ID + "/resourceGroups/" + $CSV_ROW.RESOURCE_NAME
    }
    else {
        # /subscriptions/98b6c4c8-1234-41e0-1234-e34e041bdf44/resourceGroups/xImage-rg/providers/Microsoft.Network/networkSecurityGroups/GoldenVM-nsg
        $ROW_RESOURCE_ID = "/subscriptions/" + $CSV_ROW.SUBSCRIPTION_ID + "/resourceGroups/" + $CSV_ROW.RESOURCE_GROUP_NAME + "/providers/" + $CSV_ROW.RESOURCE_TYPE + "/" + $CSV_ROW.RESOURCE_NAME
    }

    foreach ($AZURE_RESOURCE in $AZURE_RESOURCES) {
        # compare resource ID in the CSV file with the resource ID in Azure
        if ($ROW_RESOURCE_ID -eq $AZURE_RESOURCE.ResourceId) {
            $AZURE_RESOURCE_TAGS = $AZURE_RESOURCE.Tags
            # if $AZURE_RESOURCE_TAGS is null, create it
            if ($null -eq $AZURE_RESOURCE_TAGS) {
                $AZURE_RESOURCE_TAGS = @{}
            }
            # Call Get-Tag function to get the tags of the resource in the CSV file and store them in $ROW_RESOURCE_TAGS
            $ROW_RESOURCE_TAGS = Get-Tag -CSV_ROW $CSV_ROW

            $TagsUpdateRequired = $false

            # Iterate through the $ROW_RESOURCE_TAGS hashtable and compare it with the $AZURE_RESOURCE_TAGS hashtable. if the tag doesn't exist in the $AZURE_RESOURCE_TAGS hashtable, add it. if the tag exists in the $AZURE_RESOURCE_TAGS hashtable, update it if the value is different.
            foreach ($ROW_RESOURCE_TAG in $ROW_RESOURCE_TAGS.GetEnumerator()) {
                $ROW_RESOURCE_TAG_NAME = $ROW_RESOURCE_TAG.Name
                $ROW_RESOURCE_TAG_VALUE = $ROW_RESOURCE_TAG.Value

                if ($AZURE_RESOURCE_TAGS.ContainsKey($ROW_RESOURCE_TAG_NAME)) {
                    # Delete the tag if the value is empty
                    if ([string]::IsNullOrEmpty($ROW_RESOURCE_TAG_VALUE)) {
                        write-host "Resource "$ROW_RESOURCE_ID": Deleting tag ""$ROW_RESOURCE_TAG_NAME"""
                        $AZURE_RESOURCE_TAGS.Remove($ROW_RESOURCE_TAG_NAME)
                        $TagsUpdateRequired = $true
                    }
                    # Update the tag if the value is different
                    elseif ($AZURE_RESOURCE_TAGS[$ROW_RESOURCE_TAG_NAME] -ne $ROW_RESOURCE_TAG_VALUE) {
                        
                        write-host "Resource "$ROW_RESOURCE_ID": Updating tag ""$ROW_RESOURCE_TAG_NAME"" with value ""$ROW_RESOURCE_TAG_VALUE"""
                        $AZURE_RESOURCE_TAGS[$ROW_RESOURCE_TAG_NAME] = $ROW_RESOURCE_TAG_VALUE
                        $TagsUpdateRequired = $true
                    }
                }
                # Add the tag if it doesn't exist and the value is not empty
                elseif (![string]::IsNullOrEmpty($ROW_RESOURCE_TAG_VALUE)) {
                    write-host "Resource "$ROW_RESOURCE_ID": Adding tag ""$ROW_RESOURCE_TAG_NAME"" with value ""$ROW_RESOURCE_TAG_VALUE"""
                    $AZURE_RESOURCE_TAGS.Add($ROW_RESOURCE_TAG_NAME, $ROW_RESOURCE_TAG_VALUE)
                    $TagsUpdateRequired = $true
                }                
            }

            # Update the tags of the resource in Azure if there is a change
            # Azure Domain Name System (DNS) zones don't support the use of spaces in the tag or a tag that starts with a number. Azure DNS tag names don't support special and unicode characters. The value can contain all characters.
            # See https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/tag-resources
            if ($TagsUpdateRequired) {
                write-host "Resource "$ROW_RESOURCE_ID": Updating tags" -ForegroundColor Yellow
                try {
                    $exitStatus = Set-AzResource -ResourceId $AZURE_RESOURCE.ResourceId -Tag $AZURE_RESOURCE_TAGS -Force
                }
                catch {
                    # Do nothing
                }                
                if ($exitStatus) {
                    $SuccessfulUpdates += @{
                        ResourceId = $AZURE_RESOURCE.ResourceId
                        ExitStatus = $exitStatus
                    }
                }
                else {
                    $FailedUpdates += @{
                        ResourceId = $AZURE_RESOURCE.ResourceId
                        ExitStatus = $exitStatus
                    }
                }
            }
            else {
                write-host "Resource "$ROW_RESOURCE_ID": No tags update required" -ForegroundColor Green
            }
        }
    }
}
Write-Host "Updating tags... Done" -ForegroundColor Green

Write-Host
Write-Host
Write-Host "Summary:" -ForegroundColor Cyan

# Print failed updates
if ($FailedUpdates.Count -gt 0) {
    Write-Host "Failed Updates ("$FailedUpdates.Count"):" -ForegroundColor Red
    $FailedUpdates | ForEach-Object {
        Write-Host "  - Resource $($_.ResourceId): Update Status - Failure" -ForegroundColor Red
    }
}
else {
    Write-Host "- No Failed Updates" -ForegroundColor Green
}

# Print successful updates
if ($SuccessfulUpdates.Count -gt 0) {
    Write-Host "- Successful Updates ("$SuccessfulUpdates.Count"):" -ForegroundColor Green
    $SuccessfulUpdates | ForEach-Object {
        Write-Host "  - Resource $($_.ResourceId): Update Status - Success" -ForegroundColor Green
    }
}
else {
    Write-Host "- No Successful Updates" -ForegroundColor Green
}