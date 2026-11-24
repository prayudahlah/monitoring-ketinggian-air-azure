# Mapping Bab III - Azure

| Subbab | Implementasi |
|---|---|
| A.1 Arsitektur Sistem | ADLS, ADF, Synapse, Azure ML, ACR, Container Apps, Key Vault, Log Analytics, App Insights, Budget |
| A.2 Komponen dan Fungsi | Tabel resource di `docs/azure/v0.md` |
| A.3 Alur Kerja Sistem | ADF -> Synapse -> bronze/silver/gold -> Azure ML -> predictions -> API/dashboard |
| B.1 Struktur flow dan task | ADF fallback `start_synapse`, `set_run_id`, `wait_for_synapse`, `fail_if_not_success`; Synapse pipeline empat notebook |
| B.2 Penjadwalan | Trigger `tr_daily_0600_wib`, 23:00 UTC, **Stopped** |
| B.3 Penanganan kegagalan | Retry 2x, timeout, Until status polling, IfCondition + Fail, metric alert `PipelineFailedRuns` |
| C.1 Sumber Data | USGS 3 stasiun, parameter 00065/00060, Open-Meteo |
| C.2 Perolehan Data | 2015-10-01 sampai sekarang, batch harian, bronze JSON per `ingest_date` |
| C.3 Pembersihan dan Pengolahan | Notebook `02_silver` dan `03_gold`, DQ, quarantine, Delta |
| D.1 Rekayasa Fitur | 48 fitur di `03_gold` dan `azureml/src/schema.py` |
| D.2 Target dan Horizon | `y_h1`, `y_h6`, `y_h24` |
| D.3 Prosedur Pelatihan | Azure ML command job, split kronologis, 9 model LightGBM |
| D.4 Parameter Model | `azureml/src/train.py`, early stopping 100 |
| D.5 Evaluasi Model | MAE, RMSE, bias, NSE, KGE, POD/FAR/CSI, gate 2% |
| E.1 API Inference | Container Apps `ca-api-hidrologi` |
| E.2 Dashboard | Container Apps `ca-dash-hidrologi` |
| E.3 MLOps | Managed MLflow, registry, retrain job |
| E.4 CI/CD | GitHub Actions OIDC, buildx, containerapp update |
| E.5 Keamanan dan Biaya | Managed identity, RBAC, Key Vault, budget $40, metric alert |
| F.1 Sumber Daya Azure | `eastasia`, ADLS Standard LRS, ACR Basic, Container Apps Consumption min 0, Synapse Small 3 node, Azure ML DS3_v2 min 0 |
| F.2 Parameter dan Kuota | Env var dan parameter notebook, lihat `docs/azure/runbook.md` |

## Yang nyata dan yang belum

Nyata:

- Infrastruktur dan identity.
- Notebook dan Synapse pipeline.
- ADF fallback dengan polling.
- Azure ML environment dan job definition.
- Container Apps API/dashboard.
- Alert dan diagnostic settings.

Belum:

- Data bronze/silver/gold.
- Model dan metrik.
- Prediksi.
- Backfill.
- Private endpoint dan autentikasi pengguna.
