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
