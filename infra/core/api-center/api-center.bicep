param name string
param location string = resourceGroup().location
param tags object = {}
param apimName string
param apimManagedIdentityName string
param portalClientId string = ''

// Create the API Center
resource apiCenter 'Microsoft.ApiCenter/services@2024-03-01' = {
  name: name
  location: location
  tags: union(tags, { 'azd-service-name': name })
  identity: {
    type: 'SystemAssigned'
  }
  properties: {}
}

// Create the default workspace (required) - COMMENTED OUT FOR TESTING
/*
resource apiCenterWorkspace 'Microsoft.ApiCenter/services/workspaces@2024-03-01' = {
  parent: apiCenter
  name: 'default'
  properties: {
    title: 'Default workspace'
    description: 'Default workspace for API Center'
  }
}

// Create environment for APIM integration
resource apimEnvironment 'Microsoft.ApiCenter/services/workspaces/environments@2024-03-01' = {
  parent: apiCenterWorkspace
  name: 'apim-environment'
  properties: {
    title: 'API Management Environment'
    description: 'Environment for Azure API Management integration'
    kind: 'production'
    server: {
      type: 'Azure API Management'
    }
  }
}
*/

// Reference the existing APIM managed identity
resource apimManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: apimManagedIdentityName
}

// Reference the existing APIM service
resource apimService 'Microsoft.ApiManagement/service@2024-05-01' existing = {
  name: apimName
}

// Assign API Center Data Reader role to APIM's managed identity for sync
resource apimApiCenterDataReaderRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: apiCenter
  name: guid(apiCenter.id, apimManagedIdentity.id, 'ApiCenterDataReader')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '0c34c906-8d99-4cb7-8bb7-33f5b0a1a799') // Azure API Center Data Reader
    principalId: apimManagedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// Assign API Management Service Reader role to API Center's system identity for sync
resource apiCenterApimServiceReaderRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: apimService
  name: guid(apimService.id, apiCenter.name, 'ApiManagementServiceReader')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '71522526-b88f-4d52-b57f-d31fc3546d0d') // API Management Service Reader
    principalId: apiCenter.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

output apiCenterName string = apiCenter.name
output apiCenterPortalUrl string = 'https://${apiCenter.name}.portal.${location}.azure-apicenter.ms'
output apiCenterDataEndpoint string = 'https://${apiCenter.name}.data.${location}.azure-apicenter.ms'
output apiCenterSystemIdentityPrincipalId string = apiCenter.identity.principalId
output workspaceName string = 'default' // apiCenterWorkspace.name
output environmentName string = 'apim-environment' // apimEnvironment.name
output portalClientId string = portalClientId

// Additional outputs for portal configuration
output redirectUris array = [
  'https://${apiCenter.name}.portal.${location}.azure-apicenter.ms'
  'https://vscode.dev/redirect'
  'http://localhost'
  // Note: The ms-appx-web URI with client ID must be configured manually in the portal after deployment
]

// Post-deployment setup instructions
output portalSetupInstructions string = '''
API Center Portal Setup Instructions:
====================================

1. Navigate to your API Center in the Azure portal:
   https://portal.azure.com/#@${tenant().tenantId}/resource/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.ApiCenter/services/${apiCenter.name}

2. Go to "API Center portal" > "Settings" in the left menu

3. On the "Identity provider" tab, select "Start set up"

4. On the "Manual" tab, enter the following:
   - Client ID: ${portalClientId}
   - Redirect URI: https://${apiCenter.name}.portal.${location}.azure-apicenter.ms

5. Select "Save + publish"

6. The portal will be available at: https://${apiCenter.name}.portal.${location}.azure-apicenter.ms

Note: App registration "${apiCenter.name}-apic-aad" has been created with the following redirect URIs:
- SPA: https://${apiCenter.name}.portal.${location}.azure-apicenter.ms
- SPA: https://vscode.dev/redirect  
- SPA: http://localhost
- Mobile: ms-appx-web://Microsoft.AAD.BrokerPlugin/${portalClientId}
'''
