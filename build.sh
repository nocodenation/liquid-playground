#!/bin/bash

# Parse arguments
# - --system-dependencies accepts a comma-separated list of apt packages
# - --post-installation-commands accepts a comma-separated list of shell commands
SYSTEM_DEPENDENCIES=""
POST_INSTALLATION_COMMANDS=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --system-dependencies=*)
      SYSTEM_DEPENDENCIES="${1#*=}"
      shift
      ;;
    --system-dependencies)
      shift
      SYSTEM_DEPENDENCIES="${1:-}"
      shift || true
      ;;
    --post-installation-commands=*)
      POST_INSTALLATION_COMMANDS="${1#*=}"
      shift
      ;;
    --post-installation-commands)
      shift
      POST_INSTALLATION_COMMANDS="${1:-}"
      shift || true
      ;;
    *)
      echo "Unknown option or positional argument not supported: $1" >&2
      echo "Usage: $0 [--system-dependencies \"pkg1, pkg2\"] [--post-installation-commands \"cmd1, cmd2\"]" >&2
      exit 1
      ;;
  esac
done

# Build the final list of additional packages from --system-dependencies
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
