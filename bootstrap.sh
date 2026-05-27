#!/bin/bash

# ==============================================================================
# HyperInit - Bootstrap Loader
# Supports minimal LXC/Debian containers (root, no sudo, optional git).
# ==============================================================================

REPO_URL="${HYPER_INIT_REPO_URL:-https://github.com/chujiaqi900102/hyper-init.git}"
REPO_TARBALL="${HYPER_INIT_REPO_TARBALL:-https://github.com/chujiaqi900102/hyper-init/archive/refs/heads/main.tar.gz}"
REPO_BRANCH="${HYPER_INIT_REPO_BRANCH:-main}"
INSTALL_DIR="$HOME/.hyper-init"
BOOTSTRAP_MODE="prod"   # prod = GitHub git clone; test = LAN tarball
PREFER_TARBALL=0

bootstrap_usage() {
    cat <<'EOF'
HyperInit bootstrap

Usage:
  bash bootstrap.sh              Production: clone/update from GitHub (default)
  bash bootstrap.sh -t URL       Test/LAN: fetch repo tarball from local HTTP server
  bash bootstrap.sh --test URL

Examples:
  bash bootstrap.sh
  bash bootstrap.sh -t http://192.168.122.195:8888
  bash bootstrap.sh -t 192.168.122.195:8888
  wget -qO- http://LAN:8888/bootstrap.sh | bash -s -- -t http://LAN:8888

Environment (optional overrides):
  HYPER_INIT_SERVE_BASE, HYPER_INIT_REPO_TARBALL, HYPER_INIT_REPO_URL,
  HYPER_INIT_MIRROR_URL, HYPER_INIT_REPO_BRANCH, HYPER_INIT_GIT_HTTP_VERSION
EOF
}

normalize_serve_base() {
    local base="$1"
    case "$base" in
        http://*|https://*) printf '%s' "${base%/}" ;;
        *) printf 'http://%s' "${base%/}" ;;
    esac
}

parse_bootstrap_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -t|--test)
                BOOTSTRAP_MODE="test"
                if [[ -n "${2:-}" && "$2" != -* ]]; then
                    HYPER_INIT_SERVE_BASE="$(normalize_serve_base "$2")"
                    shift
                fi
                ;;
            -h|--help)
                bootstrap_usage
                exit 0
                ;;
            *)
                echo "Error: unknown option: $1 (try --help)" >&2
                exit 1
                ;;
        esac
        shift
    done
}

apply_repo_fetch_mode() {
    # Env-based LAN overrides (work with or without -t).
    if [[ -n "${HYPER_INIT_SERVE_BASE:-}" && -z "${HYPER_INIT_REPO_TARBALL:-}" ]]; then
        REPO_TARBALL="$(normalize_serve_base "$HYPER_INIT_SERVE_BASE")/hyper-init-main.tar.gz"
    fi
    if [[ -n "${HYPER_INIT_REPO_TARBALL:-}" ]]; then
        PREFER_TARBALL=1
    elif [[ -n "${HYPER_INIT_SERVE_BASE:-}" ]]; then
        PREFER_TARBALL=1
    elif [[ "$BOOTSTRAP_MODE" == "test" ]]; then
        PREFER_TARBALL=1
        if [[ -z "${HYPER_INIT_REPO_TARBALL:-}" && -z "${HYPER_INIT_SERVE_BASE:-}" ]]; then
            echo "Error: test mode (-t) requires a serve base URL." >&2
            echo "  Example: bash bootstrap.sh -t http://192.168.122.195:8888" >&2
            echo "  Or:     export HYPER_INIT_SERVE_BASE=http://LAN_HOST:8888" >&2
            exit 1
        fi
    fi
}

parse_bootstrap_args "$@"
apply_repo_fetch_mode

_debug_log() {
    [[ -n "${HYPER_INIT_DEBUG_LOG:-}" ]] || return 0
    local hypothesis_id="$1" location="$2" message="$3" data_json="$4"
    local ts
    ts=$(date +%s%3N 2>/dev/null || date +%s000)
    { printf '{"hypothesisId":"%s","location":"%s","message":"%s","data":%s,"timestamp":%s}\n' \
        "$hypothesis_id" "$location" "$message" "$data_json" "$ts"; } >> "$HYPER_INIT_DEBUG_LOG" 2>/dev/null || true
}

# Prefer HTTP/1.1 for GitHub fetches (avoids "Error in the HTTP2 framing layer" on some networks).
GIT_FETCH_HTTP_VERSION="${HYPER_INIT_GIT_HTTP_VERSION:-HTTP/1.1}"

# Non-interactive mirror for bootstrap apt (override with HYPER_INIT_MIRROR_URL).
BOOTSTRAP_MIRROR_URL="${HYPER_INIT_MIRROR_URL:-https://mirrors.tuna.tsinghua.edu.cn}"

# Helpers below mirror lib/os.sh; bootstrap runs before the repo is cloned.
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

# Switch APT mirrors before apt-get update/install (Debian 13 deb822 .sources, LXC wget-only).
bootstrap_configure_apt_mirror() {
    local distro="" codename="" mirror_url deb_uri sec_uri ubuntu_uri ts

    if ! is_debian_family; then
        return 0
    fi
    if [ -f /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        distro="${ID:-}"
        codename="${VERSION_CODENAME:-}"
    fi
    if [ -z "$codename" ]; then
        echo "Warning: could not detect suite codename; skipping APT mirror configuration." >&2
        return 0
    fi

    mirror_url="$BOOTSTRAP_MIRROR_URL"
    deb_uri="${mirror_url}/debian"
    sec_uri="${mirror_url}/debian-security"
    echo "Configuring APT mirror ($mirror_url) before package install..."

    ts=$(date +%Y%m%d_%H%M%S 2>/dev/null || echo backup)
    if [ -f /etc/apt/sources.list ]; then
        run_privileged cp /etc/apt/sources.list "/etc/apt/sources.list.bak.${ts}" 2>/dev/null || true
    fi
    if [ -f /etc/apt/sources.list.d/debian.sources ]; then
        run_privileged cp /etc/apt/sources.list.d/debian.sources \
            "/etc/apt/sources.list.d/debian.sources.bak.${ts}" 2>/dev/null || true
    fi
    if [ -f /etc/apt/sources.list.d/ubuntu.sources ]; then
        run_privileged cp /etc/apt/sources.list.d/ubuntu.sources \
            "/etc/apt/sources.list.d/ubuntu.sources.bak.${ts}" 2>/dev/null || true
    fi

    case "$distro" in
        debian)
            if [ -f /etc/apt/sources.list.d/debian.sources ]; then
                run_privileged sed -i \
                    -e "s|https\\?://deb\\.debian\\.org/debian-security|${sec_uri}|g" \
                    -e "s|https\\?://security\\.debian\\.org/debian-security|${sec_uri}|g" \
                    -e "s|https\\?://deb\\.debian\\.org/debian|${deb_uri}|g" \
                    /etc/apt/sources.list.d/debian.sources
                if [ -f /etc/apt/sources.list ]; then
                    run_privileged sed -i \
                        -e "s|https\\?://deb\\.debian\\.org/debian-security|${sec_uri}|g" \
                        -e "s|https\\?://security\\.debian\\.org/debian-security|${sec_uri}|g" \
                        -e "s|https\\?://deb\\.debian\\.org/debian|${deb_uri}|g" \
                        /etc/apt/sources.list
                fi
            else
                run_privileged tee /etc/apt/sources.list > /dev/null <<EOF
# Generated by HyperInit bootstrap
deb ${deb_uri}/ ${codename} main contrib non-free non-free-firmware
deb ${deb_uri}/ ${codename}-updates main contrib non-free non-free-firmware
deb ${deb_uri}/ ${codename}-backports main contrib non-free non-free-firmware
deb ${sec_uri} ${codename}-security main contrib non-free non-free-firmware
EOF
            fi
            ;;
        ubuntu)
            ubuntu_uri="${mirror_url}/ubuntu"
            if [ -f /etc/apt/sources.list.d/ubuntu.sources ]; then
                if command -v perl &>/dev/null; then
                    run_privileged env UBUNTU_APT_URI="$ubuntu_uri" \
                        perl -i -pe 's/^URIs:\s*.*/URIs: $ENV{UBUNTU_APT_URI}/' \
                        /etc/apt/sources.list.d/ubuntu.sources
                else
                    run_privileged sed -i "s#^URIs:.*#URIs: ${ubuntu_uri}#" \
                        /etc/apt/sources.list.d/ubuntu.sources
                fi
            else
                run_privileged tee /etc/apt/sources.list > /dev/null <<EOF
# Generated by HyperInit bootstrap
deb ${ubuntu_uri}/ ${codename} main restricted universe multiverse
deb ${ubuntu_uri}/ ${codename}-updates main restricted universe multiverse
deb ${ubuntu_uri}/ ${codename}-backports main restricted universe multiverse
deb ${ubuntu_uri}/ ${codename}-security main restricted universe multiverse
EOF
            fi
            ;;
        *)
            echo "Warning: unknown distro '$distro'; attempting generic mirror rewrite on .sources files." >&2
            local f
            for f in /etc/apt/sources.list.d/*.sources; do
                [ -f "$f" ] || continue
                run_privileged sed -i \
                    -e "s|https\\?://deb\\.debian\\.org/debian-security|${sec_uri}|g" \
                    -e "s|https\\?://security\\.debian\\.org/debian-security|${sec_uri}|g" \
                    -e "s|https\\?://deb\\.debian\\.org/debian|${deb_uri}|g" \
                    "$f"
            done
            ;;
    esac
    return 0
}

apt_install() {
    if [[ $# -eq 0 ]]; then
        return 0
    fi
    prepare_apt_noninteractive
    if ! run_privileged apt-get update -qq; then
        echo "Error: apt-get update failed. Check /etc/apt/sources (Debian 13 uses deb822 .sources files)." >&2
        # #region agent log
        _debug_log "F" "bootstrap.sh:apt_install" "apt-get update failed" "{}"
        # #endregion
        return 1
    fi
    if ! run_privileged apt-get install -y \
        -o Dpkg::Options::=--force-confdef \
        -o Dpkg::Options::=--force-confold \
        "$@"; then
        echo "Error: apt-get install failed for: $*" >&2
        return 1
    fi
    return 0
}

debian_pkg_installed() {
    dpkg -s "$1" &>/dev/null
}

bootstrap_can_privilege() {
    [[ $EUID -eq 0 ]] || command -v sudo &>/dev/null
}

# Install all bootstrap prerequisites before fetch_repo / main.sh.
# Required: bash, curl, tar, ca-certificates (Debian). Optional: git (tarball fallback).
# sudo is installed only for non-root users; root/LXC does not need it.
ensure_bootstrap_deps() {
    local -a deb_pkgs=()
    local cmd in_container="false"
    local need_required_install=0
    local git_was_missing=0

    is_container_env && in_container="true"

    # #region agent log
    _debug_log "H" "bootstrap.sh:ensure_bootstrap_deps" "entry" \
        "{\"euid\":$EUID,\"has_sudo\":$(command -v sudo &>/dev/null && echo true || echo false),\"container\":$in_container,\"debian\":$(is_debian_family && echo true || echo false)}"
    # #endregion

    if ! bootstrap_can_privilege; then
        echo "Error: not running as root and sudo is not installed." >&2
        echo "In LXC/Proxmox: exec into the container as root, e.g. lxc exec <name> -- bash" >&2
        return 1
    fi

    for cmd in bash curl tar; do
        if ! command -v "$cmd" &>/dev/null; then
            need_required_install=1
            break
        fi
    done

    if [[ $EUID -ne 0 ]] && ! command -v sudo &>/dev/null; then
        need_required_install=1
    fi

    if is_debian_family && ! debian_pkg_installed ca-certificates; then
        need_required_install=1
    fi

    command -v git &>/dev/null || git_was_missing=1

    if [[ $need_required_install -eq 0 && $git_was_missing -eq 0 ]]; then
        # #region agent log
        _debug_log "H" "bootstrap.sh:ensure_bootstrap_deps" "already satisfied" "{}"
        # #endregion
        return 0
    fi

    echo "Checking bootstrap dependencies..."

    if is_debian_family; then
        for cmd in bash curl tar; do
            if ! command -v "$cmd" &>/dev/null; then
                deb_pkgs+=("$cmd")
            fi
        done
        if [[ $EUID -ne 0 ]] && ! command -v sudo &>/dev/null; then
            deb_pkgs+=(sudo)
        fi
        if ! debian_pkg_installed ca-certificates; then
            deb_pkgs+=(ca-certificates)
        fi
        if [[ ${#deb_pkgs[@]} -gt 0 ]] || { [[ $git_was_missing -eq 1 ]] && ! command -v git &>/dev/null; }; then
            bootstrap_configure_apt_mirror
        fi
        if [[ ${#deb_pkgs[@]} -gt 0 ]]; then
            echo "Installing: ${deb_pkgs[*]}"
            apt_install "${deb_pkgs[@]}" || return 1
        fi
        for cmd in bash curl tar; do
            if ! command -v "$cmd" &>/dev/null; then
                echo "Error: required command missing after install: $cmd" >&2
                # #region agent log
                _debug_log "D" "bootstrap.sh:ensure_bootstrap_deps" "required still missing" "{\"cmd\":\"$cmd\"}"
                # #endregion
                return 1
            fi
        done
        if [[ $EUID -ne 0 ]] && ! command -v sudo &>/dev/null; then
            echo "Error: sudo is required for non-root installs but is still missing." >&2
            return 1
        fi
        if [[ $git_was_missing -eq 1 ]] && ! command -v git &>/dev/null; then
            echo "Installing git (optional, enables clone/update)..."
            apt_install git || {
                echo "Warning: git could not be installed; will try curl tarball fallback."
                # #region agent log
                _debug_log "G" "bootstrap.sh:ensure_bootstrap_deps" "git optional install failed" "{}"
                # #endregion
            }
        fi
        return 0
    fi

    if [ -f /etc/redhat-release ] || { [ -f /etc/os-release ] && . /etc/os-release && [[ "$ID" == "rhel" || "$ID" == "fedora" || "$ID" == "centos" || "$ID" == "rocky" || "$ID" == "almalinux" ]]; }; then
        local -a dnf_pkgs=()
        for cmd in bash curl tar; do
            command -v "$cmd" &>/dev/null || dnf_pkgs+=("$cmd")
        done
        [[ $EUID -ne 0 ]] && ! command -v sudo &>/dev/null && dnf_pkgs+=(sudo)
        if [[ ${#dnf_pkgs[@]} -gt 0 ]]; then
            echo "Installing: ${dnf_pkgs[*]}"
            run_privileged dnf install -y "${dnf_pkgs[@]}" || return 1
        fi
        command -v git &>/dev/null || run_privileged dnf install -y git || \
            echo "Warning: git could not be installed; will try curl tarball fallback."
        return 0
    fi

    if [ -f /etc/arch-release ] || { [ -f /etc/os-release ] && . /etc/os-release && [[ "$ID" == "arch" ]]; }; then
        local -a pac_pkgs=()
        for cmd in bash curl tar; do
            command -v "$cmd" &>/dev/null || pac_pkgs+=("$cmd")
        done
        [[ $EUID -ne 0 ]] && ! command -v sudo &>/dev/null && pac_pkgs+=(sudo)
        if [[ ${#pac_pkgs[@]} -gt 0 ]]; then
            echo "Installing: ${pac_pkgs[*]}"
            run_privileged pacman -S --noconfirm "${pac_pkgs[@]}" || return 1
        fi
        command -v git &>/dev/null || run_privileged pacman -S --noconfirm git || \
            echo "Warning: git could not be installed; will try curl tarball fallback."
        return 0
    fi

    echo "Error: unsupported OS for automatic bootstrap dependency install." >&2
    echo "Install manually: bash curl tar ca-certificates git (optional) sudo (if non-root)" >&2
    # #region agent log
    _debug_log "C" "bootstrap.sh:ensure_bootstrap_deps" "unsupported OS" "{}"
    # #endregion
    return 1
}

fetch_repo_tarball() {
    if ! command -v curl &>/dev/null; then
        echo "Error: curl is required to download HyperInit tarball." >&2
        return 1
    fi

    echo "Fetching HyperInit via curl from $REPO_TARBALL ..."
    local tmpdir parent extracted
    tmpdir=$(mktemp -d)
    parent=$(dirname "$INSTALL_DIR")
    mkdir -p "$parent"
    # #region agent log
    _debug_log "C" "bootstrap.sh:fetch_repo_tarball" "curl tarball start" "{\"url\":\"$REPO_TARBALL\"}"
    # #endregion
    if ! curl -fsSL --http1.1 --connect-timeout 15 --max-time 300 "$REPO_TARBALL" -o "$tmpdir/hyper-init.tar.gz"; then
        # #region agent log
        _debug_log "C" "bootstrap.sh:fetch_repo_tarball" "curl tarball failed" "{\"url\":\"$REPO_TARBALL\"}"
        # #endregion
        rm -rf "$tmpdir"
        return 1
    fi
    tar -xzf "$tmpdir/hyper-init.tar.gz" -C "$tmpdir"
    extracted=""
    if [ -d "$tmpdir/hyper-init-main" ]; then
        extracted="$tmpdir/hyper-init-main"
    elif [ -f "$tmpdir/main.sh" ]; then
        extracted="$tmpdir"
    else
        local d
        for d in "$tmpdir"/*/; do
            [ -d "$d" ] || continue
            if [ -f "${d}main.sh" ]; then
                if [ -n "$extracted" ]; then
                    extracted=""
                    break
                fi
                extracted="${d%/}"
            fi
        done
    fi
    if [ -z "$extracted" ] || [ ! -f "$extracted/main.sh" ]; then
        echo "Error: unexpected archive layout (expected main.sh at archive root or in one top-level directory)." >&2
        rm -rf "$tmpdir"
        return 1
    fi
    mv "$extracted" "$INSTALL_DIR"
    rm -rf "$tmpdir"
    # #region agent log
    _debug_log "G" "bootstrap.sh:fetch_repo_tarball" "fetched via tarball" "{\"install_dir\":\"$INSTALL_DIR\"}"
    # #endregion
    return 0
}

git_fetch_cmd() {
    env GIT_TERMINAL_PROMPT=0 git \
        -c "http.version=$GIT_FETCH_HTTP_VERSION" \
        -c http.lowSpeedLimit=1000 \
        -c http.lowSpeedTime=30 \
        "$@"
}

cleanup_failed_install_dir() {
    if [[ -d "$INSTALL_DIR" && ! -d "$INSTALL_DIR/.git" ]]; then
        rm -rf "$INSTALL_DIR"
        # #region agent log
        _debug_log "D" "bootstrap.sh:cleanup_failed_install_dir" "removed partial install dir" "{\"install_dir\":\"$INSTALL_DIR\"}"
        # #endregion
    fi
}

fetch_repo() {
    if [ -d "$INSTALL_DIR/.git" ] && command -v git &>/dev/null; then
        echo "Updating existing installation..."
        if git_fetch_cmd -C "$INSTALL_DIR" pull; then
            return 0
        fi
        echo "Warning: git pull failed; trying tarball fallback..." >&2
        # #region agent log
        _debug_log "A" "bootstrap.sh:fetch_repo" "git pull failed, tarball fallback" "{\"install_dir\":\"$INSTALL_DIR\"}"
        # #endregion
        rm -rf "$INSTALL_DIR"
        fetch_repo_tarball
        return $?
    fi

    if [ -d "$INSTALL_DIR" ]; then
        echo "Using existing installation at $INSTALL_DIR"
        return 0
    fi

    if [[ $PREFER_TARBALL -eq 1 ]]; then
        fetch_repo_tarball
        return $?
    fi

    if command -v git &>/dev/null; then
        echo "Cloning HyperInit from $REPO_URL (branch $REPO_BRANCH)..."
        if [[ "$REPO_URL" == *github.com* ]]; then
            echo "Tip: for LAN testing use: bash bootstrap.sh -t http://LAN_HOST:8888"
        fi
        # #region agent log
        _debug_log "A" "bootstrap.sh:fetch_repo" "git clone attempt" \
            "{\"repo_url\":\"$REPO_URL\",\"branch\":\"$REPO_BRANCH\",\"http_version\":\"$GIT_FETCH_HTTP_VERSION\"}"
        # #endregion
        if git_fetch_cmd clone --depth 1 -b "$REPO_BRANCH" "$REPO_URL" "$INSTALL_DIR"; then
            # #region agent log
            _debug_log "A" "bootstrap.sh:fetch_repo" "git clone ok" "{\"install_dir\":\"$INSTALL_DIR\"}"
            # #endregion
            return 0
        fi
        # #region agent log
        _debug_log "B" "bootstrap.sh:fetch_repo" "git clone failed" "{\"install_dir\":\"$INSTALL_DIR\"}"
        # #endregion
        cleanup_failed_install_dir
        echo "Warning: git clone failed; trying tarball fallback..." >&2
        fetch_repo_tarball
        return $?
    fi

    fetch_repo_tarball
}

echo "Initializing HyperInit..."
if [[ "$BOOTSTRAP_MODE" == "test" ]]; then
    echo "Mode: test (LAN tarball from $REPO_TARBALL)"
else
    echo "Mode: production (GitHub)"
fi

# #region agent log
_debug_log "A" "bootstrap.sh:main" "bootstrap start" \
    "{\"euid\":$EUID,\"mode\":\"$BOOTSTRAP_MODE\",\"prefer_tarball\":$PREFER_TARBALL,\"has_sudo\":$(command -v sudo &>/dev/null && echo true || echo false),\"install_dir\":\"$INSTALL_DIR\",\"container\":$(is_container_env && echo true || echo false)}"
# #endregion

if is_container_env; then
    echo "Container environment detected (LXC/LXD/Docker)."
fi

if ! ensure_bootstrap_deps; then
    exit 1
fi

command -v git &>/dev/null && warn_git=0 || warn_git=1

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
