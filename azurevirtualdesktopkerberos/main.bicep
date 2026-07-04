targetScope = 'resourceGroup'

@description('Project name. Required. Use 2 to 20 characters. Use only letters, numbers and hyphens. This value is used in Azure resource names. The storage account becomes sajv<project without hyphens>.')
@minLength(2)
@maxLength(20)
param projectName string

var location = resourceGroup().location

@description('AVD registration token expiration time. Default is 27 days from deployment time. Normally do not change this.')
param registrationTokenExpirationTime string = dateTimeAdd(utcNow(), 'P27D')

@description('Username. Required. Local administrator username for the AVD session host VMs.')
param adminUsername string

@description('Password. Required. Local administrator password for the AVD session host VMs. Use a strong password.')
@secure()
param adminPassword string

@description('Object ID. Required. Entra ID group that receives AVD desktop access, Virtual Machine User Login, and Storage File Data SMB Share Contributor permissions.')
param avdDesktopAccessGroupObjectId string = 'fa65fdc8-3c24-48a2-bd56-eb2939f965f8'

@description('Object ID. Required. Entra ID group that receives Virtual Machine Administrator Login and Storage File Data Privileged Contributor permissions.')
param avdAdminsGroupObjectId string = 'd3216b41-c48e-478c-acc4-50d35dff57ab'

@description('Object ID. Optional. Azure Virtual Desktop enterprise application/service principal object ID. Fill this for Start VM on Connect RBAC. App/client ID is 9cdead84-a844-4324-93f2-b2e6bb768d07, but the object ID is tenant-specific. Leave empty to skip this role assignment.')
param avdServicePrincipalObjectId string = '7ea13f1d-177a-4c0e-98a3-8ef6814a7190'

@description('Object ID. Optional. Existing Entra ID computer/device group for AVD session hosts. This template only returns the value for policy targeting; it does not create or populate the group.')
param avdComputerGroupObjectId string = ''

@description('Friendly name shown for the AVD Workspace.')
param workspaceFriendlyName string = 'JV Azure Virtual Desktop Workspace'

@description('Description shown for the AVD Workspace.')
param workspaceDescription string = 'Workspace for Azure Virtual Desktop.'

@description('Description shown for the AVD Desktop Application Group.')
param applicationGroupDescription string = 'Desktop application group for Azure Virtual Desktop.'

@description('Display name for the default desktop in the Desktop Application Group.')
param defaultDesktopDisplayName string = 'Session Desktop'

@description('Description shown for the AVD Host Pool.')
param hostPoolDescription string = 'Pooled Azure Virtual Desktop host pool.'

@description('Load balancer type for the pooled host pool.')
@allowed([
  'BreadthFirst'
  'DepthFirst'
])
param hostPoolLoadBalancerType string = 'BreadthFirst'

@description('Maximum concurrent sessions per session host.')
@minValue(1)
param hostPoolMaximumSessionsAllowed int = 8

@description('Number of AVD session hosts to deploy.')
@minValue(1)
@maxValue(10)
param sessionHostCount int = 1

@description('Prefix for AVD session host names. A numeric suffix is added: -0, -1, -2. Keep max 11 characters.')
@minLength(1)
@maxLength(11)
param sessionHostNamePrefix string = 'vm-jv-avd'

@description('Azure VM size for the AVD session host VMs.')
param sessionHostVmSize string = 'Standard_E4as_v7'

@description('Enroll session hosts in Intune during deployment. For cloud-only deployments this should normally stay true. Tenant-side automatic MDM enrollment scope and Intune policies must allow these devices/users.')
param enrollSessionHostsInIntune bool = true

@description('Microsoft AVD DSC configuration package used to register session hosts to the host pool.')
param avdDscConfigurationZipUrl string = 'https://raw.githubusercontent.com/Azure/RDS-Templates/master/ARM-wvd-templates/DSC/Configuration.zip'

@description('Tags. Optional. Add Azure resource tags as a JSON object. Leave empty if no tags are needed.')
param tags object = {}

var projectClean = toLower(projectName)
var projectStorage = toLower(replace(projectName, '-', ''))

var vnetName = 'vnet-jv-${projectClean}'
var subnetName = 'snet-jv-${projectClean}'
var nsgName = 'nsg-jv-avd-${projectClean}'

var storageAccountName = 'sajv${projectStorage}'
var fslogixShareName = 'fslogix-profiles'

var hostPoolName = 'vdhp-jv-${projectClean}'
var applicationGroupName = 'vdag-jv-${projectClean}'
var workspaceName = 'vdws-jv-${projectClean}'

var sessionHostNames = [for index in range(0, sessionHostCount): '${sessionHostNamePrefix}-${index}']
var entraSsoRdpProperties = join([
  'targetisaadjoined:i:1'
  'enablerdsaadauth:i:1'
  'redirectwebauthn:i:1'
  'audiocapturemode:i:1'
  'audiomode:i:0'
  'camerastoredirect:s:*'
  'devicestoredirect:s:*'
  'drivestoredirect:s:*'
  'redirectclipboard:i:1'
  'redirectcomports:i:1'
  'redirectprinters:i:1'
  'redirectsmartcards:i:1'
  'screen mode id:i:2'
], ';')

var intuneMdmApplicationId = '0000000a-0000-0000-c000-000000000000'
var avdServicePrincipalClientId = '9cdead84-a844-4324-93f2-b2e6bb768d07'

var desktopVirtualizationPowerOnContributorRoleId = '489581de-a3bd-480d-9518-53dea7416b33'
var desktopVirtualizationUserRoleId = '1d18fff3-a72a-46b5-b4a9-0b38a3cd7e63'
var virtualMachineUserLoginRoleId = 'fb879df8-f326-4884-b1cf-06f3ad86be52'
var virtualMachineAdministratorLoginRoleId = '1c0163c0-47e6-4577-8991-ea5c82e286e4'
var storageFileDataSmbShareContributorRoleId = '0c867c2a-1d8c-454a-a3db-ab2ea1bdc8bb'
var storageFileDataPrivilegedContributorRoleId = '69566ab7-960f-475b-8e7c-b3118f30c6bd'


// Fixed deployment defaults. These values are intentionally not exposed as Azure portal wizard fields.
var vnetAddressSpace = [
  '10.69.0.0/16'
]
var subnetAddressPrefixes = [
  '10.69.0.0/24'
]
var storageIpRules = []
var storageNetworkBypass = [
  'AzureServices'
]
var storageReplicationType = 'LRS'
var fileShareSoftDeleteRetentionDays = 7
var fslogixShareQuotaGb = 5120
var fslogixShareAccessTier = 'TransactionOptimized'
var osDiskSizeGb = 128
var imagePublisher = 'MicrosoftWindowsDesktop'
var imageOffer = 'windows-11'
var imageSku = 'win11-25h2-avd'
var imageVersion = 'latest'

resource nsg 'Microsoft.Network/networkSecurityGroups@2024-01-01' = {
  name: nsgName
  location: location
  tags: tags
  properties: {
    securityRules: []
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2024-01-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: vnetAddressSpace
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefixes: subnetAddressPrefixes
          networkSecurityGroup: {
            id: nsg.id
          }
          serviceEndpoints: [
            {
              service: 'Microsoft.Storage'
            }
          ]
        }
      }
    ]
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: {
    name: 'Standard_${storageReplicationType}'
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    defaultToOAuthAuthentication: true
    largeFileSharesState: 'Enabled'
    publicNetworkAccess: 'Enabled'
    isLocalUserEnabled: false
    encryption: {
      keySource: 'Microsoft.Storage'
      requireInfrastructureEncryption: true
      services: {
        blob: {
          enabled: true
          keyType: 'Account'
        }
        file: {
          enabled: true
          keyType: 'Account'
        }
      }
    }
    azureFilesIdentityBasedAuthentication: {
      directoryServiceOptions: 'AADKERB'
      defaultSharePermission: 'StorageFileDataSmbShareContributor'
    }
    networkAcls: {
      defaultAction: 'Deny'
      bypass: join(storageNetworkBypass, ',')
      ipRules: [for ipRule in storageIpRules: {
        action: 'Allow'
        value: ipRule
      }]
      virtualNetworkRules: [
        {
          action: 'Allow'
          id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, subnetName)
        }
      ]
    }
  }
  dependsOn: [
    vnet
  ]
}

resource fileService 'Microsoft.Storage/storageAccounts/fileServices@2023-05-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    shareDeleteRetentionPolicy: {
      enabled: true
      days: fileShareSoftDeleteRetentionDays
    }
    protocolSettings: {
      smb: {
        versions: 'SMB3.1.1'
        authenticationMethods: 'Kerberos'
        kerberosTicketEncryption: 'AES-256'
        channelEncryption: 'AES-256-GCM'
      }
    }
  }
}

resource fslogixShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-05-01' = {
  parent: fileService
  name: fslogixShareName
  properties: {
    enabledProtocols: 'SMB'
    shareQuota: fslogixShareQuotaGb
    accessTier: fslogixShareAccessTier
  }
}

// The host pool is created in a nested module so the registration-token expiration can stay hidden from the Azure Portal wizard.
// Downstream resources use module outputs to avoid host pool ResourceNotFound timing/reference issues.


resource hostPool 'Microsoft.DesktopVirtualization/hostPools@2024-04-03' = {
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

resource applicationGroup 'Microsoft.DesktopVirtualization/applicationGroups@2024-04-03' = {
  name: applicationGroupName
  location: location
  tags: tags
  properties: {
    applicationGroupType: 'Desktop'
    hostPoolArmPath: hostPool.outputs.hostPoolId
    friendlyName: applicationGroupName
    description: applicationGroupDescription
    defaultDesktopDisplayName: defaultDesktopDisplayName
  }
}

resource workspace 'Microsoft.DesktopVirtualization/workspaces@2024-04-03' = {
  name: workspaceName
  location: location
  tags: tags
  properties: {
    friendlyName: workspaceFriendlyName
    description: workspaceDescription
    publicNetworkAccess: 'Enabled'
    applicationGroupReferences: [
      applicationGroup.id
    ]
  }
}

resource sessionHostNic 'Microsoft.Network/networkInterfaces@2024-01-01' = [for index in range(0, sessionHostCount): {
  name: 'nic-${sessionHostNames[index]}'
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, subnetName)
          }
        }
      }
    ]
  }
  dependsOn: [
    vnet
  ]
}]

resource sessionHostVm 'Microsoft.Compute/virtualMachines@2024-03-01' = [for index in range(0, sessionHostCount): {
  name: sessionHostNames[index]
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    licenseType: 'Windows_Client'
    hardwareProfile: {
      vmSize: sessionHostVmSize
    }
    osProfile: {
      computerName: sessionHostNames[index]
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        provisionVMAgent: true
        enableAutomaticUpdates: true
      }
    }
    storageProfile: {
      imageReference: {
        publisher: imagePublisher
        offer: imageOffer
        sku: imageSku
        version: imageVersion
      }
      osDisk: {
        name: 'osdisk-${sessionHostNames[index]}'
        createOption: 'FromImage'
        caching: 'ReadWrite'
        diskSizeGB: osDiskSizeGb
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: sessionHostNic[index].id
          properties: {
            primary: true
            deleteOption: 'Delete'
          }
        }
      ]
    }
    securityProfile: {
      securityType: 'TrustedLaunch'
      uefiSettings: {
        secureBootEnabled: true
        vTpmEnabled: true
      }
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
}]

resource aadLoginExtension 'Microsoft.Compute/virtualMachines/extensions@2024-03-01' = [for index in range(0, sessionHostCount): {
  parent: sessionHostVm[index]
  name: 'AADLoginForWindows'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.ActiveDirectory'
    type: 'AADLoginForWindows'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
    settings: enrollSessionHostsInIntune ? {
      mdmId: intuneMdmApplicationId
    } : {}
  }
  dependsOn: [
    sessionHostVm[index]
  ]
}]


resource avdRegistrationExtension 'Microsoft.Compute/virtualMachines/extensions@2024-03-01' = [for index in range(0, sessionHostCount): {
  parent: sessionHostVm[index]
  name: 'Microsoft.PowerShell.DSC'
  location: location
  properties: {
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.83'
    autoUpgradeMinorVersion: true
    settings: {
      modulesUrl: avdDscConfigurationZipUrl
      configurationFunction: 'Configuration.ps1\\AddSessionHost'
      properties: {
        hostPoolName: hostPool.outputs.hostPoolName
        aadJoin: true
        mdmId: enrollSessionHostsInIntune ? intuneMdmApplicationId : ''
        UseAgentDownloadEndpoint: true
        sessionHostConfigurationLastUpdateTime: ''
      }
    }
    protectedSettings: {
      properties: {
        registrationInfoToken: first(hostPool.listRegistrationTokens().value).token
      }
    }
  }
  dependsOn: [
    hostPool
    aadLoginExtension[index]
  ]
}]

resource guestAttestationExtension 'Microsoft.Compute/virtualMachines/extensions@2024-03-01' = [for index in range(0, sessionHostCount): {
  parent: sessionHostVm[index]
  name: 'GuestAttestation'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Security.WindowsAttestation'
    type: 'GuestAttestation'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
  }
}]

resource avdStartVmOnConnectRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(avdServicePrincipalObjectId)) {
  name: guid(resourceGroup().id, avdServicePrincipalObjectId, desktopVirtualizationPowerOnContributorRoleId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', desktopVirtualizationPowerOnContributorRoleId)
    principalId: avdServicePrincipalObjectId
    principalType: 'ServicePrincipal'
  }
}

resource desktopAccessRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: applicationGroup
  name: guid(applicationGroup.id, avdDesktopAccessGroupObjectId, desktopVirtualizationUserRoleId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', desktopVirtualizationUserRoleId)
    principalId: avdDesktopAccessGroupObjectId
    principalType: 'Group'
  }
}

resource desktopAccessVmLoginRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, avdDesktopAccessGroupObjectId, virtualMachineUserLoginRoleId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', virtualMachineUserLoginRoleId)
    principalId: avdDesktopAccessGroupObjectId
    principalType: 'Group'
  }
}

resource avdAdminsVmAdminLoginRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, avdAdminsGroupObjectId, virtualMachineAdministratorLoginRoleId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', virtualMachineAdministratorLoginRoleId)
    principalId: avdAdminsGroupObjectId
    principalType: 'Group'
  }
}

resource desktopAccessStorageContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storageAccount
  name: guid(storageAccount.id, avdDesktopAccessGroupObjectId, storageFileDataSmbShareContributorRoleId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageFileDataSmbShareContributorRoleId)
    principalId: avdDesktopAccessGroupObjectId
    principalType: 'Group'
  }
}

resource avdAdminsStoragePrivilegedContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storageAccount
  name: guid(storageAccount.id, avdAdminsGroupObjectId, storageFileDataPrivilegedContributorRoleId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageFileDataPrivilegedContributorRoleId)
    principalId: avdAdminsGroupObjectId
    principalType: 'Group'
  }
}

output resourceGroupName string = resourceGroup().name
output expectedTerraformResourceGroupName string = 'rg-jv-${projectClean}'
output vnetResourceName string = vnet.name
output subnetResourceName string = subnetName
output storageAccountResourceName string = storageAccount.name
output fslogixProfilesShareName string = fslogixShare.name
output fslogixProfilesUncPath string = '\\\\${storageAccount.name}.file.core.windows.net\\${fslogixShare.name}'
output hostPoolResourceName string = hostPool.outputs.hostPoolName
output applicationGroupResourceName string = applicationGroup.name
output workspaceResourceName string = workspace.name
output sessionHostNameList array = sessionHostNames
output hostPoolRdpProperties string = hostPool.outputs.hostPoolRdpProperties
output avdComputerGroupObjectIdValue string = avdComputerGroupObjectId
output avdServicePrincipalClientIdValue string = avdServicePrincipalClientId
output postDeploymentNote string = 'Deploy this template into the resource group you want to use. To match the original Terraform naming exactly, create/select resource group rg-jv-${projectClean} before deploying.'
