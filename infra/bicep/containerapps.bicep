// Container Apps Consumption environment for API and dashboard.
// The express/consumption environment does not support system-assigned
// identity for ACR pull, so a user-assigned identity is used for AcrPull.
// The system-assigned identity still handles storage, Key Vault and Azure ML.
param name string
param location string
param apiName string
param dashboardName string
param apiImage string
param dashboardImage string
param logAnalyticsName string
param acrName string
param acrLoginServer string
param storageAccountName string
param keyVaultName string
param keyVaultUri string
param mlWorkspaceName string
param mlflowTrackingUri string
param tags object = {}

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: logAnalyticsName
}

resource registry 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: acrName
}

resource acrIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-hidrologi-acr'
  location: location
  tags: tags
}

resource acrIdentityRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(registry.id, acrIdentity.id, 'AcrPull')
  scope: registry
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '7f951dda-4ed3-4680-a7ca-43fe172d538d'
    )
    principalId: acrIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource goldContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' existing = {
  name: '${storageAccountName}/default/gold'
}

resource vault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

resource mlWorkspace 'Microsoft.MachineLearningServices/workspaces@2024-10-01' existing = {
  name: mlWorkspaceName
}

resource environment 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalytics.properties.customerId
        sharedKey: logAnalytics.listKeys().primarySharedKey
      }
    }
    zoneRedundant: false
  }
}

resource api 'Microsoft.App/containerApps@2024-03-01' = {
  name: apiName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned, UserAssigned'
    userAssignedIdentities: {
      '${acrIdentity.id}': {}
    }
  }
  properties: {
    managedEnvironmentId: environment.id
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: 8000
        transport: 'http'
        allowInsecure: false
      }
      registries: [
        {
          server: acrLoginServer
          identity: acrIdentity.id
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'api'
          image: apiImage
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
          env: [
            {
              name: 'ENVIRONMENT'
              value: 'azure-v0'
            }
            {
              name: 'AZURE_STORAGE_ACCOUNT'
              value: storageAccountName
            }
            {
              name: 'AZURE_STORAGE_CONTAINER'
              value: 'gold'
            }
            {
              name: 'KEY_VAULT_URI'
              value: keyVaultUri
            }
            {
              name: 'MLFLOW_TRACKING_URI'
              value: mlflowTrackingUri
            }
            {
              name: 'MLFLOW_MODEL_NAME'
              value: 'hydrology-lightgbm'
            }
          ]
        }
      ]
      scale: {
        minReplicas: 0
        maxReplicas: 2
      }
    }
  }
}

resource dashboard 'Microsoft.App/containerApps@2024-03-01' = {
  name: dashboardName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned, UserAssigned'
    userAssignedIdentities: {
      '${acrIdentity.id}': {}
    }
  }
  properties: {
    managedEnvironmentId: environment.id
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: 8501
        transport: 'http'
        allowInsecure: false
      }
      registries: [
        {
          server: acrLoginServer
          identity: acrIdentity.id
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'dashboard'
          image: dashboardImage
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          env: [
            {
              name: 'ENVIRONMENT'
              value: 'azure-v0'
            }
            {
              name: 'AZURE_STORAGE_ACCOUNT'
              value: storageAccountName
            }
            {
              name: 'AZURE_STORAGE_CONTAINER'
              value: 'gold'
            }
            {
              name: 'KEY_VAULT_URI'
              value: keyVaultUri
            }
            {
              name: 'MLFLOW_TRACKING_URI'
              value: mlflowTrackingUri
            }
            {
              name: 'MLFLOW_MODEL_NAME'
              value: 'hydrology-lightgbm'
            }
          ]
        }
      ]
      scale: {
        minReplicas: 0
        maxReplicas: 1
      }
    }
  }
}

resource apiStorageRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(goldContainer.id, api.id, 'Storage Blob Data Reader')
  scope: goldContainer
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
    )
    principalId: api.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource dashboardStorageRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(goldContainer.id, dashboard.id, 'Storage Blob Data Reader')
  scope: goldContainer
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
    )
    principalId: dashboard.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource apiKeyVaultRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(vault.id, api.id, 'Key Vault Secrets User')
  scope: vault
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '4633458b-17de-408a-b874-0445c86b69e6'
    )
    principalId: api.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource dashboardKeyVaultRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(vault.id, dashboard.id, 'Key Vault Secrets User')
  scope: vault
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '4633458b-17de-408a-b874-0445c86b69e6'
    )
    principalId: dashboard.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource apiMlRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(mlWorkspace.id, api.id, 'AzureML Data Scientist')
  scope: mlWorkspace
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      'f6c7c914-8db3-469d-8ca1-694a8f32e121'
    )
    principalId: api.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource dashboardMlRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(mlWorkspace.id, dashboard.id, 'AzureML Data Scientist')
  scope: mlWorkspace
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      'f6c7c914-8db3-469d-8ca1-694a8f32e121'
    )
    principalId: dashboard.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

output apiFqdn string = api.properties.configuration.ingress.fqdn
output dashboardFqdn string = dashboard.properties.configuration.ingress.fqdn
output apiPrincipalId string = api.identity.principalId
output dashboardPrincipalId string = dashboard.identity.principalId
