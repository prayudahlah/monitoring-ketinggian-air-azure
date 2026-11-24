"""Minimal inference API for the Azure v0 deployment.

The endpoint is intentionally read-only and returns 503 until the Azure ML
training job has registered a model. This lets the Container App be deployed
idle without pretending that a model exists.
"""

from __future__ import annotations

import os

from fastapi import FastAPI, HTTPException

STATIONS = ("11525670", "11150500", "11454000")
HORIZONS = (1, 6, 24)

app = FastAPI(
    title="Hydrology Inference API",
    version="0.1.0",
    description="Azure v0 API for gage-height predictions.",
)


@app.get("/health")
def health() -> dict:
    return {
        "status": "ok",
        "environment": os.getenv("ENVIRONMENT", "unset"),
        "storage_account": os.getenv("AZURE_STORAGE_ACCOUNT", ""),
        "model": "not_loaded",
    }


@app.get("/stations")
def stations() -> dict:
    return {"stations": list(STATIONS), "horizons": list(HORIZONS)}


@app.get("/predict")
def predict(station_id: str, horizon: int = 6) -> dict:
    if station_id not in STATIONS:
        raise HTTPException(status_code=404, detail="unknown station")
    if horizon not in HORIZONS:
        raise HTTPException(
            status_code=400, detail="horizon must be one of 1, 6, 24"
        )
    raise HTTPException(
        status_code=503,
        detail="model not trained yet; run the Azure ML training job first",
    )
