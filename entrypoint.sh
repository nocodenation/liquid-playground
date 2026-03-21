#!/bin/bash
# Entrypoint script for liquid-playground
# Handles automatic NAR deployment before starting NiFi

set -e

echo "🚀 Liquid Playground - Starting..."

# Check if nar_extensions directory exists and has NAR files
if [ -d "/opt/nifi/nifi-current/nar_extensions" ]; then
    NAR_COUNT=$(find /opt/nifi/nifi-current/nar_extensions -maxdepth 1 -name "*.nar" 2>/dev/null | wc -l)

    if [ "$NAR_COUNT" -gt 0 ]; then
        echo "📦 Found $NAR_COUNT NAR file(s) in nar_extensions directory"
        echo "📋 Copying NARs to lib directory..."

        # Copy all NAR files from nar_extensions to lib
        cp -v /opt/nifi/nifi-current/nar_extensions/*.nar /opt/nifi/nifi-current/lib/ 2>/dev/null || true

        echo "✅ NAR deployment complete"
    else
        echo "ℹ️  No NAR files found in nar_extensions directory"
    fi
else
    echo "ℹ️  nar_extensions directory not mounted"
fi

# Start opencode web if enabled
if [ "${OPENCODE_ENABLE:-false}" = "true" ]; then
    echo "🤖 OpenCode enabled - starting opencode web..."

    mkdir -p "/home/nifi/.config/opencode"

    OPENCODE_PORT="${OPENCODE_SERVER_PORT:-4096}"
    OPENCODE_OLLAMA_URL="${OPENCODE_OLLAMA_HOST:-http://ollama:11434}"

    # Parse model: if it contains '/', use as-is (provider/model); otherwise assume ollama
    _MODEL_RAW="${OPENCODE_MODEL:-llama3.1:8b}"
    case "$_MODEL_RAW" in
        */*)
            OPENCODE_FULL_MODEL="$_MODEL_RAW"
            OPENCODE_OLLAMA_MODEL="${_MODEL_RAW#ollama/}"
            ;;
        *)
            OPENCODE_FULL_MODEL="ollama/$_MODEL_RAW"
            OPENCODE_OLLAMA_MODEL="$_MODEL_RAW"
            ;;
    esac

    # Build providers JSON block — ollama is always included
    _PROVIDERS="    \"llamacpp\": {
      \"npm\": \"@ai-sdk/openai-compatible\",
      \"name\": \"llamacpp\",
      \"options\": {
        \"baseURL\": \"${OPENCODE_OLLAMA_URL}/v1\"
      },
      \"models\": {
        \"${OPENCODE_OLLAMA_MODEL}\": {
          \"name\": \"llamacpp: ${OPENCODE_OLLAMA_MODEL}\",
          \"modalities\": {
            \"input\": [\"text\", \"image\"],
            \"output\": [\"text\"]
          }
        }
      }
    }"

    if [ -n "${OPENCODE_ANTHROPIC_KEY}" ]; then
        _PROVIDERS="${_PROVIDERS},
    \"anthropic\": {
      \"options\": {
        \"apiKey\": \"${OPENCODE_ANTHROPIC_KEY}\"
      }
    }"
    fi

    if [ -n "${OPENCODE_OPENAI_KEY}" ]; then
        _PROVIDERS="${_PROVIDERS},
    \"openai\": {
      \"options\": {
        \"apiKey\": \"${OPENCODE_OPENAI_KEY}\"
      }
    }"
    fi

    # Write opencode config into the working directory so opencode uses it as the project root
    printf '{
  "model": "%s",
  "provider": {
%s
  },
  "server": {
    "port": %s,
    "hostname": "0.0.0.0",
    "mdns": false,
    "cors": ["https://localhost:8443"]
  }
}\n' "$OPENCODE_FULL_MODEL" "$_PROVIDERS" "$OPENCODE_PORT" > "/home/nifi/.config/opencode/opencode.json"

    if [ -n "${OPENCODE_PASSWORD}" ]; then
      export OPENCODE_SERVER_PASSWORD="${OPENCODE_PASSWORD}"
    fi
    if [ -n "${OPENCODE_USERNAME}" ]; then
      export OPENCODE_SERVER_USERNAME="${OPENCODE_USERNAME}"
    fi
    opencode web &
    echo "✅ opencode web started on port $OPENCODE_PORT"
fi

# Execute the original NiFi start script
echo "🔧 Starting NiFi..."
exec /opt/nifi/scripts/start.sh "$@"

#/opt/nifi/scripts/start.sh & start_sh_pid="$!"
#wait ${start_sh_pid}