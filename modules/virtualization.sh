#!/bin/bash

# ==============================================================================
# HyperInit - Virtualization (QEMU/KVM, VirtualBox)
# ==============================================================================
# Supports Debian/Ubuntu (apt), Fedora/RHEL (dnf), Arch (pacman).
# ==============================================================================

virtualization_menu() {
    show_menu "VIRTUALIZATION" \
        "1. Install QEMU/KVM + libvirt (native Linux virtualization)" \
        "2. Install virt-manager (GUI for libvirt)" \
        "3. Install VirtualBox" \
        "B. Back to Main Menu"

    case "$SELECTION" in
        *"QEMU/KVM"*)
            install_qemu_kvm
            ;;
        *"virt-manager"*)
            install_virt_manager
            ;;
        *"VirtualBox"*)
            install_virtualbox
            ;;
        *"Back"*)
            return
            ;;
    esac
    read -n 1 -s -r -p "Press any key to continue..."
    virtualization_menu
}

install_qemu_kvm() {
    info "Installing QEMU/KVM and libvirt..."

    case "$PKG_MANAGER" in
        apt)
            install_pkg "qemu-kvm" || return 1
            install_pkg "libvirt-daemon-system" || return 1
            install_pkg "libvirt-clients" || return 1
            install_pkg "bridge-utils" || true
            run_task "Adding user to libvirt group" sudo usermod -aG libvirt "$USER"
            ;;
        dnf)
            run_task "Installing virtualization group" sudo dnf install -y @virtualization
            run_task "Adding user to libvirt group" sudo usermod -aG libvirt "$USER"
            ;;
        pacman)
            install_pkg "qemu-full" || install_pkg "qemu" || return 1
            install_pkg "libvirt" || return 1
            run_task "Adding user to libvirt group" sudo usermod -aG libvirt "$USER"
            ;;
        *)
            warn "QEMU/KVM installation currently supports apt, dnf, and pacman only."
            return 1
            ;;
    esac

    if command -v systemctl &>/dev/null; then
        run_task "Enabling libvirtd" sudo systemctl enable libvirtd
        run_task "Starting libvirtd" sudo systemctl start libvirtd
    fi

    success "QEMU/KVM and libvirt installed."
    info "Log out and back in (or reboot) for group 'libvirt' to take effect."
    info "Manage VMs: virsh, or install 'virt-manager' from this menu for GUI."
}

install_virt_manager() {
    info "Installing virt-manager (GUI for libvirt)..."

    local pkg="virt-manager"
    case "$PKG_MANAGER" in
        apt|dnf|pacman)
            install_pkg "$pkg" || return 1
            ;;
        *)
            warn "virt-manager installation currently supports apt, dnf, and pacman only."
            return 1
            ;;
    esac

    success "virt-manager installed."
    info "Run 'virt-manager' to create and manage VMs with a graphical interface."
}

install_virtualbox() {
    info "Installing VirtualBox..."

    case "$PKG_MANAGER" in
        apt)
            install_pkg "virtualbox" || return 1
            install_pkg "virtualbox-ext-pack" || true
            ;;
        dnf)
            # Fedora: use RPMFusion or official Oracle repo; fallback to distro package name
            install_pkg "VirtualBox" 2>/dev/null || install_pkg "virtualbox" 2>/dev/null || {
                warn "On Fedora/RHEL, you may need to enable RPMFusion and install VirtualBox manually."
                return 1
            }
            ;;
        pacman)
            install_pkg "virtualbox" || return 1
            install_pkg "virtualbox-guest-iso" || true
            run_task "Loading vboxdrv module" sudo modprobe vboxdrv
            info "For permanent load: add 'vboxdrv' to MODULES in /etc/mkinitcpio.conf and run sudo mkinitcpio -P"
            ;;
        *)
            warn "VirtualBox installation currently supports apt, dnf, and pacman only."
            return 1
            ;;
    esac

    success "VirtualBox installed."
    if command -v VBoxManage &>/dev/null; then
        echo -e "${NEON_CYAN}VBoxManage:${RESET} $(VBoxManage --version 2>/dev/null || true)"
    fi
    info "Run 'VirtualBox' or 'virtualbox' to start the GUI."
}
