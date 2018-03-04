#!/bin/bash

ZIMBRA_ENVIRONMENT_PATH="/data"

function prepare_chroot
{
    mount -o bind /dev $ZIMBRA_ENVIRONMENT_PATH/dev
    mount -o bind /dev/pts $ZIMBRA_ENVIRONMENT_PATH/dev/pts
    mount -t sysfs /sys $ZIMBRA_ENVIRONMENT_PATH/sys
    mount -t proc /proc $ZIMBRA_ENVIRONMENT_PATH/proc
    cp /proc/mounts $ZIMBRA_ENVIRONMENT_PATH/etc/mtab
    cp /etc/hosts $ZIMBRA_ENVIRONMENT_PATH/etc
    mount -o bind /etc/hosts $ZIMBRA_ENVIRONMENT_PATH/etc/hosts
    mount -o bind /etc/hostname $ZIMBRA_ENVIRONMENT_PATH/etc/hostname
    mount -o bind /etc/resolv.conf $ZIMBRA_ENVIRONMENT_PATH/etc/resolv.conf
    cp /app/control-zimbra.sh $ZIMBRA_ENVIRONMENT_PATH/app/
    chmod 750 $ZIMBRA_ENVIRONMENT_PATH/app/control-zimbra.sh
}

function shutdown_chroot
{
    umount $ZIMBRA_ENVIRONMENT_PATH/etc/resolv.conf
    umount $ZIMBRA_ENVIRONMENT_PATH/etc/hostname
    umount $ZIMBRA_ENVIRONMENT_PATH/etc/hosts
    umount $ZIMBRA_ENVIRONMENT_PATH/proc
    umount $ZIMBRA_ENVIRONMENT_PATH/sys
    umount $ZIMBRA_ENVIRONMENT_PATH/dev/pts
    umount $ZIMBRA_ENVIRONMENT_PATH/dev
}

function setup_environment
{
    if [ -z "$(ls -A $ZIMBRA_ENVIRONMENT_PATH)" ]; then

        echo "Installing minimalistic Ubuntu 16.04 LTS (Xenial)..."
        debootstrap --variant=minbase --arch=amd64 xenial /data http://archive.ubuntu.com/ubuntu/

        echo "Installing Zimbra..."
        mkdir -p $ZIMBRA_ENVIRONMENT_PATH/app
        cp /app/install-zimbra.sh $ZIMBRA_ENVIRONMENT_PATH/app/
        chmod 750 $ZIMBRA_ENVIRONMENT_PATH/app/install-zimbra.sh
        prepare_chroot
        chroot $ZIMBRA_ENVIRONMENT_PATH /app/install-zimbra.sh # starts services at the end...
        chroot $ZIMBRA_ENVIRONMENT_PATH /app/control-zimbra.sh stop
        shutdown_chroot

    fi
}

function setup_signals
{
  cid="$1"; shift
  handler="$1"; shift
  for sig; do
    trap "$handler '$cid' '$sig'" "$sig"
  done
}

# initially the zimbra is not running...
running=0

function handle_signal
{
  # echo "Received signal: $2"
  case "$2" in
    SIGINT|SIGTERM)
      # echo "Shutting down Zimbra..."
      chroot $ZIMBRA_ENVIRONMENT_PATH /app/control-zimbra.sh stop
      running=0
      ;;
    SIGHUP)
      # echo "Reloading Zimbra configuration..."
      chroot $ZIMBRA_ENVIRONMENT_PATH /app/control-zimbra.sh reload
      ;;
  esac
}

setup_signals "$1" "handle_signal" SIGINT SIGTERM SIGHUP


# install Ubuntu + Zimbra into /data
setup_environment "$@"
if [ $? -ne 0 ]; then exit $?; fi

# prepare the chroot environment
if [ "$$" = "1" ]; then
    prepare_chroot
fi


if [ "$1" = 'run' ]; then

    # start Zimbra processes
    running=1
    chroot $ZIMBRA_ENVIRONMENT_PATH /app/control-zimbra.sh start

    # wait for signals
    # echo "Waiting for signals..."
    while [ $running -ne 0 ]; do
        tail -f /dev/null & wait ${!}
    done
    # echo "Stopped waiting for signals..."

elif [ "$1" = 'run-and-enter' ]; then

    # start Zimbra processes and a shell
    running=1
    chroot $ZIMBRA_ENVIRONMENT_PATH /app/control-zimbra.sh start
    chroot $ZIMBRA_ENVIRONMENT_PATH /bin/bash -c "/bin/bash && kill $$" 0<&0 1>&1 2>&2 &

    # wait for signals
    # echo "Waiting for signals..."
    while [ $running -ne 0 ]; do
        tail -f /dev/null & wait ${!}
    done
    # echo "Stopped waiting for signals..."

elif [ $# -gt 0 ]; then

    # parameters were specified
    # => interpret parameters as regular command
    chroot $ZIMBRA_ENVIRONMENT_PATH "$@"

fi


# shut chroot down
if [ "$$" = "1" ]; then
    shutdown_chroot
fi

