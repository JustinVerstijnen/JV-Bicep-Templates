targetScope = 'resourceGroup'

@description('Short project name. Keep this short because the Windows computer name has a 15 character limit.')
@minLength(2)
@maxLength(8)
param projectName string = 'projname'

@description('Azure region where the resources will be deployed. By default, the resource group location is used.')
param location string = resourceGroup().location

@description('Local administrator username for the Windows Server VM.')
param adminUsername string = 'justin-admin'

@description('Local administrator password for the Windows Server VM and the Active Directory DSRM password. Use a strong password.')
@secure()
param adminPassword string

@description('Public IPv4 address that is allowed to connect with RDP. Enter only the IP address, without /32.')
param sourceIpAddress string

@description('Windows Server VM size.')
param vmSize string = 'Standard_D2as_v7'

@description('Virtual network address space.')
param vnetAddressPrefix string = '10.69.0.0/16'

@description('Subnet address space.')
param subnetPrefix string = '10.69.0.0/24'

@description('Static private IP address for the domain controller.')
param vmPrivateIpAddress string = '10.69.0.4'

@description('Active Directory domain name to create on the server.')
param domainName string = 'justinverstijnen.nl'

@description('Active Directory NetBIOS name to create on the server.')
@minLength(1)
@maxLength(15)
param domainNetbiosName string = 'JV'

@description('Tags applied to all supported resources.')
param tags object = {
  deployment: 'bicep'
  workload: 'single-server-ad-lab'
}

var lowerProjectName = toLower(projectName)
var namePrefix = 'jv-${lowerProjectName}'
var vnetName = 'vnet-${namePrefix}'
var subnetName = 'snet-${namePrefix}'
var nsgName = 'nsg-${namePrefix}'
var publicIpName = 'pip-${namePrefix}'
var nicName = 'nic-${namePrefix}'
var vmName = 'vm-${namePrefix}'
var osDiskName = 'osdisk-${namePrefix}'
var rdpRuleName = 'allow-rdp-from-admin-ip'

// This command installs the AD DS role, creates a new forest, installs DNS, and schedules a restart.
// The password is base64 encoded only to avoid quoting issues in the PowerShell command.
// The command itself is passed through protectedSettings, so it is not stored as normal deployment output.
var encodedAdminPassword = base64(adminPassword)

var installAdScriptLines = [
  '$ErrorActionPreference = \'Stop\''
  'Install-WindowsFeature AD-Domain-Services -IncludeManagementTools'
  '$adminPasswordPlain = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String(\'${encodedAdminPassword}\'))'
  '$securePassword = ConvertTo-SecureString $adminPasswordPlain -AsPlainText -Force'
  'Install-ADDSForest -DomainName \'${domainName}\' -DomainNetbiosName \'${domainNetbiosName}\' -SafeModeAdministratorPassword $securePassword -InstallDNS -Force -NoRebootOnCompletion:$true'
  '$adminPasswordPlain = $null'
  'shutdown.exe /r /t 60 /c \'Restart after Active Directory Domain Services installation\''
  'exit 0'
]

var installAdCommand = 'powershell.exe -ExecutionPolicy Unrestricted -NoProfile -Command "${join(installAdScriptLines, '; ')}"'

resource nsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: nsgName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: rdpRuleName
        properties: {
          priority: 1000
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
    dhcpOptions: {
      dnsServers: [
        vmPrivateIpAddress
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

resource installAdDsExtension 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = {
  parent: vm
  name: 'install-ad-ds'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    protectedSettings: {
      commandToExecute: installAdCommand
    }
  }
}

output resourceGroupName string = resourceGroup().name
output virtualMachineName string = vm.name
output privateIPAddress string = vmPrivateIpAddress
output publicIPAddress string = publicIp.properties.ipAddress
output rdpCommand string = 'mstsc /v:${publicIp.properties.ipAddress}'
output activeDirectoryDomain string = domainName
output postDeploymentNote string = 'The VM restarts after the AD DS installation. Wait several minutes before testing the new domain controller.'
