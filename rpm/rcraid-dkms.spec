# RPM spec for the AMD RAIDXpert2 (rcraid) driver, packaged as a DKMS module.
#
# Works on RHEL-family distros (EL8, EL9, ...) and openSUSE Leap 15 / SLES 15.
# The package only ships module sources; the kernel object is built on the
# target machine by DKMS via the %post scriptlet below.
#
# Layout of the source tarball (rcraid-dkms-<version>.tar.gz):
#   rcraid-dkms-<version>/dkms.conf     - template, @DKMS_VERSION@ substituted
#   rcraid-dkms-<version>/Makefile      - kernel module makefile
#   rcraid-dkms-<version>/*.c, *.h      - driver sources
#   rcraid-dkms-<version>/rcblob.x86_64 - AMD firmware object
#   rcraid-dkms-<version>/LICENSE_SDK   - AMD SDK license
#
# Build with:  rpmbuild -ba rpm/rcraid-dkms.spec   (or via vagrant/build-test.sh)

%global module      rcraid
# Registering the module as <version>-<release> makes a package upgrade
# reinstall+rebuild the module even when the upstream version is unchanged.
%global dkmsver     %{version}-%{release}
%global dkmsdir     %{_usrsrc}/%{module}-%{dkmsver}
# No debuginfo subpackage: the only ELF in the payload is the prebuilt
# rcblob object, which has no build-id and would fail find-debuginfo.
%global debug_package %{nil}

Name:           %{module}-dkms
Version:        9.3.2
Release:        1%{?dist}
Summary:        AMD RAIDXpert2 NVMe/SATA RAID driver (DKMS)
License:        LicenseRef-Proprietary
Group:          System/Kernel
URL:            https://github.com/thopiekar/rcraid-dkms
Source0:        %{name}-%{version}.tar.gz

# The payload is x86_64-only (prebuilt firmware object), so the package is
# archful even though it only ships sources.
ExclusiveArch:  x86_64

Requires:       dkms
Requires:       gcc
Requires:       make
Requires:       kmod
%if 0%{?suse_version}
# openSUSE Leap / SLES: kernel-default-devel provides the kernel-default
# build tree (/usr/src/linux-obj/...). dkms is in the SLE backports repo.
Requires:       kernel-default-devel
%else
Requires:       kernel-devel
%endif
Requires(post):   dkms
Requires(preun):  dkms

%description
Kernel driver for the AMD RAIDXpert2 (Promontory) SATA/NVMe RAID
controller found on AM4/TR4/sTRX4 chipset motherboards (X370, X399,
X470, X570, TRX40, WRX80).

This package installs the driver sources under /usr/src and lets DKMS
build, install and rebuild the rcraid.ko module for the running kernel
and for every subsequently installed kernel.

A dracut configuration snippet (/etc/dracut.conf.d/rcraid.conf) makes
sure rcraid is included in newly generated initramfs images, which is
required to boot from an rcraid array.

%prep
%setup -q -n %{name}-%{version}

%build
# Nothing to compile at package build time; DKMS builds the module on
# the target system.

%install
%{__install} -d %{buildroot}%{dkmsdir}
%{__install} -d %{buildroot}%{_sysconfdir}/dracut.conf.d
%{__install} -d %{buildroot}%{_defaultlicensedir}/%{name}
cp -a * %{buildroot}%{dkmsdir}/
%{__install} -m 644 LICENSE_SDK %{buildroot}%{_defaultlicensedir}/%{name}/LICENSE_SDK
sed -e 's/@DKMS_VERSION@/%{dkmsver}/g' \
    %{buildroot}%{dkmsdir}/dkms.conf > %{buildroot}%{dkmsdir}/dkms.conf.new
mv %{buildroot}%{dkmsdir}/dkms.conf.new %{buildroot}%{dkmsdir}/dkms.conf
cat > %{buildroot}%{_sysconfdir}/dracut.conf.d/%{module}.conf <<'EOF'
# Pull the rcraid RAID driver into every generated initramfs so that the
# system can boot from a RAIDCore/RAIDXpert2 array.
add_drivers+=" rcraid "
EOF

%files
%{dkmsdir}/
%license %{_defaultlicensedir}/%{name}/LICENSE_SDK
%config(noreplace) %{_sysconfdir}/dracut.conf.d/%{module}.conf

%post
# Register, build and install the module for the running kernel.
# --rpm_safe_upgrade protects the module during package upgrades.
dkms add     -m %{module} -v %{dkmsver} --rpm_safe_upgrade
dkms build   -m %{module} -v %{dkmsver} --rpm_safe_upgrade
dkms install -m %{module} -v %{dkmsver} --rpm_safe_upgrade --force
# Refresh the current initramfs so the driver is available at boot.
if command -v dracut >/dev/null 2>&1; then
    dracut -f --kver "$(uname -r)" || \
        echo "warning: dracut failed; regenerate the initramfs manually" >&2
fi
exit 0

%preun
# Remove the module from all kernels. On package upgrades the
# rpm_safe_upgrade lock left by the new package's %post turns this into
# a no-op.
dkms remove -m %{module} -v %{dkmsver} --all --rpm_safe_upgrade || :
exit 0

%changelog
* Fri Oct 16 2026 rcraid-dkms maintainers
- 9.3.2-1
- Initial unified EL/SUSE DKMS spec (EL8, EL9, openSUSE Leap 15).
