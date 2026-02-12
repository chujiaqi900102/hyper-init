#!/bin/bash

# ==============================================================================
# HyperInit - Bootstrap Loader
# ==============================================================================

REPO_URL="https://github.com/chujiaqi900102/hyper-init.git"
INSTALL_DIR="$HOME/.hyper-init"

echo "Initializing HyperInit..."

# Ensure git and curl are installed
deps=(git curl)
for dep in "${deps[@]}"; do
    if ! command -v "$dep" &> /dev/null; then
        echo "$dep not found. Installing..."
        if [ -f /etc/debian_version ]; then
            sudo apt update && sudo apt install -y "$dep"
        elif [ -f /etc/redhat-release ]; then
            sudo dnf install -y "$dep"
        elif [ -f /etc/arch-release ]; then
            sudo pacman -S --noconfirm "$dep"
        fi
    fi
done

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
