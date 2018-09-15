#!/bin/bash

# This script starts a new instance of the griffinplus/zimbra container and opens a shell in it.
# It is useful in cases where some debugging is needed...

IPV4="aaa.bbb.ccc.ddd"              # ipv4 of docker host (maps the ports to the container)
IPV6="2001:xxxx:yyyy:zzzz::2"       # ipv6 of container (directly accessable from the internet)
NETWORK="frontend"                  # name of the network the container will be connected to
HOSTNAME="zimbra.my-domain.com"     # FQDN of container (as specified in the DNS)

# create a named volume that will store a complete Ubuntu 16.04 LTS and Zimbra
docker volume create zimbra-data

# run the container
docker run -it \
           --rm \
           --ip6 $IPV6 \
           --network $NETWORK \
           --hostname $HOSTNAME \
           -p $IPV4:25:25 \
           -p $IPV4:80:80 \
           -p $IPV4:110:110 \
           -p $IPV4:143:143 \
           -p $IPV4:443:443 \
           -p $IPV4:465:465 \
           -p $IPV4:587:587 \
           -p $IPV4:993:993 \
           -p $IPV4:995:995 \
           -p $IPV4:5222:5222 \
           -p $IPV4:5223:5223 \
           -p $IPV4:7071:7071 \
           --volume zimbra-data:/data \
           --cap-add NET_ADMIN \
           --cap-add SYS_ADMIN \
           --cap-add SYS_PTRACE \
           --security-opt apparmor=unconfined \
           griffinplus/zimbra \
           run-and-enter
