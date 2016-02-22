#!/bin/sh

export SCRIPT_NAME=""
export HOSTNAME=`hostname`
export NFS_VERROU=""
export IS_FULL_DAY=""
export CURRENT_WEEK_DAY=`date +%u`
export CURRENT_MONTH_DAY=`date +%d`
export DEFAULT_BACKUP_DIR="/home/backup"
export DEFAULT_LOG_DIR="/var/log/kimengumi"
export DEFAULT_LIB_DIR="/var/lib/kimengumi"

Init() {
        if [ "x$1" = "x" ] ; then
                echo 'Init : pas de nom';
                exit 1
        fi
	SCRIPT_NAME=$1

	# SHM selon système
	if [ -d /run/shm ] ; then
		SHMDIR="/run/shm"
	elif [ -d /dev/shm ] ; then
		SHMDIR="/dev/shm"
	else
		SHMDIR="/tmp"
	fi

	# blocage du lancement concurrent
	EXISTINGPROC=`ps -eaf | grep "$0" | egrep -v "$$|$PPID|grep" 2>/dev/null`
	EXISTINGFIFO=`ls --color=never -d ${SHMDIR}/${SCRIPT_NAME}_*_fifo_err 2>/dev/null`
	if [ "x${EXISTINGFIFO}" != "x" ] ; then
		if [ "x${EXISTINGPROC}" != "x" ] ; then
			echo "Une autre instance de \"${SCRIPT_NAME}\" est deja en cours d'execution !" >&2
			echo "Annulation de l'execution" >&2
			echo "---" >&2
			ps -eaf | head -n 1 >&2 
			echo "${EXISTINGPROC}" >&2
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
        tee -a ${DEFAULT_LOG_DIR}/${SCRIPT_NAME}.log < ${SHMDIR}/${SCRIPT_NAME}_$$_fifo_err &
        exec >> ${DEFAULT_LOG_DIR}/${SCRIPT_NAME}.log 2> ${SHMDIR}/${SCRIPT_NAME}_$$_fifo_err
        echo "============================================"
	echo "## `date +"%T ## %F"` ## Début de ${SCRIPT_NAME} ##"
	BackupSetDayFull 6 #samedi
}

Fin() {
        echo "## `date +"%T ## %F"` ## Fin de ${SCRIPT_NAME} ##"
        rm ${SHMDIR}/${SCRIPT_NAME}_$$_fifo_err
}

Title() {
	echo "## `date +"%T"` ## $1 ##"
}

NfsMountBackup() {
	Title "Montage de ${DEFAULT_BACKUP_DIR}"
	umount ${DEFAULT_BACKUP_DIR} --force 2> /dev/null
	mount  ${DEFAULT_BACKUP_DIR}
        if [ ! -d ${DEFAULT_BACKUP_DIR}/${HOSTNAME} ] ; then
                echo "LE PARTAGE DE BACKUP NE SEMBLE PAS MONTE - ARRET DU SCRIPT" >&2
		Fin
		exit 1
        fi

}

NfsUmountBackup() {
	Title "Démontage de ${DEFAULT_BACKUP_DIR}"
	umount ${DEFAULT_BACKUP_DIR} --force || (echo "ERREUR AU DEMONTAGE DISQUE BACKUP" >&2 )
}

NfsVerrou() {
	if [ -e ${DEFAULT_BACKUP_DIR}/verrou_* ] ; then
		echo -n "Un verrou NFS à été posé: Attente"
		while ls ${DEFAULT_BACKUP_DIR}/verrou_* >/dev/null 2>&1 ; do
			echo -n '.'
			sleep 300 # 5min
		done
		echo -n "\n"
	fi
	touch ${DEFAULT_BACKUP_DIR}/verrou_${HOSTNAME}_${SCRIPT_NAME} || (echo "Impossible de poser le verrou NFS" >&2)
	NFS_VERROU="1"
}

NfsVerrouRemove() {
        rm ${DEFAULT_BACKUP_DIR}/verrou_${HOSTNAME}_${SCRIPT_NAME} || (echo "Impossible de supprimer le verrou NFS" >&2)
	NFS_VERROU=""
}

NfsVzDumpAll() {
        Title 'sauvegarde VMs'
	# VZdump sort tout en sortie erreur. on passe donc par un fichier temporaire, puis un grep pour remonter uniquement les vrais erreurs.
        vzdump -all 1 -compress lzo -maxfiles 1 -stdexcludes 1 -dumpdir ${DEFAULT_BACKUP_DIR}/vzdump/ >/tmp/vzdump.log 2>&1
        cat /tmp/vzdump.log
        grep -v 'INFO:' /tmp/vzdump.log >&2
}

BackupMysql() {
	# backup & archivage sur 1 mois
	# usage : BackupMysql [REP(optionel)] [nogzip(desactive gzip)]

	USER="--defaults-extra-file=/etc/mysql/debian.cnf"
	DAY=`date +%d`
	REP="$1"
	GZIP="$2"
	if [ "x${REP}" = "x" ] ; then
		HOSTNAME=`hostname -s`
	        REP="${DEFAULT_BACKUP_DIR}/${HOSTNAME}/mysql"
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


BackupSetWeekDayFull() {
        if [ "x${CURRENT_WEEK_DAY}" = "x$1" ] ; then
                ISFULL="1";
        else
                ISFULL="";
        fi
}

BackupSetMonthDayFull() {
		# La première occurrence du jour de la semaine dans le mois.

        if [ "x${CURRENT_WEEK_DAY}" = "x$1" ] ; then
                if [ "${CURRENT_MONTH_DAY}" -le "$1" ] ; then
                        ISFULL="1";
                else
                        ISFULL="";
                fi
        else
                ISFULL="";
        fi
}

BackupRep() {
	# backup & archiv incrémentale sur 7 jours & archivage sur 30 jours
	# usage : BackupRep [REP] [none/lzop/gzip (optionnel, default gzip)] [DEST(optionnel)]

	REP="$1"
	GZIP="$2"
	TAREP="$3"
	if [ "x${REP}" = "x" ] || [ ! -d  "${REP}" ] ; then
	        echo "BackupRep [REP] [none/lzop/gzip (optionnel, default gzip)] [DEST(optionnel)]" >&2
	        return 1
	fi
	SNAPREP="${DEFAULT_LIB_DIR}/backuprep/"
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
	        TAREP="${DEFAULT_BACKUP_DIR}/`hostname -s`/${NOM}"
	fi
	if [ ! -d ${TAREP} ] ; then
	        mkdir -p ${TAREP} || return 4
	fi
	SNAPSHOT="${SNAPREP}/${NOM}.snapshot"
	if [ "x${IS_FULL_DAY}" = "x1" ] && [ -e ${SNAPSHOT} ]; then
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
	        tar --listed-incremental=${SNAPSHOT} ${EXCLUDE} -cpf ${TAREP}/${NOM}.${CURRENT_MONTH_DAY}.tar .
	elif [ "x${GZIP}" = "xlzop" ] ; then
	        tar --listed-incremental=${SNAPSHOT} ${EXCLUDE} --lzop -cpf ${TAREP}/${NOM}.${CURRENT_MONTH_DAY}.tar.lzo .
	else
		tar --listed-incremental=${SNAPSHOT} ${EXCLUDE} -zcpf ${TAREP}/${NOM}.${CURRENT_MONTH_DAY}.tar.gz .
	fi
}

RsyncRep() {
	if [ "x$1" = "x" ] ; then
	        echo "veuillez spécificer un répertoire (sans le / final)"
	        return 1
	fi
	HOSTNAME=`hostname`
	if ls ${DEFAULT_BACKUP_DIR}/${HOSTNAME}$1 > /dev/null
	then
	        Title "Rsync de $1"
	        nice -n19 rsync -rltgoD --del --ignore-errors --force --exclude="lost+found" --delete-excluded $1/ ${DEFAULT_BACKUP_DIR}/${HOSTNAME}$1
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
	else
	        echo -e "\n!!! $1: repertoire de backup ${DEFAULT_BACKUP_DIR}/${HOSTNAME}$1 inacessible !!!"
	fi
}	
	
RotateLog() {
        FICTAILLE=$(stat -c%s "$1")
        if [ "x$FICTAILLE" = "x0" ] ; then
                rm -f $1
                # fichier vide rien à archiver, on fait le ménage
        elif [ "$FICTAILLE" -gt "10485760" ] ; then
                gzip -f9S .`date +%j`.gz $1
                # format fichier compressé: [nom_fichier].[num_jour_semaine].gz
        fi
}

RotateApache() {
	Title "Rotation des logs Apache"
	for FIC in /var/log/apache2/*log
	do
        	RotateLog $FIC
	done
	/etc/init.d/apache2 reload
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
