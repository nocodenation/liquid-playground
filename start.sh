#!/bin/bash

PYTHON_PROCESSOR_PATHS=()
SAVE_CREDENTIALS=false
CLI_USERNAME=""
CLI_PASSWORD=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -s|--save-credentials)
      SAVE_CREDENTIALS=true
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
    *)
      PYTHON_PROCESSOR_PATHS+=("$1")
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

# If Python processor paths are provided, add them as volume mounts
if [ ${#PYTHON_PROCESSOR_PATHS[@]} -gt 0 ]; then
  echo "Adding Python processor paths as volume mounts..."

  # Build the block of lines to insert after the python_extensions mount
  INSERT_LINES=""
  for path in "${PYTHON_PROCESSOR_PATHS[@]}"; do
    # Remove trailing slash if present
    path=${path%/}
    # Get the basename of the path to use as the mount point
    basename=$(basename "$path")
    # Append the new volume mount line with proper indentation and newline
    INSERT_LINES+="      - ${path}:/opt/nifi/nifi-current/python_extensions/${basename}:z\n"
  done

  # Use awk to insert the constructed lines immediately after the python_extensions entry
  awk -v insert="$INSERT_LINES" '
    inserted==0 && $0 ~ /^[[:space:]]*- \.\/python_extensions:\/opt\/nifi\/nifi-current\/python_extensions:z$/ {
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
