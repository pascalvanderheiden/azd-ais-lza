#!/usr/bin/env pwsh

# run az login and set correct subscription if needed.
./scripts/set-az-currentsubscription.ps1

if ($? -eq $true) {
    # Get environment variables
    $azdenv = azd env get-values --output json | ConvertFrom-Json
    
    Write-Host "Starting post deployment script..."
    
    # Configure API Center Portal
    Write-Host "Configuring API Center Portal..."
    
    try {
        # Pass environment variables as parameters to the configuration script
        ./scripts/configure-api-center-portal.ps1 `
            -SubscriptionId $azdenv.AZURE_SUBSCRIPTION_ID `
            -ResourceGroupName $azdenv.RESOURCE_GROUP_NAME `
            -ApiCenterName $azdenv.API_CENTER_NAME `
            -ClientId $azdenv.API_CENTER_PORTAL_CLIENT_ID
        
        if ($? -eq $true) {
            Write-Host "API Center Portal configuration completed successfully"
        } else {
            Write-Host "API Center Portal configuration completed with warnings (this is normal for manual steps)"
        }
    }
    catch {
        Write-Host "API Center Portal configuration encountered an issue: $_"
        Write-Host "This may be due to manual steps required. Please review the output above."
    }
    
    # Store API Center Portal Client ID in Key Vault (now that Key Vault exists)
    if ($azdenv.DEPLOY_API_CENTER -eq "true" -and $azdenv.API_CENTER_PORTAL_CLIENT_ID) {
        Write-Host "Storing API Center portal client ID in Key Vault..."
        
        # Generate Key Vault name based on the pattern from main.bicep
        $keyVaultName = if ($azdenv.KEYVAULT_NAME) { $azdenv.KEYVAULT_NAME } else { "kv-" + $azdenv.RESOURCE_TOKEN }
        
        try {
            $secretResult = az keyvault secret set `
                --name "ApiCenterPortalClientId" `
                --vault-name $keyVaultName `
                --value $azdenv.API_CENTER_PORTAL_CLIENT_ID `
                --output json 2>&1
                
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Client ID stored successfully in Key Vault"
            } else {
                Write-Host "Warning: Failed to store client ID in Key Vault: $secretResult" -ForegroundColor Yellow
            }
        }
        catch {
            Write-Host "Warning: Error storing client ID in Key Vault: $_" -ForegroundColor Yellow
        }
    } else {
        Write-Host "Skipping Key Vault storage - API Center not deployed or client ID not available"
    }
    
    Write-Host "Post deployment script finished"
}
else {
    Write-Host "Failed to set Azure subscription context"
    exit 1
}