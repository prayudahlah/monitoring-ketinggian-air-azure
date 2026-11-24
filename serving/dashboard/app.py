"""Azure v0 dashboard.

The page is deliberately small: it proves the Container App is connected to
the storage account and shows an empty state until the gold Delta tables exist.
The full hydrograph moves here after the first pipeline run.
"""

from __future__ import annotations

import os

import streamlit as st

st.set_page_config(
    page_title="Monitoring Ketinggian Air",
    page_icon=None,
    layout="wide",
)

st.title("Monitoring Ketinggian Air")
st.caption("Azure v0 - idle deployment, pipeline belum dijalankan")

storage_account = os.getenv("AZURE_STORAGE_ACCOUNT", "")
model_name = os.getenv("MLFLOW_MODEL_NAME", "hydrology-lightgbm")

left, middle, right = st.columns(3)
left.metric("Storage account", storage_account or "belum diset")
middle.metric("Gold container", os.getenv("AZURE_STORAGE_CONTAINER", "gold"))
right.metric("Model", "belum dilatih")

st.info(
    "Resource sudah terhubung. Data gold, prediksi, dan metrik model akan "
    "muncul setelah pipeline dijalankan."
)

with st.expander("Konfigurasi runtime"):
    st.json(
        {
            "environment": os.getenv("ENVIRONMENT", "azure-v0"),
            "storage_account": storage_account,
            "gold_container": os.getenv("AZURE_STORAGE_CONTAINER", "gold"),
            "mlflow_tracking_uri": os.getenv("MLFLOW_TRACKING_URI", ""),
            "model_name": model_name,
            "status": "no_data",
        }
    )
