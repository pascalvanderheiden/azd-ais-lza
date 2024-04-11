param name string
param location string = resourceGroup().location
param apimSubnetName string
param apimNsgName string
param aseSubnetName string
param aseNsgName string

param privateEndpointSubnetName string
param privateEndpointNsgName string
param privateDnsZoneNames array
param tags object = {}
param apimSku string
param deployAse bool


var webServerFarmDelegation = [
  {
    name: 'Microsoft.Web/serverFarms'
    properties: {
      serviceName: 'Microsoft.Web/serverFarms'
    }
  }
] 
var aseNewSubnet = {
  name: aseSubnetName
  properties: {
    addressPrefix: '10.0.3.0/24'
    networkSecurityGroup: aseNsg.id == '' ? null : {
      id: aseNsg.id
    }
    delegations: [
      {
          name: 'Microsoft.Web.hostingEnvironments'
          properties: {
              serviceName: 'Microsoft.Web/hostingEnvironments'
          }
      }
    ]
    serviceEndpoints: [
      {
        service: 'Microsoft.Storage'
      }
    ]
  }
}

resource apimNsg 'Microsoft.Network/networkSecurityGroups@2020-07-01' = {
  name: apimNsgName
  location: location
  tags: union(tags, { 'azd-service-name': apimNsgName })
  properties: {
    securityRules: [
      {
        name: 'AllowAPIMFrontdoor'
        properties: {
            protocol: 'Tcp'
            sourcePortRange: '*'
            destinationPortRange: '443'
            sourceAddressPrefix: 'AzureFrontDoor.Backend'
            destinationAddressPrefix: 'VirtualNetwork'
            access: 'Allow'
            priority: 100
            direction: 'Inbound'
        }
      }
      {
        name: 'AllowAPIMPortal'
        properties: {
            protocol: 'Tcp'
            sourcePortRange: '*'
            destinationPortRange: '3443'
            sourceAddressPrefix: 'ApiManagement'
            destinationAddressPrefix: 'VirtualNetwork'
            access: 'Allow'
            priority: 110
            direction: 'Inbound'
        }
      }
      {
        name: 'AllowAPIMLoadBalancer'
        properties: {
            protocol: 'Tcp'
            sourcePortRange: '*'
            destinationPortRange: '*'
            sourceAddressPrefix: 'AzureLoadBalancer'
            destinationAddressPrefix: 'VirtualNetwork'
            access: 'Allow'
            priority: 120
            direction: 'Inbound'
        }
      }
      {
        name: 'AllowVnetStorage'
        properties: {
            protocol: '*'
            sourcePortRange: '*'
            destinationPortRange: '443'
            sourceAddressPrefix: 'VirtualNetwork'
            destinationAddressPrefix: 'Storage'
            access: 'Allow'
            priority: 130
            direction: 'Outbound'
        }
      }
      {
        name: 'AllowEntra'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'AzureActiveDirectory'
          access: 'Allow'
          priority: 140
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowKeyvault'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'AzureKeyVault'
          access: 'Allow'
          priority: 150
          direction: 'Outbound'
        }
      }
      {
          name: 'AllowVnetMonitor'
          properties: {
              protocol: '*'
              sourcePortRange: '*'
              sourceAddressPrefix: 'VirtualNetwork'
              destinationAddressPrefix: 'AzureMonitor'
              access: 'Allow'
              priority: 160
              direction: 'Outbound'
              destinationPortRanges: [
                  '1886'
                  '443'
              ]
          }
      }
      {
        name: 'AllowRedis'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '6381-6383'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 170
          direction: 'Inbound'
        }
      }
    ]
  }
}

resource aseNsg 'Microsoft.Network/networkSecurityGroups@2022-09-01' = if(deployAse){
  name: aseNsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowVnetAzureConOutbound'
        properties: {
            protocol: '*'
            sourcePortRange: '*'
            destinationPortRange: '*'
            sourceAddressPrefix: 'VirtualNetwork'
            destinationAddressPrefix: 'AzureConnectors'
            access: 'Allow'
            priority: 110
            direction: 'Outbound'
        }
      }
      {
          name: 'AllowVnetAzureConInbound'
          properties: {
              protocol: '*'
              sourcePortRange: '*'
              destinationPortRange: '*'
              sourceAddressPrefix: 'AzureConnectors'
              destinationAddressPrefix: 'VirtualNetwork'
              access: 'Allow'
              priority: 120
              direction: 'Inbound'
          }
      }
    ]
  }
}

resource privateEndpointNsg 'Microsoft.Network/networkSecurityGroups@2020-07-01' = {
  name: privateEndpointNsgName
  location: location
  tags: union(tags, { 'azd-service-name': privateEndpointNsgName })
  properties: {
    securityRules: []
  }
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2019-11-01' = {
  name: name
  location: location
  tags: union(tags, { 'azd-service-name': name })
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'default'
        properties: {
          addressPrefix: '10.0.0.0/24'
        }
      }
      {
        name: apimSubnetName
        properties: {
          addressPrefix: '10.0.1.0/24'
          networkSecurityGroup: apimNsg.id == '' ? null : {
            id: apimNsg.id 
          }
          // Needed when using APIM StandardV2 SKU
          delegations: apimSku == 'StandardV2' ? webServerFarmDelegation :  []
        }
      }
      {
        name: privateEndpointSubnetName
        properties: {
          addressPrefix: '10.0.2.0/24'
          networkSecurityGroup: privateEndpointNsg.id == '' ? null : {
            id: privateEndpointNsg.id
          }
        }
      }
      deployAse ? aseNewSubnet : {}
    ]
  }

  resource defaultSubnet 'subnets' existing = {
    name: 'default'
  }

  resource apimSubnet 'subnets' existing = {
    name: apimSubnetName
  }
  
  resource aseSubnet 'subnets' existing = if(deployAse){
    name: aseSubnetName
  }
  
  resource privateEndpointSubnet 'subnets' existing = {
    name: privateEndpointSubnetName
  }
}

resource privateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = [for privateDnsZoneName in privateDnsZoneNames: {
  name: '${privateDnsZoneName}/privateDnsZoneLink'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: virtualNetwork.id
    }
    registrationEnabled: false
  }
}]

output virtualNetworkId string = virtualNetwork.id
output vnetName string = virtualNetwork.name
output apimSubnetName string = virtualNetwork::apimSubnet.name
output apimSubnetId string = virtualNetwork::apimSubnet.id
output aseSubnetName string = virtualNetwork::aseSubnet.name
output aseSubnetId string = virtualNetwork::aseSubnet.id
output privateEndpointSubnetName string = virtualNetwork::privateEndpointSubnet.name
output privateEndpointSubnetId string = virtualNetwork::privateEndpointSubnet.id
