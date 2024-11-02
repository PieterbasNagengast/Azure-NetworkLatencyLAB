param location string

@description('Prefix Name')
@maxLength(6)
@minLength(3)
param prefix string

@description('Enable or Disable telemetry')
param avmTelemetry bool

@description('vnet IP Address space')
param ipAddressSpace string

@description('AzureFirewallSubnet IP address prefix')
param AzFwSubnetAddressPrefix string = cidrSubnet(ipAddressSpace, 26, 0)
@description('AzureBastionSubnet IP address prefix')
param AzBastionSubnetAddressPrefix string = cidrSubnet(ipAddressSpace, 26, 1)

@description('Availability Zone')
@allowed([
  1
  2
  3
])
param vmAvailabilityZones array

@description('Azure Firewall Tier')
@allowed([
  'Standard'
  'Premium'
])
param AzFwTier string = 'Premium'

var vnetName = '${prefix}-vnet'
var AzFwName = '${prefix}-FW'
var AzFwPolicyName = '${prefix}-FW-Policy'
var AzBastionName = '${prefix}-Bastion'

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
        name: 'AzureFirewallSubnet'
        addressPrefix: AzFwSubnetAddressPrefix
      }
      {
        name: 'AzureBastionSubnet'
        addressPrefix: AzBastionSubnetAddressPrefix
      }
    ]
    enableTelemetry: avmTelemetry
  }
}

module bastion 'br/public:avm/res/network/bastion-host:0.5.0' = {
  name: 'bastion-deployment'
  params: {
    name: AzBastionName
    location: location
    enableTelemetry: avmTelemetry
    virtualNetworkResourceId: vnet.outputs.resourceId
  }
}

module fwPolicy 'br/public:avm/res/network/firewall-policy:0.2.0' = {
  name: 'firewall-policy-deployment'
  params: {
    name: AzFwPolicyName
    location: location
    enableTelemetry: avmTelemetry
    tier: AzFwTier
    ruleCollectionGroups: [
      {
        nme: 'DefaultNetworkRuleCollectionGroup'
        priority: 100
        ruleCollections: [
          {
            name: 'ALLOW-NetworkRuleCollection'
            priority: 100
            action: {
              type: 'Allow'
            }
            ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
            rules: [
              {
                name: 'ALLOW-ALL'
                ruleType: 'NetworkRule'
                destinationAddresses: [
                  '*'
                ]
                destinationPorts: [
                  '*'
                ]
                destinationFqdns: []
                destinationIpGroups: []
                ipProtocols: [
                  'TCP'
                  'UDP'
                  'ICMP'
                ]
                sourceAddresses: [
                  '*'
                ]
                sourceIpGroups: []
                ruleAction: {
                  type: 'Allow'
                }
              }
            ]
          }
        ]
      }
    ]
  }
}

module fw 'br/public:avm/res/network/azure-firewall:0.5.1' = {
  name: 'firewall-deployment'
  params: {
    name: AzFwName
    location: location
    enableTelemetry: avmTelemetry
    firewallPolicyId: fwPolicy.outputs.resourceId
    zones: vmAvailabilityZones
    azureSkuTier: AzFwTier
    virtualNetworkResourceId: vnet.outputs.resourceId
  }
}

output vnetResourceId string = vnet.outputs.resourceId
output AzFwPrivateIp string = fw.outputs.privateIp
