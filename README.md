# Docker Image with Zimbra 8.8.6 (FOSS Edition)

[![Build Status](https://travis-ci.org/cloudycube/docker-zimbra.svg?branch=master)](https://travis-ci.org/cloudycube/docker-zimbra) [![Docker 
Pulls](https://img.shields.io/docker/pulls/cloudycube/zimbra.svg)](https://hub.docker.com/r/cloudycube/zimbra) [![Github 
Stars](https://img.shields.io/github/stars/cloudycube/docker-zimbra.svg?label=github%20%E2%98%85)](https://github.com/cloudycube/docker-zimbra) [![Github 
Stars](https://img.shields.io/github/contributors/cloudycube/docker-zimbra.svg)](https://github.com/cloudycube/docker-zimbra) [![Github 
Forks](https://img.shields.io/github/forks/cloudycube/docker-zimbra.svg?label=github%20forks)](https://github.com/cloudycube/docker-zimbra)

## Overview

This image contains everything needed to download, setup and run the [Zimbra](https://www.zimbra.com/) colaboration suite. The image itself does not contain Zimbra. On the first start, the container installs a minimalistic Ubuntu 16.04 LTS onto a docker volume. This installation serves as the root filesystem for Zimbra, so Zimbra can work with the environment and everything is kept consistent and persistent - even if the container is updated. Although it is a docker container, it actually behaves more like a LXD container that integrates into the docker ecosystem. This also implys that you must take care of updating the Ubuntu installation and Zimbra regularly. Pulling a new image version **does not** automatically update the Ubuntu installation on the docker volume.

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

### Step 2 - Create a Volume for the Zimbra Container

The *zimbra* container installs a minimalistic Ubuntu 16.04 LTS and Zimbra onto a docker volume. You can create a named volume using the following command:

```
docker volume create zimbra-data
```

### Step 3 - Install Zimbra

Before installing Zimbra, you should ensure that your DNS contains the following records:
- An `A` record mapping the FQDN of the Zimbra container to the public IPv4 address of the docker host (e.g. zimbra.my-domain.com), the docker host maps the service ports to the container.
- An `AAAA` record mapping the FQDN of the Zimbra container to its public IPv6 address (e.g. zimbra.my-domain.com)
- A `MX` record with the hostname of the Zimbra container (as specified by the `A`/`AAAA` records)

The following command will install *Zimbra* onto the created volume. You will have the chance to customize Zimbra using Zimbra's menu-driven installation script. Please replace the hostname with the hostname you specified in the `A`/`AAAA` DNS records. Since the IPv4 address via which the container will be publicly accessable, is actually assigned to the docker host, the installation script will complain that there is a problem with the DNS. Just ignore the warning and proceed. It will be working at the end.

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

The command `run-and-enter` tell the container to open a shell within the container at the end. You can also directly enter the Ubuntu installation with Zimbra specifying `run-and-enter-zimbra`. The default command is `run`. It simply kicks off a script that initializes the container and waits for the container being stopped to initiate shutting down Zimbra (and related services) gracefully.

As soon as the manual configuration is done, you will most probably only run the container in background using the `run` command:
```
docker run --name zimbra \ 
           --detach \
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
           run
```

## Maintenance

The container installs a complete Ubuntu 16.04 LTS installation plus Zimbra onto the attached volume, if the volume is empty. This also means that running an updated docker image does not automatically update the installation on the volume. This must be done manually. You can get a shell in the container using the following command:

```
docker exec -it zimbra /bin/bash
```

The entire Ubuntu installation is kept in `/data`, so you need to *chroot* to dive into environment:

```
chroot /data /bin/bash
```

At this point you can - with some restrictions - work the installation as you would do with a regular Ubuntu installation. Some kernel calls are blocked by the docker's default *seccomp* profile, so you might need to adjust this. Furthermore *systemd* is not working, so you need to call init scripts directly to start/stop services.

First of all you should keep the Ubuntu installation up-to-date calling the following commands regularly:

```
apt-get update
apt-get upgrade
```

If a new Zimbra installation is available, you have to update it manually to ensure that customizations done since the initial setup are re-applied properly. A new image that would install a new version of Zimbra **WILL NOT** update an already existing installation.

## Improving Security

### Rejecting false "Mail From" addresses

Zimbra is configured to allow any sender address when receiving mail. This can be a security problem as an attacker could send mails to Zimbra users impersonating other users. The following links provide good guides to improve security:
- [Rejecting false "mail from" addresses](https://wiki.zimbra.com/wiki/Rejecting_false_%22mail_from%22_addresses)
- [Enforcing a match between FROM address and sasl username](https://wiki.zimbra.com/wiki/Enforcing_a_match_between_FROM_address_and_sasl_username_8.5)

To sum it up, you need to do the following things to reject false "mail from" addresses and allow authenticated users to use their own identities (mail adresses) only:

```
sudo -u zimbra /opt/zimbra/bin/zmprov mcf zimbraMtaSmtpdRejectUnlistedRecipient yes
sudo -u zimbra /opt/zimbra/bin/zmprov mcf zimbraMtaSmtpdRejectUnlistedSender yes
sudo -u zimbra /opt/zimbra/bin/zmprov mcf zimbraMtaSmtpdSenderLoginMaps proxy:ldap:/opt/zimbra/conf/ldap-slm.cf +zimbraMtaSmtpdSenderRestrictions reject_authenticated_sender_login_mismatch
```

Furthermore you need to edit the file `/opt/zimbra/conf/zmconfigd/smtpd_sender_restrictions.cf` and add `reject_sender_login_mismatch` after the `permit_mynetworks` line. It should look like the following:

```
%%exact VAR:zimbraMtaSmtpdSenderRestrictions reject_authenticated_sender_login_mismatch%%
%%contains VAR:zimbraMtaSmtpdSenderRestrictions check_sender_access lmdb:/opt/zimbra/conf/postfix_reject_sender%%
%%contains VAR:zimbraServiceEnabled cbpolicyd^ check_policy_service inet:localhost:%%zimbraCBPolicydBindPort%%%%
%%contains VAR:zimbraServiceEnabled amavis^ check_sender_access regexp:/opt/zimbra/common/conf/tag_as_originating.re%%
permit_mynetworks
reject_sender_login_mismatch
permit_sasl_authenticated
permit_tls_clientcerts
%%contains VAR:zimbraServiceEnabled amavis^ check_sender_access regexp:/opt/zimbra/common/conf/tag_as_foreign.re%%
```

The server needs to be restarted to apply the changes:

```
sudo -u zimbra /opt/zimbra/bin/zmcontrol restart
```
