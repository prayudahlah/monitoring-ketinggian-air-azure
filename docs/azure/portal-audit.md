# Portal audit - Azure

Untuk AI agent, mulai dari `docs/azure/agent-handover.md`.

Panduan memeriksa isi komponen Azure lewat portal. Semua langkah read-only.
Jangan klik **Run**, **Debug**, **Trigger now**, atau **Submit job**.

## 1. Resource group

**Resource groups > rg-hidrologi-v0 > Overview**

Resource yang harus terlihat:

- `sthidrogkiq7v7oc3lns`
- `stmlgkiq7v7oc3lns`
- `kv-hidro-gkiq7v7oc3lns`
- `acrhidrogkiq7v7oc3lns`
- `log-hidrologi-v0`
- `appi-hidrologi-v0`
- `syn-hidrologi-v0`
- `adf-hidrologi-v0`
- `mlw-hidrologi-v0`
- `cae-hidrologi-v0`
- `ca-api-hidrologi`
- `ca-dash-hidrologi`
- `id-hidrologi-acr`
- `ag-hidrologi-v0`
- `alert-adf-pipeline-failed`

## 2. Storage

**Storage accounts > sthidrogkiq7v7oc3lns > Data storage > Containers**

Container:

```text
bronze
silver
gold
synapse
```

Semua harus kosong.

**Settings > Configuration**

- Hierarchical namespace: Enabled
- Allow storage account key access: Disabled
- Minimum TLS version: 1.2

## 3. Key Vault

Semua anggota kelompok sudah diberi role `Key Vault Secrets User`. Owner
subscription saja tidak memberi akses isi Key Vault.

Jika masih muncul pesan **not allowed by RBAC**:

1. Tunggu 5 sampai 10 menit.
2. Refresh portal.
3. Jika masih gagal, minta admin memeriksa role assignment.

Jangan mencoba membaca value secret.

Setelah itu buka:

**Objects > Secrets**

Harus ada:

```text
storage-account
```

Selain itu akan ada beberapa secret dengan nama UUID dan content type
`application/vnd.ms-StorageAccountAccessKey`. Itu dibuat otomatis oleh Azure
ML untuk datastore. Jangan hapus secret tersebut.

Jangan buka value secret.

**Access control (IAM) > Role assignments** harus memuat:

- `mlw-hidrologi-v0` sebagai Key Vault Administrator
- `adf-hidrologi-v0` sebagai Key Vault Secrets User
- `syn-hidrologi-v0` sebagai Key Vault Secrets User
- `ca-api-hidrologi` sebagai Key Vault Secrets User
- `ca-dash-hidrologi` sebagai Key Vault Secrets User

## 4. ACR

**Container registries > acrhidrogkiq7v7oc3lns > Repositories**

Repository:

```text
api
dashboard
training
```

Tag:

```text
api: v0, v1
dashboard: v0, v1
training: v0, v1
```

**Settings > Properties**

- Admin user: Disabled
- SKU: Basic

**Access control (IAM) > Role assignments**

- `id-hidrologi-acr`: AcrPull
- `mlw-hidrologi-v0`: AcrPull
- `gh-hidrologi-v0`: AcrPush

## 5. Synapse

**Azure Synapse Analytics > syn-hidrologi-v0 > Open Synapse Studio**

### Develop

**Develop > Notebooks**

```text
01_ingest
02_silver
03_gold
04_predict
```

Buka `02_silver`. Kode transformasi harus terlihat di cell.

Parameter cell berisi default:

```python
window_start = "2015-10-01"
window_end = "2015-10-31"
```

Default ini hanya untuk run langsung dari notebook. Saat dipanggil pipeline,
nilai dari pipeline menimpa parameter cell. Code cell tidak meng-assign ulang
nilai default.

### Integrate

**Integrate > Pipelines > pl_daily_hidrologi_syn**

```text
ingest_bronze -> transform_silver -> build_gold -> predict
```

### Manage

**Manage > Apache Spark pools > sparksmall**

- Node size: Small
- Node count: 3
- Spark version: 3.5
- Auto-pause: 15 minutes
- Status: Succeeded

**Manage > Access control**: `adf-hidrologi-v0` memiliki Synapse Administrator.

**Monitor**: belum ada pipeline run.

## 6. ADF

**Data factories > adf-hidrologi-v0 > Open Azure Data Factory Studio**

### Author

**Author > Pipelines > pl_daily_hidrologi**

```text
start_synapse
set_run_id
wait_for_synapse
fail_if_not_success
```

`wait_for_synapse` adalah Until loop yang memeriksa status Synapse setiap
60 detik.

### Manage

**Manage > Linked services**

```text
ls_adls
ls_synapse
ls_keyvault
ls_azureml
```

Klik `ls_synapse`. Authentication harus Managed identity dan workspace
resource ID mengarah ke `syn-hidrologi-v0`.

**Manage > Triggers**

`tr_daily_0600_wib` harus **Stopped**.

Jangan klik Trigger now atau Debug.

### Monitor

**Monitor > Pipeline runs** harus kosong.

## 7. Azure ML

**Azure Machine Learning > mlw-hidrologi-v0 > Launch studio**

### Compute

**Compute > Compute clusters > cpu-cluster**

- Minimum nodes: 0
- Maximum nodes: 2

### Environments

**Environments > hydrology-training > v1**

Image:

```text
acrhidrogkiq7v7oc3lns.azurecr.io/training:v1
```

### Data

**Data > Datastores > adls_gold**

Storage account `sthidrogkiq7v7oc3lns`, filesystem `gold`.

### Jobs dan Models

- **Jobs**: kosong
- **Models**: kosong

### MLflow

MLflow tracking URI:

```text
azureml://eastasia.api.azureml.ms/mlflow/v1.0/subscriptions/838d94c7-d2fd-4c8c-8ceb-ad3ce9dfc707/resourceGroups/rg-hidrologi-v0/providers/Microsoft.MachineLearningServices/workspaces/mlw-hidrologi-v0
```

## 8. Container Apps

**Container Apps > cae-hidrologi-v0 > Apps**

### ca-api-hidrologi

- Image: `api:v1`
- Scale: min 0, max 2
- Identity: system-assigned + `id-hidrologi-acr`
- Ingress: external, port 8000

URL:

```text
https://ca-api-hidrologi.thankfulrock-98208269.eastasia.azurecontainerapps.io/health
https://ca-api-hidrologi.thankfulrock-98208269.eastasia.azurecontainerapps.io/stations
```

### ca-dash-hidrologi

- Image: `dashboard:v1`
- Scale: min 0, max 1
- Ingress: external, port 8501

URL:

```text
https://ca-dash-hidrologi.thankfulrock-98208269.eastasia.azurecontainerapps.io/
```

### IAM

- `ca-api-hidrologi`: Storage Blob Data Reader, Key Vault Secrets User, AzureML Data Scientist
- `ca-dash-hidrologi`: Storage Blob Data Reader, Key Vault Secrets User, AzureML Data Scientist
- `id-hidrologi-acr`: AcrPull

## 9. Monitoring dan budget

**Log Analytics workspaces > log-hidrologi-v0 > Logs**

Query opsional:

```text
ADFPipelineRun | take 10
SynapseIntegrationPipelineRuns | take 10
ContainerAppConsoleLogs_CL | take 10
```

**Azure Monitor > Alerts**

`alert-adf-pipeline-failed` harus enabled, severity 2.

**Azure Monitor > Action groups**

`ag-hidrologi-v0` harus berisi email `yudafihan@student.uns.ac.id`.

**Cost Management > Budgets**

`budget-hidrologi-v0`, amount $40, alert 50/80/100%.

## 10. Identity dan CI/CD

**Microsoft Entra ID > App registrations > gh-hidrologi-v0 > Certificates & secrets > Federated credentials**

```text
github-dev
github-prayudahlah-azure
```

**Resource groups > rg-hidrologi-v0 > Access control (IAM)**

`gh-hidrologi-v0`:

- Contributor pada resource group
- AcrPush pada ACR

GitHub:

```text
https://github.com/prayudahlah/monitoring-ketinggian-air-azure
```

Run `azure-ci` terakhir harus success. Job `images` dan `serving` harus skipped.

## Interkonektivitas

| Dari | Ke | Mekanisme |
|---|---|---|
| ADF | Synapse | `ls_synapse` + Synapse Administrator |
| ADF | ADLS | `ls_adls` + Storage Blob Data Contributor |
| ADF | Key Vault | `ls_keyvault` + Secrets User |
| ADF | Azure ML | `ls_azureml` + AzureML Data Scientist |
| Synapse | ADLS | Workspace MI + Storage Blob Data Contributor |
| Synapse | Key Vault | Workspace MI + Secrets User |
| Synapse | Azure ML | Workspace MI + AzureML Data Scientist |
| Azure ML | ADLS | Workspace MI + datastore `adls_gold` |
| Azure ML | ACR | Workspace MI + AcrPull |
| Container Apps | ACR | `id-hidrologi-acr` + AcrPull |
| Container Apps | gold | System MI + Storage Blob Data Reader |
| Container Apps | Key Vault | System MI + Secrets User |
| Container Apps | Azure ML | System MI + AzureML Data Scientist |
| GitHub Actions | Azure | OIDC + federated credential |
| ADF/Synapse | Log Analytics | Diagnostic settings |

## Checklist no-run

- ADF trigger Stopped
- ADF run 0
- Synapse pipeline belum pernah run
- Azure ML job 0
- Compute 0/2
- Model registry kosong
- Bronze, silver, gold kosong
- Container Apps min 0
