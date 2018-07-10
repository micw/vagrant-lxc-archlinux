#!/bin/bash

rm -rf work
mkdir work
mkdir work/rootfs
(cd work && curl -s https://git.archlinux.org/arch-install-scripts.git/snapshot/arch-install-scripts-18.tar.gz | tar xfvz -)
(cd work/arch-install-scripts-18 && make)
work/arch-install-scripts-18/pacstrap work/rootfs \
  filesystem systemd-sysvcompat bash bzip2 coreutils \
  diffutils file findutils gawk gcc-libs gettext glibc \
  grep gzip inetutils iproute2 less licenses logrotate \
  netctl pacman procps-ng psmisc s-nail sed shadow \
  sysfsutils tar util-linux which \
  sudo openssh ca-certificates curl wget

chroot work/rootfs useradd -m vagrant
chroot work/rootfs systemctl enable sshd

mkdir -p work/rootfs/home/vagrant/.ssh
echo "ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA6NF8iallvQVp22WDkTkyrtvp9eWW6A8YVr+kz4TjGYe7gHzIw+niNltGEFHzD8+v1I2YJ6oXevct1YeS0o9HZyN1Q9qgCgzUFtdOKLv6IedplqoPkcmF0aYet2PkEDo3MlTBckFXPITAMzF8dJSIFo9D8HfdOV0IAdx4O7PtixWKn5y2hMNG0zQPyUecp4pzC6kivAIhyfHilFR61RGL+GPXQ2MWZWFYbAGjyiYJnAmCP3NOTd0jMZEnDkbUvxhMmBYSdETk1rRgm+R4LOzFUGaHqHDLKLX+FIPKcF96hrucXzcWyLbIbEgE98OHlnVYCzRdK8jlqm8tehUc9c9WhQ== vagrant insecure public key" \
  > work/rootfs/home/vagrant/.ssh/authorized_keys
echo "vagrant ALL=(ALL) NOPASSWD:ALL" > work/rootfs/etc/sudoers.d/vagrant
echo "nameserver 8.8.8.8" > work/rootfs/etc/resolv.conf
echo -e "127.0.0.1  localhost\n 127.0.1.1  vagrant-lxc-archlinux" > work/rootfs/etc/hosts
echo "vagrant-lxc-archlinux" > work/rootfs/etc/hostname

rm -rf work/rootfs/var/cache/pacman/pkg/*

tar --numeric-owner -czf work/rootfs.tar.gz -C work ./rootfs

cat << EOF >  work/metadata.json
{
	"provider": "lxc",
	"version":  "1.0.0"
}
EOF

cp lxc-config work/lxc-config

tar -czf work/archlinux.box -C work rootfs.tar.gz lxc-config metadata.json
