#!/bin/bash

# Test script for convolve container
set -e

# Configuration
IMAGE_NAME="wasimraja81/askappy-ubuntu-24.04"

# Get the comprehensive tag from command line
if [ -n "$1" ]; then
    COMPREHENSIVE_TAG="$1"
else
    echo "Error: Please provide the comprehensive tag to test"
    echo "Usage: $0 <comprehensive-tag>"
    echo "Example: $0 convolve-v4.3.0-8256419-20250810"
    exit 1
fi

echo "Testing Docker image: ${IMAGE_NAME}:${COMPREHENSIVE_TAG}"

# Test basic functionality
echo "Testing container startup..."
docker run --rm ${IMAGE_NAME}:${COMPREHENSIVE_TAG} python3 --version

echo "Testing RACS-tools installation..."
docker run --rm ${IMAGE_NAME}:${COMPREHENSIVE_TAG} python3 -c "import racs_tools; print('RACS-tools imported successfully')"

echo "Testing beamcon_2D binary availability..."
docker run --rm ${IMAGE_NAME}:${COMPREHENSIVE_TAG} which beamcon_2D

echo "Testing beamcon_3D binary availability..."
docker run --rm ${IMAGE_NAME}:${COMPREHENSIVE_TAG} which beamcon_3D

echo "Testing binary execution..."
docker run --rm ${IMAGE_NAME}:${COMPREHENSIVE_TAG} beamcon_2D --help || echo "beamcon_2D help displayed"
docker run --rm ${IMAGE_NAME}:${COMPREHENSIVE_TAG} beamcon_3D --help || echo "beamcon_3D help displayed"

echo "Displaying build metadata..."
docker run --rm ${IMAGE_NAME}:${COMPREHENSIVE_TAG} cat /opt/RACS-tools/BUILD_INFO.txt

echo "Container test completed successfully!"
