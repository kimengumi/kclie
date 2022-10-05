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
# @author Antonio Rossetti <antonio@kimengumi.fr>
# @copyright since 2009 Antonio Rossetti
# @license <https://joinup.ec.europa.eu/software/page/eupl> EUPL
#

#
# Library helping write batch scripts
#

export SCRIPT_NAME=""
export HOSTNAME=$(hostname)
export BACKUP_DIR_LOCK=""
export BACKUP_DIR_MOUNT=""
export IS_FULL_DAY=1
export CURRENT_WEEK_DAY=$(date +%u)
export CURRENT_MONTH_DAY=$(date +%d)
export CURRENT_YEAR_DAY=$(date +%j)
export DEFAULT_BACKUP_DIR="/home/backup/"
export DEFAULT_LOG_DIR="/var/log/kclie/"
export DEFAULT_LIB_DIR="/var/lib/kclie/"
export IFS_STD="${IFS}"
export IFS_LIB=$(echo -en "\n\b")
export NICE=19
export QUIET_TIMELOG=""
export SINGLE_QUIET_DELAY=15

BatchStart() {
    if [ "x$1" = "x" ]; then
        echo 'Name is mandatory'
        exit 1
    fi
    SCRIPT_NAME=$1

    renice -n ${NICE} $$ >/dev/null

    # available SHM depending of OS
    if [ -d /run/shm ]; then
        SHMDIR="/run/shm"
    elif [ -d /dev/shm ]; then
        SHMDIR="/dev/shm"
    else
        SHMDIR="/tmp"
    fi

    # batch are started on a singleton basis
    EXIST_PROC=$(ps -eaf | grep "$0" | egrep -v "$$|$PPID|grep" 2>/dev/null)
    EXIST_FIFO=$(ls --color=never -d ${SHMDIR}/${SCRIPT_NAME}_*_fifo_err 2>/dev/null)
    OLDER_FIFO=$(find ${SHMDIR}/${SCRIPT_NAME}_*_fifo_err -cmin +${SINGLE_QUIET_DELAY} 2>/dev/null)
    if [ "x${EXIST_FIFO}" != "x" ]; then
        if [ "x${EXIST_PROC}" != "x" ]; then
            if [ "x${OLDER_FIFO}" != "x" ]; then
                echo "Another instance of \"${SCRIPT_NAME}\" is in progress, aborting execution." >&2
                echo "---------------------" >&2
                ps -eaf | head -n 1 >&2
                echo "${EXIST_PROC}" >&2
            fi
            exit 2
        else
            rm ${SHMDIR}/${SCRIPT_NAME}_*_fifo_err
        fi
    fi

    # Gestion des sorties :
    #  - La sortie standard sort uniquement en log
    #  - La sortie erreur sort en log ET à l'écran ( = par mail en cron)
    mkfifo ${SHMDIR}/${SCRIPT_NAME}_$$_fifo_err
    mkdir -p ${DEFAULT_LOG_DIR}
    tee -a ${DEFAULT_LOG_DIR}/${SCRIPT_NAME}.log <${SHMDIR}/${SCRIPT_NAME}_$$_fifo_err &
    exec >>${DEFAULT_LOG_DIR}/${SCRIPT_NAME}.log 2>${SHMDIR}/${SCRIPT_NAME}_$$_fifo_err
    if [ "x${QUIET_TIMELOG}" = "x" ]; then
        echo "============================================"
        echo "## $(date +"%T ## %F") ## Start of ${SCRIPT_NAME} ##"
    fi
    BackupSetWeekDayFull 6 #saturday

    # Deal with filenames with spaces
    export IFS="${IFS_LIB}"
}

BatchEnd() {
    if [ "x${QUIET_TIMELOG}" = "x" ]; then
        echo "## $(date +"%T ## %F") ## End of ${SCRIPT_NAME} ##"
    fi
    rm ${SHMDIR}/${SCRIPT_NAME}_$$_fifo_err
    export IFS=${IFS_STD}
}

BatchEcho() {
    if [ "x${QUIET_TIMELOG}" = "x" ]; then
        echo "## $(date +"%T") ## $1 ##"
    else
        echo $1
    fi
}

BackupDirMount() {
    if [ "x$1" != "x" ]; then
        export BACKUP_DIR_MOUNT=$1
    else
        export BACKUP_DIR_MOUNT=${DEFAULT_BACKUP_DIR}
    fi
    BatchEcho "Mount ${BACKUP_DIR_MOUNT}"
    # Forse umount/remount to ensure not having dead mounting points (ex. NFS)
    umount ${BACKUP_DIR_MOUNT} --force 2>/dev/null
    mount ${BACKUP_DIR_MOUNT}
    if [ -d ${BACKUP_DIR_MOUNT}/${HOSTNAME} ]; then
        export DEFAULT_BACKUP_DIR=${BACKUP_DIR_MOUNT}/${HOSTNAME}
    elif [ -e ${BACKUP_DIR_MOUNT}/${HOSTNAME} ]; then
        export DEFAULT_BACKUP_DIR=${BACKUP_DIR_MOUNT}
    else
        echo "${BACKUP_DIR_MOUNT} doesn't seem to be mounted, aborting script!" >&2
        echo "A file or a dir having the hostname name is mandatory in the mounted space." >&2
        BatchEnd
        exit 1
    fi
}

BackupDirUmount() {
    if [ "x${BACKUP_DIR_MOUNT}" != "x" ]; then
        BatchEcho "Unmount ${BACKUP_DIR_MOUNT}"
        umount ${BACKUP_DIR_MOUNT} --force || (echo "Unable tu unmount ${BACKUP_DIR_MOUNT}" >&2)
    fi
}

BackupDirLock() {
    if [ "x$1" != "x" ]; then
        export BACKUP_DIR_LOCK=$1
    elif [ "x${BACKUP_DIR_MOUNT}" != "x" ]; then
        export BACKUP_DIR_LOCK=${BACKUP_DIR_MOUNT}
    else
        export BACKUP_DIR_LOCK=${BACKUP_DIR_MOUNT}
    fi
    if [ -e ${BACKUP_DIR_LOCK}/lock_* ]; then
        echo -n "${BACKUP_DIR_LOCK} is locked, waiting"
        while ls ${BACKUP_DIR_LOCK}/lock_* >/dev/null 2>&1; do
            echo -n '.'
            sleep 300 # 5min
        done
        echo -n "\n"
    fi
    BatchEcho "Add lock in ${BACKUP_DIR_LOCK}"
    touch ${BACKUP_DIR_LOCK}/lock_${HOSTNAME}_${SCRIPT_NAME} || (echo "Unable to lock ${BACKUP_DIR_LOCK}" >&2)
}

BackupDirUnlock() {
    if [ "x${BACKUP_DIR_LOCK}" != "x" ]; then
        BatchEcho "Remove lock in ${BACKUP_DIR_LOCK}"
        rm ${BACKUP_DIR_LOCK}/lock_${HOSTNAME}_${SCRIPT_NAME} || (echo "Unable to unlock ${BACKUP_DIR_LOCK}" >&2)
    fi
}

ProxmoxDumpAll() {
    REP="$1"
    if [ "x${REP}" = "x" ]; then
        REP="${DEFAULT_BACKUP_DIR}/"
    fi
    BatchEcho 'Backups off all Proxmox VMs & CTs'
    #can not define IFS with perl scripts in Taint mode
    unset IFS
    # VZdump sort tout en sortie erreur. on passe donc par un fichier temporaire, puis un grep pour remonter uniquement les vrais erreurs.
    vzdump -all 1 -compress gzip -maxfiles 1 -stdexcludes 1 -dumpdir ${REP} >/tmp/vzdump.log 2>&1
    export IFS="${IFS_LIB}"
    cat /tmp/vzdump.log
    egrep -v "INFO:| created.| successfully " /tmp/vzdump.log >&2
}

BackupMysql() {
    # backup all databases, and keep (or not) one month (or week) of old dumps
    # usage : BackupMysql [none/week/month/year (optional, default week)] [none/gzip (optional, default gzip)] [REP(optional)]

    HIST="$1"
    COMPRESS="$2"
    REP="$3"

    if [ -e /etc/mysql/debian.cnf ]; then
        USER="--defaults-extra-file=/etc/mysql/debian.cnf"
    elif [ -e ${HOME}/.my.cnf ]; then
        USER="--defaults-extra-file=${HOME}/.my.cnf"
    else
        echo "No credentials found for mysql" >&2
        return 5
    fi

    if [ "x${HIST}" = "xnone" ]; then
        HIST=""
    elif [ "x${HIST}" = "xyear" ]; then
        HIST=".${CURRENT_YEAR_DAY}"
    elif [ "x${HIST}" = "xmonth" ]; then
        HIST=".${CURRENT_MONTH_DAY}"
    else
        HIST=".${CURRENT_WEEK_DAY}"
    fi

    if [ "x${REP}" = "x" ]; then
        REP="${DEFAULT_BACKUP_DIR}/mysql"
    fi
    echo "Dumping in ${REP}"
    if [ ! -d ${REP} ]; then
        mkdir -p ${REP} || return 4
    fi

    BatchEcho "Lock all tables of all databases"
    mysql ${USER} -Bse "FLUSH TABLES WITH READ LOCK;"

    for BASE in $(mysql ${USER} -Bse 'show databases'); do
        if [ "x${BASE}" != "xinformation_schema" ] && [ "x${BASE}" != "xperformance_schema" ]; then
            BatchEcho "Dumping database ${BASE}"
            if [ "x${BASE}" = "xmysql" ]; then
                EXTRAOPTIONS="--events"
            else
                EXTRAOPTIONS=""
            fi
            if [ "x${COMPRESS}" = "none" ]; then
                mysqldump ${USER} --skip-lock-tables -f ${BASE} ${EXTRAOPTIONS} >${REP}/${BASE}${HIST}.sql
            else
                mysqldump ${USER} --skip-lock-tables -f ${BASE} ${EXTRAOPTIONS} | gzip -9f >${REP}/${BASE}${HIST}.sql.gz
            fi
        fi
    done

    BatchEcho "Unlock tables"
    mysql ${USER} -Bse "UNLOCK TABLES;"
}

BackupSetWeekDayFull() {
    if [ "x${CURRENT_WEEK_DAY}" = "x$1" ]; then
        IS_FULL_DAY=1
    else
        IS_FULL_DAY=""
    fi
}

BackupSetMonthDayFull() {
    # The first occurrence for the day of the week in the month.
    if [ "x${CURRENT_WEEK_DAY}" = "x$1" ]; then
        if [ "${CURRENT_MONTH_DAY}" -le "$1" ]; then
            IS_FULL_DAY=1
        else
            IS_FULL_DAY=""
        fi
    else
        IS_FULL_DAY=""
    fi
}

BackupRep() {
    # Incremental backup (one full each week) with history on one week/month. Can also do simple archive backups.
    # usage : BackupRep [REP] [none/week/month/year (optional, default week)] [none/lzop/gzip (optional, default gzip)] [DEST(optional)]

    REP="$1"
    HIST="$2"
    COMPRESS="$3"
    TAREP="$4"
    if [ "x${REP}" = "x" ] || [ ! -e "${REP}" ]; then
        echo "BackupRep [REP] [none/week/month/year (optional, default week)] [none/lzop/gzip (optionnel, default gzip)] [DEST(optionnel)]" >&2
        return 1
    fi
    if [ ! -d "${REP}" ]; then
        echo "BackupRep: Skip ${REP} which is no a directory"
        return 1
    fi
    SNAPREP="${DEFAULT_LIB_DIR}/backuprep/"
    if [ ! -d ${SNAPREP} ]; then
        mkdir -p ${SNAPREP} || return 4
    fi
    if [ "x${REP}" = "x/etc" ] && [ -f /usr/bin/dpkg ]; then
        /usr/bin/dpkg --get-selections >/etc/apt/$(hostname -s).dpkg-get-selections
    fi
    if [ "x${REP}" = "x/" ]; then
        NOM="root"
    else
        NOM=$(echo ${REP} | sed -e 's/^\///' -e 's/\/$//' -e 's/\//-/g' -e 's/\ /_/g')
    fi
    if [ "x${TAREP}" = "x" ]; then
        TAREP="${DEFAULT_BACKUP_DIR}"
    fi
    if [ ! -d ${TAREP} ]; then
        mkdir -p "${TAREP}" || return 4
    fi
    if [ "x${IS_FULL_DAY}" = "x1" ] && [ -e "${SNAPREP}/${NOM}.snapshot" ]; then
        rm ${SNAPREP}/${NOM}.snapshot || return 3
    fi
    cd ${REP} || return 2
    EXCLUDE=""
    if [ -e ./.backup-exclude ]; then
        EXCLUDE="--exclude-from=./.backup-exclude"
    elif [ -e ${TAREP}/.exclude ]; then
        EXCLUDE="--exclude-from=${TAREP}/.exclude"
    fi
    SNAPSHOT="--listed-incremental=${SNAPREP}/${NOM}.snapshot"
    if [ "x${HIST}" = "xnone" ]; then
        HIST=""
        SNAPSHOT=""
    elif [ "x${HIST}" = "xyear" ]; then
        HIST=".${CURRENT_YEAR_DAY}"
    elif [ "x${HIST}" = "xmonth" ]; then
        HIST=".${CURRENT_MONTH_DAY}"
    else
        HIST=".${CURRENT_WEEK_DAY}"
    fi
    BatchEcho "Archive ${REP} into ${TAREP} ..."
    if [ "x${COMPRESS}" != "x" ] && [ "x${COMPRESS}" != "xlzop" ] && [ "x${COMPRESS}" != "xgzip" ]; then
        tar ${SNAPSHOT} ${EXCLUDE} -cpf ${TAREP}/${NOM}${HIST}.tar .
    elif [ "x${COMPRESS}" = "xlzop" ]; then
        tar ${SNAPSHOT} ${EXCLUDE} --lzop -cpf ${TAREP}/${NOM}${HIST}.tar.lzo .
    else
        tar ${SNAPSHOT} ${EXCLUDE} -zcpf ${TAREP}/${NOM}${HIST}.tar.gz .
    fi
}

RsyncRep() {
    if [ "x$1" = "x" ]; then
        echo "Please specify a directory (without the final /)"
        return 1
    fi
    if [ "x$1" = "x/" ]; then
        NAME="root"
    else
        NAME=$(echo $1 | sed -e 's/^\///' -e 's/\/$//' -e 's/\//-/g' -e 's/\ /_/g')
    fi
    if [ ! -d ${DEFAULT_BACKUP_DIR}/${NAME} ]; then
        mkdir -p "${DEFAULT_BACKUP_DIR}/${NAME}" || return 4
    fi
    BatchEcho "Rsync $1 into ${DEFAULT_BACKUP_DIR}/"
    nice -n19 rsync -rltgoD --del --ignore-errors --force --exclude="lost+found" --delete-excluded $1/ ${DEFAULT_BACKUP_DIR}/${NAME}
    # -r : parcours le dossier indiqué et tous ses sous-dossiers
    # -l : copie les liens symboliques comme liens symboliques
    # -t : préserve les dates
    # -g : préserve le groupe
    # -o : mettre le propriétaire du fichier de destination identique à  celui du fichier source
    # -D : préserve les périphériques
    # ###-q : moins loquace
    # --del : permet de supprimer les fichiers sur "destination" qui n'existent plus sur "source"
    # --ignore-errors : efface même s'il y a eu des erreurs E/S
    # --force : force la suppression de répertoires même non-vides
    # --delete-excluded : efface également les fichiers exclus côté réception
}

RotateOneLog() {
    if [ "x$1" = "x" ]; then
        echo "Please specify a filename"
        return 1
    fi
    FICSIZE=$(stat -c%s "$1" || stat -f%z "$1" || echo 0) 2>/dev/null
    if [ "$FICSIZE" -gt "1048576" ]; then # rotate log start from 1Mb
        gzip -f9S .${CURRENT_WEEK_DAY}.gz $1
        # rotated log name :[filename].[week-day-num].gz
    fi
}

RotateLogs() {
    if [ "x$1" = "x" ]; then
        echo "Please specify a log directorys"
        return 1
    fi
    BatchEcho "Rotation of log files from $1"
    for FIC in $(find $1 -type f -name "*log"); do
        echo $FIC
        RotateOneLog $FIC
    done
}

SmartCheckDisk() {
    if [ "x$1" = "x" ]; then
        echo "veuillez spécificer un disque (ex: /dev/sda)"
        return 1
    fi
    STATUS=$(/usr/sbin/smartctl -q errorsonly -H $1)
    SLFTST=$(/usr/sbin/smartctl -q errorsonly -l selftest $1)
    ERRORL=$(/usr/sbin/smartctl -q errorsonly -l error $1)
    if [ "x${STATUS}" != "x" ] || [ "x${SLFTST}" != "x" ] || [ "x${ERRORL}" != "x" ]; then
        BatchEcho "Vérification Smart du disque $1 KO" >&2
        echo ${STATUS} >&2
        echo ${ERRORL} >&2
        echo ${SLFTST} >&2
    else
        BatchEcho "Vérification Smart du disque $1 OK"
    fi
}

Purge() {

    if [ "x$1" = "x" ] || [ "x$2" = "x" ]; then
        echo "Utilisation: Purge [nb-jours] [rep]"
        return 1
    fi

    #Find created of modified files more than X days
    find $2 -ctime +$1 -mtime +$1 -type f -exec rm {} \;

    #Find empty directories, created of modified more than X days
    find $2 -depth -type d -empty -ctime +$1 -mtime +$1 -exec rmdir {} \;
}
