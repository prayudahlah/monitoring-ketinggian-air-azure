# Monitoring Ketinggian Air - Azure

Azure implementation of the hydrology medallion pipeline.

## Handover

Mulai dari `docs/azure/agent-handover.md`. Dokumen itu menjelaskan urutan baca,
batas no-run, inventory resource, dan status implementasi.

## Services

```text
ADLS Gen2
  bronze -> silver -> gold

ADF
  triggers the Synapse pipeline and polls its status

Synapse Spark
  01_ingest -> 02_silver -> 03_gold -> 04_predict

Azure ML
  LightGBM training + managed MLflow

Container Apps
  FastAPI + Streamlit, minReplicas 0

Key Vault, ACR, Log Analytics, Application Insights, Budget
```

## Repository layout

```text
infra/bicep/          Azure infrastructure
infra/scripts/        deployment helpers
synapse/notebooks/    PySpark notebooks, code visible
synapse/pipeline/     Synapse pipeline definition
adf/                  linked services, pipeline, stopped trigger
azureml/              training image, environment, job
serving/              API and dashboard containers
docs/azure/           architecture, mapping, runbook, RBAC
```

## Implementation

Synapse notebooks contain the transformations directly. Training runs as an
Azure ML command job.

## Current status

- Infrastructure deployed in `eastasia`.
- Synapse notebooks and pipeline deployed.
- ADF fallback pipeline deployed with status polling.
- Trigger `tr_daily_0600_wib` is **Stopped**.
- Azure ML environment `hydrology-training:v1`.
- Container Apps API and dashboard run with `minReplicas: 0`.
- No data pipeline, notebook, training, or prediction has been run.

## Deploy artifacts

```bash
python infra/scripts/deploy_synapse.py
python infra/scripts/deploy_adf.py
az ml environment create --file azureml/environment.yml \
  --resource-group rg-hidrologi-v0 \
  --workspace-name mlw-hidrologi-v0
```

## Run later

See `docs/azure/runbook.md`. Do not run the pipeline until the sample window
and budget are approved.
