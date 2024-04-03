param name string
param wafName string
param apimGwUrl string
param apimName string
param logAnalyticsWorkspaceIdForDiagnostics string
param tags object = {}

var frontDoorEnabledState = true
var healthProbe1EnabledState = true
var frontDoorWafEnabledState = true
var frontDoorWafMode = 'Detection'
var nameLower = toLower(name)

var backendPool1Name = '${nameLower}-apimBackendPool1'
var healthProbe1Name = '${nameLower}-apimHealthProbe1'
var frontendEndpoint1Name = '${nameLower}-apimFrontendEndpoint1'
var loadBalancing1Name = '${nameLower}-apimLoadBalancing1'
var routingRule1Name = '${nameLower}-apimRoutingRule1'

var frontendEndpoint1hostName = '${nameLower}.azurefd.net'
var backendPool1TargetUrl = apimGwUrl
var frontDoorIdNamedValue = 'frontDoorId'

resource apimService 'Microsoft.ApiManagement/service@2023-03-01-preview' existing = {
  name: apimName
}

resource resAzFd 'Microsoft.Network/frontdoors@2020-01-01' = {
  name: nameLower
  location: 'Global'
  tags: union(tags, { 'azd-service-name': name })
  properties: {
    enabledState: frontDoorEnabledState ? 'Enabled' : 'Disabled'
    friendlyName: nameLower
    frontendEndpoints: [
      {
        name: frontendEndpoint1Name
        properties: {
          hostName: frontendEndpoint1hostName
          sessionAffinityEnabledState: 'Disabled'
          sessionAffinityTtlSeconds: 0
          webApplicationFirewallPolicyLink: {
            id: '${resAzFdWaf.id}'
          }
        }
      }
    ]
    backendPoolsSettings: {
      enforceCertificateNameCheck: 'Enabled'
      sendRecvTimeoutSeconds: 30
    }
    backendPools: [
      {
        name: backendPool1Name
        properties: {
          backends: [
            {
              address: backendPool1TargetUrl
              backendHostHeader: backendPool1TargetUrl
              enabledState: 'Enabled'
              httpPort: 80
              httpsPort: 443
              priority: 1
              weight: 50
            }
          ]
          healthProbeSettings: {
            id: resourceId('Microsoft.Network/frontDoors/healthProbeSettings', nameLower, healthProbe1Name)
          }
          loadBalancingSettings: {
            id: resourceId('Microsoft.Network/frontDoors/loadBalancingSettings', nameLower, loadBalancing1Name)
          }
        }
      }
    ]
    healthProbeSettings: [
      {
        name: healthProbe1Name
        properties: {
            path: '/status-0123456789abcdef'
            protocol: 'Https'
            intervalInSeconds: 30
            enabledState: healthProbe1EnabledState ? 'Enabled' : 'Disabled'
            healthProbeMethod: 'GET'
        }
      }
    ]
    loadBalancingSettings: [
      {
        name: loadBalancing1Name
        properties: {
          sampleSize: 4
          successfulSamplesRequired: 2
        }
      }
    ]
    routingRules: [
      {
        name: routingRule1Name
        properties: {
          frontendEndpoints: [
            {
              id: resourceId('Microsoft.Network/frontDoors/FrontendEndpoints', nameLower, frontendEndpoint1Name)
            }
          ]
          acceptedProtocols: [
            'Https'
          ]
          patternsToMatch: [
            '/*'
          ]
          enabledState: 'Enabled'
          routeConfiguration: {
            '@odata.type': '#Microsoft.Azure.FrontDoor.Models.FrontdoorForwardingConfiguration'
            forwardingProtocol: 'HttpsOnly'
            backendPool: {
              id: resourceId('Microsoft.Network/frontDoors/BackendPools', nameLower, backendPool1Name)
            }
          }
        }
      }
    ]
  }
}

resource resAzFdWaf 'Microsoft.Network/FrontDoorWebApplicationFirewallPolicies@2019-10-01' = {
  name: wafName
  location: 'Global'
  properties: {
    policySettings: {
      enabledState: frontDoorWafEnabledState ? 'Enabled' : 'Disabled'
      mode: frontDoorWafMode
      customBlockResponseStatusCode: 403
    }
    customRules: {
      rules: [
        {
          name: 'blockQsExample'
          enabledState: 'Enabled'
          priority: 4
          ruleType: 'MatchRule'
          rateLimitDurationInMinutes: 1
          rateLimitThreshold: 100
          matchConditions: [
              {
                  matchVariable: 'QueryString'
                  operator: 'Contains'
                  negateCondition: false
                  matchValue: [
                      'blockme'
                  ]
                  transforms: []
              }
          ]
          action: 'Block'
        }
      ]
    }
    managedRules: {
      managedRuleSets: [
        {
          ruleSetType: 'DefaultRuleSet'
          ruleSetVersion: '1.0'
        }
        {
          ruleSetType: 'BotProtection'
          ruleSetVersion: 'preview-0.1'
        }
      ]
    }
  }
}

resource fdIdApimNamedValue 'Microsoft.ApiManagement/service/namedValues@2021-08-01' = {
  name: frontDoorIdNamedValue
  parent: apimService
  properties: {
    displayName: frontDoorIdNamedValue
    secret: true
    value: resAzFd.properties.frontdoorId
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
  scope: resAzFd
  properties: {
    workspaceId: logAnalyticsWorkspaceIdForDiagnostics
    logs: [
      {
        category: 'FrontDoorWebApplicationFirewallLog'
        enabled: true
      }
    ]
  }
}

output frontDoorName string = resAzFd.name
output frontDoorWafName string = resAzFdWaf.name
output frontDoorUrl string = resAzFd.properties.frontendEndpoints[0].properties.hostName
