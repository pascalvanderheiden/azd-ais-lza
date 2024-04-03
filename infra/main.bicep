targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the environment that can be used as part of naming resource convention')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

@description('Deploy Front Door')
@metadata({
  azd: {
    type: 'boolean'
  }
})
param deployFrontDoor bool

@description('Deploy an App Service Environment v3')
@metadata({
  azd: {
    type: 'boolean'
  }
})
param deployAse bool

@description('Deploy Service Bus Namespace')
@metadata({
  azd: {
    type: 'boolean'
  }
})
param deployServiceBus bool

@description('Use Redis Cache for Azure API Management')
@metadata({
  azd: {
    type: 'boolean'
  }
})
param useRedisCacheForAPIM bool

@description('Azure API Management SKU.')
@allowed(['StandardV2', 'Developer', 'Premium'])
param apimSku string = 'StandardV2'

@description('Azure Storage SKU.')
@allowed(['Standard_LRS','Standard_GRS','Standard_RAGRS','Standard_ZRS','Premium_LRS','Premium_ZRS','Standard_GZRS','Standard_RAGZRS'])
param storageSku string = 'Standard_LRS'

//Leave blank to use default naming conventions
param apimIdentityName string = ''
param aseIdentityName string = ''
param apimServiceName string = ''
param logAnalyticsName string = ''
param applicationInsightsDashboardName string = ''
param applicationInsightsName string = ''
param vnetName string = ''
param apimSubnetName string = ''
param apimNsgName string = ''
param aseSubnetName string = ''
param aseNsgName string = ''
param privateEndpointSubnetName string = ''
param privateEndpointNsgName string = ''
param redisCacheServiceName string = ''
param myIpAddress string = ''
param myPrincipalId string = ''
param keyVaultName string = ''
param frontDoorName string = ''
param wafName string = ''
param appServiceEnvironmentName string = ''
param appServicePlanName string = ''
param serviceBusName string = ''
param storageAccountName string = ''
param fileShareName string = ''
param calcRestServiceName string = ''

// Tags that should be applied to all resources.
// 
// Note that 'azd-service-name' tags should be applied separately to service host resources.
// Example usage:
//   tags: union(tags, { 'azd-service-name': <service name in azure.yaml> })
var tags = { 'azd-env-name': environmentName }
var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))

var monitorPrivateDnsZoneName = 'privatelink.monitor.azure.com'
var redisCachePrivateDnsZoneName = 'privatelink.redis.cache.windows.net'
var keyvaultPrivateDnsZoneName = 'privatelink.vaultcore.azure.net'
var serviceBusPrivateDnsZoneName = 'privatelink.servicebus.windows.net'
var asePrivateDnsZoneName = 'privatelink.appserviceenvironment.net'
var storagePrivateDnsZoneName = 'privatelink.blob.${az.environment().suffixes.storage}'
var privateDnsZoneNames = [
  monitorPrivateDnsZoneName
  redisCachePrivateDnsZoneName
  keyvaultPrivateDnsZoneName
  serviceBusPrivateDnsZoneName
  storagePrivateDnsZoneName
  asePrivateDnsZoneName
]

resource rg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: 'rg-${environmentName}'
  location: location
  tags: tags
}

module dnsDeployment './modules/networking/dns.bicep' = [for privateDnsZoneName in privateDnsZoneNames: {
  name: 'dns-deployment-${privateDnsZoneName}'
  scope: rg
  params: {
    name: privateDnsZoneName
  }
}]

module managedIdentityApim './modules/security/managed-identity.bicep' = {
  name: 'managed-identity-apim'
  scope: rg
  params: {
    name: !empty(apimIdentityName) ? apimIdentityName : '${abbrs.managedIdentityUserAssignedIdentities}${resourceToken}-apim'
    location: location
    tags: tags
  }
}

module managedIdentityAse './modules/security/managed-identity.bicep' = if(deployAse){
  name: 'managed-identity-ase'
  scope: rg
  params: {
    name: !empty(aseIdentityName) ? aseIdentityName : '${abbrs.managedIdentityUserAssignedIdentities}${resourceToken}-ase'
    location: location
    tags: tags
  }
}

module storage './modules/storage/storage.bicep' = {
  name: 'storage'
  scope: rg
  params: {
    name: !empty(storageAccountName) ? storageAccountName : '${abbrs.storageStorageAccounts}${resourceToken}'
    location: location
    storageSku: storageSku 
    aseManagedIdentityName: deployAse ? managedIdentityAse.outputs.managedIdentityName : ''
    fileShareName: !empty(fileShareName) ? fileShareName : '${abbrs.webSitesAppServiceEnvironment}${resourceToken}-share'
    vNetName: vnet.outputs.vnetName
    privateEndpointSubnetName: vnet.outputs.privateEndpointSubnetName
    storagePrivateEndpointName: '${abbrs.storageStorageAccounts}${abbrs.privateEndpoints}${resourceToken}'
    storagePrivateDnsZoneName: storagePrivateDnsZoneName
    dnsResourceGroupName: rg.name
    vnetResourceGroupName: rg.name
  }
}

module redisCache './modules/cache/redis.bicep' = if(useRedisCacheForAPIM){
  name: 'redis-cache'
  scope: rg
  params: {
    name: !empty(redisCacheServiceName) ? redisCacheServiceName : '${abbrs.cacheRedis}${resourceToken}'
    location: location
    tags: tags
    sku: 'Basic'
    capacity: 1
    redisCachePrivateEndpointName: '${abbrs.cacheRedis}${abbrs.privateEndpoints}${resourceToken}'
    vNetName: vnet.outputs.vnetName
    privateEndpointSubnetName: vnet.outputs.privateEndpointSubnetName
    redisCacheDnsZoneName: redisCachePrivateDnsZoneName
    apimServiceName: apim.outputs.apimName
  }
}

module vnet './modules/networking/vnet.bicep' = {
  name: 'vnet'
  scope: rg
  params: {
    name: !empty(vnetName) ? vnetName : '${abbrs.networkVirtualNetworks}${resourceToken}'
    apimSubnetName: !empty(apimSubnetName) ? apimSubnetName : '${abbrs.networkVirtualNetworksSubnets}${abbrs.apiManagementService}${resourceToken}'
    apimNsgName: !empty(apimNsgName) ? apimNsgName : '${abbrs.networkNetworkSecurityGroups}${abbrs.apiManagementService}${resourceToken}'
    aseSubnetName: !empty(aseSubnetName) ? aseSubnetName : '${abbrs.networkVirtualNetworksSubnets}${abbrs.webSitesAppServiceEnvironment}${resourceToken}'
    aseNsgName: !empty(aseNsgName) ? aseNsgName : '${abbrs.networkNetworkSecurityGroups}${abbrs.webSitesAppServiceEnvironment}${resourceToken}'
    privateEndpointSubnetName: !empty(privateEndpointSubnetName) ? privateEndpointSubnetName : '${abbrs.networkVirtualNetworksSubnets}${abbrs.privateEndpoints}${resourceToken}'
    privateEndpointNsgName: !empty(privateEndpointNsgName) ? privateEndpointNsgName : '${abbrs.networkNetworkSecurityGroups}${abbrs.privateEndpoints}${resourceToken}'
    location: location
    tags: tags
    privateDnsZoneNames: privateDnsZoneNames
    apimSku: apimSku
    deployAse: deployAse
  }
  dependsOn: [
    dnsDeployment
  ]
}

module monitoring './modules/monitor/monitoring.bicep' = {
  name: 'monitoring'
  scope: rg
  params: {
    location: location
    tags: tags
    logAnalyticsName: !empty(logAnalyticsName) ? logAnalyticsName : '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
    applicationInsightsName: !empty(applicationInsightsName) ? applicationInsightsName : '${abbrs.insightsComponents}${resourceToken}'
    vNetName: vnet.outputs.vnetName
    privateEndpointSubnetName: vnet.outputs.privateEndpointSubnetName
    applicationInsightsDnsZoneName: monitorPrivateDnsZoneName
    applicationInsightsPrivateEndpointName: '${abbrs.insightsComponents}${abbrs.privateEndpoints}${resourceToken}'
    applicationInsightsDashboardName: !empty(applicationInsightsDashboardName) ? applicationInsightsDashboardName : '${abbrs.portalDashboards}${resourceToken}'
  }
}

var apimService = !empty(apimServiceName) ? apimServiceName : '${abbrs.apiManagementService}${resourceToken}'
module apimPip './modules/networking/publicip.bicep' = if(apimSku != 'StandardV2'){
  name: 'apim-pip'
  scope: rg
  params: {
    name: '${apimService}-pip'
    location: location
    tags: tags
    fqdn:'${apimService}.${location}.cloudapp.azure.com'
  }
}

module apim './modules/apim/apim.bicep' = {
  name: 'apim'
  scope: rg
  params: {
    name: apimService
    location: location
    tags: tags
    sku: apimSku
    virtualNetworkType: 'External'
    applicationInsightsName: monitoring.outputs.applicationInsightsName
    apimManagedIdentityName: managedIdentityApim.outputs.managedIdentityName
    apimSubnetId: vnet.outputs.apimSubnetId
  }
}

module calcRestApiService './modules/apim/openapi-link-api.bicep' = {
  name: 'calc-rest-api-service'
  scope: rg
  params: {
    name: !empty(calcRestServiceName) ? calcRestServiceName : 'calc-rest-${resourceToken}'
    path: 'calc'
    openApiSpecUrl: 'http://calcapi.cloudapp.net/calcapi.json'
    apimName: apim.outputs.apimName
    apimLoggerName: apim.outputs.apimLoggerName
  }
}

module keyvault './modules/keyvault/keyvault.bicep' = {
  name: 'keyvault'
  scope: rg
  params: {
    name: !empty(keyVaultName) ? keyVaultName : '${abbrs.keyVaultVaults}${resourceToken}'
    location: location
    apimManagedIdentityName: managedIdentityApim.outputs.managedIdentityName
    aseManagedIdentityName: deployAse ? managedIdentityAse.outputs.managedIdentityName : ''
    vNetName: vnet.outputs.vnetName
    privateEndpointSubnetName: vnet.outputs.privateEndpointSubnetName
    keyvaultPrivateEndpointName: '${abbrs.keyVaultVaults}${abbrs.privateEndpoints}${resourceToken}'
    keyvaultPrivateDnsZoneName: keyvaultPrivateDnsZoneName
    apimServiceName: apim.outputs.apimName
    myIpAddress: myIpAddress
    myPrincipalId: myPrincipalId
    dnsResourceGroupName: rg.name
    vnetResourceGroupName: rg.name
    apimResourceGroupName: rg.name
    logAnalyticsWorkspaceIdForDiagnostics : monitoring.outputs.logAnalyticsWorkspaceId
  }
}

module frontDoor './modules/networking/frontdoor_waf.bicep' = if(deployFrontDoor){
  name: 'frontdoor'
  scope: rg
  params: {
    name: !empty(frontDoorName) ? frontDoorName : '${abbrs.networkFrontDoors}${resourceToken}'
    wafName: !empty(wafName) ? wafName : '${abbrs.networkFrontdoorWebApplicationFirewallPolicies}${resourceToken}'
    apimGwUrl: apim.outputs.apimEndpoint
    apimName: apim.outputs.apimName
    logAnalyticsWorkspaceIdForDiagnostics : monitoring.outputs.logAnalyticsWorkspaceId
  }
}

module ase './modules/host/ase_asp.bicep' = if(deployAse){
  name: 'ase'
  scope: rg
  params: {
    name: !empty(appServiceEnvironmentName) ? appServiceEnvironmentName : '${abbrs.webSitesAppServiceEnvironment}${resourceToken}'
    aspName: !empty(appServicePlanName) ? appServicePlanName : '${abbrs.webServerFarms}${resourceToken}'
    location: location
    virtualNetworkId: vnet.outputs.aseSubnetId
    subnetName: vnet.outputs.aseSubnetName
    aseManagedIdentityName: managedIdentityAse.outputs.managedIdentityName
  }
}

module serviceBus './modules/servicebus/servicebus.bicep' = if(deployServiceBus){
  name: 'servicebus'
  scope: rg
  params: {
    name: !empty(serviceBusName) ? serviceBusName : '${abbrs.serviceBusNamespaces}${resourceToken}'
    location: location
    serviceBusPrivateDnsZoneName : serviceBusPrivateDnsZoneName
    serviceBusPrivateEndpointName : '${abbrs.serviceBusNamespaces}${abbrs.privateEndpoints}${resourceToken}'
    privateEndpointSubnetName : vnet.outputs.privateEndpointSubnetName
    vNetName : vnet.outputs.vnetName
    aseManagedIdentityName : deployAse ? managedIdentityAse.outputs.managedIdentityName : ''
    dnsResourceGroupName : rg.name
    vnetResourceGroupName : rg.name
  }
}

output TENANT_ID string = subscription().tenantId
output DEPLOYMENT_LOCATION string = location
output APIM_NAME string = apim.outputs.apimName
output RESOURCE_TOKEN string = resourceToken
output APPLICATIONINSIGHTS_CONNECTION_STRING string = monitoring.outputs.applicationInsightsConnectionString
output DEPLOY_FRONTDOOR bool = deployFrontDoor
output DEPLOY_ASE bool = deployAse
output DEPLOY_SERVICEBUS bool = deployServiceBus
output DEPLOY_REDIS bool = useRedisCacheForAPIM
output AZURE_FD_URL string =  deployFrontDoor ? 'https://${frontDoor.outputs.frontDoorUrl}' : ''
output AZURE_TENANT_ID string = subscription().tenantId

