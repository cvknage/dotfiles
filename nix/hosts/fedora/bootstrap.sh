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

# Fedora Workstation already ships upstream GNOME, so unlike Ubuntu there is no
# vanilla session to add.

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

missing_groups=()
for group in "${GROUPS_WANTED[@]}"; do
  if ! id -nG "$TARGET_USER" | tr ' ' '\n' | grep -qx "$group"; then
    missing_groups+=("$group")
  fi
done

if [ ${#missing_packages[@]} -eq 0 ] && [ ${#missing_groups[@]} -eq 0 ]; then
  echo "Fedora prerequisites already in place."
  exit 0
fi

if [ "$(id -u)" -ne 0 ]; then
  echo "Fedora prerequisites need root; re-running with sudo..."
  exec sudo -E bash "${BASH_SOURCE[0]}" "$@"
fi

if [ ${#missing_packages[@]} -gt 0 ]; then
  echo "Installing: ${missing_packages[*]}"
  dnf install -y "${missing_packages[@]}"
fi

# System Manager declares this group too, but it activates after this script.
groupadd -f uinput

for group in "${missing_groups[@]}"; do
  echo "Adding $TARGET_USER to group $group"
  usermod -aG "$group" "$TARGET_USER"
done

systemctl enable --now docker

cat <<EOF

Fedora prerequisites installed. Steps Fedora or IT must still own:

  - Graphics drivers:  Nvidia via RPM Fusion (akmod-nvidia), if needed
  - Tuxedo drivers:    tuxedo-drivers DKMS, built from source on Fedora
  - Check Point Harmony Endpoint: vendor .deb; needs conversion or a vendor RPM
  - Red Hat IdM:       ipa-client-install, run with domain credentials by IT
  - SELinux:           enforcing by default; expect to audit denials for the
                       agent sandbox and the Nix store rather than disable it
  - Firewall:          firewalld is active by default, unlike Ubuntu's ufw

Log out and back in (or reboot) so the new group memberships apply.
EOF
