#!/bin/bash

set -e

info() {
	echo
	echo "============================================================="
	echo "==="
	echo "=== $*"
	echo "==="
	echo
}

export PACMAN_VERSION=5.1.1

info "Installing required packages"
apt update
apt install -y pkg-config libssl-dev libarchive-dev curl wget build-essential m4 psmisc

info "Compiling arch-install-scripts and pacman"
rm -rf work
mkdir work
mkdir work/rootfs
(cd work && curl -s https://git.archlinux.org/arch-install-scripts.git/snapshot/arch-install-scripts-18.tar.gz | tar xfvz -)
(cd work/arch-install-scripts-18 && make && make install)
if [ ! -f /bin/pacman ]; then
  (cd work && curl -s https://sources.archlinux.org/other/pacman/pacman-${PACMAN_VERSION}.tar.gz | tar xfvz -)
  (cd work/pacman-${PACMAN_VERSION} && ./configure --prefix=/)
  (cd work/pacman-${PACMAN_VERSION} && make && make install)
  (cd work/pacman-${PACMAN_VERSION}/src/pacman && make && make install)
fi

info "Installing arch base system to work/rootfs"

cp pacman.conf /etc/pacman.conf
mkdir -p /etc/pacman.d/
echo 'Server = http://mirrors.kernel.org/archlinux/$repo/os/$arch' > /etc/pacman.d/mirrorlist

pacstrap -c work/rootfs pacman \
  filesystem systemd-sysvcompat bash bzip2 coreutils \
  diffutils file findutils gawk gcc-libs gettext glibc \
  grep gzip inetutils iproute2 less licenses logrotate \
  netctl pacman procps-ng psmisc s-nail sed shadow \
  sysfsutils tar util-linux which \
  sudo openssh ca-certificates curl wget \
  python-simplejson git base-devel \
  pacutils perl perl-libwww perl-term-ui perl-json \
  perl-data-dump perl-lwp-protocol-https perl-term-readline-gnu \
  perl-json-xs

info "Configuring base system for vagrant-lxc usage"

mount -o bind /dev work/rootfs/dev
mount -t proc none work/rootfs/proc
chroot work/rootfs pacman-key --init
chroot work/rootfs pacman-key --populate archlinux
killall -9 dirmngr gpg-agent || true

chroot work/rootfs useradd -u 2000 -m vagrant
chroot work/rootfs systemctl enable sshd
chroot work/rootfs trust extract-compat

cp pacman-init.service work/rootfs/usr/lib/systemd/system/pacman-init.service
cp systemd-firstboot.service work/rootfs/usr/lib/systemd/system/systemd-firstboot.service
cp rc-local.service work/rootfs/usr/lib/systemd/system/rc-local.service
cp rc.local work/rootfs/etc/rc.local

chmod 0755 \
  work/rootfs/usr/lib/systemd/system/pacman-init.service \
  work/rootfs/usr/lib/systemd/system/systemd-firstboot.service \
  work/rootfs/usr/lib/systemd/system/rc-local.service \
  work/rootfs/etc/rc.local

chroot work/rootfs systemctl enable pacman-init
chroot work/rootfs systemctl enable pacman-init
chroot work/rootfs systemctl enable rc-local


mkdir -p work/rootfs/home/vagrant/.ssh
echo "ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA6NF8iallvQVp22WDkTkyrtvp9eWW6A8YVr+kz4TjGYe7gHzIw+niNltGEFHzD8+v1I2YJ6oXevct1YeS0o9HZyN1Q9qgCgzUFtdOKLv6IedplqoPkcmF0aYet2PkEDo3MlTBckFXPITAMzF8dJSIFo9D8HfdOV0IAdx4O7PtixWKn5y2hMNG0zQPyUecp4pzC6kivAIhyfHilFR61RGL+GPXQ2MWZWFYbAGjyiYJnAmCP3NOTd0jMZEnDkbUvxhMmBYSdETk1rRgm+R4LOzFUGaHqHDLKLX+FIPKcF96hrucXzcWyLbIbEgE98OHlnVYCzRdK8jlqm8tehUc9c9WhQ== vagrant insecure public key" \
  > work/rootfs/home/vagrant/.ssh/authorized_keys
echo "vagrant ALL=(ALL) NOPASSWD:ALL" > work/rootfs/etc/sudoers.d/vagrant
echo "nameserver 8.8.8.8" > work/rootfs/etc/resolv.conf
echo -e "127.0.0.1  localhost\n 127.0.1.1  vagrant-lxc-archlinux" > work/rootfs/etc/hosts
echo "vagrant-lxc-archlinux" > work/rootfs/etc/hostname

chown 2000.2000 work/rootfs/home/vagrant -R

sed -i 's/CheckSpace/#CheckSpace/' work/rootfs/etc/pacman.conf
chroot work/rootfs su vagrant -c "git clone https://aur.archlinux.org/trizen.git /tmp/trizen"
chroot work/rootfs su vagrant -c "cd /tmp/trizen && makepkg -si --noconfirm"
sed -i 's/#CheckSpace/CheckSpace/' work/rootfs/etc/pacman.conf


sleep 1
umount work/rootfs/dev
umount work/rootfs/proc

rm -rf work/rootfs/var/cache/pacman/pkg/*
rm -rf work/rootfs/etc/pacman.d/gnupg
rm -rf work/rootfs/etc/machine-id
rm -rf work/rootfs/tmp/*

info "Packing rootfs"

tar --numeric-owner -czf work/rootfs.tar.gz -C work ./rootfs

cat << EOF >  work/metadata.json
{
	"provider": "lxc",
	"version":  "1.0.0"
}
EOF

cp lxc-config work/lxc-config

info "Packing box"

tar -czf work/archlinux.box -C work rootfs.tar.gz lxc-config metadata.json

info "Done."
