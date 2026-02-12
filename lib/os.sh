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

init_sudo() {
    # If running as root, we are good
    if [[ $EUID -eq 0 ]]; then
        return 0
    fi

    # Validate sudo access (this calls sudo, which asks for password if needed)
    # The user asked to "save as env var", but safe practice is to refresh the sudo timestamp.
    info "Sudo privileges are required. Please enter your password if prompted."
    
    if ! sudo -v; then
        error "Sudo verification failed. Exiting."
        exit 1
    fi

    # Keep-alive loop: updates sudo timestamp every 60 seconds
    # Runs in the background and kills itself when the parent script exits
    ( while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null & )

    success "Sudo privileges initialized."
}
