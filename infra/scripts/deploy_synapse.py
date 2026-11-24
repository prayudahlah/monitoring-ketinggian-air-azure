#!/usr/bin/env python3
"""Upload native Synapse notebooks and create the Synapse pipeline.

No notebook is executed. This is an artifact deployment only.
"""

from __future__ import annotations

import os
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SYNAPSE = os.getenv("AZURE_SYNAPSE_NAME", "syn-hidrologi-v0")
SPARK_POOL = os.getenv("AZURE_SPARK_POOL", "sparksmall")
NOTEBOOKS = ["01_ingest", "02_silver", "03_gold", "04_predict"]


def run(*args: str) -> str:
    result = subprocess.run(args, check=False, text=True, capture_output=True)
    if result.returncode != 0:
        raise RuntimeError(
            f"{' '.join(args)} failed:\n{result.stderr or result.stdout}"
        )
    return result.stdout


def main() -> int:
    for name in NOTEBOOKS:
        path = ROOT / "synapse/notebooks" / f"{name}.ipynb"
        print(f"notebook: {name}")
        run(
            "az", "synapse", "notebook", "create",
            "--workspace-name", SYNAPSE,
            "--name", name,
            "--file", f"@{path}",
            "--spark-pool-name", SPARK_POOL,
            "--executor-count", "2",
            "--executor-size", "Small",
            "--output", "none",
        )

    pipeline = ROOT / "synapse/pipeline/pl_daily_hidrologi_syn.json"
    print("pipeline: pl_daily_hidrologi_syn")
    run(
        "az", "synapse", "pipeline", "create",
        "--workspace-name", SYNAPSE,
        "--name", "pl_daily_hidrologi_syn",
        "--file", f"@{pipeline}",
        "--output", "none",
    )
    print("synapse artifacts deployed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
