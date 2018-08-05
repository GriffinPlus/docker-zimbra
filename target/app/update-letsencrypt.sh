#!/bin/bash

set -e

HOSTNAME=`/opt/zimbra/bin/zmhostname`
EMAIL_ADDRESS=`sudo -u zimbra /opt/zimbra/bin/zmlocalconfig smtp_destination | cut -d ' ' -f3`
CERTBOT_HTTP_PORT=9000
SCRIPT_PATH=`realpath "$0"`

function pre_hook
{
    echo "Redirecting HTTP port to Certbot..."
    iptables  -I INPUT 1 -i eth0 -p tcp --dport $CERTBOT_HTTP_PORT -j ACCEPT
    ip6tables -I INPUT 1 -i eth0 -p tcp --dport $CERTBOT_HTTP_PORT -j ACCEPT
    iptables  -t nat -A PREROUTING -i eth0 -p tcp --dport 80 -j REDIRECT --to-port $CERTBOT_HTTP_PORT
    ip6tables -t nat -A PREROUTING -i eth0 -p tcp --dport 80 -j REDIRECT --to-port $CERTBOT_HTTP_PORT
}

function deploy_hook
{
    echo "Deploying the certificate..."
    wget -q -O /tmp/identrust.p7b https://www.identrust.com/node/935
    openssl pkcs7 -print_certs -inform der -in /tmp/identrust.p7b | awk '/subject=\/O=Digital Signature Trust Co.\/CN=DST Root CA X3/,/^-----END CERTIFICATE-----$/' > /tmp/dst-root-ca-x3.pem
    sudo -u zimbra /opt/zimbra/bin/zmproxyctl stop
    sudo -u zimbra /opt/zimbra/bin/zmmailboxdctl stop
    cp /etc/letsencrypt/live/$HOSTNAME/privkey.pem /opt/zimbra/ssl/zimbra/commercial/commercial.key
    cp /etc/letsencrypt/live/$HOSTNAME/cert.pem /tmp/cert.pem
    cat /etc/letsencrypt/live/$HOSTNAME/chain.pem /tmp/dst-root-ca-x3.pem > /tmp/chain.pem
    chown zimbra /opt/zimbra/ssl/zimbra/commercial/commercial.key
    chmod 600 /opt/zimbra/ssl/zimbra/commercial/commercial.key
    chmod 644 /tmp/cert.pem
    chmod 644 /tmp/chain.pem
    sudo -u zimbra /opt/zimbra/bin/zmcertmgr deploycrt comm /tmp/cert.pem /tmp/chain.pem
    # sudo -u zimbra /opt/zimbra/bin/zmcertmgr viewdeployedcrt
    sudo -u zimbra /opt/zimbra/bin/zmcontrol restart
}

function post_hook
{
    echo "Removing redirection of the HTTP port..."
    iptables  -D INPUT -i eth0 -p tcp --dport $CERTBOT_HTTP_PORT -j ACCEPT
    ip6tables -D INPUT -i eth0 -p tcp --dport $CERTBOT_HTTP_PORT -j ACCEPT
    iptables  -t nat -D PREROUTING -i eth0 -p tcp --dport 80 -j REDIRECT --to-port $CERTBOT_HTTP_PORT
    ip6tables -t nat -D PREROUTING -i eth0 -p tcp --dport 80 -j REDIRECT --to-port $CERTBOT_HTTP_PORT
}

if [ "$1" == "pre" ]; then
    pre_hook
    exit 0
elif [ "$1" == "deploy" ]; then
    deploy_hook
    exit 0
elif [ "$1" == "post" ]; then
    post_hook
    exit 0
fi

certbot certonly -n \
    --standalone \
    --pre-hook "$SCRIPT_PATH pre" \
    --deploy-hook "$SCRIPT_PATH deploy" \
    --post-hook "$SCRIPT_PATH post" \
    --preferred-challenges http-01 \
    --http-01-port $CERTBOT_HTTP_PORT \
    --agree-tos \
    --email $EMAIL_ADDRESS \
    -d $HOSTNAME

#    --test-cert \
#    --force-renewal \
#    --break-my-certs \
