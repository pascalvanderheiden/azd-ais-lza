param name string
param displayName string
param apimName string
param apimLoggerName string
param openApiSpecUrl string
param path string

@description('The number of bytes of the request/response body to record for diagnostic purposes')
param logBytes int = 8192

var logSettings = {
  headers: [ 'Content-type', 'User-agent' ]
  body: { bytes: logBytes }
}

resource apimService 'Microsoft.ApiManagement/service@2022-08-01' existing = {
  name: apimName
}

resource apimLogger 'Microsoft.ApiManagement/service/loggers@2022-08-01' existing = if (!empty(apimLoggerName)) {
  name: apimLoggerName
  parent: apimService
}

resource restApi 'Microsoft.ApiManagement/service/apis@2022-08-01' = {
  name: name
  parent: apimService
  properties: {
    displayName: displayName
    path: path
    protocols: [ 'https' ]
    subscriptionRequired: true
    subscriptionKeyParameterNames: {
      header: 'api-key'
    }
    type: 'http'
    format: 'openapi-link'
    value: openApiSpecUrl
  }
}

resource apiPolicies 'Microsoft.ApiManagement/service/apis/policies@2023-03-01-preview' = {
  name: 'policy'
  parent: restApi
  properties: {
    value: loadTextContent('../apim/policies/api-policy.xml')
    format: 'rawxml'
  }
}

resource diagnosticsPolicy 'Microsoft.ApiManagement/service/apis/diagnostics@2022-08-01' = if (!empty(apimLoggerName)) {
  name: 'applicationinsights'
  parent: restApi
  properties: {
    alwaysLog: 'allErrors'
    httpCorrelationProtocol: 'W3C'
    logClientIp: true
    loggerId: apimLogger.id
    metrics: true
    verbosity: 'verbose'
    sampling: {
      samplingType: 'fixed'
      percentage: 100
    }
    frontend: {
      request: logSettings
      response: logSettings
    }
    backend: {
      request: logSettings
      response: logSettings
    }
  }
}

output serviceUrl string = '${apimService.properties.gatewayUrl}/${path}'
