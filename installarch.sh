#!/bin/bash

set -e

# Download the binary
echo "Downloading installarch..."
curl -L -o https://github.com/Yew12347/installarch/releases/download/alpha02/installarch

# Make it executable
chmod +x "$FILENAME"

# Run it
echo "Running installarch..."
./installarch
