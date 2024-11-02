targetScope = 'subscription'
@description('Azure region')
param location string = deployment().location

@description('Enable or Disable telemetry')
param avmTelemetry bool = false

param HubPrefix string = 'Hub'
param Spoke1Prefix string = 'Spoke1'
param Spoke2Prefix string = 'Spoke2'


@description('Admin Username')
param adminUsername string

@description('Admin Password')
@secure()
param adminPassword string

@description('vnet IP Address space')
param ipAddressSpace string = '10.0.0.0/8'

@description('Availability Zone')
@allowed([
  1
  2
  3
])
param vmAvailabilityZones array = [1,2,3]


var rgSpoke1Name = '${Spoke1Prefix}-rg'
var rgSpoke2Name = '${Spoke2Prefix}-rg'
var rgHubName = '${HubPrefix}-rg'

module rgHub 'br/public:avm/res/resources/resource-group:0.4.0' = {
  name: '${HubPrefix}-rg-deployment'
  params: {
    name: rgHubName
    location: location
    enableTelemetry: avmTelemetry
  }
}

module hub 'modules/hub.bicep' = {
  scope: resourceGroup(rgHubName)
  name: '${HubPrefix}-deployment'
  params: {
    location: location
    avmTelemetry: avmTelemetry
    ipAddressSpace: cidrSubnet(ipAddressSpace,16,0)
    prefix: HubPrefix
    vmAvailabilityZones: vmAvailabilityZones
  }
  dependsOn: [
    rgHub
  ]
}

module rgSpoke1 'br/public:avm/res/resources/resource-group:0.4.0' = {
  name: '${Spoke1Prefix}-rg-deployment'
  params: {
    name: rgSpoke1Name
    location: location
    enableTelemetry: avmTelemetry
  }
}

module Spoke1 'modules/spokeVMs.bicep' = {
  scope: resourceGroup(rgSpoke1Name)
  name: 'spoke1-deployment'
  params: {
    location: location
    adminPassword: adminPassword
    adminUsername: adminUsername
    avmTelemetry: avmTelemetry
    ipAddressSpace: cidrSubnet(ipAddressSpace,16,1)
    prefix: Spoke1Prefix
    vmAvailabilityZones: vmAvailabilityZones
    HubVnetResourceId: hub.outputs.vnetResourceId
    AzFwPrivateIp: hub.outputs.AzFwPrivateIp
  }
  dependsOn: [
    rgSpoke1
  ]
}

module rgSpoke2 'br/public:avm/res/resources/resource-group:0.4.0' = {
  name: '${Spoke2Prefix}-rg-deployment'
  params: {
    name: rgSpoke2Name
    location: location
    enableTelemetry: avmTelemetry
  }
}

module Spoke2 'modules/spokeVMs.bicep' = {
  scope: resourceGroup(rgSpoke2Name)
  name: 'spoke2-deployment'
  params: {
    location: location
    adminPassword: adminPassword
    adminUsername: adminUsername
    avmTelemetry: avmTelemetry
    ipAddressSpace: cidrSubnet(ipAddressSpace,16,2)
    prefix: Spoke2Prefix
    vmAvailabilityZones: vmAvailabilityZones
    HubVnetResourceId: hub.outputs.vnetResourceId
    AzFwPrivateIp: hub.outputs.AzFwPrivateIp
  }
  dependsOn: [
    rgSpoke2
  ]
}
