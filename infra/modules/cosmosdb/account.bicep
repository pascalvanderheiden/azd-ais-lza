param name string
param location string
param tags object = {}
param vNetName string
param privateEndpointSubnetName string
param cosmosPrivateEndpointName string
param cosmosAccountPrivateDnsZoneName string
param apimManagedIdentityName string
param aseManagedIdentityName string
param myIpAddress string = ''
param myPrincipalId string = ''
param dnsResourceGroupName string
param vnetResourceGroupName string

var defaultConsistencyLevel = 'Session'

resource apimManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: apimManagedIdentityName
}

resource aseManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = if(aseManagedIdentityName != ''){
  name: aseManagedIdentityName
}

resource account 'Microsoft.DocumentDB/databaseAccounts@2022-05-15' = {
  name: toLower(name)
  kind: 'GlobalDocumentDB'
  location: location
  tags: union(tags, { 'azd-service-name': name })
  properties: {
    consistencyPolicy: {
      defaultConsistencyLevel: defaultConsistencyLevel
    }
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: true
      }
    ]
    disableKeyBasedMetadataWriteAccess: true
    databaseAccountOfferType: 'Standard'
    enableAutomaticFailover: false
    enableMultipleWriteLocations: false
    capabilities: [
      {
        name: 'EnableServerless'
      }
    ]
    publicNetworkAccess: 'Disabled'
    ipRules: [
      {
        ipAddressOrRange: myIpAddress
      }
    ]

  }
}

resource database 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2022-05-15' = {
  name: 'ods'
  parent: account
  properties:{
    resource: {
      id: 'ods'
    }
  }
}

var CosmosDBBuiltInDataContributor = {
  id: '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.DocumentDB/databaseAccounts/${account.name}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002'
}
resource ApimSqlRoleAssignment 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2023-11-15' = {
  name: guid(account.name, CosmosDBBuiltInDataContributor.id, apimManagedIdentityName)
  parent: account
  properties: {
    principalId: apimManagedIdentity.properties.principalId
    roleDefinitionId: CosmosDBBuiltInDataContributor.id
    scope: account.id
  }
}

resource AseSqlRoleAssignment 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2023-11-15' = if(aseManagedIdentityName != ''){
  name: guid(account.name, CosmosDBBuiltInDataContributor.id, aseManagedIdentityName)
  parent: account
  properties: {
    principalId: aseManagedIdentity.properties.principalId
    roleDefinitionId: CosmosDBBuiltInDataContributor.id
    scope: account.id
  }
}

resource sqlRoleAssignmentCurrentUser 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2023-11-15' = {
  name: guid(account.name,CosmosDBBuiltInDataContributor.id, myPrincipalId)
  parent: account
  properties: {
    principalId: myPrincipalId
    roleDefinitionId: CosmosDBBuiltInDataContributor.id
    scope: account.id
  }
}

module privateEndpoint '../networking/private-endpoint.bicep' = {
  name: '${account.name}-privateEndpoint-deployment'
  params: {
    groupIds: [
      'Sql'
    ]
    dnsZoneName: cosmosAccountPrivateDnsZoneName
    name: cosmosPrivateEndpointName
    subnetName: privateEndpointSubnetName
    privateLinkServiceId: account.id
    vNetName: vNetName
    location: location
    dnsResourceGroupName : dnsResourceGroupName
    vnetResourceGroupName: vnetResourceGroupName
  }
}

output cosmosDbName string = account.name
output cosmosDbEndPoint string = account.properties.documentEndpoint
