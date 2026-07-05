# Single Server IIS

This template deploys one Windows Server VM with IIS installed.

## Parameters

- `abbreviation`: defaults to `jv` and is used in resource names.
- `vmSize`: defaults to `Standard_D2as_v7`.
- `webSourceAddressPrefix`: defaults to `Internet`.

## Deployed resources with default abbreviation `jv`

- Virtual network: `vnet-jv-vnet01`
- Subnet: `snet-jv-snet01`
- Network security group: `nsg-jv-nsg01`
- Static public IP address: `pip-jv-iis01`
- Network interface: `nic-jv-iis01`
- Windows Server 2022 Azure Edition VM: `vm-jv-iis01`
- OS disk: `osdisk-jv-iis01`
- Custom Script Extension to install IIS

## Network access

- `Allow-HTTPS-Inbound` allows HTTPS TCP/443 from `webSourceAddressPrefix` with priority 1000. The default value is `Internet`.
- `Allow-RDP-Inbound` allows RDP TCP/3389 only from the configured `sourceIpAddress` with priority 2000.

Note: this opens TCP/443 in the NSG. The template does not configure an SSL certificate or HTTPS binding in IIS.

## Outputs

- `rdpCommand`
- `websiteUrl`
- `publicIPAddress`
- `privateIPAddress`
