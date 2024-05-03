param name string
param location string = resourceGroup().location
param tags object = {}
param serviceBusPrivateDnsZoneName string
param serviceBusPrivateEndpointName string
param privateEndpointSubnetName string
param vNetName string
param aseManagedIdentityName string
param sku string

resource aseManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = if (aseManagedIdentityName != ''){
  name: aseManagedIdentityName
}

resource serviceBus 'Microsoft.ServiceBus/namespaces@2022-01-01-preview' = {
  name: name
  location: location
  tags: union(tags, { 'azd-service-name': name })
  sku: {
    name: sku
  }
  properties: {
    minimumTlsVersion: '1.2'
    publicNetworkAccess: 'Disabled'
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

module sbReceiverRoleAssignment '../roleassignments/roleassignment.bicep' = if (aseManagedIdentityName != ''){
  name: 'sb-ase-receiver-roleAssignment'
  params: {
    principalId: (aseManagedIdentityName != '') ? aseManagedIdentity.properties.principalId : ''
    roleName: 'Service Bus Data Receiver'
    targetResourceId: (aseManagedIdentityName != '') ? serviceBus.id : ''
    deploymentName: 'sb-ase-roleAssignment-DataReceiver'
  }
}

module sbSenderRoleAssignment '../roleassignments/roleassignment.bicep' = if (aseManagedIdentityName != ''){
  name: 'sb-ase-sender-roleAssignment'
  params: {
    principalId: (aseManagedIdentityName != '') ? aseManagedIdentity.properties.principalId : ''
    roleName: 'Service Bus Data Sender'
    targetResourceId: (aseManagedIdentityName != '') ? serviceBus.id : ''
    deploymentName: 'sb-ase-roleAssignment-DataSender'
  }
}

output serviceBusNamespaceName string =  serviceBus.name
output serviceBusNamespaceFullQualifiedName string = '${serviceBus.name}.servicebus.windows.net'
