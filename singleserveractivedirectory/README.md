# Single Server Active Directory

This template deploys one Windows Server Active Directory domain controller.

## Parameters

- `abbreviation`: defaults to `jv` and is used in resource names.
- `adminUsername`: local administrator username for the VM.
- `adminPassword`: local administrator password for the VM.
- `dsrmPassword`: separate Directory Services Restore Mode password.
- `domainName`: defaults to `internal.justinverstijnen.nl`.
- `domainNetbiosName`: defaults to `JV`.
- `vmSize`: defaults to `Standard_E2as_v7`.

## Deployed resources with default abbreviation `jv`

- Virtual network: `vnet-jv-vnet01`
- Subnet: `snet-jv-snet01`
- Network security group: `nsg-jv-nsg01`
- Domain controller VM: `vm-jv-dc01`
- OS disk: `osdisk-jv-dc01`
- Network interface: `nic-jv-dc01`
- Static public IP address: `pip-jv-dc01`
- Custom Script Extension to install Active Directory Domain Services and DNS

## Network access

- `Allow-RDP-Inbound` allows RDP TCP/3389 only from the configured `sourceIpAddress`.
- VNet DNS and the VM NIC DNS setting are configured to use the domain controller private IP `10.69.0.4`.

## Outputs

- `rdpCommand`
- `publicIPAddress`
- `privateIPAddress`
- `activeDirectoryDomain`
