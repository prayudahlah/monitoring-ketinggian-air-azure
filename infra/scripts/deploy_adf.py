#!/usr/bin/env python3
"""Deploy ADF linked services, the daily pipeline and a stopped trigger.

Tries the SynapseNotebook activity first. If ADF rejects the notebook
reference, deploys the Web Activity + Until polling fallback instead.
"""

from __future__ import annotations

import os
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
RG = os.getenv("AZURE_RESOURCE_GROUP", "rg-hidrologi-v0")
ADF = os.getenv("AZURE_DATA_FACTORY", "adf-hidrologi-v0")
SYNAPSE = os.getenv("AZURE_SYNAPSE_NAME", "syn-hidrologi-v0")
ADF_PRINCIPAL = os.getenv("AZURE_DATA_FACTORY_PRINCIPAL", "f8609809-f701-48c5-84cd-48ae18d3f2f8")


def run(*args: str) -> str:
    result = subprocess.run(args, check=False, text=True, capture_output=True)
    if result.returncode != 0:
        raise RuntimeError(
            f"{' '.join(args)} failed:\n{result.stderr or result.stdout}"
        )
    return result.stdout


def create_linked_services() -> None:
    for path in sorted((ROOT / "adf/linkedService").glob("*.json")):
        name = path.stem
        print(f"linked service: {name}")
        run(
            "az", "datafactory", "linked-service", "create",
            "--resource-group", RG,
            "--factory-name", ADF,
            "--name", name,
            "--properties", f"@{path}",
            "--output", "none",
        )


def create_pipeline() -> None:
    notebook_pipeline = ROOT / "adf/pipeline/pl_daily_hidrologi.json"
    fallback = ROOT / "adf/pipeline/pl_daily_hidrologi_fallback.json"
    try:
        print("trying SynapseNotebook pipeline")
        run(
            "az", "datafactory", "pipeline", "create",
            "--resource-group", RG,
            "--factory-name", ADF,
            "--name", "pl_daily_hidrologi",
            "--pipeline", f"@{notebook_pipeline}",
            "--output", "none",
        )
        print("SynapseNotebook pipeline deployed")
        return
    except RuntimeError as exc:
        message = str(exc)
        if "invalid reference" not in message:
            raise
        print("notebook reference rejected; deploying fallback")
    run(
        "az", "datafactory", "pipeline", "create",
        "--resource-group", RG,
        "--factory-name", ADF,
        "--name", "pl_daily_hidrologi",
        "--pipeline", f"@{fallback}",
        "--output", "none",
    )
    print("fallback pipeline deployed")


def assign_synapse_role() -> None:
    try:
        run(
            "az", "synapse", "role", "assignment", "create",
            "--workspace-name", SYNAPSE,
            "--role", "Synapse Administrator",
            "--assignee", ADF_PRINCIPAL,
            "--output", "none",
        )
        print("ADF -> Synapse Administrator")
    except RuntimeError as exc:
        if "already exists" not in str(exc):
            raise
        print("ADF -> Synapse Administrator (already present)")


def create_trigger() -> None:
    trigger = ROOT / "adf/trigger/tr_daily_0600_wib.json"
    print("trigger: tr_daily_0600_wib")
    run(
        "az", "datafactory", "trigger", "create",
        "--resource-group", RG,
        "--factory-name", ADF,
        "--name", "tr_daily_0600_wib",
        "--properties", f"@{trigger}",
        "--output", "none",
    )
    run(
        "az", "datafactory", "trigger", "stop",
        "--resource-group", RG,
        "--factory-name", ADF,
        "--name", "tr_daily_0600_wib",
        "--output", "none",
    )


def main() -> int:
    create_linked_services()
    assign_synapse_role()
    create_pipeline()
    create_trigger()
    print("adf artifacts deployed; trigger stopped")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
