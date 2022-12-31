# Deploying Zimbra with Letsencrypt 

This example shows how to deploy the Zimbra container along with Jason Wilder's [nginx-proxy](https://github.com/jwilder/nginx-proxy)
and Yves Blusseau's [letsencrypt-nginx-proxy-companion](https://github.com/JrCs/docker-letsencrypt-nginx-proxy-companion) to run Zimbra with free X.509 certificates issued by the Letsencrypt certificate authority.

## Howto

### Step 1) Adjust Settings

The `docker-compose-wrapper.sh` script contains site-specific settings you have to adjust according to your own environment.
The script contains comments to assist with configuring the script properly.

### Step 2) Install Zimbra

After adjusting the site-specific settings, you can install Zimbra:

```
./docker-compose-wrapper.sh run --rm zimbra
```

The installation script will then download the required files, start Zimbra's menu-driven installation script and ask for
accepting the license agreement. Just answer Y to proceed.

```
Checking for existing installation...
    zimbra-drive...NOT FOUND
    zimbra-imapd...NOT FOUND
    zimbra-patch...NOT FOUND
    zimbra-mta-patch...NOT FOUND
    zimbra-proxy-patch...NOT FOUND
    zimbra-license-tools...NOT FOUND
    zimbra-license-extension...NOT FOUND
    zimbra-network-store...NOT FOUND
    zimbra-network-modules-ng...NOT FOUND
    zimbra-chat...NOT FOUND
    zimbra-talk...NOT FOUND
    zimbra-ldap...NOT FOUND
    zimbra-logger...NOT FOUND
    zimbra-mta...NOT FOUND
    zimbra-dnscache...NOT FOUND
    zimbra-snmp...NOT FOUND
    zimbra-store...NOT FOUND
    zimbra-apache...NOT FOUND
    zimbra-spell...NOT FOUND
    zimbra-convertd...NOT FOUND
    zimbra-memcached...NOT FOUND
    zimbra-proxy...NOT FOUND
    zimbra-archiving...NOT FOUND
    zimbra-core...NOT FOUND


----------------------------------------------------------------------
PLEASE READ THIS AGREEMENT CAREFULLY BEFORE USING THE SOFTWARE.
SYNACOR, INC. ("SYNACOR") WILL ONLY LICENSE THIS SOFTWARE TO YOU IF YOU
FIRST ACCEPT THE TERMS OF THIS AGREEMENT. BY DOWNLOADING OR INSTALLING
THE SOFTWARE, OR USING THE PRODUCT, YOU ARE CONSENTING TO BE BOUND BY
THIS AGREEMENT. IF YOU DO NOT AGREE TO ALL OF THE TERMS OF THIS
AGREEMENT, THEN DO NOT DOWNLOAD, INSTALL OR USE THE PRODUCT.

License Terms for this Zimbra Collaboration Suite Software:
https://www.zimbra.com/license/zimbra-public-eula-2-6.html
----------------------------------------------------------------------



Do you agree with the terms of the software license agreement? [N] y
```

Next Zimbra asks whether to use the package repository. Just accept it:

```
Use Zimbra's package repository [Y] y

Warning: apt-key output should not be parsed (stdout is not a terminal)
Importing Zimbra GPG key

Configuring package repository

Checking for installable packages

Found zimbra-core (local)
Found zimbra-ldap (local)
Found zimbra-logger (local)
Found zimbra-mta (local)
Found zimbra-dnscache (local)
Found zimbra-snmp (local)
Found zimbra-store (local)
Found zimbra-apache (local)
Found zimbra-spell (local)
Found zimbra-memcached (repo)
Found zimbra-proxy (local)
Found zimbra-drive (repo)
Found zimbra-imapd (local)
Found zimbra-patch (repo)
Found zimbra-mta-patch (repo)
Found zimbra-proxy-patch (repo)
```

Now the installation script wants to know which packages to install. You can safely install everything, but
`zimbra-dnscache` and beta features. The DNS cache would otherwise conflict with the already running dnsmasq
the container runs itself to provide a split-horizon DNS for Zimbra.

```
Select the packages to install

Install zimbra-ldap [Y] y

Install zimbra-logger [Y] y

Install zimbra-mta [Y] y

Install zimbra-dnscache [Y] n

Install zimbra-snmp [Y] y

Install zimbra-store [Y] y

Install zimbra-apache [Y] y

Install zimbra-spell [Y] y

Install zimbra-memcached [Y] y

Install zimbra-proxy [Y] y

Install zimbra-drive [Y] y

Install zimbra-imapd (BETA - for evaluation only) [N] n

Install zimbra-chat [Y] y
Checking required space for zimbra-core
Checking space for zimbra-store
Checking required packages for zimbra-store
zimbra-store package check complete.

Installing:
    zimbra-core
    zimbra-ldap
    zimbra-logger
    zimbra-mta
    zimbra-snmp
    zimbra-store
    zimbra-apache
    zimbra-spell
    zimbra-memcached
    zimbra-proxy
    zimbra-drive
    zimbra-patch
    zimbra-mta-patch
    zimbra-proxy-patch
    zimbra-chat

The system will be modified.  Continue? [N] y
```

After committing to continue there is no way back as the installation script modifies the system. If something goes
wrong, it might leave the environment in an inconsistent state that can not be repaired by simply running the installer
once again. In this case, simply shut the container down, clear the persistent volume and start over once again.

The installer now tells what it is doing:

```
Beginning Installation - see /tmp/install.log.il8yiBAj for details...

                          zimbra-core-components will be downloaded and installed.
                            zimbra-timezone-data will be installed.
                           zimbra-common-mbox-db will be installed.
                         zimbra-common-mbox-docs will be installed.
                          zimbra-common-core-jar will be installed.
                         zimbra-common-mbox-conf will be installed.
                    zimbra-common-mbox-conf-msgs will be installed.
                   zimbra-common-mbox-conf-attrs will be installed.
                   zimbra-common-mbox-native-lib will be installed.
                  zimbra-common-mbox-conf-rights will be installed.
                         zimbra-common-core-libs will be installed.
                                     zimbra-core will be installed.
                          zimbra-ldap-components will be downloaded and installed.
                                     zimbra-ldap will be installed.
                                   zimbra-logger will be installed.
                           zimbra-mta-components will be downloaded and installed.
                                      zimbra-mta will be installed.
                          zimbra-snmp-components will be downloaded and installed.
                                     zimbra-snmp will be installed.
                         zimbra-store-components will be downloaded and installed.
                       zimbra-jetty-distribution will be downloaded and installed.
                                 zimbra-mbox-war will be installed.
                                zimbra-mbox-conf will be installed.
                             zimbra-mbox-service will be installed.
                       zimbra-mbox-webclient-war will be installed.
                          zimbra-mbox-store-libs will be installed.
                   zimbra-mbox-admin-console-war will be installed.
                                    zimbra-store will be installed.
                        zimbra-apache-components will be downloaded and installed.
                                   zimbra-apache will be installed.
                         zimbra-spell-components will be downloaded and installed.
                                    zimbra-spell will be installed.
                                zimbra-memcached will be downloaded and installed.
                         zimbra-proxy-components will be downloaded and installed.
                                    zimbra-proxy will be installed.
                                    zimbra-drive will be downloaded and installed (later).
                                    zimbra-patch will be downloaded and installed (later).
                                zimbra-mta-patch will be downloaded and installed (later).
                              zimbra-proxy-patch will be downloaded and installed (later).
                                     zimbra-chat will be downloaded and installed (later).


Downloading packages (10):
   zimbra-core-components
   zimbra-ldap-components
   zimbra-mta-components
   zimbra-snmp-components
   zimbra-store-components
   zimbra-jetty-distribution
   zimbra-apache-components
   zimbra-spell-components
   zimbra-memcached
   zimbra-proxy-components
      ...done

Removing /opt/zimbra
Removing zimbra crontab entry...done.
Cleaning up zimbra init scripts...done.
Cleaning up /etc/security/limits.conf...done.

Finished removing Zimbra Collaboration Server.

Installing repo packages (10):
   zimbra-core-components
   zimbra-ldap-components
   zimbra-mta-components
   zimbra-snmp-components
   zimbra-store-components
   zimbra-jetty-distribution
   zimbra-apache-components
   zimbra-spell-components
   zimbra-memcached
   zimbra-proxy-components
      ...done

Installing local packages (25):
   zimbra-timezone-data
   zimbra-common-mbox-db
   zimbra-common-mbox-docs
   zimbra-common-core-jar
   zimbra-common-mbox-conf
   zimbra-common-mbox-conf-msgs
   zimbra-common-mbox-conf-attrs
   zimbra-common-mbox-native-lib
   zimbra-common-mbox-conf-rights
   zimbra-common-core-libs
   zimbra-core
   zimbra-ldap
   zimbra-logger
   zimbra-mta
   zimbra-snmp
   zimbra-mbox-war
   zimbra-mbox-conf
   zimbra-mbox-service
   zimbra-mbox-webclient-war
   zimbra-mbox-store-libs
   zimbra-mbox-admin-console-war
   zimbra-store
   zimbra-apache
   zimbra-spell
   zimbra-proxy
      ...done

Installing extra packages (5):
   zimbra-drive
   zimbra-patch
   zimbra-mta-patch
   zimbra-proxy-patch
   zimbra-chat
      ...done

Running Post Installation Configuration:
Operations logged to /tmp/zmsetup.20191015-163028.log
Installing LDAP configuration database...done.
Setting defaults...
```

Then the installer complains about the domain not having a proper MX record in the DNS. Nevertheless, the split-horizon
DNS is configured correctly, so the domain part of the FQDN set in the EXTERNAL_HOST_FQDN is set in the MX record.
Simply adjust the domain name appropriately. It will work at the end.

```
DNS ERROR resolving MX for zimbra.my-domain.com
It is suggested that the domain name have an MX record configured in DNS
Change domain name? [Yes] Y
Create domain: [zimbra.my-domain.com] my-domain.com

DNS ERROR resolving MX for my-domain.com
It is suggested that the domain name have an MX record configured in DNS
Re-Enter domain name? [Yes] n
done.
Checking for port conflicts
```

Now the installer comes up with the menu-driven configuration.

```
Main menu

   1) Common Configuration:
   2) zimbra-ldap:                             Enabled
   3) zimbra-logger:                           Enabled
   4) zimbra-mta:                              Enabled
   5) zimbra-snmp:                             Enabled
   6) zimbra-store:                            Enabled
        +Create Admin User:                    yes
        +Admin user to create:                 admin@my-company.com
******* +Admin Password                        UNSET
        +Anti-virus quarantine user:           virus-quarantine.evok1gr4_@my-comain.com
        +Enable automated spam training:       yes
        +Spam training user:                   spam.es2woawrlq@my-comain.com
        +Non-spam(Ham) training user:          ham.da0n07ip@my-domain.com
        +SMTP host:                            zimbra.my-domain.com
        +Web server HTTP port:                 8080
        +Web server HTTPS port:                8443
        +Web server mode:                      https
        +IMAP server port:                     7143
        +IMAP server SSL port:                 7993
        +POP server port:                      7110
        +POP server SSL port:                  7995
        +Use spell check server:               yes
        +Spell server URL:                     http://zimbra.my-domain.com:7780/aspell.php
        +Enable version update checks:         TRUE
        +Enable version update notifications:  TRUE
        +Version update notification email:    admin@my-domain.com
        +Version update source email:          admin@my-domain.com
        +Install mailstore (service webapp):   yes
        +Install UI (zimbra,zimbraAdmin webapps): yes

   7) zimbra-spell:                            Enabled
   8) zimbra-proxy:                            Enabled
   9) Default Class of Service Configuration:
   s) Save config to file
   x) Expand menu
   q) Quit

Address unconfigured (**) items  (? - help)
```

Enter menu 6 first to set the admin password:

```
Store configuration

   1) Status:                                  Enabled
   2) Create Admin User:                       yes
   3) Admin user to create:                    admin@my-domain.com
** 4) Admin Password                           UNSET
   5) Anti-virus quarantine user:              virus-quarantine.evok1gr4_@my-domain.com
   6) Enable automated spam training:          yes
   7) Spam training user:                      spam.es2woawrlq@my-domain.com
   8) Non-spam(Ham) training user:             ham.da0n07ip@my-domain.com
   9) SMTP host:                               zimbra.my-domain.com
  10) Web server HTTP port:                    8080
  11) Web server HTTPS port:                   8443
  12) Web server mode:                         https
  13) IMAP server port:                        7143
  14) IMAP server SSL port:                    7993
  15) POP server port:                         7110
  16) POP server SSL port:                     7995
  17) Use spell check server:                  yes
  18) Spell server URL:                        http://zimbra.my-domain.com:7780/aspell.php
  19) Enable version update checks:            TRUE
  20) Enable version update notifications:     TRUE
  21) Version update notification email:       admin@my-domain.com
  22) Version update source email:             admin@my-domain.com
  23) Install mailstore (service webapp):      yes
  24) Install UI (zimbra,zimbraAdmin webapps): yes

Select, or 'r' for previous menu [r] 4

Password for admin@my-company.com (min 6 characters): [_O1zGgc8c] my-password

Store configuration

   ...

Select, or 'r' for previous menu [r] r

Main menu

   1) Common Configuration:
   2) zimbra-ldap:                             Enabled
   3) zimbra-logger:                           Enabled
   4) zimbra-mta:                              Enabled
   5) zimbra-snmp:                             Enabled
   6) zimbra-store:                            Enabled
   7) zimbra-spell:                            Enabled
   8) zimbra-proxy:                            Enabled
   9) Default Class of Service Configuration:
   s) Save config to file
   x) Expand menu
   q) Quit

*** CONFIGURATION COMPLETE - press 'a' to apply
Select from menu, or press 'a' to apply config (? - help)
```

Running the Zimbra container with the nginx-proxy requires some more adjustments.

#### Menu 1: Common Configuration

The entire Zimbra system is installed within the container. There are no external Zimbra components, so there is no
need to use encrypted communication between Zimbra components. It is safe to set `Secure interprocess communications`
to `no`. Furthermore you should set `Timezone` according to your location and `IP Mode` to `both` if you intend to
make Zimbra accessable via IPv4 and IPv6.

```
Common configuration

   1) Hostname:                                zimbra.my-company.com
   2) Ldap master host:                        zimbra.my-company.com
   3) Ldap port:                               389
   4) Ldap Admin password:                     set
   5) Store ephemeral attributes outside Ldap: no
   6) Secure interprocess communications:      no
   7) TimeZone:                                Europe/Berlin
   8) IP Mode:                                 both
   9) Default SSL digest:                      sha256

Select, or 'r' for previous menu [r]
```



#### Menu 8: zimbra-proxy

The Zimbra container is about to run behind a reverse-proxy in front of *zimbra-store*, respectively the web service part
of it. You should disable Zimbra's own NGINX HTTP[S] proxy in this menu, because running two reverse proxys in a line
causes redirection loops. The nginx-proxy will directly proxy requests to the *Jetty* web service. Furthermore you should
set `strict server name enforcement` to `no` to allow the web service to be accessed without restricting the server name to
configured virtual domains.

This step should be done **before** configuring the *zimbra-store* as disabling the proxy influences the web service settings.

```
Proxy configuration

   1) Status:                                  Enabled
   2) Enable POP/IMAP Proxy:                   TRUE
   3) Enable strict server name enforcement?   no
   4) IMAP proxy port:                         143
   5) IMAP SSL proxy port:                     993
   6) POP proxy port:                          110
   7) POP SSL proxy port:                      995
   8) Bind password for nginx ldap user:       set
   9) Enable HTTP[S] Proxy:                    FALSE

Select, or 'r' for previous menu [r]
```

#### Menu 6: zimbra-store

In this menu you should set `Web server mode` to `both` to enable the reverse-proxy to proxy requests to the web service.
Although using `http` should be enough, it does not work...

```
Store configuration

   1) Status:                                  Enabled
   2) Create Admin User:                       yes
   3) Admin user to create:                    admin@my-company.com
   4) Admin Password                           set
   5) Anti-virus quarantine user:              virus-quarantine.evok1gr4_@my-company.com
   6) Enable automated spam training:          yes
   7) Spam training user:                      spam.es2woawrlq@my-company.com
   8) Non-spam(Ham) training user:             ham.da0n07ip@my-company.com
   9) SMTP host:                               zimbra.my-company.com
  10) Web server HTTP port:                    80
  11) Web server HTTPS port:                   443
  12) Web server mode:                         both
  13) IMAP server port:                        7143
  14) IMAP server SSL port:                    7993
  15) POP server port:                         7110
  16) POP server SSL port:                     7995
  17) Use spell check server:                  yes
  18) Spell server URL:                        http://zimbra.my-company.com:7780/aspell.php
  19) Enable version update checks:            TRUE
  20) Enable version update notifications:     TRUE
  21) Version update notification email:       admin@my-company.com
  22) Version update source email:             admin@my-company.com
  23) Install mailstore (service webapp):      yes
  24) Install UI (zimbra,zimbraAdmin webapps): yes
```

Back in the Main Menu the configuration can be applied:

```
Main menu

   1) Common Configuration:
   2) zimbra-ldap:                             Enabled
   3) zimbra-logger:                           Enabled
   4) zimbra-mta:                              Enabled
   5) zimbra-snmp:                             Enabled
   6) zimbra-store:                            Enabled
   7) zimbra-spell:                            Enabled
   8) zimbra-proxy:                            Enabled
   9) Default Class of Service Configuration:
   s) Save config to file
   x) Expand menu
   q) Quit

*** CONFIGURATION COMPLETE - press 'a' to apply
Select from menu, or press 'a' to apply config (? - help) a
Save configuration data to a file? [Yes] y
Save config in file: [/opt/zimbra/config.21601]
Saving config in /opt/zimbra/config.21601...done.
The system will be modified - continue? [No] y
Operations logged to /tmp/zmsetup.20191015-163028.log
Setting local config values...done.
Initializing core config...Setting up CA...done.
Deploying CA to /opt/zimbra/conf/ca ...done.
Creating SSL zimbra-store certificate...done.
Creating new zimbra-ldap SSL certificate...done.
Creating new zimbra-mta SSL certificate...done.
Creating new zimbra-proxy SSL certificate...done.
Installing mailboxd SSL certificates...done.
Installing MTA SSL certificates...done.
Installing LDAP SSL certificate...done.
Installing Proxy SSL certificate...done.
Initializing ldap...done.
Setting replication password...done.
Setting Postfix password...done.
Setting amavis password...done.
Setting nginx password...done.
Setting BES searcher password...done.
Creating server entry for zimbra.my-company.com...done.
Setting Zimbra IP Mode...done.
Saving CA in ldap...done.
Saving SSL Certificate in ldap...done.
Setting spell check URL...done.
Setting service ports on zimbra.my-company.com...done.
Setting zimbraFeatureTasksEnabled=TRUE...done.
Setting zimbraFeatureBriefcasesEnabled=TRUE...done.
Checking current setting of zimbraReverseProxyAvailableLookupTargets
Querying LDAP for other mailstores
Searching LDAP for reverseProxyLookupTargets...done.
Adding zimbra.my-company.com to zimbraReverseProxyAvailableLookupTargets
Updating zimbraLDAPSchemaVersion to version '1557224584'
Setting TimeZone Preference...done.
Disabling strict server name enforcement on zimbra.my-company.com...done.
Initializing mta config...done.
Setting services on zimbra.my-company.com...done.
Adding zimbra.my-company.com to zimbraMailHostPool in default COS...done.
Creating domain zimbra.my-company.com...done.
Setting default domain name...done.
Creating domain zimbra.my-company.com...already exists.
Creating admin account admin@zimbra.my-company.com...done.
Creating root alias...done.
Creating postmaster alias...done.
Creating user spam.es2woawrlq@my-company.com...done.
Creating user ham.da0n07ip@my-company.com...done.
Creating user virus-quarantine.evok1gr4_@my-company.com...done.
Setting spam training and Anti-virus quarantine accounts...done.
Initializing store sql database...done.
Setting zimbraSmtpHostname for zimbra.my-company.com...done.
Configuring SNMP...done.
Setting up syslog.conf...done.
Starting servers...done.
Installing common zimlets...
        com_zimbra_viewmail...done.
        com_zimbra_attachmail...done.
        com_zimbra_srchhighlighter...done.
        com_zimbra_bulkprovision...done.
        com_zimbra_email...done.
        com_zimbra_date...done.
        com_zimbra_mailarchive...done.
        com_zimbra_proxy_config...done.
        com_zimbra_phone...done.
        com_zimbra_ymemoticons...done.
        com_zextras_drive_open...done.
        com_zextras_chat_open...done.
        com_zimbra_clientuploader...done.
        com_zimbra_webex...done.
        com_zimbra_url...done.
        com_zimbra_adminversioncheck...done.
        com_zimbra_cert_manager...done.
        com_zimbra_tooltip...done.
        com_zimbra_attachcontacts...done.
Finished installing common zimlets.
Restarting mailboxd...done.
Creating galsync account for default domain...done.

You have the option of notifying Zimbra of your installation.
This helps us to track the uptake of the Zimbra Collaboration Server.
The only information that will be transmitted is:
        The VERSION of zcs installed (8.8.15_GA_3869_UBUNTU18_64)
        The ADMIN EMAIL ADDRESS created (admin@my-company.com)

Notify Zimbra of your installation? [Yes] y
Checking if the NG started running...done.
Setting up zimbra crontab...done.


Moving /tmp/zmsetup.20191015-163028.log to /opt/zimbra/log


Configuration complete - press return to exit

```

Of course, it's up to you to register the installation.

After registering the Zimbra installation the installation script will perform a few common automatic configuration steps:

Install brute-force detector auditswatch
Generate a 4096 bit prime to use as DH parameters

```
Retrieving some information needed for further steps...
- Admin e-mail address: admin@my-company.com

Configuring Zimbra's brute-force detector (auditswatch) to send notifications to admin@my-company.com...
--2019-10-15 18:08:30--  http://bugzilla-attach.zimbra.com/attachment.cgi?id=66723
Resolving bugzilla-attach.zimbra.com (bugzilla-attach.zimbra.com)... 3.208.5.102, 3.211.235.155
Connecting to bugzilla-attach.zimbra.com (bugzilla-attach.zimbra.com)|3.208.5.102|:80... connected.
HTTP request sent, awaiting response... 200 OK
Length: 35695 (35K) [application/x-perl]
Saving to: 'auditswatch'

auditswatch                                                 100%[========================================================================================================================================>]  34.86K  --.-KB/s    in 0.09s

2019-10-15 18:08:31 (400 KB/s) - 'auditswatch' saved [35695/35695]

/opt/zimbra/conf/auditswatchrc is missing.
Starting auditswatch...done.

Removing Zimbra installation files...
removed '/install/zcs/README.txt'
removed '/install/zcs/data/versions-init.sql'
removed directory '/install/zcs/data'
removed '/install/zcs/util/addUser.sh'
removed '/install/zcs/util/utilfunc.sh'
removed '/install/zcs/util/globals.sh'
removed '/install/zcs/util/modules/postinstall.sh'
removed '/install/zcs/util/modules/getconfig.sh'
removed '/install/zcs/util/modules/packages.sh'
removed directory '/install/zcs/util/modules'
removed directory '/install/zcs/util'
removed '/install/zcs/.BUILD_RELEASE_CANDIDATE'
removed '/install/zcs/.BUILD_TIME_STAMP'
removed '/install/zcs/readme_binary_en_US.txt'
removed '/install/zcs/.BUILD_RELEASE_NO'
removed '/install/zcs/.BUILD_PLATFORM'
removed '/install/zcs/bin/zmValidateLdap.pl'
removed '/install/zcs/bin/zmdbintegrityreport'
removed '/install/zcs/bin/checkService.pl'
removed '/install/zcs/bin/checkLicense.pl'
removed '/install/zcs/bin/get_plat_tag.sh'
removed directory '/install/zcs/bin'
removed '/install/zcs/docs/zcl.txt'
removed '/install/zcs/docs/en_US/Import_Wizard_Outlook.pdf'
removed '/install/zcs/docs/en_US/admin.pdf'
removed '/install/zcs/docs/en_US/Zimbra iCalendar Migration Guide.pdf'
removed '/install/zcs/docs/en_US/Migration_Exch_Admin.pdf'
removed '/install/zcs/docs/en_US/Fedora Server Config.pdf'
removed '/install/zcs/docs/en_US/User Instructions for ZCS Import Wizard.pdf'
removed '/install/zcs/docs/en_US/MigrationWizard_Domino.pdf'
removed '/install/zcs/docs/en_US/quick_start.pdf'
removed '/install/zcs/docs/en_US/OSmultiserverinstall.pdf'
removed '/install/zcs/docs/en_US/MigrationWizard.pdf'
removed '/install/zcs/docs/en_US/RNZCSO_2005Beta.pdf'
removed '/install/zcs/docs/en_US/zimbra_user_guide.pdf'
removed directory '/install/zcs/docs/en_US'
removed directory '/install/zcs/docs'
removed directory '/install/zcs/lib/jars'
removed directory '/install/zcs/lib'
removed '/install/zcs/.BUILD_TYPE'
removed '/install/zcs/install.sh'
removed '/install/zcs/packages/zimbra-mbox-conf_8.8.15.1568012813-1.u18_amd64.deb'
removed '/install/zcs/packages/zimbra-mbox-admin-console-war_8.8.15.1566392834-1.u18_amd64.changes'
removed '/install/zcs/packages/zimbra-mbox-store-libs_8.8.15.1562583874-1.u18_amd64.deb'
removed '/install/zcs/packages/zimbra-timezone-data_2.0.1+1570028338-1.u18_amd64.deb'
removed '/install/zcs/packages/zimbra-mbox-conf_8.8.15.1568012813-1.u18_amd64.changes'
removed '/install/zcs/packages/zimbra-logger_8.8.15.GA.3869.UBUNTU18.64_amd64.deb'
removed '/install/zcs/packages/zimbra-dnscache_8.8.15.GA.3869.UBUNTU18.64_amd64.deb'
removed '/install/zcs/packages/Packages'
removed '/install/zcs/packages/zimbra-mbox-service_8.8.15.1568694943-1.u18_amd64.deb'
removed '/install/zcs/packages/zimbra-mbox-admin-console-war_8.8.15.1566392834-1.u18_amd64.deb'
removed '/install/zcs/packages/zimbra-common-mbox-conf_8.8.15.1568694943-1.u18_amd64.changes'
removed '/install/zcs/packages/zimbra-common-mbox-conf-msgs_8.8.15.1556130968-1.u18_amd64.changes'
removed '/install/zcs/packages/zimbra-mbox-store-libs_8.8.15.1562583874-1.u18_amd64.changes'
removed '/install/zcs/packages/zimbra-common-mbox-conf-attrs_8.8.15.1558767359-1.u18_amd64.changes'
removed '/install/zcs/packages/zimbra-mbox-service_8.8.15.1568694943-1.u18_amd64.changes'
removed '/install/zcs/packages/zimbra-common-mbox-conf-rights_8.8.15.1487328490-1.u18_amd64.changes'
removed '/install/zcs/packages/zimbra-common-mbox-native-lib_8.8.15.1521095672-1.u18_amd64.changes'
removed '/install/zcs/packages/zimbra-imapd_8.8.15.GA.3869.UBUNTU18.64_amd64.deb'
removed '/install/zcs/packages/zimbra-mta_8.8.15.GA.3869.UBUNTU18.64_amd64.deb'
removed '/install/zcs/packages/zimbra-common-mbox-conf_8.8.15.1568694943-1.u18_amd64.deb'
removed '/install/zcs/packages/zimbra-common-core-jar_8.8.15.1568694943-1.u18_amd64.deb'
removed '/install/zcs/packages/zimbra-common-mbox-conf-rights_8.8.15.1487328490-1.u18_amd64.deb'
removed '/install/zcs/packages/zimbra-apache_8.8.15.GA.3869.UBUNTU18.64_amd64.deb'
removed '/install/zcs/packages/zimbra-common-core-libs_8.8.15.1562583874-1.u18_amd64.changes'
removed '/install/zcs/packages/zimbra-mbox-webclient-war_8.8.15.1567495075-1.u18_amd64.changes'
removed '/install/zcs/packages/zimbra-common-core-jar_8.8.15.1568694943-1.u18_amd64.changes'
removed '/install/zcs/packages/zimbra-common-mbox-conf-msgs_8.8.15.1556130968-1.u18_amd64.deb'
removed '/install/zcs/packages/zimbra-common-mbox-db_8.8.15.1568694943-1.u18_amd64.deb'
removed '/install/zcs/packages/zimbra-snmp_8.8.15.GA.3869.UBUNTU18.64_amd64.deb'
removed '/install/zcs/packages/zimbra-common-mbox-native-lib_8.8.15.1521095672-1.u18_amd64.deb'
removed '/install/zcs/packages/zimbra-common-mbox-docs_8.8.15.1552677786-1.u18_amd64.deb'
removed '/install/zcs/packages/zimbra-mbox-war_8.8.15.1568694943-1.u18_amd64.changes'
removed '/install/zcs/packages/zimbra-mbox-webclient-war_8.8.15.1567495075-1.u18_amd64.deb'
removed '/install/zcs/packages/zimbra-ldap_8.8.15.GA.3869.UBUNTU18.64_amd64.deb'
removed '/install/zcs/packages/zimbra-common-mbox-docs_8.8.15.1552677786-1.u18_amd64.changes'
removed '/install/zcs/packages/zimbra-common-mbox-db_8.8.15.1568694943-1.u18_amd64.changes'
removed '/install/zcs/packages/zimbra-common-core-libs_8.8.15.1562583874-1.u18_amd64.deb'
removed '/install/zcs/packages/zimbra-core_8.8.15.GA.3869.UBUNTU18.64_amd64.deb'
removed '/install/zcs/packages/zimbra-proxy_8.8.15.GA.3869.UBUNTU18.64_amd64.deb'
removed '/install/zcs/packages/zimbra-spell_8.8.15.GA.3869.UBUNTU18.64_amd64.deb'
removed '/install/zcs/packages/zimbra-mbox-war_8.8.15.1568694943-1.u18_amd64.deb'
removed '/install/zcs/packages/zimbra-common-mbox-conf-attrs_8.8.15.1558767359-1.u18_amd64.deb'
removed '/install/zcs/packages/zimbra-store_8.8.15.GA.3869.UBUNTU18.64_amd64.deb'
removed directory '/install/zcs/packages'
removed '/install/zcs/.BUILD_NUM'
removed directory '/install/zcs'
removed directory '/install/auditswatch'
removed '/install/zcs.tgz'
removed directory '/install'

Adding Zimbra's Perl include path to search path...

Generating stronger DH parameters (4096 bit)...
Generating DH parameters, 4096 bit long safe prime, generator 2
This is going to take a long time
..................
..................
..................

zmdhparam: saving 'zimbraSSLDHParam' via zmprov modifyConfig

Configuring cipher suites (as strong as possible without breaking compatibility and sacrificing speed)...

Configuring default COS to use selected persona in the Return-Path of the mail envelope (important for privacy).

Installing mail utilities to enable unattended-upgrades to send notifications.
(Can be done after installing Zimbra only as bsd-mailx pulls in postfix that conflicts with the postfix package deployed by Zimbra.)
Reading package lists... Done
Building dependency tree
Reading state information... Done
The following additional packages will be installed:
  liblockfile-bin liblockfile1
The following NEW packages will be installed:
  bsd-mailx liblockfile-bin liblockfile1
0 upgraded, 3 newly installed, 0 to remove and 0 not upgraded.
Need to get 84.7 kB of archives.
After this operation, 249 kB of additional disk space will be used.
Get:1 http://archive.ubuntu.com/ubuntu bionic/main amd64 liblockfile-bin amd64 1.14-1.1 [11.9 kB]
Get:2 http://archive.ubuntu.com/ubuntu bionic/main amd64 liblockfile1 amd64 1.14-1.1 [6804 B]
Get:3 http://archive.ubuntu.com/ubuntu bionic/main amd64 bsd-mailx amd64 8.1.2-0.20160123cvs-4 [66.0 kB]
Fetched 84.7 kB in 0s (634 kB/s)
debconf: delaying package configuration, since apt-utils is not installed
Selecting previously unselected package liblockfile-bin.
(Reading database ... 51888 files and directories currently installed.)
Preparing to unpack .../liblockfile-bin_1.14-1.1_amd64.deb ...
Unpacking liblockfile-bin (1.14-1.1) ...
Selecting previously unselected package liblockfile1:amd64.
Preparing to unpack .../liblockfile1_1.14-1.1_amd64.deb ...
Unpacking liblockfile1:amd64 (1.14-1.1) ...
Selecting previously unselected package bsd-mailx.
Preparing to unpack .../bsd-mailx_8.1.2-0.20160123cvs-4_amd64.deb ...
Unpacking bsd-mailx (8.1.2-0.20160123cvs-4) ...
Setting up liblockfile-bin (1.14-1.1) ...
Setting up liblockfile1:amd64 (1.14-1.1) ...
Setting up bsd-mailx (8.1.2-0.20160123cvs-4) ...
update-alternatives: using /usr/bin/bsd-mailx to provide /usr/bin/mailx (mailx) in auto mode
Processing triggers for libc-bin (2.27-3ubuntu1) ...

Restarting services...
Host zimbra.my-company.com
        Stopping zmconfigd...Done.
        Stopping zimlet webapp...Done.
        Stopping zimbraAdmin webapp...Done.
        Stopping zimbra webapp...Done.
        Stopping service webapp...Done.
        Stopping stats...Done.
        Stopping mta...Done.
        Stopping spell...Done.
        Stopping snmp...Done.
        Stopping cbpolicyd...Done.
        Stopping archiving...Done.
        Stopping opendkim...Done.
        Stopping amavis...Done.
        Stopping antivirus...Done.
        Stopping antispam...Done.
        Stopping proxy...Done.
        Stopping memcached...Done.
        Stopping mailbox...Done.
        Stopping logger...Done.
        Stopping dnscache...Done.
        Stopping ldap...Done.
 * Starting enhanced syslogd rsyslogd                                                                                                                                                                                                 [ OK ]
 * Starting periodic command scheduler cron                                                                                                                                                                                           [ OK ]
 * Starting OpenBSD Secure Shell server sshd                                                                                                                                                                                          [ OK ]
Host zimbra.my-company.com
        Starting ldap...Done.
        Starting zmconfigd...Done.
        Starting logger...Done.
        Starting mailbox...Done.
        Starting memcached...Done.
        Starting proxy...Done.
        Starting amavis...Done.
        Starting antispam...Done.
        Starting antivirus...Done.
        Starting opendkim...Done.
        Starting snmp...Done.
        Starting spell...Done.
        Starting mta...Done.
        Starting stats...Done.
        Starting service webapp...Done.
        Starting zimbra webapp...Done.
        Starting zimbraAdmin webapp...Done.
        Starting zimlet webapp...Done.
Starting auditswatch...done.
Stopping auditswatch...done.
Host zimbra.my-company.com
        Stopping zmconfigd...Done.
        Stopping zimlet webapp...Done.
        Stopping zimbraAdmin webapp...Done.
        Stopping zimbra webapp...Done.
        Stopping service webapp...Done.
        Stopping stats...Done.
        Stopping mta...Done.
        Stopping spell...Done.
        Stopping snmp...Done.
        Stopping cbpolicyd...Done.
        Stopping archiving...Done.
        Stopping opendkim...Done.
        Stopping amavis...Done.
        Stopping antivirus...Done.
        Stopping antispam...Done.
        Stopping proxy...Done.
        Stopping memcached...Done.
        Stopping mailbox...Done.
        Stopping logger...Done.
        Stopping dnscache...Done.
        Stopping ldap...Done.
 * Stopping OpenBSD Secure Shell server sshd                                                                                                                                                                                          [ OK ]
 * Stopping periodic command scheduler cron                                                                                                                                                                                           [ OK ]
 * Stopping enhanced syslogd rsyslogd
```

Now Zimbra should be fully functional. You can run Zimbra along with the reverse proxy as follows:

```
./docker-compose-wrapper.sh up
```

If nginx-proxy is working correctly, you should reach the Zimbra web interface as expected at port 80 (HTTP)
and/or 443 (HTTPS). The admin console should be accessable via HTTPS at port 7071.

Have Fun!
