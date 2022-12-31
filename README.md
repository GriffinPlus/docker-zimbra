---

## ATTENTION

This project is not developed any further.

---

# Docker Image with Zimbra 8.8.15 GA (FOSS Edition)

[![Build Status](https://dev.azure.com/griffinplus/Docker%20Images/_apis/build/status/14?branchName=master)](https://dev.azure.com/griffinplus/Docker%20Images/_build/latest?definitionId=14&branchName=master)
[![Docker Pulls](https://img.shields.io/docker/pulls/griffinplus/zimbra.svg)](https://hub.docker.com/r/griffinplus/zimbra)
[![Github Stars](https://img.shields.io/github/stars/griffinplus/docker-zimbra.svg?label=github%20%E2%98%85)](https://github.com/griffinplus/docker-zimbra)
[![Github Stars](https://img.shields.io/github/contributors/griffinplus/docker-zimbra.svg)](https://github.com/griffinplus/docker-zimbra) 
[![Github Forks](https://img.shields.io/github/forks/griffinplus/docker-zimbra.svg?label=github%20forks)](https://github.com/griffinplus/docker-zimbra)

## Overview

This image contains everything needed to download, setup and run the [Zimbra](https://www.zimbra.com/) collaboration suite. The image itself does not contain Zimbra. On the first start, the container installs a minimalistic Ubuntu 18.04 LTS onto a docker volume. This installation serves as the root filesystem for Zimbra, so Zimbra can work with the environment and everything is kept consistent and persistent - even if the container is updated. This also implies that pulling a new image version **does not** automatically update the Ubuntu installation on the docker volume. To reduce the chance of security issues, the container configures Ubuntu's *unattended upgrades* package to install official updates automatically. 

The container supports IPv6 with a global IPv6 address and configures packet filtering to block common attacks and access to non-public ports.

## Usage

Usage scenarios on how to deploy the Zimbra container on a *Docker* host or on *Kubernetes* can be found in the [wiki](https://github.com/GriffinPlus/docker-zimbra/wiki).

## Maintenance

The container installs a complete Ubuntu 18.04 LTS installation plus Zimbra onto the attached volume, if the volume is empty. This also means that running an updated docker image does not automatically update the installation on the volume. Nevertheless the installation is kept up-to-date as Ubuntu's *unattended upgrades* package installs official updates automatically. If you do not want the installation to be updated automatically, you can simply disable unattended upgrades by setting `APT::Periodic::Unattended-Upgrade "0";` in `/etc/apt/apt.conf.d/20auto-upgrades` after the installation has finished.

To install updates manually, you need to get a shell in the container using the following command:

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

By default Zimbra generates a self-signed certificate for TLS. As self-signed certificates are not trusted web browsers will complain about it. To use a certificate issued by a trusted certification authority (CA), you can tell the container to set it in by providing the private key at `/data/app/tls/zimbra.key` and the certificate at `/data/app/tls/zimbra.crt`. The container keeps track of changes to the certificate file and re-configures Zimbra, if necessary. Therefore it is recommended to mount a volume with the key and the certificate at `/data/app/tls` and use it for exchanging the certificate. The certificate *should* contain the certificate chain up to the root certificate. If a certificate of an intermediate CA or root CA is missing, the container will try to download the missing certificates using the *Authority Information Access* extension (if available).

Furthermore 4096 bit DH parameters are generated improving the security level of the key exchange.

#### HTTP Transport Security (HSTS)

If the container is *directly* connected to the internet (without a reverse proxy in between), HTTP Transport Security (HSTS) should be enabled to tell web browsers to connect to Zimbra over HTTPS only. This can be done as follows:

```
sudo -u zimbra -- /opt/zimbra/bin/zmprov mcf +zimbraResponseHeader "Strict-Transport-Security: max-age=31536000"
```

The configuration passes the popular SSL/TLS server tests:
- [SSL Labs](https://www.ssllabs.com/ssltest/) (supports HTTPS only)
- [Online Domain Tools](http://ssl-checker.online-domain-tools.com/) (supports HTTPS, SMTP, IMAP, POP)
- [High-Tech-Bridge](https://www.htbridge.com/ssl/) (supports HTTPS, SMTP, IMAP, POP)

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

Access to backend services, e.g. LDAP, MariaDB or the Jetty server, is blocked by the packet filter. Access to webmail via HTTP(S) as well as mail access via POP(S) and IMAP(S) are proxied by NGINX shipped with Zimbra adding an extra layer of security. If you keep the default settings when installing Zimbra using this image, secure inter-process communication will be enabled. You can disable this feature. It will speed up the overall system performance as Zimbra components communicate without encryption. This is not an issue as everything is running on the same host, even within the same container.

Furthermore the packet filter comes with a couple of rules protecting against common threats:
- TCP floods (except SYN floods)
- Bogus flags in TCP packets
- RH0 packets (can be used for DoS attacks)
- Ping of Death

### Mitigating Denial of Service (DoS) Attacks

#### HTTP Request Rate Limiting

Zimbra provides a simple mechanism to mitigate DoS attacks by rate-limiting HTTP requests per IP address.

At first the `zimbraHttpDosFilterDelayMillis` setting determines how to handle requests exceeding the rate-limit.
`-1` simply rejects the request (default). Any other positive value applys a delay (in ms) to the request to throttle it down. The setting can be configured as follows:

```
sudo -u zimbra -- zmprov mcf zimbraHttpDosFilterDelayMillis -1
```

The `zimbraHttpDosFilterMaxRequestsPerSec` setting determines the maximum number of requests that are allowed per second. The default value is `30`. The setting can be configured as follows:

```
sudo -u zimbra -- zmprov mcf zimbraHttpDosFilterMaxRequestsPerSec 30
```

At last the `zimbraHttpThrottleSafeIPs` setting determines IP addresses or IP address ranges (in CIDR notation) that should not be throttled. By default the whitelist is empty, but loopback adresses are always whitelisted. The setting can be configured as follows:

```
sudo -u zimbra -- zmprov mcf zimbraHttpThrottleSafeIPs 10.1.2.3/32 zimbraHttpThrottleSafeIPs 192.168.4.0/24
```

Alternatively you can add values to an existing list:

```
sudo -u zimbra -- zmprov mcf +zimbraHttpThrottleSafeIPs 10.1.2.3/32
sudo -u zimbra -- zmprov mcf +zimbraHttpThrottleSafeIPs 192.168.4.0/24
```

### Mitigating Brute Force Attacks

Zimbra comes with a mechanism that blocks IP addresses, if there are too many failed login attempts coming from the address. The default values are usually a good starting point, but depending on the deployment it might be useful to adjust the settings.

At first the `zimbraInvalidLoginFilterDelayInMinBetwnReqBeforeReinstating` setting determines the time (in minutes) to block an IP address that has caused too many login attempts. The default value is `15`. The setting can be adjusted as follows:

```
sudo -u zimbra -- zmprov mcf zimbraInvalidLoginFilterDelayInMinBetwnReqBeforeReinstating 15
```

The setting `zimbraInvalidLoginFilterMaxFailedLogin` determines the number of failed login attempts before an IP address gets blocked. The default value is `10`. It can be adjusted as follows:

```
sudo -u zimbra -- zmprov mcf zimbraInvalidLoginFilterMaxFailedLogin 10
```

At last the setting `zimbraInvalidLoginFilterReinstateIpTaskIntervalInMin` determines the interval (in minutes) betwen running the process to unblock IP addresses. The default value is `5`. Usually there is no need to tweak it, but it can be adjusted as follows:

```
sudo -u zimbra -- zmprov mcf zimbraInvalidLoginFilterReinstateIpTaskIntervalInMin 5
```

### Monitoring Authentication Activity

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
