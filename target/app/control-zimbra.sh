#!/bin/bash

case "$1" in

    start)
        /etc/init.d/rsyslog start
        /etc/init.d/cron start
        /etc/init.d/ssh start

        if [ ! -f "/.dont_start_zimbra" ]; then

            # start Zimbra services
            /etc/init.d/zimbra start
            sudo -u zimbra -- /opt/zimbra/bin/zmauditswatchctl start

            # stop the certificate updater service, if it is running
            if [ -f "/run/tls-cert-updater.pid" ]; then
                TLS_UPDATER_PID=`cat /run/tls-cert-updater.pid`
                kill $TLS_UPDATER_PID > /dev/null 2>&1
                rm -f /run/tls-cert-updater.pid
            fi

            # start the certificate updater service (needs Zimbra to be running)
            /bin/bash -c '
                source /app/venv/bin/activate
                python3 /app/tls-cert-updater.py &> /var/log/tls-cert-updater.py &
                echo -n $! > /run/tls-cert-updater.pid
            '
        fi
        ;;

    stop)
        # stop the certificate updater service
        if [ -f "/run/tls-cert-updater.pid" ]; then
            TLS_UPDATER_PID=`cat /run/tls-cert-updater.pid`
            kill $TLS_UPDATER_PID > /dev/null 2>&1
            rm -f /run/tls-cert-updater.pid
        fi

        # stop Zimbra services
        if [ ! -f "/.dont_start_zimbra" ]; then
            sudo -u zimbra -- /opt/zimbra/bin/zmauditswatchctl stop
            /etc/init.d/zimbra stop
        fi

        /etc/init.d/ssh stop
        /etc/init.d/cron stop
        /etc/init.d/rsyslog stop
        ;;

    reload)
        # TODO
        ;;
  esac
