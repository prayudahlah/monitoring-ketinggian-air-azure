#!/usr/bin/env bash
# Build the Azure ML training image.
set -euo pipefail

ACR="${AZURE_ACR_NAME:-acrhidrogkiq7v7oc3lns}"
LOGIN_SERVER="${ACR}.azurecr.io"
TAG="${1:-v1}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

az acr login --name "$ACR"

cd "$ROOT/azureml"
docker buildx build \
  --platform linux/amd64 \
  --pull \
  --provenance=false \
  --sbom=false \
  --output "type=image,name=${LOGIN_SERVER}/training:${TAG},push=true,oci-mediatypes=true" \
  -f Dockerfile .

echo "pushed training:${TAG}"
