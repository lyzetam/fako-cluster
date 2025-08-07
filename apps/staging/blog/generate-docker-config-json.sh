#!/bin/bash

# Helper script to generate base64 encoded Docker config JSON
# Usage: ./generate-docker-config-json.sh <username> <password-or-token>

if [ $# -ne 2 ]; then
    echo "Usage: $0 <dockerhub-username> <dockerhub-password-or-token>"
    exit 1
fi

USERNAME=$1
PASSWORD=$2

# Generate base64 encoded auth string
AUTH=$(echo -n "${USERNAME}:${PASSWORD}" | base64)

# Create the Docker config JSON
DOCKER_CONFIG_JSON=$(cat <<EOF
{
  "auths": {
    "https://index.docker.io/v1/": {
      "username": "${USERNAME}",
      "password": "${PASSWORD}",
      "auth": "${AUTH}"
    }
  }
}
EOF
)

# Base64 encode the entire JSON
ENCODED_JSON=$(echo -n "$DOCKER_CONFIG_JSON" | base64 | tr -d '\n')

echo "Base64 encoded Docker config JSON:"
echo "$ENCODED_JSON"
echo ""
echo "You can now replace BASE64_ENCODED_DOCKER_CONFIG_JSON in docker-registry-secret-unencrypted-fixed.yaml with this value"
