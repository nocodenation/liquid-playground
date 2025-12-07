#!/bin/bash

# Get additional packages from command line arguments
ADDITIONAL_PACKAGES="$*"

# Create a temporary copy of the Dockerfile
cp Dockerfile Dockerfile.tmp

# If additional packages are provided, append them to the apt-get install line
if [ -n "$ADDITIONAL_PACKAGES" ]; then
    # Escape special characters in the replacement string
    ESCAPED_PACKAGES=$(echo "$ADDITIONAL_PACKAGES" | sed 's/[\/&]/\\&/g')

    # Determine sed in-place flag for GNU vs BSD (macOS)
    if sed --version >/dev/null 2>&1; then
        # GNU sed
        SED_INPLACE=(-i)
    else
        # BSD sed (macOS) requires a backup suffix (empty string to avoid backup files)
        SED_INPLACE=(-i '')
    fi

    # Find the line with apt-get install and append the additional packages
    sed "${SED_INPLACE[@]}" -e 's/\(RUN apt-get install -y python3 python3-pip\)/\1 '"$ESCAPED_PACKAGES"'/' Dockerfile.tmp
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
