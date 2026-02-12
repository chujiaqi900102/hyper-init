#!/bin/bash

# ==============================================================================
# HyperInit - Bootstrap Loader
# ==============================================================================

REPO_URL="https://github.com/your-repo/hyper-init.git" # Placeholder
INSTALL_DIR="$HOME/.hyper-init"

echo "Initializing HyperInit..."

# Ensure git is installed
if ! command -v git &> /dev/null; then
    echo "Git not found. Installing..."
    if [ -f /etc/debian_version ]; then
        sudo apt update && sudo apt install -y git
    elif [ -f /etc/redhat-release ]; then
        sudo dnf install -y git
    elif [ -f /etc/arch-release ]; then
        sudo pacman -S --noconfirm git
    fi
fi

# Clone Repo
if [ -d "$INSTALL_DIR" ]; then
    echo "Updating existing installation..."
    cd "$INSTALL_DIR" && git pull
else
    echo "Cloning HyperInit..."
    git clone --depth 1 "$REPO_URL" "$INSTALL_DIR"
fi

# Run
cd "$INSTALL_DIR"
bash main.sh
