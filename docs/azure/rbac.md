# RBAC Azure

## Workload identity

| Principal | Role | Scope |
|---|---|---|
| Synapse MI | Storage Blob Data Contributor | Storage account |
| Synapse MI | Key Vault Secrets User | Key Vault |
| Synapse MI | AzureML Data Scientist | ML workspace |
| Azure ML MI | Storage Blob Data Contributor | Storage account |
| Azure ML MI | AcrPull | ACR |
| ADF MI | Storage Blob Data Contributor | Storage account |
| ADF MI | Contributor + Synapse Administrator | Synapse |
| ADF MI | AzureML Data Scientist | ML workspace |
| ADF MI | Key Vault Secrets User | Key Vault |
| API MI | Storage Blob Data Reader | Container `gold` |
| API MI | Key Vault Secrets User | Key Vault |
| API MI | AzureML Data Scientist | ML workspace |
| Dashboard MI | Storage Blob Data Reader | Container `gold` |
| Dashboard MI | Key Vault Secrets User | Key Vault |
| Dashboard MI | AzureML Data Scientist | ML workspace |
| `id-hidrologi-acr` | AcrPull | ACR |
| OIDC SP | Contributor | Resource group |
| OIDC SP | AcrPush | ACR |

## Human access

| Principal | Role | Scope |
|---|---|---|
| 4 anggota kelompok | Owner | Subscription |
| 4 anggota kelompok | Key Vault Secrets User | Key Vault |

Owner subscription tidak memberi akses data plane ke Key Vault. Role
`Key Vault Secrets User` diberikan terpisah ke semua anggota.

## Developer personas

Subscription masih dimiliki 4 anggota kelompok sebagai Owner. Role per orang
tidak bisa menurunkan Owner. Tabel ini adalah target state kalau proyek punya
subscription sendiri.

| Persona | Target Azure role | GitHub |
|---|---|---|
| Platform/DevOps | Contributor RG, AcrPush, Monitoring Reader | CODEOWNERS `infra/`, `.github/` |
| Data engineer | Storage Blob Data Contributor, Synapse Administrator, ADF Contributor | CODEOWNERS `synapse/`, `adf/` |
| ML engineer | AzureML Data Scientist, Storage Blob Data Contributor gold | CODEOWNERS `azureml/` |
| App developer | Container Apps Contributor, Storage Blob Data Reader gold, Key Vault Secrets User | CODEOWNERS `serving/` |

## Catatan laporan

- RBAC sistem ditegakkan pada workload identity.
- Human access masih inherited Owner dari subscription bersama.
- Semua anggota sudah punya `Key Vault Secrets User`.
- OIDC SP bisa dipersempit dari Contributor RG menjadi Container Apps
  Contributor pada dua app + AcrPush.
- Belum ada private endpoint.
