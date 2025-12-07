#!/bin/bash

# Update package list and install build dependencies to prevent compilation hangs
echo "Installing build dependencies..."
apt-get update && apt-get install -y build-essential python3-dev

# Set environment variable to allow installing packages system-wide (PEP 668)
export PIP_BREAK_SYSTEM_PACKAGES=1
export PIP_DEFAULT_TIMEOUT=3000
export PIP_NO_CACHE_DIR=1

# Install spaCy language model for Microsoft Presidio
echo "Installing spaCy..."
pip3 install spacy --prefer-binary

echo "Installing spaCy model en_core_web_lg..."

# Check if we copied a local wheel file
if compgen -G "/tmp/en_core_web_lg*.whl" > /dev/null; then
    echo "Found local model wheel, installing..."
    pip3 install /tmp/en_core_web_lg*.whl
else
    echo "Downloading spaCy model en_core_web_lg (this may take a while)..."
    # Use direct URL to control timeout and avoid potential spacy download wrapper issues
    pip3 install https://github.com/explosion/spacy-models/releases/download/en_core_web_lg-3.8.0/en_core_web_lg-3.8.0-py3-none-any.whl
fi
