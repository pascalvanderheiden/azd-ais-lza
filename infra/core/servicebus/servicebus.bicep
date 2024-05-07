param name string
param location string = resourceGroup().location
param tags object = {}
param serviceBusPrivateDnsZoneName string
param serviceBusPrivateEndpointName string
param privateEndpointSubnetName string
param vNetName string
param sku string
param keyVaultName string
param myIpAddress string = ''

resource serviceBus 'Microsoft.ServiceBus/namespaces@2022-01-01-preview' = {
  name: name
  location: location
  tags: union(tags, { 'azd-service-name': name })
  sku: {
    name: sku
  }
  properties: {
    minimumTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
  }
}

resource serviceBusNetworkRuleIpAddress 'Microsoft.ServiceBus/namespaces/networkRules@2022-10-01-preview' = {
  name: '${serviceBus.name}-allow-ipaddress'
  parent: serviceBus
  properties: {
    defaultAction: 'Deny'
    publicNetworkAccess: 'Enabled'
    virtualNetworkRules: []
    ipRules: [
      {
        ipMask: myIpAddress //for local development
        action: 'Allow'
      }
    ]
  }
}

module privateEndpoint '../networking/private-endpoint.bicep' = {
  name: '${serviceBus.name}-privateEndpoint-deployment'
  params: {
    groupIds: [
      'namespace'
    ]
    dnsZoneName: serviceBusPrivateDnsZoneName
    name: serviceBusPrivateEndpointName
    subnetName: privateEndpointSubnetName
    privateLinkServiceId: serviceBus.id
    vNetName: vNetName
    location: location
  }
}

var endpoint = '${serviceBus.id}/AuthorizationRules/RootManageSharedAccessKey'
var serviceBusConnectionString = 'Endpoint=sb://${serviceBus.name}.servicebus.windows.net/;SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey=${listKeys(endpoint, serviceBus.apiVersion).primaryKey}'
module keyvaultSecretConnectionString '../keyvault/keyvault-secret.bicep' = {
  name: '${serviceBus.name}-connectionstring-deployment-keyvault'
  params: {
    keyVaultName: keyVaultName
    secretName: 'servicebus-connection-string'
    secretValue: serviceBusConnectionString
  }
}

output serviceBusNamespaceName string =  serviceBus.name
output serviceBusNamespaceFullQualifiedName string = '${serviceBus.name}.servicebus.windows.net'
