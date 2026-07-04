targetScope = 'resourceGroup'

param hostPoolName string
param location string
param tags object
param hostPoolLoadBalancerType string
param hostPoolMaximumSessionsAllowed int
param hostPoolDescription string
param entraSsoRdpProperties string

@description('Hidden inner parameter. Default is 27 days from deployment time.')
param registrationTokenExpirationTime string = dateTimeAdd(utcNow(), 'P27D')

resource hostPool 'Microsoft.DesktopVirtualization/hostPools@2024-04-08-preview' = {
  name: hostPoolName
  location: location
  tags: tags
  properties: {
    hostPoolType: 'Pooled'
    loadBalancerType: hostPoolLoadBalancerType
    maxSessionLimit: hostPoolMaximumSessionsAllowed
    startVMOnConnect: true
    validationEnvironment: false
    preferredAppGroupType: 'Desktop'
    publicNetworkAccess: 'Enabled'
    managementType: 'Standard'
    friendlyName: hostPoolName
    description: hostPoolDescription
    customRdpProperty: entraSsoRdpProperties
    registrationInfo: {
      expirationTime: registrationTokenExpirationTime
      registrationTokenOperation: 'Update'
    }
  }
}

output hostPoolName string = hostPool.name
output hostPoolId string = hostPool.id
output hostPoolRdpProperties string = hostPool.properties.customRdpProperty

@secure()
output registrationInfoToken string = hostPool.properties.registrationInfo.token
