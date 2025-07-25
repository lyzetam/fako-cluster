#!/bin/bash

# Script to update container image versions from :latest to specific versions
# This updates high and medium priority images as identified in the analysis

echo "Updating container image versions from :latest to specific versions..."
echo "================================================"

# High Priority Updates (Security & Stability)
echo "Applying High Priority updates..."

# cloudflare/cloudflared:latest → 2025.7.0
find apps/ -name "*.yaml" -type f -exec sed -i '' 's|cloudflare/cloudflared:latest|cloudflare/cloudflared:2025.7.0|g' {} \;
echo "✓ Updated cloudflare/cloudflared to 2025.7.0"

# aquasec/kube-bench:latest → v0.11.1
find apps/ -name "*.yaml" -type f -exec sed -i '' 's|aquasec/kube-bench:latest|aquasec/kube-bench:v0.11.1|g' {} \;
echo "✓ Updated aquasec/kube-bench to v0.11.1"

# zricethezav/gitleaks:latest → v8.28.0
find apps/ -name "*.yaml" -type f -exec sed -i '' 's|zricethezav/gitleaks:latest|zricethezav/gitleaks:v8.28.0|g' {} \;
echo "✓ Updated zricethezav/gitleaks to v8.28.0"

# bitnami/kubectl:latest → 1.33.3
find apps/ -name "*.yaml" -type f -exec sed -i '' 's|bitnami/kubectl:latest|bitnami/kubectl:1.33.3|g' {} \;
echo "✓ Updated bitnami/kubectl to 1.33.3"

echo ""
echo "Applying Medium Priority updates..."

# n8nio/n8n:latest → 1.104.1
find apps/ -name "*.yaml" -type f -exec sed -i '' 's|n8nio/n8n:latest|n8nio/n8n:1.104.1|g' {} \;
echo "✓ Updated n8nio/n8n to 1.104.1"

# dpage/pgadmin4:latest → 9.6.0
find apps/ -name "*.yaml" -type f -exec sed -i '' 's|dpage/pgadmin4:latest|dpage/pgadmin4:9.6.0|g' {} \;
echo "✓ Updated dpage/pgadmin4 to 9.6.0"

# buildkite/puppeteer:latest → 10.0.0
find apps/ -name "*.yaml" -type f -exec sed -i '' 's|buildkite/puppeteer:latest|buildkite/puppeteer:10.0.0|g' {} \;
echo "✓ Updated buildkite/puppeteer to 10.0.0"

echo ""
echo "================================================"
echo "Update complete!"
echo ""
echo "To review the changes, run:"
echo "  git diff"
echo ""
echo "To commit the changes, run:"
echo "  git add -A && git commit -m 'chore: update container images from latest to specific versions'"
echo ""
echo "Note: Low priority updates and custom images were not included in this script."
echo "Refer to notes/image-version-recommendations.md for the complete list."
