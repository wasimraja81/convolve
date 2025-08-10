#!/bin/bash

# Build script for convolve container
set -e

# Configuration
IMAGE_NAME="wasimraja81/askappy-ubuntu-24.04"
CONTAINER_NAME="convolve"
BASE_TAG="convolve"
RACS_TOOLS_REPO="https://github.com/AlecThomson/RACS-tools.git"

# Clean up any existing temporary clone
echo "Cleaning up temporary files..."
rm -rf tmp/RACS-tools

# Clone RACS-tools repository
echo "Cloning RACS-tools repository..."
mkdir -p tmp
cd tmp
git clone ${RACS_TOOLS_REPO}
cd RACS-tools

# Capture git metadata
RACS_GIT_SHA=$(git rev-parse HEAD)
RACS_GIT_SHA_SHORT=$(git rev-parse --short HEAD)
RACS_GIT_TAG=$(git describe --tags --exact-match 2>/dev/null || echo "no-tag")
RACS_GIT_DESCRIBE=$(git describe --tags --always --dirty 2>/dev/null || git rev-parse HEAD)
RACS_BUILD_DATE=$(date -u +%Y%m%d)

# Create comprehensive tag: convolve + git-tag + git-sha + build-date
if [ "${RACS_GIT_TAG}" != "no-tag" ]; then
    COMPREHENSIVE_TAG="convolve-${RACS_GIT_TAG}-${RACS_GIT_SHA_SHORT}-${RACS_BUILD_DATE}"
else
    COMPREHENSIVE_TAG="convolve-${RACS_GIT_SHA_SHORT}-${RACS_BUILD_DATE}"
fi

echo "RACS-tools metadata:"
echo "  Git SHA: ${RACS_GIT_SHA}"
echo "  Git Tag: ${RACS_GIT_TAG}"
echo "  Git Describe: ${RACS_GIT_DESCRIBE}"
echo "  Build Date: ${RACS_BUILD_DATE}"
echo "  Comprehensive Tag: ${COMPREHENSIVE_TAG}"

cd ../..

echo "Building Docker image: ${IMAGE_NAME}:${COMPREHENSIVE_TAG}"

# Build the Docker image with build args for metadata
docker build \
    --build-arg RACS_GIT_SHA="${RACS_GIT_SHA}" \
    --build-arg RACS_GIT_TAG="${RACS_GIT_TAG}" \
    --build-arg RACS_GIT_DESCRIBE="${RACS_GIT_DESCRIBE}" \
    --build-arg RACS_BUILD_DATE="${RACS_BUILD_DATE}" \
    -t ${IMAGE_NAME}:${COMPREHENSIVE_TAG} .

echo "Successfully built:"
echo "  - ${IMAGE_NAME}:${COMPREHENSIVE_TAG}"

# Clean up temporary clone
echo "Cleaning up temporary files..."
rm -rf tmp/RACS-tools

echo ""
echo "To push to registry, run:"
echo "  ./scripts/push.sh ${COMPREHENSIVE_TAG}"
