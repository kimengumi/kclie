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

# CHECK CONFIGURATION
if [ "x${EXTIF}" = "x" ] || \
  [ "x${LOCIF}" = "x" ] || \
  [ "x${LOCIP4NETW}" = "x" ] || \
  [ "x${LOCIP4PREF}" = "x" ] || \
  [ "x${LOCIP6NETW}" = "x" ] || \
  [ "x${LOCIP6PREF}" = "x" ] ; then

    echo 'Please initialise your script before loading the library.
Sample configuration :

export EXTIF="eth1"                     # Interface with the public / external IP
export LOCIF="eth0"                     # Interface with the local / internal IP
export LOCIP4NETW="192.168.0.0/16"      # Local ipv4 Subnet (could be more than the connected subnet if necessary)
export LOCIP4PREF="192.168.1."          # Prefix used to write ipv4 rules
export LOCIP6NETW="fd85:e1b1:e282::/48" # Local ipv6 Subnet (could be more than the connected subnet if necessary)
export LOCIP6PREF="fd85:e1b1:e282:1::"  # Prefix used to write ipv6 rules
'
  exit 1
fi

# Check iptables
if [ "$(id -u)" != "0" ]; then
  echo 'You are not root : entering preview mode ...'
  export ip4t="echo IPv4"
  export ip6t="echo IPv6"
  export sctl="echo sysctl"
else
  export ip4t=`which iptables`
  export ip6t=`which ip6tables`
  export sctl=`which sysctl`
  if [ ! -x ${ip4t} ] || [ ! -x ${ip6t} ] || [ ! -x $sctl ] ; then
    echo 'No executable for iptables or ip6tables or sysctl found !'
    exit 1
  fi
fi

# Reset tables and allow ssh to host
DualBasicRules () {

  if [ "x$1" = "x" ] ; then
    echo "Usage: DualBasicRules [SSH Port to Current Host]"
    exit 1 # we do not start anything (ssh connection to host no securized)
  fi
  HOST_SSH_PORT=$1

  echo "reseting ip4/6 tables ..."

  ${ip4t} -P INPUT ACCEPT
  ${ip6t} -P INPUT ACCEPT
  ${ip4t} -P OUTPUT ACCEPT
  ${ip6t} -P OUTPUT ACCEPT
  ${ip4t} -P FORWARD ACCEPT
  ${ip6t} -P FORWARD ACCEPT
  ${ip4t} -F
  ${ip6t} -F
  ${ip4t} -X
  ${ip6t} -X
  ${ip4t} -t nat -F
  ${ip6t} -t nat -F
  ${ip4t} -t nat -X
  ${ip6t} -t nat -X
  ${ip4t} -t mangle -F
  ${ip6t} -t mangle -F
  ${ip4t} -t mangle -X
  ${ip6t} -t mangle -X

  echo "Applying ip4/6 safe rules ..."

  # SSH autorisé dans tout les cas, de partout
  ${ip4t} -A INPUT -j ACCEPT -p tcp --dport ${HOST_SSH_PORT}
  ${ip6t} -A INPUT -j ACCEPT -p tcp --dport ${HOST_SSH_PORT}

  # specific ipv6
  ${ip6t} -A INPUT -j ACCEPT -d ff00::/8 # ipv6 Multicast
  ${ip6t} -A INPUT -j ACCEPT -p icmpv6 --icmpv6-type 135 # Neighbor Solicitation
  ${ip6t} -A INPUT -j ACCEPT -p icmpv6 --icmpv6-type 136 # Neighbor Advertisement

  # Limit ping
  ${ip4t} -A INPUT -j ACCEPT -p icmp   --icmp-type 8     -m limit --limit 5/sec --limit-burst 10
  ${ip6t} -A INPUT -j ACCEPT -p icmpv6 --icmpv6-type 128 -m limit --limit 5/sec --limit-burst 10

  echo "Applying ip4/6 local rules ..."

  # LOCAL HOST
  ${ip4t} -A INPUT -j ACCEPT -i lo
  ${ip6t} -A INPUT -j ACCEPT -i lo

  # LOCAL NET
  ${ip4t} -A INPUT -j ACCEPT -i ${LOCIF} -s ${LOCIP4NETW}
  ${ip6t} -A INPUT -j ACCEPT -i ${LOCIF} -s ${LOCIP6NETW}
  ${ip4t} -A FORWARD -j ACCEPT -i ${LOCIF} -s ${LOCIP4NETW}
  ${ip6t} -A FORWARD -j ACCEPT -i ${LOCIF} -s ${LOCIP6NETW}

  # LOCAL NET specific ipv6
  ${ip6t} -A INPUT -j ACCEPT -i ${LOCIF} -s fe80::/10 # Link Local addresses
  ${ip6t} -A FORWARD -j ACCEPT -i ${LOCIF} -s fe80::/10 # Link Local addresses

  # LOCAL NAT OUTPUT
  ${ip4t} -A POSTROUTING -t nat -j ACCEPT -s ${LOCIP4NETW} -d ${LOCIP4NETW}
  ${ip6t} -A POSTROUTING -t nat -j ACCEPT -s ${LOCIP6NETW} -d ${LOCIP6NETW}
  ${ip4t} -A POSTROUTING -t nat -j MASQUERADE -s ${LOCIP4NETW} -o ${EXTIF}
  ${ip6t} -A POSTROUTING -t nat -j MASQUERADE -s ${LOCIP6NETW} -o ${EXTIF}

}

DualHttpNat () {

  if [ "x$1" = "x" ] ; then
    echo "Usage: DualHttpNat [End of local ip4/6]"
    return 1
  fi
  ENDIP=$1
  echo "Redirecting Http/Https to ${LOCIP4PREF}${ENDIP} / ${LOCIP6PREF}${ENDIP} ..."

  ${ip4t} -A PREROUTING -t nat -j DNAT -i ${EXTIF} -p tcp --dport 80 --to ${LOCIP4PREF}${ENDIP}:80
  ${ip6t} -A PREROUTING -t nat -j DNAT -i ${EXTIF} -p tcp --dport 80 --to [${LOCIP6PREF}${ENDIP}]:80
  ${ip4t} -A PREROUTING -t nat -j DNAT -i ${EXTIF} -p tcp --dport 443 --to ${LOCIP4PREF}${ENDIP}:443
  ${ip6t} -A PREROUTING -t nat -j DNAT -i ${EXTIF} -p tcp --dport 443 --to [${LOCIP6PREF}${ENDIP}]:443
  ${ip4t} -A FORWARD -j DROP   -p tcp --dport 80 -m string --to 70 --algo bm --string 'GET /w00tw00t.at.ISC.SANS.'
  ${ip6t} -A FORWARD -j DROP   -p tcp --dport 80 -m string --to 70 --algo bm --string 'GET /w00tw00t.at.ISC.SANS.'
  ${ip4t} -A FORWARD -j ACCEPT -p tcp -d ${LOCIP4PREF}${ENDIP} --dport 80
  ${ip6t} -A FORWARD -j ACCEPT -p tcp -d ${LOCIP6PREF}${ENDIP} --dport 80
  ${ip4t} -A FORWARD -j ACCEPT -p tcp -d ${LOCIP4PREF}${ENDIP} --dport 443
  ${ip6t} -A FORWARD -j ACCEPT -p tcp -d ${LOCIP6PREF}${ENDIP} --dport 443

}

DualCustomNat () {

  if [ "x$1" = "x" ] || [ "x$2" = "x" ] || [ "x$3" = "x" ] || [ "x$4" = "x" ]; then
    echo "Usage: DualCustomNat [tcp/udp] [External Port] [Local Port] [End of local ip4/6]"
    return 1
  fi
  TYPE=$1
  DPORT=$2
  LPORT=$3
  ENDIP=$4

  echo "Redirecting port ${DPORT} (${TYPE}) TO ${LOCIP4PREF}${ENDIP} / ${LOCIP6PREF}${ENDIP} port ${LPORT} ..."

  ${ip4t} -A PREROUTING -t nat -j DNAT -i ${EXTIF} -p ${TYPE} --dport ${DPORT} --to ${LOCIP4PREF}${ENDIP}:${LPORT}
  ${ip6t} -A PREROUTING -t nat -j DNAT -i ${EXTIF} -p ${TYPE} --dport ${DPORT}  --to [${LOCIP6PREF}${ENDIP}]:${LPORT}
  ${ip4t} -A FORWARD -j ACCEPT -p tcp -d ${LOCIP4PREF}${ENDIP} --dport ${LPORT}
  ${ip6t} -A FORWARD -j ACCEPT -p tcp -d ${LOCIP6PREF}${ENDIP} --dport ${LPORT}

}

DualSshNat () {

  if [ "x$1" = "x" ] || [ "x$2" = "x" ] || [ "x$3" = "x" ] ; then
    echo "Usage: DualSshNat [extrenal port prefix] [First End of local ip4/6] [Last End of local ip4/6]"
    return 1
  fi
  DPREFIX=$1
  FIRST_ENDIP=$2
  LAST_ENDIP=$3

  echo "Redirecting SSH ports ${DPREFIX}XXX FROM (ip-prefix)${FIRST_ENDIP} TO (ip-prefix)${LAST_ENDIP}"

  for ENDIP in `seq -w ${FIRST_ENDIP} ${LAST_ENDIP}` ; do
          ${ip4t} -A PREROUTING -t nat -j DNAT -i ${EXTIF} -p tcp --dport ${DPREFIX}${ENDIP} --to ${LOCIP4PREF}${ENDIP}:22
          ${ip6t} -A PREROUTING -t nat -j DNAT -i ${EXTIF} -p tcp --dport ${DPREFIX}${ENDIP} --to [${LOCIP6PREF}${ENDIP}]:22
          ${ip4t} -A FORWARD -j ACCEPT -p tcp -d ${LOCIP4PREF}${ENDIP} --dport 22
          ${ip6t} -A FORWARD -j ACCEPT -p tcp -d ${LOCIP6PREF}${ENDIP} --dport 22
  done
}

OvhMonitoring () {

  if [ "x$1" = "x" ] ; then
    echo "Usage: OvhMonitoring [External ipv4 Network Prefix]"
    return 1
  fi
  EXTERNAL_IP4_PREFIX=$1

  echo "Allowing OVH Monitoring servers ..."

  ${ip4t} -A INPUT -j ACCEPT -p tcp  -s 213.186.50.100 --dport 22
  ${ip4t} -A INPUT -j ACCEPT -p icmp -s ${EXTERNAL_IP4_PREFIX}250 #spécifique au sous réseau du serveur
  ${ip4t} -A INPUT -j ACCEPT -p icmp -s ${EXTERNAL_IP4_PREFIX}251 #spécifique au sous réseau du serveur
  ${ip4t} -A INPUT -j ACCEPT -p icmp -s 167.114.37.0/24
  ${ip4t} -A INPUT -j ACCEPT -p icmp -s 213.186.33.13
  ${ip4t} -A INPUT -j ACCEPT -p icmp -s 213.186.33.62
  ${ip4t} -A INPUT -j ACCEPT -p icmp -s 213.186.45.4
  ${ip4t} -A INPUT -j ACCEPT -p icmp -s 213.186.50.100
  ${ip4t} -A INPUT -j ACCEPT -p icmp -s 213.186.50.98
  ${ip4t} -A INPUT -j ACCEPT -p icmp -s 213.251.184.9
  ${ip4t} -A INPUT -j ACCEPT -p icmp -s 37.187.231.251
  ${ip4t} -A INPUT -j ACCEPT -p icmp -s 37.59.0.235
  ${ip4t} -A INPUT -j ACCEPT -p icmp -s 8.33.137.2
  ${ip4t} -A INPUT -j ACCEPT -p icmp -s 92.222.184.0/24
  ${ip4t} -A INPUT -j ACCEPT -p icmp -s 92.222.185.0/24
  ${ip4t} -A INPUT -j ACCEPT -p icmp -s 92.222.186.0/24

}

DualDefaultRules () {

  if [ "x$1" != "xlog" ] && [ "x$1" != "x" ] ; then
    echo "Usage: DualDefaultRules [log]"
  fi

  echo "Applying ip4/6 default end rules ..."

  for WAY in "INPUT" "FORWARD" ; do
    ${ip4t} -A ${WAY} -j ACCEPT -p icmp   -m state --state ESTABLISHED,RELATED
    ${ip6t} -A ${WAY} -j ACCEPT -p icmpv6 -m state --state ESTABLISHED,RELATED
    ${ip4t} -A ${WAY} -j ACCEPT -p tcp -m state --state ESTABLISHED,RELATED
    ${ip6t} -A ${WAY} -j ACCEPT -p tcp -m state --state ESTABLISHED,RELATED
    ${ip4t} -A ${WAY} -j ACCEPT -p udp -m state --state ESTABLISHED,RELATED
    ${ip6t} -A ${WAY} -j ACCEPT -p udp -m state --state ESTABLISHED,RELATED
    if [ "x$1" = "xlog" ] ; then
      ${ip4t} -A ${WAY} -j LOG --log-prefix="[IP4 ${WAY} DROP] "
      ${ip6t} -A ${WAY} -j LOG --log-prefix="[IP6 ${WAY} DROP] "
    fi
    ${ip4t} -P ${WAY} DROP
    ${ip6t} -P ${WAY} DROP
  done

  # activation du Forwarding

  ${sctl} -w net.ipv4.conf.all.accept_redirects=0
  ${sctl} -w net.ipv4.conf.all.forwarding=1
  ${sctl} -w net.ipv4.conf.all.rp_filter=1
  ${sctl} -w net.ipv4.conf.all.send_redirects=0
  ${sctl} -w net.ipv4.conf.default.forwarding=1
  ${sctl} -w net.ipv4.ip_forward=1

  ${sctl} -w net.ipv6.conf.all.accept_redirects=0
  ${sctl} -w net.ipv6.conf.all.forwarding=1
  ${sctl} -w net.ipv6.conf.all.router_solicitations=1
  ${sctl} -w net.ipv6.conf.default.forwarding=1
  ${sctl} -w net.ipv6.conf.default.proxy_ndp=1
  ${sctl} -w net.ipv6.conf.all.proxy_ndp=1

}
