# Convolve Container

This repository contains the Docker setup for building a container with RACS-tools installed on top of a base casacore image.

## Overview

- **Base Image**: `wasimraja81/base-casacore:casacore-3.7.1-20250810-607f488`
- **Target Registry**: `wasimraja81/askappy-ubuntu-24.04:convolve-<tag>`
- **Source Code**: [RACS-tools](https://github.com/AlecThomson/RACS-tools.git) (cloned during build)

## Key Features

- **Fresh RACS-tools**: Always builds from the latest master branch
- **Metadata Preservation**: Captures git SHA, tags, and build date
- **Binary Access**: `beamcon_2D` and `beamcon_3D` available in `/usr/local/bin`
- **Build Reproducibility**: Git metadata embedded in container labels and build info
- **Smart Tagging**: Uses actual RACS-tools git tags for container versions

## Quick Start

### Building the Container

```bash
# Build with automatic timestamp tag
./scripts/build.sh

# Build with custom tag  
./scripts/build.sh v1.0.0
```

The build process will:
1. Clone the latest RACS-tools from GitHub
2. Capture git metadata (SHA, tags, build date)
3. Build the container with embedded metadata
4. Tag with both build timestamp and RACS-tools git tag (e.g., `convolve-v4.3.0`)
5. Clean up temporary files

### Testing the Container

```bash
# Test with a specific version
./scripts/test.sh v1.0.0

# Test the most recent git tag version (auto-detected)
./scripts/test.sh
```

Tests include:
- Python and RACS-tools import verification
- Binary availability (`beamcon_2D`, `beamcon_3D`)
- Build metadata display

### Pushing to Registry

```bash
# Push latest built image
./scripts/push.sh

# Push specific version
./scripts/push.sh v1.0.0
```

### Running Interactively

```bash
# Run with latest image
./scripts/run.sh

# Run with specific version
./scripts/run.sh v1.0.0
```

## Container Details

The container includes:

- **Base**: casacore 3.7.1 pre-installed
- **RACS-tools**: Installed from source at `/opt/RACS-tools`
- **Python Environment**: Python 3 with all RACS-tools dependencies
- **Working Directory**: `/workspace` (mounted from host when using `run.sh`)

### Available Tools

RACS-tools provides various radio astronomy utilities. After starting the container, you can access:

- Python modules: `import racs_tools`
- Command-line tools: Available in `/opt/RACS-tools/bin/`

## File Structure

```
.
├── Dockerfile              # Main container definition
├── README.md               # This file
├── scripts/
│   ├── build.sh            # Build the container
│   ├── push.sh             # Push to registry  
│   ├── test.sh             # Test container functionality
│   ├── run.sh              # Run container interactively
│   └── info.sh             # Show build metadata
├── tmp/                    # Temporary build directory (auto-cleaned)
└── .gitignore              # Git ignore file
```

## Usage Examples

### Building and Deploying

1. **Build the container**:
   ```bash
   ./scripts/build.sh v1.0.0
   ```

2. **Test it works**:
   ```bash
   ./scripts/test.sh v1.0.0
   ```

3. **Push to registry**:
   ```bash
   ./scripts/push.sh v1.0.0
   ```

### Development Workflow

1. **Start interactive session**:
   ```bash
   ./scripts/run.sh
   ```

2. **Test RACS-tools functionality**:
   ```bash
   python3 -c "import racs_tools; print('RACS-tools loaded successfully')"
   ```

## Registry Information

Images will be pushed to:
- `wasimraja81/askappy-ubuntu-24.04:convolve-<your-version>` (e.g., `convolve-v1.0.0`)
- `wasimraja81/askappy-ubuntu-24.04:convolve-<racs-git-tag>` (e.g., `convolve-v4.3.0`)

## Notes

- **Base Image**: Built on `wasimraja81/base-casacore:casacore-3.7.1-20250810-607f488`
- Make sure Docker is installed and you're logged into your Docker Hub registry
- The scripts automatically handle tagging with both your version and the RACS-tools git tag
- All scripts include error handling (`set -e`) to stop on any failures
- Git metadata is preserved in container labels and `/opt/RACS-tools/BUILD_INFO.txt`
- Binaries `beamcon_2D` and `beamcon_3D` are available in `/usr/local/bin`
