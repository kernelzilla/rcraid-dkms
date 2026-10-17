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

### CI Status

The `vagrant-*` jobs run the full pipeline (rpmbuild → `rpm -Uvh` → DKMS
build/install → verify → modprobe smoke test) in real libvirt VMs; the
`pkg-*` jobs build the binary packages; the container jobs compile the
module against each distro's kernel-devel.

| Target | Status |
| :--- | :---: |
| **AlmaLinux 8** (kernel 4.18) | <img src="https://img.shields.io/github/actions/workflow/status/kernelzilla/rcraid-dkms/release.yml?job=vagrant-el8&style=flat-square&logo=redhat&logoColor=white&label=vagrant"/> <img src="https://img.shields.io/github/actions/workflow/status/kernelzilla/rcraid-dkms/rcraid-dkms-ci.yml?job=rcraid-dkms_rpm_almalinux%3A8&style=flat-square&logo=redhat&logoColor=white&label=container"/> |
| **AlmaLinux 9** (kernel 5.14) | <img src="https://img.shields.io/github/actions/workflow/status/kernelzilla/rcraid-dkms/release.yml?job=vagrant-el9&style=flat-square&logo=redhat&logoColor=white&label=vagrant"/> <img src="https://img.shields.io/github/actions/workflow/status/kernelzilla/rcraid-dkms/rcraid-dkms-ci.yml?job=rcraid-dkms_rpm_almalinux%3A9&style=flat-square&logo=redhat&logoColor=white&label=container"/> |
| **openSUSE Leap 15.6** (kernel 6.4) | <img src="https://img.shields.io/github/actions/workflow/status/kernelzilla/rcraid-dkms/release.yml?job=vagrant-opensuse15&style=flat-square&logo=opensuse&logoColor=white&label=vagrant"/> <img src="https://img.shields.io/github/actions/workflow/status/kernelzilla/rcraid-dkms/rcraid-dkms-ci.yml?job=rcraid-dkms_rpm_opensuse%2Fleap%3A15.6&style=flat-square&logo=opensuse&logoColor=white&label=container"/> |
| **Ubuntu 22.04** (kernel 5.15) | <img src="https://img.shields.io/github/actions/workflow/status/kernelzilla/rcraid-dkms/rcraid-dkms-ci.yml?job=rcraid-dkms_ubuntu-22.04&style=flat-square&logo=ubuntu&logoColor=white&label=build"/> |
| **Ubuntu 24.04** (kernel 6.8) | <img src="https://img.shields.io/github/actions/workflow/status/kernelzilla/rcraid-dkms/rcraid-dkms-ci.yml?job=rcraid-dkms_ubuntu-24.04&style=flat-square&logo=ubuntu&logoColor=white&label=build"/> |
| **Ubuntu + xanmod** (kernel 7.2) | <img src="https://img.shields.io/github/actions/workflow/status/kernelzilla/rcraid-dkms/release.yml?job=vagrant-ubuntu-xanmod&style=flat-square&logo=ubuntu&logoColor=white&label=vagrant"/> |
| **Debian 13** (vanilla, all stable+LTS) | <img src="https://img.shields.io/github/actions/workflow/status/kernelzilla/rcraid-dkms/release.yml?job=vagrant-debian-vanilla&style=flat-square&logo=debian&logoColor=white&label=vagrant"/> |
| **Ubuntu 24.04** (vanilla, all stable+LTS) | <img src="https://img.shields.io/github/actions/workflow/status/kernelzilla/rcraid-dkms/release.yml?job=vagrant-ubuntu2404-vanilla&style=flat-square&logo=ubuntu&logoColor=white&label=vagrant"/> |
| **Ubuntu 22.04** (vanilla, all stable+LTS) | <img src="https://img.shields.io/github/actions/workflow/status/kernelzilla/rcraid-dkms/release.yml?job=vagrant-ubuntu2204-vanilla&style=flat-square&logo=ubuntu&logoColor=white&label=vagrant"/> |
| **Debian** (.deb package) | <img src="https://img.shields.io/github/actions/workflow/status/kernelzilla/rcraid-dkms/release.yml?job=pkg-debian&style=flat-square&logo=debian&logoColor=white&label=package"/> |
| **Arch** (.pkg.tar.zst) | <img src="https://img.shields.io/github/actions/workflow/status/kernelzilla/rcraid-dkms/release.yml?job=pkg-arch&style=flat-square&logo=archlinux&logoColor=white&label=package"/> |
| **Release** (tag → GitHub release) | <img src="https://img.shields.io/github/actions/workflow/status/kernelzilla/rcraid-dkms/release.yml?job=github-release&style=flat-square&logo=github&logoColor=white&label=release"/> |

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
| 6.18.x | Ubuntu + xanmod (clang)   | builds               |
| 7.2.x  | Ubuntu + xanmod x64v3 (clang/lld) | builds, loads, DKMS |
| 7.2.11 | Debian 13, vanilla ([kernel-deb](https://github.com/ToeiRei/kernel-deb)) | builds, loads, DKMS |
| 5.10 – 7.2 | Debian 13 / Ubuntu 22.04+24.04, all kernel.org stable+longterm series | DKMS-built in CI |

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
| `rcraid-ubuntu-xanmod` | `alvistack/ubuntu-24.04` | 7.2 (xanmod x64v3) |
| `rcraid-debian-vanilla` | `debian/trixie64` | 7.2.11 + all series |
| `rcraid-ubuntu2404-vanilla` | `alvistack/ubuntu-24.04` | 7.2.11 + all series |
| `rcraid-ubuntu2204-vanilla` | `alvistack/ubuntu-22.04` | 7.2.11 + all series |

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
the dkms state, module file, `modinfo`, and clean package removal. The
built artifacts are pulled to `dist/` *before* the destructive part:
`vagrant/load-test.sh` (run via `vagrant ssh`, or by CI) reinstalls the
package and inserts the module — on machines without RAID hardware the
driver's PCI probing can disturb the virtio NIC, so the load test
deliberately runs last; its result is logged to the VM console
(readable via `virsh screenshot <domain>`) and `/root/rcraid-smoke.rc`.

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
  git clone https://github.com/kernelzilla/rcraid-dkms.git
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

Known hardware
==============
The mainboards below use the AMD X370, X399, X470 and X570 chipsets that
carry the Promontory RAID option ROM / RAIDXpert2 firmware this driver
talks to. Boards based on the refreshed, fanless **X570S** spin of the
X570 chipset are listed as well and tagged accordingly. Links point to
the official vendor product pages.

### X370 (Socket AM4)

* ASUS
  * [ROG CROSSHAIR VI EXTREME](https://rog.asus.com/motherboards/rog-crosshair/rog-crosshair-vi-extreme-model/)
  * [ROG CROSSHAIR VI HERO](https://rog.asus.com/motherboards/rog-crosshair/rog-crosshair-vi-hero-model/)
  * [ROG CROSSHAIR VI HERO (WI-FI AC)](https://rog.asus.com/motherboards/rog-crosshair/rog-crosshair-vi-hero-wi-fi-ac-model/)
  * [ROG STRIX X370-F GAMING](https://rog.asus.com/motherboards/rog-strix/rog-strix-x370-f-gaming-model/)
  * [ROG STRIX X370-I GAMING](https://rog.asus.com/motherboards/rog-strix/rog-strix-x370-i-gaming-model/)
  * [PRIME X370-PRO](https://www.asus.com/Motherboards/PRIME-X370-PRO/)
  * [PRIME X370-A](https://www.asus.com/Motherboards/PRIME-X370-A/)
* MSI
  * [X370 XPOWER GAMING TITANIUM](https://www.msi.com/Motherboard/X370-XPOWER-GAMING-TITANIUM)
  * [X370 GAMING M7 ACK](https://www.msi.com/Motherboard/X370-GAMING-M7-ACK)
  * [X370 GAMING PRO CARBON](https://www.msi.com/Motherboard/X370-GAMING-PRO-CARBON)
  * [X370 GAMING PRO CARBON AC](https://www.msi.com/Motherboard/X370-GAMING-PRO-CARBON-AC)
  * [X370 GAMING PRO](https://www.msi.com/Motherboard/X370-GAMING-PRO)
  * [X370 GAMING PLUS](https://www.msi.com/Motherboard/X370-GAMING-PLUS)
  * [X370 KRAIT GAMING](https://www.msi.com/Motherboard/X370-KRAIT-GAMING)
  * [X370 SLI PLUS](https://www.msi.com/Motherboard/X370-SLI-PLUS)
* GIGABYTE
  * [GA-AX370-Gaming K7](https://www.gigabyte.com/Motherboard/GA-AX370-Gaming-K7-rev-10)
  * [GA-AX370-Gaming K5](https://www.gigabyte.com/Motherboard/GA-AX370-Gaming-K5-rev-1x)
  * [GA-AX370-Gaming 5](https://www.gigabyte.com/Motherboard/GA-AX370-Gaming-5-rev-10)
  * [GA-AX370-Gaming K3](https://www.gigabyte.com/Motherboard/GA-AX370-Gaming-K3-rev-10)
  * [GA-AX370-Gaming 3](https://www.gigabyte.com/Motherboard/GA-AX370-Gaming-3-rev-1x)
  * [GA-AX370-Gaming](https://www.gigabyte.com/Motherboard/GA-AX370-Gaming-rev-1x)
  * [GA-AX370M-Gaming 3](https://www.gigabyte.com/Motherboard/GA-AX370M-Gaming-3-rev-1x)
  * [GA-AX370M-DS3H](https://www.gigabyte.com/Motherboard/GA-AX370M-DS3H-rev-1x)
* ASRock
  * [Fatal1ty X370 Professional Gaming](https://www.asrock.com/mb/AMD/Fatal1ty%20X370%20Professional%20Gaming/index.asp)
  * [X370 Taichi](https://www.asrock.com/mb/AMD/X370%20Taichi/index.asp)
  * [Fatal1ty X370 Gaming K4](https://www.asrock.com/mb/AMD/Fatal1ty%20X370%20Gaming%20K4/index.asp)
  * [Fatal1ty X370 Gaming-ITX/ac](https://www.asrock.com/mb/AMD/Fatal1ty%20X370%20Gaming-ITXac/index.asp)
  * [X370 Killer SLI](https://www.asrock.com/mb/AMD/X370%20Killer%20SLI/index.asp)
  * [X370 Killer SLI/ac](https://www.asrock.com/mb/AMD/X370%20Killer%20SLIac/index.asp)
  * [X370 Pro4](https://www.asrock.com/mb/AMD/X370%20Pro4/index.asp)
* BIOSTAR
  * [RACING X370GT7](https://www.biostar.com.tw/app/en/mb/introduction.php?S_ID=874)
  * [RACING X370GT5](https://www.biostar.com.tw/app/en/mb/introduction.php?S_ID=873)
  * [RACING X370GT3](https://www.biostar.com.tw/app/en/mb/introduction.php?S_ID=871)
  * [RACING X370GTN](https://www.biostar.com.tw/app/en/mb/introduction.php?S_ID=879)

### X399 (Socket TR4, Ryzen Threadripper)

* ASUS
  * [ROG ZENITH EXTREME](https://rog.asus.com/motherboards/rog-zenith/rog-zenith-extreme-model/)
  * [ROG ZENITH EXTREME ALPHA](https://rog.asus.com/motherboards/rog-zenith/rog-zenith-extreme-alpha-model/)
  * [ROG STRIX X399-E GAMING](https://rog.asus.com/motherboards/rog-strix/rog-strix-x399-e-gaming-model/)
  * [PRIME X399-A](https://www.asus.com/Motherboards/PRIME-X399-A/)
* MSI
  * [MEG X399 CREATION](https://www.msi.com/Motherboard/MEG-X399-CREATION)
  * [X399 GAMING PRO CARBON AC](https://www.msi.com/Motherboard/X399-GAMING-PRO-CARBON-AC)
  * [X399 SLI PLUS](https://www.msi.com/Motherboard/X399-SLI-PLUS)
* GIGABYTE
  * [X399 AORUS XTREME](https://www.gigabyte.com/Motherboard/X399-AORUS-XTREME-rev-10)
  * [X399 AORUS GAMING 7](https://www.gigabyte.com/Motherboard/X399-AORUS-Gaming-7-rev-10)
  * [X399 AORUS PRO](https://www.gigabyte.com/Motherboard/X399-AORUS-PRO-rev-10)
  * [X399 DESIGNARE EX](https://www.gigabyte.com/Motherboard/X399-DESIGNARE-EX-rev-10)
* ASRock
  * [Fatal1ty X399 Professional Gaming](https://www.asrock.com/mb/AMD/Fatal1ty%20X399%20Professional%20Gaming/index.asp)
  * [X399 Taichi](https://www.asrock.com/mb/AMD/X399%20Taichi/index.asp)
  * [X399M Taichi](https://www.asrock.com/mb/AMD/X399M%20Taichi/index.asp)
  * [X399 Phantom Gaming 6](https://www.asrock.com/mb/AMD/X399%20Phantom%20Gaming%206/index.asp)

### X470 (Socket AM4)

* ASUS
  * [ROG CROSSHAIR VII HERO](https://rog.asus.com/motherboards/rog-crosshair/rog-crosshair-vii-hero-model/)
  * [ROG CROSSHAIR VII HERO (WI-FI)](https://rog.asus.com/motherboards/rog-crosshair/rog-crosshair-vii-hero-wi-fi-model/)
  * [ROG STRIX X470-F GAMING](https://rog.asus.com/motherboards/rog-strix/rog-strix-x470-f-gaming-model/)
  * [ROG STRIX X470-I GAMING](https://rog.asus.com/motherboards/rog-strix/rog-strix-x470-i-gaming-model/)
  * [PRIME X470-PRO](https://www.asus.com/Motherboards/PRIME-X470-PRO/)
  * [TUF X470-PLUS GAMING](https://www.asus.com/Motherboards/TUF-X470-PLUS-GAMING/)
* MSI
  * [X470 GAMING M7 AC](https://www.msi.com/Motherboard/X470-GAMING-M7-AC)
  * [X470 GAMING PRO CARBON](https://www.msi.com/Motherboard/X470-GAMING-PRO-CARBON)
  * [X470 GAMING PRO CARBON AC](https://www.msi.com/Motherboard/X470-GAMING-PRO-CARBON-AC)
  * [X470 GAMING PRO](https://www.msi.com/Motherboard/X470-GAMING-PRO)
  * [X470 GAMING PRO MAX](https://www.msi.com/Motherboard/X470-GAMING-PRO-MAX)
  * [X470 GAMING PLUS](https://www.msi.com/Motherboard/X470-GAMING-PLUS)
  * [X470 GAMING PLUS MAX](https://www.msi.com/Motherboard/X470-GAMING-PLUS-MAX)
* GIGABYTE
  * [X470 AORUS GAMING 7 WIFI](https://www.gigabyte.com/Motherboard/X470-AORUS-GAMING-7-WIFI-rev-10)
  * [X470 AORUS GAMING 7 WIFI-50](https://www.gigabyte.com/Motherboard/X470-AORUS-GAMING-7-WIFI-50-rev-11)
  * [X470 AORUS GAMING 5 WIFI](https://www.gigabyte.com/Motherboard/X470-AORUS-GAMING-5-WIFI-rev-10)
  * [X470 AORUS ULTRA GAMING](https://www.gigabyte.com/Motherboard/X470-AORUS-ULTRA-GAMING-rev-10)
* ASRock
  * [X470 Taichi Ultimate](https://www.asrock.com/mb/AMD/X470%20Taichi%20Ultimate/index.asp)
  * [X470 Taichi](https://www.asrock.com/mb/AMD/X470%20Taichi/index.asp)
  * [Fatal1ty X470 Gaming K4](https://www.asrock.com/mb/AMD/Fatal1ty%20X470%20Gaming%20K4/index.asp)
  * [Fatal1ty X470 Gaming-ITX/ac](https://www.asrock.com/mb/AMD/Fatal1ty%20X470%20Gaming-ITXac/index.asp)
  * [X470 Master SLI](https://www.asrock.com/mb/AMD/X470%20Master%20SLI/index.asp)
  * [X470 Master SLI/ac](https://www.asrock.com/mb/AMD/X470%20Master%20SLIac/index.asp)
  * [X470 Pro4](https://www.asrock.com/mb/AMD/X470%20Pro4/index.asp)
* BIOSTAR
  * [RACING X470GT8](https://www.biostar.com.tw/app/en/mb/introduction.php?S_ID=909)
  * [RACING X470GTN](https://www.biostar.com.tw/app/en/mb/introduction.php?S_ID=910)
  * [RACING X470GTA](https://www.biostar.com.tw/app/en/mb/introduction.php?S_ID=955)
  * [RACING X470GTQ](https://www.biostar.com.tw/app/en/mb/introduction.php?S_ID=956)
  * [X470MH](https://www.biostar.com.tw/app/en/mb/introduction.php?S_ID=960)
  * [X470NH](https://www.biostar.com.tw/app/en/mb/introduction.php?S_ID=962)

### X570 (Socket AM4)

* ASUS
  * [ROG CROSSHAIR VIII FORMULA](https://rog.asus.com/motherboards/rog-crosshair/rog-crosshair-viii-formula-model/)
  * [ROG CROSSHAIR VIII HERO](https://rog.asus.com/motherboards/rog-crosshair/rog-crosshair-viii-hero-model/)
  * [ROG CROSSHAIR VIII HERO (WI-FI)](https://rog.asus.com/motherboards/rog-crosshair/rog-crosshair-viii-hero-wi-fi-model/)
  * [ROG CROSSHAIR VIII DARK HERO](https://rog.asus.com/motherboards/rog-crosshair/rog-crosshair-viii-dark-hero-model/)
  * [ROG CROSSHAIR VIII IMPACT](https://rog.asus.com/motherboards/rog-crosshair/rog-crosshair-viii-impact-model/)
  * [ROG CROSSHAIR VIII EXTREME](https://rog.asus.com/motherboards/rog-crosshair/rog-crosshair-viii-extreme-model/) *(X570S)*
  * [ROG STRIX X570-E GAMING](https://rog.asus.com/motherboards/rog-strix/rog-strix-x570-e-gaming-model/)
  * [ROG STRIX X570-E GAMING WIFI II](https://rog.asus.com/motherboards/rog-strix/rog-strix-x570-e-gaming-wifi-ii-model/) *(X570S)*
  * [ROG STRIX X570-F GAMING](https://rog.asus.com/motherboards/rog-strix/rog-strix-x570-f-gaming-model/)
  * [ROG STRIX X570-I GAMING](https://rog.asus.com/motherboards/rog-strix/rog-strix-x570-i-gaming-model/)
  * [ProArt X570-CREATOR WIFI](https://www.asus.com/motherboards-components/motherboards/proart/proart-x570-creator-wifi/)
  * [Pro WS X570-ACE](https://www.asus.com/Motherboards/Pro-WS-X570-ACE/)
  * [PRIME X570-PRO](https://www.asus.com/Motherboards/PRIME-X570-PRO/)
  * [PRIME X570-P](https://www.asus.com/Motherboards/PRIME-X570-P/)
  * [TUF GAMING X570-PLUS](https://www.asus.com/Motherboards/TUF-GAMING-X570-PLUS/)
  * [TUF GAMING X570-PLUS (WI-FI)](https://www.asus.com/Motherboards/TUF-GAMING-X570-PLUS-WI-FI/)
  * [TUF GAMING X570-PRO (WI-FI)](https://www.asus.com/motherboards-components/motherboards/tuf-gaming/tuf-gaming-x570-pro-wi-fi/) *(X570S)*
* MSI
  * [MEG X570 GODLIKE](https://www.msi.com/Motherboard/MEG-X570-GODLIKE)
  * [MEG X570 ACE](https://www.msi.com/Motherboard/MEG-X570-ACE)
  * [MEG X570 UNIFY](https://www.msi.com/Motherboard/MEG-X570-UNIFY)
  * [PRESTIGE X570 CREATION](https://www.msi.com/Motherboard/PRESTIGE-X570-CREATION)
  * [MPG X570 GAMING PRO CARBON WIFI](https://www.msi.com/Motherboard/MPG-X570-GAMING-PRO-CARBON-WIFI)
  * [MPG X570 GAMING EDGE WIFI](https://www.msi.com/Motherboard/MPG-X570-GAMING-EDGE-WIFI)
  * [MPG X570 GAMING PLUS](https://www.msi.com/Motherboard/MPG-X570-GAMING-PLUS)
  * [MAG X570 TOMAHAWK WIFI](https://www.msi.com/Motherboard/MAG-X570-TOMAHAWK-WIFI)
  * [X570-A PRO](https://www.msi.com/Motherboard/X570-A-PRO)
  * [MEG X570S ACE MAX](https://www.msi.com/Motherboard/MEG-X570S-ACE-MAX) *(X570S)*
  * [MEG X570S UNIFY-X MAX](https://www.msi.com/Motherboard/MEG-X570S-UNIFY-X-MAX) *(X570S)*
  * [MPG X570S CARBON MAX WIFI](https://www.msi.com/Motherboard/MPG-X570S-CARBON-MAX-WIFI) *(X570S)*
  * [MPG X570S CARBON EK X](https://www.msi.com/Motherboard/MPG-X570S-CARBON-EK-X) *(X570S)*
  * [MAG X570S TOMAHAWK MAX WIFI](https://www.msi.com/Motherboard/MAG-X570S-TOMAHAWK-MAX-WIFI) *(X570S)*
  * [MAG X570S TORPEDO MAX](https://www.msi.com/Motherboard/MAG-X570S-TORPEDO-MAX) *(X570S)*
* GIGABYTE
  * [X570 AORUS XTREME](https://www.gigabyte.com/Motherboard/X570-AORUS-XTREME-rev-12)
  * [X570 AORUS MASTER](https://www.gigabyte.com/Motherboard/X570-AORUS-MASTER-rev-11-12)
  * [X570 AORUS ULTRA](https://www.gigabyte.com/Motherboard/X570-AORUS-ULTRA-rev-11-12)
  * [X570 AORUS PRO](https://www.gigabyte.com/Motherboard/X570-AORUS-PRO-rev-11-12)
  * [X570 AORUS PRO WIFI](https://www.gigabyte.com/Motherboard/X570-AORUS-PRO-WIFI-rev-11-12)
  * [X570 AORUS ELITE](https://www.gigabyte.com/Motherboard/X570-AORUS-ELITE-rev-10)
  * [X570 AORUS ELITE WIFI](https://www.gigabyte.com/Motherboard/X570-AORUS-ELITE-WIFI-rev-1x)
  * [X570 I AORUS PRO WIFI](https://www.gigabyte.com/Motherboard/X570-I-AORUS-PRO-WIFI-rev-10)
  * [X570 GAMING X](https://www.gigabyte.com/Motherboard/X570-GAMING-X-rev-11)
  * [X570 UD](https://www.gigabyte.com/Motherboard/X570-UD-rev-11)
  * [X570S AORUS MASTER](https://www.gigabyte.com/Motherboard/X570S-AORUS-MASTER-rev-10) *(X570S)*
  * [X570S AORUS PRO AX](https://www.gigabyte.com/Motherboard/X570S-AORUS-PRO-AX-rev-11) *(X570S)*
  * [X570S AORUS ELITE AX](https://www.gigabyte.com/Motherboard/X570S-AORUS-ELITE-AX-rev-10) *(X570S)*
  * [X570S AORUS ELITE](https://www.gigabyte.com/Motherboard/X570S-AORUS-ELITE-rev-10) *(X570S)*
  * [X570SI AORUS PRO AX](https://www.gigabyte.com/Motherboard/X570SI-AORUS-PRO-AX-rev-11) *(X570S)*
  * [X570S AERO G](https://www.gigabyte.com/Motherboard/X570S-AERO-G-rev-10) *(X570S)*
  * [X570S GAMING X](https://www.gigabyte.com/Motherboard/X570S-GAMING-X-rev-10) *(X570S)*
  * [X570S UD](https://www.gigabyte.com/Motherboard/X570S-UD-rev-10) *(X570S)*
* ASRock
  * [X570 AQUA](https://www.asrock.com/mb/AMD/X570%20AQUA/index.asp)
  * [X570 Creator](https://www.asrock.com/mb/AMD/X570%20Creator/index.asp)
  * [X570 Taichi](https://www.asrock.com/mb/AMD/X570%20Taichi/index.asp)
  * [X570 Taichi Razer Edition](https://www.asrock.com/mb/AMD/X570%20Taichi%20Razer%20Edition/index.asp)
  * [X570 Phantom Gaming X](https://www.asrock.com/mb/AMD/X570%20Phantom%20Gaming%20X/index.asp)
  * [X570 PG Velocita](https://www.asrock.com/mb/AMD/X570%20PG%20Velocita/index.asp)
  * [X570 Phantom Gaming-ITX/TB3](https://www.asrock.com/mb/AMD/X570%20Phantom%20Gaming-ITXTB3/index.asp)
  * [X570 Phantom Gaming 4](https://www.asrock.com/mb/AMD/X570%20Phantom%20Gaming%204/index.asp)
  * [X570 Phantom Gaming 4 WiFi ax](https://www.asrock.com/mb/AMD/X570%20Phantom%20Gaming%204%20WiFi%20ax/index.asp)
  * [X570 Phantom Gaming 4S](https://www.asrock.com/mb/AMD/X570%20Phantom%20Gaming%204S/index.asp)
  * [X570 Extreme4](https://www.asrock.com/mb/AMD/X570%20Extreme4/index.asp)
  * [X570 Extreme4 WiFi ax](https://www.asrock.com/mb/AMD/X570%20Extreme4%20WiFi%20ax/index.asp)
  * [X570 Steel Legend](https://www.asrock.com/mb/AMD/X570%20Steel%20Legend/index.asp)
  * [X570 Steel Legend WiFi ax](https://www.asrock.com/mb/AMD/X570%20Steel%20Legend%20WiFi%20ax/index.asp)
  * [X570 Pro4](https://www.asrock.com/mb/AMD/X570%20Pro4/index.asp)
  * [X570M Pro4](https://www.asrock.com/mb/AMD/X570M%20Pro4/index.asp)
  * [X570S PG Riptide](https://www.asrock.com/mb/AMD/X570S%20PG%20Riptide/index.asp) *(X570S)*
* EVGA
  * [X570 DARK](https://www.evga.com/products/product.aspx?pn=121-VR-A579-KR) *(X570S)*
* BIOSTAR
  * [RACING X570GT8](https://www.biostar.com.tw/app/en/mb/introduction.php?S_ID=952)
  * [RACING X570GTA](https://www.biostar.com.tw/app/en/mb/introduction.php?S_ID=963)
  * [RACING X570GT](https://www.biostar.com.tw/app/en/mb/introduction.php?S_ID=957)
* Colorful
  * [CVN X570 GAMING PRO V14](https://www.colorful.cn/home/product?id=787&mid=84)

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
