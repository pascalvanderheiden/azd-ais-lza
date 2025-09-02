param name string
param location string = resourceGroup().location
param tags object = {}
param virtualNetworkId string
param subnetName string

resource hostingEnvironment 'Microsoft.Web/hostingEnvironments@2022-03-01' = {
  name: name
  location: location
  tags: union(tags, { 'azd-service-name': name })
  kind: 'ASEV3'
  properties: {
    virtualNetwork: {
      id: virtualNetworkId
      subnet: subnetName
    }
    internalLoadBalancingMode: 'Web, Publishing'
    zoneRedundant: false
  }
}

output aseName string = hostingEnvironment.name
output aseDomainName string = hostingEnvironment.properties.dnsSuffix
output aseExtId string = hostingEnvironment.id
