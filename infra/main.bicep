targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the environment that can be used as part of naming resource convention')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

@description('Deploy API Management Developer Portal')
@metadata({
  azd: {
    type: 'boolean'
  }
})
param deployApimDevPortal bool

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

@description('Front Door SKU.')
@allowed([
  'Standard_AzureFrontDoor'
  'Premium_AzureFrontDoor'
])
param frontDoorSku string = 'Premium_AzureFrontDoor'

@description('Azure API Management SKU.')
@allowed(['StandardV2', 'Developer', 'Premium'])
param apimSku string = 'StandardV2'
param apimSkuCount int = 1

@description('Azure Storage SKU.')
@allowed(['Standard_LRS','Standard_GRS','Standard_RAGRS','Standard_ZRS','Premium_LRS','Premium_ZRS','Standard_GZRS','Standard_RAGZRS'])
param storageSku string = 'Standard_LRS'

@description('Service Bus SKU.')
@allowed(['Basic', 'Standard', 'Premium'])
param serviceBusSku string = 'Premium'

@allowed([
  'Detection'
  'Prevention'
])
@description('The mode that the WAF should be deployed using. In \'Prevention\' mode, the WAF will block requests it detects as malicious. In \'Detection\' mode, the WAF will not block requests and will simply log the request.')
param wafMode string = 'Prevention'

@description('The list of managed rule sets to configure on the WAF.')
param wafManagedRuleSets array = [
  {
    ruleSetType: 'Microsoft_DefaultRuleSet'
    ruleSetVersion: '1.1'
  }
  {
    ruleSetType: 'Microsoft_BotManagerRuleSet'
    ruleSetVersion: '1.0'
  }
]

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
param laSubnetName string = ''
param laNsgName string = ''
param privateEndpointSubnetName string = ''
param privateEndpointNsgName string = ''
param myIpAddress string = ''
param myPrincipalId string = ''
param keyVaultName string = ''
param frontDoorName string = ''
param wafName string = ''
param frontDoorProxyEndpointName string = ''
param frontDoorDeveloperPortalEndpointName string = ''
param appServiceEnvironmentName string = ''
param appServicePlanName string = ''
param serviceBusName string = ''
param storageAccountName string = ''
param calcRestServiceName string = ''

// Tags that should be applied to all resources.
var tags = { 'azd-env-name': environmentName }

var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var apimFrontDoorIdNamedValueName = 'frontDoorId'
var monitorPrivateDnsZoneName = 'privatelink.monitor.azure.com'
var keyvaultPrivateDnsZoneName = 'privatelink.vaultcore.azure.net'
var serviceBusPrivateDnsZoneName = 'privatelink.servicebus.windows.net'
var storageAccountBlobPrivateDnsZoneName = 'privatelink.blob.${az.environment().suffixes.storage}'
var storageAccountQueuePrivateDnsZoneName = 'privatelink.queue.${az.environment().suffixes.storage}'
var storageAccountTablePrivateDnsZoneName = 'privatelink.table.${az.environment().suffixes.storage}'
var storageAccountFilePrivateDnsZoneName = 'privatelink.file.${az.environment().suffixes.storage}'
var privateDnsZoneNames = [
  monitorPrivateDnsZoneName
  keyvaultPrivateDnsZoneName
  serviceBusPrivateDnsZoneName
  storageAccountBlobPrivateDnsZoneName
  storageAccountQueuePrivateDnsZoneName
  storageAccountTablePrivateDnsZoneName
  storageAccountFilePrivateDnsZoneName
]

resource rg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: 'rg-${environmentName}'
  location: location
  tags: tags
}

module dnsDeployment './core/networking/dns.bicep' = [for privateDnsZoneName in privateDnsZoneNames: {
  name: 'dns-deployment-${privateDnsZoneName}'
  scope: rg
  params: {
    name: privateDnsZoneName
    tags: tags
  }
}]

module managedIdentityApim './core/security/managed-identity.bicep' = {
  name: 'managed-identity-apim'
  scope: rg
  params: {
    name: !empty(apimIdentityName) ? apimIdentityName : '${abbrs.managedIdentityUserAssignedIdentities}${resourceToken}-apim'
    location: location
    tags: tags
  }
}

module managedIdentityAse './core/security/managed-identity.bicep' = if(deployAse){
  name: 'managed-identity-ase'
  scope: rg
  params: {
    name: !empty(aseIdentityName) ? aseIdentityName : '${abbrs.managedIdentityUserAssignedIdentities}${resourceToken}-ase'
    location: location
    tags: tags
  }
}

module managedIdentityFrontDoor './core/security/managed-identity.bicep' = if(deployFrontDoor){
  name: 'managed-identity-front-door'
  scope: rg
  params: {
    name: !empty(aseIdentityName) ? aseIdentityName : '${abbrs.managedIdentityUserAssignedIdentities}${resourceToken}-fd'
    location: location
    tags: tags
  }
}

module storage './core/storage/storage.bicep' = {
  name: 'storage'
  scope: rg
  params: {
    name: !empty(storageAccountName) ? storageAccountName : '${abbrs.storageStorageAccounts}${resourceToken}'
    location: location
    tags: tags
    storageSku: storageSku 
    aseManagedIdentityName: deployAse ? managedIdentityAse.outputs.managedIdentityName : ''
    myIpAddress: myIpAddress
    myPrincipalId: myPrincipalId
    vNetName: vnet.outputs.vnetName
    privateEndpointSubnetName: vnet.outputs.privateEndpointSubnetName
    blobPrivateDnsZoneName: storageAccountBlobPrivateDnsZoneName
    blobPrivateEndpointName: '${abbrs.storageStorageAccounts}${abbrs.privateEndpoints}${resourceToken}-blob'
    tablePrivateDnsZoneName: storageAccountTablePrivateDnsZoneName
    tablePrivateEndpointName: '${abbrs.storageStorageAccounts}${abbrs.privateEndpoints}${resourceToken}-table'
    filePrivateDnsZoneName: storageAccountFilePrivateDnsZoneName
    filePrivateEndpointName: '${abbrs.storageStorageAccounts}${abbrs.privateEndpoints}${resourceToken}-file'
    queuePrivateDnsZoneName: storageAccountQueuePrivateDnsZoneName
    queuePrivateEndpointName: '${abbrs.storageStorageAccounts}${abbrs.privateEndpoints}${resourceToken}-queue'
    keyVaultName: keyvault.outputs.keyvaultName
  }
}

module vnet './core/networking/vnet.bicep' = {
  name: 'vnet'
  scope: rg
  params: {
    name: !empty(vnetName) ? vnetName : '${abbrs.networkVirtualNetworks}${resourceToken}'
    apimSubnetName: !empty(apimSubnetName) ? apimSubnetName : '${abbrs.networkVirtualNetworksSubnets}${abbrs.apiManagementService}${resourceToken}'
    apimNsgName: !empty(apimNsgName) ? apimNsgName : '${abbrs.networkNetworkSecurityGroups}${abbrs.apiManagementService}${resourceToken}'
    aseSubnetName: !empty(aseSubnetName) ? aseSubnetName : '${abbrs.networkVirtualNetworksSubnets}${abbrs.webSitesAppServiceEnvironment}${resourceToken}'
    aseNsgName: !empty(aseNsgName) ? aseNsgName : '${abbrs.networkNetworkSecurityGroups}${abbrs.webSitesAppServiceEnvironment}${resourceToken}'
    laSubnetName: !empty(laSubnetName) ? laSubnetName : '${abbrs.networkVirtualNetworksSubnets}la-${resourceToken}'
    laNsgName: !empty(laNsgName) ? laNsgName : '${abbrs.networkNetworkSecurityGroups}la-${resourceToken}'
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

module monitoring './core/monitor/monitoring.bicep' = {
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
module apimPip './core/networking/publicip.bicep' = if(apimSku != 'StandardV2'){
  name: 'apim-pip'
  scope: rg
  params: {
    name: '${apimService}-pip'
    location: location
    tags: tags
    fqdn:'${apimService}.${location}.cloudapp.azure.com'
  }
}

module apim './core/apim/apim.bicep' = {
  name: 'apim'
  scope: rg
  params: {
    name: apimService
    location: location
    tags: tags
    sku: apimSku
    skuCount: apimSkuCount
    virtualNetworkType: 'External'
    applicationInsightsName: monitoring.outputs.applicationInsightsName
    apimManagedIdentityName: managedIdentityApim.outputs.managedIdentityName
    apimSubnetId: vnet.outputs.apimSubnetId
    deployApimDevPortal: deployApimDevPortal
    keyVaultName: keyvault.outputs.keyvaultName
  }
}

module calcRestApiService './core/apim/openapi-link-api.bicep' = {
  name: 'calc-rest-api-service'
  scope: rg
  params: {
    name: !empty(calcRestServiceName) ? calcRestServiceName : 'calc-rest-${resourceToken}'
    displayName: 'Calculator API'
    path: 'calc'
    openApiSpecUrl: 'http://calcapi.cloudapp.net/calcapi.json'
    apimName: apim.outputs.apimName
    apimLoggerName: apim.outputs.apimLoggerName
  }
}

module keyvault './core/keyvault/keyvault.bicep' = {
  name: 'keyvault'
  scope: rg
  params: {
    name: !empty(keyVaultName) ? keyVaultName : '${abbrs.keyVaultVaults}${resourceToken}'
    location: location
    tags: tags
    apimManagedIdentityName: managedIdentityApim.outputs.managedIdentityName
    aseManagedIdentityName: deployAse ? managedIdentityAse.outputs.managedIdentityName : ''
    vNetName: vnet.outputs.vnetName
    privateEndpointSubnetName: vnet.outputs.privateEndpointSubnetName
    keyvaultPrivateEndpointName: '${abbrs.keyVaultVaults}${abbrs.privateEndpoints}${resourceToken}'
    keyvaultPrivateDnsZoneName: keyvaultPrivateDnsZoneName
    myPrincipalId: myPrincipalId
    myIpAddress: myIpAddress
    logAnalyticsWorkspaceIdForDiagnostics : monitoring.outputs.logAnalyticsWorkspaceId
  }
}

module frontDoor './core/networking/front-door.bicep' = if(deployFrontDoor){
  name: 'front-door'
  scope: rg
  params: {
    name: !empty(frontDoorName) ? frontDoorName : '${abbrs.networkFrontDoors}${resourceToken}'
    wafName: !empty(wafName) ? wafName : 'waf${resourceToken}'
    tags: tags
    sku: frontDoorSku
    proxyEndpointName: !empty(frontDoorProxyEndpointName) ? frontDoorProxyEndpointName : 'afd-proxy-${abbrs.networkFrontDoors}${resourceToken}'
    developerPortalEndpointName: !empty(frontDoorDeveloperPortalEndpointName) ? frontDoorDeveloperPortalEndpointName : 'afd-portal-${abbrs.networkFrontDoors}${resourceToken}'
    proxyOriginHostName: deployFrontDoor ? apim.outputs.apimProxyHostName : ''
    developerPortalOriginHostName: deployApimDevPortal ? apim.outputs.apimDeveloperPortalHostName : ''
    apimName: deployFrontDoor ? apim.outputs.apimName : ''
    wafMode: wafMode
    wafManagedRuleSets: wafManagedRuleSets
    apimFrontDoorIdNamedValueName: apimFrontDoorIdNamedValueName
    logAnalyticsWorkspaceIdForDiagnostics : deployFrontDoor ? monitoring.outputs.logAnalyticsWorkspaceId : ''
    fdManagedIdentityName: deployFrontDoor ? managedIdentityFrontDoor.outputs.managedIdentityName : ''
  }
}

module ase './core/host/ase.bicep' = if(deployAse){
  name: 'ase'
  scope: rg
  params: {
    name: !empty(appServiceEnvironmentName) ? appServiceEnvironmentName : '${abbrs.webSitesAppServiceEnvironment}${resourceToken}'
    location: location
    tags: tags
    virtualNetworkId: deployAse ? vnet.outputs.aseSubnetId : ''
    subnetName: deployAse ? vnet.outputs.aseSubnetName : ''
    aseManagedIdentityName: deployAse ? managedIdentityAse.outputs.managedIdentityName : ''
  }
}

module asp './core/host/asp.bicep' = {
  name: 'asp'
  scope: rg
  params: {
    name: !empty(appServicePlanName) ? appServicePlanName : '${abbrs.webServerFarms}${resourceToken}'
    aseName: deployAse ? ase.outputs.aseName : ''
    tags: tags
    location: location
    deployAse: deployAse
    skuName: deployAse ? 'I1v2' : 'WS1'
    skuCount: 1
  }
}

module serviceBus './core/servicebus/servicebus.bicep' = if(deployServiceBus){
  name: 'servicebus'
  scope: rg
  params: {
    name: !empty(serviceBusName) ? serviceBusName : '${abbrs.serviceBusNamespaces}${resourceToken}'
    location: location
    tags: tags
    sku: serviceBusSku
    serviceBusPrivateDnsZoneName : serviceBusPrivateDnsZoneName
    serviceBusPrivateEndpointName : '${abbrs.serviceBusNamespaces}${abbrs.privateEndpoints}${resourceToken}'
    privateEndpointSubnetName : deployServiceBus ? vnet.outputs.privateEndpointSubnetName : ''
    vNetName : deployServiceBus ? vnet.outputs.vnetName : ''
    keyVaultName: deployServiceBus ? keyvault.outputs.keyvaultName : ''
    myIpAddress: myIpAddress
  }
}

output RESOURCE_TOKEN string = resourceToken
output AZURE_TENANT_ID string = subscription().tenantId
output AZURE_LOCATION string = location
output AZURE_SUBSCRIPTION_ID string = subscription().subscriptionId
output APIM_NAME string = apim.outputs.apimName
output FRONTDOOR_NAME string = deployFrontDoor ? frontDoor.outputs.frontDoorName : ''
output FRONTDOOR_GATEWAY_ENDPOINT_NAME string = deployFrontDoor ? frontDoor.outputs.frontDoorProxyEndpointHostName : ''
output FRONTDOOR_PORTAL_ENDPOINT_NAME string = deployFrontDoor ? frontDoor.outputs.frontDoorDeveloperPortalEndpointHostName : ''
output ASE_NAME string = deployAse ? ase.outputs.aseName : ''
output ASP_NAME string = asp.outputs.appServicePlanName
output SERVICEBUS_NAME string = deployServiceBus ? serviceBus.outputs.serviceBusNamespaceName : ''
output STORAGE_ACCOUNT_NAME string = storage.outputs.storageName
output KEYVAULT_NAME string = keyvault.outputs.keyvaultName
output RESOURCE_GROUP_NAME string = rg.name
output VNET_NAME string = vnet.outputs.vnetName
output VNET_PE_SUBNET_NAME string = vnet.outputs.privateEndpointSubnetName
output VNET_LA_SUBNET_NAME string = vnet.outputs.laSubnetName
output DEPLOY_FRONTDOOR bool = deployFrontDoor
output DEPLOY_ASE bool = deployAse
output DEPLOY_SERVICEBUS bool = deployServiceBus
output DEPLOY_APIM_DEV_PORTAL bool = deployApimDevPortal
output APPINSIGHTS_NAME string = monitoring.outputs.applicationInsightsName
