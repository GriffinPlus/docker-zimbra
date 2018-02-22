FROM cloudycube/base-supervisor
MAINTAINER Sascha Falk <sascha@falk-online.eu>

ENV ZIMBRA_DOWNLOAD_URL="https://files.zimbra.com/downloads/8.8.6_GA/zcs-8.8.6_GA_1906.UBUNTU16_64.20171130041047.tgz"
ENV ZIMBRA_DOWNLOAD_HASH="8a83e67df40bc0e396d5178980531dbca89a81b648891c1667c53a02486a110e"

# Update image and install additional packages
# -----------------------------------------------------------------------------
RUN \
  # install packages
  apt-get -y update && \
  apt-get -y install \
    anacron \
    net-tools && \
  \
  # download zimbra
  mkdir /install && \
  cd /install && \
  wget -O /install/zcs.tgz $ZIMBRA_DOWNLOAD_URL && \
  CALC_HASH=`sha256sum zcs.tgz | cut -d ' ' -f1` && \
  if [ "$CALC_HASH" != "$ZIMBRA_DOWNLOAD_HASH" ]; then echo "Downloaded file is corrupt!" && exit 1; fi && \
  \
  # clean up
  apt-get -y autoremove && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/*

# Copy prepared files into the image
# -----------------------------------------------------------------------------
COPY target /

# Volumes
# -----------------------------------------------------------------------------
VOLUME [ "/opt/zimbra" ]

# Expose ports
# -----------------------------------------------------------------------------
# 25/tcp   - SMTP (for incoming mail)
# 110/tcp  - POP3
# 143/tcp  - IMAP
# 443/tcp  - HTTP over TLS (for web mail clients)
# 465/tcp  - SMTP over SSL (for mail clients)
# 587/tcp  - SMTP (submission, for mail clients)
# 993/tcp  - IMAP over TLS (for mail clients)
# 995/tcp  - POP3 over TLS (for mail clients)
# 5222/tcp - XMPP
# 5223/tcp - XMPP (default legacy port)
# -----------------------------------------------------------------------------
EXPOSE 25 110 143 443 465 587 993 995 5222 5223

