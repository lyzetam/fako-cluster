#!/bin/bash

# Script to update container image versions from :latest to specific versions
# Usage: ./update-image-versions.sh

echo "Starting image version updates..."

# High Priority Updates

# 1. Update cloudflare/cloudflared:latest to 2025.7.0
echo "Updating cloudflare/cloudflared images..."
find apps -name "*.yaml" -type f -exec sed -i '' 's|image: cloudflare/cloudflared:latest|image: cloudflare/cloudflared:2025.7.0|g' {} +

# 2. Update bitnami/kubectl:latest to 1.33.3
echo "Updating bitnami/kubectl images..."
find apps -name "*.yaml" -type f -exec sed -i '' 's|image: bitnami/kubectl:latest|image: bitnami/kubectl:1.33.3|g' {} +

# 3. Update aquasec/kube-bench:latest to v0.11.1
echo "Updating aquasec/kube-bench images..."
find apps -name "*.yaml" -type f -exec sed -i '' 's|image: aquasec/kube-bench:latest|image: aquasec/kube-bench:v0.11.1|g' {} +

# 4. Update zricethezav/gitleaks:latest to v8.28.0
echo "Updating zricethezav/gitleaks images..."
find apps -name "*.yaml" -type f -exec sed -i '' 's|image: zricethezav/gitleaks:latest|image: zricethezav/gitleaks:v8.28.0|g' {} +

# Medium Priority Updates

# 5. Update n8nio/n8n:latest to 1.104.1
echo "Updating n8nio/n8n images..."
find apps -name "*.yaml" -type f -exec sed -i '' 's|image: n8nio/n8n:latest|image: n8nio/n8n:1.104.1|g' {} +

# 6. Update dpage/pgadmin4:latest to 9.6.0
echo "Updating dpage/pgadmin4 images..."
find apps -name "*.yaml" -type f -exec sed -i '' 's|image: dpage/pgadmin4:latest|image: dpage/pgadmin4:9.6.0|g' {} +

# 7. Update buildkite/puppeteer:latest to 10.0.0
echo "Updating buildkite/puppeteer images..."
find apps -name "*.yaml" -type f -exec sed -i '' 's|image: buildkite/puppeteer:latest|image: buildkite/puppeteer:10.0.0|g' {} +

echo "Image version updates completed!"
echo ""
echo "Summary of changes:"
echo "- cloudflare/cloudflared:latest → 2025.7.0"
echo "- bitnami/kubectl:latest → 1.33.3"
echo "- aquasec/kube-bench:latest → v0.11.1"
echo "- zricethezav/gitleaks:latest → v8.28.0"
echo "- n8nio/n8n:latest → 1.104.1"
echo "- dpage/pgadmin4:latest → 9.6.0"
echo "- buildkite/puppeteer:latest → 10.0.0"
echo ""
echo "Please review the changes with: git diff"
echo "To revert changes: git checkout -- apps/"
