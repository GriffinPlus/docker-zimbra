#!/bin/bash

set -e

ZIMBRA_DOWNLOAD_URL="https://files.zimbra.com/downloads/8.8.7_GA/zcs-8.8.7_GA_1964.UBUNTU16_64.20180223145016.tgz"
ZIMBRA_DOWNLOAD_HASH="c1ae07a77d8337832114c87a75c4d5b7245a4ae1ce428bd6eb8bc178249587cc"
SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"

# enable updating of /etc/resolv.conf when updating
echo "resolvconf resolvconf/linkify-resolvconf boolean false" | debconf-set-selections

echo
echo "Updating environment..."
apt-get -y update
apt-get -y install software-properties-common
add-apt-repository --yes "deb http://archive.ubuntu.com/ubuntu xenial          main restricted universe"
add-apt-repository --yes "deb http://archive.ubuntu.com/ubuntu xenial-updates  main restricted universe"
add-apt-repository --yes "deb http://archive.ubuntu.com/ubuntu xenial-security main restricted universe"
add-apt-repository --yes "ppa:certbot/certbot"
apt-get -y update
apt-get -y dist-upgrade

echo
echo "Installing prerequisites..."
apt-get -y install \
    certbot \
    coreutils \
    cron \
    iptables \
    logrotate \
    lsb-release \
    nano \
    net-tools \
    rsyslog \
    ssh \
    wget

# download zimbra
echo
echo "Downloading Zimbra..."
mkdir -p /install
cd /install
wget -O zcs.tgz $ZIMBRA_DOWNLOAD_URL
CALC_HASH=`sha256sum zcs.tgz | cut -d ' ' -f1`
if [ "$CALC_HASH" != "$ZIMBRA_DOWNLOAD_HASH" ]; then
    echo "Downloaded file is corrupt!"
    exit 1
fi

echo
echo "Extracting Zimbra..."
mkdir zcs
tar -C zcs -xvzf zcs.tgz --strip-components=1

echo
echo "Installing Zimbra..."
cd zcs
./install.sh

echo
echo "Removing Zimbra installation files..."
cd /
rm -Rv /install

echo
echo "Adding Zimbra's Perl include path to search path..."
echo 'PERL5LIB="/opt/zimbra/common/lib/perl5"' >> /etc/environment

echo
echo "Scheduling running Certbot daily..."
echo "0 0 * * * root /app/update-letsencrypt.sh >/dev/null 2>&1" > /etc/cron.d/certbot

echo
echo "Generating stronger DH parameters (4096 bit)..."
sudo -u zimbra /opt/zimbra/bin/zmdhparam set -new 4096

echo
echo "Configuring cipher suites (as strong as possible without breaking compatibility and sacrificing speed)..."
sudo -u zimbra /opt/zimbra/bin/zmprov mcf zimbraReverseProxySSLCiphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES256-SHA:ECDHE-RSA-AES256-SHA'
sudo -u zimbra /opt/zimbra/bin/zmprov mcf zimbraMtaSmtpdTlsCiphers high
sudo -u zimbra /opt/zimbra/bin/zmprov mcf zimbraMtaSmtpdTlsProtocols '!SSLv2,!SSLv3'
sudo -u zimbra /opt/zimbra/bin/zmprov mcf zimbraMtaSmtpdTlsMandatoryCiphers high
sudo -u zimbra /opt/zimbra/bin/zmprov mcf zimbraMtaSmtpdTlsExcludeCiphers 'aNULL,MD5,DES'

echo
echo "Enabling HTTP Strict Transport Security (HSTS)..."
sudo -u zimbra /opt/zimbra/bin/zmprov mcf +zimbraResponseHeader "Strict-Transport-Security: max-age=31536000"

exit 0
