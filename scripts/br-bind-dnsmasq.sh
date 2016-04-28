#!/bin/bash

IFNAME=$1
DELETE=$2
PID="/run/lxc/dnsmasq-$IFNAME.pid"

if [ "$DELETE" == "delete" ] ; then
  kill $(cat $PID) && rm $PID && exit 0
fi

  # ifconfig the bridge (probably could use brctl, but this is a dumb workaround)
  ifconfig "$IFNAME" 
  if [ "$?" != "0" ] ; then
    continue;
  fi
  # it exists, is there a pid file and running pid for it?
  if [ -e "$PID" ] ; then
    ps $(cat $PID)
    if [ "$?" == "0" ] ; then
      echo "$IFNAME seems to have a dnsmasq running for it, skipping" && exit 0     
    fi
  fi

  INETLINE=$(ifconfig $IFNAME|grep 'inet addr:'|sed 's/inet addr:\([^ ]*\)[ ]*Bcast:[^ ]*[ ]*Mask:\([^ ]*\).*/\1 \2/')
  echo $INETLINE
  # cut the inet addr and the mask
  IFADDR=$(echo $INETLINE|cut -f1 -d ' ')
  echo $IFADDR
  MASK=$(echo $INETLINE|cut -f2 -d ' ')
  echo $MASK

  if [ "$MASK" != "255.255.255.0" ] ; then
    echo "I can only handle /24 addresses (mask is $MASK)" && exit 1
  fi

  # set the range
  range_highbits=$(echo $IFADDR|sed 's/\([0-9]*.[0-9]*.[0-9]*\)..*/\1/')
  RANGE="$range_highbits.10,$range_highbits.253"

  echo $RANGE
  # we got here because the bridge exists and needs a dnsmasq process, so make one
  dnsmasq -u lxc-dnsmasq --strict-order --bind-interfaces --pid-file=$PID \
      --conf-file= --listen-address $IFADDR --dhcp-range $RANGE --dhcp-lease-max=253 \
      --dhcp-no-override --except-interface=lo --interface=$IFNAME \
      --dhcp-leasefile=/var/lib/misc/dnsmasq.$IFNAME.leases --dhcp-authoritative

