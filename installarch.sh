#!/bin/bash

set -e

FILENAME="installarche"
DOWNLOAD_URL="https://github.com/Yew12347/installarch/releases/download/alpha03/installarch"

# Download the binary
echo "Downloading installarch..."
curl -L -o "$FILENAME" "$DOWNLOAD_URL"

# Make it executable
chmod +x "$FILENAME"

# Run it
echo "Running installarch..."
./"$FILENAME"
