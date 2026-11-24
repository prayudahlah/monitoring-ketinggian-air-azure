# Mapping Bab III - Azure

Dokumen ini memetakan setiap subbab Bab III ke service atau artefak Azure,
cara memeriksanya, dan status implementasinya.

Status harus dibaca apa adanya. `deployed` bukan berarti pipeline sudah
dijalankan. `defined` berarti kode atau definisi ada, tetapi belum dieksekusi.

## Ringkasan status

| Status | Arti |
|---|---|
| `deployed` | Resource atau artefak ada dan bisa diperiksa |
| `defined` | Kode atau definisi ada, belum dijalankan |
| `not run` | Pipeline, data, atau training belum dieksekusi |
| `placeholder` | Endpoint hidup, tetapi belum menampilkan hasil model |

## Tabel mapping

| Subbab | Service / artefak | Cara cek | Expected | Status |
|---|---|---|---|---|
| A.1 Arsitektur Sistem | ADLS, ADF, Synapse, Azure ML, ACR, Container Apps, Key Vault, Log Analytics, App Insights, Budget | Resource group overview | Semua resource ada | `deployed` |
| A.2 Komponen dan Fungsi | Tabel resource di `docs/azure/v0.md` | Buka `v0.md` dan resource group | Nama dan fungsi cocok | `deployed` |
| A.3 Alur Kerja Sistem | `docs/azure/system-flow.md`, ADF, Synapse | Baca flow dan pipeline | Input, proses, output jelas | `defined` |
| B.1 Struktur flow dan task | ADF `pl_daily_hidrologi` dan Synapse `pl_daily_hidrologi_syn` | ADF Author, Synapse Integrate | ADF punya 4 activity fallback; Synapse punya 4 notebook | `deployed` |
| B.2 Penjadwalan | Trigger `tr_daily_0600_wib` | ADF Manage > Triggers | Status `Stopped` | `deployed` |
| B.3 Penanganan kegagalan | Retry, Until status, IfCondition, Fail, metric alert | ADF Author, Azure Monitor | Retry dan alert ada | `deployed` |
| C.1 Sumber Data | USGS 3 stasiun, Open-Meteo | Buka `01_ingest` | Endpoint dan parameter benar | `defined` |
| C.2 Perolehan Data | Bronze JSON per `ingest_date` | Storage container `bronze` | Kosong sebelum run | `not run` |
| C.3 Pembersihan dan Pengolahan | `02_silver` dan `03_gold` | Buka notebook | Schema, dedup, DQ, Delta terlihat | `defined` |
| D.1 Rekayasa Fitur | 48 fitur di `03_gold` dan `azureml/src/schema.py` | Buka notebook dan schema | Daftar fitur sama | `defined` |
| D.2 Target dan Horizon | `y_h1`, `y_h6`, `y_h24` | Buka `03_gold` | Tiga target ada | `defined` |
| D.3 Prosedur Pelatihan | Azure ML job `azureml/train_job.yml` | ML Studio Jobs | Job belum ada | `not run` |
| D.4 Parameter Model | `azureml/src/train.py` | Buka file | LightGBM dan early stopping ada | `defined` |
| D.5 Evaluasi Model | MAE, RMSE, bias, NSE, KGE, POD/FAR/CSI, gate 2% | Buka `azureml/src/metrics.py` | Metrik dan gate ada | `defined` |
| E.1 API Inference | `ca-api-hidrologi` | URL `/health`, `/stations`, `/predict` | 200, 200, 503 | `deployed` + `placeholder` |
| E.2 Dashboard | `ca-dash-hidrologi` | URL dashboard | 200, empty state | `deployed` + `placeholder` |
| E.3 MLOps | Managed MLflow dan registry | ML Studio Environments, Models | Environment v1 ada, model kosong | `defined` |
| E.4 CI/CD | GitHub Actions OIDC | Tab Actions | Test success, CD skipped | `deployed` |
| E.5 Keamanan dan Biaya | MI, RBAC, Key Vault, budget, alert | IAM, Key Vault, Budget | Role, secret, alert, budget ada | `deployed` |
| F.1 Sumber Daya Azure | `eastasia`, SKU, compute | Portal dan Bicep | Region dan SKU sesuai | `deployed` |
| F.2 Parameter dan Kuota | Env var, parameter notebook, kuota | `docs/azure/system-flow.md` | Parameter terdokumentasi | `defined` |

## Cara cek per kelompok

### Arsitektur

- Buka `rg-hidrologi-v0`.
- Pastikan resource sesuai `agent-handover.md`.
- Buka `docs/azure/system-flow.md` untuk alur.

### Orkestrasi

- ADF Studio > Author > `pl_daily_hidrologi`.
- Synapse Studio > Integrate > `pl_daily_hidrologi_syn`.
- ADF Studio > Manage > Triggers > `tr_daily_0600_wib`.
- Azure Monitor > Alerts > `alert-adf-pipeline-failed`.

### Data

- Storage account `sthidrogkiq7v7oc3lns`.
- Container `bronze`, `silver`, `gold`, `synapse`.
- Sebelum run, semua kosong.
- Buka notebook `01_ingest`, `02_silver`, `03_gold` untuk kode.

### Pemodelan

- Azure ML Studio > Environments > `hydrology-training` > `v1`.
- Azure ML Studio > Compute > `cpu-cluster`, min 0.
- Azure ML Studio > Jobs, harus kosong.
- Azure ML Studio > Models, harus kosong.

### Layanan

- Container Apps > `cae-hidrologi-v0` > Apps.
- API URL `/health`, `/stations`, `/predict`.
- Dashboard URL.
- GitHub Actions > `azure-ci`.

### Konfigurasi

- Bicep di `infra/bicep/`.
- Environment variable di `azureml/train_job.yml` dan Container Apps.
- Region dan SKU di `docs/azure/v0.md`.

## Bukti yang disarankan

| Subbab | Bukti |
|---|---|
| A | Screenshot resource group dan diagram |
| B | Screenshot ADF canvas, Synapse pipeline, trigger Stopped |
| C | Screenshot container kosong dan notebook silver/gold |
| D | Screenshot environment, compute, dan konfigurasi training |
| E | Screenshot API health, dashboard, IAM, budget, CI |
| F | Screenshot resource group dan Bicep |

## Catatan

- ADF memakai fallback Web Activity + polling. Activity notebook langsung
  belum berhasil.
- API dan dashboard masih placeholder.
- Smoke test nanti tidak boleh dipakai sebagai hasil penelitian.
- Jika dokumen berbeda dengan Azure, verifikasi ke resource dan kode.
