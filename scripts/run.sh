#!/bin/bash

# Development script to run container interactively
set -e

# Configuration
IMAGE_NAME="wasimraja81/askappy-ubuntu-24.04"

# Get the comprehensive tag from command line
if [ -n "$1" ]; then
    COMPREHENSIVE_TAG="$1"
else
    echo "Error: Please provide the comprehensive tag to run"
    echo "Usage: $0 <comprehensive-tag>"
    echo "Example: $0 convolve-v4.3.0-8256419-20250810"
    exit 1
fi

# Mount current directory for development
MOUNT_DIR=$(pwd)

echo "Starting interactive container: ${IMAGE_NAME}:${COMPREHENSIVE_TAG}"
echo "Mounting current directory: ${MOUNT_DIR} -> /workspace"

docker run -it --rm \
    -v "${MOUNT_DIR}:/workspace" \
    -w /workspace \
    ${IMAGE_NAME}:${COMPREHENSIVE_TAG} \
    /bin/bash
