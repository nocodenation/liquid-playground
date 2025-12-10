#!/bin/bash

# Put all arguments into a variable for parsing
ARGS="$@"

# Initialize variables
PIP_PACKAGES=""
POST_INSTALL_COMMANDS=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --post-installation-commands)
            POST_INSTALL_COMMANDS="$2"
            shift # past argument
            shift # past value
            ;;
        *)
            # Append to pip packages
            PIP_PACKAGES="$PIP_PACKAGES $1"
            shift # past argument
            ;;
    esac
done

# Create a temporary copy of the Dockerfile
cp Dockerfile Dockerfile.tmp

# Determine sed in-place flag for GNU vs BSD (macOS)
if sed --version >/dev/null 2>&1; then
    # GNU sed
    SED_INPLACE=(-i)
else
    # BSD sed (macOS) requires a backup suffix (empty string to avoid backup files)
    SED_INPLACE=(-i '')
fi

# If pip packages are provided, inject a pip install command
if [ -n "$PIP_PACKAGES" ]; then
    echo "Injecting pip packages: $PIP_PACKAGES"
    # Insert after the apt-get install line
    # We look for the specific apt-get line and append a newline + pip install
    sed "${SED_INPLACE[@]}" -e "/RUN apt-get install -y python3 python3-pip/a \\
RUN pip3 install --break-system-packages $PIP_PACKAGES" Dockerfile.tmp
fi

# Inject post-installation commands if provided
if [ -n "$POST_INSTALL_COMMANDS" ]; then
    echo "Injecting post-installation commands..."
    INJECTED_COMMANDS=""
    
    # Split by comma
    IFS=',' read -ra CMDS <<< "$POST_INSTALL_COMMANDS"
    
    # helper variable to manage newlines/backslashes
    FIRST=true
    
    for cmd in "${CMDS[@]}"; do
        if [ "$FIRST" = true ]; then
            INJECTED_COMMANDS="RUN $cmd"
            FIRST=false
        else
            # Append with backslash (for sed continuation) and literal newline
            INJECTED_COMMANDS="${INJECTED_COMMANDS}\\
RUN $cmd"
        fi
    done
    
    # Insert before USER nifi:nifi
    sed "${SED_INPLACE[@]}" -e "/USER nifi:nifi/i \\
$INJECTED_COMMANDS" Dockerfile.tmp
fi

# Check for build_extensions.sh and inject it into Dockerfile
if [ -f "build_extensions.sh" ]; then
    echo "Found build_extensions.sh, injecting into Docker build..."
    
    # Define the insertion point (before switching to nifi user)
    INSERT_POINT="USER nifi:nifi"
    
    # Check for .whl files in the current directory to inject
    COPY_WHEELS=""
    if compgen -G "*.whl" > /dev/null; then
        echo "Found .whl files, injecting into Docker build..."
        COPY_WHEELS="COPY *.whl /tmp/"
    fi
    
    # Content to insert
    # We use a literal newline in the variable for reliable insertion
    INSERT_CONTENT="COPY build_extensions.sh /tmp/build_extensions.sh\\
${COPY_WHEELS}\\
RUN chmod +x /tmp/build_extensions.sh && /tmp/build_extensions.sh"
    
    # Determine sed in-place flag for GNU vs BSD (macOS) if not already set
    if [ -z "$SED_INPLACE" ]; then
        if sed --version >/dev/null 2>&1; then
            SED_INPLACE=(-i)
        else
            SED_INPLACE=(-i '')
        fi
    fi

    # Insert the content before the user switch
    sed "${SED_INPLACE[@]}" -e "/$INSERT_POINT/i \\
$INSERT_CONTENT" Dockerfile.tmp
fi

# Stop existing container if it's running
docker compose down

# Remove existing image if it exists
docker image rm nocodenation/liquid-playground:latest

# Build the Docker image using the temporary Dockerfile
if uname -a | grep "arm64"; then
    ARCH=linux/arm64
else
    ARCH=linux/amd64
fi
echo "$ARCH"
docker build -t nocodenation/liquid-playground:latest -f Dockerfile.tmp --platform $ARCH .

# Clean up the temporary Dockerfile
rm Dockerfile.tmp
