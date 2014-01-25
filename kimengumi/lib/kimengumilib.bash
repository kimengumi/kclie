#!/bin/sh

export NOMSCRIPT=""
export HOSTNAME=`hostname`
export ISFULL=""
export CURWDAYNB=`date +%u`
export CURMDAYNB=`date +%d`

Init() {
        if [ "x$1" = "x" ] ; then
                echo 'Init : pas de nom';
                exit 1
        fi
	NOMSCRIPT=$1
	PGREP=`ps -eaf | grep "$0" | egrep -v "$$|$PPID|grep"`
	if [ "x${PGREP}" != "x" ] ; then
		echo "Une autre instance de \"${NOMSCRIPT}\" est déjà en cours d'éxecution !" >&2
		echo "Annulation de l'éxecution" >&2
		echo "---" >&2
		ps -eaf | head -n 1 >&2 
		echo "${PGREP}" >&2
		exit 2
	fi
        mkfifo /dev/shm/ferr_$$_${NOMSCRIPT}
	mkdir -p /var/log/kimengumi/
        tee -a /var/log/kimengumi/${NOMSCRIPT}.log < /dev/shm/ferr_$$_${NOMSCRIPT} &
        exec >> /var/log/kimengumi/${NOMSCRIPT}.log 2> /dev/shm/ferr_$$_${NOMSCRIPT}
        echo "============================================"
	echo "## `date +"%T ## %F"` ## Début de ${NOMSCRIPT} ##"
	BackupSetWeekDayFull 7 #dimanche
}

Fin() {
        echo "## `date +"%T ## %F"` ## Fin de ${NOMSCRIPT} ##"
        rm /dev/shm/ferr_$$_${NOMSCRIPT}
}

Title() {
	echo "## `date +"%T"` ## $1 ##"
}

BackupSetWeekDayFull() {
        if [ "x${CURWDAYNB}" = "x$1" ] ; then
                ISFULL="1";
        else
                ISFULL="";
        fi
}

BackupSetMonthDayFull() {
        if [ "x${CURWDAYNB}" = "x$1" ] ; then
                if [ "${CURMDAYNB}" -le "$1" ] ; then
                        ISFULL="1";
                else
                        ISFULL="";
                fi
        else
                ISFULL="";
        fi
}

BackupMysql() {
	# backup & archivage sur 1 mois
	# usage : BackupMysql [REP(optionel)] [nogzip(desactive gzip)]

	USER="--defaults-extra-file=/etc/mysql/debian.cnf"
	DAY=`date +%d`
	REP="$1"
	GZIP="$2"
	if [ "x${REP}" = "x" ] ; then
	        REP="/home/backup/mysql"
	fi
	echo "sauvegarde des bases dans ${REP}"
	if [ ! -d ${REP} ] ; then
	        mkdir -p ${REP} || return 4
	fi
	for BASE in $(mysql ${USER} -Bse 'show databases') ; do
	        if [ "x${BASE}" != "xinformation_schema" ] && [ "x${BASE}" != "xperformance_schema" ] ; then
	                Title "sauvegarde de la base ${BASE}"
			if [ "x${BASE}" = "xmysql" ] ; then
				EXTRAOPTIONS="--events"
			else
				EXTRAOPTIONS=""
			fi
	                if [ "x${GZIP}" != "x" ] ; then
	                        mysqldump ${USER} -f ${BASE} ${EXTRAOPTIONS} > ${REP}/${BASE}.${DAY}.sql
	                else
	                        mysqldump ${USER} -f ${BASE} ${EXTRAOPTIONS} | gzip -f > ${REP}/${BASE}.${DAY}.sql.gz
	                fi
	        fi
	done
}

BackupRep() {
        # backup incrémentale sur 7 jours & archivé sur 30 jours
        # usage : BackupRep [REP] [none/lzop/gzip (optionnel, default gzip)] [DEST(optionnel)]

        REP="$1"
        GZIP="$2"
        TAREP="$3"
        if [ "x${REP}" = "x" ] || [ ! -d  "${REP}" ] ; then
                echo "BackupRep [REP] [none/lzop/gzip (optionnel, default gzip)] [DEST(optionnel)]" >&2
                return 1
        fi
        SNAPREP="/var/lib/Kimengumi/backuprep/"
        if [ ! -d ${SNAPREP} ] ; then
                mkdir -p ${SNAPREP} || return 4
        fi
        if [ "x${REP}" = "x/etc" ] && [ -f /usr/bin/dpkg ]; then
                /usr/bin/dpkg --get-selections > /etc/apt/`hostname -s`.paquets
        fi
        if [ "x${REP}" = "x/" ] ; then
                NOM="root"
        else
                NOM=`echo ${REP} | sed -e 's/\///' -e 's/\//-/g'`
        fi
        if [ "x${TAREP}" = "x" ] ; then
                TAREP="/home/backup/${NOM}"
        fi
        if [ ! -d ${TAREP} ] ; then
                mkdir -p ${TAREP} || return 4
        fi
        SNAPSHOT="${SNAPREP}/${NOM}.snapshot"
        if [ "x${ISFULL}" = "x1" ] && [ -e ${SNAPSHOT} ]; then
                rm ${SNAPSHOT} || return 3
        fi
        if [ -e  ${REP}/.backup-exclude ] ; then
                EXCLUDE="--exclude-from=${REP}/.backup-exclude"
        else
                if [ -e  ${TAREP}/.exclude ] ; then
                        EXCLUDE="--exclude-from=${TAREP}/.exclude"
                fi
        fi
        cd ${REP} || return 2
        Title "Sauvegarde de ${REP} dans ${TAREP} ..."
        if [ "x${GZIP}" != "x" ] && [ "x${GZIP}" != "xlzop" ] && [ "x${GZIP}" != "xgzip" ] ; then
                tar --listed-incremental=${SNAPSHOT} ${EXCLUDE} -cpf ${TAREP}/${NOM}.${CURMDAYNB}.tar .
        elif [ "x${GZIP}" = "xlzop" ] ; then
                tar --listed-incremental=${SNAPSHOT} ${EXCLUDE} --lzop -cpf ${TAREP}/${NOM}.${CURMDAYNB}.tar.lzo .
        else
                tar --listed-incremental=${SNAPSHOT} ${EXCLUDE} -zcpf ${TAREP}/${NOM}.${CURMDAYNB}.tar.gz .
        fi
}

SmartCheckDisk() {
        if [ "x$1" = "x" ] ; then
                echo "veuillez spécificer un disque (ex: /dev/sda)"
                return 1
        fi
        STATUS=`/usr/sbin/smartctl -q errorsonly -H $1`
        SLFTST=`/usr/sbin/smartctl -q errorsonly -l selftest $1`
        ERRORL=`/usr/sbin/smartctl -q errorsonly -l error $1`
        if [ "x${STATUS}" != "x" ] || [ "x${SLFTST}" != "x" ] || [ "x${ERRORL}" != "x" ]
        then
                Title "Vérification Smart du disque $1 KO"  >&2
                echo ${STATUS} >&2
                echo ${ERRORL} >&2
                echo ${SLFTST} >&2
        else
                Title "Vérification Smart du disque $1 OK"
        fi
}

