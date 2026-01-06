#!/bin/bash

EXTENSION_PATHS=()
SAVE_CREDENTIALS=false
CLEAR_ALL_FLOWS=false
CLI_USERNAME=""
CLI_PASSWORD=""
ADDITIONAL_PORT_MAPPINGS=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -s|--save-credentials)
      SAVE_CREDENTIALS=true
      shift
      ;;
    -c|--clear-all-flows)
      CLEAR_ALL_FLOWS=true
      shift
      ;;
    -u|--username)
      CLI_USERNAME="$2"
      shift 2
      ;;
    -p|--password)
      CLI_PASSWORD="$2"
      shift 2
      ;;
    --add-port-mapping)
      ADDITIONAL_PORT_MAPPINGS="$2"
      shift 2
      ;;
    *)
      EXTENSION_PATHS+=("$1")
      shift
      ;;
  esac
done

# Handle legacy credentials file
if [ -f .nifi_credentials ] && [ ! -f .credentials ]; then
    echo "Renaming .nifi_credentials to .credentials..."
    mv .nifi_credentials .credentials
fi

CREDENTIALS_FILE=".credentials"
EFFECTIVE_USERNAME=""
EFFECTIVE_PASSWORD=""
USE_CUSTOM_CREDENTIALS=false
CREDENTIALS_SOURCE=""

# 1. Check CLI Arguments
if [ -n "$CLI_USERNAME" ] && [ -n "$CLI_PASSWORD" ]; then
    if [ ${#CLI_PASSWORD} -ge 12 ]; then
        EFFECTIVE_USERNAME="$CLI_USERNAME"
        EFFECTIVE_PASSWORD="$CLI_PASSWORD"
        USE_CUSTOM_CREDENTIALS=true
        CREDENTIALS_SOURCE="CLI"
        echo "Using credentials provided via command line."
    else
        echo "WARNING: Command line password is too short (<12 chars). NiFi would reject it."
        echo "         Ignoring CLI credentials."
    fi
elif [ -n "$CLI_USERNAME" ] || [ -n "$CLI_PASSWORD" ]; then
    echo "WARNING: Both username and password must be provided via command line. Ignoring partial input."
fi

# 2. Check File (if not already set by CLI)
if [ "$USE_CUSTOM_CREDENTIALS" = false ] && [ -f "$CREDENTIALS_FILE" ]; then
  file_username=$(grep "SINGLE_USER_CREDENTIALS_USERNAME" "$CREDENTIALS_FILE" | cut -d= -f2 | tr -d '\r')
  file_password=$(grep "SINGLE_USER_CREDENTIALS_PASSWORD" "$CREDENTIALS_FILE" | cut -d= -f2 | tr -d '\r')
  
  if [ -n "$file_username" ] && [ -n "$file_password" ]; then
      if [ ${#file_password} -ge 12 ]; then
          EFFECTIVE_USERNAME="$file_username"
          EFFECTIVE_PASSWORD="$file_password"
          USE_CUSTOM_CREDENTIALS=true
          CREDENTIALS_SOURCE="FILE"
          echo "Found valid credentials in $CREDENTIALS_FILE."
      else
          echo "WARNING: Found $CREDENTIALS_FILE but password is too short (<12 chars)."
          echo "         Ignoring file."
      fi
  else
      echo "WARNING: Found $CREDENTIALS_FILE but username or password is missing."
      echo "         Ignoring file."
  fi
fi

if [ "$USE_CUSTOM_CREDENTIALS" = false ]; then
    echo "No valid custom credentials found. NiFi will generate new credentials."
    CREDENTIALS_SOURCE="GENERATED"
fi

# Stop any existing container
echo "Stopping any existing container..."
docker compose down

# Handle persistence state
STATE_DIR="./state"

if [ "$CLEAR_ALL_FLOWS" = true ]; then
    echo "Clearing all persisted flows and state..."
    if [ -d "$STATE_DIR" ]; then
        rm -rf "$STATE_DIR"
        echo "State directory deleted."
    else
        echo "No state directory found to clear."
    fi
fi

# Create state directories if they don't exist
mkdir -p "$STATE_DIR/conf"
mkdir -p "$STATE_DIR/database_repository"
mkdir -p "$STATE_DIR/flowfile_repository"
mkdir -p "$STATE_DIR/content_repository"
mkdir -p "$STATE_DIR/provenance_repository"
mkdir -p "$STATE_DIR/run" # For Process ID

# Create SSL certificates directory if it doesn't exist
mkdir -p "./ssl_certificates"

# Initialize configuration if empty (Bootstrap Persistence)
if [ -z "$(ls -A "$STATE_DIR/conf")" ]; then
    echo "Initializing persistent configuration..."
    # Run a temporary container to copy default config
    docker run --rm \
        -v "$(pwd)/$STATE_DIR/conf":/target \
        --entrypoint /bin/bash \
        nocodenation/liquid-playground:latest \
        -c "cp -r /opt/nifi/nifi-current/conf/* /target/"
    echo "Configuration initialized."
fi

# Ensure permissions (Docker user is usually 1000:1000 for NiFi image)
# We use a broad chmod here to avoid permission issues on mounts
chmod -R 777 "$STATE_DIR"

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
    $0 ~ /volumes:/ {
      print "      - ./state/conf:/opt/nifi/nifi-current/conf:z"
      print "      - ./state/database_repository:/opt/nifi/nifi-current/database_repository:z"
      print "      - ./state/flowfile_repository:/opt/nifi/nifi-current/flowfile_repository:z"
      print "      - ./state/content_repository:/opt/nifi/nifi-current/content_repository:z"
      print "      - ./state/provenance_repository:/opt/nifi/nifi-current/provenance_repository:z"
      print "      - ./ssl_certificates:/opt/nifi/nifi-current/ssl:z"
    }
  ' docker-compose.tmp.yml > docker-compose.tmp.yml.new && mv docker-compose.tmp.yml.new docker-compose.tmp.yml
else
  # No credentials file, but we still need to add persistence volumes
  awk '
    { print }
    $0 ~ /volumes:/ {
      print "      - ./state/conf:/opt/nifi/nifi-current/conf:z"
      print "      - ./state/database_repository:/opt/nifi/nifi-current/database_repository:z"
      print "      - ./state/flowfile_repository:/opt/nifi/nifi-current/flowfile_repository:z"
      print "      - ./state/content_repository:/opt/nifi/nifi-current/content_repository:z"
      print "      - ./state/provenance_repository:/opt/nifi/nifi-current/provenance_repository:z"
      print "      - ./ssl_certificates:/opt/nifi/nifi-current/ssl:z"
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
    # Remove surrounding quotes if present
    port_mapping=$(echo "$port_mapping" | sed 's/^"//;s/"$//')
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
      echo "Using credentials from $CREDENTIALS_SOURCE:"
      echo ""
      echo "Username: $EFFECTIVE_USERNAME"
      echo "Password: $EFFECTIVE_PASSWORD"
      echo ""
      
      # If CLI was source and save requested, save them
      if [ "$CREDENTIALS_SOURCE" == "CLI" ] && [ "$SAVE_CREDENTIALS" = true ]; then
          echo "Saving provided credentials to $CREDENTIALS_FILE..."
          echo "SINGLE_USER_CREDENTIALS_USERNAME=$EFFECTIVE_USERNAME" > "$CREDENTIALS_FILE"
          echo "SINGLE_USER_CREDENTIALS_PASSWORD=$EFFECTIVE_PASSWORD" >> "$CREDENTIALS_FILE"
          echo "Credentials saved."
          echo ""
      fi
    else
      # Generated
      echo "Extracting generated credentials..."
      echo ""
      username=$(docker compose -f docker-compose.tmp.yml logs | grep "Generated Username" | tail -n 1 | sed -E 's/.*\[([^]]*)\].*/\1/')
      password=$(docker compose -f docker-compose.tmp.yml logs | grep "Generated Password" | tail -n 1 | sed -E 's/.*\[([^]]*)\].*/\1/')
      echo "Username: $username"
      echo "Password: $password"
      echo ""
      
      if [ "$SAVE_CREDENTIALS" = true ]; then
          echo "Saving generated credentials to $CREDENTIALS_FILE..."
          echo "SINGLE_USER_CREDENTIALS_USERNAME=$username" > "$CREDENTIALS_FILE"
          echo "SINGLE_USER_CREDENTIALS_PASSWORD=$password" >> "$CREDENTIALS_FILE"
          echo "Credentials saved."
          echo ""
      fi
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
