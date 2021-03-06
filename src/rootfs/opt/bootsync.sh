#!/bin/sh
. /etc/init.d/tc-functions;

# /etc/inittab -> /etc/init.d/rcS -> /etc/init.d/tc-config -> /opt/bootsync.sh

printf "${YELLOW}Running init script...$NORMAL\n";

STAMP=`date +%Y%m%d`;
LOG_DIR=/log/tiny/${STAMP:0:6};

# This log is started before the persistence partition is mounted
{

    # Configure sysctl, Read sysctl.conf
    sysctl -p /etc/sysctl.conf;

    # Load TCE extensions
    find /usr/local/tce.installed -type f -perm /u+x -exec /bin/sh -c {} \;

    # filter env
    sed 's/[\|\;\& ]/\n/g' /proc/cmdline | grep '^[_A-Z]\+=' > /etc/env;

    # mount and monitor hard drive array
    /usr/local/sbin/mdisk init;

    # for find/crond/log
    mkdir -p \
        /opt/tiny/etc/crontabs \
        /opt/tiny/etc/init.d \
        $LOG_DIR;

    # mdiskd
    /usr/local/sbin/mdisk monitor;

    # create empty config
    [ -s /opt/tiny/etc/env ] || printf \
        "# set environment variable\n\n" > \
        /opt/tiny/etc/env;

    # filter env
    awk -F# '{print $1}' /opt/tiny/etc/env 2>/dev/null | sed 's/[\|\;\&]/\n/g;s/export//g;s/^[ ]\+//g' | \
        grep '^[_A-Z]\+=' >> /etc/env;

    echo >> /etc/env;

    # init env
    . /etc/env;

    # change password
    /usr/local/sbin/pw load;

    echo "------ firewall --------------";
    # http://wiki.tinycorelinux.net/wiki:firewall
    # tce-load -wi iptables; -> /usr/local/sbin/basic-firewall
    sh /usr/local/etc/init.d/firewall.sh init;

    # set static ip or start dhcp
    /usr/local/sbin/ifinit;

    # mount cgroups hierarchy. https://github.com/tianon/cgroupfs-mount
    sh /usr/local/etc/init.d/cgroupfs.sh mount;

    sleep 2;

    # init
    find /opt/tiny/etc/init.d -type f -perm /u+x -name "S*.sh" -exec /bin/sh -c {} \;

    # sync the clock
    ntpd -d -n -p pool.ntp.org >> $LOG_DIR/ntpd_$STAMP.log 2>&1 &

    # start cron
    crond -f -d "${CROND_LOGLEVEL:-8}" >> $LOG_DIR/crond_$STAMP.log 2>&1 &

    # if we have the tc user, let's add it do the docker group
    grep -q '^tc:' /etc/passwd && addgroup tc docker;

    chmod 775 /tmp /volume1;
    chown :staff /tmp /volume1;

    # hide directory
    chmod 700 /opt/tiny/etc;

    # mkdir /tmp/tce
    # tce-setup
    # printf "http://repo.tinycorelinux.net/\n" | tee /opt/tcemirror

    #maybe the links will be up by now - trouble is, on some setups, they may never happen, so we can't just wait until they are
    sleep 3;

    # set the hostname
    echo tiny$(ip addr | grep -A 2 'eth[0-9]*:' | grep inet | awk -F'[.]|/' '{print "-"$4}' | awk '{printf $_}') | \
        tee /opt/tiny/etc/hostname;
    HOSTNAME=`cat /opt/tiny/etc/hostname`;
    /usr/bin/sethostname $HOSTNAME;

    # ssh dameon start
    sh /usr/local/etc/init.d/sshd.sh;

    # Launch ACPId (shutdown)
    /usr/local/etc/init.d/acpid start;

    echo "------ ifconfig --------------";
    # show ip info
    ifconfig | grep -A 2 '^[a-z]' | sed 's/Link .*//;s/--//g;s/UP.*//g;s/\s\s/ /g' | grep -v '^$';

    echo "----- containerd -------------";

    # Launch Containerd
    /usr/local/sbin/containerd start;

    # Allow rc.local customisation
    touch /opt/tiny/etc/rc.local;
    if [ -x /opt/tiny/etc/rc.local ]; then
        echo "------ rc.local --------------";
        . /opt/tiny/etc/rc.local
    fi

} 2>&1 | tee -a /var/log/boot_$STAMP.log;

# move log
{
    printf "\n\n[`date`]\n";
    cat /var/log/boot_*.log
} >> $LOG_DIR/boot_$STAMP.log && rm -f /var/log/boot_*.log;

unset LOG_DIR STAMP;

printf "${YELLOW}Finished init script...$NORMAL\n";

sleep 1.5;

clear;
