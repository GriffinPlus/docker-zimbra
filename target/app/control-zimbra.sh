#!/bin/bash

set -e

case "$1" in
    start)
        /etc/init.d/rsyslog start
        /etc/init.d/cron start
        /etc/init.d/ssh start
        /etc/init.d/zimbra start
        ;;
    stop)
        /etc/init.d/zimbra stop
        /etc/init.d/ssh stop
        /etc/init.d/cron stop
        /etc/init.d/rsyslog stop
        ;;
    reload)
        # TODO
        ;;
  esac

