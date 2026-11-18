// Assigns AcrPull to a principal (e.g. Container App managed identity) on an ACR in this resource group.
// Deploy with scope: resourceGroup(acrResourceGroupName) so the ACR is in scope.

@description('Principal ID (e.g. Container App managed identity) to grant AcrPull')
param principalId string

@description('ACR registry name in this resource group')
param acrName string

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: acrName
}

resource acrPullRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: '7f951dda-4ed3-4680-a7ca-43fe172d538d' // AcrPull built-in role
}

resource containerAppAcrPull 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: acr
  name: guid(acr.id, principalId, acrPullRoleDefinition.id)
  properties: {
    roleDefinitionId: acrPullRoleDefinition.id
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}
