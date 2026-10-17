#!/usr/bin/env bash
# setup-vagrant.sh — install everything needed to build & test the rcraid
# DKMS module in Vagrant/libvirt VMs on the supported distro families:
#
#   Debian/Ubuntu, RHEL-family (EL8, EL9, Fedora), openSUSE/SLES 15, Arch
#
# Installs: KVM/libvirt stack, build tools, Vagrant (HashiCorp package,
# except on Arch which ships its own), vagrant-libvirt + vagrant-reload
# plugins, adds the user to libvirt/kvm groups, starts libvirtd and
# defines the repo's DHCP-only "vagrantnet" network.
#
# Usage:  ./setup-vagrant.sh          (as a sudo-capable user, or root)
# Env:    VAGRANT_VERSION=2.4.9       (override to change the version)
set -euo pipefail

VAGRANT_VERSION="${VAGRANT_VERSION:-2.4.9}"
VAGRANT_PLUGINS="${VAGRANT_PLUGINS:-vagrant-libvirt vagrant-reload}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NETWORK_XML="$SCRIPT_DIR/vagrant/vagrantnet.xml"

log() { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  command -v sudo >/dev/null || die "sudo is required (or run as root)"
  SUDO="sudo"
fi
RUN_USER="${SUDO_USER:-$USER}"

[ -r /etc/os-release ] || die "cannot detect distro: /etc/os-release missing"
# shellcheck disable=SC1091
. /etc/os-release
IDS=" ${ID:-} ${ID_LIKE:-} "

install_hashicorp_vagrant() {
  local fmt="$1" url tmp
  tmp=$(mktemp)
  case "$fmt" in
    deb) url="https://releases.hashicorp.com/vagrant/${VAGRANT_VERSION}/vagrant_${VAGRANT_VERSION}-1_amd64.deb" ;;
    rpm) url="https://releases.hashicorp.com/vagrant/${VAGRANT_VERSION}/vagrant_${VAGRANT_VERSION}-1_x86_64.rpm" ;;
  esac
  log "Fetching Vagrant ${VAGRANT_VERSION} ($fmt)"
  curl -fsSL -o "$tmp.$fmt" "$url"
  case "$fmt" in
    deb) $SUDO dpkg -i "$tmp.$fmt" || $SUDO apt-get -f install -y ;;
    rpm) $SUDO rpm -Uvh "$tmp.$fmt" ;;
  esac
  rm -f "$tmp.$fmt"
}

case "$IDS" in
  *" debian "*|*" ubuntu "*)
    log "Debian-family detected: ${PRETTY_NAME:-$ID}"
    $SUDO apt-get update
    $SUDO apt-get install -y qemu-kvm libvirt-daemon-system libvirt-clients \
      libvirt-dev libxslt-dev libxml2-dev zlib1g-dev ruby-dev \
      build-essential rsync curl
    install_hashicorp_vagrant deb
    ;;
  *" rhel "*|*" centos "*|*" fedora "*|*" almalinux "*|*" rocky "*|*" ol "*)
    log "RHEL-family detected: ${PRETTY_NAME:-$ID}"
    $SUDO dnf install -y qemu-kvm libvirt libvirt-client libvirt-devel \
      libxslt-devel libxml2-devel zlib-devel ruby-devel \
      gcc make rsync curl
    install_hashicorp_vagrant rpm
    ;;
  *" suse "*|*" opensuse "*|*" sles "*)
    log "SUSE-family detected: ${PRETTY_NAME:-$ID}"
    $SUDO zypper install -y qemu-kvm libvirt libvirt-client libvirt-devel \
      libxslt-devel libxml2-devel zlib-devel ruby-devel \
      gcc make rsync curl
    install_hashicorp_vagrant rpm
    ;;
  *" arch "*)
    log "Arch-family detected: ${PRETTY_NAME:-$ID}"
    $SUDO pacman -Sy --needed --noconfirm qemu-base libvirt libxslt libxml2 \
      zlib base-devel rsync curl vagrant
    ;;
  *)
    die "unsupported distro: ${PRETTY_NAME:-$ID} (supported: Debian/Ubuntu, EL8/EL9/Fedora, openSUSE 15/SLES 15, Arch)"
    ;;
esac

log "Enabling libvirtd"
$SUDO systemctl enable --now libvirtd

log "Adding '$RUN_USER' to libvirt and kvm groups"
$SUDO usermod -aG libvirt,kvm "$RUN_USER"

if [ -r "$NETWORK_XML" ]; then
  if ! virsh -c qemu:///system net-info vagrantnet >/dev/null 2>&1; then
    log "Defining 'vagrantnet' (DHCP-only; no port-53 conflict)"
    virsh -c qemu:///system net-define "$NETWORK_XML" \
      || $SUDO virsh -c qemu:///system net-define "$NETWORK_XML"
    virsh -c qemu:///system net-start vagrantnet 2>/dev/null \
      || $SUDO virsh -c qemu:///system net-start vagrantnet
    virsh -c qemu:///system net-autostart vagrantnet 2>/dev/null \
      || $SUDO virsh -c qemu:///system net-autostart vagrantnet
  else
    log "'vagrantnet' already defined"
  fi
else
  log "No $NETWORK_XML found — the Vagrantfile can also use libvirt's"
  log "  'default' network via VAGRANT_LIBVIRT_NETWORK=default"
fi

log "Installing Vagrant plugins as $RUN_USER: $VAGRANT_PLUGINS"
for plugin in $VAGRANT_PLUGINS; do
  if [ "$SUDO" = "sudo" ]; then
    vagrant plugin list | grep -qx "$plugin .*" || vagrant plugin install "$plugin"
  else
    su - "$RUN_USER" -c "vagrant plugin list | grep -qx '$plugin .*' || vagrant plugin install '$plugin'"
  fi
done

log "Done. Verify with:"
echo "    vagrant plugin list"
echo "    virsh -c qemu:///system net-list --all"
echo "    vagrant up rcraid-el8   # or rcraid-el9 / rcraid-opensuse15"
[ "$(id -u)" -eq 0 ] || groups | grep -q libvirt || \
  echo "NOTE: log out and back in for the new group membership to take effect."
