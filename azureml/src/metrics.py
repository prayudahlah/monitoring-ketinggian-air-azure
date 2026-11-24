"""Regression and event metrics for the training job."""

from __future__ import annotations

import math

import numpy as np


def _paired(y_true, y_pred) -> tuple[np.ndarray, np.ndarray]:
    true = np.asarray(y_true, dtype=float)
    pred = np.asarray(y_pred, dtype=float)
    mask = np.isfinite(true) & np.isfinite(pred)
    return true[mask], pred[mask]


def regression_metrics(y_true, y_pred) -> dict:
    true, pred = _paired(y_true, y_pred)
    n = int(true.size)
    if n == 0:
        return {
            "n": 0,
            "mae": math.nan,
            "rmse": math.nan,
            "bias": math.nan,
            "nse": math.nan,
            "kge": math.nan,
        }

    error = pred - true
    mae = float(np.mean(np.abs(error)))
    rmse = float(np.sqrt(np.mean(error**2)))
    bias = float(np.mean(error))
    denominator = float(np.sum((true - true.mean()) ** 2))
    nse = 1.0 - float(np.sum(error**2)) / denominator if denominator > 0 else math.nan

    if true.std() > 0 and true.mean() != 0:
        correlation = float(np.corrcoef(true, pred)[0, 1])
        alpha = float(pred.std() / true.std())
        beta = float(pred.mean() / true.mean())
        kge = 1.0 - math.sqrt(
            (correlation - 1) ** 2 + (alpha - 1) ** 2 + (beta - 1) ** 2
        )
    else:
        kge = math.nan

    return {
        "n": n,
        "mae": mae,
        "rmse": rmse,
        "bias": bias,
        "nse": nse,
        "kge": kge,
    }


def event_metrics(y_true, y_pred, threshold: float) -> dict:
    true, pred = _paired(y_true, y_pred)
    if true.size == 0:
        return {"pod": math.nan, "far": math.nan, "csi": math.nan}

    observed = true >= threshold
    forecast = pred >= threshold
    hits = int(np.sum(observed & forecast))
    misses = int(np.sum(observed & ~forecast))
    false_alarms = int(np.sum(~observed & forecast))

    pod = hits / (hits + misses) if hits + misses else math.nan
    far = false_alarms / (hits + false_alarms) if hits + false_alarms else math.nan
    csi = (
        hits / (hits + misses + false_alarms)
        if hits + misses + false_alarms
        else math.nan
    )
    return {"pod": pod, "far": far, "csi": csi}
