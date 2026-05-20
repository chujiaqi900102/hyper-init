#!/bin/bash

# ==============================================================================
# HyperInit - OS Abstraction Layer
# ==============================================================================

# Global Variables
OS_TYPE=""
OS_VERSION=""
PKG_MANAGER=""

# Run as root directly, or via sudo when available (LXC/minimal images often have no sudo).
run_privileged() {
    if [[ $EUID -eq 0 ]]; then
        "$@"
    elif command -v sudo &>/dev/null; then
        sudo "$@"
    else
        error "Need root or sudo to run: $*"
        return 127
    fi
}

is_container_env() {
    if command -v systemd-detect-virt &>/dev/null; then
        local virt
        virt=$(systemd-detect-virt --container 2>/dev/null || true)
        [[ -n "$virt" && "$virt" != "none" ]]
        return
    fi
    grep -qE '^(container|lxc)=' /proc/1/environ 2>/dev/null || \
        [[ -d /dev/.lxc ]] || \
        [[ -f /run/systemd/container ]]
}

prepare_apt_noninteractive() {
    export DEBIAN_FRONTEND=noninteractive
    export DEBIAN_PRIORITY=critical
    export NEEDRESTART_MODE=a
    if [[ $EUID -eq 0 ]] && [[ -d /etc/needrestart/conf.d ]]; then
        printf '%s\n' '$nrconf{restart} = "a";' > /etc/needrestart/conf.d/99-hyper-init.conf 2>/dev/null || true
    fi
}

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
            prepare_apt_noninteractive
            run_task "Installing $pkg_name" run_privileged apt-get install -y \
                -o Dpkg::Options::=--force-confdef \
                -o Dpkg::Options::=--force-confold \
                "$pkg_name"
            ;;
        dnf)
            rpm -q "$pkg_name" &> /dev/null
            if [ $? -eq 0 ]; then
                info "$pkg_name is already installed."
                return 0
            fi
            run_task "Installing $pkg_name" run_privileged dnf install -y "$pkg_name"
            ;;
        pacman)
            pacman -Qi "$pkg_name" &> /dev/null
            if [ $? -eq 0 ]; then
                info "$pkg_name is already installed."
                return 0
            fi
            run_task "Installing $pkg_name" run_privileged pacman -S --noconfirm "$pkg_name"
            ;;
        *)
            error "Package manager not supported for installing $pkg_name"
            return 1
            ;;
    esac
}

init_sudo() {
    # Root (common in LXC): no sudo required
    if [[ $EUID -eq 0 ]]; then
        if is_container_env; then
            info "Running inside a container as root (sudo not required)."
        fi
        return 0
    fi

    if ! command -v sudo &>/dev/null; then
        error "Not running as root and sudo is not installed."
        error "In LXC: use 'lxc exec <name> -- bash' or 'pct exec <vmid> -- bash' as root, or install sudo."
        exit 1
    fi

    info "Sudo privileges are required. Please enter your password if prompted."
    
    if ! sudo -v; then
        error "Sudo verification failed. Exiting."
        exit 1
    fi

    ( while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null & )

    success "Sudo privileges initialized."
}
