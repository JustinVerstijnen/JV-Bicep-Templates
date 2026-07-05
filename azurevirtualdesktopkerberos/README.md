# Azure Virtual Desktop with Entra Kerberos FSLogix

This folder contains the Bicep and ARM version of the old Terraform Azure Virtual Desktop Kerberos project.

## Files

- `main.bicep` - readable Bicep source.
- `main.json` - ARM template for Azure Portal deployment.
- `deploy.html` - Deploy to Azure button using the same structure as the existing Deployment Templates repo.

## Parameters

- `abbreviation`: defaults to `jv` and is used in resource names.
- `adminUsername`: local administrator username for the AVD session host VMs.
- `adminPassword`: local administrator password for the AVD session host VMs.
- `sessionHostCount`: defaults to `1`.
- `sessionHostVmSize`: defaults to `Standard_E4as_v7`.
- `avdDesktopAccessGroupObjectId`: Entra ID group that receives AVD desktop access, Virtual Machine User Login, and Storage File Data SMB Share Contributor permissions.
- `avdAdminsGroupObjectId`: Entra ID group that receives Virtual Machine Administrator Login and Storage File Data Privileged Contributor permissions.

## Deployed resources with default abbreviation `jv`

- Virtual network: `vnet-jv-vnet01`
- Subnet: `snet-jv-snet01`
- Network security group: `nsg-jv-nsg01`
- Storage account for FSLogix profiles. The name starts with `sajv` and includes a deterministic unique suffix because Azure Storage account names must be globally unique.
- Azure Files share: `fslogix-profiles`
- Azure Files identity-based authentication with `AADKERB`
- Azure Files SMB security profile with Kerberos, SMB 3.1.1, AES-256 Kerberos ticket encryption and AES-256-GCM SMB channel encryption
- Pooled Azure Virtual Desktop host pool: `vdhp-jv-avd01`
- Desktop application group: `vdag-jv-avd01`
- Workspace: `vdws-jv-avd01`
- Session host VM(s): `vm-jv-sh-1`, `vm-jv-sh-2`, etc.
- Session host NIC(s): `nic-vm-jv-sh-1`, `nic-vm-jv-sh-2`, etc.
- Session host OS disk(s): `osdisk-vm-jv-sh-1`, `osdisk-vm-jv-sh-2`, etc.
- AVD DSC registration extension
- Guest Attestation extension
- RBAC assignments for AVD users, AVD admins, FSLogix storage access, and optional Start VM on Connect

## Simplified Azure Portal wizard

The following deployment values are intentionally fixed inside the template instead of exposed as Azure Portal wizard fields:

- Virtual network address space: `10.69.0.0/16`
- AVD subnet address prefix: `10.69.0.0/24`
- Storage IP rules: none
- Storage network bypass: `AzureServices`
- Storage replication type: `LRS`
- File share soft delete retention: `7` days
- FSLogix share quota: `5120` GiB
- FSLogix share access tier: `TransactionOptimized`
- Registration token expiration: 27 days from deployment time
- OS disk size: `128` GiB
- Image publisher: `MicrosoftWindowsDesktop`
- Image offer: `windows-11`
- Image SKU: `win11-25h2-avd`
- Image version: `latest`

## Optional but recommended parameter

- `avdServicePrincipalObjectId`

This is the tenant-specific Object ID of the Azure Virtual Desktop enterprise application/service principal. Fill this value if you want the template to assign `Desktop Virtualization Power On Contributor` for Start VM on Connect.

The Azure Virtual Desktop app/client ID is:

```text
9cdead84-a844-4324-93f2-b2e6bb768d07
```

You need the Object ID, not the app/client ID.

Example lookup:

```powershell
az ad sp show --id 9cdead84-a844-4324-93f2-b2e6bb768d07 --query id -o tsv
```

## Deployment permissions

The identity deploying this template needs permissions to create Azure resources and role assignments. In practice this usually means:

- Contributor for resource creation.
- User Access Administrator, Role Based Access Control Administrator, or Owner for RBAC role assignments.

## Deploy button

After committing this folder to `main` in `JustinVerstijnen/AzureDeploymentTemplates`, open `deploy.html` or use this raw ARM template path:

```text
https://raw.githubusercontent.com/JustinVerstijnen/AzureDeploymentTemplates/refs/heads/main/azurevirtualdesktopkerberos/main.json
```

## Fix notes

- The AVD registration token is retrieved with `listRegistrationTokens()` instead of `reference(...).registrationInfo.token`.
- This is required because `registrationInfo` is not returned on GET/reference for newer Azure Virtual Desktop host pool API versions.
- The AVD registration token is no longer passed as a nested deployment `secureString` output.
- ARM does not expose the `.value` of secure outputs to another template. The DSC extension retrieves the registration token directly with `listRegistrationTokens()` inside `protectedSettings`.
- `enrollSessionHostsInIntune` defaults to `true` for cloud-only deployments.
