param name string
param location string = resourceGroup().location
param tags object = {}
param aseName string
param deployAse bool
param skuName string
param skuCount int

resource hostingEnvironment 'Microsoft.Web/hostingEnvironments@2022-03-01' existing = if(deployAse) {
  name: aseName
}

resource serverFarm 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: name
  location: location
  tags: union(tags, { 'azd-service-name': name })
  properties: {
    hostingEnvironmentProfile: {
      id: deployAse ? hostingEnvironment.id : ''
    }
  }
  sku: {
    name: skuName
    capacity: skuCount
  }
}

output appServicePlanName string = serverFarm.name
output appServicePlanExtId string = serverFarm.id
