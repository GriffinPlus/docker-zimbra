# UNDER DEVELOPMENT - ***DO NOT USE IN PRODUCTION***

---------------------------------------------------------------------------

# Docker Image with Zimbra 8.8.6 (FOSS Edition)

[![Build Status](https://travis-ci.org/cloudycube/docker-zimbra.svg?branch=master)](https://travis-ci.org/cloudycube/docker-zimbra) [![Docker 
Pulls](https://img.shields.io/docker/pulls/cloudycube/zimbra.svg)](https://hub.docker.com/r/cloudycube/zimbra) [![Github 
Stars](https://img.shields.io/github/stars/cloudycube/docker-zimbra.svg?label=github%20%E2%98%85)](https://github.com/cloudycube/docker-zimbra) [![Github 
Stars](https://img.shields.io/github/contributors/cloudycube/docker-zimbra.svg)](https://github.com/cloudycube/docker-zimbra) [![Github 
Forks](https://img.shields.io/github/forks/cloudycube/docker-zimbra.svg?label=github%20forks)](https://github.com/cloudycube/docker-zimbra)

## Overview

This image contains everything needed to download, setup and run the [Zimbra](https://www.zimbra.com/) colaboration suite. The image itself does not contain Zimbra. On the first start, the container installs a minimalistic Ubuntu 16.04 LTS onto a docker volume. This installation serves as the root filesystem for Zimbra, so Zimbra can modify the installation and everything is kept consistent and persistent - even if the container is updated. This also implys that you must take care of updating the Ubuntu installation and Zimbra regularly. Pulling a new image version **does not** automatically update the Ubuntu installation on the docker volume.

## Usage

The container needs your docker host to have IPv6 up and running. A global IPv6 address is needed as well. Please see [here](https://docs.docker.com/engine/userguide/networking/default_network/ipv6/) for details on how to enable IPv6 support.

### Step 1 - Configuring a User-Defined Network

If you do not already have an user-defined network for public services, you can create a simple bridge network (called *frontend* in the example below) and define the subnets, from which docker will allocate ip addresses for containers. Most probably you will have only one IPv4 address for your server, so you should choose a subnet from the site-local ranges (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16). Docker takes care of connecting published services to the public IPv4 address of the server. Any IPv6 enabled server today has at least a /64 subnet assigned, so any single container can have its own IPv6 address, network address translation (NAT) is not necessary. Therefore you should choose an IPv6 subnet that is part of the subnet assigned to your server. Docker recommends to use a subnet of at least /80, so it can assign IP addresses by ORing the (virtual) MAC address of the container with the specified subnet.
```
docker network create -d bridge \
  --subnet 192.168.0.0/24 \
  --subnet 2001:xxxx:xxxx:xxxx::/80 \
  --ipv6 \
  frontend
```

### Step 1 - Create a Volume for the Zimbra Container

The *zimbra* container installs a minimalistic Ubuntu 16.04 LTS and Zimbra onto a docker volume. You can create a named volume using the following command:

```
docker volume create zimbra-data
```

### Step 2 - Install Zimbra

Before installing Zimbra, you should ensure that your DNS contains the following records:
- An `A` record mapping the FQDN of the Zimbra container to its public IPv4 address (e.g. zimbra.my-domain.com)
- An `AAAA` record mapping the FQDN of the Zimbra container to its public IPv6 address (e.g. zimbra.my-domain.com)
- A `MX` record with the hostname of the Zimbra container (as specified by the `A`/`AAAA` records)

The following command will install *Zimbra* onto the created volume. You will have the chance to customize Zimbra using Zimbra's menu-driven installation script. Please replace the hostname with the hostname you specified in the `A`/`AAAA` DNS records. The installation will take several minutes.

```
docker run -it \
           --rm \
           --ip6=2001:xxxx:xxxx:xxxx::2 \
           --network frontend \
           --hostname zimbra.my-domain.com \
           -p 25:25 \
           -p 80:80 \
           -p 110:110 \
           -p 143:143 \
           -p 443:443 \
           -p 465:465 \
           -p 587:587 \
           -p 993:993 \
           -p 995:995 \
           -p 5222:5222 \
           -p 5223:5223 \
           -p 7071:7071 \
           --volume zimbra-data:/data \
           --cap-add NET_ADMIN \
           --cap-add SYS_ADMIN \
           --cap-add SYS_PTRACE \
           --security-opt apparmor=unconfined \
           cloudycube/zimbra \
           run-and-enter
```

The container needs a few additional capabilities to work properly. The `NET_ADMIN` capability is needed to configure network interfaces and the *iptables* firewall. The `SYS_ADMIN` capability is needed to set up the chrooted environment where Zimbra is working. The `SYS_PTRACE` capability is needed to get *rsyslog* to start/stop properly. Furthermore *AppArmor* protection must be disabled to set up the chrooted environment as well.
