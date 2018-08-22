# Docker Image with Zimbra 8.8.9 (FOSS Edition)

[![Build Status](https://travis-ci.org/cloudycube/docker-zimbra.svg?branch=master)](https://travis-ci.org/cloudycube/docker-zimbra) [![Docker 
Pulls](https://img.shields.io/docker/pulls/cloudycube/zimbra.svg)](https://hub.docker.com/r/cloudycube/zimbra) [![Github 
Stars](https://img.shields.io/github/stars/cloudycube/docker-zimbra.svg?label=github%20%E2%98%85)](https://github.com/cloudycube/docker-zimbra) [![Github 
Stars](https://img.shields.io/github/contributors/cloudycube/docker-zimbra.svg)](https://github.com/cloudycube/docker-zimbra) [![Github 
Forks](https://img.shields.io/github/forks/cloudycube/docker-zimbra.svg?label=github%20forks)](https://github.com/cloudycube/docker-zimbra)

## Overview

This image contains everything needed to download, setup and run the [Zimbra](https://www.zimbra.com/) colaboration suite. The image itself does not contain Zimbra. On the first start, the container installs a minimalistic Ubuntu 16.04 LTS onto a docker volume. This installation serves as the root filesystem for Zimbra, so Zimbra can work with the environment and everything is kept consistent and persistent - even if the container is updated. This also implys that you must take care of updating the Ubuntu installation and Zimbra regularly. Pulling a new image version **does not** automatically update the Ubuntu installation on the docker volume.

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

The command `run-and-enter` tells the container to open a shell within the container at the end. You can also directly enter the Ubuntu installation with Zimbra specifying `run-and-enter-zimbra`. The default command is `run`. It simply kicks off a script that initializes the container and waits for the container being stopped to initiate shutting down Zimbra (and related services) gracefully.

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

The entire Ubuntu installation is kept in `/data`, so you need to *chroot* to dive into the environment:

```
chroot /data /bin/bash
```

At this point you can - with some restrictions - work with the installation as you would do with a regular Ubuntu installation. Some kernel calls are blocked by the docker's default *seccomp* profile, so you might need to adjust this. Furthermore *systemd* is not working, so you need to call init scripts directly to start/stop services.

First of all you should keep the Ubuntu installation up-to-date calling the following commands regularly:

```
apt-get update
apt-get upgrade
```

If a new Zimbra installation is available, you have to update it manually to ensure that customizations done since the initial setup are re-applied properly. A new image that would install a new version of Zimbra **WILL NOT** update an already existing installation.

## Security

### Transport Security (TLS)

The container fetches free certificates from the *Let's Encrypt CA* and configures Zimbra to use them appropriately. At the moment only 2048 bit RSA certificates are supported. It supports cipher suites providing a reasonable level of security without sacrificing compatibility and speed only. Furthermore 4096 bit DH parameters are generated improving the security level of the key exchange. As long as Zimbra's proxy is enabled - which should always be the case - HTTP Transport Security (HSTS) is enabled to tell web browsers to connect to Zimbra over HTTPS only.

The configuration passes the popular SSL/TLS server tests:
- [SSL Labs](https://www.ssllabs.com/ssltest/) (supports HTTPS only)
- [Online Domain Tools](http://ssl-checker.online-domain-tools.com/) (supports HTTPS, SMTP, IMAP, POP)
- [High-Tech-Bridge](https://www.htbridge.com/ssl/) (supports HTTPS, SMTP, IMAP, POP)

Feel free to check your installation by yourself and open an issue, if there should be something wrong with the configuration. I will try to fix it as soon as possible.

### Firewall

The container configures the firewall allowing only the following services to be accessed from the public internet.

| Port     | Description                             |
| :------- | :-------------------------------------- |
| 25/tcp   | SMTP                                    |
| 80/tcp   | HTTP                                    |
| 110/tcp  | POP3                                    |
| 143/tcp  | IMAP                                    |
| 443/tcp  | HTTP over TLS                           |
| 465/tcp  | SMTP over SSL                           |
| 587/tcp  | SMTP (submission, for mail clients)     |
| 993/tcp  | IMAP over TLS                           |
| 995/tcp  | POP3 over TLS                           |
| 5222/tcp | XMPP                                    |
| 5223/tcp | XMPP (default legacy port)              |
| 7071/tcp | HTTPS (admin panel)                     |

Access to backend services, e.g. LDAP, MariaDB or the Jetty server, is blocked by the packet filter. Access to webmail or the admin panel via HTTP(S) as well as mail access via POP(S) and IMAP(S) are proxied by NGINX shipped with Zimbra adding an extra layer of security. If you keep the default settings when installing Zimbra using this image, inter-process communication will configured to work without encryption to speed up operation. This is not an issue as everything is running on the same host, even within the same container.

Furthermore the packet filter comes with a couple of rules protecting against common threats:
- TCP floods (except SYN floods)
- Bogus flags in TCP packets
- RH0 packets (can be used for DoS attacks)
- Ping of Death

### Brute Force Detection

The container configures Zimbra's brute-force detection *zmauditswatch*. It monitors authentication activity and sends an email to a configured recipient notifying the recipient of a possible attack. The default recipient is the administrator (as returned by `zmlocalconfig smtp_destination`). It does not block the attack!

The initial parameter set is as follows:

| Parameter                         | Value   | Description                       
| :-------------------------------- | :-----: | :--------------------------------------------------------------------------------------
| zimbra_swatch_notice_user         | *admin* | The email address of the person receiving notifications about possible brute-force attacks.
| zimbra_swatch_threshold_seconds   | 3600    | Detection time the thresholds below refer to (in seconds).
| zimbra_swatch_ipacct_threshold    | 10      | IP/Account hash check which warns on *xx* auth failures from an IP/Account combo within the specified time.
| zimbra_swatch_acct_threshold      | 15      | Account check which warns on *xx* auth failures from any IP within the specified time. Attempts to detect a distributed hijack based attack on a single account.
| zimbra_swatch_ip_threshold        | 20      | IP check which warns on *xx* auth failures to any account within the specified time. Attempts to detect a single host based attack across multiple accounts.
| zimbra_swatch_total_threshold     | 100     | Total auth failure check which warns on *xx* auth failures from any IP to any account within the specified time.

In most cases the parameters should be ok, but if you need to tune them, the following commands can be used to change the parameters:
```
sudo -u zimbra -- /opt/zimbra/bin/zmlocalconfig -e zimbra_swatch_notice_user=admin@my-domain.com
sudo -u zimbra -- /opt/zimbra/bin/zmlocalconfig -e zimbra_swatch_threshold_seconds=3600
sudo -u zimbra -- /opt/zimbra/bin/zmlocalconfig -e zimbra_swatch_ipacct_threshold=10
sudo -u zimbra -- /opt/zimbra/bin/zmlocalconfig -e zimbra_swatch_acct_threshold=15
sudo -u zimbra -- /opt/zimbra/bin/zmlocalconfig -e zimbra_swatch_ip_threshold=20
sudo -u zimbra -- /opt/zimbra/bin/zmlocalconfig -e zimbra_swatch_total_threshold=100
```

## Manual Adjustments Improving Security

### Enabling Domain Key Identified Mail (DKIM)

*Domain Keys Identified Mail (DKIM)* is an email authentication method designed to detect email spoofing. It allows the receiver to check that an email claimed to have come from a specific domain was indeed authorized by the owner of that domain. It is intended to prevent forged sender addresses in emails, a technique often used in phishing and email spam.

In technical terms, DKIM lets a domain associate its name with an email message by affixing a digital signature to it. Verification is carried out using the signer's public key published in the DNS. A valid signature guarantees that some parts of the email (possibly including attachments) have not been modified since the signature was affixed. Usually, DKIM signatures are not visible to end-users, and are affixed or verified by the infrastructure rather than message's authors and recipients. In that respect, DKIM differs from end-to-end digital signatures.

To enable DKIM signing you only need to run the following command (replace the domain name accordingly):

```
sudo -u zimbra -- /opt/zimbra/libexec/zmdkimkeyutil -a -d my-domain.com
```

This will create a 2048 bit RSA key and enable DKIM signing for the specified domain. To finish the configuration, the TXT record returned by `zmdkimkeyutil` must be published in your DNS. The name of the TXT record looks like the `AB6EFD30-2AA8-11E8-ACDA-A71CCC6989A6._domainkey` whereas `AB6EFD30-2AA8-11E8-ACDA-A71CCC6989A6` is the DKIM selector a message refers to. The value of the DKIM record looks like the following:

```
v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAmQ0nDvzpJn4b6nvvTDw2N0/Glcj24w0ZyTgNW1h5zNEEmxiH+7TuTcRvCVmBIHrY/anAtdiMZ60leQqo2USjI3ixE7Y1AewvjP95yS/WRq3Khoi7E2JsucreMcrf5WkVPsJd6G1Aw2uBGG/h/lyfjGYtpOjjnNqEb9Nxh3eMwATYNFUI55PVuTI405yR12SUPRomI2QvqiqTW2
```

After a few minutes you should be able to check whether DKIM signing works using the [DKIM Test](http://www.appmaildev.com/en/dkim). You will just have to send an email to the generated address and wait for the report.

### Sender Policy Framework (SPF)

*Sender Policy Framework (SPF)* is a simple email-validation system designed to detect email spoofing by providing a mechanism to allow receiving mail exchangers to check that incoming mail from a domain comes from a host authorized by that domain's administrators. The list of authorized sending hosts for a domain is published in the Domain Name System (DNS) records for that domain in the form of a specially formatted TXT record. Email spam and phishing often use forged "from" addresses, so publishing and checking SPF records can be considered anti-spam techniques.

To enable SPF you need to add a TXT record to your DNS. The name of the TXT record must be the name of the domain the SPF policy refers to. The value of the TXT record defines the policy. A simple, but effective policy is:

```
v=spf1 mx a ~all
```

This instructs other mail servers to accept mail from a mail server whose IP address is listed by `A` or `AAAA` records in the DNS of the same domain. Furthermore all mail exchangers of the domain (identified by `MX` records) are allowed to send mail for the domain. At the end `~all` tells other mail servers to treat violations of the policy as *soft fails*, i.e. the mail is tagged, but not rejected. This is primarily useful in conjunction with a DMARC policy (see below). The [SPF syntax documentation](http://www.openspf.org/SPF_Record_Syntax) shows how to craft a custom SPF policy.

A few minutes after setting the SPF record you can use one of the following tools to check it:
- [MxToolbox](https://mxtoolbox.com/spf.aspx)
- [Dmarcian SPF Surveyer](https://dmarcian.com/spf-survey/)

### Domain-based Message Authentication, Reporting and Conformance (DMARC)

*Domain-based Message Authentication, Reporting and Conformance (DMARC)* is an email-validation system designed to detect and prevent email spoofing. It is intended to combat certain techniques often used in phishing and email spam, such as emails with forged sender addresses that appear to originate from legitimate organizations. Specified in RFC 7489, DMARC counters the illegitimate usage of the exact domain name in the `From:` field of email message headers.

DMARC is built on top of the two mechanisms discussed above, *DomainKeys Identified Mail (DKIM)* and the *Sender Policy Framework (SPF)*. It allows the administrative owner of a domain to publish a policy on which mechanism (DKIM, SPF or both) is employed when sending email from that domain and how the receiver should deal with failures. Additionally, it provides a reporting mechanism of actions performed under those policies. It thus coordinates the results of DKIM and SPF and specifies under which circumstances the `From:` header field, which is often visible to end users, should be considered legitimate.

To enable DMARC you need to add a TXT record to your DNS. The name of the TXT record must be `_dmarc`. The value of the TXT record defines how mail servers receiving mail from your domain should act. A simple, but proven record is...

```
v=DMARC1; p=quarantine; rua=mailto:dmarc@my-domain.com; ruf=mailto:dmarc@my-domain.com; sp=quarantine
```

This instructs other mail servers to accept mails only, if the DKIM signature is present and valid and/or the SPF policy is met. If both checks fail, the mail should not be delivered and put aside (quarantined). Mail servers will send aggregate reports (`rua`) and forensic data (`ruf`) to `dmarc@my-domain.com`. The official [DMARC website](https://dmarc.org) provides a comprehensive documentation how DMARC works and how it can be configured to suit your needs (if you need more fine-grained control over DMARC parameters). [Kitterman's DMARC Assistent](http://www.kitterman.com/dmarc/assistant.html) helps with setting up a custom DMARC policy.

A few minutes after setting the DMARC record in your DNS, you can check it using one of the following tools:
- [MxToolbox](https://mxtoolbox.com/DMARC.aspx)
- [Dmarcian DMARC Inspector](https://dmarcian.com/dmarc-inspector/)
- [Proofpoint DMARC Check](https://stopemailfraud.proofpoint.com/dmarc/)

### Rejecting false "Mail From" addresses

Zimbra is configured to allow any sender address when receiving mail. This can be a security problem as an attacker could send mails to Zimbra users impersonating other users. The following links provide good guides to improve security:
- [Rejecting false "mail from" addresses](https://wiki.zimbra.com/wiki/Rejecting_false_%22mail_from%22_addresses)
- [Enforcing a match between FROM address and sasl username](https://wiki.zimbra.com/wiki/Enforcing_a_match_between_FROM_address_and_sasl_username_8.5)

To sum it up, you need to do the following things to reject false "mail from" addresses and allow authenticated users to use their own identities (mail adresses) only:

```
sudo -u zimbra -- /opt/zimbra/bin/zmprov mcf zimbraMtaSmtpdRejectUnlistedRecipient yes
sudo -u zimbra -- /opt/zimbra/bin/zmprov mcf zimbraMtaSmtpdRejectUnlistedSender yes
sudo -u zimbra -- /opt/zimbra/bin/zmprov mcf zimbraMtaSmtpdSenderLoginMaps proxy:ldap:/opt/zimbra/conf/ldap-slm.cf +zimbraMtaSmtpdSenderRestrictions reject_authenticated_sender_login_mismatch
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

**As all manual changes done to Zimbra's configuration files changes to `smtpd_sender_restrictions.cf` are overwritten when Zimbra is upgraded. The change must be re-applied after an upgrade!**

The server needs to be restarted to apply the changes:

```
sudo -u zimbra -- /opt/zimbra/bin/zmcontrol restart
```
