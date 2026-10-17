# -*- mode: ruby -*-
# vi: set ft=ruby :
#
# Vagrantfile for building and testing the rcraid-dkms RPM.
#
# VMs (all use the libvirt provider):
#   rcraid-el8         - EL8   (AlmaLinux 8)
#   rcraid-el9         - EL9   (AlmaLinux 9)
#   rcraid-opensuse15  - openSUSE Leap 15.6
#
# Each VM is provisioned in two phases:
#   1. provision-deps.sh - install dkms/kernel-devel/rpm-build + update kernel
#      :reload           - reboot into the updated kernel (vagrant-reload)
#   2. build-test.sh     - build the RPM, install it, run vagrant/verify.sh
#
# Usage:
#   vagrant up rcraid-el9           # one VM
#   vagrant/test-all.sh             # all three, pulls artifacts into dist/
#
# The repo is pushed into the guest with the "file" provisioner (no rsync
# or NFS needed on host or guest); the synced folder is disabled on
# purpose.

Vagrant.configure("2") do |config|
  config.vm.provider :libvirt do |lv|
    lv.memory = 4096
    lv.cpus   = 4
    # qcow2 overlay images: do not rewrite the base box
    lv.storage_pool_name = "default"
    # NAT network with DNS disabled (<dns enable='no'/>) so libvirt's
    # dnsmasq only serves DHCP and does not collide with a resolver
    # already bound to host port 53. Create once with:
    #   virsh net-define vagrant/vagrantnet.xml && virsh net-start vagrantnet
    # On a clean host/CI runner the stock libvirt "default" network works:
    #   VAGRANT_LIBVIRT_NETWORK=default vagrant up rcraid-el8
    lv.management_network_name = ENV["VAGRANT_LIBVIRT_NETWORK"] || "vagrantnet"
    # Domain names default to "<project-dir-basename>_<vm>"; override to
    # avoid collisions when several worktrees share the basename (e.g. a
    # CI runner checkout next to a development checkout).
    lv.default_prefix = ENV["VAGRANT_DOMAIN_PREFIX"] if ENV["VAGRANT_DOMAIN_PREFIX"]
  end

  config.vm.synced_folder ".", "/vagrant", disabled: true

  {
    "el8"        => "almalinux/8",
    "el9"        => "almalinux/9",
    "opensuse15" => "opensuse/Leap-15.6.x86_64",
    "ubuntu-xanmod" => "alvistack/ubuntu-24.04",
    # vanilla-kernel targets: ToeiRei/kernel-deb packages, booted on the
    # latest kernel.org stable; DKMS-builds run for *every* stable and
    # longterm series' headers (see vagrant/kernel-versions.sh).
    "debian-vanilla"     => "debian/trixie64",
    "ubuntu2404-vanilla" => "alvistack/ubuntu-24.04",
    "ubuntu2204-vanilla" => "alvistack/ubuntu-22.04",
  }.each do |name, box|
    config.vm.define "rcraid-#{name}" do |node|
      node.vm.box = box
      node.vm.hostname = "rcraid-#{name}"

      # push the working tree into the guest (scp-based, provider-agnostic)
      node.vm.provision "file", source: ".", destination: "$HOME/rcraid-dkms"

      node.vm.provision "deps", type: "shell",
        env: {
          "XANMOD"         => name == "ubuntu-xanmod" ? "1" : "0",
          "VANILLA_KERNEL" => name.end_with?("-vanilla") ? "1" : "0",
          # kernel.org version to boot; VANILLA_KVERS=auto means
          # "headers for every stable+longterm series"
          "VANILLA_KVER"   => ENV["VANILLA_KVER"] || "7.2.11",
          "VANILLA_KVERS"  => ENV["VANILLA_KVERS"] || "auto",
        },
        path: "vagrant/provision-deps.sh"
      node.vm.provision :reload
      node.vm.provision "build-test", type: "shell", privileged: true,
        path: "vagrant/build-test.sh"
    end
  end
end
