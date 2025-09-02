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
    
    # Configure API Center and API Management Integration
    if ($azdenv.DEPLOY_API_CENTER -eq "true") {
        Write-Host "Configuring API Center and API Management integration..."
        
        try {
            ./scripts/configure-apic-apim-integration.ps1 `
                -SubscriptionId $azdenv.AZURE_SUBSCRIPTION_ID `
                -ResourceGroupName $azdenv.RESOURCE_GROUP_NAME `
                -ApiCenterName $azdenv.API_CENTER_NAME `
                -ApimName $azdenv.APIM_NAME
            
            if ($? -eq $true) {
                Write-Host "API Center and API Management integration completed successfully"
            } else {
                Write-Host "API Center and API Management integration completed with warnings"
            }
        }
        catch {
            Write-Host "API Center and API Management integration encountered an issue: $_"
            Write-Host "You can run the integration script manually later if needed."
        }
    } else {
        Write-Host "Skipping API Center and API Management integration - API Center not deployed"
    }
    
    # Store API Center Portal Client ID in Key Vault (now that Key Vault exists)
    if ($azdenv.DEPLOY_API_CENTER -eq "true" -and $azdenv.API_CENTER_PORTAL_CLIENT_ID) {
        Write-Host "Storing API Center portal client ID in Key Vault..."
        
        # Generate Key Vault name based on the pattern from main.bicep
        $keyVaultName = if ($azdenv.KEYVAULT_NAME) { $azdenv.KEYVAULT_NAME } else { "kv-" + $azdenv.RESOURCE_TOKEN }
        
        # Retry logic for Key Vault secret creation (to handle role assignment propagation delays)
        $maxRetries = 3
        $retryDelay = 30 # seconds
        $success = $false
        
        for ($attempt = 1; $attempt -le $maxRetries; $attempt++) {
            Write-Host "Attempt $attempt of $maxRetries to store client ID in Key Vault..."
            
            try {
                $secretResult = az keyvault secret set `
                    --name "ApiCenterPortalClientId" `
                    --vault-name $keyVaultName `
                    --value $azdenv.API_CENTER_PORTAL_CLIENT_ID `
                    --output json 2>&1
                    
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "Client ID stored successfully in Key Vault"
                    $success = $true
                    break
                } else {
                    Write-Host "Attempt $attempt failed: $secretResult" -ForegroundColor Yellow
                    if ($attempt -lt $maxRetries) {
                        Write-Host "Waiting $retryDelay seconds before retry (role assignments may still be propagating)..." -ForegroundColor Yellow
                        Start-Sleep -Seconds $retryDelay
                    }
                }
            }
            catch {
                Write-Host "Attempt $attempt failed with exception: $_" -ForegroundColor Yellow
                if ($attempt -lt $maxRetries) {
                    Write-Host "Waiting $retryDelay seconds before retry..." -ForegroundColor Yellow
                    Start-Sleep -Seconds $retryDelay
                }
            }
        }
        
        if (-not $success) {
            Write-Host "Warning: Failed to store client ID in Key Vault after $maxRetries attempts" -ForegroundColor Yellow
            Write-Host "This may be due to role assignment propagation delays. You can manually run this script later or store the secret manually." -ForegroundColor Yellow
            Write-Host "Client ID: $($azdenv.API_CENTER_PORTAL_CLIENT_ID)" -ForegroundColor Yellow
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