# Install Azure CLI
# Install-Module -Name Az -Repository PSGallery -Force

# Login to Azure
Connect-AzAccount

$servicePrincipalName = "UpdateTagsSP"
$servicePrincipalRole = "Contributor"
$roleDefinitionName = "Contributor"
$waitTimeout = 3

# Get all subscriptions in the tenant
$subscriptions = Get-AzSubscription

# Loop through each subscription
foreach ($subscription in $subscriptions) {
    # Set the context to the subscription
    Set-AzContext -SubscriptionId $subscription.Id

    # Check if the service principal already exists
    $sp = Get-AzADServicePrincipal -DisplayName $servicePrincipalName
    # If there are multiple service principals with the same name, display an error
    if ($sp.Count -gt 1) {
        Write-Error "There are multiple service principals with the name '$servicePrincipalName'. Please delete the duplicates and try again."
        return
    }


    # If the service principal does not exist, create a new one
    # Create a new service principal with the 'Contributor' role for the current subscription
    if ($null -eq $sp) {
        $sp = New-AzADServicePrincipal -DisplayName $servicePrincipalName -Role $servicePrincipalRole -Scope "/subscriptions/$($subscription.Id)"
        Write-Host "Working on subscription: $($subscription.Name)" -ForegroundColor Yellow
        Write-Host "TenantId: $($subscription.TenantId)"
        Write-Host "AppId: $($sp.AppId)"
        # $password = ConvertFrom-SecureString -SecureString $sp.PasswordCredentials.SecretText -AsPlainText
        Write-Host "Password: $($sp.PasswordCredentials.SecretText)"

        # Wait for the service principal to propagate in Entra ID
        Write-Host "Waiting for service principal to propagate in Entra ID..." -ForegroundColor Yellow
        for ($i = $waitTimeout; $i -gt 0; $i--) {
            Write-Host -n "$i..."
            Start-Sleep -Seconds 1
        }
    } else {
        Write-Host "Service principal already exists for subscription: $($subscription.Name)" -ForegroundColor Yellow
        Write-Host "TenantId: $($subscription.TenantId)"
        Write-Host "AppId: $($sp.AppId)"
    }
    # Check if the role assignment exists
    $roleAssignment = Get-AzRoleAssignment -ObjectId $sp.Id -RoleDefinitionName $roleDefinitionName -Scope "/subscriptions/$($subscription.Id)"
    
    # If the role assignment does not exist, create it
    if (-not $roleAssignment) {
        New-AzRoleAssignment -ObjectId $sp.Id -RoleDefinitionName $roleDefinitionName -Scope "/subscriptions/$($subscription.Id)"
    }
}
