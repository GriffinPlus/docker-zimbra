#!/bin/bash

set -e

ZIMBRA_DOWNLOAD_URL="https://files.zimbra.com/downloads/8.8.11_GA/zcs-NETWORK-8.8.11_GA_3737.UBUNTU16_64.20181207111719.tgz"
ZIMBRA_DOWNLOAD_HASH="c1446764fd2bee6ddd074976c26f029f395739735d42cf2eec380d16719e358f"
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
    apticron \
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
ADMIN_EMAIL=`sudo -u zimbra /opt/zimbra/bin/zmlocalconfig smtp_destination | cut -d ' ' -f3`
echo "Configuring apticron to send update notifications to $ADMIN_EMAIL..."
echo "EMAIL=\"$ADMIN_EMAIL\"" >> /etc/apticron/apticron.conf

echo
echo "Configuring Zimbra's brute-force detector (auditswatch) to send notifications to $ADMIN_EMAIL..."
# download and install missing auditswatch file
# ----------------------------------------------------------------------------------------------------------
mkdir -p /install/auditswatch
cd /install/auditswatch
wget -O auditswatch http://bugzilla-attach.zimbra.com/attachment.cgi?id=66723
mv auditswatch  /opt/zimbra/libexec/auditswatch
chown root:root /opt/zimbra/libexec/auditswatch
chmod 0755 /opt/zimbra/libexec/auditswatch

# configure auditswatch
# ----------------------------------------------------------------------------------------------------------
# The email address that we want to be worn when all the conditions happens.
sudo -u zimbra -- /opt/zimbra/bin/zmlocalconfig -e zimbra_swatch_notice_user=$ADMIN_EMAIL
# The duration within the thresholds below refer to (in seconds)
sudo -u zimbra -- /opt/zimbra/bin/zmlocalconfig -e zimbra_swatch_threshold_seconds=3600
# IP/Account hash check which warns on 10 auth failures from an IP/Account combo within the specified time.
sudo -u zimbra -- /opt/zimbra/bin/zmlocalconfig -e zimbra_swatch_ipacct_threshold=10
# Account check which warns on 15 auth failures from any IP within the specified time.
# Attempts to detect a distributed hijack based attack on a single account.
sudo -u zimbra -- /opt/zimbra/bin/zmlocalconfig -e zimbra_swatch_acct_threshold=15
# IP check which warns on 20 auth failures to any account within the specified time.
# Attempts to detect a single host based attack across multiple accounts.
sudo -u zimbra -- /opt/zimbra/bin/zmlocalconfig -e zimbra_swatch_ip_threshold=20
# Total auth failure check which warns on 100 auth failures from any IP to any account within the specified time.
# The recommended value on this is guestimated at 1% of active accounts for the Mailbox.
sudo -u zimbra -- /opt/zimbra/bin/zmlocalconfig -e zimbra_swatch_total_threshold=100
# check whether the service starts as expected
# ----------------------------------------------------------------------------------------------------------
sudo -u zimbra -- /opt/zimbra/bin/zmauditswatchctl start

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

echo
echo "Configuring default COS to use selected persona in the Return-Path of the mail envelope (important for privacy)."
sudo -u zimbra /opt/zimbra/bin/zmprov mc default zimbraSmtpRestrictEnvelopeFrom FALSE

exit 0
