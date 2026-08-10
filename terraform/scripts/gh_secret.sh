#!/usr/bin/env bash
set -eu

# Define name for use in uninitialized directories
REPO_NAME=""

TF_API_TOKEN=""
DOCKER_USERNAME=""
DOCKER_PASSWORD=""
DO_API_TOKEN=""
CLOUDFLARE_TOKEN=""
CLOUDFLARE_ZONE_ID=""
DATADOG_API_KEY=""
DATADOG_APP_KEY=""
POSTGRES_PASS=""
REDIS_PASS=""

# Oracle Cloud Infrastructure (OKE)
OCI_TENANCY=""
OCI_USER=""
OCI_COMPARTMENT=""
OCI_FINGERPRINT=""
OCI_REGION=""
OCI_PRIVATE_KEY=""

# Declare an associative array to hold secrets and their corresponding values
declare -A secrets=(
  ["TF_API_TOKEN"]="${TF_API_TOKEN}"
  ["DOCKER_USERNAME"]="${DOCKER_USERNAME}"
  ["DOCKER_PASSWORD"]="${DOCKER_PASSWORD}"
  ["DO_API_TOKEN"]="${DO_API_TOKEN}"
  ["CLOUDFLARE_TOKEN"]="${CLOUDFLARE_TOKEN}"
  ["CLOUDFLARE_ZONE_ID"]="${CLOUDFLARE_ZONE_ID}"
  ["DATADOG_API_KEY"]="${DATADOG_API_KEY}"
  ["DATADOG_APP_KEY"]="${DATADOG_APP_KEY}"
  ["POSTGRES_PASS"]="${POSTGRES_PASS}"
  ["REDIS_PASS"]="${REDIS_PASS}"
  ["OCI_TENANCY"]="${OCI_TENANCY}"
  ["OCI_USER"]="${OCI_USER}"
  ["OCI_COMPARTMENT"]="${OCI_COMPARTMENT}"
  ["OCI_FINGERPRINT"]="${OCI_FINGERPRINT}"
  ["OCI_REGION"]="${OCI_REGION}"
  ["OCI_PRIVATE_KEY"]="${OCI_PRIVATE_KEY}"
)

# Iterate over the secrets and set them using `gh secret set`
for secret_name in "${!secrets[@]}"; do
  gh secret set "$secret_name" --repo "$REPO_NAME" --body "${secrets[$secret_name]}"
done

echo "All secrets have been set successfully!"
