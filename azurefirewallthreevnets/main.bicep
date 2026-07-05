targetScope = 'resourceGroup'

@description('Abbreviation. Used in Azure resource names. Default is jv.')
@minLength(2)
@maxLength(6)
param abbreviation string = 'jv'

var location = resourceGroup().location
var abbreviationLower = toLower(abbreviation)

@description('Azure Firewall SKU tier.')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param firewallSkuTier string = 'Standard'

@description('Tags. Optional. Add Azure resource tags as a JSON object. Leave empty if no tags are needed.')
param tags object = {}

var vnet01Name = 'vnet-${abbreviationLower}-vnet01'
var vnet02Name = 'vnet-${abbreviationLower}-vnet02'
var vnet03Name = 'vnet-${abbreviationLower}-vnet03'

var vnet01AddressSpace = '10.69.0.0/16'
var vnet02AddressSpace = '10.70.0.0/16'
var vnet03AddressSpace = '10.71.0.0/16'

var azureFirewallSubnetName = 'AzureFirewallSubnet'
var azureFirewallSubnetPrefix = '10.69.0.0/26'
var vnet01SubnetName = 'snet-${abbreviationLower}-vnet01'
var vnet01SubnetPrefix = '10.69.1.0/24'
var vnet02SubnetName = 'snet-${abbreviationLower}-vnet02'
var vnet02SubnetPrefix = '10.70.0.0/24'
var vnet03SubnetName = 'snet-${abbreviationLower}-vnet03'
var vnet03SubnetPrefix = '10.71.0.0/24'

var firewallName = 'afw-${abbreviationLower}-afw01'
var firewallPolicyName = 'afwp-${abbreviationLower}-afwp01'
var firewallPublicIpName = 'pip-${abbreviationLower}-afw01'
var firewallIpConfigName = 'ipconfig1'

resource vnet01 'Microsoft.Network/virtualNetworks@2024-01-01' = {
  name: vnet01Name
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnet01AddressSpace
      ]
    }
    subnets: [
      {
        name: azureFirewallSubnetName
        properties: {
          addressPrefix: azureFirewallSubnetPrefix
        }
      }
      {
        name: vnet01SubnetName
        properties: {
          addressPrefix: vnet01SubnetPrefix
        }
      }
    ]
  }
}

resource vnet02 'Microsoft.Network/virtualNetworks@2024-01-01' = {
  name: vnet02Name
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnet02AddressSpace
      ]
    }
    subnets: [
      {
        name: vnet02SubnetName
        properties: {
          addressPrefix: vnet02SubnetPrefix
        }
      }
    ]
  }
}

resource vnet03 'Microsoft.Network/virtualNetworks@2024-01-01' = {
  name: vnet03Name
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnet03AddressSpace
      ]
    }
    subnets: [
      {
        name: vnet03SubnetName
        properties: {
          addressPrefix: vnet03SubnetPrefix
        }
      }
    ]
  }
}

resource vnet01ToVnet02 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-01-01' = {
  name: '${vnet01.name}/VNET01-to-VNET02'
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: vnet02.id
    }
  }
}

resource vnet02ToVnet01 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-01-01' = {
  name: '${vnet02.name}/VNET02-to-VNET01'
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: vnet01.id
    }
  }
}

resource vnet01ToVnet03 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-01-01' = {
  name: '${vnet01.name}/VNET01-to-VNET03'
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: vnet03.id
    }
  }
}

resource vnet03ToVnet01 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-01-01' = {
  name: '${vnet03.name}/VNET03-to-VNET01'
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: vnet01.id
    }
  }
}

resource vnet02ToVnet03 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-01-01' = {
  name: '${vnet02.name}/VNET02-to-VNET03'
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: vnet03.id
    }
  }
}

resource vnet03ToVnet02 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-01-01' = {
  name: '${vnet03.name}/VNET03-to-VNET02'
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: vnet02.id
    }
  }
}

resource firewallPublicIp 'Microsoft.Network/publicIPAddresses@2024-01-01' = {
  name: firewallPublicIpName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource firewallPolicy 'Microsoft.Network/firewallPolicies@2024-01-01' = {
  name: firewallPolicyName
  location: location
  tags: tags
  properties: {
    threatIntelMode: 'Alert'
    sku: {
      tier: firewallSkuTier
    }
  }
}

resource firewall 'Microsoft.Network/azureFirewalls@2024-01-01' = {
  name: firewallName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'AZFW_VNet'
      tier: firewallSkuTier
    }
    firewallPolicy: {
      id: firewallPolicy.id
    }
    ipConfigurations: [
      {
        name: firewallIpConfigName
        properties: {
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnet01Name, azureFirewallSubnetName)
          }
          publicIPAddress: {
            id: firewallPublicIp.id
          }
        }
      }
    ]
  }
  dependsOn: [
    vnet01
  ]
}

output resourceGroupName string = resourceGroup().name
output azureFirewallName string = firewall.name
output azureFirewallPolicyName string = firewallPolicy.name
output azureFirewallPublicIpName string = firewallPublicIp.name
output azureFirewallPublicIpAddress string = firewallPublicIp.properties.ipAddress
output vnetNames array = [
  vnet01.name
  vnet02.name
  vnet03.name
]
output peeringNames array = [
  'VNET01-to-VNET02'
  'VNET02-to-VNET01'
  'VNET01-to-VNET03'
  'VNET03-to-VNET01'
  'VNET02-to-VNET03'
  'VNET03-to-VNET02'
]
