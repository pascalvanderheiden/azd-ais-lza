param name string
param location string = resourceGroup().location
param tags object = {}
param publisherEmail string = 'noreply@microsoft.com'
param publisherName string = 'n/a'
param sku string
param skuCount int
param applicationInsightsName string
param apimManagedIdentityName string
param deployApimDevPortal bool
//Vnet Integration
param apimSubnetId string
param virtualNetworkType string
param keyVaultName string

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: applicationInsightsName
}

resource managedIdentityApim 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: apimManagedIdentityName
}

resource keyvault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

//setting explicit public IP for APIM will force stV2 instance of APIM
resource apimPublicIp 'Microsoft.Network/publicIPAddresses@2023-04-01' existing = if(sku != 'StandardV2'){
  name: '${name}-pip'
}

resource apimService 'Microsoft.ApiManagement/service@2023-05-01-preview' = {
  name: name
  location: location
  tags: union(tags, { 'azd-service-name': name })
  sku: {
    name: sku
    capacity: (sku == 'Consumption') ? 0 : ((sku == 'Developer') ? 1 : skuCount)
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityApim.id}': {}
    }
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
    virtualNetworkType: virtualNetworkType
    publicIpAddressId: sku != 'StandardV2' ? apimPublicIp.id : null
    developerPortalStatus: deployApimDevPortal ? 'Enabled' : 'Disabled'
    virtualNetworkConfiguration: {
      subnetResourceId: apimSubnetId
    }
    // Custom properties are not supported for Consumption SKU
    customProperties: sku == 'Consumption' ? {} : {
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_RSA_WITH_AES_128_GCM_SHA256': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_RSA_WITH_AES_256_CBC_SHA256': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_RSA_WITH_AES_128_CBC_SHA256': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_RSA_WITH_AES_256_CBC_SHA': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_RSA_WITH_AES_128_CBC_SHA': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TripleDes168': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls10': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls11': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Ssl30': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls10': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls11': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Ssl30': 'false'
    }
  }
}

resource apiConsumerSubscription 'Microsoft.ApiManagement/service/subscriptions@2023-05-01-preview' = {
  parent: apimService
  name: 'consumer-subscription'
  properties: {
    scope: '/apis'
    displayName: 'Consumer'
    state: 'active'
    allowTracing: true
  }
}

resource apimLogger 'Microsoft.ApiManagement/service/loggers@2023-05-01-preview' = {
  name: 'appinsights-logger'
  parent: apimService
  properties: {
    credentials: {
      instrumentationKey: applicationInsights.properties.InstrumentationKey
    }
    description: 'Logger to Azure Application Insights'
    isBuffered: false
    loggerType: 'applicationInsights'
    resourceId: applicationInsights.id
  }
}

output apimName string = apimService.name
output apimLoggerName string = apimLogger.name
output apimProxyHostName string = apimService.properties.hostnameConfigurations[0].hostName
output apimDeveloperPortalHostName string = deployApimDevPortal ? replace(apimService.properties.developerPortalUrl, 'https://', '') : ''
