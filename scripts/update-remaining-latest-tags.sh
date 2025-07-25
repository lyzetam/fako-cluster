#!/bin/bash

# Script to update remaining container images from :latest to specific versions
# Based on actual images found in the cluster

echo "Updating remaining container images from :latest to specific versions..."
echo "================================================"

# Track changes
CHANGES_MADE=0

# Check if ollama/ollama needs updating (recommendation: wait for stable 0.10.0)
echo "Checking ollama/ollama..."
if grep -q "ollama/ollama:latest" apps/base/ollama/deployment-gpu.yaml 2>/dev/null; then
    echo "- Found ollama/ollama:latest (recommendation: wait for stable 0.10.0 release)"
    echo "  Skipping update as only RC versions are currently available"
fi

# Update custom images notice
echo ""
echo "Custom images (lzetam/*) found:"
grep -r "lzetam/.*:latest" apps/ --include="*.yaml" | awk -F: '{print $1}' | sort | uniq | while read file; do
    echo "  - $file"
done
echo "  Recommendation: Tag these with semantic versions in your CI/CD pipeline"

# Update MCP server images notice
echo ""
echo "MCP Server images found:"
grep -r "mcp/.*:latest\|mcpk8s/.*:latest" apps/ --include="*.yaml" | awk -F: '{print $1}' | sort | uniq | while read file; do
    echo "  - $file"
done
echo "  Recommendation: These appear to be development placeholders"

# Update voice tools notice
echo ""
echo "Voice tools (rhasspy/*) found:"
grep -r "rhasspy/.*:latest" apps/ --include="*.yaml" | awk -F: '{print $1}' | sort | uniq | while read file; do
    echo "  - $file"
done
echo "  Recommendation: Check GitHub releases for specific versions"

# ChromaDB
echo ""
if grep -q "chromadb/chroma:latest" apps/ 2>/dev/null; then
    echo "ChromaDB found:"
    echo "  Recommendation: Check with ChromaDB team for stable version"
    echo "  (Only dev versions visible in public tags)"
fi

echo ""
echo "================================================"
echo "Summary:"
echo "✓ Headlamp updated to 0.33.0"
echo ""
echo "Remaining images using :latest require:"
echo "1. Custom images (lzetam/*): Add semantic versioning in CI/CD"
echo "2. MCP servers: Replace with proper repositories"
echo "3. Voice tools: Check GitHub releases"
echo "4. Ollama: Wait for stable release"
echo "5. ChromaDB: Contact vendor for stable version"
echo ""
echo "To see all remaining :latest tags, run:"
echo "  grep -r ':latest' apps/ --include='*.yaml' | grep 'image:'"
