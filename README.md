# Convolve Container

Multi-architecture Docker container for RACS-tools with comprehensive build pipeline and testing system.

## Overview

- **Base Image**: `wasimraja81/base-casacore:casacore-3.7.1-20250810-607f488`
- **Target Registry**: `wasimraja81/askappy-ubuntu-24.04:convolve-<comprehensive-tag>`
- **Platforms**: `linux/amd64`, `linux/arm64`
- **Source Code**: [RACS-tools](https://github.com/AlecThomson/RACS-tools.git) (cloned during build)

## Key Features

- **Multi-Architecture**: Builds for both AMD64 and ARM64 platforms
- **Two Build Modes**: Development (fast) and Production (clean, no-cache)
- **Fresh RACS-tools**: Always builds from the latest source
- **Build-time Validation**: Binary verification during container build
- **Comprehensive Testing**: Automated test suite with health checks
- **Safe Cleanup Options**: Conservative and aggressive Docker cleanup modes
- **Smart Tagging**: `convolve-{git-tag}-{git-sha}-{build-date}` format

## Build System

### Quick Start

```bash
# Development: Fast build, local testing
./scripts/build.sh --check-build

# Production: Clean build, multi-arch, push to registry  
./scripts/build.sh

# With cleanup options
./scripts/build.sh --cleanup                    # Safe cleanup
./scripts/build.sh --cleanup-aggressive         # Full cleanup
```

### Build Modes

| Mode | Cache | Platforms | Push | Use Case |
|------|-------|-----------|------|----------|
| **Development** (`--check-build`) | ✅ Yes | Single (native) | ❌ No | Fast iteration, local testing |
| **Production** (default) | ❌ No | Multi-arch | ✅ Yes | Deployment, reproducible builds |

### Individual Scripts

All scripts support comprehensive tagging and can be used standalone:

```bash
./scripts/test.sh <tag>     # Run comprehensive tests
./scripts/push.sh <tag>     # Push multi-arch image  
./scripts/run.sh <tag>      # Interactive container
./scripts/info.sh <tag>     # Display build metadata
```
## Build Process

The build system automatically:

1. **Clones RACS-tools** from GitHub master branch
2. **Captures Git Metadata** (SHA, tags, build date)  
3. **Builds Container** with embedded metadata and validation
4. **Runs Tests** (development mode only)
5. **Pushes Multi-arch** (production mode only)
6. **Cleans Up** (if requested)

### Example Tags

- `convolve-v4.3.0-a1b2c3d-20250811` (with git tag)
- `convolve-a1b2c3d-20250811` (no git tag)

## Container Details

### Base Environment
- **Base**: casacore 3.7.1 with Ubuntu 24.04
- **RACS-tools**: Installed from source with binary validation
- **Python Environment**: Python 3 with full dependency stack
- **Health Check**: Automated binary validation

### Available Tools
- **Python modules**: `import racs_tools` 
- **Binaries**: `beamcon_2D`, `beamcon_3D` in `/usr/local/bin`
- **Source code**: Available at `/opt/RACS-tools`

### Runtime Features
- **Working Directory**: `/workspace` (auto-mounted when using `run.sh`)
- **Volume Support**: Automatic host directory mounting
- **Multi-arch**: Runs natively on both AMD64 and ARM64

## Advanced Usage

### Cleanup Options

```bash
# Safe cleanup (recommended) - only affects current project
./scripts/build.sh --check-build --cleanup

# Aggressive cleanup (CI/CD) - affects all Docker artifacts  
./scripts/build.sh --cleanup-aggressive
```

### Manual Operations

```bash
# View build help
./scripts/build.sh --help

# Get container metadata
./scripts/info.sh <tag>

# Run specific tests only
docker run --rm wasimraja81/askappy-ubuntu-24.04:<tag> python -c "import racs_tools; print('OK')"
```

## File Structure

```
.
├── Dockerfile                    # Multi-arch container definition
├── README.md                     # Documentation
├── .gitignore                    # Excludes tmp/ build artifacts
└── scripts/
    ├── build.sh                  # Main build orchestrator (two modes)
    ├── test.sh                   # Comprehensive test suite
    ├── push.sh                   # Multi-arch registry push
    ├── run.sh                    # Interactive container runner  
    └── info.sh                   # Build metadata display
```

## Development Workflow

### Typical Development Cycle

1. **Develop/Test**: `./scripts/build.sh --check-build`
2. **Iterate**: Make changes, repeat step 1
3. **Deploy**: `./scripts/build.sh` (production build)
4. **Cleanup**: Add `--cleanup` flag as needed

### CI/CD Integration

```yaml
# Example GitHub Actions usage
- name: Build and Push
  run: |
    ./scripts/build.sh --cleanup-aggressive
```

## Troubleshooting

### Build Issues
- Check Docker buildx is installed: `docker buildx version`
- Verify registry access: `docker login`
- For cache issues: Use `--no-cache` (already enabled in production)

### Test Failures  
- Binary validation fails: Check RACS-tools source integrity
- Import errors: Verify Python environment in container
- Platform issues: Test single-arch first with `--check-build`

### Cleanup Problems
- Use conservative cleanup by default: `--cleanup`
- Only use aggressive cleanup in isolated CI environments
- Check disk space: `docker system df`

---

## Registry Information

Images are pushed to:
- `wasimraja81/askappy-ubuntu-24.04:convolve-v4.3.0-a1b2c3d-20250811`
- Multi-architecture support: `linux/amd64`, `linux/arm64`
- Automatic platform detection for optimal performance

## Notes

- **Clean Production Builds**: No cache used in production mode for reproducibility
- **Git Integration**: Metadata preserved in container labels and `/opt/RACS-tools/BUILD_INFO.txt`  
- **Binary Access**: `beamcon_2D` and `beamcon_3D` available in `/usr/local/bin`
- **Error Handling**: All scripts use `set -e` for fail-fast behavior
- **Authentication**: Ensure `docker login` for registry access
