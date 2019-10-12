#!/bin/bash

set -e

SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"

# enable updating of /etc/resolv.conf when updating
echo "resolvconf resolvconf/linkify-resolvconf boolean false" | debconf-set-selections

echo
echo "Updating environment..."
apt-get -y update
apt-get -y install software-properties-common
add-apt-repository --yes "deb http://archive.ubuntu.com/ubuntu bionic          main restricted universe"
add-apt-repository --yes "deb http://archive.ubuntu.com/ubuntu bionic-updates  main restricted universe"
add-apt-repository --yes "deb http://archive.ubuntu.com/ubuntu bionic-security main restricted universe"
apt-get -y update
apt-get -y dist-upgrade
apt-get -y autoremove

echo
echo "Installing prerequisites..."
apt-get -y install \
    coreutils \
    cron \
    iptables \
    logrotate \
    lsb-release \
    nano \
    net-tools \
    python3 \
    python3-pip \
    python3-virtualenv \
    rsyslog \
    ssh \
    sudo \
    unattended-upgrades \
    wget

echo
echo Preparing virtual Python environment for setup/service scripts...
python3 -m virtualenv --python=/usr/bin/python3 /app/venv
source /app/venv/bin/activate
pip3 install pem
pip3 install pyOpenSSL
deactivate

echo
echo Setting up unattended upgrades...
cp -f $SCRIPTPATH/resources/50unattended-upgrades /etc/apt/apt.conf.d/
cat > /etc/apt/apt.conf.d/20auto-upgrades <<EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "3";
APT::Periodic::Unattended-Upgrade "1";
EOF

exit 0
