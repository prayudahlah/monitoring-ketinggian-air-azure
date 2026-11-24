# Runbook Azure Native

Jangan jalankan pipeline sebelum sample dan budget disetujui.

## Deploy artefak

```bash
python infra/scripts/deploy_synapse.py
python infra/scripts/deploy_adf.py
./infra/scripts/build_training.sh v1
az ml environment create --file azureml/environment.yml \
  --resource-group rg-hidrologi-v0 --workspace-name mlw-hidrologi-v0
```

ADF native `SynapseNotebook` akan dicoba lebih dulu. Kalau ditolak, script
memakai pipeline fallback dengan polling status.

Untuk GitHub Actions di repo baru, tambahkan federated credential
`repo:prayudahlah/monitoring-ketinggian-air-azure:ref:refs/heads/main` dan set
`AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`.

## Gate 0 - preflight

```bash
az datafactory trigger show -g rg-hidrologi-v0 --factory-name adf-hidrologi-v0 \
  -n tr_daily_0600_wib --query "properties.runtimeState" -o tsv

az synapse spark pool show --workspace-name syn-hidrologi-v0 \
  --resource-group rg-hidrologi-v0 --name sparksmall -o json

az ml compute show -g rg-hidrologi-v0 -w mlw-hidrologi-v0 \
  -n cpu-cluster --query "{min:min_instances,max:max_instances}" -o json
```

Trigger harus `Stopped`, compute `0/2`.

## Gate 1 - sample Synapse

```bash
az synapse pipeline create-run \
  --workspace-name syn-hidrologi-v0 \
  --name pl_daily_hidrologi_syn \
  --parameters '{"window_start":"2015-10-01","window_end":"2015-10-07","predict_days":"7"}'
```

`04_predict` akan gagal atau skip karena model belum ada. Bronze, silver, dan
gold tetap terbentuk.

## Gate 2 - training

```bash
az ml job create --file azureml/train_job.yml \
  --resource-group rg-hidrologi-v0 \
  --workspace-name mlw-hidrologi-v0
```

Training membutuhkan gold yang cukup. Sample 7 hari tidak cukup untuk
`TRAIN_MIN_ROWS=5000`. Lakukan backfill dulu atau turunkan batas hanya untuk
smoke test.

## Gate 3 - prediction

Jalankan notebook `04_predict` dari Synapse Studio, atau jalankan ulang
Synapse pipeline dengan window yang sama setelah model ada.

## Gate 4 - backfill

Satu run penuh atau per tahun, bukan per bulan.

```bash
az synapse pipeline create-run \
  --workspace-name syn-hidrologi-v0 \
  --name pl_daily_hidrologi_syn \
  --parameters '{"window_start":"2015-10-01","window_end":"2026-11-23","predict_days":"7"}'
```

## Gate 5 - trigger

```bash
az datafactory trigger start \
  --resource-group rg-hidrologi-v0 \
  --factory-name adf-hidrologi-v0 \
  --name tr_daily_0600_wib
```

## Stop darurat

```bash
az datafactory trigger stop \
  --resource-group rg-hidrologi-v0 \
  --factory-name adf-hidrologi-v0 \
  --name tr_daily_0600_wib
```

Container Apps sudah `minReplicas: 0`. Tidak perlu stop manual.

## Biaya

| Gate | Perkiraan |
|---|---|
| Idle | $6 sampai $7,5/bulan |
| Sample | $1 sampai $1,5 |
| Training | $0,2 sampai $0,5 |
| Prediction | $0,6 sampai $0,8 |
| Backfill satu run | $3 sampai $5 |
| Backfill tahunan, 11 run | $9 sampai $11 |
| Backfill bulanan | $85 sampai $100, tidak disarankan |
