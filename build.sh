#!/bin/bash

# Get additional packages from command line arguments
ADDITIONAL_PACKAGES="$*"

# Create a temporary copy of the Dockerfile
cp Dockerfile Dockerfile.tmp

# If additional packages are provided, append them to the apt-get install line
if [ -n "$ADDITIONAL_PACKAGES" ]; then
    # Escape special characters in the replacement string
    ESCAPED_PACKAGES=$(echo "$ADDITIONAL_PACKAGES" | sed 's/[\/&]/\\&/g')
    # Find the line with apt-get install and append the additional packages
    sed -i 's/\(RUN apt-get install -y python3 python3-pip\)/\1 '"$ESCAPED_PACKAGES"'/' Dockerfile.tmp
fi

# Stop existing container if it's running
docker compose down

# Remove existing image if it exists
docker image rm nocodenation/liquid-playground:latest

# Build the Docker image using the temporary Dockerfile
docker build -t nocodenation/liquid-playground:latest -f Dockerfile.tmp .

# Clean up the temporary Dockerfile
rm Dockerfile.tmp
