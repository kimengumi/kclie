#!/bin/bash
#
# Kimengumi Command Line Interface Environnement
#
# Configurable Packaging script library
#
# Copyright 2017 Antonio Rossetti (https://www.kimengumi.fr)
#
# Licensed under the EUPL, Version 1.1 or – as soon they will be approved by
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


##############
# EXEMPLE DE SCRIPT D'APPEL

##!/bin/bash
#
#export SUFFIX="toto"
#export SRCPATH=/titi
#export PATCHDIR=/tata
#export BDD=tutu
#
#. /opt/kclie/lib/create.bash

# ARGUMENTS
export PREFIX=$1
export VERSIONDST=$2
export VERSIONSRC=$3

#AUTRE
export DATE=`date +%Y%m%d%H%M%S`

# FONCTIONS
GenerateRevisionTxt() {
	echo "Package de livraison : ${PREFIX}${SUFFIX} ${VERSIONDST}" > ${SRCPATH}/revision.txt
        echo "Package genere le : `date +%Y-%m-%d_%H-%M-%S`" >> ${SRCPATH}/revision.txt
        if [ "x${VERSIONSRC}" != "x" ] ; then
                echo "Incremental depuis package : ${PREFIXSRC}${SUFFIX} ${VERSIONSRC}" >> ${SRCPATH}/revision.txt
        fi

	if [ -e ${SRCPATH}/.svn ] ; then
		svn info ${SRCPATH} | grep vision | head -n 1 >> ${SRCPATH}/revision.txt
	elif [ -e ${SRCPATH}/.git ] ; then
		(cd ${SRCPATH} ; git log --pretty=format:'Revision: %h' -n 1 >> ${SRCPATH}/revision.txt )
		echo "" >> ${SRCPATH}/revision.txt
	fi

	echo "========================="
  cat ${SRCPATH}/revision.txt
	echo "========================="
}

# VERIFS PRELIMINAIRES
if [ "x${SUFFIX}" != "x" ] ; then
	export SUFFIX="-${SUFFIX}";
fi
if [ "x${SRCPATH}" = "x" ] ; then
	echo "variable SRCPATH non initalisÃ©e"
	exit 3
fi
if [ "x${PATCHDIR}" = "x" ] ; then
  echo "variable PATCHDIR non initalisÃ©e"
  exit 3
fi
if [ "x${BDD}" = "x" ] ; then
  echo "variable BDD non initalisÃ©e"
  exit 3
fi
cd ${SRCPATH}
if [ -e  ${PATCHDIR}/initial-${VERSIONDST}${SUFFIX}.tar.gz ] ; then
	echo "Attention le fichier ${PATCHDIR}/initial-${VERSIONDST}${SUFFIX}.tar.gz existe deja !"
	exit 2
fi
if [ -e  ${PATCHDIR}/patch-${VERSIONDST}${SUFFIX}.tar.gz ] ; then
  echo "Attention le fichier ${PATCHDIR}/patch-${VERSIONDST}${SUFFIX}.tar.gz existe deja !"
  exit 2
fi


# LIVRAISON INITIALE
if [ "x$1" = "xinitial" ] ; then

	# FICHIERS
	echo "crÃ©ation du fichier de livraison initiale ${PREFIX}-${VERSIONDST}${SUFFIX}.tar.gz ..."
	GenerateRevisionTxt
	tar --exclude-from=${PATCHDIR}/.${PREFIX}${SUFFIX}.exclude -zcf ${PATCHDIR}/${PREFIX}-${VERSIONDST}${SUFFIX}.tar.gz .

	if [ ! -e ${PATCHDIR}/${PREFIX}-${VERSIONDST}.sql.gz ] ; then

		# BDD
		echo "Dump de la base ${BDD} dans ${PREFIX}-${VERSIONDST}.sql.gz ..."
		mysqldump ${BDD} | gzip -9f > ${PATCHDIR}/${PREFIX}-${VERSIONDST}.sql.gz
	fi

# LIVRAISON PATCH
elif [ "x$1" = "xpatch" ] ; then

	if [ "x${VERSIONSRC}" = "x" ] ; then
		echo 'syntaxe create patch [version dest] [version src]'
		exit 2
	fi
	export PREFIXSRC=patch
        if [ ! -e  ${PATCHDIR}/${PREFIXSRC}-${VERSIONSRC}${SUFFIX}.tar.gz ] ; then
		export PREFIXSRC=initial
	fi
	if [ ! -e  ${PATCHDIR}/${PREFIXSRC}-${VERSIONSRC}${SUFFIX}.tar.gz ] ; then
               	echo "le fichier ${PATCHDIR}/${PREFIX}-${VERSIONSRC}${SUFFIX}.tar.gz n'existe pas !"
               	exit 2
        fi

	EPOCH=`date +"%s"`

	DATELAST=`stat -c "%Y" ${PATCHDIR}/${PREFIXSRC}-${VERSIONSRC}${SUFFIX}.tar.gz `
	EPOCH=`expr $EPOCH / 86400`
	DATELAST=`expr $DATELAST / 86400`
	DATELAST=`expr $EPOCH - $DATELAST`
	DATELAST=`expr $DATELAST + 1`

	echo "CrÃ©ation depuis le patch ${PREFIXSRC}-${VERSIONSRC}${SUFFIX}.tar.gz datÃ© de ${DATELAST} jours ..."
	GenerateRevisionTxt
	tar --exclude-from=${PATCHDIR}/.${PREFIX}${SUFFIX}.exclude -zcf ${PATCHDIR}/${PREFIX}-${VERSIONDST}${SUFFIX}.tar.gz `find . -type f -mtime -${DATELAST}`


# AUTRES SYNTAXES
else
	echo 'syntaxe create [initial/patch] [version dest] [version src]'
	exit 2
fi

# GENERATE SUMMARY
if [ -e  ${PATCHDIR}/${PREFIX}-${VERSIONDST}${SUFFIX}.tar.gz ] ; then
	cat ${SRCPATH}/revision.txt >> ${PATCHDIR}/${PREFIX}-${VERSIONDST}${SUFFIX}.recap.txt
	echo "=========================" >> ${PATCHDIR}/${PREFIX}-${VERSIONDST}${SUFFIX}.recap.txt
	echo "md5sum `md5sum ${PATCHDIR}/${PREFIX}-${VERSIONDST}${SUFFIX}.tar.gz `" >> ${PATCHDIR}/${PREFIX}-${VERSIONDST}${SUFFIX}.recap.txt
	echo "=========================" >> ${PATCHDIR}/${PREFIX}-${VERSIONDST}${SUFFIX}.recap.txt
	if [ "x$1" = "xpatch" ] ; then
		echo "CHANGELOG" >> ${PATCHDIR}/${PREFIX}-${VERSIONDST}${SUFFIX}.recap.txt
		DATELAST=`stat -c "%Y" ${PATCHDIR}/${PREFIXSRC}-${VERSIONSRC}${SUFFIX}.tar.gz `
		DATELAST=`date +%Y-%m-%d -d @${DATELAST}`

        	if [ -e ${SRCPATH}/.svn ] ; then
			REVHEAD=`svn info ${SRCPATH} | grep vision | head -n 1 | cut -d" " -f2`
			svn log  -r{${DATELAST}}:${REVHEAD} ${SRCPATH} | perl -nwle 'print unless m/^((r\d)|(-)|($))/' | sort | uniq >> ${PATCHDIR}/${PREFIX}-${VERSIONDST}${SUFFIX}.recap.txt
		elif [ -e ${SRCPATH}/.git ] ; then
                	( cd ${SRCPATH} ; git log --pretty=oneline --since=${DATELAST} | cut -d " " -f 2-255 | sort | uniq >> ${PATCHDIR}/${PREFIX}-${VERSIONDST}${SUFFIX}.recap.txt )
        	fi

		echo "=========================" >> ${PATCHDIR}/${PREFIX}-${VERSIONDST}${SUFFIX}.recap.txt
	fi
	tar -tf ${PATCHDIR}/${PREFIX}-${VERSIONDST}${SUFFIX}.tar.gz >> ${PATCHDIR}/${PREFIX}-${VERSIONDST}${SUFFIX}.recap.txt
	echo "=========================" >> ${PATCHDIR}/${PREFIX}-${VERSIONDST}${SUFFIX}.recap.txt
fi
