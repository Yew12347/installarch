#!/bin/bash

set -e

# Define variables
URL="https://github.com/Yew12347/installarch/releases/download/alpha02/installarch"
FILENAME="installarch"

# Download the binary
echo "Downloading installarch..."
curl -L -o "$FILENAME" "$URL"

# Make it executable
chmod +x "$FILENAME"

# Run it
echo "Running installarch..."
./"$FILENAME"
