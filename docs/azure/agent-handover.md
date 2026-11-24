# Agent handover - Azure hydrology

Dokumen ini adalah entry point untuk anggota kelompok dan AI agent mereka.
Baca dokumen ini sebelum menyentuh Azure.

## 1. Tujuan repo dan batasannya

Repo ini berisi implementasi Azure untuk pipeline prediksi ketinggian air:

- ingest USGS dan Open-Meteo
- bronze, silver, gold
- training LightGBM
- predictions
- API dan dashboard

Batasannya:

- Fokus repo ini hanya Azure.
- Data dan model belum dijalankan.
- API dan dashboard masih placeholder.
- ADF memakai fallback Web Activity + polling, bukan activity notebook langsung.
- CD belum dijalankan.

### Disclaimer

Dokumen ini direkonstruksi dari kondisi repo dan resource Azure pada commit
terakhir. Ada risiko dokumen tidak sepenuhnya selaras dengan rencana awal,
perubahan manual di portal, atau perubahan kode setelah dokumen ini ditulis.

Aturan untuk AI agent:

- Jangan menganggap dokumen ini sebagai kebenaran mutlak.
- Verifikasi nama resource, status, dan isi tabel ke Azure.
- Jika dokumen berbeda dengan kode atau Azure, kode dan Azure yang menang.
- Jangan mengarang resource, nama, command, atau status.
- Laporkan drift, jangan memperbaikinya sendiri tanpa izin.

## 2. Sumber kebenaran

Urutan sumber kebenaran:

1. Definisi resource di Azure.
2. Kode di repo ini.
3. Dokumen di `docs/azure/`.
4. Riwayat chat, hanya sebagai konteks.

Commit terbaru bisa dicek dengan:

```bash
git log -1 --oneline
```

## 3. Urutan baca

1. `docs/azure/agent-handover.md` (dokumen ini)
2. `docs/azure/system-flow.md`
3. `docs/azure/bab3-mapping.md`
4. `docs/azure/portal-audit.md`
5. `docs/azure/rbac.md`
6. `docs/azure/runbook.md`
7. `docs/azure/v0.md`

## 4. Resource inventory

| Komponen | Nama |
|---|---|
| Resource group | `rg-hidrologi-v0` |
| ADLS | `sthidrogkiq7v7oc3lns` |
| Storage Azure ML | `stmlgkiq7v7oc3lns` |
| Key Vault | `kv-hidro-gkiq7v7oc3lns` |
| ACR | `acrhidrogkiq7v7oc3lns` |
| Synapse | `syn-hidrologi-v0` |
| Spark pool | `sparksmall` |
| Data Factory | `adf-hidrologi-v0` |
| Azure ML | `mlw-hidrologi-v0` |
| ML compute | `cpu-cluster` |
| ML environment | `hydrology-training:v1` |
| Container Apps env | `cae-hidrologi-v0` |
| API | `ca-api-hidrologi` |
| Dashboard | `ca-dash-hidrologi` |
| Log Analytics | `log-hidrologi-v0` |
| App Insights | `appi-hidrologi-v0` |
| Budget | `budget-hidrologi-v0` |
| OIDC app | `gh-hidrologi-v0` |
| ACR identity | `id-hidrologi-acr` |
| Action group | `ag-hidrologi-v0` |
| Alert | `alert-adf-pipeline-failed` |

## 5. Status yang dipakai

| Status | Arti |
|---|---|
| `deployed` | Resource atau artefak ada dan bisa diperiksa |
| `defined` | Kode atau definisi ada, belum dijalankan |
| `not run` | Pipeline, data, atau training belum dieksekusi |
| `placeholder` | Endpoint hidup, tetapi belum menampilkan hasil model |

## 6. Aturan no-run

Jangan lakukan ini tanpa izin manusia:

- Menjalankan ADF pipeline.
- Menjalankan Synapse notebook atau Synapse pipeline.
- Submit Azure ML job.
- Mengaktifkan trigger ADF.
- Menjalankan backfill.
- Menjalankan CD atau update Container Apps.
- Menghapus resource atau role assignment.

Trigger `tr_daily_0600_wib` harus tetap `Stopped`.

## 7. Verifikasi read-only

Perintah aman:

```bash
az resource list -g rg-hidrologi-v0 -o table
az datafactory trigger show -g rg-hidrologi-v0 --factory-name adf-hidrologi-v0 -n tr_daily_0600_wib --query "properties.runtimeState" -o tsv
az synapse notebook list --workspace-name syn-hidrologi-v0 --query "[].name" -o table
az synapse pipeline show --workspace-name syn-hidrologi-v0 --name pl_daily_hidrologi_syn --query "activities[].{name:name,type:type,notebook:notebook.referenceName}" -o table
az ml job list -g rg-hidrologi-v0 -w mlw-hidrologi-v0 --query "length(@)" -o tsv
az containerapp list -g rg-hidrologi-v0 --query "[].{name:name,min:properties.template.scale.minReplicas,max:properties.template.scale.maxReplicas}" -o table
```

Jangan menjalankan perintah yang mengandung `create-run`, `trigger start`,
`job create`, `deployment create`, atau `delete`.

## 8. Key Vault

Semua anggota kelompok sudah memiliki `Key Vault Secrets User`. Owner
subscription saja tidak memberi akses isi Key Vault.

Jika portal masih menampilkan unauthorized:

1. Tunggu 5 sampai 10 menit.
2. Refresh.
3. Jika masih gagal, minta admin memeriksa role assignment.
4. Jangan mencoba membaca value secret.

Secret `storage-account` adalah milik proyek. Secret UUID dengan content type
`application/vnd.ms-StorageAccountAccessKey` dibuat otomatis oleh Azure ML.
Jangan menghapus secret tersebut.

## 9. Mapping bukti ke Bab III

Gunakan `docs/azure/bab3-mapping.md`. Setiap baris punya:

- subbab
- service atau artefak
- cara cek
- expected
- status

Status harus ditulis apa adanya. Jangan menaikkan status `defined` menjadi
`deployed` tanpa bukti.

## 10. Batas biaya

- Budget `budget-hidrologi-v0`: $40 per bulan.
- Idle saat ini sekitar $6 sampai $7,5 per bulan.
- Uji minimal end-to-end sekitar $1,50 sampai $2,00.
- Jangan menjalankan uji berulang tanpa izin.
- Setelah run, pastikan Spark pool auto-pause dan Azure ML compute kembali 0.

## 11. Jika ada kegagalan

- Baca log di ADF, Synapse, atau Azure ML.
- Jangan langsung retry.
- Jangan menghapus resource.
- Laporkan langkah, error, dan status terakhir.
- Tunggu instruksi manusia.

## 12. Checklist serah terima

- [ ] Repo public bisa diakses.
- [ ] Semua anggota bisa membuka `rg-hidrologi-v0`.
- [ ] Semua anggota punya `Key Vault Secrets User`.
- [ ] Trigger ADF `Stopped`.
- [ ] Tidak ada ADF run.
- [ ] Tidak ada Azure ML job.
- [ ] Container Apps min 0.
- [ ] Budget $40 aktif.
- [ ] CI test success.
- [ ] CD belum dijalankan.
- [ ] Data dan model belum dijalankan.
