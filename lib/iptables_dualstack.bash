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

    echo -e "\033[93m
    Please initialise your script before loading the library.\033[0m"
    echo '
-------- Header placed and configured in your script --------
#!/bin/bash
#
# My dual stack firewall script
#
# Usage of the script :
# ./my-firewall-script [preview] [4/6]
#

# Configuration
export EXTIF="eth1"                     # Interface with the public / external IP
export LOCIF="eth0"                     # Interface with the local / internal IP
export LOCIP4NETW="192.168.0.0/16"      # Local ipv4 Subnet (could be more than the connected subnet if necessary)
export LOCIP4PREF="192.168.1."          # Prefix used to write ipv4 rules
export LOCIP6NETW="fd85:e1b1:e282::/48" # Local ipv6 Subnet (could be more than the connected subnet if necessary)
export LOCIP6PREF="fd85:e1b1:e282:1::"  # Prefix used to write ipv6 rules

# Load dual stack library'
  echo "source ${KCLIE_PATH}/lib/iptables_dualstack.bash
-------------------------------------------------------------"
  exit 1
fi

# Check iptables
export preview=false
export ip4t=`which iptables`
export ip6t=`which ip6tables`
export sctl=`which sysctl`
if [ ! -x ${ip4t} ] || [ ! -x ${ip6t} ] || [ ! -x ${sctl} ] ; then
  echo 'No executable for iptables or ip6tables or sysctl found !'
  exit 1
fi

# Try run iptables, if not start preview mode
${ip4t} -L >/dev/null 2>&1
if [ "x$?" != "x0" ] || [ "x$1" == "xpreview" ] ; then
  echo 'Entering preview mode ...'
  export preview=true
  export ipview=${2}
  export sctl="echo sysctl"
  export ip4t="false"
  export ip6t="false"
  if [ "x${ipview}" != "x6" ] ; then
    export ip4t="echo IPv4"
  fi
  if [ "x${ipview}" != "x4" ] ; then
    export ip6t="echo IPv6"
  fi
fi

# Run args on both iptables & ip6tables
Dual () {
  if ${preview} ; then
    echo -e "\033[92mDual $@\033[0m"
  else
    ${ip4t} $@
    ${ip6t} $@
  fi
}
echo "x$2QQQx6"
# Run args for iptables
Ipv4 () {
  if ${preview} ; then
    if [ "x${ipview}" != "x6" ] ; then
      echo -e "\033[93mIPv4 $@\033[0m"
    fi
  else
    ${ip4t} $@
  fi
}

# Run args for ip6tables
Ipv6 () {
  if ${preview} ; then
    if [ "x${ipview}" != "x4" ] ; then
      echo -e "\033[94mIPv6 $@\033[0m"
    fi
  else
    ${ip6t} $@
  fi
}

# Run args for ip6tables
SysCtl () {
  if ${preview} ; then
    echo -e "\033[95mSysCtl $@\033[0m"
  else
    ${sctl} $@
  fi
}

# Reset tables and allow ssh to host
DualBasicRules () {

  if [ "x$1" = "x" ] ; then
    echo "Usage: DualBasicRules [SSH Port to Current Host]"
    exit 1 # we do not start anything (ssh connection to host no securized)
  fi
  HOST_SSH_PORT=$1

  echo "reseting ip4/6 tables ..."

  Dual -P INPUT ACCEPT
  Dual -P OUTPUT ACCEPT
  Dual -P FORWARD ACCEPT
  Dual -F
  Dual -X
  Dual -t nat -F
  Dual -t nat -X
  Dual -t mangle -F
  Dual -t mangle -X

  echo "Applying ip4/6 safe rules ..."

  # SSH autorisé dans tout les cas, de partout
  Dual -A INPUT -j ACCEPT -p tcp --dport ${HOST_SSH_PORT}

  # specific ipv6
  Ipv6 -A INPUT -j ACCEPT -d ff00::/8 # ipv6 Multicast
  Ipv6 -A INPUT -j ACCEPT -p icmpv6 --icmpv6-type 135 # Neighbor Solicitation
  Ipv6 -A INPUT -j ACCEPT -p icmpv6 --icmpv6-type 136 # Neighbor Advertisement

  echo "Applying ip4/6 local rules ..."

  # LOCAL HOST
  Dual -A INPUT -j ACCEPT -i lo

  # LOCAL NET
  Ipv4 -A INPUT -j ACCEPT -i ${LOCIF} -s ${LOCIP4NETW}
  Ipv6 -A INPUT -j ACCEPT -i ${LOCIF} -s ${LOCIP6NETW}

  # LOCAL NET specific ipv6
  Ipv6 -A INPUT -j ACCEPT -i ${LOCIF} -s fe80::/10 # Link Local addresses
}

DualMasquerade () {

  # LOCAL NET
  Ipv4 -A FORWARD -j ACCEPT -i ${LOCIF} -s ${LOCIP4NETW}
  Ipv6 -A FORWARD -j ACCEPT -i ${LOCIF} -s ${LOCIP6NETW}

  # LOCAL NET specific ipv6
  Ipv6 -A FORWARD -j ACCEPT -i ${LOCIF} -s fe80::/10 # Link Local addresses

  # LOCAL NAT OUTPUT
  Ipv4 -A POSTROUTING -t nat -j ACCEPT -s ${LOCIP4NETW} -d ${LOCIP4NETW}
  Ipv6 -A POSTROUTING -t nat -j ACCEPT -s ${LOCIP6NETW} -d ${LOCIP6NETW}
  Ipv4 -A POSTROUTING -t nat -j MASQUERADE -s ${LOCIP4NETW} -o ${EXTIF}
  Ipv6 -A POSTROUTING -t nat -j MASQUERADE -s ${LOCIP6NETW} -o ${EXTIF}

  DualActivateForward
}

DualHttpNat () {

  if [ "x$1" = "x" ] ; then
    echo "Usage: DualHttpNat [End of local ip4/6]"
    return 1
  fi
  ENDIP=$1
  echo "Redirecting Http/Https to ${LOCIP4PREF}${ENDIP} / ${LOCIP6PREF}${ENDIP} ..."

  Ipv4    -A PREROUTING -t nat -j DNAT -i ${EXTIF} -p tcp --dport 80 --to ${LOCIP4PREF}${ENDIP}:80
  Ipv6    -A PREROUTING -t nat -j DNAT -i ${EXTIF} -p tcp --dport 80 --to [${LOCIP6PREF}${ENDIP}]:80
  Ipv4    -A PREROUTING -t nat -j DNAT -i ${EXTIF} -p tcp --dport 443 --to ${LOCIP4PREF}${ENDIP}:443
  Ipv6    -A PREROUTING -t nat -j DNAT -i ${EXTIF} -p tcp --dport 443 --to [${LOCIP6PREF}${ENDIP}]:443
  ${ip4t} -A FORWARD -j DROP   -p tcp --dport 80 -m string --to 70 --algo bm --string 'GET /w00tw00t.at.ISC.SANS.'
  ${ip6t} -A FORWARD -j DROP   -p tcp --dport 80 -m string --to 70 --algo bm --string 'GET /w00tw00t.at.ISC.SANS.'
  Ipv4    -A FORWARD -j ACCEPT -p tcp -d ${LOCIP4PREF}${ENDIP} --dport 80
  Ipv4    -A FORWARD -j ACCEPT -p tcp -d ${LOCIP4PREF}${ENDIP} --dport 443
  Ipv6    -A FORWARD -j ACCEPT -p tcp -d ${LOCIP6PREF}${ENDIP} --dport 80
  Ipv6    -A FORWARD -j ACCEPT -p tcp -d ${LOCIP6PREF}${ENDIP} --dport 443
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

  Ipv4 -A PREROUTING -t nat -j DNAT -i ${EXTIF} -p ${TYPE} --dport ${DPORT} --to ${LOCIP4PREF}${ENDIP}:${LPORT}
  Ipv6 -A PREROUTING -t nat -j DNAT -i ${EXTIF} -p ${TYPE} --dport ${DPORT}  --to [${LOCIP6PREF}${ENDIP}]:${LPORT}
  Ipv4 -A FORWARD -j ACCEPT -p tcp -d ${LOCIP4PREF}${ENDIP} --dport ${LPORT}
  Ipv6 -A FORWARD -j ACCEPT -p tcp -d ${LOCIP6PREF}${ENDIP} --dport ${LPORT}
}

DualSshNat () {

  if [ "x$1" = "x" ] || [ "x$2" = "x" ] || [ "x$3" = "x" ] ; then
    echo "Usage: DualSshNat [extrenal port prefix] [First End of local ip4/6] [Last End of local ip4/6]"
    echo ""
    echo "Note : Prefix can be from 1 to 65, the end part will always have 3 digits (with leading zero)"
    return 1
  fi
  DPREFIX=$1
  FIRST_ENDIP=$2
  LAST_ENDIP=$3

  echo "Redirecting SSH ports ${DPREFIX}XXX FROM (ip-prefix)${FIRST_ENDIP} TO (ip-prefix)${LAST_ENDIP}"

  for ENDIP in `seq -w ${FIRST_ENDIP} ${LAST_ENDIP}` ; do
    Ipv4 -A PREROUTING -t nat -j DNAT -i ${EXTIF} -p tcp --dport ${DPREFIX}`printf "%.3d" ${ENDIP}` --to ${LOCIP4PREF}${ENDIP}:22
  done
  for ENDIP in `seq -w ${FIRST_ENDIP} ${LAST_ENDIP}` ; do
    Ipv6 -A PREROUTING -t nat -j DNAT -i ${EXTIF} -p tcp --dport ${DPREFIX}`printf "%.3d" ${ENDIP}` --to [${LOCIP6PREF}${ENDIP}]:22
  done

  Ipv4 -A FORWARD -j ACCEPT -p tcp -m iprange --dst-range ${LOCIP4PREF}${FIRST_ENDIP}-${LOCIP4PREF}${LAST_ENDIP} --dport 22
  Ipv6 -A FORWARD -j ACCEPT -p tcp -m iprange --dst-range ${LOCIP6PREF}${FIRST_ENDIP}-${LOCIP6PREF}${LAST_ENDIP} --dport 22
}

OvhMonitoring () {

  if [ "x$1" = "x" ] ; then
    echo "Usage: OvhMonitoring [External ipv4 Network Prefix]"
    return 1
  fi
  EXTERNAL_IP4_PREFIX=$1

  echo "Allowing OVH Monitoring servers ..."

  # List from :
  # https://docs.ovh.com/pages/releaseview.action?pageId=9928706
  # https://docs.ovh.com/fr/fr/cloud/dedicated/monitoring-ip-ovh/
  # http://docs.ovh.ca/fr/guides-network-firewall.html#ovh-monitoring
  # http://guide.ovh.com/firewall

  Ipv4 -A INPUT -j ACCEPT -p icmp -s 213.186.33.13   # ping.ovh.net
  Ipv4 -A INPUT -j ACCEPT -p icmp -s 213.186.33.62   # a2.ovh.net
  Ipv4 -A INPUT -j ACCEPT -p icmp -s 213.186.50.98   # proxy.ovh.net
  Ipv4 -A INPUT -j ACCEPT -p icmp -s 213.186.50.100  # cache.ovh.net
  Ipv4 -A INPUT -j ACCEPT -p icmp -s 213.186.45.4    # proxy.p19.ovh.net
  Ipv4 -A INPUT -j ACCEPT -p icmp -s 213.251.184.9   # proxy.rbx.ovh.net
  Ipv4 -A INPUT -j ACCEPT -p icmp -s 37.59.0.235     # proxy.sbg.ovh.net
  Ipv4 -A INPUT -j ACCEPT -p icmp -s 8.33.137.2      # proxy.bhs.ovh.net
  Ipv4 -A INPUT -j ACCEPT -p icmp -s 37.187.231.251  # rtm-collector.ovh.net
  Ipv4 -A INPUT -j ACCEPT -p icmp -s 92.222.184.0/24 # netmon-X-rbx.ovh.net
  Ipv4 -A INPUT -j ACCEPT -p icmp -s 92.222.185.0/24 # netmon-X-sbg.ovh.net
  Ipv4 -A INPUT -j ACCEPT -p icmp -s 92.222.186.0/24 # netmon-X-gra.ovh.net
  Ipv4 -A INPUT -j ACCEPT -p icmp -s 167.114.37.0/24 # netmon-X-bhs.ovh.ca
  Ipv4 -A INPUT -j ACCEPT -p icmp -s 151.80.231.244  # mrtg-rbx-101
  Ipv4 -A INPUT -j ACCEPT -p icmp -s 151.80.231.245  # mrtg-rbx-102
  Ipv4 -A INPUT -j ACCEPT -p icmp -s 151.80.231.246  # mrtg-rbx-103
  Ipv4 -A INPUT -j ACCEPT -p icmp -s 151.80.231.247  # mrtg-gra-101
  Ipv4 -A INPUT -j ACCEPT -p icmp -s ${EXTERNAL_IP4_PREFIX}249 # specific to the server subnet
  Ipv4 -A INPUT -j ACCEPT -p icmp -s ${EXTERNAL_IP4_PREFIX}250 # specific to the server subnet
  Ipv4 -A INPUT -j ACCEPT -p icmp -s ${EXTERNAL_IP4_PREFIX}251 # specific to the server subnet
  Ipv4 -A INPUT -j ACCEPT -p tcp  -s 213.186.50.100 --dport 22 # cache.ovh.net

}

DualDefaultRules () {

  if [ "x$1" != "xlog" ] && [ "x$1" != "x" ] ; then
    echo "Usage: DualDefaultRules [log]"
  fi

  echo "Applying ip4/6 default end rules ..."

  for WAY in "INPUT" "FORWARD" ; do

    # Allow but limit ping
    Ipv4 -A ${WAY} -j ACCEPT -p icmp   --icmp-type 8     -m limit --limit 5/sec --limit-burst 10
    Ipv6 -A ${WAY} -j ACCEPT -p icmpv6 --icmpv6-type 128 -m limit --limit 5/sec --limit-burst 10

    # Allow established & related
    Ipv4 -A ${WAY} -j ACCEPT -p icmp   -m state --state ESTABLISHED,RELATED
    Ipv6 -A ${WAY} -j ACCEPT -p icmpv6 -m state --state ESTABLISHED,RELATED
    Dual -A ${WAY} -j ACCEPT -p tcp -m state --state ESTABLISHED,RELATED
    Dual -A ${WAY} -j ACCEPT -p udp -m state --state ESTABLISHED,RELATED

    # Log
    if [ "x$1" = "xlog" ] ; then
      Ipv4 -A ${WAY} -j LOG --log-prefix="[IP4-${WAY}-DROP] "
      Ipv6 -A ${WAY} -j LOG --log-prefix="[IP6-${WAY}-DROP] "
    fi

    # Default Drop
    Dual -P ${WAY} DROP

  done
}

# activation du Forwarding
DualActivateForward () {

  SysCtl -w net.ipv4.conf.all.accept_redirects=0
  SysCtl -w net.ipv4.conf.all.forwarding=1
  SysCtl -w net.ipv4.conf.all.rp_filter=1
  SysCtl -w net.ipv4.conf.all.send_redirects=0
  SysCtl -w net.ipv4.conf.default.forwarding=1
  SysCtl -w net.ipv4.ip_forward=1

  SysCtl -w net.ipv6.conf.all.accept_redirects=0
  SysCtl -w net.ipv6.conf.all.forwarding=1
  SysCtl -w net.ipv6.conf.all.router_solicitations=1
  SysCtl -w net.ipv6.conf.default.forwarding=1
  SysCtl -w net.ipv6.conf.default.proxy_ndp=1
  SysCtl -w net.ipv6.conf.all.proxy_ndp=1

}
