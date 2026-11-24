# Arsitektur Azure

```mermaid
flowchart LR
    USGS[USGS NWIS] --> ING[01_ingest]
    OM[Open-Meteo] --> ING
    ADF[ADF<br/>pl_daily_hidrologi] --> SYN[Synapse pipeline<br/>pl_daily_hidrologi_syn]
    SYN --> ING
    ING --> BZ[(Bronze<br/>ADLS)]
    BZ --> SL[02_silver]
    SL --> SV[(Silver Delta)]
    SV --> GD[03_gold]
    GD --> GO[(Gold Delta)]
    GO --> ML[Azure ML training]
    ML --> MLF[Managed MLflow]
    MLF --> PR[04_predict]
    PR --> PD[(Predictions Delta)]
    PD --> APP[Container Apps<br/>API + dashboard]

    KV[Key Vault] -. secret .-> APP
    ACR[ACR] -. image .-> APP
    ACR -. image .-> ML
    LOG[Log Analytics] -. log .-> ADF
    LOG -. log .-> SYN
    LOG -. log .-> APP
    ALERT[Azure Monitor alert] -. failure .-> ADF
```

Alur:

1. ADF memicu Synapse pipeline dan memeriksa statusnya.
2. `01_ingest` mengambil USGS dan Open-Meteo, menulis bronze.
3. `02_silver` membersihkan, DQ, quarantine, menulis silver Delta.
4. `03_gold` membentuk hourly, fitur, target, dataset version.
5. Azure ML melatih 9 model LightGBM, mencatat metrik dan model ke MLflow.
6. `04_predict` memuat model terbaru dan menulis predictions Delta.
7. Container Apps menyajikan API dan dashboard.

Jalur data berjalan di layanan Azure.

## Identity

- Synapse MI: storage, Key Vault, Azure ML.
- Azure ML MI: storage dan ACR.
- ADF MI: storage, Synapse, Azure ML, Key Vault.
- Container Apps: user-assigned `id-hidrologi-acr` untuk AcrPull, system-assigned
  untuk gold, Key Vault, Azure ML.
- GitHub Actions: OIDC.
