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
param myIpAddress string = ''
param myPrincipalId string
param dnsResourceGroupName string
param vnetResourceGroupName string
param apimResourceGroupName string
param logAnalyticsWorkspaceIdForDiagnostics string


resource rgApim 'Microsoft.Resources/resourceGroups@2023-07-01' existing = {
  name: apimResourceGroupName
  scope: subscription()
}


resource apimService 'Microsoft.ApiManagement/service@2023-03-01-preview' existing = {
  name: apimServiceName
  scope: rgApim
}

resource apimMarketingSubscription 'Microsoft.ApiManagement/service/subscriptions@2021-08-01' existing = {
  name: 'marketing-dept-subscription'
  parent: apimService
}


resource apimFinanceSubscription 'Microsoft.ApiManagement/service/subscriptions@2021-08-01' existing = {
  name: 'finance-dept-subscription'
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
    networkAcls:{
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      ipRules: [
        {
          value: myIpAddress
        }
      ]
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

resource marketingApiKey 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  name: 'Marketing'
  parent: keyvault
  properties: {
    attributes: {
      enabled: true
      
    }
    
    value: apimMarketingSubscription.listSecrets(apimMarketingSubscription.apiVersion).primaryKey
  }
}

resource financeApiKey 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  name: 'Finance'
  parent: keyvault
  properties: {
    attributes: {
      enabled: true
      
    }
    value: apimFinanceSubscription.listSecrets(apimFinanceSubscription.apiVersion).primaryKey
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
    dnsResourceGroupName: dnsResourceGroupName
    vnetResourceGroupName: vnetResourceGroupName
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
