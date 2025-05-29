#!/bin/bash

# Get Python processor paths from command line arguments
PYTHON_PROCESSOR_PATHS=("$@")

# Stop any existing container
echo "Stopping any existing container..."
docker compose down

# Check if the image exists
echo "Checking if the Docker image exists..."
if ! docker image inspect nocodenation/liquid-playground:latest &> /dev/null; then
  echo "Image does not exist. Running build.sh to create it..."
  ./build.sh
fi

# Create a temporary copy of the docker-compose.yml file
cp docker-compose.yml docker-compose.tmp.yml

# If Python processor paths are provided, add them as volume mounts
if [ ${#PYTHON_PROCESSOR_PATHS[@]} -gt 0 ]; then
  echo "Adding Python processor paths as volume mounts..."

  # Find the line number where the predefined volume mount ends
  VOLUMES_END=$(grep -n "./python_extensions:" docker-compose.tmp.yml | cut -d: -f1)
  VOLUMES_END=$((VOLUMES_END + 1))

  # Add each Python processor path as a volume mount
  for path in "${PYTHON_PROCESSOR_PATHS[@]}"; do
    # Remove trailing slash if present
    path=${path%/}
    # Get the basename of the path to use as the mount point
    basename=$(basename "$path")
    # Insert the new volume mount after the existing one
    sed -i "${VOLUMES_END}i\\      - ${path}:/opt/nifi/nifi-current/python_extensions/${basename}:r" docker-compose.tmp.yml
  done
fi

# Start the container with the temporary docker-compose file
echo "Starting the container..."
docker compose -f docker-compose.tmp.yml up -d

# Wait for NiFi to start and extract credentials
echo "Waiting for NiFi to start..."
while true; do
  # Check if the log contains the startup completion message
  if docker compose -f docker-compose.tmp.yml logs | grep -q "org.apache.nifi.runtime.Application Started Application in"; then
    echo ""
    echo "NiFi has started successfully!"

    # Extract and display the username and password
    echo "Extracting credentials..."
    echo ""
    username=$(docker compose -f docker-compose.tmp.yml logs | grep "Generated Username" | tail -n 1 | sed -E 's/.*\[([^]]*)\].*/\1/')
    password=$(docker compose -f docker-compose.tmp.yml logs | grep "Generated Password" | tail -n 1 | sed -E 's/.*\[([^]]*)\].*/\1/')
    echo "Username: $username"
    echo "Password: $password"
    echo ""

    echo "Use these credentials to access NiFi: https://localhost:8443/nifi"

    # Clean up the temporary docker-compose file
    rm docker-compose.tmp.yml

    break
  fi

  # Wait for a moment before checking again
  sleep 5
  echo "Still waiting for NiFi to start..."
done
