#!/bin/bash

# ==============================================================================
# HyperInit - Bootstrap Loader
# Supports minimal LXC/Debian containers (root, no sudo, optional git).
# ==============================================================================

REPO_URL="https://github.com/chujiaqi900102/hyper-init.git"
REPO_TARBALL="https://github.com/chujiaqi900102/hyper-init/archive/refs/heads/main.tar.gz"
INSTALL_DIR="$HOME/.hyper-init"

# #region agent log
_debug_log() {
    local hypothesis_id="$1" location="$2" message="$3" data_json="$4"
    local ts log_path
    ts=$(date +%s%3N 2>/dev/null || date +%s000)
    for log_path in \
        "/home/chujiaqi/codex/hyper-init/.cursor/debug-5b3cc3.log" \
        "/tmp/hyper-init-debug-5b3cc3.log"; do
        printf '{"sessionId":"5b3cc3","hypothesisId":"%s","location":"%s","message":"%s","data":%s,"timestamp":%s}\n' \
            "$hypothesis_id" "$location" "$message" "$data_json" "$ts" >> "$log_path" 2>/dev/null || true
    done
}
# #endregion

run_privileged() {
    if [[ $EUID -eq 0 ]]; then
        "$@"
    elif command -v sudo &>/dev/null; then
        sudo "$@"
    else
        echo "Error: need root privileges or sudo to run: $*" >&2
        return 127
    fi
}

is_debian_family() {
    if [ -f /etc/debian_version ]; then
        return 0
    fi
    if [ -f /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        case "${ID:-}${ID_LIKE:-}" in
            *debian*|*ubuntu*) return 0 ;;
        esac
    fi
    return 1
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

apt_install() {
    local pkg
    prepare_apt_noninteractive
    if ! run_privileged apt-get update -qq; then
        echo "Error: apt-get update failed. Check /etc/apt/sources (Debian 13 uses deb822 .sources files)." >&2
        # #region agent log
        _debug_log "F" "bootstrap.sh:apt_install" "apt-get update failed" "{}"
        # #endregion
        return 1
    fi
    for pkg in "$@"; do
        if ! run_privileged apt-get install -y \
            -o Dpkg::Options::=--force-confdef \
            -o Dpkg::Options::=--force-confold \
            "$pkg"; then
            echo "Error: apt-get install failed for: $pkg" >&2
            return 1
        fi
    done
    return 0
}

install_dep() {
    local dep="$1"
    local in_container="false"
    is_container_env && in_container="true"

    # #region agent log
    _debug_log "B" "bootstrap.sh:install_dep" "install_dep entry" \
        "{\"dep\":\"$dep\",\"euid\":$EUID,\"has_sudo\":$(command -v sudo &>/dev/null && echo true || echo false),\"container\":$in_container,\"debian\":$(is_debian_family && echo true || echo false)}"
    # #endregion

    if command -v "$dep" &>/dev/null; then
        return 0
    fi

    echo "$dep not found. Installing..."

    if is_debian_family; then
        local pkgs=("$dep")
        # HTTPS git clone and curl need CA store in minimal LXC templates
        if [[ "$dep" == "git" || "$dep" == "curl" ]]; then
            pkgs=(ca-certificates "${pkgs[@]}")
        fi
        apt_install "${pkgs[@]}" || return 1
    elif [ -f /etc/redhat-release ] || { [ -f /etc/os-release ] && . /etc/os-release && [[ "$ID" == "rhel" || "$ID" == "fedora" || "$ID" == "centos" || "$ID" == "rocky" || "$ID" == "almalinux" ]]; }; then
        run_privileged dnf install -y "$dep" || return 1
    elif [ -f /etc/arch-release ] || { [ -f /etc/os-release ] && . /etc/os-release && [[ "$ID" == "arch" ]]; }; then
        run_privileged pacman -S --noconfirm "$dep" || return 1
    else
        echo "Error: unsupported OS; install $dep manually and re-run." >&2
        # #region agent log
        _debug_log "C" "bootstrap.sh:install_dep" "unsupported OS" "{\"dep\":\"$dep\"}"
        # #endregion
        return 1
    fi

    if ! command -v "$dep" &>/dev/null; then
        echo "Error: failed to install $dep." >&2
        # #region agent log
        _debug_log "D" "bootstrap.sh:install_dep" "dep still missing after install" "{\"dep\":\"$dep\"}"
        # #endregion
        return 1
    fi

    # #region agent log
    _debug_log "D" "bootstrap.sh:install_dep" "dep available" "{\"dep\":\"$dep\"}"
    # #endregion
    return 0
}

fetch_repo() {
    if [ -d "$INSTALL_DIR/.git" ] && command -v git &>/dev/null; then
        echo "Updating existing installation..."
        git -C "$INSTALL_DIR" pull
        return $?
    fi

    if [ -d "$INSTALL_DIR" ]; then
        echo "Using existing installation at $INSTALL_DIR"
        return 0
    fi

    if command -v git &>/dev/null; then
        echo "Cloning HyperInit..."
        git clone --depth 1 "$REPO_URL" "$INSTALL_DIR"
        return $?
    fi

    if ! command -v curl &>/dev/null; then
        echo "Error: neither git nor curl available to download HyperInit." >&2
        return 1
    fi

    echo "Fetching HyperInit via curl (git unavailable)..."
    local tmpdir parent extracted
    tmpdir=$(mktemp -d)
    parent=$(dirname "$INSTALL_DIR")
    mkdir -p "$parent"
    if ! curl -fsSL "$REPO_TARBALL" -o "$tmpdir/hyper-init.tar.gz"; then
        rm -rf "$tmpdir"
        return 1
    fi
    tar -xzf "$tmpdir/hyper-init.tar.gz" -C "$tmpdir"
    extracted="$tmpdir/hyper-init-main"
    if [ ! -d "$extracted" ]; then
        echo "Error: unexpected archive layout from GitHub tarball." >&2
        rm -rf "$tmpdir"
        return 1
    fi
    mv "$extracted" "$INSTALL_DIR"
    rm -rf "$tmpdir"
    # #region agent log
    _debug_log "G" "bootstrap.sh:fetch_repo" "fetched via tarball" "{\"install_dir\":\"$INSTALL_DIR\"}"
    # #endregion
    return 0
}

echo "Initializing HyperInit..."

# #region agent log
_debug_log "A" "bootstrap.sh:main" "bootstrap start" \
    "{\"euid\":$EUID,\"has_sudo\":$(command -v sudo &>/dev/null && echo true || echo false),\"install_dir\":\"$INSTALL_DIR\",\"container\":$(is_container_env && echo true || echo false)}"
# #endregion

if is_container_env; then
    echo "Container environment detected (LXC/LXD/Docker)."
fi

# curl first (one-liner already needs it; ensure CA store on Debian)
if ! install_dep curl; then
    exit 1
fi

# git optional — tarball fallback if install fails
if ! install_dep git; then
    warn_git=1
    echo "Warning: git could not be installed; will try curl tarball fallback."
    # #region agent log
    _debug_log "G" "bootstrap.sh:main" "git install skipped" "{}"
    # #endregion
else
    warn_git=0
fi

if ! fetch_repo; then
    echo "Error: could not download HyperInit to $INSTALL_DIR" >&2
    # #region agent log
    _debug_log "E" "bootstrap.sh:main" "fetch_repo failed" "{\"warn_git\":$warn_git}"
    # #endregion
    exit 1
fi

if [ ! -f "$INSTALL_DIR/main.sh" ]; then
    echo "Error: $INSTALL_DIR/main.sh not found after download." >&2
    # #region agent log
    _debug_log "E" "bootstrap.sh:main" "main.sh missing" "{\"install_dir\":\"$INSTALL_DIR\"}"
    # #endregion
    exit 1
fi

cd "$INSTALL_DIR" || exit 1
# #region agent log
_debug_log "E" "bootstrap.sh:main" "starting main.sh" "{\"pwd\":\"$(pwd)\"}"
# #endregion
bash main.sh
