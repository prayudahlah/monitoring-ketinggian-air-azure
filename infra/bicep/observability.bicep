
param synapseName string = 'syn-hidrologi-v0'
param keyVaultName string = 'kv-hidro-gkiq7v7oc3lns'
param mlWorkspaceName string = 'mlw-hidrologi-v0'
param dataFactoryName string = 'adf-hidrologi-v0'
param logAnalyticsName string = 'log-hidrologi-v0'
param alertEmail string = 'yudafihan@student.uns.ac.id'

resource synapse 'Microsoft.Synapse/workspaces@2021-06-01' existing = {
  name: synapseName
}

resource vault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

resource mlWorkspace 'Microsoft.MachineLearningServices/workspaces@2024-10-01' existing = {
  name: mlWorkspaceName
}

resource factory 'Microsoft.DataFactory/factories@2018-06-01' existing = {
  name: dataFactoryName
}

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: logAnalyticsName
}

resource synapseKeyVaultRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(vault.id, synapse.id, 'Key Vault Secrets User')
  scope: vault
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '4633458b-17de-408a-b874-0445c86b69e6'
    )
    principalId: synapse.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource synapseMlRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(mlWorkspace.id, synapse.id, 'AzureML Data Scientist')
  scope: mlWorkspace
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      'f6c7c914-8db3-469d-8ca1-694a8f32e121'
    )
    principalId: synapse.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: 'ag-hidrologi-v0'
  location: 'global'
  properties: {
    groupShortName: 'hidrologi'
    enabled: true
    emailReceivers: [
      {
        name: 'admin'
        emailAddress: alertEmail
        useCommonAlertSchema: true
      }
    ]
  }
}

resource adfFailureAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-adf-pipeline-failed'
  location: 'global'
  properties: {
    description: 'ADF pipeline failed runs'
    severity: 2
    enabled: true
    scopes: [
      factory.id
    ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'PipelineFailedRuns'
          metricName: 'PipelineFailedRuns'
          operator: 'GreaterThan'
          threshold: 0
          timeAggregation: 'Total'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroup.id
      }
    ]
  }
}

resource adfDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag-adf-to-log'
  scope: factory
  properties: {
    workspaceId: logAnalytics.id
    logs: [
      {
        category: 'PipelineRuns'
        enabled: true
      }
      {
        category: 'ActivityRuns'
        enabled: true
      }
      {
        category: 'TriggerRuns'
        enabled: true
      }
    ]
  }
}

resource synapseDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag-synapse-to-log'
  scope: synapse
  properties: {
    workspaceId: logAnalytics.id
    logs: [
      {
        category: 'IntegrationPipelineRuns'
        enabled: true
      }
      {
        category: 'IntegrationActivityRuns'
        enabled: true
      }
      {
        category: 'IntegrationTriggerRuns'
        enabled: true
      }
    ]
  }
}

output actionGroupId string = actionGroup.id
output adfAlertId string = adfFailureAlert.id
