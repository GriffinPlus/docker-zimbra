#!/bin/bash

case "$1" in
    start)
        /etc/init.d/rsyslog start
        /etc/init.d/cron start
        /etc/init.d/zimbra start
        ;;
    stop)
        /etc/init.d/zimbra stop
        /etc/init.d/cron stop
        /etc/init.d/rsyslog stop
        ;;
    reload)
        # TODO
        ;;
  esac
