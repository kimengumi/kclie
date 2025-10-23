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
# Library of functions dealing with vhosts created with kclie wizard
#

GetVhostDirFromCurrentDir() {
    DIR=$(pwd)
    while [ "${DIR}" != "/" ]; do
        if [ -e "${DIR}/db.config.php" ] || [ -e "${DIR}/.env.local" ]; then
            if [[ "${DIR}" =~ ^/home/[^/]+/web/[^/]+/?$ ]]; then
                VHOST_DIR=${DIR%/}
                return
            fi
        fi
        DIR=$(dirname "${DIR}")
    done
}

GetVhostDirFromVhostName() {
    for SEARCH in `ls --color=never -d  /home/*/web/$1 2>/dev/null`; do
        if [ -d "${SEARCH}" ]; then
            VHOST_DIR=${SEARCH}
            return
        fi
    done
}

GetVhostVarsFromVhostDir() {
    read VHOST_USER VHOST_NAME <<< $(echo "${VHOST_DIR}" | awk -F'/' '{print $3, $5}')
    VHOST_GROUP=$(id -gn ${VHOST_USER})
    if [ -r "${VHOST_DIR}/db.config.php" ] || [ -r "${VHOST_DIR}/.env.local" ]; then
        VHOST_HAVE_DB=1
        VHOST_DB_NAME=$(echo "${VHOST_USER}_${VHOST_NAME}" | sed -e "s/\./-/g")
        VHOST_DB_DUMP="${VHOST_DIR}/db.dump.sql.gz"
    else
        VHOST_HAVE_DB=0
    fi
    if [ -r "/run/php/${VHOST_NAME}.sock" ] ; then
        VHOST_HAVE_PHP=1
        VHOST_PHP_SOCK="/run/php/${VHOST_NAME}.sock"
        VHOST_PHP_TMP="/home/${VHOST_USER}/web/${VHOST_NAME}/var/tmp"
    else
        VHOST_HAVE_PHP=0
    fi
}

GetVhostVarsFromAuto(){
    if [ "x$1" != "x" ] ; then
        GetVhostDirFromVhostName $1
    else
        GetVhostDirFromCurrentDir
    fi
    if [ "x${VHOST_DIR}" = "x" ] ; then
        echo -e "Unspecified or not existing vhost. Usage:\n$0 ([servername] dectect from current path if not specified)"
        exit 1
    fi
    GetVhostVarsFromVhostDir
}