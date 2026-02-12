#!/bin/bash

# ==============================================================================
# HyperInit - OS Abstraction Layer
# ==============================================================================

# Global Variables
OS_TYPE=""
OS_VERSION=""
PKG_MANAGER=""

detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_TYPE=$ID
        OS_VERSION=$VERSION_ID
    else
        critical "Cannot detect OS type. /etc/os-release missing."
    fi

    case "$OS_TYPE" in
        ubuntu|debian|kali|pop)
            PKG_MANAGER="apt"
            ;;
        centos|rhel|fedora|almalinux|rocky)
            PKG_MANAGER="dnf"
            ;;
        arch|manjaro)
            PKG_MANAGER="pacman"
            ;;
        *)
            PKG_MANAGER="unknown"
            warn "Unsupported OS detected: $OS_TYPE. Some functions may fail."
            ;;
    esac
}

install_pkg() {
    local pkg_name=$1
    
    case "$PKG_MANAGER" in
        apt)
            # Check if installed
            dpkg -s "$pkg_name" &> /dev/null
            if [ $? -eq 0 ]; then
                info "$pkg_name is already installed."
                return 0
            fi
            run_task "Installing $pkg_name" sudo apt-get install -y "$pkg_name"
            ;;
        dnf)
            rpm -q "$pkg_name" &> /dev/null
            if [ $? -eq 0 ]; then
                info "$pkg_name is already installed."
                return 0
            fi
            run_task "Installing $pkg_name" sudo dnf install -y "$pkg_name"
            ;;
        pacman)
            pacman -Qi "$pkg_name" &> /dev/null
            if [ $? -eq 0 ]; then
                info "$pkg_name is already installed."
                return 0
            fi
            run_task "Installing $pkg_name" sudo pacman -S --noconfirm "$pkg_name"
            ;;
        *)
            error "Package manager not supported for installing $pkg_name"
            return 1
            ;;
    esac
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
       warn "This script might need root privileges for some tasks."
       # We don't exit because we use sudo in commands
    fi
}
