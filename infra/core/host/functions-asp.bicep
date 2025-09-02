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

var properties = {
  hostingEnvironmentProfile: {
    id: deployAse ? hostingEnvironment.id : ''
  }
}

resource functionAppServicePlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: name
  location: location
  tags: union(tags, { 'azd-service-name': name })
  properties: deployAse ? properties : {}
  sku: {
    name: skuName
    capacity: skuCount
  }
  kind: 'functionapp'
}

output functionsAppServicePlanName string = functionAppServicePlan.name
output functionsAppServicePlanId string = functionAppServicePlan.id
