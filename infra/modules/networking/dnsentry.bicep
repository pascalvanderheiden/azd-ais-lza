param dnsZoneName string 
param ipAddress string
param hostname string

resource dnsEntry 'Microsoft.Network/privateDnsZones/A@2020-06-01' = {
  name :  '${dnsZoneName}/${hostname}'
  properties: {
    ttl: 3600
    aRecords: [
      {
        ipv4Address: ipAddress
      }
    ]
  }
}

resource privateDnsZoneA 'Microsoft.Network/privateDnsZones/A@2020-06-01' = {
  name: '${privateDnsZoneName}/*'
  properties: {
    ttl: 3600
    aRecords: [
        {
            ipv4Address: aseIp
        }
    ]
  }
  dependsOn: [
    privateDnsZone
  ]
}

resource privateDnsZoneAscm 'Microsoft.Network/privateDnsZones/A@2020-06-01' = {
  name: '${privateDnsZoneName}/*.scm'
  properties: {
    ttl: 3600
    aRecords: [
        {
            ipv4Address: aseIp
        }
    ]
  }
  dependsOn: [
    privateDnsZone
  ]
}

resource privateDnsZoneAall 'Microsoft.Network/privateDnsZones/A@2020-06-01' = {
  name: '${privateDnsZoneName}/@'
  properties: {
    ttl: 3600
    aRecords: [
        {
            ipv4Address: aseIp
        }
    ]
  }
  dependsOn: [
    privateDnsZone
  ]
}

resource privateDnsZoneSOA 'Microsoft.Network/privateDnsZones/SOA@2020-06-01' = {
  name: '${privateDnsZoneName}/@'
  properties: {
    ttl: 3600
    soaRecord: {
        email: 'azureprivatedns-host.microsoft.com'
        expireTime: 2419200
        host: 'azureprivatedns.net'
        minimumTtl: 10
        refreshTime: 3600
        retryTime: 300
        serialNumber: 1
    }
  }
  dependsOn: [
    privateDnsZone
  ]
}

resource virtualNetworkLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  name: '${privateDnsZone.name}/${privateDnsZone.name}-link'
  location: 'global'
  properties: {
    registrationEnabled: autoVmRegistration
    virtualNetwork: {
      id: virtualNetworkId
    }
  }
}
