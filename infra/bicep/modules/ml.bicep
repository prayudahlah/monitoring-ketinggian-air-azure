param name string
param location string
param storageAccountName string
param mlStorageAccountId string
param keyVaultId string
param appInsightsId string
param acrId string
param tags object = {}

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: last(split(acrId, '/'))
}

resource workspace 'Microsoft.MachineLearningServices/workspaces@2024-10-01' = {
  name: name
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: 'Basic'
  }
  properties: {
    friendlyName: name
    storageAccount: mlStorageAccountId
    keyVault: keyVaultId
    applicationInsights: appInsightsId
    containerRegistry: acrId
    publicNetworkAccess: 'Enabled'
  }
}

resource compute 'Microsoft.MachineLearningServices/workspaces/computes@2024-10-01' = {
  parent: workspace
  name: 'cpu-cluster'
  location: location
  properties: {
    computeType: 'AmlCompute'
    properties: {
      vmSize: 'STANDARD_DS3_v2'
      vmPriority: 'Dedicated'
      scaleSettings: {
        minNodeCount: 0
        maxNodeCount: 2
        nodeIdleTimeBeforeScaleDown: 'PT5M'
      }
      osType: 'Linux'
      enableNodePublicIp: true
      remoteLoginPortPublicAccess: 'Disabled'
    }
  }
}

resource goldDatastore 'Microsoft.MachineLearningServices/workspaces/datastores@2024-10-01' = {
  parent: workspace
  name: 'adls_gold'
  properties: {
    datastoreType: 'AzureDataLakeGen2'
    accountName: storageAccountName
    filesystem: 'gold'
    endpoint: environment().suffixes.storage
    protocol: 'https'
    credentials: {
      credentialsType: 'None'
    }
    description: 'Gold Delta tables used by training and prediction.'
  }
}

resource acrRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acrId, workspace.id, 'AcrPull')
  scope: containerRegistry
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '7f951dda-4ed3-4680-a7ca-43fe172d538d'
    )
    principalId: workspace.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

output id string = workspace.id
output name string = workspace.name
output principalId string = workspace.identity.principalId
output mlflowTrackingUri string = 'https://${location}.api.azureml.ms/mlflow/v1.0/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.MachineLearningServices/workspaces/${workspace.name}'
