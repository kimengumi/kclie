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

CurrentDirVhostDir() {
    DIR=$(pwd)
    while [ "${DIR}" != "/" ]; do
        if [ -e "${DIR}/db.config.php" ]; then
            echo ${DIR}
            return
        fi
        DIR=$(dirname "${DIR}")
    done
}