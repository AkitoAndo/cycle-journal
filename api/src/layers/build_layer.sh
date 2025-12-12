#!/bin/bash
# JWT Layer build script for Lambda
# Run this script to install dependencies for the Lambda Layer

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAYER_DIR="$SCRIPT_DIR/jwt/python"

echo "Building JWT Lambda Layer..."

# Clean and recreate the directory
rm -rf "$LAYER_DIR"
mkdir -p "$LAYER_DIR"

# Install packages for Lambda (Linux x86_64)
pip install \
    --platform manylinux2014_x86_64 \
    --target "$LAYER_DIR" \
    --implementation cp \
    --python-version 3.12 \
    --only-binary=:all: \
    --upgrade \
    -r "$SCRIPT_DIR/jwt/requirements.txt"

echo "Layer built successfully at: $LAYER_DIR"
echo "Contents:"
ls -la "$LAYER_DIR"
