#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Configures integration between Azure API Center and Azure API Management

.DESCRIPTION
    This script creates an integration between Azure API Center and Azure API Management
    to enable continuous synchronization of APIs from API Management to API Center.
    The integration uses Azure CLI commands as this functionality is currently only
    available via CLI.

.PARAMETER SubscriptionId
    The Azure subscription ID

.PARAMETER ResourceGroupName
    The name of the resource group containing both API Center and API Management

.PARAMETER ApiCenterName
    The name of the API Center service

.PARAMETER ApimName
    The name of the API Management service

.PARAMETER IntegrationName
    The name for the integration (optional, defaults to 'apim-integration')

.EXAMPLE
    ./configure-apic-apim-integration.ps1 -SubscriptionId "12345678-1234-1234-1234-123456789012" -ResourceGroupName "rg-myproject" -ApiCenterName "apic-myproject" -ApimName "apim-myproject"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $true)]
    [string]$ApiCenterName,
    
    [Parameter(Mandatory = $true)]
    [string]$ApimName,
    
    [Parameter(Mandatory = $false)]
    [string]$IntegrationName = "apim-integration"
)

Write-Host "API Center and API Management Integration Script"
Write-Host "================================================="
Write-Host "Configuration Parameters:"
Write-Host "  Subscription ID: $SubscriptionId"
Write-Host "  Resource Group: $ResourceGroupName"
Write-Host "  API Center Name: $ApiCenterName"
Write-Host "  API Management Name: $ApimName"
Write-Host "  Integration Name: $IntegrationName"
Write-Host ""

# Set Azure subscription context
Write-Host "Setting Azure subscription context..."
az account set --subscription $SubscriptionId
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Failed to set subscription context" -ForegroundColor Red
    exit 1
}

# Verify API Center exists
Write-Host "Verifying API Center exists..."
$apiCenter = az apic show --name $ApiCenterName --resource-group $ResourceGroupName --output json 2>$null | ConvertFrom-Json
if (-not $apiCenter) {
    Write-Host "Error: API Center '$ApiCenterName' not found in resource group '$ResourceGroupName'" -ForegroundColor Red
    exit 1
}
Write-Host "API Center found: $($apiCenter.name)"

# Verify API Management exists
Write-Host "Verifying API Management exists..."
$apim = az apim show --name $ApimName --resource-group $ResourceGroupName --output json 2>$null | ConvertFrom-Json
if (-not $apim) {
    Write-Host "Error: API Management '$ApimName' not found in resource group '$ResourceGroupName'" -ForegroundColor Red
    exit 1
}
Write-Host "API Management found: $($apim.name)"

# Check if integration already exists
Write-Host "Checking if integration already exists..."
$existingIntegration = az apic integration list --resource-group $ResourceGroupName --service-name $ApiCenterName --output json 2>$null | ConvertFrom-Json
$integrationExists = $false

if ($existingIntegration) {
    foreach ($integration in $existingIntegration) {
        if ($integration.name -eq $IntegrationName) {
            $integrationExists = $true
            Write-Host "Integration '$IntegrationName' already exists"
            break
        }
    }
}

if (-not $integrationExists) {
    Write-Host "Creating API Management integration..."
    
# Check Azure CLI version
Write-Host "Checking Azure CLI version..."
$cliVersion = az version --output json | ConvertFrom-Json
$cliVersionString = $cliVersion."azure-cli"
Write-Host "Azure CLI version: $cliVersionString"

# Parse version to check if it's >= 2.57.0
$versionParts = $cliVersionString.Split('.')
$majorVersion = [int]$versionParts[0]
$minorVersion = [int]$versionParts[1]

if ($majorVersion -lt 2 -or ($majorVersion -eq 2 -and $minorVersion -lt 57)) {
    Write-Host "Warning: Azure CLI version $cliVersionString detected. API Center integration requires version 2.57.0 or higher." -ForegroundColor Yellow
    Write-Host "Please update Azure CLI using: az upgrade" -ForegroundColor Yellow
}

# Install the apic-extension
Write-Host "Installing/updating Azure CLI apic-extension..."
az extension add --name apic-extension --allow-preview --upgrade --output none 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Warning: Could not install/update apic-extension" -ForegroundColor Yellow
    Write-Host "The integration feature may not work properly" -ForegroundColor Yellow
}    # Create the integration
    Write-Host "Creating integration between API Center and API Management..."
    $integrationResult = az apic integration create apim `
        --resource-group $ResourceGroupName `
        --service-name $ApiCenterName `
        --integration-name $IntegrationName `
        --azure-apim $ApimName `
        --output json 2>&1
    
    # Check if the command succeeded
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Integration created successfully!" -ForegroundColor Green
        try {
            $integration = $integrationResult | ConvertFrom-Json
            Write-Host "Integration Details:"
            Write-Host "  Name: $($integration.name)"
            Write-Host "  Provisioning State: $($integration.properties.provisioningState)"
        } catch {
            Write-Host "Integration created, but unable to parse response details" -ForegroundColor Yellow
        }
        
        # Display sync status
        Write-Host ""
        Write-Host "API synchronization has been initiated. APIs from API Management will be synchronized to API Center."
        Write-Host "Note: API synchronization typically occurs within minutes, but can take up to 24 hours."
        Write-Host ""
        Write-Host "You can monitor the integration in the Azure portal:"
        Write-Host "1. Navigate to your API Center: https://portal.azure.com/#resource/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.ApiCenter/services/$ApiCenterName"
        Write-Host "2. Go to 'Assets' > 'Environments' to see the integrated API Management environment"
        Write-Host "3. Go to 'Assets' > 'APIs' to see synchronized APIs"
    } else {
        Write-Host "Error creating integration:" -ForegroundColor Red
        Write-Host "$integrationResult" -ForegroundColor Red
        
        # Enhanced error analysis
        $errorString = $integrationResult | Out-String
        
        # Check for common error patterns and provide specific guidance
        if ($errorString -like "*Forbidden*" -or $errorString -like "*Authorization*" -or $errorString -like "*permission*") {
            Write-Host ""
            Write-Host "PERMISSIONS ERROR DETECTED" -ForegroundColor Yellow
            Write-Host "This appears to be a permissions error. Please ensure:" -ForegroundColor Yellow
            Write-Host "1. The API Center's system-assigned managed identity has 'API Management Service Reader' role on the API Management instance" -ForegroundColor Yellow
            Write-Host "2. You have sufficient permissions to create integrations in the API Center" -ForegroundColor Yellow
            Write-Host "3. The role assignments have had time to propagate (can take up to 10 minutes)" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "To assign the required role, run:" -ForegroundColor Cyan
            Write-Host "az role assignment create --assignee-object-id <API-CENTER-MANAGED-IDENTITY-ID> --role 'API Management Service Reader' --scope /subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.ApiManagement/service/$ApimName" -ForegroundColor Cyan
        }
        elseif ($errorString -like "*not found*" -or $errorString -like "*does not exist*") {
            Write-Host ""
            Write-Host "RESOURCE NOT FOUND ERROR" -ForegroundColor Yellow
            Write-Host "One of the resources was not found. Please verify:" -ForegroundColor Yellow
            Write-Host "1. API Center '$ApiCenterName' exists in resource group '$ResourceGroupName'" -ForegroundColor Yellow
            Write-Host "2. API Management '$ApimName' exists in resource group '$ResourceGroupName'" -ForegroundColor Yellow
            Write-Host "3. You have access to both resources" -ForegroundColor Yellow
        }
        elseif ($errorString -like "*apic*" -or $errorString -like "*extension*" -or $errorString -like "*command*") {
            Write-Host ""
            Write-Host "EXTENSION ERROR DETECTED" -ForegroundColor Yellow
            Write-Host "This may be due to the apic-extension. Please try:" -ForegroundColor Yellow
            Write-Host "1. Update Azure CLI: az upgrade" -ForegroundColor Yellow
            Write-Host "2. Reinstall extension: az extension remove --name apic-extension && az extension add --name apic-extension" -ForegroundColor Yellow
        }
        elseif ($errorString -like "*already exists*" -or $errorString -like "*conflict*") {
            Write-Host ""
            Write-Host "INTEGRATION ALREADY EXISTS" -ForegroundColor Yellow
            Write-Host "An integration with this name may already exist. Try:" -ForegroundColor Yellow
            Write-Host "1. List existing integrations: az apic integration list --resource-group $ResourceGroupName --service-name $ApiCenterName" -ForegroundColor Yellow
            Write-Host "2. Use a different integration name or delete the existing one" -ForegroundColor Yellow
        }
        else {
            Write-Host ""
            Write-Host "GENERAL TROUBLESHOOTING" -ForegroundColor Yellow
            Write-Host "For general troubleshooting:" -ForegroundColor Yellow
            Write-Host "1. Verify Azure CLI version is 2.57.0 or higher: az version" -ForegroundColor Yellow
            Write-Host "2. Check your Azure subscription and permissions" -ForegroundColor Yellow
            Write-Host "3. Try running with debug output: az apic integration create apim --debug ..." -ForegroundColor Yellow
        }
        
        exit 1
    }
} else {
    Write-Host "Integration already exists. Skipping creation."
    
    # Get integration details
    $integration = az apic integration show --resource-group $ResourceGroupName --service-name $ApiCenterName --integration-name $IntegrationName --output json 2>$null | ConvertFrom-Json
    if ($integration) {
        Write-Host "Current Integration Details:"
        Write-Host "  Name: $($integration.name)"
        Write-Host "  Provisioning State: $($integration.properties.provisioningState)"
    }
}

Write-Host ""
Write-Host "API Center and API Management integration configuration completed!" -ForegroundColor Green