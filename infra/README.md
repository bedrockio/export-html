# Azure infrastructure (Bicep)

Deploys the ClaimTouch **export-html-pdf** Container App into an **existing** resource group and Container App Environment.

Only the Container App and its ACR pull identity are created by this repo.

Platform resources (resource groups, networking, CAE, ACR, monitoring, DR) live in [`claimtouch/infra`](https://github.com/claimtouch/infra). Do not add CAE/VNet/Postgres templates here.

## Prerequisites

- Platform already provisioned (`claimtouch/infra`)
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) installed and logged in
- Contributor on the app resource group; User Access Administrator on the ACR RG for AcrPull

## Quick start

```bash
./scripts/azure-setup.sh
```

| Environment | Resource group | CAE | Container App |
| --- | --- | --- | --- |
| stage | `claimtouch-stage` | `ct-cta-stage-cae-eus` | `ct-cta-stage-htmlpdf-eus` |
| qa | `ct-claims-qa-rg-eus` | `ct-claims-qa-cae-eus` | `ct-cta-qa-htmlpdf-eus` |
| prod | `ct-cta-prod-rg-eus` | `ct-cta-prod-cae-eus` | `ct-cta-prod-htmlpdf-eus` |

## Layout

| Path | Purpose |
| --- | --- |
| `infra/main.bicep` | Container App + AcrPull only |
| `infra/modules/container-app.bicep` | Container App resource (port 2305, 2 CPU / 4Gi defaults) |
| `infra/modules/acr-pull-role-assignment.bicep` | AcrPull on `claimtouch` ACR |
| `scripts/azure-setup.sh` | Interactive first-time Container App deploy |
| `scripts/azure-naming.sh` | Shared `ct-cta-*-htmlpdf-*` naming |
| `.github/workflows/deploy.yml` | Build, push to ACR, deploy by digest |

## GitHub Actions

| Workflow | Trigger | Purpose |
| --- | --- | --- |
| `build-test.yml` | Pull request | Install deps + lint |
| `verify-tag.yml` | Push tag `v*.*.*` | Verify signed release tags |
| `deploy.yml` | Manual (`workflow_dispatch`) | Build, push to ACR, deploy Container App by digest |

### Deploy workflow

| Environment | Container App | Resource group |
| --- | --- | --- |
| production | `ct-cta-prod-htmlpdf-eus` | `ct-cta-prod-rg-eus` |
| qa | `ct-cta-qa-htmlpdf-eus` | `ct-claims-qa-rg-eus` |
| stage | `ct-cta-stage-htmlpdf-eus` | `claimtouch-stage` |

Image: `claimtouch.azurecr.io/claimtouch/export-html-pdf` (tags: commit SHA for stage/qa, signed `v*.*.*` for production, plus `latest-<env>`).

Repository secrets (same as other Claimtouch services): `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`.  
For production tag verification: `GPG_PUBLIC_KEYS`, `ALLOWED_GPG_FPRS`.
