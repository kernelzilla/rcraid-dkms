# Convenience targets for the rcraid-dkms RPM packaging + Vagrant tests.
#
#   make tarball            build rpm source tarball into dist/
#   make vagrant-test       vagrant up + verify on all three distros
#   make vagrant-test-el9   same, one VM (also: -el8 / -opensuse15)
#   make collect            pull built RPMs out of all running VMs
#   make destroy            vagrant destroy all test VMs

VMS := rcraid-el8 rcraid-el9 rcraid-opensuse15 rcraid-ubuntu-xanmod rcraid-debian-vanilla72

.PHONY: tarball vagrant-test collect destroy $(VMS:%=vagrant-test-%)

tarball:
	bash rpm/mksources.sh dist

vagrant-test:
	bash vagrant/test-all.sh

$(VMS:%=vagrant-test-%):
	vagrant up $(@:vagrant-test-%=rcraid-%) --provider=libvirt
	bash vagrant/pull-artifacts.sh $(@:vagrant-test-%=rcraid-%)

collect:
	@for vm in $(VMS); do bash vagrant/pull-artifacts.sh $$vm || true; done

destroy:
	@for vm in $(VMS); do vagrant destroy -f $$vm || true; done
