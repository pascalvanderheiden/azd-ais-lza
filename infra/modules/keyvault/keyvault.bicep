param name string
param location string 
param tags object = {}
param keyvaultPrivateDnsZoneName string
param keyvaultPrivateEndpointName string
param privateEndpointSubnetName string
param vNetName string
param apimManagedIdentityName string
param aseManagedIdentityName string
param apimServiceName string
param myPrincipalId string
param logAnalyticsWorkspaceIdForDiagnostics string

resource apimService 'Microsoft.ApiManagement/service@2023-03-01-preview' existing = {
  name: apimServiceName
}

resource apimConsumerSubscription 'Microsoft.ApiManagement/service/subscriptions@2021-08-01' existing = {
  name: 'consumer-subscription'
  parent: apimService
}

resource apimManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: apimManagedIdentityName
}

resource aseManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = if (aseManagedIdentityName != ''){
  name: aseManagedIdentityName
}

resource keyvault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: name
  location: location
  tags: union(tags, { 'azd-service-name': name })
  properties: {
    sku: {
      name: 'standard'
      family: 'A'
    }
    enableRbacAuthorization: true
    enableSoftDelete: false
    tenantId: subscription().tenantId
    publicNetworkAccess: 'Disabled'
    networkAcls:{
      bypass: 'AzureServices'
      defaultAction: 'Deny'
    }
  }
}

module apimRoleAssignment '../roleassignments/roleassignment.bicep' = {
  name: 'kv-apim-roleAssignment'
  params: {
    principalId: apimManagedIdentity.properties.principalId
    roleName: 'Key Vault Secrets User'
    targetResourceId: keyvault.id
    deploymentName: 'kv-apim-roleAssignment-SecretsUser'
  }
}

module aseRoleAssignment '../roleassignments/roleassignment.bicep' = if (aseManagedIdentityName != ''){
  name: 'kv-ase-roleAssignment'
  params: {
    principalId: aseManagedIdentity.properties.principalId
    roleName: 'Key Vault Secrets User'
    targetResourceId: keyvault.id
    deploymentName: 'kv-ase-roleAssignment-SecretsUser'
  }
}

module currentUserRoleAssignment '../roleassignments/roleassignment.bicep' = {
  name: 'kv-currentuser-roleAssignment'
  params: {
    principalId: myPrincipalId
    roleName: 'Key Vault Secrets Officer'
    targetResourceId: keyvault.id
    deploymentName: 'kv-currentuser-roleAssignment-SecretOfficer'
    principalType: 'User'
  }
}

resource consumerApiKey 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  name: 'Consumer'
  parent: keyvault
  properties: {
    attributes: {
      enabled: true
      
    }
    
    value: apimConsumerSubscription.listSecrets(apimConsumerSubscription.apiVersion).primaryKey
  }
}

module privateEndpoint '../networking/private-endpoint.bicep' = {
  name: '${keyvault.name}-privateEndpoint-deployment'
  params: {
    groupIds: [
      'vault'
    ]
    dnsZoneName: keyvaultPrivateDnsZoneName
    name: keyvaultPrivateEndpointName
    subnetName: privateEndpointSubnetName
    privateLinkServiceId: keyvault.id
    vNetName: vNetName
    location: location
  }
}

resource keyVaultDiagnosticSettings  'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'default'
  scope: keyvault
  properties: {
    workspaceId: logAnalyticsWorkspaceIdForDiagnostics
    logs: [
      {
        category: 'AuditEvent'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

output keyvaultName string = keyvault.name
output keyvaultUrl string = keyvault.properties.vaultUri
