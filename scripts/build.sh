#!/bin/bash

# Build script for convolve container
set -e

# Configuration
IMAGE_NAME="wasimraja81/askappy-ubuntu-24.04"
CONTAINER_NAME="convolve"
BASE_TAG="convolve"
RACS_TOOLS_REPO="https://github.com/AlecThomson/RACS-tools.git"
RACS_TOOLS_TAG="v4.0.3"  # Specific tag to build from
BUILD_PLATFORMS="linux/amd64,linux/arm64"
TEST_PLATFORM="linux/arm64"  # Native platform for your Mac

# Parse command line arguments
CHECK_BUILD_MODE=false
CLEANUP_AFTER_BUILD=false
AGGRESSIVE_CLEANUP=false
SINGLE_ARCH_MODE=false
SINGLE_ARCH_PLATFORM=""
CUSTOM_TAG=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --check-build)
            CHECK_BUILD_MODE=true
            shift
            ;;
        --tag)
            if [[ $# -gt 1 ]]; then
                CUSTOM_TAG="$2"
                shift
            else
                echo "Error: --tag requires a tag name"
                exit 1
            fi
            shift
            ;;
        --single-arch)
            SINGLE_ARCH_MODE=true
            # Check if next argument is a platform
            if [[ $# -gt 1 && $2 =~ ^linux/(amd64|arm64)$ ]]; then
                SINGLE_ARCH_PLATFORM="$2"
                shift
            else
                SINGLE_ARCH_PLATFORM="${TEST_PLATFORM}"
            fi
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
            echo "Build Modes:"
            echo "  (no options)                 Multi-arch production build with retry logic"
            echo "  --check-build                Single-platform development build with testing (local only)"
            echo "  --single-arch [PLATFORM]     Single-platform production build and push"
            echo "                               PLATFORM: linux/amd64 or linux/arm64 (default: native)"
            echo ""
            echo "RACS-tools Options:"
            echo "  --tag TAG                    Build from specific RACS-tools Git tag (default: ${RACS_TOOLS_TAG})"
            echo ""
            echo "Cleanup Options:"
            echo "  --cleanup                    Remove Docker artifacts from this build only"
            echo "  --cleanup-aggressive         Remove ALL unused Docker artifacts (affects other projects)"
            echo ""
            echo "Examples:"
            echo "  $0                           # Multi-arch build from ${RACS_TOOLS_TAG}"
            echo "  $0 --tag v4.1.0             # Build from specific RACS-tools tag v4.1.0"
            echo "  $0 --single-arch             # Build for native platform (ARM64) only"
            echo "  $0 --single-arch linux/amd64 # Build for AMD64 only (cross-compile)"
            echo "  $0 --check-build             # Development: build, test locally, no push"
            echo "  $0 --tag v4.0.3 --cleanup-aggressive  # Build v4.0.3 + aggressive cleanup"
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

    # Determine which tag to use
    local target_tag="${CUSTOM_TAG:-${RACS_TOOLS_TAG}}"
    
    echo "Cloning RACS-tools repository..."
    echo "Target tag: ${target_tag}"
    mkdir -p tmp
    cd tmp
    git clone ${RACS_TOOLS_REPO}
    cd RACS-tools
    
    # Checkout the specific tag
    echo "Checking out tag: ${target_tag}"
    git checkout ${target_tag}
    if [ $? -ne 0 ]; then
        echo "❌ Error: Failed to checkout tag '${target_tag}'"
        echo "   Please verify the tag exists at: ${RACS_TOOLS_REPO}/tags"
        cd ../..
        rm -rf tmp/RACS-tools
        exit 1
    fi

    # Capture git metadata
    RACS_GIT_SHA=$(git rev-parse HEAD)
    RACS_GIT_SHA_SHORT=$(git rev-parse --short HEAD)
    RACS_GIT_TAG=$(git describe --tags --exact-match 2>/dev/null || echo "no-tag")
    RACS_GIT_DESCRIBE=$(git describe --tags --always --dirty 2>/dev/null || git rev-parse HEAD)
    RACS_BUILD_DATE=$(date -u +%Y%m%d)

    # Create comprehensive tag with RACS-tools version
    if [ "${RACS_GIT_TAG}" != "no-tag" ]; then
        COMPREHENSIVE_TAG="convolve-${RACS_GIT_TAG}-${RACS_GIT_SHA_SHORT}-${RACS_BUILD_DATE}"
    else
        COMPREHENSIVE_TAG="convolve-${target_tag}-${RACS_GIT_SHA_SHORT}-${RACS_BUILD_DATE}"
    fi

    echo "RACS-tools metadata:"
    echo "  Git SHA: ${RACS_GIT_SHA}"
    echo "  Git Tag: ${RACS_GIT_TAG}"
    echo "  Git Describe: ${RACS_GIT_DESCRIBE}"
    echo "  Build Date: ${RACS_BUILD_DATE}"
    echo "  Target Tag: ${target_tag}"
    echo "  Comprehensive Tag: ${COMPREHENSIVE_TAG}"

    cd ../..
}

# Function to build single-arch image and push
build_single_arch_image() {
    local platform=$1
    echo ""
    echo "🔍 SINGLE-ARCH BUILD: Building for ${platform}"
    echo "Image: ${IMAGE_NAME}:${COMPREHENSIVE_TAG}"
    
    docker buildx build \
        --platform ${platform} \
        --no-cache \
        --build-arg RACS_GIT_SHA="${RACS_GIT_SHA}" \
        --build-arg RACS_GIT_TAG="${RACS_GIT_TAG}" \
        --build-arg RACS_GIT_DESCRIBE="${RACS_GIT_DESCRIBE}" \
        --build-arg RACS_BUILD_DATE="${RACS_BUILD_DATE}" \
        --push \
        -t ${IMAGE_NAME}:${COMPREHENSIVE_TAG} .

    if [ $? -eq 0 ]; then
        echo ""
        echo "✅ Single-arch build completed and pushed: ${IMAGE_NAME}:${COMPREHENSIVE_TAG}"
        echo "   Platform: ${platform}"
        return 0
    else
        echo ""
        echo "❌ Single-arch build failed!"
        return 1
    fi
}
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
    
    # Retry logic for multi-arch build (handles transient ARM64 pull failures)
    local max_attempts=3
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        echo "Build attempt $attempt of $max_attempts..."
        
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
            echo "   Completed on attempt $attempt"
            return 0
        else
            echo "❌ Build attempt $attempt failed"
            if [ $attempt -lt $max_attempts ]; then
                echo "⏳ Waiting 30 seconds before retry..."
                sleep 30
            fi
            attempt=$((attempt + 1))
        fi
    done
    
    echo ""
    echo "❌ Production build/push failed after $max_attempts attempts!"
    return 1
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
        
        # Clean up buildx cache for current builder
        echo "Cleaning buildx cache for current builder..."
        docker buildx prune --force 2>/dev/null || echo "  (Cache cleanup skipped)"
        
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
    # Show build configuration
    local target_tag="${CUSTOM_TAG:-${RACS_TOOLS_TAG}}"
    echo "=============================================="
    echo "🔧 BUILD CONFIGURATION"
    echo "=============================================="
    echo "RACS-tools Repository: ${RACS_TOOLS_REPO}"
    echo "RACS-tools Target Tag: ${target_tag}"
    echo "Docker Image Base: ${IMAGE_NAME}"
    echo "Build Date: $(date -u +%Y-%m-%d)"
    echo ""
    
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
        echo "   📦 RACS-tools version: ${RACS_GIT_TAG}"
        echo "   📦 Built from SHA: ${RACS_GIT_SHA_SHORT}"
        if [ "$CLEANUP_AFTER_BUILD" = true ]; then
            echo "   🧹 Docker cleanup will be performed"
        else
            echo "   📦 Image available locally: ${IMAGE_NAME}:${COMPREHENSIVE_TAG}"
        fi
        echo ""
        echo "Ready for production build:"
        echo "  $0"
        
    elif [ "$SINGLE_ARCH_MODE" = true ]; then
        # Single-arch production mode: build specified platform and push
        echo "=============================================="
        echo "🏗️  SINGLE-ARCH MODE: Single platform build and push"
        echo "=============================================="
        echo "Platform: ${SINGLE_ARCH_PLATFORM}"
        echo "Note: Building single platform as fallback to multi-arch"
        
        if ! build_single_arch_image "${SINGLE_ARCH_PLATFORM}"; then
            echo ""
            echo "❌ Single-arch build failed!"
            # Clean up on failure
            echo "Cleaning up temporary files..."
            rm -rf tmp/RACS-tools
            exit 1
        fi
        
        echo ""
        echo "🎉 Single-arch build successful!"
        echo "   ✅ Single platform image built and pushed"
        echo "   🌐 Available on registry: ${IMAGE_NAME}:${COMPREHENSIVE_TAG}"
        echo "   📋 Platform: ${SINGLE_ARCH_PLATFORM}"
        echo "   📦 RACS-tools version: ${RACS_GIT_TAG} (SHA: ${RACS_GIT_SHA_SHORT})"
        
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
        echo "   📦 RACS-tools version: ${RACS_GIT_TAG} (SHA: ${RACS_GIT_SHA_SHORT})"
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
