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

@description('Rate limit threshold value for rate limit custom rule.')
param rateLimitThreshold int = 100

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

resource profile 'Microsoft.Cdn/profiles@2023-05-01' = {
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

resource proxyEndpoint 'Microsoft.Cdn/profiles/afdEndpoints@2023-05-01' = {
  name: proxyEndpointName
  parent: profile
  location: 'global'
  tags: union(tags, { 'azd-service-name': name })
  properties: {
    enabledState: 'Enabled'
  }
}

resource proxyOriginGroup 'Microsoft.Cdn/profiles/originGroups@2023-05-01' = {
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

resource proxyOrigin 'Microsoft.Cdn/profiles/originGroups/origins@2023-05-01' = {
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

resource proxyRoute 'Microsoft.Cdn/profiles/afdEndpoints/routes@2023-05-01' = {
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

resource developerPortalEndpoint 'Microsoft.Cdn/profiles/afdEndpoints@2023-05-01' = {
  name: developerPortalEndpointName
  parent: profile
  location: 'global'
  properties: {
    enabledState: 'Enabled'
  }
}

resource developerPortalOriginGroup 'Microsoft.Cdn/profiles/originGroups@2023-05-01' = {
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

resource developerPortalOrigin 'Microsoft.Cdn/profiles/originGroups/origins@2023-05-01' = if(developerPortalOriginHostName != ''){
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

resource developerPortalRoute 'Microsoft.Cdn/profiles/afdEndpoints/routes@2023-05-01' = if(developerPortalOriginHostName != ''){
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

// Define enhanced WAF variables for DDoS protection
var frontDoorSkuName = sku
// Use the provided managed rule sets directly (now includes Bot Manager v1.1)
var enhancedManagedRuleSets = wafManagedRuleSets

// Custom rate limiting rule for DDoS protection
var customRateLimitRule = {
  action: 'Block'
  enabledState: 'Enabled'
  matchConditions: [
    {
      matchValue: [
        '0.0.0.0/0'
      ]
      matchVariable: 'SocketAddr'
      negateCondition: false
      operator: 'IPMatch'
      transforms: []
    }
  ]
  name: 'GlobalRateLimitRule'
  priority: 100
  rateLimitDurationInMinutes: 5
  rateLimitThreshold: rateLimitThreshold
  ruleType: 'RateLimitRule'
}

resource wafPolicy 'Microsoft.Network/FrontDoorWebApplicationFirewallPolicies@2024-02-01' = {
  name: wafName
  location: 'global'
  sku: {
    name: frontDoorSkuName
  }
  properties: {
    managedRules: {
      managedRuleSets: enhancedManagedRuleSets
    }
    customRules: {
      rules: [
        customRateLimitRule
      ]
    }
    policySettings: {
      enabledState: 'Enabled'
      mode: wafMode
      requestBodyCheck: 'Enabled'
      customBlockResponseBody: null
      customBlockResponseStatusCode: 403
      redirectUrl: null
      javascriptChallengeExpirationInMinutes: 30
      logScrubbing: null
    }
  }
}

resource securityPolicy 'Microsoft.Cdn/profiles/securityPolicies@2023-05-01' = {
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

resource fdIdApimNamedValue 'Microsoft.ApiManagement/service/namedValues@2023-03-01-preview' = {
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
    value: loadTextContent('../apim/policies/global-policy.xml')
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
output frontDoorWafId string = wafPolicy.id
