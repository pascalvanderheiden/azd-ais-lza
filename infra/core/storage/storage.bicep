param name string
param location string = resourceGroup().location
param tags object = {}
param storageSku string 
param aseManagedIdentityName string
param myIpAddress string = ''
param myPrincipalId string
param blobPrivateDnsZoneName string
param blobPrivateEndpointName string
param tablePrivateDnsZoneName string
param tablePrivateEndpointName string
param queuePrivateDnsZoneName string
param queuePrivateEndpointName string
param filePrivateDnsZoneName string
param filePrivateEndpointName string
param privateEndpointSubnetName string
param vNetName string
param keyVaultName string

resource aseManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = if (aseManagedIdentityName != ''){
  name: aseManagedIdentityName
}

resource storage 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: name
  location: location
  tags: union(tags, { 'azd-service-name': name })
  sku: {
    name: storageSku
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false 
    networkAcls:{
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      ipRules: [
        {
          value: myIpAddress //for local development
        }
      ]
    }
    encryption: {
      services: {
        blob: {
          keyType: 'Account'
          enabled: true
        }
        file: {
          keyType: 'Account'
          enabled: true
        }
      }
    }
  }
}

module privateEndpointBlob '../networking/private-endpoint.bicep' = {
  name: '${storage.name}-privateEndpoint-deployment-blob'
  params: {
    groupIds: [
      'blob'
    ]
    dnsZoneName: blobPrivateDnsZoneName
    name: blobPrivateEndpointName
    subnetName: privateEndpointSubnetName
    privateLinkServiceId: storage.id
    vNetName: vNetName
    location: location
  }
}

module privateEndpointTable '../networking/private-endpoint.bicep' = {
  name: '${storage.name}-privateEndpoint-deployment-table'
  params: {
    groupIds: [
      'table'
    ]
    dnsZoneName: tablePrivateDnsZoneName
    name: tablePrivateEndpointName
    subnetName: privateEndpointSubnetName
    privateLinkServiceId: storage.id
    vNetName: vNetName
    location: location
  }
}

module privateEndpointFile '../networking/private-endpoint.bicep' = {
  name: '${storage.name}-privateEndpoint-deployment-file'
  params: {
    groupIds: [
      'file'
    ]
    dnsZoneName: filePrivateDnsZoneName
    name: filePrivateEndpointName
    subnetName: privateEndpointSubnetName
    privateLinkServiceId: storage.id
    vNetName: vNetName
    location: location
  }
}

module privateEndpointQueue '../networking/private-endpoint.bicep' = {
  name: '${storage.name}-privateEndpoint-deployment-queue'
  params: {
    groupIds: [
      'queue'
    ]
    dnsZoneName: queuePrivateDnsZoneName
    name: queuePrivateEndpointName
    subnetName: privateEndpointSubnetName
    privateLinkServiceId: storage.id
    vNetName: vNetName
    location: location
  }
}

var blobStorageConnectionString = 'DefaultEndpointsProtocol=https;AccountName=${storage.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(storage.id, storage.apiVersion).keys[0].value}'
module keyvaultSecretConnectionString '../keyvault/keyvault-secret.bicep' = {
  name: '${storage.name}-connectionstring-deployment-keyvault'
  params: {
    keyVaultName: keyVaultName
    secretName: 'storage-connection-string'
    secretValue: blobStorageConnectionString
  }
}

output storageName string = storage.name
output storageEndpoint string = storage.properties.primaryEndpoints.blob
output storageConnectionString string = blobStorageConnectionString
