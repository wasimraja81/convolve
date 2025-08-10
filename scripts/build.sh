#!/bin/bash

# Build script for convolve container
set -e

# Configuration
IMAGE_NAME="wasimraja81/askappy-ubuntu-24.04"
CONTAINER_NAME="convolve"
BASE_TAG="convolve"
RACS_TOOLS_REPO="https://github.com/AlecThomson/RACS-tools.git"
BUILD_PLATFORMS="linux/amd64,linux/arm64"
TEST_PLATFORM="linux/arm64"  # Native platform for your Mac

# Parse command line arguments
CHECK_BUILD_MODE=false
CLEANUP_AFTER_BUILD=false
AGGRESSIVE_CLEANUP=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --check-build)
            CHECK_BUILD_MODE=true
            shift
            ;;
        --cleanup)
            CLEANUP_AFTER_BUILD=true
            shift
            ;;
        --cleanup-aggressive)
            CLEANUP_AFTER_BUILD=true
            AGGRESSIVE_CLEANUP=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --check-build        Build single-platform for testing only (local load, no push)"
            echo "  --cleanup            Remove Docker artifacts from this build (conservative)"
            echo "  --cleanup-aggressive Remove ALL unused Docker artifacts (affects other projects)"
            echo "  --help, -h           Show this help message"
            echo ""
            echo "Modes:"
            echo "  Default       Build multi-arch and push to registry (production mode, no cache)"
            echo "  --check-build Build single-platform, test locally, no push (development mode)"
            echo ""
            echo "Examples:"
            echo "  $0                           # Production: Build multi-arch, no cache, and push"
            echo "  $0 --check-build            # Development: Build, test, load locally"
            echo "  $0 --check-build --cleanup  # Development: Build, test, safe cleanup"
            echo "  $0 --cleanup-aggressive     # Production: Build, push, aggressive cleanup"
            echo ""
            echo "Cleanup modes:"
            echo "  --cleanup            Safe: Only removes artifacts from this specific build"
            echo "  --cleanup-aggressive Aggressive: Removes ALL unused Docker artifacts system-wide"
            echo "                       (may affect other projects - use in CI/CD environments)"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Function to clone and capture metadata
clone_and_capture_metadata() {
    echo "Cleaning up any existing temporary clone..."
    rm -rf tmp/RACS-tools

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

    # Create comprehensive tag
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
}

# Function to build Docker image for check mode
build_check_image() {
    echo ""
    echo "🔍 CHECK BUILD MODE: Building single-platform for testing"
    echo "Platform: ${TEST_PLATFORM}"
    echo "Image: ${IMAGE_NAME}:${COMPREHENSIVE_TAG}"
    
    docker buildx build \
        --platform ${TEST_PLATFORM} \
        --build-arg RACS_GIT_SHA="${RACS_GIT_SHA}" \
        --build-arg RACS_GIT_TAG="${RACS_GIT_TAG}" \
        --build-arg RACS_GIT_DESCRIBE="${RACS_GIT_DESCRIBE}" \
        --build-arg RACS_BUILD_DATE="${RACS_BUILD_DATE}" \
        --load \
        -t ${IMAGE_NAME}:${COMPREHENSIVE_TAG} .

    echo ""
    echo "✅ Check build completed: ${IMAGE_NAME}:${COMPREHENSIVE_TAG}"
}

# Function to build and push multi-arch image
build_production_image() {
    echo ""
    echo "🚀 PRODUCTION MODE: Building multi-arch and pushing to registry"
    echo "Platforms: ${BUILD_PLATFORMS}"
    echo "Image: ${IMAGE_NAME}:${COMPREHENSIVE_TAG}"
    echo "Cache: Disabled for clean production build"
    
    # Build multi-arch with no cache, health check and push
    docker buildx build \
        --platform ${BUILD_PLATFORMS} \
        --no-cache \
        --build-arg RACS_GIT_SHA="${RACS_GIT_SHA}" \
        --build-arg RACS_GIT_TAG="${RACS_GIT_TAG}" \
        --build-arg RACS_GIT_DESCRIBE="${RACS_GIT_DESCRIBE}" \
        --build-arg RACS_BUILD_DATE="${RACS_BUILD_DATE}" \
        --push \
        -t ${IMAGE_NAME}:${COMPREHENSIVE_TAG} .

    if [ $? -eq 0 ]; then
        echo ""
        echo "🚀 Successfully built and pushed multi-arch image: ${IMAGE_NAME}:${COMPREHENSIVE_TAG}"
        echo "   Available platforms: ${BUILD_PLATFORMS}"
        return 0
    else
        echo ""
        echo "❌ Production build/push failed!"
        return 1
    fi
}

# Function to run tests (only in check mode)
run_tests() {
    echo ""
    echo "Running tests on built container (${TEST_PLATFORM})..."
    echo "====================================="
    
    ./scripts/test.sh ${COMPREHENSIVE_TAG}
    
    if [ $? -eq 0 ]; then
        echo ""
        echo "✅ All tests passed!"
        return 0
    else
        echo ""
        echo "❌ Tests failed!"
        return 1
    fi
}

# Function to cleanup Docker artifacts
cleanup_docker_artifacts() {
    if [ "$AGGRESSIVE_CLEANUP" = true ]; then
        echo ""
        echo "🧹 AGGRESSIVE CLEANUP MODE: Removing ALL unused Docker artifacts..."
        echo "=================================================================="
        echo "⚠️  WARNING: This will affect other projects and builds!"
        
        # Remove the specific image we built
        echo "Removing built image: ${IMAGE_NAME}:${COMPREHENSIVE_TAG}"
        docker rmi "${IMAGE_NAME}:${COMPREHENSIVE_TAG}" 2>/dev/null || echo "  (Image not found locally)"
        
        # Aggressive system-wide cleanup
        echo "Performing aggressive system cleanup..."
        docker system prune --all --force --volumes
        
        echo ""
        echo "💥 Aggressive cleanup completed!"
        echo "   🗑️  ALL unused images, containers, networks, and volumes removed"
        echo "   🗑️  ALL build cache cleared"
        echo "   ⚠️  Other projects may need to rebuild from scratch"
        
    else
        echo ""
        echo "🧹 CONSERVATIVE CLEANUP MODE: Removing Docker artifacts..."
        echo "=========================================================="
        
        # Remove the specific image we built
        echo "Removing built image: ${IMAGE_NAME}:${COMPREHENSIVE_TAG}"
        docker rmi "${IMAGE_NAME}:${COMPREHENSIVE_TAG}" 2>/dev/null || echo "  (Image not found locally - likely pushed only)"
        
        # Clean up buildx cache for this specific builder only
        echo "Cleaning buildx cache for this builder..."
        docker buildx prune --builder elated_lichterman --force 2>/dev/null || echo "  (Using default builder - skipping specific cleanup)"
        
        # More conservative cleanup - only remove dangling images with our label/name pattern
        echo "Removing dangling images related to this build..."
        docker images --filter "dangling=true" --filter "reference=${IMAGE_NAME}*" --quiet | xargs -r docker rmi 2>/dev/null || true
        
        # Show current disk usage
        echo "Current Docker disk usage:"
        docker system df
        
        echo ""
        echo "✅ Conservative cleanup completed!"
        echo "   🗑️  Specific image removed: ${IMAGE_NAME}:${COMPREHENSIVE_TAG}"
        echo "   🗑️  Builder cache cleared for this project"
        echo "   🗑️  Related dangling images removed"
        echo "   ✅  Other projects' artifacts preserved"
    fi
}

# Function to run tests (only in check mode)

# Main execution flow
main() {
    clone_and_capture_metadata
    
    if [ "$CHECK_BUILD_MODE" = true ]; then
        # Development mode: build single-platform, test, load locally
        echo "==============================================="
        echo "🔍 DEVELOPMENT MODE: Check build with testing"
        echo "==============================================="
        
        build_check_image
        
        if ! run_tests; then
            echo ""
            echo "❌ Check build completed but tests failed."
            echo "   Image available locally: ${IMAGE_NAME}:${COMPREHENSIVE_TAG}"
            echo "   Fix issues and try again."
            # Clean up on failure
            echo "Cleaning up temporary files..."
            rm -rf tmp/RACS-tools
            exit 1
        fi
        
        echo ""
        echo "🎉 Check build successful!"
        echo "   ✅ Single-platform build completed"
        echo "   ✅ All tests passed"
        if [ "$CLEANUP_AFTER_BUILD" = true ]; then
            echo "   🧹 Docker cleanup will be performed"
        else
            echo "   📦 Image available locally: ${IMAGE_NAME}:${COMPREHENSIVE_TAG}"
        fi
        echo ""
        echo "Ready for production build:"
        echo "  $0"
        
    else
        # Production mode: build multi-arch and push directly
        echo "=============================================="
        echo "🚀 PRODUCTION MODE: Multi-arch build and push"
        echo "=============================================="
        
        if ! build_production_image; then
            echo ""
            echo "❌ Production build/push failed!"
            # Clean up on failure
            echo "Cleaning up temporary files..."
            rm -rf tmp/RACS-tools
            exit 1
        fi
        
        echo ""
        echo "🎉 Production build successful!"
        echo "   ✅ Multi-arch image built and pushed"
        echo "   🌐 Available on registry: ${IMAGE_NAME}:${COMPREHENSIVE_TAG}"
        echo "   📋 Platforms: ${BUILD_PLATFORMS}"
        if [ "$CLEANUP_AFTER_BUILD" = true ]; then
            echo "   🧹 Docker cleanup will be performed"
        fi
        echo ""
        echo "To test locally first next time:"
        echo "  $0 --check-build"
    fi
    
    # Perform cleanup if requested
    if [ "$CLEANUP_AFTER_BUILD" = true ]; then
        cleanup_docker_artifacts
    fi
    
    # Clean up temporary files at the end
    echo ""
    echo "Cleaning up temporary files..."
    rm -rf tmp/RACS-tools
}

# Execute main function
main
