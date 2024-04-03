param name string
param location string = resourceGroup().location
param tags object = {}
param storagePrivateDnsZoneName string
param storagePrivateEndpointName string
param privateEndpointSubnetName string
param dnsResourceGroupName string
param vnetResourceGroupName string
param vNetName string
param storageSku string 
param aseManagedIdentityName string
param fileShareName string

resource aseManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = if (aseManagedIdentityName != ''){
  name: aseManagedIdentityName
}

resource storage 'Microsoft.Storage/storageAccounts@2021-04-01' = {
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
      defaultAction: 'Allow'
    }
  }
}

resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2021-04-01' = {
  name: '${storage.name}/default/${fileShareName}'
}

module stReaderRoleAssignment '../roleassignments/roleassignment.bicep' = if (aseManagedIdentityName != ''){
  name: 'st-ase-reader-roleAssignment'
  params: {
    principalId: aseManagedIdentity.properties.principalId
    roleName: 'Storage Blob Data Reader'
    targetResourceId: storage.id
    deploymentName: 'st-ase-roleAssignment-DataReader'
  }
}

module stContributorRoleAssignment '../roleassignments/roleassignment.bicep' = if (aseManagedIdentityName != ''){
  name: 'st-ase-contributor-roleAssignment'
  params: {
    principalId: aseManagedIdentity.properties.principalId
    roleName: 'Storage Blob Data Contributor'
    targetResourceId: storage.id
    deploymentName: 'st-ase-roleAssignment-DataContributor'
  }
}

module privateEndpoint '../networking/private-endpoint.bicep' = {
  name: '${storage.name}-privateEndpoint-deployment'
  params: {
    groupIds: [
      'blob'
    ]
    dnsZoneName: storagePrivateDnsZoneName
    name: storagePrivateEndpointName
    subnetName: privateEndpointSubnetName
    privateLinkServiceId: storage.id
    vNetName: vNetName
    location: location
    dnsResourceGroupName: dnsResourceGroupName
    vnetResourceGroupName: vnetResourceGroupName
  }
}

output storageName string = storage.name
output storageEndpoint string = storage.properties.primaryEndpoints.blob
var blobStorageConnectionString = 'DefaultEndpointsProtocol=https;AccountName=${storage.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(storage.id, storage.apiVersion).keys[0].value}'
output storageConnectionString string = blobStorageConnectionString
