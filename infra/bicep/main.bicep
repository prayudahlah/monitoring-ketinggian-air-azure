targetScope = 'subscription'

@description('Azure region for every resource. The subscription policy only allows a small set of regions; eastasia supports Synapse and Azure ML.')
param location string = 'eastasia'

@description('Short name prefix used by every resource.')
param prefix string = 'hidrologi-v0'

@description('Email that receives budget alerts.')
param alertEmail string = 'yudafihan@student.uns.ac.id'

@description('Monthly budget in USD.')
param budgetAmount int = 40

@description('First day of the budget period. Must be the first day of a month.')
param budgetStartDate string = '2026-11-01'

var tags = {
  project: 'monitoring-ketinggian-air'
  environment: 'v0'
}

var rgName = 'rg-${prefix}'
var suffix = uniqueString(subscription().subscriptionId, rgName)
var storageName = 'sthidro${suffix}'
var mlStorageName = 'stml${suffix}'
var acrName = 'acrhidro${suffix}'
var keyVaultName = 'kv-hidro-${suffix}'
var logName = 'log-${prefix}'
var appInsightsName = 'appi-${prefix}'
var synapseName = 'syn-${prefix}'
var adfName = 'adf-${prefix}'
var mlName = 'mlw-${prefix}'

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: rgName
  location: location
  tags: tags
}

module storage 'modules/storage.bicep' = {
  scope: rg
  name: 'storage'
  params: {
    name: storageName
    location: location
    tags: tags
  }
}

module mlStorage 'modules/mlstorage.bicep' = {
  scope: rg
  name: 'mlstorage'
  params: {
    name: mlStorageName
    location: location
    tags: tags
  }
}

module keyVault 'modules/keyvault.bicep' = {
  scope: rg
  name: 'keyvault'
  params: {
    name: keyVaultName
    location: location
    tenantId: subscription().tenantId
    storageAccountName: storageName
    tags: tags
  }
}

module acr 'modules/acr.bicep' = {
  scope: rg
  name: 'acr'
  params: {
    name: acrName
    location: location
    tags: tags
  }
}

module logAnalytics 'modules/loganalytics.bicep' = {
  scope: rg
  name: 'loganalytics'
  params: {
    name: logName
    location: location
    tags: tags
  }
}

module appInsights 'modules/appinsights.bicep' = {
  scope: rg
  name: 'appinsights'
  params: {
    name: appInsightsName
    location: location
    logAnalyticsId: logAnalytics.outputs.id
    tags: tags
  }
}

module synapse 'modules/synapse.bicep' = {
  scope: rg
  name: 'synapse'
  params: {
    name: synapseName
    location: location
    storageAccountName: storageName
    storageAccountId: storage.outputs.id
    tags: tags
  }
}

module dataFactory 'modules/datafactory.bicep' = {
  scope: rg
  name: 'datafactory'
  params: {
    name: adfName
    location: location
    storageAccountId: storage.outputs.id
    synapseId: synapse.outputs.id
    mlWorkspaceId: ml.outputs.id
    tags: tags
  }
}

module ml 'modules/ml.bicep' = {
  scope: rg
  name: 'ml'
  params: {
    name: mlName
    location: location
    storageAccountName: storageName
    mlStorageAccountId: mlStorage.outputs.id
    keyVaultId: keyVault.outputs.id
    appInsightsId: appInsights.outputs.id
    acrId: acr.outputs.id
    tags: tags
  }
}

module budget 'modules/budget.bicep' = {
  scope: rg
  name: 'budget'
  params: {
    name: 'budget-${prefix}'
    amount: budgetAmount
    startDate: budgetStartDate
    alertEmail: alertEmail
  }
}

output resourceGroupName string = rgName
output location string = location
output storageAccountName string = storage.outputs.name
output storageAccountId string = storage.outputs.id
output acrName string = acr.outputs.name
output acrLoginServer string = acr.outputs.loginServer
output keyVaultName string = keyVault.outputs.name
output keyVaultUri string = keyVault.outputs.uri
output logAnalyticsId string = logAnalytics.outputs.id
output logAnalyticsCustomerId string = logAnalytics.outputs.customerId
output appInsightsId string = appInsights.outputs.id
output synapseName string = synapse.outputs.name
output synapsePrincipalId string = synapse.outputs.principalId
output dataFactoryName string = dataFactory.outputs.name
output dataFactoryPrincipalId string = dataFactory.outputs.principalId
output mlWorkspaceName string = ml.outputs.name
output mlWorkspacePrincipalId string = ml.outputs.principalId
output mlflowTrackingUri string = ml.outputs.mlflowTrackingUri
