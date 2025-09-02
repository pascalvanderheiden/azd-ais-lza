# API Center Portal App Registration Script
# This script creates an Azure AD App Registration for the API Center managed portal
# Based on https://learn.microsoft.com/en-us/azure/api-center/set-up-api-center-portal

# Run az login and set correct subscription if needed
./scripts/set-az-currentsubscription.ps1

if ($? -eq $true) {
    
    $azdenv = azd env get-values --output json | ConvertFrom-Json
    
    # Only proceed if API Center is being deployed
    if ($azdenv.DEPLOY_API_CENTER -eq "true") {
        
        # Generate API Center name (it gets derived during deployment)
        $apiCenterName = if ($azdenv.API_CENTER_NAME) { $azdenv.API_CENTER_NAME } else { "apic-" + $azdenv.RESOURCE_TOKEN }
        
        # Check if registration exists
        $displayName = $apiCenterName + "-apic-aad"
        $app = az ad app list --display-name "$displayName" --output json | ConvertFrom-Json
        
        if (!$app) {
            
            Write-Host "Creating new API Center portal app registration $displayName..."
            
            # Build redirect URIs for API Center portal and VS Code extension
            $apiCenterPortalUrl = "https://" + $apiCenterName + ".portal." + $azdenv.AZURE_LOCATION + ".azure-apicenter.ms"
            $vscodeRedirectUri = "https://vscode.dev/redirect"
            $localhostRedirectUri = "http://localhost"
            
            # Create SPA redirect URIs array
            $spaRedirectUris = @($apiCenterPortalUrl, $vscodeRedirectUri, $localhostRedirectUri)
            
            # Create the app registration first without redirect URIs
            $app = az ad app create `
                --display-name "$displayName" `
                --sign-in-audience AzureADMyOrg `
                --enable-id-token-issuance true `
                --output json | ConvertFrom-Json
            
            if ($app -and $app.appId) {
                Write-Host "App registration $displayName created successfully with App ID: $($app.appId)"
                
                # Update with SPA redirect URIs for SPA functionality
                Write-Host "Configuring SPA redirect URIs..."
                $spaRedirectUrisString = ($spaRedirectUris -join ' ')
                $updateResult = az ad app update --id "$($app.appId)" `
                    --spa-redirect-uris $spaRedirectUrisString `
                    --output json 2>&1
                
                if ($LASTEXITCODE -ne 0) {
                    Write-Host "Warning: Failed to configure SPA redirect URIs: $updateResult" -ForegroundColor Yellow
                }
            } else {
                Write-Host "ERROR: Failed to create app registration" -ForegroundColor Red
                return
            }
            
            # Configure additional redirect URIs for VS Code extension
            Write-Host "Configuring additional redirect URIs for VS Code extension..."
            
            # Create the mobile redirect URI with the client ID
            $mobileRedirectUri = "ms-appx-web://Microsoft.AAD.BrokerPlugin/" + $app.appId
            $publicClientRedirectUris = @($vscodeRedirectUri, $localhostRedirectUri, $mobileRedirectUri)
            
            # Update the app registration with public client redirect URIs
            $publicClientRedirectUrisString = ($publicClientRedirectUris -join ' ')
            $updateResult = az ad app update --id "$($app.appId)" `
                --public-client-redirect-uris $publicClientRedirectUrisString `
                --output json 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Public client redirect URIs configured successfully"
            } else {
                Write-Host "Warning: Failed to configure public client redirect URIs: $updateResult" -ForegroundColor Yellow
            }
            
            Write-Host "Note: Client ID will be stored in Key Vault during post-deployment phase"
            
            # Set environment variables
            $envResult1 = azd env set API_CENTER_PORTAL_CLIENT_ID "$($app.appId)" 2>&1
            $envResult2 = azd env set API_CENTER_PORTAL_REDIRECT_URI "$apiCenterPortalUrl" 2>&1
            
            if ($envResult1 -match "ERROR" -or $envResult2 -match "ERROR") {
                Write-Host "Warning: Failed to set some environment variables" -ForegroundColor Yellow
                Write-Host "Result 1: $envResult1" -ForegroundColor Yellow
                Write-Host "Result 2: $envResult2" -ForegroundColor Yellow
            }
            
            Write-Host "API Center portal app registration setup completed successfully!" -ForegroundColor Green
            Write-Host "App Name: $displayName" -ForegroundColor Green
            Write-Host "Client ID: $($app.appId)" -ForegroundColor Green
            Write-Host "Portal URL: $apiCenterPortalUrl" -ForegroundColor Green
            
        }
        else {
            Write-Host "App registration $displayName already exists with App ID: $($app.appId)"
            
            # Ensure environment variables are set
            azd env set API_CENTER_PORTAL_CLIENT_ID "$($app.appId)"
            azd env set API_CENTER_PORTAL_REDIRECT_URI "https://$apiCenterName.portal.$($azdenv.AZURE_LOCATION).azure-apicenter.ms"
            
            Write-Host "Note: Client ID will be stored in Key Vault during post-deployment phase"
        }
    }
    else {
        Write-Host "API Center deployment is disabled, skipping app registration setup"
    }
}
else {
    Write-Host "Failed to set Azure subscription" -ForegroundColor Red
    exit 1
}