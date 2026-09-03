#!/usr/bin/env bash

# Installs the Fedora-owned packages the Nix tiers depend on, so the host is
# ready for the Nix installer, System Manager, and Home Manager. Fedora stays
# authoritative for the kernel, drivers, desktop, identity, and Docker.
#
# Safe to re-run: it elevates only when something is actually missing.

set -euo pipefail

PACKAGES=(
  # Fedora packages Nix itself, built against Fedora's SELinux policy, so the
  # Determinate installer is not used here. Fedora 44 ships 2.34.8, the same
  # version the flake pins for NixOS and macOS. Updates come from dnf.
  nix
  nix-daemon

  # Flake evaluation and the git+ssh secrets input
  ca-certificates
  curl
  git
  openssh-clients
  xz

  # fusermount3 is setuid and host-owned; gocryptfs (~/Notes) needs it
  fuse3

  # Fedora's Docker build. Provides docker.service and containerd.service, so
  # the agent-boundary drop-ins apply unchanged. Podman is the Fedora default
  # but the Taskfiles and Testcontainers here expect the Docker daemon.
  moby-engine
  docker-compose

  # NetworkManager VPN plugin, matching networkmanager-openvpn on NixOS
  NetworkManager-openvpn
  NetworkManager-openvpn-gnome
)

# Hardware-specific: NVIDIA driver from RPM Fusion, built as an akmod against
# the running kernel; skipped on other hosts. mokutil is needed to enroll the
# module signing key when Secure Boot is on. NVIDIA's PCI vendor id is 0x10de.
if grep -q "0x10de" /sys/bus/pci/devices/*/vendor 2>/dev/null; then
  PACKAGES+=(akmod-nvidia mokutil)
fi

# Hardware-specific: Tuxedo's own repo provides the Control Center, and
# tuxedo-drivers (DKMS) comes with it as a dependency. Skipped on other hosts.
if grep -qi tuxedo /sys/class/dmi/sys_vendor 2>/dev/null; then
  PACKAGES+=(tuxedo-control-center)
fi

# RPM Fusion provides the NVIDIA driver and multimedia packages Fedora ships
# without. The release packages are installed by URL; they are not in Fedora's
# own repos.
RPMFUSION_REPOS=(
  rpmfusion-free-release
  rpmfusion-nonfree-release
)

# input: read raw keyboard devices. uinput: inject events. Only needed to run
# kanata by hand; the service runs as a DynamicUser with its own groups.
GROUPS_WANTED=(docker input uinput)

TARGET_USER="${SUDO_USER:-$USER}"

if [ -r /etc/os-release ]; then
  DISTRO_ID="$(. /etc/os-release && echo "$ID")"
else
  DISTRO_ID="unknown"
fi
if [ "$DISTRO_ID" != "fedora" ]; then
  echo "This bootstrap targets Fedora; detected '$DISTRO_ID'." >&2
  exit 1
fi

missing_packages=()
for package in "${PACKAGES[@]}"; do
  if ! rpm -q "$package" >/dev/null 2>&1; then
    missing_packages+=("$package")
  fi
done

missing_repos=()
for repo in "${RPMFUSION_REPOS[@]}"; do
  if ! rpm -q "$repo" >/dev/null 2>&1; then
    missing_repos+=("$repo")
  fi
done

missing_groups=()
for group in "${GROUPS_WANTED[@]}"; do
  if ! id -nG "$TARGET_USER" | tr ' ' '\n' | grep -qx "$group"; then
    missing_groups+=("$group")
  fi
done

if [ ${#missing_packages[@]} -eq 0 ] && [ ${#missing_groups[@]} -eq 0 ] \
  && [ ${#missing_repos[@]} -eq 0 ]; then
  echo "Fedora prerequisites already in place."
  exit 0
fi

if [ "$(id -u)" -ne 0 ]; then
  echo "Fedora prerequisites need root; re-running with sudo..."
  exec sudo -E bash "${BASH_SOURCE[0]}" "$@"
fi

if [ ${#missing_repos[@]} -gt 0 ]; then
  echo "Enabling RPM Fusion: ${missing_repos[*]}"
  dnf install -y \
    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
fi

# The repo file pins nothing: baseurl and gpgkey both use $releasever, so it
# works for any Fedora release. dnf fetches the GPG key from the declared URL
# on first install.
if grep -qi tuxedo /sys/class/dmi/sys_vendor 2>/dev/null && [ ! -s /etc/yum.repos.d/tuxedo.repo ]; then
  echo "Adding the Tuxedo package repository..."
  curl -fsSL "https://rpm.tuxedocomputers.com/fedora/tuxedo.repo" -o /etc/yum.repos.d/tuxedo.repo
fi

if [ ${#missing_packages[@]} -gt 0 ]; then
  echo "Installing: ${missing_packages[*]}"
  dnf install -y "${missing_packages[@]}"
fi

# Secure Boot refuses the unsigned akmod. Instead of disabling Secure Boot,
# akmods signs the locally built module with its own key; mokutil queues the
# key for enrollment, confirmed on the MOK screen at the next reboot.
if rpm -q akmod-nvidia >/dev/null 2>&1 && command -v mokutil >/dev/null 2>&1 \
  && [ -d /sys/firmware/efi ] && mokutil --sb-state 2>/dev/null | grep -qi "enabled"; then
  if [ ! -e /etc/pki/akmods/certs/public_key.der ]; then
    echo "Generating the akmod signing key..."
    kmodgenca -a
  fi
  if ! mokutil --test-key /etc/pki/akmods/certs/public_key.der >/dev/null 2>&1; then
    echo "Secure Boot is on; enrolling the akmod signing key (choose a password)."
    mokutil --import /etc/pki/akmods/certs/public_key.der
  fi
fi

# System Manager declares this group too, but it activates after this script.
groupadd -f uinput

for group in "${missing_groups[@]}"; do
  echo "Adding $TARGET_USER to group $group"
  usermod -aG "$group" "$TARGET_USER"
done

systemctl enable --now docker nix-daemon

cat <<EOF

Fedora prerequisites installed. Steps Fedora or IT must still own:

  - Check Point Harmony Endpoint: vendor .deb; needs conversion or a vendor RPM
  - Red Hat IdM:       ipa-client-install, run with domain credentials by IT
  - SELinux:           enforcing by default; expect to audit denials for the
                       agent sandbox and the Nix store rather than disable it
  - Firewall:          firewalld is active by default, unlike Ubuntu's ufw

If akmod-nvidia was installed, reboot: the NVIDIA module builds on the next
boot and startup can take a few minutes. Verify with nvidia-smi afterwards.
With Secure Boot, confirm the MOK enrollment screen at that reboot (the menu
is QWERTY); skipping it leaves the driver unable to load.

Log out and back in (or reboot) so the new group memberships apply.
EOF
