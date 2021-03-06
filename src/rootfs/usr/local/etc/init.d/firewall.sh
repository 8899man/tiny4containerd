#!/bin/sh
# Begin basic-firewall
#
# This is a very basic firewall for normal users.
# It blocks all incoming traffic, allows all outgoing,
# and only allows incoming stuff when you started it (ie browsing)

[ $(id -u) = 0 ] || { echo 'must be root' >&2; exit 1; }

_init() {

    # Insert connection-tracking modules
    modprobe -q iptable_nat
    modprobe -q nf_conntrack_ipv4
    modprobe -q nf_conntrack_ftp
    modprobe -q ipt_LOG

    # Enable broadcast echo Protection
    echo 1 > /proc/sys/net/ipv4/icmp_echo_ignore_broadcasts

    # Disable Source Routed Packets
    echo 0 > /proc/sys/net/ipv4/conf/all/accept_source_route

    # Enable TCP SYN Cookie Protection
    echo 1 > /proc/sys/net/ipv4/tcp_syncookies

    # Disable ICMP Redirect Acceptance
    echo 0 > /proc/sys/net/ipv4/conf/all/accept_redirects

    # Don't send Redirect Messages
    echo 0 > /proc/sys/net/ipv4/conf/all/send_redirects

    # Drop Spoofed Packets coming in on an interface, where responses
    # would result in the reply going out a different interface.
    echo 1 > /proc/sys/net/ipv4/conf/all/rp_filter

    # Log packets with impossible addresses.
    echo 1 > /proc/sys/net/ipv4/conf/all/log_martians

    # be verbose on dynamic ip-addresses  (not needed in case of static IP)
    echo 2 > /proc/sys/net/ipv4/ip_dynaddr

    # disable Explicit Congestion Notification
    # too many routers are still ignorant
    echo 0 > /proc/sys/net/ipv4/tcp_ecn

    # Set a known state
    iptables -P INPUT   DROP
    iptables -P FORWARD DROP
    iptables -P OUTPUT  ACCEPT

    # These lines are here in case rules are already in place and the
    # script is ever rerun on the fly. We want to remove all rules and
    # pre-existing user defined chains before we implement new rules.
    iptables -F
    iptables -X
    iptables -Z

    iptables -t nat -F

    # Allow local-only connections
    iptables -A INPUT  -i lo -j ACCEPT

    # Permit answers on already established connections
    # and permit new connections related to established ones
    # (e.g. port mode ftp)
    iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

    # Speed up some ftp / IM
    # iptables -A INPUT  -p tcp --dport 113 -j REJECT --reject-with tcp-reset

    # Log everything else. What's Windows' latest exploitable vulnerability?
    # iptables -A INPUT -j LOG --log-prefix "FIREWALL:INPUT "

    # if [ "$1" != "noprompt" ]; then

    # 	# ANSI COLORS
    # 	NORMAL="$(echo -e '\033[0;39m')"
    # 	BLUE="$(echo -e '\033[1;34m')"
    # 	WHITE="$(echo -e '\033[1;37m')"

    # 	echo "${BLUE}Your basic firewall is now ${WHITE}[operational]${NORMAL}"
    # 	echo "Press enter to continue"
    # 	read bogus
    # fi

    # End of basic-firewall
    _status
}

_status() {
    . /etc/init.d/tc-functions
    printf "$BLUE\n"
    # To display numeric values, type
    iptables -vnL
    printf "$NORMAL\n"
}

case $1 in
    init) _init;;
    ""|status) _status;;
    *) echo "Usage ${0##*/} {init|status}" >&2; exit 1
esac

exit 0
