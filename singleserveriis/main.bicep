targetScope = 'resourceGroup'

@description('Abbreviation. Used in Azure resource names. Default is jv, which creates names like vm-jv-iis01.')
@minLength(2)
@maxLength(6)
param abbreviation string = 'jv'

var location = resourceGroup().location

@description('Username. Required. Local administrator username for the Windows Server VM.')
param adminUsername string

@description('Password. Required. Local administrator password for the Windows Server VM. Use a strong password.')
@secure()
param adminPassword string

@description('Public IP address. Required. Public IPv4 address that is allowed to connect with RDP. Enter only the IP address, without /32.')
param sourceIpAddress string

@description('Server size. Required. Enter an Azure VM size, for example Standard_D2as_v5 or Standard_D2as_v7.')
param vmSize string = 'Standard_D2as_v7'

@description('Source address prefix that is allowed to access the IIS website on HTTPS port 443. Default is Internet.')
param webSourceAddressPrefix string = 'Internet'

@description('Tags. Optional. Add Azure resource tags as a JSON object. Leave empty if no tags are needed.')
param tags object = {}

var vnetAddressPrefix = '10.69.0.0/16'
var subnetPrefix = '10.69.0.0/24'
var vmPrivateIpAddress = '10.69.0.4'

var abbreviationLower = toLower(abbreviation)
var vnetName = 'vnet-${abbreviationLower}-vnet01'
var subnetName = 'snet-${abbreviationLower}-snet01'
var nsgName = 'nsg-${abbreviationLower}-nsg01'
var publicIpName = 'pip-${abbreviationLower}-iis01'
var nicName = 'nic-${abbreviationLower}-iis01'
var vmName = 'vm-${abbreviationLower}-iis01'
var osDiskName = 'osdisk-${abbreviationLower}-iis01'
var rdpRuleName = 'Allow-RDP-Inbound'
var httpsRuleName = 'Allow-HTTPS-Inbound'

// This command installs IIS and places a small default page in wwwroot.
var installIisScriptLines = [
  '$ErrorActionPreference = \'Stop\''
  'Install-WindowsFeature -Name Web-Server -IncludeManagementTools'
  'Install-WindowsFeature -Name Web-Mgmt-Tools'
  '$html = \'<html><head><title>${vmName}</title></head><body><h1>IIS is running</h1><p>Server: ${vmName}</p><p>Deployed with Bicep and ARM.</p></body></html>\''
  'Set-Content -Path \'C:/inetpub/wwwroot/index.html\' -Value $html -Encoding UTF8'
  'exit 0'
]

var installIisCommand = 'powershell.exe -ExecutionPolicy Unrestricted -NoProfile -Command "${join(installIisScriptLines, '; ')}"'

resource nsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: nsgName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: httpsRuleName
        properties: {
          priority: 1000
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: webSourceAddressPrefix
          destinationAddressPrefix: '*'
          description: 'Allow HTTPS traffic to the IIS website.'
        }
      }
      {
        name: rdpRuleName
        properties: {
          priority: 2000
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: '${sourceIpAddress}/32'
          destinationAddressPrefix: '*'
          description: 'Allow RDP only from the configured administrator IP address.'
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetPrefix
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
    ]
  }
}

resource publicIp 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
  name: publicIpName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: nicName
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: vmPrivateIpAddress
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, subnetName)
          }
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
    ]
  }
  dependsOn: [
    vnet
  ]
}

resource vm 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: vmName
  location: location
  tags: tags
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        provisionVMAgent: true
        enableAutomaticUpdates: true
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-datacenter-azure-edition'
        version: 'latest'
      }
      osDisk: {
        name: osDiskName
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
          properties: {
            primary: true
          }
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
}

resource installIisExtension 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = {
  parent: vm
  name: 'install-iis'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    protectedSettings: {
      commandToExecute: installIisCommand
    }
  }
}

output resourceGroupName string = resourceGroup().name
output virtualMachineName string = vm.name
output privateIPAddress string = vmPrivateIpAddress
output publicIPAddress string = publicIp.properties.ipAddress
output rdpCommand string = 'mstsc /v:${publicIp.properties.ipAddress}'
output websiteUrl string = 'http://${publicIp.properties.ipAddress}'
output postDeploymentNote string = 'IIS is installed with a default test page. Open the websiteUrl output after the VM extension has completed.'
