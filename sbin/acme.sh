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

#
# Acme.sh wrapper (running with www-data user)
#

# Check KCLIE env and load if necessary
if [ "x${KCLIE_PATH}" = "x" ]; then
    source $(dirname $0)/../env || ( echo 'KCLIE not configured' ; exit 2 )
fi

if ! getent passwd www-data >/dev/null 2>&1; then
    echo -e "${C_RED}www-data user does not exists${C_OFF}"
    exit
fi

export LE_WORKING_DIR=${KCLIE_PATH}/vendor/acme.sh
export LE_CONFIG_HOME=/etc/acme.sh

if [ ! -x ${LE_WORKING_DIR}/acme.sh ] || [ ! -e ${LE_CONFIG_HOME}/account.conf ]; then

    echo -e "\n\033[0;92mInstall Acme.sh\033[0m\n"
    mkdir -p ${LE_WORKING_DIR} ${LE_CONFIG_HOME}
    chown www-data:www-data ${LE_WORKING_DIR} ${LE_CONFIG_HOME}
    cd ${LE_WORKING_DIR}
    wget -nv -O - https://raw.githubusercontent.com/acmesh-official/acme.sh/master/acme.sh | sudo -u www-data \
        sh -s -- --install-online --home ${LE_WORKING_DIR} --config-home ${LE_CONFIG_HOME}
fi

sudo -u www-data ${LE_WORKING_DIR}/acme.sh "$@"