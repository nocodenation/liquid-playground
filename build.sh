#!/bin/bash

# Load environment variables from .env file if it exists
if [ -f .env ]; then
    # Export variables from .env file, ignoring comments and empty lines
    set -a
    source .env
    set +a
fi

# Use environment variables (with defaults if not set)
SYSTEM_DEPENDENCIES="${SYSTEM_DEPENDENCIES:-}"
POST_INSTALLATION_COMMANDS="${POST_INSTALLATION_COMMANDS:-}"
PERSIST_NIFI_STATE="${PERSIST_NIFI_STATE:-false}"

# Convert PERSIST_NIFI_STATE to boolean-like behavior
if [ "$PERSIST_NIFI_STATE" = "true" ]; then
    PERSIST_NIFI_STATE=true
else
    PERSIST_NIFI_STATE=false
fi

# Build the final list of additional packages from SYSTEM_DEPENDENCIES
ADDITIONAL_PACKAGES_STR=""
if [ -n "$SYSTEM_DEPENDENCIES" ]; then
    IFS=',' read -r -a __DEPS <<< "$SYSTEM_DEPENDENCIES"
    __DEPS_TRIMMED=()
    for d in "${__DEPS[@]}"; do
        trimmed=$(echo "$d" | xargs)
        if [ -n "$trimmed" ]; then
            __DEPS_TRIMMED+=("$trimmed")
        fi
    done
    ADDITIONAL_PACKAGES_STR="${__DEPS_TRIMMED[*]}"
fi

# Create a temporary copy of the Dockerfile
cp Dockerfile Dockerfile.tmp

# If additional packages are provided, append them to the apt-get install line
if [ -n "$ADDITIONAL_PACKAGES_STR" ]; then
    # Escape special characters in the replacement string
    ESCAPED_PACKAGES=$(echo "$ADDITIONAL_PACKAGES_STR" | sed 's/[\/&]/\\&/g')

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

# If post installation commands provided, inject them under the marker in Dockerfile
if [ -n "$POST_INSTALLATION_COMMANDS" ]; then
    # Build the block of RUN commands from comma-separated list
    IFS=',' read -r -a __CMDS <<< "$POST_INSTALLATION_COMMANDS"
    POST_INSTALL_BLOCK=""
    for c in "${__CMDS[@]}"; do
        # trim whitespace around the command
        trimmed=$(echo "$c" | xargs)
        if [ -n "$trimmed" ]; then
            POST_INSTALL_BLOCK+="RUN $trimmed\n"
        fi
    done

    # Insert the block right after the line that has the marker
    awk -v block="$POST_INSTALL_BLOCK" '
      {
        print $0
        if ($0 ~ /# POST_INSTALL_COMMANDS/) {
          n = split(block, lines, "\\n");
          for (i = 1; i <= n; i++) if (length(lines[i]) > 0) print lines[i];
        }
      }
    ' Dockerfile.tmp > Dockerfile.tmp.__new && mv Dockerfile.tmp.__new Dockerfile.tmp
fi

# Extract ENVIRONMENT_VARIABLES from .env without evaluation (preserve literal values like $PATH)
# Note: $$ is used in .env to escape $ for docker compose, so we convert $$ back to $ here
RAW_ENVIRONMENT_VARIABLES=""
if [ -f .env ]; then
    RAW_ENVIRONMENT_VARIABLES=$(grep -E '^ENVIRONMENT_VARIABLES=' .env | head -n 1 | sed 's/^ENVIRONMENT_VARIABLES=//' | sed 's/^"\(.*\)"$/\1/' | sed "s/^'\(.*\)'$/\1/" | sed 's/\$\$/$/g')
fi

# If environment variables are provided, inject export statements into ~/.bashrc
if [ -n "$RAW_ENVIRONMENT_VARIABLES" ]; then
    echo "Adding environment variables to image's ~/.bashrc..."
    
    # Build the block of RUN commands to append exports to /root/.bashrc
    ENV_EXPORTS_BLOCK=""
    
    # Parse comma-separated key=value pairs
    # First, convert escaped quotes to a placeholder, then split on comma, then restore
    # Replace \" with a placeholder that won't appear in normal values
    placeholder=$'\x01'
    normalized=$(echo "$RAW_ENVIRONMENT_VARIABLES" | sed "s/\\\\\"/$placeholder/g")
    
    IFS=',' read -r -a __ENV_VARS <<< "$normalized"
    for env_var in "${__ENV_VARS[@]}"; do
        # Trim whitespace
        env_var=$(echo "$env_var" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        # Restore escaped quotes (placeholder back to regular quotes)
        env_var=$(echo "$env_var" | sed "s/$placeholder/\"/g")
        
        if [ -n "$env_var" ]; then
            # Remove surrounding quotes from the value part if present
            # e.g., VAR="value" -> VAR=value for the export
            env_var=$(echo "$env_var" | sed 's/="\(.*\)"$/=\1/' | sed "s/='\(.*\)'$/=\1/")
            
            # Escape single quotes for use in the echo command (replace ' with '\''
            escaped_for_echo=$(echo "$env_var" | sed "s/'/'\\\\''/g")
            
            ENV_EXPORTS_BLOCK+="RUN echo 'export $escaped_for_echo' >> /root/.bashrc\n"
            ENV_EXPORTS_BLOCK+="RUN echo 'export $escaped_for_echo' >> /home/nifi/.bashrc\n"
            echo "  - Adding: export $env_var"
        fi
    done
    
    # Insert the block right after the ENVIRONMENT_VARIABLES_EXPORTS marker
    if [ -n "$ENV_EXPORTS_BLOCK" ]; then
        awk -v block="$ENV_EXPORTS_BLOCK" '
          {
            print $0
            if ($0 ~ /# ENVIRONMENT_VARIABLES_EXPORTS/) {
              n = split(block, lines, "\\n");
              for (i = 1; i <= n; i++) if (length(lines[i]) > 0) print lines[i];
            }
          }
        ' Dockerfile.tmp > Dockerfile.tmp.__new && mv Dockerfile.tmp.__new Dockerfile.tmp
    fi
fi

# Stop existing container if it's running
docker compose down

# Remove existing image if it exists
# Suppress error if the image doesn't exist and silence output
docker image rm nocodenation/liquid-playground:latest >/dev/null 2>&1 || true

# Build the Docker image using the temporary Dockerfile
if uname -a | grep "arm64"; then
    ARCH=linux/arm64
else
    ARCH=linux/amd64
fi
echo "Building nocodenation/liquid-playground:latest for $ARCH"
docker build -t nocodenation/liquid-playground:latest -f Dockerfile.tmp --platform $ARCH .

# Clean up the temporary Dockerfile
rm Dockerfile.tmp

# Handle PERSIST_NIFI_STATE - create state folder and copy directories from image
if [ "$PERSIST_NIFI_STATE" = true ]; then
    STATE_DIR="./nifi_state"
    
    # Check if state folder already exists
    if [ -d "$STATE_DIR" ]; then
        echo ""
        echo "State folder already exists at $STATE_DIR"
        read -p "Do you want to overwrite its contents? (y/N): " confirm
        if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
            echo "Skipping state folder creation."
        else
            echo "Removing existing state folder..."
            # Removing state folder requires sudo if not running as root
            if [ "$(id -u)" != "0" ]; then
                echo "Root privileges required to remove state folder."
                sudo rm -rf "$STATE_DIR"
            else
                rm -rf "$STATE_DIR"
            fi
            
            echo "Creating state folder and copying directories from image..."
            mkdir -p "$STATE_DIR"
            chmod 777 "$STATE_DIR"
            
            # Run a temporary container to copy directories
            docker run --rm \
                -v "$(pwd)/$STATE_DIR":/target \
                --entrypoint /bin/bash \
                nocodenation/liquid-playground:latest \
                -c "cp -r /opt/nifi/nifi-current/conf /target/ && \
                    cp -r /opt/nifi/nifi-current/database_repository /target/ && \
                    cp -r /opt/nifi/nifi-current/flowfile_repository /target/ && \
                    cp -r /opt/nifi/nifi-current/content_repository /target/ && \
                    cp -r /opt/nifi/nifi-current/provenance_repository /target/ && \
                    cp -r /opt/nifi/nifi-current/state /target/"
            
            echo "State folder created successfully."
        fi
    else
        echo "Creating state folder and copying directories from image..."
        mkdir -p "$STATE_DIR"
        chmod 777 "$STATE_DIR"
        
        # Run a temporary container to copy directories
        docker run --rm \
            -v "$(pwd)/$STATE_DIR":/target \
            --entrypoint /bin/bash \
            nocodenation/liquid-playground:latest \
            -c "cp -r /opt/nifi/nifi-current/conf /target/ && \
                cp -r /opt/nifi/nifi-current/database_repository /target/ && \
                cp -r /opt/nifi/nifi-current/flowfile_repository /target/ && \
                cp -r /opt/nifi/nifi-current/content_repository /target/ && \
                cp -r /opt/nifi/nifi-current/provenance_repository /target/ && \
                cp -r /opt/nifi/nifi-current/state /target/"
        
        echo "State folder created successfully."
    fi
fi
