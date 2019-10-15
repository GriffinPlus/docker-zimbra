#!/bin/bash

export HOST_IPV4="78.47.33.233"                   # ipv4 of docker host (maps the ports to the container)
export ZIMBRA_IPV6="2a01:4f8:c2c:f025:d000::2"    # ipv6 of container (directly accessable from the internet)
export ZIMBRA_HOSTNAME="zimbra2.griffin.plus"     # FQDN of container (as specified in the DNS)
export ZIMBRA_ADMIN_EMAIL="admin@zimbra2.griffin.plus"
export FRONTEND_IPV4_SUBNET="192.168.10.0/24"
export FRONTEND_IPV4_GATEWAY="192.168.10.1"
export FRONTEND_IPV6_SUBNET="2a01:4f8:c2c:f025:d000::/80"
export FRONTEND_IPV6_GATEWAY="2a01:4f8:c2c:f025:d000::1"

docker-compose $@
