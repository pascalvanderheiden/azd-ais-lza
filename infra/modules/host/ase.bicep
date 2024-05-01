param name string
param location string = resourceGroup().location
param tags object = {}
param virtualNetworkId string
param subnetName string
param aseManagedIdentityName string

var internalLoadBalancingMode = 'Web,Publishing'
var privateDnsZoneName = '${name}.appserviceenvironment.net'

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

resource asev3config 'Microsoft.Web/hostingEnvironments/configurations@2022-03-01' = {
  name: 'networking'
  parent: hostingEnvironment
  properties: {
    allowNewPrivateEndpointConnections: false
    ftpEnabled: false
    remoteDebugEnabled: true
  }
}

module dnsDeployment '../networking/dns.bicep' = {
  name: 'dns-deployment-${privateDnsZoneName}'
  params: {
    name: privateDnsZoneName
  }
}

module webrecord '../networking/dnsentry.bicep' = {
  name: 'dns-entry-ase-webrecord'
  params: {
    dnsZoneName: privateDnsZoneName
    ipAddress: asev3config.properties.internalInboundIpAddresses[0]
    hostname: '*'
  }
}

module scmrecord '../networking/dnsentry.bicep' = {
  name: 'dns-entry-ase-scmrecord'
  params: {
    dnsZoneName: privateDnsZoneName
    ipAddress: asev3config.properties.internalInboundIpAddresses[0]
    hostname: '*.scm'
  }
}

module atrecord '../networking/dnsentry.bicep' = {
  name: 'dns-entry-ase-atrecord'
  params: {
    dnsZoneName: privateDnsZoneName
    ipAddress: asev3config.properties.internalInboundIpAddresses[0]
    hostname: '@'
  }
}

output aseName string = hostingEnvironment.name
output aseDomainName string = hostingEnvironment.properties.dnsSuffix
output aseExtId string = hostingEnvironment.id
