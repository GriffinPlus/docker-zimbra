#!/bin/bash

set -e

ZIMBRA_DOWNLOAD_URL="https://files.zimbra.com/downloads/8.8.6_GA/zcs-8.8.6_GA_1906.UBUNTU16_64.20171130041047.tgz"
ZIMBRA_DOWNLOAD_HASH="8a83e67df40bc0e396d5178980531dbca89a81b648891c1667c53a02486a110e"
SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"

# enable updating of /etc/resolv.conf when updating
echo "resolvconf resolvconf/linkify-resolvconf boolean false" | debconf-set-selections

echo "Installing prerequisites..."
apt-get -y update
apt-get -y upgrade
apt-get -y install \
    coreutils \
    cron \
    logrotate \
    lsb-release \
    nano \
    net-tools \
    rsyslog \
    ssh \
    wget

# download zimbra
echo "Downloading Zimbra..."
mkdir -p /install
cd /install
wget -O zcs.tgz $ZIMBRA_DOWNLOAD_URL
CALC_HASH=`sha256sum zcs.tgz | cut -d ' ' -f1`
if [ "$CALC_HASH" != "$ZIMBRA_DOWNLOAD_HASH" ]; then
    echo "Downloaded file is corrupt!"
    exit 1
fi

# extract zimbra to /install/zcs
mkdir zcs
tar -C zcs -xvzf zcs.tgz --strip-components=1

# install zimbra
cd zcs
./install.sh

# remove installation files
cd /
rm -R /install

exit 0

