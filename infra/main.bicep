// ClaimTouch export-html-pdf – deploy Container App only into an existing RG and CAE.
// Platform (RG, CAE, VNet, ACR, monitoring) lives in claimtouch/infra.
// Naming: ct-cta-<env>-htmlpdf-<regionShort>

targetScope = 'resourceGroup'

@description('Resource ID of the existing Container Apps managed environment')
param containerAppEnvironmentId string

@description('Container App name (e.g. ct-cta-stage-htmlpdf-eus)')
param containerAppName string

@description('Container image for the HTML→PDF service')
param containerAppImage string = 'claimtouch.azurecr.io/claimtouch/export-html-pdf:latest-stage'

@description('Container App CPU (Chrome needs ~2)')
param containerAppCpu string = '2'

@description('Container App memory in Gi (Chrome needs ~4)')
param containerAppMemory string = '4.0'

@description('Min replicas (0 = scale to zero)')
param minReplicas int = 0

@description('Max replicas')
param maxReplicas int = 10

@description('Ingress external traffic')
param ingressExternal bool = true

@description('ACR resource group (for AcrPull role assignment)')
param acrResourceGroupName string = 'ct-cta-prod-rg-eus'

@description('ACR registry name')
param acrName string = 'claimtouch'

resource acrPullIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${containerAppName}-acrpull'
  location: resourceGroup().location
}

module acrPullRoleAssignment './modules/acr-pull-role-assignment.bicep' = {
  scope: resourceGroup(acrResourceGroupName)
  name: 'acr-pull-role-assignment'
  params: {
    principalId: acrPullIdentity.properties.principalId
    acrName: acrName
  }
}

module containerApp './modules/container-app.bicep' = {
  name: 'container-app'
  params: {
    appName: containerAppName
    environmentId: containerAppEnvironmentId
    image: containerAppImage
    cpu: containerAppCpu
    memory: containerAppMemory
    targetPort: 2305
    minReplicas: minReplicas
    maxReplicas: maxReplicas
    ingressExternal: ingressExternal
    containerEnv: [
      {
        name: 'NODE_ENV'
        value: 'production'
      }
      {
        name: 'PORT'
        value: '2305'
      }
    ]
    registryIdentityId: acrPullIdentity.id
    acrServer: '${acrName}.azurecr.io'
  }
  dependsOn: [ acrPullRoleAssignment ]
}

output containerAppFqdn string = containerApp.outputs.fqdn
output containerAppName string = containerApp.outputs.appName
output containerAppPrincipalId string = containerApp.outputs.principalId
