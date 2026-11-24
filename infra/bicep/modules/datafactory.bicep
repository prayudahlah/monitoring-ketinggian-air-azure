param name string
param location string
param storageAccountId string
param synapseId string
param mlWorkspaceId string
param tags object = {}

var synapseName = last(split(synapseId, '/'))
var mlWorkspaceName = last(split(mlWorkspaceId, '/'))

resource factory 'Microsoft.DataFactory/factories@2018-06-01' = {
  name: name
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publicNetworkAccess: 'Enabled'
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: last(split(storageAccountId, '/'))
}

resource synapseWorkspace 'Microsoft.Synapse/workspaces@2021-06-01' existing = {
  name: synapseName
}

resource mlWorkspace 'Microsoft.MachineLearningServices/workspaces@2024-10-01' existing = {
  name: mlWorkspaceName
}

resource storageRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccountId, factory.id, 'Storage Blob Data Contributor')
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
    )
    principalId: factory.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource synapseRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(synapseId, factory.id, 'Contributor')
  scope: synapseWorkspace
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      'b24988ac-6180-42a0-ab88-20f7382dd24c'
    )
    principalId: factory.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource mlRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(mlWorkspaceId, factory.id, 'AzureML Data Scientist')
  scope: mlWorkspace
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      'f6c7c914-8db3-469d-8ca1-694a8f32e121'
    )
    principalId: factory.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

output id string = factory.id
output name string = factory.name
output principalId string = factory.identity.principalId
