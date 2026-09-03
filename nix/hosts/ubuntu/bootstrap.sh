#!/usr/bin/env bash

# Installs the Ubuntu-owned packages the Nix tiers depend on, so the host is
# ready for the Nix installer, System Manager, and Home Manager. Ubuntu stays
# authoritative for the kernel, drivers, desktop, identity, and Docker.
#
# Safe to re-run: it elevates only when something is actually missing.

set -euo pipefail

PACKAGES=(
  # Nix installer, flake evaluation, and the git+ssh secrets input
  ca-certificates
  curl
  git
  openssh-client
  xz-utils

  # fusermount3 is setuid and host-owned; gocryptfs (~/Notes) needs it
  fuse3

  # Docker stays rootful and Ubuntu-owned; System Manager only adds drop-ins
  docker.io
  docker-compose-v2

  # NetworkManager VPN plugin, matching networkmanager-openvpn on NixOS
  network-manager-openvpn
  network-manager-openvpn-gnome
)

# Upstream GNOME session, selectable as "GNOME" at the GDM login screen and
# installed alongside Ubuntu's own. Home Manager's dconf settings and GNOME
# extensions target stock GNOME, so this is the session they expect. Installed
# without recommends: the app suite comes from Nix, and duplicates would compete
# for the same desktop entries. `gnome-session` is in universe.
#
# Unverified: whether gnome-session alone registers the session with GDM. Check
# for /usr/share/wayland-sessions/gnome.desktop after installing; if it is
# absent, `apt install --no-install-recommends vanilla-gnome-desktop` instead.
DESKTOP_PACKAGES=(
  gnome-session
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
if [ "$DISTRO_ID" != "ubuntu" ]; then
  echo "This bootstrap targets Ubuntu; detected '$DISTRO_ID'." >&2
  exit 1
fi

package_installed() {
  dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q 'install ok installed'
}

missing_packages=()
for package in "${PACKAGES[@]}"; do
  package_installed "$package" || missing_packages+=("$package")
done

missing_desktop=()
for package in "${DESKTOP_PACKAGES[@]}"; do
  package_installed "$package" || missing_desktop+=("$package")
done

missing_groups=()
for group in "${GROUPS_WANTED[@]}"; do
  if ! id -nG "$TARGET_USER" | tr ' ' '\n' | grep -qx "$group"; then
    missing_groups+=("$group")
  fi
done

if [ ${#missing_packages[@]} -eq 0 ] && [ ${#missing_desktop[@]} -eq 0 ] && [ ${#missing_groups[@]} -eq 0 ]; then
  echo "Ubuntu prerequisites already in place."
  exit 0
fi

if [ "$(id -u)" -ne 0 ]; then
  echo "Ubuntu prerequisites need root; re-running with sudo..."
  exec sudo -E bash "${BASH_SOURCE[0]}" "$@"
fi

export DEBIAN_FRONTEND=noninteractive

if [ ${#missing_packages[@]} -gt 0 ] || [ ${#missing_desktop[@]} -gt 0 ]; then
  apt-get update
fi

if [ ${#missing_packages[@]} -gt 0 ]; then
  echo "Installing: ${missing_packages[*]}"
  apt-get install -y "${missing_packages[@]}"
fi

if [ ${#missing_desktop[@]} -gt 0 ]; then
  echo "Installing (no recommends): ${missing_desktop[*]}"
  apt-get install -y --no-install-recommends "${missing_desktop[@]}"
fi

# System Manager declares this group too, but it activates after this script.
groupadd -f uinput

for group in "${missing_groups[@]}"; do
  echo "Adding $TARGET_USER to group $group"
  usermod -aG "$group" "$TARGET_USER"
done

systemctl enable --now docker

cat <<EOF

Ubuntu prerequisites installed. Steps Ubuntu or IT must still own:

  - Graphics drivers:  sudo ubuntu-drivers autoinstall
  - Tuxedo drivers:    tuxedo-drivers DKMS package from Tuxedo's repository
  - Check Point Harmony Endpoint: vendor .deb, installed per IT policy
  - Red Hat IdM:       ipa-client-install, run with domain credentials by IT
  - Session:           pick "GNOME" (not "Ubuntu") from the gear icon at the
                       login screen, so the managed dconf settings apply

Log out and back in (or reboot) so the new group memberships apply.
EOF
