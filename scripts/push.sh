#!/bin/bash

# Push script for convolve container
set -e

# Configuration
IMAGE_NAME="wasimraja81/askappy-ubuntu-24.04"

# Get the comprehensive tag from command line
if [ -n "$1" ]; then
    COMPREHENSIVE_TAG="$1"
else
    echo "Error: Please provide the comprehensive tag to push"
    echo "Usage: $0 <comprehensive-tag>"
    echo "Example: $0 convolve-v4.3.0-8256419-20250810"
    exit 1
fi

echo "Pushing Docker image: ${IMAGE_NAME}:${COMPREHENSIVE_TAG}"

# Push the image
docker push ${IMAGE_NAME}:${COMPREHENSIVE_TAG}

echo "Successfully pushed: ${IMAGE_NAME}:${COMPREHENSIVE_TAG}"
