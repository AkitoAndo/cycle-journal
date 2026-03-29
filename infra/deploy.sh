#!/bin/bash
set -euo pipefail

# Usage: ./deploy.sh <dev|prod>

ENV="${1:?Usage: ./deploy.sh <dev|prod>}"
PROJECT_ID="cycle-journal"
REGION="asia-northeast1"
REPO="asia-northeast1-docker.pkg.dev/${PROJECT_ID}/cycle-api"

if [[ "$ENV" != "dev" && "$ENV" != "prod" ]]; then
  echo "Error: environment must be 'dev' or 'prod'"
  exit 1
fi

echo "=== Deploying CycleJournal API ($ENV) ==="

# 1. Docker build & push
echo "--- Building and pushing Docker image ---"
cd "$(dirname "$0")/../api"
docker build --platform linux/amd64 -t "${REPO}/api:${ENV}" .
docker push "${REPO}/api:${ENV}"

# latest タグも更新
docker tag "${REPO}/api:${ENV}" "${REPO}/api:latest"
docker push "${REPO}/api:latest"

# 2. Terraform apply
echo "--- Applying Terraform ($ENV) ---"
cd "$(dirname "$0")"

# 環境ごとに state prefix を分離
terraform init -reconfigure -backend-config="prefix=terraform/${ENV}"
terraform plan -var-file="${ENV}.tfvars" -out="tfplan-${ENV}"

echo ""
echo "Plan created. Apply? (y/N)"
read -r confirm
if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
  terraform apply "tfplan-${ENV}"
  echo ""
  echo "=== Deployed! ==="
  terraform output cloud_run_url
else
  echo "Cancelled."
  rm -f "tfplan-${ENV}"
fi
