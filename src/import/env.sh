#!/bin/bash

: ${TIMEOUT_SEC:=600};
: ${TIMELAG_SEC:=5};

: ${STATE_DIR:=$HOME};
: ${ISO_DIR:=$STATE_DIR/iso};
: ${OUT_DIR:=$STATE_DIR/out};
: ${CELLAR_DIR:=$STATE_DIR/cellar};

: ${KERNEL_MAJOR_VERSION:=4.9};
# : ${LIBCAP2_VERSION:=2.22};

: ${THREAD_COUNT:=2};

LOCK_DIR=$STATE_DIR/lock;
ROOTFS_DIR=$STATE_DIR/rootfs;
WORK_DIR=$STATE_DIR/work;
CORES_COUNT=$(nproc);
LABEL=`date +tc-%y%m%d-%H`;

# linux
KERNEL_PUB=https://cdn.kernel.org/pub; # https://mirrors.edge.kernel.org/pub

# linux
KERNEL_DOWNLOAD=$KERNEL_PUB/linux/kernel;
LIBCAP2_DOWNLOAD=$KERNEL_PUB/linux/libs/security/linux-privs/libcap2;
DOCKER_DOWNLOAD=https://download.docker.com/linux/static/stable/x86_64; # https://docs.docker.com/install/linux/docker-ce/binaries/#prerequisites
TCL_REPO_DOWNLOAD=http://www.tinycorelinux.net/9.x/x86_64; # tiny core linux

# tce-load -wi [tcz]
#   mdadm: raid-dm-KERNEL
#   iptables: netfilter-KERNEL

# fork: https://github.com/boot2docker/boot2docker/blob/master/Dockerfile
TCZ_DEPS="
    openssh openssl
    git curl ca-certificates expat2
    iproute2
    iptables
    sshfs-fuse fuse
    lvm2 liblvm2 udev-lib readline
    rsync
    tar acl attr
    xz
    pcre
    ntpclient
    mdadm
    e2fsprogs
    net-tools
    procps
    portmap
    tcp_wrappers
    acpid
";

# debian sources
DEBIAN_SOURCE='deb http://deb.debian.org/debian stretch main
deb http://deb.debian.org/debian stretch-updates main
deb http://security.debian.org stretch/updates main
';

DEBIAN_CN_SOURCE='deb http://ftp.cn.debian.org/debian stretch main contrib non-free
deb-src http://ftp.cn.debian.org/debian stretch main contrib non-free
deb http://ftp.cn.debian.org/debian stretch-updates main contrib non-free
deb-src http://ftp.cn.debian.org/debian stretch-updates main contrib non-free
deb http://ftp.cn.debian.org/debian-security stretch/updates main contrib non-free
deb-src http://ftp.cn.debian.org/debian-security stretch/updates main contrib non-free
';

# APT_GET_LIST_MAKE="
#     automake
#     bc bsdtar build-essential
#     curl
#     kmod
#     libc6 libc6-dev
#     pkg-config
#     squashfs-tools
#     unzip
# ";

eval $(grep 'CONFIG_LOCALVERSION=' $THIS_DIR/config/kernel.cfg) || return $(_err $LINENO 1)
