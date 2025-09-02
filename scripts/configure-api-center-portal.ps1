# API Center Portal Configuration Script
# This script configures the API Center portal settings after deployment
# Based on https://learn.microsoft.com/en-us/azure/api-center/set-up-api-center-portal

param(
    [Parameter(Mandatory=$false)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$false)]
    [string]$ApiCenterName,
    
    [Parameter(Mandatory=$false)]
    [string]$ClientId
)

Write-Host "API Center Portal Configuration Script" -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Green

# Get environment values if parameters not provided
if ([string]::IsNullOrEmpty($SubscriptionId) -or [string]::IsNullOrEmpty($ResourceGroupName) -or [string]::IsNullOrEmpty($ApiCenterName) -or [string]::IsNullOrEmpty($ClientId)) {
    Write-Host "Getting configuration from azd environment..." -ForegroundColor Yellow
    
    try {
        $azdenv = azd env get-values --output json | ConvertFrom-Json
        
        if ([string]::IsNullOrEmpty($SubscriptionId)) {
            $SubscriptionId = $azdenv.AZURE_SUBSCRIPTION_ID
        }
        if ([string]::IsNullOrEmpty($ResourceGroupName)) {
            $ResourceGroupName = $azdenv.RESOURCE_GROUP_NAME
        }
        if ([string]::IsNullOrEmpty($ApiCenterName)) {
            $ApiCenterName = $azdenv.API_CENTER_NAME
        }
        if ([string]::IsNullOrEmpty($ClientId)) {
            $ClientId = $azdenv.API_CENTER_PORTAL_CLIENT_ID
        }
    }
    catch {
        Write-Host "Failed to get azd environment values: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Please provide parameters manually or ensure azd environment is configured." -ForegroundColor Red
        exit 1
    }
}

# Validate required parameters
if ([string]::IsNullOrEmpty($SubscriptionId)) {
    Write-Host "Error: SubscriptionId is required" -ForegroundColor Red
    exit 1
}
if ([string]::IsNullOrEmpty($ResourceGroupName)) {
    Write-Host "Error: ResourceGroupName is required" -ForegroundColor Red
    exit 1
}
if ([string]::IsNullOrEmpty($ApiCenterName)) {
    Write-Host "Error: ApiCenterName is required" -ForegroundColor Red
    exit 1
}
if ([string]::IsNullOrEmpty($ClientId)) {
    Write-Host "Error: ClientId is required" -ForegroundColor Red
    exit 1
}

Write-Host "Configuration Parameters:" -ForegroundColor Cyan
Write-Host "  Subscription ID: $SubscriptionId" -ForegroundColor Cyan
Write-Host "  Resource Group: $ResourceGroupName" -ForegroundColor Cyan
Write-Host "  API Center Name: $ApiCenterName" -ForegroundColor Cyan
Write-Host "  Client ID: $ClientId" -ForegroundColor Cyan

# Set the subscription context
Write-Host "`nSetting Azure subscription context..." -ForegroundColor Yellow
try {
    az account set --subscription $SubscriptionId
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to set subscription context" -ForegroundColor Red
        exit 1
    }
}
catch {
    Write-Host "Error setting subscription: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Check if API Center exists
Write-Host "Verifying API Center exists..." -ForegroundColor Yellow
try {
    $apiCenter = az apic show --resource-group $ResourceGroupName --name $ApiCenterName --output json 2>$null | ConvertFrom-Json
    if (-not $apiCenter) {
        Write-Host "Error: API Center '$ApiCenterName' not found in resource group '$ResourceGroupName'" -ForegroundColor Red
        exit 1
    }
    Write-Host "API Center found: $($apiCenter.name)" -ForegroundColor Green
}
catch {
    Write-Host "Error checking API Center: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Note: This script requires Azure CLI version that supports 'az apicenter' commands." -ForegroundColor Yellow
    Write-Host "You may need to install the apicenter extension: az extension add --name apicenter" -ForegroundColor Yellow
    exit 1
}

Write-Host "`n" -ForegroundColor Green
Write-Host "MANUAL CONFIGURATION REQUIRED" -ForegroundColor Yellow
Write-Host "=============================" -ForegroundColor Yellow
Write-Host "The Azure CLI does not currently support configuring API Center portal settings." -ForegroundColor Yellow
Write-Host "Please complete the following manual steps in the Azure portal:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Navigate to your API Center in the Azure portal:" -ForegroundColor Cyan
Write-Host "   https://portal.azure.com/#@/resource/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.ApiCenter/services/$ApiCenterName" -ForegroundColor White
Write-Host ""
Write-Host "2. In the left menu, select 'API Center portal' > 'Settings'" -ForegroundColor Cyan
Write-Host ""
Write-Host "3. On the 'Identity provider' tab, select 'Start set up'" -ForegroundColor Cyan
Write-Host ""
Write-Host "4. On the 'Manual' tab, enter the following information:" -ForegroundColor Cyan
Write-Host "   - Client ID: $ClientId" -ForegroundColor White
Write-Host "   - Redirect URI: https://$ApiCenterName.portal.$($apiCenter.location).azure-apicenter.ms" -ForegroundColor White
Write-Host ""
Write-Host "5. Select 'Save + publish'" -ForegroundColor Cyan
Write-Host ""
Write-Host "6. Your portal will be available at:" -ForegroundColor Cyan
Write-Host "   https://$ApiCenterName.portal.$($apiCenter.location).azure-apicenter.ms" -ForegroundColor White
Write-Host ""

# Check if app registration exists
Write-Host "Verifying app registration..." -ForegroundColor Yellow
try {
    $app = az ad app show --id $ClientId --output json 2>$null | ConvertFrom-Json
    if ($app) {
        Write-Host "App registration verified: $($app.displayName)" -ForegroundColor Green
        Write-Host "App ID: $($app.appId)" -ForegroundColor Cyan
        
        # Display redirect URIs
        Write-Host "`nConfigured Redirect URIs:" -ForegroundColor Cyan
        if ($app.spa -and $app.spa.redirectUris) {
            Write-Host "  SPA Redirect URIs:" -ForegroundColor Yellow
            foreach ($uri in $app.spa.redirectUris) {
                Write-Host "    - $uri" -ForegroundColor White
            }
        }
        if ($app.publicClient -and $app.publicClient.redirectUris) {
            Write-Host "  Mobile/Desktop Redirect URIs:" -ForegroundColor Yellow
            foreach ($uri in $app.publicClient.redirectUris) {
                Write-Host "    - $uri" -ForegroundColor White
            }
        }
    } else {
        Write-Host "Warning: Could not verify app registration with Client ID: $ClientId" -ForegroundColor Yellow
        Write-Host "Please ensure the app registration exists and you have permissions to view it." -ForegroundColor Yellow
    }
}
catch {
    Write-Host "Warning: Could not verify app registration: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host "`nConfiguration script completed!" -ForegroundColor Green
Write-Host "Please complete the manual portal configuration steps above." -ForegroundColor Yellow