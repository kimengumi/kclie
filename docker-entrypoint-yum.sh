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


ln -fs /usr/share/zoneinfo/Europe/Paris /etc/localtime
# Install common package available in a full system but not in the standard docker image
yum install -y git vim wget zsh
git config --global pull.rebase false
groupadd user
useradd -g user -G wheel -s /usr/bin/zsh -m user
echo "user:user" | chpasswd
/opt/kclie/configure
echo "motd" | sudo -u user tee /home/user/.zshrc
su --login user