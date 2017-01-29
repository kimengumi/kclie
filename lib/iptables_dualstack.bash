#!/bin/bash
#
# Kimengumi Command Line Interface Environnement
#
# Dual Stack ipv4/ipv6 iptables Library
#
# Copyright 2017 Antonio Rossetti (https://www.kimengumi.fr)
#
# Licensed under the EUPL, Version 1.1 or – as soon they will be approved by
# the European Commission - subsequent versions of the EUPL (the "Licence");
# You may not use this work except in compliance with the Licence.
# You may obtain a copy of the Licence at:
#
# https://joinup.ec.europa.eu/software/page/eupl
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the Licence is distributed on an "AS IS" basis,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the Licence for the specific language governing permissions and
# limitations under the Licence.

export ip4t=/sbin/iptables # executable iptables
export ip6t=/sbin/ip6tables # executable ip6tables

# DEFAULT CONFIGURATION (can be overrident after sourcing)

export HOST_SSH_PORT="22"

export EXTERNAL_IF="eth1"

export LOCAL_IF="eth0"
export LOCAL_IP4_NETWORK="192.168.0.0/16"     # could be more than the local subnet (if VPN connected example)
export LOCAL_IP6_NETWORK="fd85:e1b1:e282::/48"  # could be more than the local subnet (if VPN connected example)
export LOCAL_IP4_PREFIX="192.168.1."          # used to write Ips in the local subnet
export LOCAL_IP6_PREFIX="fd85:e1b1:e282:1::"  # used to write Ips in the local subnet

# Reset tables and allow ssh to host
DualBasicRules () {

  echo "reseting ip4/6 tables ..."

  $ip4t -P INPUT ACCEPT
  $ip4t -P OUTPUT ACCEPT
  $ip4t -P FORWARD ACCEPT
  $ip4t -F
  $ip4t -X
  $ip4t -t nat -F
  $ip4t -t nat -X
  $ip4t -t mangle -F
  $ip4t -t mangle -X
  $ip6t -P INPUT ACCEPT
  $ip6t -P OUTPUT ACCEPT
  $ip6t -P FORWARD ACCEPT
  $ip6t -F
  $ip6t -X
  $ip6t -t nat -F
  $ip6t -t nat -X
  $ip6t -t mangle -F
  $ip6t -t mangle -X

  echo "Applying ip4/6 safe rules ..."

  # SSH autorisé dans tout les cas, de partout
  $ip4t -A INPUT -j ACCEPT -p tcp --dport ${HOST_SSH_PORT}
  $ip6t -A INPUT -j ACCEPT -p tcp --dport ${HOST_SSH_PORT}

  # Multicast
  $ip6t -A INPUT -j ACCEPT -d ff00::/8

  # Neighbor Solicitation & Advertisement
  $ip6t -A INPUT -j ACCEPT -p icmpv6 --icmpv6-type 135 # Neighbor Solicitation
  $ip6t -A INPUT -j ACCEPT -p icmpv6 --icmpv6-type 136 # Neighbor Advertisement

  # Limit ping
  $ip4t -A INPUT -j ACCEPT -p icmp --icmp-type 8 -m limit --limit 5/sec --limit-burst 10
  $ip6t -A INPUT -j ACCEPT -p icmpv6 --icmpv6-type 128 -m limit --limit 5/sec --limit-burst 10

  # Protection contre l'IP spoofing
  if [ -e /proc/sys/net/ipv4/conf/all/rp_filter ] ; then
          for f in /proc/sys/net/ipv4/conf/*/rp_filter
          do
                  echo 1 > $f
          done
  fi

  echo "Applying ip4/6 local rules ..."

  # LOCAL HOST
  $ip4t -A INPUT -j ACCEPT -i lo
  $ip6t -A INPUT -j ACCEPT -i lo

  # LOCAL NET
  $ip4t -A INPUT -j ACCEPT -i ${LOCAL_IF} -s ${LOCAL_IP4_NETWORK}
  $ip6t -A INPUT -j ACCEPT -i ${LOCAL_IF} -s ${LOCAL_IP6_NETWORK}
  $ip4t -A FORWARD -j ACCEPT -i ${LOCAL_IF} -s ${LOCAL_IP4_NETWORK}
  $ip6t -A FORWARD -j ACCEPT -i ${LOCAL_IF} -s ${LOCAL_IP6_NETWORK}

  # LOCAL NAT OUTPUT
  $ip4t -A POSTROUTING -t nat -j ACCEPT -s ${LOCAL_IP4_NETWORK} -d ${LOCAL_IP4_NETWORK}
  $ip6t -A POSTROUTING -t nat -j ACCEPT -s ${LOCAL_IP6_NETWORK} -d ${LOCAL_IP6_NETWORK}
  $ip4t -A POSTROUTING -t nat -j MASQUERADE -s ${LOCAL_IP4_NETWORK} -o ${EXTERNAL_IF}
  $ip6t -A POSTROUTING -t nat -j MASQUERADE -s ${LOCAL_IP6_NETWORK} -o ${EXTERNAL_IF}

}

DualHttpNat () {

  if [ "x$1" = "x" ] ; then
    echo "Usage: DualHttpNat [End of local ip4/6]"
    return 1
  fi
  END_IP=$1
  echo "Redirecting Http/Https to ${LOCAL_IP4_PREFIX}${END_IP} / ${LOCAL_IP6_PREFIX}${END_IP} ..."

  $ip4t -A PREROUTING -t nat -j DNAT -i ${EXTERNAL_IF} -p tcp --dport 80 --to ${LOCAL_IP4_PREFIX}${END_IP}:80
  $ip4t -A PREROUTING -t nat -j DNAT -i ${EXTERNAL_IF} -p tcp --dport 443 --to ${LOCAL_IP4_PREFIX}${END_IP}:443
  $ip4t -A FORWARD -j DROP   -p tcp --dport 80 -m string --to 70 --algo bm --string 'GET /w00tw00t.at.ISC.SANS.'
  $ip4t -A FORWARD -j ACCEPT -p tcp -d ${LOCAL_IP4_PREFIX}${END_IP} --dport 80
  $ip4t -A FORWARD -j ACCEPT -p tcp -d ${LOCAL_IP4_PREFIX}${END_IP} --dport 443

  $ip6t -A PREROUTING -t nat -j DNAT -i ${EXTERNAL_IF} -p tcp --dport 80  --to [${LOCAL_IP6_PREFIX}${END_IP}]:80
  $ip6t -A PREROUTING -t nat -j DNAT -i ${EXTERNAL_IF} -p tcp --dport 443 --to [${LOCAL_IP6_PREFIX}${END_IP}]:443
  $ip6t -A FORWARD -j DROP   -p tcp --dport 80 -m string --to 70 --algo bm --string 'GET /w00tw00t.at.ISC.SANS.'
  $ip6t -A FORWARD -j ACCEPT -p tcp -d ${LOCAL_IP6_PREFIX}${END_IP} --dport 80
  $ip6t -A FORWARD -j ACCEPT -p tcp -d ${LOCAL_IP6_PREFIX}${END_IP} --dport 443

}

DualCustomNat () {

  if [ "x$1" = "x" ] || [ "x$2" = "x" ] || [ "x$3" = "x" ] || [ "x$4" = "x" ]; then
    echo "Usage: DualCustomNat [tcp/udp] [External Port] [Local Port] [End of local ip4/6]"
    return 1
  fi
  TYPE=$1
  DPORT=$2
  LPORT=$3
  END_IP=$4

  echo "Redirecting port ${DPORT} (${TYPE}) TO ${LOCAL_IP4_PREFIX}${END_IP} / ${LOCAL_IP6_PREFIX}${END_IP} port ${LPORT} ..."

  $ip4t -A PREROUTING -t nat -j DNAT -i ${EXTERNAL_IF} -p ${TYPE} --dport ${DPORT} --to ${LOCAL_IP4_PREFIX}${END_IP}:${LPORT}
  $ip4t -A FORWARD -j ACCEPT -p tcp -d ${LOCAL_IP4_PREFIX}${END_IP} --dport ${LPORT}

  $ip6t -A PREROUTING -t nat -j DNAT -i ${EXTERNAL_IF} -p ${TYPE} --dport ${DPORT}  --to [${LOCAL_IP6_PREFIX}${END_IP}]:${LPORT}
  $ip6t -A FORWARD -j ACCEPT -p tcp -d ${LOCAL_IP6_PREFIX}${END_IP} --dport ${LPORT}

}

DualSshNat () {

  if [ "x$1" = "x" ] || [ "x$2" = "x" ] || [ "x$3" = "x" ] ; then
    echo "Usage: DualSshNat [extrenal port prefix] [First End of local ip4/6] [Last End of local ip4/6]"
    return 1
  fi
  DPREFIX=$1
  FIRST_END_IP=$2
  LAST_END_IP=$3

  echo "Redirecting SSH ports ${DPREFIX}XXX FROM (ip-prefix)${FIRST_END_IP} TO (ip-prefix)${LAST_END_IP}"

  for i in `seq -w ${FIRST_END_IP} ${LAST_END_IP}` ; do
          $ip4t -A PREROUTING -t nat -j DNAT -i ${EXTERNAL_IF} -p tcp --dport ${DPREFIX}$i --to ${LOCAL_IP4_PREFIX}${i}:22
          $ip4t -A FORWARD -j ACCEPT -p tcp -d ${LOCAL_IP4_PREFIX}${i} --dport 22
          $ip6t -A PREROUTING -t nat -j DNAT -i ${EXTERNAL_IF} -p tcp --dport ${DPREFIX}$i --to [${LOCAL_IP6_PREFIX}${i}]:22
          $ip6t -A FORWARD -j ACCEPT -p tcp -d ${LOCAL_IP6_PREFIX}${i} --dport 22
  done
}

OvhMonitoring () {

  if [ "x$1" = "x" ] ; then
    echo "Usage: OvhMonitoring [External ipv4 Network Prefix]"
    return 1
  fi
  EXTERNAL_IP4_PREFIX=$1

  echo "Allowing OVH Monitoring servers ..."

  for SENS in "INPUT" ; do # non nécéssaire sur les vms car NAT
    $ip4t -A $SENS -j ACCEPT -p tcp  -s 213.186.50.100 --dport 22
    $ip4t -A $SENS -j ACCEPT -p icmp -s ${EXTERNAL_IP4_PREFIX}250 #spécifique au sous réseau du serveur
    $ip4t -A $SENS -j ACCEPT -p icmp -s ${EXTERNAL_IP4_PREFIX}251 #spécifique au sous réseau du serveur
    $ip4t -A $SENS -j ACCEPT -p icmp -s 167.114.37.0/24
    $ip4t -A $SENS -j ACCEPT -p icmp -s 213.186.33.13
    $ip4t -A $SENS -j ACCEPT -p icmp -s 213.186.33.62
    $ip4t -A $SENS -j ACCEPT -p icmp -s 213.186.45.4
    $ip4t -A $SENS -j ACCEPT -p icmp -s 213.186.50.100
    $ip4t -A $SENS -j ACCEPT -p icmp -s 213.186.50.98
    $ip4t -A $SENS -j ACCEPT -p icmp -s 213.251.184.9
    $ip4t -A $SENS -j ACCEPT -p icmp -s 37.187.231.251
    $ip4t -A $SENS -j ACCEPT -p icmp -s 37.59.0.235
    $ip4t -A $SENS -j ACCEPT -p icmp -s 8.33.137.2
    $ip4t -A $SENS -j ACCEPT -p icmp -s 92.222.184.0/24
    $ip4t -A $SENS -j ACCEPT -p icmp -s 92.222.185.0/24
    $ip4t -A $SENS -j ACCEPT -p icmp -s 92.222.186.0/24
  done
}

DualDefaultRules () {

  echo "Applying ip4/6 default end rules ..."

  for SENS in "INPUT" "FORWARD" ; do
    $ip4t -A $SENS -j ACCEPT -p icmp -m state --state ESTABLISHED,RELATED
    $ip4t -A $SENS -j ACCEPT -p tcp  -m state --state ESTABLISHED,RELATED
    $ip4t -A $SENS -j ACCEPT -p udp  -m state --state ESTABLISHED,RELATED
    $ip4t -A $SENS -j DROP
    $ip4t -A $SENS -j LOG --log-prefix="[IP4 ${SENS} DROP] "
    $ip4t -A $SENS -j REJECT
    $ip4t -P $SENS DROP

    $ip6t -A $SENS -j ACCEPT -p icmpv6 -m state --state ESTABLISHED,RELATED
    $ip6t -A $SENS -j ACCEPT -p tcp    -m state --state ESTABLISHED,RELATED
    $ip6t -A $SENS -j ACCEPT -p udp    -m state --state ESTABLISHED,RELATED
    $ip6t -A $SENS -j DROP
    $ip6t -A $SENS -j LOG --log-prefix="[IP6 ${SENS} DROP] "
    $ip6t -A $SENS -j REJECT
    $ip6t -P $SENS DROP
  done

  # activation du Forwarding
  sysctl -w net.ipv4.ip_forward=1
  sysctl -w net.ipv4.conf.all.forwarding=1
  sysctl -w net.ipv4.conf.all.accept_redirects=0
  sysctl -w net.ipv4.conf.all.send_redirects=0
  sysctl -w net.ipv4.conf.default.forwarding=1

  sysctl -w net.ipv6.conf.all.forwarding=1
  sysctl -w net.ipv6.conf.all.accept_redirects=0
  sysctl -w net.ipv6.conf.all.router_solicitations=1
  sysctl -w net.ipv6.conf.default.forwarding=1
  sysctl -w net.ipv6.conf.default.proxy_ndp=1
  sysctl -w net.ipv6.conf.all.proxy_ndp=1

}
