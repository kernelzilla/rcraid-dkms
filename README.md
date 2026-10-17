# rcraid-dkms
AMD RAIDXpert driver as DKMS package

Foreword:
===========

Many AMD mainboards for the AM4 socket based on the following chipsets come with RAID support:
 * X370
 * X399
 * X470
 * X570

But this RAID mode, which needs to be set in the BIOS, requires a specific driver for each OS.
There is a driver for Windows, but for Linux AMD provides either a binary blob or the sources.
When following the instructions, you will need to recompile the driver and install the kernel module on each kernel update and/or upgrade.
Since we are in the 21 century and we have software like DKMS, we don't need to do this manually, but let it happen automatically.

Goal
====
Therefore we try here to keep the code alive for many kernel versions as
possible and ship it as DKMS packages for Debian/Ubuntu, RHEL-family
distros (EL8, EL9, Fedora), openSUSE Leap 15 / SLES 15 and Arch.

Kernel compatibility notes
==========================
The `src/` directory contains AMD's RAIDXpert2 9.3.2 driver source with
community patches to keep it building on current kernels:

* Kernel 6.14+: `.sdev_configure` callback (with `queue_limits`)
  replaces `.slave_configure`.
* Kernel 6.15+: `timer_delete_sync()` replaces `del_timer_sync()`.
* Kernel 6.16+: `timer_container_of()` replaces `from_timer()`.
* Kernel 6.17+: `bios_param()` now receives a `struct gendisk *`
  instead of `struct block_device *`.
* C89-style `()` function definitions were converted to `(void)` to
  satisfy `-Wstrict-prototypes`, which is an error on newer toolchains.
* The Makefile detects `CONFIG_CC_IS_CLANG` in the target kernel's
  configuration and automatically builds the module with clang when
  needed (e.g. xanmod kernels, which are built with clang/lld). Make
  sure `clang` is installed when building for such kernels.

Distro-kernel backport handling (see `src/rc_compat.h`):

* RHEL 9 kernels backported `timer_container_of()`,
  `timer_delete_sync()` and the direct `queue_limits` API into their
  5.14 tree while removing `from_timer()` and
  `blk_queue_max_hw_sectors()`. The code detects the available API
  instead of trusting `LINUX_VERSION_CODE`.
* `<linux/stdarg.h>` is used on kernels >= 5.10; plain `<stdarg.h>`
  is not reachable under RHEL/EL kbuild flags.
* `linux/genhd.h` (removed upstream in 5.18, also absent on EL9's
  5.14) is included only when present (`__has_include`).
* `sysrq_key_op.handler` is cast to the member's real type — SLE
  15-SP6's 6.4 kernel already uses the `u8` signature upstream only
  adopted in 6.6.
* The deprecated `EXTRA_CFLAGS` accumulation was dropped from the
  module Makefile; it creates a make-time recursion abort on EL8's
  4.18 kbuild.

Supported kernel range
----------------------

The source carries compatibility shims for roughly **4.0 → 6.18+**
upstream kernels, plus the heavily backported enterprise kernels.
Continuously verified builds (Vagrant/CI matrix):

| Kernel | Distro example            | Status               |
|--------|---------------------------|----------------------|
| 4.18.x | RHEL/Alma/Rocky **EL8**   | builds, loads, DKMS  |
| 5.14.x | RHEL/Alma/Rocky **EL9**   | builds, loads, DKMS  |
| 5.15.x | Ubuntu 22.04              | builds               |
| 6.4.x  | openSUSE **Leap 15.6**    | builds, loads, DKMS  |
| 6.8.x  | Ubuntu 24.04              | builds               |
| 6.18.x | xanmod (clang toolchain)  | builds               |

Anything between these points should build as well — the compat layer
keys on API presence, not version numbers — but the matrix above is
what is actually exercised.

Note on Intel IBT / kernel CET: kernels built with
`CONFIG_X86_KERNEL_IBT=y` enforce Indirect Branch Tracking on CPUs that
support it (Intel Tiger Lake+, AMD Zen 3+). The prebuilt `rcblob` object
does not contain ENDBR instructions, so indirect calls into it will
trigger `Missing ENDBR` control-protection faults on such systems.
Boot with `ibt=warn` (log violations but continue) or `ibt=off` if your
kernel enforces IBT on your CPU. Systems without IBT-capable CPUs
(e.g. AMD Zen 2 and older) are unaffected.

Installation
============
## Debian/Ubuntu

Build the `.deb` from the in-tree `debian/` packaging:

```bash
sudo apt-get install build-essential debhelper dkms linux-headers-$(uname -r)
dpkg-buildpackage -us -uc -b      # run in the repo root
sudo dpkg -i ../rcraid-dkms_*.deb
```

The package registers the sources under `/usr/src/rcraid-<version>` and
lets DKMS build/install `rcraid.ko` for the running kernel and every
future kernel update (`AUTOINSTALL`).

  * Switching to RAID mode:
    * Boot Linux in AHCI mode.
    * Append `modprobe.blacklist=ahci` to GRUB_CMDLINE_LINUX_DEFAULT in /etc/default/grub
    * Run `sudo update-grub`
    * Restart
    * Switch to RAID mode
    * Boot your Linux installation from a RAID disk

## RHEL-family (EL8, EL9, Fedora) — RPM

The `rpm/` directory contains a unified spec file that produces a
DKMS-based RPM on both RHEL-family distros and openSUSE Leap 15 / SLES 15.

On the target system:

```bash
# dkms lives in EPEL on RHEL rebuilds
sudo dnf install epel-release
sudo dnf install rpm-build dkms kernel-devel gcc make
rpm/mksources.sh ~/rpmbuild/SOURCES
cp rpm/rcraid-dkms.spec ~/rpmbuild/SPECS/
rpmbuild -ba ~/rpmbuild/SPECS/rcraid-dkms.spec
sudo rpm -ivh ~/rpmbuild/RPMS/*/rcraid-dkms-*.rpm
```

Installing the RPM registers the module source under
`/usr/src/rcraid-<version>-<release>` and lets DKMS build, sign (via its
own MOK enrollment when Secure Boot is on) and install `rcraid.ko` for
the running kernel. DKMS' `AUTOINSTALL` rebuilds it for future kernel
updates automatically. A `/etc/dracut.conf.d/rcraid.conf` snippet is
shipped so the driver is pulled into newly generated initramfs images
(required for booting from an rcraid array).

## openSUSE Leap 15 / SLES 15 — RPM

Same spec file; different package names for the prerequisites:

```bash
sudo zypper install rpm-build dkms kernel-default-devel gcc make
rpm/mksources.sh ~/rpmbuild/SOURCES
cp rpm/rcraid-dkms.spec ~/rpmbuild/SPECS/
rpmbuild -ba ~/rpmbuild/SPECS/rcraid-dkms.spec
sudo rpm -ivh ~/rpmbuild/RPMS/*/rcraid-dkms-*.rpm
```

Note that SUSE kernels refuse out-of-tree modules by default. Either
load with `modprobe --allow-unsupported rcraid` or set
`allow_unsupported_modules 1` in
`/etc/modprobe.d/10-unsupported-modules.conf`.

### Vagrant test matrix

`vagrant/` contains a full build+test pipeline. Three VMs (libvirt
provider):

| VM name            | Box                       | Kernel family |
|--------------------|---------------------------|---------------|
| `rcraid-el8`       | `almalinux/8`             | 4.18 (EL8)    |
| `rcraid-el9`       | `almalinux/9`             | 5.14 (EL9)    |
| `rcraid-opensuse15`| `opensuse/Leap-15.6.x86_64` | 6.4 (SUSE)  |

Host requirements: KVM (`/dev/kvm`), libvirt + virsh, Vagrant (>= 2.4)
and the `vagrant-libvirt` and `vagrant-reload` plugins, plus membership
in the `libvirt` and `kvm` groups. The VMs use a DHCP-only libvirt NAT
network (`vagrantnet`, defined by `vagrant/vagrantnet.xml`) whose DNS is
disabled so it does not collide with a resolver already bound to host
port 53; set `VAGRANT_LIBVIRT_NETWORK=default` to use libvirt's stock
NAT network on hosts without that conflict.

`./setup-vagrant.sh` installs all of the above on any supported host
distro (Debian/Ubuntu, RHEL-family, openSUSE/SLES 15, Arch) — or install
manually:

```bash
virsh -c qemu:///system net-define vagrant/vagrantnet.xml
virsh -c qemu:///system net-start vagrantnet
vagrant plugin install vagrant-libvirt vagrant-reload

vagrant/test-all.sh        # everything, artifacts land in dist/<vm>/
vagrant up rcraid-el9      # or a single VM
make vagrant-test-el8      # Makefile shortcuts
```

Per VM the pipeline is: install dkms/kernel-devel/rpm-build, update the
kernel, reboot, `rpmbuild -ba` (binary + src.rpm), `rpm -Uvh` (which runs
`dkms add/build/install` via `%post`), then `vagrant/verify.sh` asserts
the dkms state, module file, `modinfo`, and clean package removal. A final
`verify-load.sh` inserts the module and logs the result to the VM
console — on machines without RAID hardware the driver's PCI probing can
disturb the virtio NIC, so the load test deliberately runs last and is
also readable via `virsh screenshot <domain>`.

Note: `modprobe rcraid` is a smoke test only — without Promontory RAID
hardware the module loads but binds to nothing, and in VMs it can take
the virtio NIC down with it. On real hardware this is a non-issue.

Distro notes:

* **openSUSE/SLES** refuse out-of-tree modules by default:
  `modprobe --allow-unsupported rcraid`, or set
  `allow_unsupported_modules 1` in `/etc/modprobe.d/10-unsupported-modules.conf`.
* On **legacy-BIOS** machines the AMD blob can NULL-call during
  `rcraid_init` (`is_var_not_supported`, observed inside SLE/Leap VMs).
  UEFI systems — which is what every RAIDXpert2 setup uses anyway — do
  not hit this path.

## Arch/Manjaro
* Download and unpack zip or:

```bash
  git clone https://github.com/thopiekar/rcraid-dkms.git
```

* From inside "arch" directory:

```bash
  makepkg -si
```

* This will compile sources and install package for current running kernel. If you need 
to make package for different kernel then you can use KVERS option.
After installing edit /etc/mkinitcpio.conf and add
  
```bash
  MODULES=(rcraid?)
```

* Then rebuild your initrd f.e.:

```bash
  mkinitcpio -p linux56
```

**Note:** If you just planning on switching to rcraid, my advice is: don't. 
Support from AMD for Promontory raid on Linux is pretty much non-existent. 
You will be way better off sticking with mdadm, zfs or lvm. 

If you REALLY want this to dual-boot Linux/Win, also don't. Setting up virtualization 
with KVM with GPU Passtrough today is really simple, and you will not need to 
boot Windows directly on your hardware ever again.

**Sidenote:** If you decide to use rcraid regardless you might want to also install RAIDXpert. 
Web interface isn't working properly on Manjaro, but rcadm is more or less is.

**Sidenote 2:** If you ever decide to switch from rcraid to something else, you may find it useful 
to know that deleting arrays only removes metadata. Partitions are still there, and can be
recovered with gdisk, gpart etc. I found out that offset for partitions is 1069056 sectors (512B).
So if you have partition starting at usual 2048 it will be at 1071104 after array deletion.

Special Thanks
==============
This repository is a fork of https://github.com/thopiekar/rcraid-dkms
by Thomas Karl Pietrowski (@thopiekar), extended to keep the driver
building on current kernels and to support additional distributions
(EL8/EL9, openSUSE Leap 15/SLES 15, and newer 6.x kernels).

  * To Thomas Karl Pietrowski for creating and maintaining the original
    rcraid-dkms project this work builds on.
  * To AMD to hand out the driver as source code at least. (Some history: Just think about Intel Poulsbo..)
    * https://www.amd.com/en/support/chipsets/amd-socket-am4/x370 - section Linux
  * To Martin Weber (@martinkarlweber) for sharing patches to make the driver work on Linux >= 4.15.x
    * https://github.com/martinkarlweber/rcraid-patches
