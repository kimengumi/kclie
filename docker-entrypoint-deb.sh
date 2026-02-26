#!/bin/bash
#
# Kimengumi Command Line Interface Environnement (kclie)
#
# Licensed under the EUPL, Version 1.2 or – as soon they will be approved by
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
#
# @author Antonio Rossetti <antonio@rossetti.fr>
# @copyright since 2009 Antonio Rossetti
# @license <https://joinup.ec.europa.eu/software/page/eupl> EUPL
#

rm -f /etc/apt/apt.conf.d/docker-*
export DEBIAN_FRONTEND=noninteractive
ln -fs /usr/share/zoneinfo/Europe/Paris /etc/localtime
dpkg-reconfigure --frontend noninteractive tzdata
# update once a day only
if [ $(find "/var/lib/apt/extended_states" -mtime -1 -print 2>/dev/null | wc -l) -lt 1 ]; then
    apt-get update;
fi
# Install common package available in a full system but not in the standard docker image
apt-get install -y gawk git procps sudo vim-nox wget zsh #both
if [ -e /etc/lsb-release ] ; then
    apt-get install -y dialog software-properties-common #ubuntu
else
    apt-get install -y cron python3 systemd #debian
fi
wget https://raw.githubusercontent.com/gdraheim/docker-systemctl-replacement/master/files/docker/systemctl3.py -O /usr/bin/systemctl
chmod 755 /usr/bin/systemctl
/usr/bin/systemctl
git config --global pull.rebase false
groupadd user
useradd -g user -G sudo -s /usr/bin/zsh -m user
echo "user:user" | chpasswd
/opt/kclie/configure
echo "motd" | sudo -u user tee /home/user/.zshrc
su --login user