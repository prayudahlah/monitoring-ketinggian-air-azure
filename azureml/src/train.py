"""Azure ML training job for the hydrology gold dataset.

Reads the gold features Delta table from a mounted input, trains one LightGBM
model per station and horizon, evaluates against persistence, and logs to the
workspace's managed MLflow.
"""

from __future__ import annotations

import json
import math
import os
from datetime import UTC, datetime

import lightgbm as lgb
import mlflow
import mlflow.lightgbm
import numpy as np
import pandas as pd
from deltalake import DeltaTable
from metrics import event_metrics, regression_metrics
from schema import FEATURE_COLS, HORIZONS, STATIONS, TARGET_COLS

DEFAULT_TRAIN_START = "2015-10-01"
DEFAULT_TRAIN_END = "2023-09-30"
DEFAULT_VAL_START = "2023-10-01"
DEFAULT_VAL_END = "2024-09-30"
DEFAULT_TEST_START = "2024-10-01"
DEFAULT_TEST_END = "2026-09-30"
DEFAULT_GATE = 0.02
DEFAULT_MIN_ROWS = 5_000

LGB_PARAMS = {
    "objective": "regression_l1",
    "metric": "mae",
    "learning_rate": 0.03,
    "num_leaves": 63,
    "min_child_samples": 50,
    "subsample": 0.8,
    "subsample_freq": 1,
    "colsample_bytree": 0.8,
    "reg_lambda": 1.0,
    "n_estimators": 3000,
    "importance_type": "gain",
    "random_state": 42,
    "n_jobs": -1,
    "verbosity": -1,
}


def _env(name: str, default: str | None = None) -> str | None:
    value = os.getenv(name)
    return value if value not in (None, "") else default


def _split(frame: pd.DataFrame) -> dict[str, pd.DataFrame]:
    train = frame[
        (frame["time_utc"] >= pd.Timestamp(_env("TRAIN_START", DEFAULT_TRAIN_START), tz="UTC"))
        & (frame["time_utc"] <= pd.Timestamp(_env("TRAIN_END", DEFAULT_TRAIN_END), tz="UTC"))
    ]
    val = frame[
        (frame["time_utc"] >= pd.Timestamp(_env("TRAIN_VAL_START", DEFAULT_VAL_START), tz="UTC"))
        & (frame["time_utc"] <= pd.Timestamp(_env("TRAIN_VAL_END", DEFAULT_VAL_END), tz="UTC"))
    ]
    test = frame[
        (frame["time_utc"] >= pd.Timestamp(_env("TRAIN_TEST_START", DEFAULT_TEST_START), tz="UTC"))
        & (frame["time_utc"] <= pd.Timestamp(_env("TRAIN_TEST_END", DEFAULT_TEST_END), tz="UTC"))
    ]
    return {"train": train, "val": val, "test": test}


def _log_metrics(prefix: str, values: dict, horizon: int) -> None:
    for name in ("mae", "rmse", "bias", "nse", "kge", "pod", "far", "csi"):
        value = values.get(name)
        if value is None or not math.isfinite(float(value)):
            continue
        mlflow.log_metric(f"{prefix}_h{horizon}_{name}", float(value))


def main() -> int:
    gold_path = os.environ.get("GOLD_FEATURES_PATH") or os.environ["GOLD_FEATURES"]
    table = DeltaTable(gold_path)
    columns = list(
        dict.fromkeys(
            [
                "station_id",
                "time_utc",
                "is_trainable",
                "is_partial",
                "stage_now",
                "dataset_version",
                "discharge_grain",
                *FEATURE_COLS,
                *TARGET_COLS,
            ]
        )
    )
    frame = table.to_pandas(columns=columns)
    frame["time_utc"] = pd.to_datetime(frame["time_utc"], utc=True)
    frame["station_id"] = frame["station_id"].astype(str)
    frame = frame[frame["is_trainable"]].copy()
    if _env("TRAIN_INCLUDE_PARTIAL", "false").lower() not in {"1", "true", "yes"}:
        frame = frame[~frame["is_partial"].astype(bool)].copy()

    splits = _split(frame)
    if len(splits["train"]) < int(_env("TRAIN_MIN_ROWS", str(DEFAULT_MIN_ROWS))):
        raise RuntimeError(
            f"only {len(splits['train'])} train rows; run a larger gold backfill first"
        )

    mlflow.set_tracking_uri(os.environ["MLFLOW_TRACKING_URI"])
    mlflow.set_experiment(_env("MLFLOW_EXPERIMENT", "hydrology-azure"))
    model_version = datetime.now(UTC).strftime("m-%Y%m%dT%H%M%SZ")
    gate = float(_env("TRAIN_GATE_IMPROVEMENT", str(DEFAULT_GATE)))

    summary = {
        "model_version": model_version,
        "rows": {name: len(part) for name, part in splits.items()},
        "dataset_version": str(frame["dataset_version"].iloc[0]),
        "discharge_grain": str(frame["discharge_grain"].iloc[0]),
        "promoted": {},
    }

    with mlflow.start_run(run_name=model_version):
        mlflow.log_params(
            {
                **LGB_PARAMS,
                "train_start": _env("TRAIN_START", DEFAULT_TRAIN_START),
                "train_end": _env("TRAIN_END", DEFAULT_TRAIN_END),
                "val_start": _env("TRAIN_VAL_START", DEFAULT_VAL_START),
                "val_end": _env("TRAIN_VAL_END", DEFAULT_VAL_END),
                "test_start": _env("TRAIN_TEST_START", DEFAULT_TEST_START),
                "test_end": _env("TRAIN_TEST_END", DEFAULT_TEST_END),
                "gate_improvement": gate,
            }
        )

        for station in STATIONS:
            station_splits = {
                name: part[part["station_id"] == station].copy()
                for name, part in splits.items()
            }
            if station_splits["train"].empty:
                continue

            for horizon, target in zip(HORIZONS, TARGET_COLS):
                train = station_splits["train"]
                val = station_splits["val"]
                test = station_splits["test"]
                threshold = float(np.nanpercentile(train[target], 95))

                train_delta = train[target] - train["stage_now"]
                val_delta = val[target] - val["stage_now"]

                eval_set = None
                if not val.empty:
                    eval_set = [(val[list(FEATURE_COLS)], val_delta)]

                callbacks = [lgb.log_evaluation(0)]
                if eval_set:
                    callbacks.insert(0, lgb.early_stopping(100, verbose=False))

                model = lgb.LGBMRegressor(**LGB_PARAMS)
                model.fit(
                    train[list(FEATURE_COLS)],
                    train_delta,
                    eval_set=eval_set,
                    callbacks=callbacks,
                )

                for split_name, split_frame in (("val", val), ("test", test)):
                    if split_frame.empty:
                        continue
                    candidate = (
                        model.predict(split_frame[list(FEATURE_COLS)])
                        + split_frame["stage_now"].to_numpy()
                    )
                    observed = split_frame[target].to_numpy()
                    persistence = split_frame["stage_now"].to_numpy()

                    candidate_metrics = regression_metrics(observed, candidate)
                    candidate_metrics.update(event_metrics(observed, candidate, threshold))
                    persistence_metrics = regression_metrics(observed, persistence)
                    persistence_metrics.update(event_metrics(observed, persistence, threshold))

                    _log_metrics(f"candidate_{station}_{split_name}", candidate_metrics, horizon)
                    _log_metrics(f"persistence_{station}_{split_name}", persistence_metrics, horizon)

                    if split_name == "test":
                        baseline = persistence_metrics["mae"]
                        score = candidate_metrics["mae"]
                        promoted = bool(
                            math.isfinite(score)
                            and math.isfinite(baseline)
                            and score < baseline * (1 - gate)
                        )
                        summary["promoted"][f"{station}_h{horizon}"] = promoted

                model_name = f"hydrology-{station}-h{horizon}"
                try:
                    mlflow.lightgbm.log_model(
                        model,
                        name=f"{station}_h{horizon}",
                        registered_model_name=model_name,
                    )
                except TypeError:
                    mlflow.lightgbm.log_model(
                        model,
                        artifact_path=f"{station}_h{horizon}",
                        registered_model_name=model_name,
                    )
                mlflow.set_tag(f"model_{station}_h{horizon}", model_name)

        mlflow.log_dict(summary, "summary.json")
        mlflow.set_tags(
            {
                "dataset_version": summary["dataset_version"],
                "discharge_grain": summary["discharge_grain"],
                "model_version": model_version,
            }
        )

    print(json.dumps(summary, default=str))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
