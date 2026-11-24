param name string
param location string
param storageAccountName string
param storageAccountId string
param tags object = {}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageAccountName
}

resource workspace 'Microsoft.Synapse/workspaces@2021-06-01' = {
  name: name
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    defaultDataLakeStorage: {
      accountUrl: 'https://${storageAccountName}.dfs.${environment().suffixes.storage}'
      filesystem: 'synapse'
    }
    managedResourceGroupName: 'rg-${name}-managed'
    publicNetworkAccess: 'Enabled'
    azureADOnlyAuthentication: false
  }
}

resource sparkPool 'Microsoft.Synapse/workspaces/bigDataPools@2021-06-01' = {
  parent: workspace
  name: 'sparksmall'
  location: location
  properties: {
    nodeSize: 'Small'
    nodeSizeFamily: 'MemoryOptimized'
    nodeCount: 3
    sparkVersion: '3.5'
    autoScale: {
      enabled: false
    }
    autoPause: {
      enabled: true
      delayInMinutes: 15
    }
    dynamicExecutorAllocation: {
      enabled: false
    }
    sessionLevelPackagesEnabled: true
    cacheSize: 50
  }
}

resource storageRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccountId, workspace.id, 'Storage Blob Data Contributor')
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
    )
    principalId: workspace.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

output id string = workspace.id
output name string = workspace.name
output principalId string = workspace.identity.principalId
output devEndpoint string = 'https://${workspace.name}.dev.azuresynapse.net'
