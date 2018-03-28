#!/bin/bash

set -e

case "$1" in
    start)
        /etc/init.d/rsyslog start
        /etc/init.d/cron start
        /etc/init.d/ssh start
        /etc/init.d/zimbra start
        sudo -u zimbra -- /opt/zimbra/bin/zmauditswatchctl start
        ;;
    stop)
        sudo -u zimbra -- /opt/zimbra/bin/zmauditswatchctl stop
        /etc/init.d/zimbra stop
        /etc/init.d/ssh stop
        /etc/init.d/cron stop
        /etc/init.d/rsyslog stop
        ;;
    reload)
        # TODO
        ;;
  esac

