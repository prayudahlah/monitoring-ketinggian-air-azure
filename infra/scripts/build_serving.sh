#!/usr/bin/env bash
# Build API and dashboard images with OCI media types.
#
# Container Apps in this subscription runs an express/consumption environment
# that rejects images with mixed Docker/OCI layer media types. Buildx with
# oci-mediatypes=true and a pinned base image avoids that failure.
set -euo pipefail

ACR="${AZURE_ACR_NAME:-acrhidrogkiq7v7oc3lns}"
LOGIN_SERVER="${ACR}.azurecr.io"
TAG="${1:-v1}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

az acr login --name "$ACR"

docker buildx build \
  --platform linux/amd64 \
  --pull \
  --provenance=false \
  --sbom=false \
  --output "type=image,name=${LOGIN_SERVER}/api:${TAG},push=true,oci-mediatypes=true" \
  "$ROOT/serving/api"

docker buildx build \
  --platform linux/amd64 \
  --pull \
  --provenance=false \
  --sbom=false \
  --output "type=image,name=${LOGIN_SERVER}/dashboard:${TAG},push=true,oci-mediatypes=true" \
  "$ROOT/serving/dashboard"

echo "pushed api:${TAG} and dashboard:${TAG}"
