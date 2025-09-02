param aseName string
param allowNewPrivateEndpointConnections bool = false
param ftpEnabled bool = false
param remoteDebugEnabled bool = false

resource hostingEnvironment 'Microsoft.Web/hostingEnvironments@2022-03-01' existing = {
  name: aseName
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

output internalInboundIpAddresses array = asev3NetworkingConfig.properties.internalInboundIpAddresses
output externalInboundIpAddresses array = asev3NetworkingConfig.properties.externalInboundIpAddresses
output windowsOutboundIpAddresses array = asev3NetworkingConfig.properties.windowsOutboundIpAddresses
output linuxOutboundIpAddresses array = asev3NetworkingConfig.properties.linuxOutboundIpAddresses
