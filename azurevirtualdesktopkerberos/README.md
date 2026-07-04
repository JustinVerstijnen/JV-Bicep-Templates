# Azure Virtual Desktop with Entra Kerberos FSLogix

This folder contains the Bicep and ARM version of the old Terraform Azure Virtual Desktop Kerberos project.

## Files

- `main.bicep` - readable Bicep source.
- `main.json` - ARM template for Azure Portal deployment.
- `deploy.html` - Deploy to Azure button using the same structure as the existing Deployment Templates repo.

## What it deploys

The template deploys an Azure Virtual Desktop environment into the resource group selected in the Azure portal:

- Virtual network and AVD subnet
- Network security group without public inbound RDP rules
- Storage account for FSLogix profiles
- Azure Files share `fslogix-profiles`
- Azure Files identity-based authentication with `AADKERB`
- Azure Files SMB security profile with Kerberos, SMB 3.1.1, AES-256 Kerberos ticket encryption and AES-256-GCM SMB channel encryption
- Pooled Azure Virtual Desktop host pool
- Desktop application group
- Workspace
- Session host VM(s), Entra joined through `AADLoginForWindows`
- AVD DSC registration extension
- Guest Attestation extension
- RBAC assignments for AVD users, AVD admins, FSLogix storage access, and optional Start VM on Connect

## Important difference from Terraform

The Terraform version created the resource group itself: `rg-jv-<project>`.

This repository uses Azure Portal Deploy to Azure templates at resource-group scope, just like the existing `singleserveractivedirectory` template. Create or select the resource group yourself before deploying. To keep the same naming as Terraform, create/select:

```text
rg-jv-<project>
```

The template also outputs `expectedTerraformResourceGroupName` after deployment.


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


## Deployment fix note

The host pool is deployed through a nested deployment so the registration-token expiration stays hidden from the Azure Portal wizard. Downstream resources now consume the host pool through nested deployment outputs. This avoids `Microsoft.DesktopVirtualization/hostpools/<name> was not found` errors where the Desktop Application Group or DSC extension tried to reference the host pool too early.

## Required parameters

- `projectName`
- `adminUsername`
- `adminPassword`
- `avdDesktopAccessGroupObjectId`
- `avdAdminsGroupObjectId`

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

After committing this folder to `main` in `JustinVerstijnen/JV-Azure-Deployment-Templates`, open `deploy.html` or use this raw ARM template path:

```text
https://raw.githubusercontent.com/JustinVerstijnen/JV-Azure-Deployment-Templates/refs/heads/main/azurevirtualdesktopkerberos/main.json
```

## Fix notes

- The AVD registration token is retrieved with `listRegistrationTokens()` instead of `reference(...).registrationInfo.token`.
- This is required because `registrationInfo` is not returned on GET/reference for newer Azure Virtual Desktop host pool API versions.
- If `AADLoginForWindows` fails with hostname `0x801c0083`, remove the old Entra/Intune device object or deploy with a new `sessionHostNamePrefix`.

## Secure output fix

The AVD registration token is no longer passed as a nested deployment `secureString` output.
ARM does not expose the `.value` of secure outputs to another template. The DSC extension now retrieves the registration token directly with `listRegistrationTokens()` inside `protectedSettings`, after the nested host pool deployment has completed.

## Default Object IDs

The Azure Portal wizard parameters now include default values for:

- `avdDesktopAccessGroupObjectId`: `fa65fdc8-3c24-48a2-bd56-eb2939f965f8`
- `avdAdminsGroupObjectId`: `d3216b41-c48e-478c-acc4-50d35dff57ab`
- `avdServicePrincipalObjectId`: `7ea13f1d-177a-4c0e-98a3-8ef6814a7190`
- `avdComputerGroupObjectId`: empty optional default

## Stable flat host pool fix

The AVD host pool is now deployed as a normal top-level ARM resource again. The earlier nested host pool deployment has been removed because repeated deployments could fail with `Microsoft.DesktopVirtualization/hostPools/... was not found` when later resources tried to resolve the host pool.

This means `registrationTokenExpirationTime` is visible in the Azure Portal wizard again, because ARM only allows `utcNow()` in parameter default values. Leave the default unchanged; it is generated as 27 days from deployment time.

## Intune enrollment default

`enrollSessionHostsInIntune` now defaults to `false`.

This avoids a common deployment failure where Intune/Defender/WDAC/ASR policies apply before the Azure Virtual Desktop agent is installed by the DSC extension. If you want Intune enrollment during deployment, set this parameter to `true` only after confirming your enrollment restrictions and endpoint security policies allow MSI/process execution from the Azure VM extension/DSC plugin path.

## Intune expression fix

`enrollSessionHostsInIntune` defaults to `true` again for cloud-only deployments.

The DSC extension settings were changed back to a normal JSON object instead of a single `createObject()` expression. This avoids ARM parser issues with boolean literals in functions and keeps the deployment wizard simple.
