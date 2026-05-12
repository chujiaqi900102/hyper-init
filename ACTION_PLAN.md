# HyperInit — Project Review Action Plan

This document captures possible defects, impact, a verification checklist, and a phased remediation plan from a focused codebase review.

---

## 1. Defect register (priority × impact)

| ID   | Area                         | Issue                                                                 | Impact                                                                 | Typical trigger                                              |
|------|------------------------------|-----------------------------------------------------------------------|------------------------------------------------------------------------|--------------------------------------------------------------|
| P1-1 | `modules/system.sh` `harden_ssh` | ~~Uses `systemctl restart sshd`~~ **Fixed 2026-05-12:** `_restart_openssh` tries `ssh` then `sshd` / `service`. | — | — |
| P1-2 | `modules/dev.sh` `install_docker` | ~~Docker repo URL hard-coded to `.../linux/debian/...`~~ **Fixed 2026-05-12:** URLs use `linux/ubuntu` or `linux/debian` from `ID` / `ID_LIKE`. | — | — |
| P1-3 | `modules/system.sh` `change_mirrors` | ~~ubuntu.sources not updated~~ **Fixed 2026-05-12:** If `ubuntu.sources` exists, rewrite all `URIs:` lines to `$mirror/ubuntu`; else classic `sources.list`. | — | — |
| P2-1 | `modules/dev.sh` `install_lxc` | Non-snap apt path installs packages but omits `lxd init`              | Install “succeeds” but `lxc launch` still blocked until manual init    | apt path without snap                                        |
| P2-2 | `modules/ai.sh` `ai_menu`    | No unified pause before recursive menu vs other modules               | Future install path missing `read` → menu redraw / UX regression risk | Any AI menu action                                             |
| P2-3 | `bootstrap.sh`               | Unknown distro: dependency loop installs nothing                      | `git clone` / `git pull` fails with unclear cause                      | Unsupported or niche `ID` in `/etc/os-release`               |
| P3-1 | `lib/utils.sh` / `lib/tui.sh` | `tput` / spinner; no cursor `trap`                                    | Errors or hidden cursor in non-TTY / minimal environments              | CI, pipes, `ssh -T`                                          |
| P3-2 | `modules/virtualization.sh`  | Fedora VirtualBox + stderr redirection around `install_pkg`          | Noisy or misleading failure diagnostics                               | Fedora + VirtualBox install                                  |
| P3-3 | `modules/shell.sh`           | `sed` assumes default `ZSH_THEME` / `plugins=(git)`                   | Theme/plugins not applied if user customized `.zshrc`                   | Non-default `.zshrc`                                         |
| P3-4 | Multiple (`curl \| bash`)    | No checksum / pinned versions                                       | Supply-chain and reproducibility risk                                  | Network installs (Node, Ollama, etc.)                      |
| P3-5 | `modules/monitoring.sh`      | dnf package `prometheus-node_exporter`                              | Install fails on some Fedora/RHEL variants                             | Repo naming differences                                      |
| P3-6 | `lib/os.sh`                  | `PKG_MANAGER=unknown`                                                 | Silent partial failure depending on caller                             | Unsupported `ID`                                             |

**Legend:** P1 = wrong behavior or security expectation gap; P2 = common environment footgun; P3 = edge case, UX, or maintainability.

---

## 2. Verification checklist

Use before merge/release and when touching related modules.

### General

- [ ] `bash -n main.sh` and all `lib/*.sh`, `modules/*.sh` pass
- [ ] Run under non-TTY or wrapped with `script` / CI: no hang, cursor restored if spinner/TUI used
- [ ] Unmatched or empty menu selection does not tight-loop without user input

### Distro matrix (spot-check at least one each)

- [ ] **Ubuntu LTS:** `change_mirrors` → `apt update` uses intended mirror; Docker uses `linux/ubuntu` when `ID=ubuntu`
- [ ] **Debian:** Docker uses `linux/debian`; `harden_ssh` leaves SSH active and config applied
- [ ] **Fedora:** VirtualBox / node_exporter / PostgreSQL init path smoke
- [ ] **Arch:** PostgreSQL `initdb`, Redis service name

### Security-sensitive

- [ ] After `harden_ssh`: `PermitRootLogin no` (or equivalent) and **SSH service actually restarted** (`ssh` or `sshd` as appropriate)
- [ ] APT backups created before destructive edits; permissions sane
- [ ] `repair_apt_sources`: cases — healthy sources; malformed `docker.list`; Microsoft `Signed-By` conflict

### LXC/LXD (`install_lxc`)

- [ ] With snap: install + init path works; `lxc list` OK
- [ ] Without snap, apt only: post-install init documented or automated; `lxc list` OK

### UX / errors

- [ ] Submenu “Back” does not swallow prior errors
- [ ] `run_task` failures show enough context (package, command) to fix locally

---

## 3. Action plan (phased)

### Phase A — Fix now (blocking correctness / security perception)

| Task | Ref   | Action                                                                 |
|------|-------|--------------------------------------------------------------------------|
| A.1  | P1-1  | ~~Done 2026-05-12~~ `_restart_openssh`: `systemctl restart ssh` → `sshd` → `service`; warn on failure. |
| A.2  | P1-2  | ~~Done 2026-05-12~~ `install_docker`: `docker_ce_linux` from `ID` + `ID_LIKE` ubuntu; all mirrors use `linux/$docker_ce_linux`. |
| A.3  | P1-3  | ~~Done 2026-05-12~~ `change_mirrors`: deb822 `ubuntu.sources` URIs updated (perl or sed); classic path if file absent. |

### Phase B — Short term (reliability / consistency)

| Task | Ref   | Action                                                                 |
|------|-------|--------------------------------------------------------------------------|
| B.1  | P2-1  | After apt `lxd` install: run `lxd init --auto` when non-interactive acceptable, or prompt; verify `lxc` works |
| B.2  | P2-3  | `bootstrap.sh`: on unknown OS, print clear error and `exit 1`, or require preinstalled `git`/`curl` |
| B.3  | P2-2  | Align `ai_menu` with other menus: single “press any key” before recurse; dedupe inner `read` where redundant |

### Phase C — Medium term (quality / maintainability)

| Task | Ref   | Action                                                                 |
|------|-------|--------------------------------------------------------------------------|
| C.1  | P3-1  | Guard `tput`; skip spinner when not a TTY; `trap` restore cursor on EXIT/INT |
| C.2  | —     | README: support matrix (Ubuntu/Debian/Fedora/Arch) per menu category |
| C.3  | P3-2, P3-5 | Fedora: document or probe package names; print upstream docs on failure |
| C.4  | P3-3  | Safer `.zshrc` edits: append block or use markers instead of fragile single-line `sed` |

### Phase D — Long term (optional)

| Task | Ref   | Action                                                                 |
|------|-------|--------------------------------------------------------------------------|
| D.1  | —     | Lightweight integration tests (e.g. container: `bash -n` + mocked `apt`) |
| D.2  | P3-4  | Pin versions or verify checksums for critical remote install scripts |

---

## 4. Suggested order of execution

1. **A.1 → A.2 → A.3** (largest user-facing impact)
2. **B.1 → B.2 → B.3**
3. **C.1 → C.2**, then **C.3 → C.4** as bandwidth allows
4. **D.*** when stabilizing for wider distribution

---

## 5. Document maintenance

- Update this file when items are fixed (strike-through or “Done YYYY-MM-DD” in a changelog section).
- Link PRs next to task IDs when implemented.

### Changelog (implemented)

- **2026-05-12:** Phase A (P1-1, P1-2, P1-3) implemented in `modules/system.sh`, `modules/dev.sh`; `bash -n` clean on all entrypoints and `lib/` / `modules/` scripts.
