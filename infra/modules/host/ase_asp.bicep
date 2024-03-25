param name string
param location string = resourceGroup().location
param aspName string
param tags object = {}
param virtualNetworkId string
param subnetName string
param aseManagedIdentityName string

var internalLoadBalancingMode = 'Web,Publishing'
var numberOfWorkers = 1
var workerPool = '1v2'

resource managedIdentityAse 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: aseManagedIdentityName
}

resource hostingEnvironment 'Microsoft.Web/hostingEnvironments@2022-03-01' = {
  name: name
  location: location
  tags: union(tags, { 'azd-service-name': name })
  kind: 'ASEV3'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityAse.id}': {}
    }
  }
  properties: {
    ipsslAddressCount: 0
    internalLoadBalancingMode: internalLoadBalancingMode
    virtualNetwork: {
      id: virtualNetworkId
      subnet: subnetName
    }
  }
}
resource serverFarm 'Microsoft.Web/serverfarms@2020-06-01' = {
  name: aspName
  location: location
  properties: {
    hostingEnvironmentProfile: {
      id: hostingEnvironment.id
    }
  }
  sku: {
    name: 'I${workerPool}'
    tier: 'IsolatedV2'
    size: 'I${workerPool}'
    family: 'Iv2'
    capacity: numberOfWorkers
  }
}

output aseName string = hostingEnvironment.name
output aseDomainName string = hostingEnvironment.properties.dnsSuffix
output aseExtId string = hostingEnvironment.id
output appServicePlanName string = serverFarm.name
output appServicePlanExtId string = serverFarm.id
