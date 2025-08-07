#!/bin/bash

# Helper script to generate Docker Hub authentication
# Usage: ./generate-docker-auth.sh <username> <password>

if [ $# -ne 2 ]; then
    echo "Usage: $0 <dockerhub-username> <dockerhub-password-or-token>"
    exit 1
fi

USERNAME=$1
PASSWORD=$2

# Generate base64 encoded auth string
AUTH=$(echo -n "${USERNAME}:${PASSWORD}" | base64)

echo "Base64 encoded auth string:"
echo "$AUTH"
echo ""
echo "You can now use this in your docker-registry-secret-unencrypted.yaml file"
