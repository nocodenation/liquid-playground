#!/bin/bash

# Load environment variables from .env file if it exists
if [ -f .env ]; then
    # Export variables from .env file, ignoring comments and empty lines
    set -a
    source .env
    set +a
fi

# Use environment variables (with defaults if not set)
PERSIST_NIFI_STATE="${PERSIST_NIFI_STATE:-false}"
CLI_USERNAME="${NIFI_USERNAME:-}"
CLI_PASSWORD="${NIFI_PASSWORD:-}"
ADDITIONAL_PORT_MAPPINGS="${ADDITIONAL_PORT_MAPPINGS:-}"
EXTENSION_PATHS_STR="${EXTENSION_PATHS:-}"

# Parse EXTENSION_PATHS from comma-separated string to array
EXTENSION_PATHS=()
if [ -n "$EXTENSION_PATHS_STR" ]; then
    IFS=',' read -r -a __PATHS <<< "$EXTENSION_PATHS_STR"
    for p in "${__PATHS[@]}"; do
        trimmed=$(echo "$p" | xargs)
        if [ -n "$trimmed" ]; then
            EXTENSION_PATHS+=("$trimmed")
        fi
    done
fi

# Convert string values to boolean-like behavior
if [ "$PERSIST_NIFI_STATE" = "true" ]; then
    PERSIST_NIFI_STATE=true
else
    PERSIST_NIFI_STATE=false
fi

EFFECTIVE_USERNAME=""
EFFECTIVE_PASSWORD=""
USE_CUSTOM_CREDENTIALS=false

# Check Environment Variables (CLI_USERNAME and CLI_PASSWORD from .env)
if [ -n "$CLI_USERNAME" ] && [ -n "$CLI_PASSWORD" ]; then
    if [ ${#CLI_PASSWORD} -ge 12 ]; then
        EFFECTIVE_USERNAME="$CLI_USERNAME"
        EFFECTIVE_PASSWORD="$CLI_PASSWORD"
        USE_CUSTOM_CREDENTIALS=true
        echo "Using credentials provided via environment variables."
    else
        echo "WARNING: Environment variable password is too short (<12 chars). NiFi would reject it."
        echo "         Ignoring environment credentials."
    fi
elif [ -n "$CLI_USERNAME" ] || [ -n "$CLI_PASSWORD" ]; then
    echo "WARNING: Both NIFI_USERNAME and NIFI_PASSWORD must be provided via environment. Ignoring partial input."
fi

if [ "$USE_CUSTOM_CREDENTIALS" = false ]; then
    echo "No custom credentials found. NiFi will generate new credentials."
fi

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

# Setup Env File for Docker
TEMP_ENV_FILE=".env.tmp"
rm -f "$TEMP_ENV_FILE"

if [ "$USE_CUSTOM_CREDENTIALS" = true ]; then
  # Create temporary env file to pass credentials to container safely
  echo "SINGLE_USER_CREDENTIALS_USERNAME=$EFFECTIVE_USERNAME" > "$TEMP_ENV_FILE"
  echo "SINGLE_USER_CREDENTIALS_PASSWORD=$EFFECTIVE_PASSWORD" >> "$TEMP_ENV_FILE"
  
  echo "Configuring container to use provided credentials..."
  awk -v env_file="$TEMP_ENV_FILE" '
    { print }
    $0 ~ /container_name: liquid-playground/ {
      print "    env_file:"
      print "      - " env_file
    }
  ' docker-compose.tmp.yml > docker-compose.tmp.yml.new && mv docker-compose.tmp.yml.new docker-compose.tmp.yml
fi

# Add persistence volume mounts if PERSIST_NIFI_STATE is true
if [ "$PERSIST_NIFI_STATE" = true ]; then
  echo "Adding persistence volume mounts..."
  awk '
    { print }
    $0 ~ /volumes:/ {
      print "      - ./state/conf:/opt/nifi/nifi-current/conf:z"
      print "      - ./state/database_repository:/opt/nifi/nifi-current/database_repository:z"
      print "      - ./state/flowfile_repository:/opt/nifi/nifi-current/flowfile_repository:z"
      print "      - ./state/content_repository:/opt/nifi/nifi-current/content_repository:z"
      print "      - ./state/provenance_repository:/opt/nifi/nifi-current/provenance_repository:z"
    }
  ' docker-compose.tmp.yml > docker-compose.tmp.yml.new && mv docker-compose.tmp.yml.new docker-compose.tmp.yml
fi

# If extension paths are provided, add them as volume mounts
if [ ${#EXTENSION_PATHS[@]} -gt 0 ]; then
  echo "Processing extension paths..."

  # Build the block of lines to insert
  PYTHON_MOUNTS=""
  NAR_MOUNTS=""

  for path in "${EXTENSION_PATHS[@]}"; do
    # Remove trailing slash if present
    path=${path%/}

    # Check if it's a file or directory
    if [ -f "$path" ]; then
      # It's a file - check extension
      if [[ "$path" == *.py ]]; then
        # Python file
        basename=$(basename "$path")
        PYTHON_MOUNTS+="      - ${path}:/opt/nifi/nifi-current/python_extensions/${basename}:z\n"
        echo "  - Mounting Python file: $basename"
      elif [[ "$path" == *.nar ]]; then
        # NAR file
        basename=$(basename "$path")
        NAR_MOUNTS+="      - ${path}:/opt/nifi/nifi-current/lib/${basename}:z\n"
        echo "  - Mounting NAR file: $basename"
      else
        echo "  - WARNING: Skipping unsupported file type: $path"
      fi
    elif [ -d "$path" ]; then
      # It's a directory - check contents
      basename=$(basename "$path")
      has_python=false
      has_nar=false

      # Check for Python files
      if find "$path" -maxdepth 1 -name "*.py" -print -quit | grep -q .; then
        has_python=true
      fi

      # Check for NAR files
      if find "$path" -maxdepth 1 -name "*.nar" -print -quit | grep -q .; then
        has_nar=true
      fi

      if [ "$has_python" = true ] && [ "$has_nar" = false ]; then
        # Directory with Python files
        PYTHON_MOUNTS+="      - ${path}:/opt/nifi/nifi-current/python_extensions/${basename}:z\n"
        echo "  - Mounting Python directory: $basename"
      elif [ "$has_nar" = true ]; then
        # Directory with NAR files - mount each NAR individually
        echo "  - Mounting NAR files from directory: $basename"
        for nar_file in "$path"/*.nar; do
          if [ -f "$nar_file" ]; then
            nar_basename=$(basename "$nar_file")
            NAR_MOUNTS+="      - ${nar_file}:/opt/nifi/nifi-current/lib/${nar_basename}:z\n"
            echo "    - $nar_basename"
          fi
        done
      else
        echo "  - WARNING: Skipping directory with no Python or NAR files: $path"
      fi
    else
      echo "  - WARNING: Path not found: $path"
    fi
  done

  # Insert Python mounts after the python_extensions entry
  if [ -n "$PYTHON_MOUNTS" ]; then
    awk -v insert="$PYTHON_MOUNTS" '
      inserted==0 && $0 ~ /^[[:space:]]*- \.\/python_extensions:\/opt\/nifi\/nifi-current\/python_extensions:z$/ {
        print;
        printf "%s", insert;
        inserted=1;
        next
      }
      { print }
    ' docker-compose.tmp.yml > docker-compose.tmp.yml.new && mv docker-compose.tmp.yml.new docker-compose.tmp.yml
  fi

  # Insert NAR mounts after the nar_extensions entry
  if [ -n "$NAR_MOUNTS" ]; then
    awk -v insert="$NAR_MOUNTS" '
      inserted==0 && $0 ~ /^[[:space:]]*- \.\/nar_extensions:\/opt\/nifi\/nifi-current\/nar_extensions:z$/ {
        print;
        printf "%s", insert;
        inserted=1;
        next
      }
      { print }
    ' docker-compose.tmp.yml > docker-compose.tmp.yml.new && mv docker-compose.tmp.yml.new docker-compose.tmp.yml
  fi
fi

# If additional port mappings are provided, add them to the docker-compose file
if [ -n "$ADDITIONAL_PORT_MAPPINGS" ]; then
  echo "Adding additional port mappings..."
  
  # Build the block of lines to insert after the existing ports
  INSERT_LINES=""
  IFS=',' read -ra PORTS <<< "$ADDITIONAL_PORT_MAPPINGS"
  for port_mapping in "${PORTS[@]}"; do
    # Remove surrounding quotes if present and trim whitespace
    port_mapping=$(echo "$port_mapping" | sed 's/^"//;s/"$//' | xargs)
    INSERT_LINES+="      - \"${port_mapping}\"\n"
  done

  # Use awk to insert the constructed lines immediately after the 8443 port entry
  awk -v insert="$INSERT_LINES" '
    inserted==0 && $0 ~ /^[[:space:]]*- "8443:8443"$/ {
      print;
      printf "%s", insert;
      inserted=1;
      next
    }
    { print }
  ' docker-compose.tmp.yml > docker-compose.tmp.yml.new && mv docker-compose.tmp.yml.new docker-compose.tmp.yml
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

    if [ "$USE_CUSTOM_CREDENTIALS" = true ]; then
      echo "Using credentials from environment variables:"
      echo ""
      echo "Username: $EFFECTIVE_USERNAME"
      echo "Password: $EFFECTIVE_PASSWORD"
      echo ""
    else
      # Generated
      echo "Extracting generated credentials..."
      echo ""
      username=$(docker compose -f docker-compose.tmp.yml logs | grep "Generated Username" | tail -n 1 | sed -E 's/.*\[([^]]*)\].*/\1/')
      password=$(docker compose -f docker-compose.tmp.yml logs | grep "Generated Password" | tail -n 1 | sed -E 's/.*\[([^]]*)\].*/\1/')
      echo "Username: $username"
      echo "Password: $password"
      echo ""
    fi

    echo "Use these credentials to access NiFi: https://localhost:8443/nifi"

    # Clean up the temporary files
    rm docker-compose.tmp.yml
    if [ -f "$TEMP_ENV_FILE" ]; then
        rm "$TEMP_ENV_FILE"
    fi

    break
  fi

  # Wait for a moment before checking again
  sleep 5
  echo "Still waiting for NiFi to start..."
done
