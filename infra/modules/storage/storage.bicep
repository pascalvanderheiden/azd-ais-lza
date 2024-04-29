param name string
param location string = resourceGroup().location
param tags object = {}
param aseSubnetName string
param storageSku string 
param aseManagedIdentityName string
param fileShareName string
param myIpAddress string
param myPrincipalId string

resource aseSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-04-01' existing = if(aseSubnetName != ''){
  name: aseSubnetName
}

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
      defaultAction: 'Allow'
      ipRules: [
        {
          action: 'Allow'
          value: myIpAddress
        }
      ]
      virtualNetworkRules: [
        {
          action: 'Allow'
          id: aseSubnet.id
        }
      ]
    }
  }
}

resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-01-01' = {
  name: '${storage.name}/default/${fileShareName}'
}

module stReaderRoleAssignment '../roleassignments/roleassignment.bicep' = if (aseManagedIdentityName != ''){
  name: 'st-ase-reader-roleAssignment'
  params: {
    principalId: (aseManagedIdentityName != '') ? aseManagedIdentity.properties.principalId : ''
    roleName: 'Storage Blob Data Reader'
    targetResourceId: (aseManagedIdentityName != '') ? storage.id : ''
    deploymentName: 'st-ase-roleAssignment-DataReader'
  }
}

module stContributorRoleAssignment '../roleassignments/roleassignment.bicep' = if (aseManagedIdentityName != ''){
  name: 'st-ase-contributor-roleAssignment'
  params: {
    principalId: (aseManagedIdentityName != '') ? aseManagedIdentity.properties.principalId : ''
    roleName: 'Storage Blob Data Contributor'
    targetResourceId: (aseManagedIdentityName != '') ? storage.id : ''
    deploymentName: 'st-ase-roleAssignment-DataContributor'
  }
}

module currentUserRoleAssignment '../roleassignments/roleassignment.bicep' = if (aseManagedIdentityName != ''){
  name: 'st-currentuser-roleAssignment'
  params: {
    principalId: myPrincipalId
    roleName: 'Storage Account Contributor'
    targetResourceId: storage.id
    deploymentName: 'st-currentuser-StorageAccountContributor'
  }
}

output storageName string = storage.name
output storageEndpoint string = storage.properties.primaryEndpoints.blob
var blobStorageConnectionString = 'DefaultEndpointsProtocol=https;AccountName=${storage.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(storage.id, storage.apiVersion).keys[0].value}'
output storageConnectionString string = blobStorageConnectionString
