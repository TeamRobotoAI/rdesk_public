#!/usr/bin/env bash
# R-Desk Client - One-Click Linux Installer
# This script installs the correct .deb package and configures permissions.
# Developed by RobotoAI Technologies Pvt. Ltd.

set -euo pipefail

echo "🚀 Starting R-Desk Client Unified Installation..."
echo "--------------------------------------------------------"

# 1. Determine Architecture & Download URLs
ARCH=$(uname -m)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEB_NAME=""
DOWNLOAD_URL=""

if [[ "$ARCH" == "x86_64" ]]; then
    echo "💻 Detected Architecture: x86_64 (AMD64)"
    DEB_NAME="r_desk_1.0.0_compatible_amd64.deb"
    DOWNLOAD_URL="https://github.com/TeamRobotoAI/rdesk_public/releases/download/v1.0.0/r_desk_1.0.0_compatible_amd64.deb"
elif [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
    echo "📱 Detected Architecture: ARM64"
    DEB_NAME="r_desk_1.0.0_arm64.deb"
    DOWNLOAD_URL="https://github.com/TeamRobotoAI/rdesk_public/releases/download/v1.0.0/r_desk_1.0.0_arm64.deb"
else
    echo "❌ Unsupported architecture: $ARCH"
    exit 1
fi

DEB_FILE="$SCRIPT_DIR/$DEB_NAME"

# 2. Check if the .deb file exists, download if missing
if [[ ! -f "$DEB_FILE" ]]; then
    echo "🌐 Local package not found. Downloading $DEB_NAME..."
    if ! curl -L "$DOWNLOAD_URL" -o "$DEB_FILE"; then
        echo "❌ Error: Failed to download package from $DOWNLOAD_URL"
        exit 1
    fi
fi

# 3. Install the .deb package
echo "📦 Installing R-Desk Package using dpkg..."
sudo dpkg -i "$DEB_FILE"
sudo apt-get install -f -y # To fix any missing dependencies automatically

# 4. Run the setup script for permissions
SETUP_SCRIPT="$SCRIPT_DIR/setup.sh"
if [[ -f "$SETUP_SCRIPT" ]]; then
    echo ""
    echo "🔧 Initiating permission setup script for remote control..."
    
    # Ensure setup.sh is executable before running
    chmod +x "$SETUP_SCRIPT"
    
    # Execute the setup script as normal user (it will call sudo where necessary)
    "$SETUP_SCRIPT"
else
    echo "⚠️ Warning: setup.sh not found at $SETUP_SCRIPT. Skipping permission setup."
fi

echo "--------------------------------------------------------"
echo "✅ Installation Complete!"
echo "R-Desk has been successfully installed on your system."
echo "You can launch R-Desk from your application menu or by typing 'r_desk' in the terminal."
