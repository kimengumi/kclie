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

# Load lib with failsafe when executed without cli profile (usually from CRON)
. ${KCLIE_PATH}/lib/batch.bash 2>/dev/null || \
. ~/.kclie/lib/batch.bash 2>/dev/null || \
. /opt/kclie/lib/batch.bash

# Config lib
export QUIET_TIMELOG=1
export SINGLE_QUIET_DELAY=60
export DEFAULT_LOG_DIR=/tmp
BatchStart batch-test

##### BATCH START HERE #####

BatchEcho test

##### BATCH END HERE #####

BatchEnd