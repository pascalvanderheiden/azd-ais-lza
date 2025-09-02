param name string
param location string = resourceGroup().location
param tags object = {}
param virtualNetworkId string
param subnetName string
param allowNewPrivateEndpointConnections bool = false
param ftpEnabled bool = false
param remoteDebugEnabled bool = false

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

resource asev3NetworkingConfig 'Microsoft.Web/hostingEnvironments/configurations@2022-03-01' = {
  name: 'networking'
  parent: hostingEnvironment
  properties: {
    allowNewPrivateEndpointConnections: allowNewPrivateEndpointConnections
    ftpEnabled: ftpEnabled
    remoteDebugEnabled: remoteDebugEnabled
  }
}

output aseName string = hostingEnvironment.name
output aseDomainName string = hostingEnvironment.properties.dnsSuffix
output aseExtId string = hostingEnvironment.id
output internalInboundIpAddresses array = asev3NetworkingConfig.properties.internalInboundIpAddresses
output externalInboundIpAddresses array = asev3NetworkingConfig.properties.externalInboundIpAddresses
output windowsOutboundIpAddresses array = asev3NetworkingConfig.properties.windowsOutboundIpAddresses
output linuxOutboundIpAddresses array = asev3NetworkingConfig.properties.linuxOutboundIpAddresses
