// Azure Container App for export-html-pdf

@description('Container App name')
param appName string

@description('Resource ID of the Container Apps managed environment')
param environmentId string

@description('Container image (e.g. claimtouch.azurecr.io/claimtouch/export-html-pdf:latest-stage)')
param image string

@description('CPU cores (e.g. 2)')
param cpu string = '2'

@description('Memory in Gi (e.g. 4.0)')
param memory string = '4.0'

@description('Ingress external traffic: true for public, false for internal only')
param ingressExternal bool = true

@description('Target port the container listens on')
param targetPort int = 2305

@description('Optional env vars as key-value array')
param containerEnv array = []

@description('User-assigned identity resource ID for ACR pull (optional). When set with acrServer, configures registry auth.')
param registryIdentityId string = ''

@description('ACR server host (e.g. claimtouch.azurecr.io). When set with registryIdentityId, configures registry auth.')
param acrServer string = ''

@description('Min replicas')
param minReplicas int = 0

@description('Max replicas')
param maxReplicas int = 10

var containerResources = { cpu: json(cpu), memory: '${memory}Gi' }

var useRegistryIdentity = !empty(registryIdentityId) && !empty(acrServer)
var appIdentity = useRegistryIdentity ? {
  type: 'SystemAssigned, UserAssigned'
  userAssignedIdentities: {
    '${registryIdentityId}': {}
  }
} : {
  type: 'SystemAssigned'
}
var registriesConfig = useRegistryIdentity ? [
  {
    server: acrServer
    identity: registryIdentityId
  }
] : []

resource containerApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: appName
  location: resourceGroup().location
  identity: appIdentity
  properties: {
    managedEnvironmentId: environmentId
    configuration: {
      ingress: {
        external: ingressExternal
        targetPort: targetPort
        transport: 'http'
        allowInsecure: false
      }
      registries: registriesConfig
    }
    template: {
      containers: [
        {
          name: 'main'
          image: image
          resources: containerResources
          env: containerEnv
        }
      ]
      scale: {
        minReplicas: minReplicas
        maxReplicas: maxReplicas
        rules: []
      }
    }
  }
}

output appId string = containerApp.id
output appName string = containerApp.name
output fqdn string = containerApp.properties.configuration.ingress.fqdn
output principalId string = containerApp.identity.principalId
