# Build container for RACS-tools (convolve)
# Base image with casacore already installed
FROM wasimraja81/base-casacore:casacore-3.7.1-20250810-607f488

# Build arguments for RACS-tools metadata
ARG RACS_GIT_SHA
ARG RACS_GIT_TAG
ARG RACS_GIT_DESCRIBE
ARG RACS_BUILD_DATE

# Set metadata
LABEL maintainer="wasimraja81"
LABEL description="Container with RACS-tools for radio astronomy data processing"
LABEL racs_tools.git_sha="${RACS_GIT_SHA}"
LABEL racs_tools.git_tag="${RACS_GIT_TAG}"
LABEL racs_tools.git_describe="${RACS_GIT_DESCRIBE}"
LABEL racs_tools.build_date="${RACS_BUILD_DATE}"

# Set working directory
WORKDIR /opt

# Update package lists and install build dependencies
RUN apt-get update && apt-get install -y \
    python3-pip \
    python3-dev \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Copy the cloned RACS-tools repository
COPY tmp/RACS-tools /opt/RACS-tools

# Change to RACS-tools directory and install
WORKDIR /opt/RACS-tools

# Install RACS-tools and its dependencies using pip (which handles pyproject.toml)
RUN pip3 install -e .

# Verify binaries are installed and accessible (they should be in /usr/local/bin after pip install)
RUN which beamcon_2D && which beamcon_3D

# Create metadata file with build information
RUN echo "RACS-tools Build Information" > /opt/RACS-tools/BUILD_INFO.txt && \
    echo "Git SHA: ${RACS_GIT_SHA}" >> /opt/RACS-tools/BUILD_INFO.txt && \
    echo "Git Tag: ${RACS_GIT_TAG}" >> /opt/RACS-tools/BUILD_INFO.txt && \
    echo "Git Describe: ${RACS_GIT_DESCRIBE}" >> /opt/RACS-tools/BUILD_INFO.txt && \
    echo "Build Date: ${RACS_BUILD_DATE}" >> /opt/RACS-tools/BUILD_INFO.txt

# Create a working directory for user data
WORKDIR /workspace

# Set environment variables
ENV PYTHONPATH="/opt/RACS-tools:${PYTHONPATH}"
ENV PATH="/opt/RACS-tools:${PATH}"

# Default command
CMD ["/bin/bash"]
