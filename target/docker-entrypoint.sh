#!/bin/bash

set -e

ZIMBRA_ENVIRONMENT_PATH="/data"
HOSTNAME=$(hostname -a)
DOMAIN=$(hostname -d)
# CONTAINER_IP=$(hostname --ip-address)
CONTAINER_IP=$(ip addr | grep 'state UP' -A2 | tail -n1 | awk '{print $2}' | cut -f1  -d'/')

function prepare_chroot
{
    mount -o bind /dev $ZIMBRA_ENVIRONMENT_PATH/dev
    mount -o bind /dev/pts $ZIMBRA_ENVIRONMENT_PATH/dev/pts
    mount -t sysfs /sys $ZIMBRA_ENVIRONMENT_PATH/sys
    mount -t proc /proc $ZIMBRA_ENVIRONMENT_PATH/proc
    rm -f $ZIMBRA_ENVIRONMENT_PATH/etc/mtab
    cp /proc/mounts $ZIMBRA_ENVIRONMENT_PATH/etc/mtab
    cp /etc/hosts $ZIMBRA_ENVIRONMENT_PATH/etc
    mount -o bind /etc/hosts $ZIMBRA_ENVIRONMENT_PATH/etc/hosts
    mount -o bind /etc/hostname $ZIMBRA_ENVIRONMENT_PATH/etc/hostname
    mount -o bind /etc/resolv.conf $ZIMBRA_ENVIRONMENT_PATH/etc/resolv.conf
    cp /app/control-zimbra.sh $ZIMBRA_ENVIRONMENT_PATH/app/
    cp /app/tls-cert-updater.py $ZIMBRA_ENVIRONMENT_PATH/app/
    chmod 750 $ZIMBRA_ENVIRONMENT_PATH/app/control-zimbra.sh
    chmod 755 $ZIMBRA_ENVIRONMENT_PATH/app/tls-cert-updater.py
}

function shutdown_chroot
{
    umount $ZIMBRA_ENVIRONMENT_PATH/etc/resolv.conf
    umount $ZIMBRA_ENVIRONMENT_PATH/etc/hostname
    umount $ZIMBRA_ENVIRONMENT_PATH/etc/hosts
    umount $ZIMBRA_ENVIRONMENT_PATH/proc
    umount $ZIMBRA_ENVIRONMENT_PATH/sys
    umount $ZIMBRA_ENVIRONMENT_PATH/dev/pts
    umount $ZIMBRA_ENVIRONMENT_PATH/dev
}

function setup_environment
{
    # install a fresh Ubuntu 18.04 LTS (bionic) linux, if the volume is still empty
    # (may contain mounted TLS certificates, so classical emptiness check cannot be used...)
    if [ ! -f "$ZIMBRA_ENVIRONMENT_PATH/etc/hosts" ]; then

        echo "Installing minimalistic Ubuntu 18.04 LTS (bionic)..."
        debootstrap --variant=minbase --arch=amd64 bionic /data http://archive.ubuntu.com/ubuntu/

        echo "Running Zimbra installation script (/app/install-zimbra.sh)..."
        mkdir -p $ZIMBRA_ENVIRONMENT_PATH/app
        mkdir -p $ZIMBRA_ENVIRONMENT_PATH/app/resources
        cp /app/setup-environment.sh $ZIMBRA_ENVIRONMENT_PATH/app/
        cp /app/install-zimbra.sh $ZIMBRA_ENVIRONMENT_PATH/app/
        cp /app/resources/50unattended-upgrades $ZIMBRA_ENVIRONMENT_PATH/app/resources/
        chmod 750 $ZIMBRA_ENVIRONMENT_PATH/app/setup-environment.sh
        chmod 750 $ZIMBRA_ENVIRONMENT_PATH/app/install-zimbra.sh
        chmod 644 $ZIMBRA_ENVIRONMENT_PATH/app/resources/50unattended-upgrades
        touch $ZIMBRA_ENVIRONMENT_PATH/.dont_start_zimbra
        prepare_chroot
        chroot $ZIMBRA_ENVIRONMENT_PATH /app/setup-environment.sh
        chroot $ZIMBRA_ENVIRONMENT_PATH /app/install-zimbra.sh # starts services at the end...
        chroot $ZIMBRA_ENVIRONMENT_PATH /app/control-zimbra.sh stop
        rm $ZIMBRA_ENVIRONMENT_PATH/app/setup-environment.sh
        shutdown_chroot

    fi
}


# Allowed ports (FIREWALL_ALLOW_PORTS_IN)
# -----------------------------------------------------------------------------
# 25/tcp   - SMTP (for incoming mail)
# 80/tcp   - HTTP (for web mail clients)
# 110/tcp  - POP3 (for mail clients)
# 143/tcp  - IMAP (for mail clients)
# 443/tcp  - HTTPS (for web mail clients)
# 465/tcp  - SMTP over SSL (for mail clients)
# 587/tcp  - SMTP (submission, for mail clients)
# 993/tcp  - IMAP over TLS (for mail clients)
# 995/tcp  - POP3 over TLS (for mail clients)
# 5222/tcp - XMPP
# 5223/tcp - XMPP (default legacy port)
# 7071/tcp - HTTPS (admin panel, https://<host>/zimbraAdmin)
# -----------------------------------------------------------------------------
FIREWALL_ALLOW_UDP_PORTS_IN=${FIREWALL_ALLOW_UDP_PORTS_IN:-}
FIREWALL_ALLOW_TCP_PORTS_IN=${FIREWALL_ALLOW_TCP_PORTS_IN:-25,80,110,143,443,465,587,993,995,5222,5223,7071}

function configure_firewall
{
    # proceed only, if the firewall is not already configured
    # (the 'AllowICMP' chain is added below)
    if [ `iptables -L AllowICMP > /dev/null 2>/dev/null; echo $?` != "0" ]; then
        return 0
    fi

    # filter all packets that have RH0 headers (deprecated, can be used for DoS attacks)
    ip6tables -t raw    -A PREROUTING  -m rt --rt-type 0 -j DROP
    ip6tables -t mangle -A POSTROUTING -m rt --rt-type 0 -j DROP

    # prevent attacker from using the loopback address as source address
    iptables  -t raw -A PREROUTING ! -i lo -s 127.0.0.0/8 -j DROP
    ip6tables -t raw -A PREROUTING ! -i lo -s ::1/128     -j DROP

    # block TCP packets with bogus flags
    iptables  -t raw -A PREROUTING -p tcp --tcp-flags ACK,FIN FIN                 -j DROP
    iptables  -t raw -A PREROUTING -p tcp --tcp-flags ACK,PSH PSH                 -j DROP
    iptables  -t raw -A PREROUTING -p tcp --tcp-flags ACK,URG URG                 -j DROP
    iptables  -t raw -A PREROUTING -p tcp --tcp-flags FIN,RST FIN,RST             -j DROP
    iptables  -t raw -A PREROUTING -p tcp --tcp-flags SYN,FIN SYN,FIN             -j DROP
    iptables  -t raw -A PREROUTING -p tcp --tcp-flags SYN,RST SYN,RST             -j DROP
    iptables  -t raw -A PREROUTING -p tcp --tcp-flags ALL     ALL                 -j DROP
    iptables  -t raw -A PREROUTING -p tcp --tcp-flags ALL     NONE                -j DROP
    iptables  -t raw -A PREROUTING -p tcp --tcp-flags ALL     FIN,PSH,URG         -j DROP
    iptables  -t raw -A PREROUTING -p tcp --tcp-flags ALL     SYN,FIN,PSH,URG     -j DROP
    iptables  -t raw -A PREROUTING -p tcp --tcp-flags ALL     SYN,RST,ACK,FIN,URG -j DROP
    ip6tables -t raw -A PREROUTING -p tcp --tcp-flags ACK,FIN FIN                 -j DROP
    ip6tables -t raw -A PREROUTING -p tcp --tcp-flags ACK,PSH PSH                 -j DROP
    ip6tables -t raw -A PREROUTING -p tcp --tcp-flags ACK,URG URG                 -j DROP
    ip6tables -t raw -A PREROUTING -p tcp --tcp-flags FIN,RST FIN,RST             -j DROP
    ip6tables -t raw -A PREROUTING -p tcp --tcp-flags SYN,FIN SYN,FIN             -j DROP
    ip6tables -t raw -A PREROUTING -p tcp --tcp-flags SYN,RST SYN,RST             -j DROP
    ip6tables -t raw -A PREROUTING -p tcp --tcp-flags ALL     ALL                 -j DROP
    ip6tables -t raw -A PREROUTING -p tcp --tcp-flags ALL     NONE                -j DROP
    ip6tables -t raw -A PREROUTING -p tcp --tcp-flags ALL     FIN,PSH,URG         -j DROP
    ip6tables -t raw -A PREROUTING -p tcp --tcp-flags ALL     SYN,FIN,PSH,URG     -j DROP
    ip6tables -t raw -A PREROUTING -p tcp --tcp-flags ALL     SYN,RST,ACK,FIN,URG -j DROP

    # block all packets that have an invalid connection state
    # (mitigates all TCP flood attacks, except SYN floods)
    iptables  -t mangle -A PREROUTING -m conntrack --ctstate INVALID -j DROP
    ip6tables -t mangle -A PREROUTING -m conntrack --ctstate INVALID -j DROP

    # block all packets that are new, but not SYN packets
    iptables  -t mangle -A PREROUTING -p tcp ! --syn -m conntrack --ctstate NEW -j DROP
    ip6tables -t mangle -A PREROUTING -p tcp ! --syn -m conntrack --ctstate NEW -j DROP

    # allow packets from loopback interface
    iptables  -A INPUT -i lo -j ACCEPT
    ip6tables -A INPUT -i lo -j ACCEPT

    # allow packets that belong to established connections
    iptables  -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    ip6tables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

    # allow access to public services (tcp)
    while IFS=',' read -ra PORTS; do
        for port in "${PORTS[@]}"; do
#             echo "Allowing tcp port $port"
             iptables -A INPUT -p tcp --dport $port -j ACCEPT
             ip6tables -A INPUT -p tcp --dport $port -j ACCEPT
        done
    done <<< "$FIREWALL_ALLOW_TCP_PORTS_IN"

    # allow access to public services (udp)
    while IFS=',' read -ra PORTS; do
        for port in "${PORTS[@]}"; do
#             echo "Allowing udp port $port"
             iptables -A INPUT -p udp --dport $port -j ACCEPT
             ip6tables -A INPUT -p udp --dport $port -j ACCEPT
        done
    done <<< "$FIREWALL_ALLOW_UDP_PORTS_IN"

    # allow necessary ICMPv4 packets

    # ICMP Type | INPUT | Description
    # -----------------------------------------------------------------------------------------
    #       0   |  yes  |   echo reply
    #       3   |  yes  |   destination unreachable
    #       8   |  yes  |   echo request (protect against ping-of-death)
    #      11   |  yes  |   time exceeded
    #      12   |  yes  |   parameter problem
    # -----------------------------------------------------------------------------------------
    iptables -N AllowICMP
    iptables -A AllowICMP -p icmp --icmp-type 0  -j ACCEPT
    iptables -A AllowICMP -p icmp --icmp-type 3  -j ACCEPT
    iptables -A AllowICMP -p icmp --icmp-type 8  -j ACCEPT -m limit --limit 5/sec --limit-burst 10
    iptables -A AllowICMP -p icmp --icmp-type 11 -j ACCEPT
    iptables -A AllowICMP -p icmp --icmp-type 12 -j ACCEPT
    iptables -A AllowICMP -j DROP
    iptables -A INPUT -p icmp -j AllowICMP

    # allow necessary ICMPv6 packets

    #  ICMPv6 Type | INPUT | Description
    # -----------------------------------------------------------------------------------------
    #         1    |  yes  |   destination unreachable
    #         2    |  yes  |   packet too big
    #         3    |  yes  |   time exceeded
    #         4    |  yes  |   parameter problem
    #       128    |  yes  |   echo request (protect against ping-of-death)
    #       129    |  yes  |   echo reply
    #       130    |  yes  |   multicast listener query
    #       131    |  yes  |   version 1 multicast listener report
    #       132    |  yes  |   multicast listener done
    #       133    |  yes  |   router solicitation
    #       134    |  yes  |   router advertisement
    #       135    |  yes  |   neighbor solicitation
    #       136    |  yes  |   neighbor advertisement
    #       151    |  yes  |   multicast router advertisement
    #       152    |  yes  |   multicast router solicitation
    #       153    |  yes  |   multicast router termination
    # -----------------------------------------------------------------------------------------
    ip6tables -N AllowICMP
    ip6tables -A AllowICMP -p icmpv6 --icmpv6-type 1   -j ACCEPT
    ip6tables -A AllowICMP -p icmpv6 --icmpv6-type 2   -j ACCEPT
    ip6tables -A AllowICMP -p icmpv6 --icmpv6-type 3   -j ACCEPT
    ip6tables -A AllowICMP -p icmpv6 --icmpv6-type 4   -j ACCEPT
    ip6tables -A AllowICMP -p icmpv6 --icmpv6-type 128 -j ACCEPT -m limit --limit 5/sec --limit-burst 10
    ip6tables -A AllowICMP -p icmpv6 --icmpv6-type 129 -j ACCEPT
    ip6tables -A AllowICMP -p icmpv6 --icmpv6-type 130 -j ACCEPT
    ip6tables -A AllowICMP -p icmpv6 --icmpv6-type 131 -j ACCEPT
    ip6tables -A AllowICMP -p icmpv6 --icmpv6-type 132 -j ACCEPT
    ip6tables -A AllowICMP -p icmpv6 --icmpv6-type 133 -j ACCEPT
    ip6tables -A AllowICMP -p icmpv6 --icmpv6-type 134 -j ACCEPT
    ip6tables -A AllowICMP -p icmpv6 --icmpv6-type 135 -j ACCEPT
    ip6tables -A AllowICMP -p icmpv6 --icmpv6-type 136 -j ACCEPT
    ip6tables -A AllowICMP -p icmpv6 --icmpv6-type 151 -j ACCEPT
    ip6tables -A AllowICMP -p icmpv6 --icmpv6-type 152 -j ACCEPT
    ip6tables -A AllowICMP -p icmpv6 --icmpv6-type 153 -j ACCEPT
    ip6tables -A AllowICMP -j DROP
    ip6tables -A INPUT -p icmpv6 -j AllowICMP

    # drop everything else
    iptables -A INPUT -j DROP
    ip6tables -A INPUT -j DROP
}


function setup_signals
{
  cid="$1"; shift
  handler="$1"; shift
  for sig; do
    trap "$handler '$cid' '$sig'" "$sig"
  done
}

# initially the zimbra is not running...
running=0

function handle_signal
{
  # echo "Received signal: $2"
  case "$2" in
    SIGINT|SIGTERM)
      # echo "Shutting down Zimbra..."
      chroot $ZIMBRA_ENVIRONMENT_PATH /app/control-zimbra.sh stop
      running=0
      ;;
    SIGHUP)
      # echo "Reloading Zimbra configuration..."
      chroot $ZIMBRA_ENVIRONMENT_PATH /app/control-zimbra.sh reload
      ;;
  esac
}

function start_zimbra
{
    running=1
    chroot $ZIMBRA_ENVIRONMENT_PATH /app/control-zimbra.sh start
}

function wait_for_signals
{
    # wait for signals
    echo "Waiting for signals..."
    while [ $running -ne 0 ]; do
        tail -f /dev/null & wait ${!}
    done
    echo "Stopped waiting for signals..."
}

setup_signals "$1" "handle_signal" SIGINT SIGTERM SIGHUP


# configure split-horizon DNS for Zimbra
if [ "$$" = "1" ]; then

    # modify /etc/hosts to contain the external FQDN of the host
    if [ ! -z "${EXTERNAL_HOST_FQDN}" ]; then
        HOSTS_TEMP_PATH=`mktemp`
        cat /etc/hosts | sed -r "s/^($(hostname --ip-address))(\s+)(.*)$/\1\2$EXTERNAL_HOST_FQDN ${EXTERNAL_HOST_FQDN%%.*} \3/" > $HOSTS_TEMP_PATH
        cp -f "$HOSTS_TEMP_PATH" /etc/hosts
        rm -f "$HOSTS_TEMP_PATH"
    fi

    # retrieve regular DNS server
    DNS_SERVER=`cat /etc/resolv.conf | sed -rn "s/^nameserver\s+([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})\s*$/\1/p"`
    if [ "$DNS_SERVER" != "127.0.0.1" ]; then
        echo "$DNS_SERVER" > /etc/nameserver.org
    else
        if [ -f /etc/nameserver.org ]; then
            DNS_SERVER=`cat /etc/nameserver.org`
        else
            echo "Setting up split-horizon DNS failed. It seems to have been configured previously, but /etc/nameserver.org is missing now!"
            exit 1
        fi
    fi

    # configure dnsmasq
    [[ -z "${MAIL_DOMAINS}" ]] && MAIL_DOMAINS=`echo "$EXTERNAL_HOST_FQDN" | cut -d '.' -f 2-`
    echo > /etc/dnsmasq.conf
    for dnsserver in $DNS_SERVER; do
        echo "server=$dnsserver" >> /etc/dnsmasq.conf
    done
    echo "listen-address=127.0.0.1" >> /etc/dnsmasq.conf
    if [ -z "${EXTERNAL_HOST_FQDN}" ]; then
        echo "domain=$DOMAIN" >> /etc/dnsmasq.conf
        echo "address=/$HOSTNAME.$DOMAIN/$CONTAINER_IP" >> /etc/dnsmasq.conf
        echo "mx-host=$DOMAIN,$HOSTNAME.$DOMAIN,0" >> /etc/dnsmasq.conf
        for domain in ${ADDITIONAL_MAIL_DOMAINS//,/ }; do
            echo "mx-host=$domain,$HOSTNAME.$DOMAIN,0" >> /etc/dnsmasq.conf
        done
    else
        EXT_HOSTNAME=`echo "$EXTERNAL_HOST_FQDN" | cut -d '.' -f 1`
        EXT_DOMAIN=`echo "$EXTERNAL_HOST_FQDN" | cut -d '.' -f 2-`
        echo "domain=$EXT_DOMAIN" >> /etc/dnsmasq.conf
        echo "address=/$EXT_HOSTNAME.$EXT_DOMAIN/$CONTAINER_IP" >> /etc/dnsmasq.conf
        echo "mx-host=$EXT_DOMAIN,$EXT_HOSTNAME.$EXT_DOMAIN,0" >> /etc/dnsmasq.conf
        for domain in ${ADDITIONAL_MAIL_DOMAINS//,/ }; do
            echo "mx-host=$domain,$EXT_HOSTNAME.$EXT_DOMAIN,0" >> /etc/dnsmasq.conf
        done
    fi
    /etc/init.d/dnsmasq start

    # modify /etc/resolv.conf to use dnsmasq
    RESOLV_CONF_TEMP_PATH=`mktemp`
    cat /etc/resolv.conf | sed "s/nameserver .*/nameserver 127.0.0.1/" > $RESOLV_CONF_TEMP_PATH
    cp -f "$RESOLV_CONF_TEMP_PATH" /etc/resolv.conf
    rm -f "$RESOLV_CONF_TEMP_PATH"

fi

# install Ubuntu into /data (if /data is empty)
# install Zimbra, if the shell is attached to a terminal
setup_environment "$@"
if [ $? -ne 0 ]; then exit $?; fi


# prepare the chroot environment and configure the firewall
if [ "$$" = "1" ]; then
    prepare_chroot
    configure_firewall
fi


if [ "$1" = 'run' ]; then

    # start Zimbra processes
    start_zimbra
    wait_for_signals

elif [ "$1" = 'run-and-enter' ]; then

    # start Zimbra processes and a shell
    start_zimbra
    /bin/bash -c "/bin/bash && kill $$" 0<&0 1>&1 2>&2 &
    wait_for_signals

elif [ "$1" = 'run-and-enter-zimbra' ]; then

    # start Zimbra processes and open a shell
    start_zimbra
    chroot $ZIMBRA_ENVIRONMENT_PATH /bin/bash -c "/bin/bash && kill $$" 0<&0 1>&1 2>&2 &
    wait_for_signals

elif [ $# -gt 0 ]; then

    # parameters were specified
    # => interpret parameters as regular command
    chroot $ZIMBRA_ENVIRONMENT_PATH "$@"

fi


# shut chroot down, if primary process (PID 1) is shutting down
if [ "$$" = "1" ]; then
    shutdown_chroot
fi
