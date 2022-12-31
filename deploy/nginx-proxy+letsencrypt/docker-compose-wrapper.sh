#!/bin/bash

export HOST_IPV4="x.x.x.x"                               # ipv4 of docker host (maps the ports to the container)
export ZIMBRA_IPV6="x:x:x:x:x::x"                        # ipv6 of container (directly accessable from the internet)
export ZIMBRA_HOSTNAME="zimbra.my-company.com"           # FQDN of container (as specified in the DNS)
export ZIMBRA_ADMIN_EMAIL="admin@zimbra.my-company.com"
export FRONTEND_IPV4_SUBNET="x.x.x.x/24"
export FRONTEND_IPV4_GATEWAY="x.x.x.x"
export FRONTEND_IPV6_SUBNET="x:x:x:x:x::/80"
export FRONTEND_IPV6_GATEWAY="x:x:x:x:x::x"

docker-compose $@
