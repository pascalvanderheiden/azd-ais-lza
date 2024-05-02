param name string
param wafName string
param apimName string
param apimFrontDoorIdNamedValueName string
param proxyOriginHostName string
param developerPortalOriginHostName string
param proxyEndpointName string
param developerPortalEndpointName string
param sku string
param logAnalyticsWorkspaceIdForDiagnostics string
param wafMode string
param wafManagedRuleSets array
param fdManagedIdentityName string
param tags object = {}

var proxyOriginGroupName = 'Proxy'
var developerPortalOriginGroupName = 'DeveloperPortal'
var proxyOriginName = 'ApiManagementProxy'
var developerPortalOriginName = 'ApiManagementDeveloperPortal'
var proxyRouteName = 'ProxyRoute'
var developerPortalRouteName = 'DeveloperPortalRoute'
var securityPolicyName = 'SecurityPolicy'

resource apimService 'Microsoft.ApiManagement/service@2023-03-01-preview' existing = {
  name: apimName
}

resource managedIdentityFrontdoor 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: fdManagedIdentityName
}

resource profile 'Microsoft.Cdn/profiles@2021-06-01' = {
  name: name
  location: 'global'
  tags: union(tags, { 'azd-service-name': name })
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityFrontdoor.id}': {}
    }
  }
  sku: {
    name: sku
  }
}

resource proxyEndpoint 'Microsoft.Cdn/profiles/afdEndpoints@2021-06-01' = {
  name: proxyEndpointName
  parent: profile
  location: 'global'
  tags: union(tags, { 'azd-service-name': name })
  properties: {
    enabledState: 'Enabled'
  }
}

resource proxyOriginGroup 'Microsoft.Cdn/profiles/originGroups@2021-06-01' = {
  name: proxyOriginGroupName
  parent: profile
  properties: {
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
    }
    healthProbeSettings: {
      probePath: '/status-0123456789abcdef'
      probeRequestType: 'GET'
      probeProtocol: 'Https'
      probeIntervalInSeconds: 30
    }
  }
}

resource proxyOrigin 'Microsoft.Cdn/profiles/originGroups/origins@2021-06-01' = {
  name: proxyOriginName
  parent: proxyOriginGroup
  properties: {
    hostName: proxyOriginHostName
    httpPort: 80
    httpsPort: 443
    originHostHeader: proxyOriginHostName
    priority: 1
    weight: 1000
  }
}

resource proxyRoute 'Microsoft.Cdn/profiles/afdEndpoints/routes@2021-06-01' = {
  name: proxyRouteName
  parent: proxyEndpoint
  dependsOn: [
    proxyOrigin // This explicit dependency is required to ensure that the origin group is not empty when the route is created.
  ]
  properties: {
    originGroup: {
      id: proxyOriginGroup.id
    }
    supportedProtocols: [
      'Http'
      'Https'
    ]
    patternsToMatch: [
      '/*'
    ]
    forwardingProtocol: 'HttpsOnly'
    linkToDefaultDomain: 'Enabled'
    httpsRedirect: 'Enabled'
  }
}

resource developerPortalEndpoint 'Microsoft.Cdn/profiles/afdEndpoints@2021-06-01' = {
  name: developerPortalEndpointName
  parent: profile
  location: 'global'
  properties: {
    enabledState: 'Enabled'
  }
}

resource developerPortalOriginGroup 'Microsoft.Cdn/profiles/originGroups@2021-06-01' = {
  name: developerPortalOriginGroupName
  parent: profile
  properties: {
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
    }
    healthProbeSettings: {
      probePath: '/status-0123456789abcdef'
      probeRequestType: 'GET'
      probeProtocol: 'Https'
      probeIntervalInSeconds: 30
    }
  }
}

resource developerPortalOrigin 'Microsoft.Cdn/profiles/originGroups/origins@2021-06-01' = if(developerPortalOriginHostName != ''){
  name: developerPortalOriginName
  parent: developerPortalOriginGroup
  properties: {
    hostName: developerPortalOriginHostName
    httpPort: 80
    httpsPort: 443
    originHostHeader: developerPortalOriginHostName
    priority: 1
    weight: 1000
  }
}

resource developerPortalRoute 'Microsoft.Cdn/profiles/afdEndpoints/routes@2021-06-01' = if(developerPortalOriginHostName != ''){
  name: developerPortalRouteName
  parent: developerPortalEndpoint
  dependsOn: [
    developerPortalOrigin // This explicit dependency is required to ensure that the origin group is not empty when the route is created.
  ]
  properties: {
    originGroup: {
      id: developerPortalOriginGroup.id
    }
    supportedProtocols: [
      'Http'
      'Https'
    ]
    patternsToMatch: [
      '/*'
    ]
    forwardingProtocol: 'HttpsOnly'
    linkToDefaultDomain: 'Enabled'
    httpsRedirect: 'Enabled'
  }
}

resource wafPolicy 'Microsoft.Network/FrontDoorWebApplicationFirewallPolicies@2020-11-01' = {
  name: wafName
  location: 'global'
  sku: {
    name: sku
  }
  properties: {
    policySettings: {
      enabledState: 'Enabled'
      mode: wafMode
    }
    managedRules: {
      managedRuleSets: wafManagedRuleSets
    }
  }
}

resource securityPolicy 'Microsoft.Cdn/profiles/securityPolicies@2021-06-01' = {
  parent: profile
  name: securityPolicyName
  properties: {
    parameters: {
      type: 'WebApplicationFirewall'
      wafPolicy: {
        id: wafPolicy.id
      }
      associations: [
        {
          domains: [
            {
              id: proxyEndpoint.id
            }
          ]
          patternsToMatch: [
            '/*'
          ]
        }
      ]
    }
  }
}

resource fdIdApimNamedValue 'Microsoft.ApiManagement/service/namedValues@2021-08-01' = {
  name: apimFrontDoorIdNamedValueName
  parent: apimService
  properties: {
    displayName: apimFrontDoorIdNamedValueName
    secret: true
    value: profile.properties.frontDoorId
  }
}

resource globalPolicies 'Microsoft.ApiManagement/service/policies@2023-03-01-preview' = {
  name: 'policy'
  parent: apimService
  properties: {
    value: loadTextContent('../apim/policies/global_policy.xml')
    format: 'rawxml'
  }
  dependsOn: [
    fdIdApimNamedValue
  ]
}

resource logAnalyticsWorkspaceDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diagnosticSettings'
  scope: profile
  properties: {
    workspaceId: logAnalyticsWorkspaceIdForDiagnostics
    logs: [
      {
        category: 'FrontDoorWebApplicationFirewallLog'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: true
        }
      }
    ]
  }
}

output frontDoorId string = profile.properties.frontDoorId
output frontDoorName string = profile.name
output frontDoorProxyEndpointHostName string = proxyEndpoint.properties.hostName
output frontDoorDeveloperPortalEndpointHostName string = developerPortalOriginHostName != '' ? developerPortalEndpoint.properties.hostName : ''
