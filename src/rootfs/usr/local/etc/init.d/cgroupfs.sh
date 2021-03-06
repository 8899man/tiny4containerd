#!/bin/sh
# Copyright 2011 Canonical, Inc
#           2014 Tianon Gravi
# Author: Serge Hallyn <serge.hallyn@canonical.com>
#         Tianon Gravi <admwiggin@gmail.com>

[ $(id -u) = 0 ] || { echo 'must be root' >&2; exit 1; }

# doh, TCL doesn't have "mountpoint"
_mountpoint() {
	dashQ=$1;
	dir=$(readlink -f "$2");
	grep -q " $dir " /proc/mounts
}

# for simplicity this script provides no flexibility
_cgroupfs_mount() {

    # if cgroup is mounted by fstab, don't run
    # don't get too smart - bail on any uncommented entry with 'cgroup' in it
    if grep -v '^#' /etc/fstab | grep -q cgroup; then
        echo 'cgroups mounted from fstab, not mounting /sys/fs/cgroup';
        return 0
    fi

    # mount /sys/fs/cgroup if not already done
    if ! _mountpoint -q /sys/fs/cgroup; then
        mount -t tmpfs -o uid=0,gid=0,mode=0755 cgroup /sys/fs/cgroup
    fi

    cd /sys/fs/cgroup;

    # get/mount list of enabled cgroup controllers
    for sys in $(awk '!/^#/ { if ($4 == 1) print $1 }' /proc/cgroups); do
        mkdir -p $sys
        if ! _mountpoint -q $sys; then
            if ! mount -n -t cgroup -o $sys cgroup $sys; then
                rmdir $sys || true
            fi
        fi
    done
}

# we don't care to move tasks around gratuitously - just umount the cgroups
_cgroupfs_umount() {

    # if /sys/fs/cgroup is not mounted, we don't bother
    if ! _mountpoint -q /sys/fs/cgroup; then
        return 0
    fi

    cd /sys/fs/cgroup;

    for sys in *; do
        if _mountpoint -q $sys; then
            umount $sys
        fi
        if [ -d $sys ]; then
            rmdir $sys || true
        fi
    done
}

# kernel provides cgroups?
if [ ! -e /proc/cgroups ]; then
    exit 0
fi

# if we don't even have the directory we need, something else must be wrong
if [ ! -d /sys/fs/cgroup ]; then
    exit 0
fi

case $1 in
    mount) _cgroupfs_mount;;
    umount) _cgroupfs_umount;;
    *) echo "Usage ${0##*/} {mount|umount}" >&2; exit 1
esac

# example /proc/cgroups:
#  #subsys_name	hierarchy	num_cgroups	enabled
#  cpuset	2	3	1
#  cpu	3	3	1
#  cpuacct	4	3	1
#  memory	5	3	0
#  devices	6	3	1
#  freezer	7	3	1
#  blkio	8	3	1

exit 0