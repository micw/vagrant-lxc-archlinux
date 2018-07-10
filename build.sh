#!/bin/bash

rm -rf work
mkdir work
mkdir work/root
(cd work && curl -s https://git.archlinux.org/arch-install-scripts.git/snapshot/arch-install-scripts-18.tar.gz | tar xfvz -)
(cd work/arch-install-scripts-18 && make)
work/arch-install-scripts-18/pacstrap work/root filesystem
