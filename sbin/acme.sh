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

ACME_DIR=${KCLIE_PATH}/vendor/acme.sh
ACME_CNF=/etc/acme.sh
SUDO_EXEC="sudo LE_WORKING_DIR=${ACME_DIR} LE_CONFIG_HOME=${ACME_CNF} -u www-data"
ACME_EXEC="${SUDO_EXEC} ${ACME_DIR}/acme.sh"

if [ ! -x ${ACME_DIR}/acme.sh ] || [ ! -e ${ACME_CNF}/account.conf ]; then

    echo -e "\n\033[0;92mInstall Acme.sh\033[0m\n"
    mkdir -p ${ACME_DIR} ${ACME_CNF} /var/www/html
    chown www-data:www-data ${ACME_DIR} ${ACME_CNF} /var/www/html
    cd ${ACME_DIR}
    wget -nv -O - https://raw.githubusercontent.com/acmesh-official/acme.sh/master/acme.sh | ${SUDO_EXEC} sh -s -- --install-online
    ${ACME_EXEC} --set-default-ca --server letsencrypt
    ${ACME_EXEC} --install-cronjob
fi

${ACME_EXEC} "$@"