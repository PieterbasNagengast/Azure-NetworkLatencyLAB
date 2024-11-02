param location string

@description('Prefix Name')
@maxLength(6)
@minLength(3)
param prefix string

@description('Enable or Disable telemetry')
param avmTelemetry bool

@description('vnet IP Address space')
param ipAddressSpace string

@description('subnet1 IP address prefix')
param subnet1AddressPrefix string = cidrSubnet(ipAddressSpace, 24, 1)
@description('subent2 IP address prefix')
param subnet2AddressPrefix string = cidrSubnet(ipAddressSpace, 24, 2)
@description('subent3 IP address prefix')
param subnet3AddressPrefix string = cidrSubnet(ipAddressSpace, 24, 3)

@description('Virtual mahcine SKU size')
param vmSKU string = 'Standard_DC8ads_cc_v5'

@description('Availability Zone')
@allowed([
  1
  2
  3
])
param vmAvailabilityZones array

@description('Admin Username')
param adminUsername string

@description('Admin Password')
@secure()
param adminPassword string

@description('Hub VNET resource ID to peer with')
param HubVnetResourceId string

@description('Azure Firewall Private IP address')
param AzFwPrivateIp string

var vnetName = '${prefix}-vnet'
var nsgSubnet1Name = '${prefix}-nsg-subnet1'
var nsgSubnet2Name = '${prefix}-nsg-subnet2'
var nsgSubnet3Name = '${prefix}-nsg-subnet3'
var udrname = '${prefix}-udr'
var vmName = '${prefix}-vm'

module nsgSubnet1 'br/public:avm/res/network/network-security-group:0.5.0' = {
  name: 'nsgSubnet1-deployment'
  params: {
    name: nsgSubnet1Name
    enableTelemetry: avmTelemetry
  }
}

module nsgSubnet2 'br/public:avm/res/network/network-security-group:0.5.0' = {
  name: 'nsgSubnet2-deployment'
  params: {
    name: nsgSubnet2Name
    enableTelemetry: avmTelemetry
  }
}

module nsgSubnet3 'br/public:avm/res/network/network-security-group:0.5.0' = {
  name: 'nsgSubnet3-deployment'
  params: {
    name: nsgSubnet3Name
    enableTelemetry: avmTelemetry
  }
}

module udr 'br/public:avm/res/network/route-table:0.4.0' = {
  name: 'udr-deployment'
  params: {
    name: udrname
    location: location
    disableBgpRoutePropagation: true
    enableTelemetry: avmTelemetry
    routes: [
      {
        name: 'toFirewall'
        properties: {
          nextHopType: 'VirtualAppliance'
          addressPrefix: '0.0.0.0/0'
          nextHopIpAddress: AzFwPrivateIp
        }
      }
    ]
  }
}

module vnet 'br/public:avm/res/network/virtual-network:0.4.0' = {
  name: 'vnet-deployment'
  params: {
    name: vnetName
    addressPrefixes: [
      ipAddressSpace
    ]
    location: location
    subnets: [
      {
        name: 'subnet1'
        addressPrefix: subnet1AddressPrefix
        networkSecurityGroupResourceId: nsgSubnet1.outputs.resourceId
        routeTableResourceId: udr.outputs.resourceId
      }
      {
        name: 'subnet2'
        addressPrefix: subnet2AddressPrefix
        networkSecurityGroupResourceId: nsgSubnet2.outputs.resourceId
        routeTableResourceId: udr.outputs.resourceId
      }
      {
        name: 'subnet3'
        addressPrefix: subnet3AddressPrefix
        networkSecurityGroupResourceId: nsgSubnet3.outputs.resourceId
        routeTableResourceId: udr.outputs.resourceId
      }
    ]
    enableTelemetry: avmTelemetry
    peerings: [
      {
        remoteVirtualNetworkResourceId: HubVnetResourceId
        remotePeeringEnabled: true
      }
    ]
  }
}

module vm 'br/public:avm/res/compute/virtual-machine:0.7.0' = [
  for (zone,i) in vmAvailabilityZones: {
    name: '${vmName}${zone}-deployment'
    params: {
      name: '${vmName}${zone}'
      adminUsername: adminUsername
      adminPassword: adminPassword
      imageReference: {
        offer: 'WindowsServer'
        publisher: 'MicrosoftWindowsServer'
        sku: '2022-datacenter-azure-edition'
        version: 'latest'
      }
      nicConfigurations: [
        {
          enableAcceleratedNetworking: true
          nicSuffix: '-nic'
          ipConfigurations: [
            {
              name: 'ipconfig1'
              subnetResourceId: '${vnet.outputs.resourceId}/subnets/subnet${zone}'
            }
          ]
        }
      ]
      osDisk: {
        name: '${vmName}${zone}-osdisk'
        caching: 'ReadWrite'
        diskSizeGB: 128
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
      encryptionAtHost: false
      location: location
      securityType: ''
      enableTelemetry: avmTelemetry
      osType: 'Windows'
      vmSize: vmSKU
      zone: zone
    }
  }
]

