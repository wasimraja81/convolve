#!/bin/bash

# Show build information for convolve container
set -e

# Configuration
IMAGE_NAME="wasimraja81/askappy-ubuntu-24.04"

# Get the comprehensive tag from command line
if [ -n "$1" ]; then
    COMPREHENSIVE_TAG="$1"
else
    echo "Error: Please provide the comprehensive tag to inspect"
    echo "Usage: $0 <comprehensive-tag>"
    echo "Example: $0 convolve-v4.3.0-8256419-20250810"
    exit 1
fi

echo "Build information for: ${IMAGE_NAME}:${COMPREHENSIVE_TAG}"
echo "========================================="

# Show Docker labels
echo "Docker Labels:"
docker inspect ${IMAGE_NAME}:${COMPREHENSIVE_TAG} --format='{{range $k, $v := .Config.Labels}}{{$k}}: {{$v}}{{println}}{{end}}' | grep -E "(racs_tools|description)"

echo ""
echo "Build Information File:"
docker run --rm ${IMAGE_NAME}:${COMPREHENSIVE_TAG} cat /opt/RACS-tools/BUILD_INFO.txt

echo ""
echo "Available Binaries:"
docker run --rm ${IMAGE_NAME}:${COMPREHENSIVE_TAG} bash -c "which beamcon_2D && which beamcon_3D"
