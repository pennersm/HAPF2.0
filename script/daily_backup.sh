#!/bin/bash
###########################################################################
# NSN INSTA HAPF2.1 PLATFORM SCRIPT
#--------------------------------------------------------------------------
# Script default name   : ~script/daily_backup.sh
# Configure version     : mkks62f.pl
# Media set             : PF21I52RH63-12
# File generated        : 03.01.2013 MPe
#
###########################################################################
TSTAMP=$(date +%d%m%Y-%H%M%S)
export -p  MYSELF="daily_backup.sh" ; TAG=$MYSELF
#----------------------------------------------------------------------------------
usage() {
bold=$(tput bold)
normal=$(tput sgr0)
printf "\n ${bold}USAGE:${normal}\n"
printf "\t backup script for HAPF2.1 files and Insta 5.0\n"
printf "\t -----------------------------------------------------------------------\n"
printf "\t daily_backup.sh {switch [value]}\n\n"
printf "\t ${bold}-include-icdb${normal} [ YES || NO ]\n"
printf "\t include an online backup of the certifier database (BE only)\n\n"
printf "\t ${bold}-include-deffiles${normal} [ YES || NO ]\n"
printf "\t Include hardocded default files/directories into backup. More files can just\n"
printf "\t be added somewhere in the configuration file by giving the abosulte file or\n"
printf "\t directory name.\n"
printf "\t Included per default in the file backup is /etc, /home, /root and further\n"
printf "\t on BE: /usr/local/certifier/var/pki and /usr/local/certifier/conf\n"
printf "\t on FE: /usr/local/certifsub/var/pki and /usr/local/certifsub/conf\n\n"
printf "\t ${bold}MIND${normal}, that ssh private or public key files in user-homes are excluded from the\n"
printf "\t backup for security reasons!!!!\n\n"
printf "\t ${bold}-keep-old-days${normal} [ number ]\n"
printf "\t number of days before an old backup directory is deleted, based on date of the\n"
printf "\t last modification made in the directory and its name pattern. Deletions are loged.\n\n"
printf "\t ${bold}-add-icdb-to-tar${normal} [ YES || NO ]\n"
printf "\t Wether to add the database backup to the tarball or not. If YES, all backed up\n"
printf "\t files will be inside one tarball, if NO, database file and log will be separate\n\n"
printf "\t ${bold}-cf${normal} [ filename ]\n"
printf "\t Specify a config filename where additional files/items can be included into the\n"
printf "\t default files from the OS backup. This file will also be read if the option\n"
printf "\t -include-deffiles is set to NO. In case no cf file is given on the command line\n"
printf "\t the script will look for a file ${HAPFCF}/hapf2-backup. If it exists and is readable\n"
printf "\t its content will be used\n\n"
printf "\t ${bold}-prepare-desaster-recovery${normal}\n"
printf "\t Prepare a media for desaster recovery procedure. Requires an original installation media\n"
printf "\t pluged in to the USB drive and mounted on /media\n\n"
printf "\t ${bold}-transplant [ filename ]${normal}\n"
printf "\t In normal backup modes as described above, the DB is taken as on target while other files\n"
printf "\t that relate to information stored in the DB, e.g. trustanchors or pins file, are included\n"
printf "\t in the DEFFILES set which also has user home directories and general, non-DB related host\n"
printf "\t configuration. As a shortcut, the \"-transplant\" option will only copy the DB and all its\n"
printf "\t external files like odbc.ini or trust anchors into the archive [ filename ]. This option \n"
printf "\t can be used to literally \"transplant\" a setup from e.g. a production environment into a\n"
printf "\t testplant with different IP addressing\n\n\n"
exit 1
}
shf_debug_break () {
        shf_cont () { : ; } ;
        echo "---------------- enter \"shf_cont\" to resume ------------------"
        unset line
        DBP="#-DEBUG-#"
        while [ "$line" != "shf_cont" ]
        do
                echo -n $DBP
                read line
                eval $line
        done
}
fetch_dbpass() {
        unset INITACC 
	local ACCFILE="${HAPFCF}/.dbacc_init"
	local CENGINE="/usr/local/certifier/conf/engine.conf"
	local ACCPERM="-r--------:root:root" 
	rc=1

        if [ -f ${ACCFILE} ] 
        then
		FNDPERM="$(ls -l ${ACCFILE}|awk '{print $1":"$3":"$4}'|tr -d '[:blank:].')"
                read -r INITACC < ${ACCFILE}
		GUIUN="$(echo ${INITACC}|cut -d':' -f 1|tr -d [:alnum:])"
		GUIPW="$(echo ${INITACC}|cut -d':' -f 2|tr -d [:graph:])"

		if [ -z "${GUIPW}" ] && [ -z "${GUIUN}" ] && [ "${ACCPERM}" = "${FNDPERM}" ]; then
			logger -p user.debug -t ${TAG} "fetched gui privileges from config ${ACCFILE}"
			rc=0
		elif [ "${ACCPERM}" != "${FNDPERM}" ]; then 
			logger -p user.warn -t ${TAG} "indiscreete file permissions on ${ACCFILE} - ignoring file"
			unset INITACC 
		else
			logger -p user.warn -t ${TAG} "found config ${ACCFILE} but can not identify proper content"
			unset INITACC
		fi
	else
		logger -p user.warn -t ${TAG} "found config ${ACCFILE} but can not identify proper content"
	fi
	: ${INITACC:="admin:admin"}

	if [ "${rc}" -eq "0" ]; then
		STAT="$(/usr/local/certifier/bin/ssh-ca-runenv /usr/local/certifier/bin/ssh-ca-tool \
                        EngineConf=${CENGINE} access=${INITACC} -x &>/dev/null)$?"
		DBCONN="$(/usr/local/certifier/bin/ssh-ca-runenv /usr/local/certifier/bin/ssh-ca-tool \
                	EngineConf=${CENGINE} access=${INITACC} -x)"
		if [ "${STAT}" -eq "0" ]; then
			echo "${DBCONN}"
			logger -p user.info -t ${TAG} "fetched db_password via gui privileges"
		fi	
		rc=${STAT}
	fi
	
	return ${rc}
}
#----------------------------------------------------------------------------------
if [ "`whoami`" != "root" ]
then
	logger -p user.info -t ${TAG} "attempt to run backup as \"`whoami`\" was rejected"
	echo "only root is allowed to start system backup"
	exit 1
fi
: ${MAINFLAG:="/etc/hapf21.flag"}
if [ ! -f ${MAINFLAG} ] 
then
	echo "not a complete HAPF2.1 installation"
	logger -p user.info -t ${TAG} "ERROR: stopping attempt to run backup in incomplete environment"
	exit 1
else
	source ${MAINFLAG}
	ROLE="${GENROLE}"
	logger -p user.debug -t ${TAG} "started for Role \"${ROLE}\""
	for HAENV in ${RUN[@]}; do source $HAENV; done
	shf_set_index
fi

if [[ "${ROLE}" == be[1,2] ]] || [ "${ROLE}" = "SingleServer" ]
then
	unset DBACT
	ICITHERE="$(cat /proc/mounts| grep /usr/local/certifier &>/dev/null)$?"
	CANACCES="$(fetch_dbpass &>/dev/null)$?"
	
	if [ "${ICITHERE}" -eq "0" ] && [ "${CANACCES}" -eq "0" ]
	then
		DBACT="TRUE"
		logger -p user.info -t ${TAG} "running for role \"${ROLE}\" - db active and accessible on \"$(uname -n)\""
		source /usr/local/certifier/bin/ssh-ca-env
		[ $? -eq 0 ] || (logger -p user.err -t ${TAG} "ERROR: no BE environment configuration found"; exit 1)
	elif [ "${ICITHERE}" -ne "0" ]; then
		DBACT="FALSE"
		logger -p user.info -t ${TAG} "running for role \"${ROLE}\" - db services not active on \"$(uname -n)\""
	elif [ "${CANACCES}" -ne "0" ]; then
		DBACT="FALSE"
		logger -p user.info -t ${TAG} "db services not accessible for role \"${ROLE}\" on \"$(uname -n)\""
	else
		DBACT="FALSE"
		logger -p user.info -t ${TAG} "undefined database or db-access status for role \"${ROLE}\" on \"$(uname -n)\""
	fi
fi
#----------------------------------------------------------------------------------
make_trans_archive() {
	printf "\n\n THIS PROCESS WILL HALT CERTIFIER SERVICES  !!! \n\n"
	printf " you know what you are doing and you have reasons to run this tool?\n"
	( shf_confirm "\n\n Please confirm that you are OK to halt certifier NOW:\n" ) || kill $$
	
	echo; while [ "$(/etc/init.d/certifier status &>/dev/null)$?" != "3" ]
	do
		crm resource stop certifier_engine &>/dev/null
		sleep 2; /etc/init.d/certifier stop
	done; echo	

	local TRANSARCH=$1
	ARCFILE="${TRANSARCH%%.*}.tar"
	touch "${ARCFILE}" || ( echo "can not write ${ARCFILE}!"; kill $$ )

	while read FILE; do
		[ -f ${FILE} ] && echo "${FILE}" || echo "can not find: ${FILE}"
		ARCDIR="$(dirname ${FILE})"
		sleep 1; tar -rf ${ARCFILE} -C ${ARCDIR} $(basename ${FILE}) &>/dev/null
		done<<FLIST
/usr/local/certifier/sybase/certifier.db
/usr/local/certifier/sybase/certifier.log	
/usr/local/certifier/conf/engine.conf
/usr/local/certifier/conf/engine-insecure.conf
/usr/local/certifier/conf/server.conf
/usr/local/certifier/conf/server-insecure.conf
/usr/local/certifier/var/pins
/usr/local/certifier/var/odbc.ini
/usr/local/certifier/var/pki/cacomm-client.crt
/usr/local/certifier/var/pki/cacomm-client.prv
/usr/local/certifier/var/pki/trusted_cacomm_ca.crt
/usr/local/certifier/lib/license-data.lic
FLIST
#
	WLDIR="/usr/local/certifier/var/acl"
	WLIST=( $( find "${WLDIR}" -type f 2>/dev/null ) )
	if [ "${#WLIST[@]}" != "0" ]; then for FILE in ${WLIST[@]}; 
	do 
		[ -f ${FILE} ] && echo "${FILE}" || echo "can not find: ${FILE}"
		tar -rf ${ARCFILE} -C ${WLDIR} $(basename ${FILE}) &>/dev/null
	done; fi
	gzip -f -9 ${ARCFILE}

	echo ; [ crm resource start certifier_engine &>/dev/null ] || \
	/etc/init.d/certifier start
	echo;echo "Archive created: $( ls -lah ${ARCFILE}.gz )"; 
}
#----------------------------------------------------------------------------------
prepare_desaster_recovery() {
	[ shf_usbdsk ] || return 5
	confirm() {
		echo "WARNING: existing archive will be overwritten: $1"
		DUMMY=""; while [[ "${DUMMY}" != [y,Y][eE][sS] ]]
		do
			echo "type \"yes\" to continue or abort with [CTRL]-[C]"
			read DUMMY
		done
		return 0
	}

	check_reco_avail() {
		export ROLE=$1
		shf_set_index
		SSHARC="sshconfig-root.${IPADDReth0[$X]}.${NOW}.tar"
		CORARC="coroconfig.${HBIPADDR[$X]}.${NOW}.tar"
		SSHOK="no" ; COROK="no"		

		( ls ${MTDIR}/$SSHARC &>/dev/null ) && SSHOK="yes"
		( ls ${MTDIR}/$CORARC &>/dev/null ) && COROK="yes"
		
		if [ "${COROK}" = "yes" ] && [ "${SSHOK}" = "yes" ]
		then
			printf "${ROLE:0:2}-cluster on ${HOSTNAME[$X]} + ${HOSTNAME[$Y]}\t: [OK] complete re-install info available\n" 
		
		else
			printf "${ROLE:0:2}-cluster on ${HOSTNAME[$X]} + ${HOSTNAME[$Y]}\t: [WARNING] none or incomplete recovery info !\n"
		fi

		echo "-----------------------------------------------------------------------------------------"
	}

	SSHARC="sshconfig-root.${IPADDReth0[$X]}.${NOW}.tar"
	CORARC="coroconfig.${HBIPADDR[$X]}.${NOW}.tar"
	
	( ls ${MTDIR}/${SSHARC} &>/dev/null ) && confirm ${MTDIR}/${SSHARC} 
	tar -Ppcf ${MTDIR}/${SSHARC} /root/.ssh    || (echo "ERROR: Can not write archive ${MTDIR}/${SSHARC}"; kill -TERM $$)
	cp -f ${MTDIR}/${SSHARC} ${MTDIR}/${SSHARC}.sav 2>/dev/null

	( ls ${MTDIR}/${CORARC} &>/dev/null ) && confirm ${MTDIR}/${CORARC}
	tar -Ppcf ${MTDIR}/${CORARC} /etc/corosync || (echo "ERROR: Can not write archive ${MTDIR}/$CORARC}"; kill -TERM $$)
	cp -f ${MTDIR}/${CORARC} ${MTDIR}/${CORARC}.sav 2>/dev/null	

	printf "\n\nTHIS MEDIA NOW CONTAINS DESASTER RECOVERY INFO FOR THE FOLLOWING NODES:\n\n"
	CHKSTR=""
	[ ! -z "${HOSTNAME[1]}" ] && CHKSTR="fe1 "
	[ ! -z "${HOSTNAME[3]}" ] && CHKSTR="${CHKSTR} be1 "
	[ ! -z "${HOSTNAME[5]}" ] && CHKSTR="${CHKSTR} fe3 "
	for ROLE in ${CHKSTR} ; do check_reco_avail $ROLE; done
	ROLE=${GENROLE}; export -p ROLE; shf_set_index
	printf "Exiting media preparation \n\n" 

kill -TERM $$ &>/dev/null
}
#----------------------------------------------------------------------------------
while [ $# != 0 ]
do
	case $1 in 
	-include-icdb)
		WITH_ICDB="$(echo $2|tr '[a-z]' '[A-Z]')"
		[ ${WITH_ICDB} = "YES" ] || [  ${WITH_ICDB} = "NO" ] || usage
		if [ ${WITH_ICDB} = "YES" ] ; then  [[ $ROLE == be[1,2] ]] || usage ; fi
		shift
	;;
	-include-deffiles)
		INCLUDE_DEFFILES="$(echo $2|tr '[a-z]' '[A-Z]')"
		[ ${INCLUDE_DEFFILES}="YES" ] || [ ${INCLUDE_DEFFILES}="NO" ] || usage
		shift
	;;
	-keep-old-days)
		KEEP_OLD_DAYS="$2"
		[ -z "$(echo ${KEPP_OLD_DAYS}|tr -d [0-9])" ] || usage 
		shift
	;;
	-add-icdb-to-tar)
		ADD_ICDB_TO_TAR="$(echo $2|tr '[a-z]' '[A-Z]')"
		[ ${ADD_ICDB_TO_TAR} = "YES" ] || [ ${ADD_ICDB_TO_TAR} = "NO" ] || usage
		shift
	;;
	-cf)
		CFFILE="$2"
		[ -r "${CFFILE}" ] || usage
		shift
	;;
	-prepare-desaster-recovery)
		prepare_desaster_recovery
	;;
	-transplant)
		TRANSARCH="$2";
		[ -d $(dirname ${TRANSARCH}) ] || ( echo "can not write into $(dirname $TRANSARCH)";usage )
		
		make_trans_archive ${TRANSARCH}
		shift
		kill $$
	;;
	*)
		usage
	;;
esac ; shift ; done
: ${CFFILE:="${HAPFCF}/hapf2-backup"}
#----------------------------------------------------------------------------------
# Following parameters are default and can be overwritten in above config file or by CLI
: ${WITH_ICDB:="YES"}
: ${INCLUDE_DEFFILES:="YES"}
: ${KEEP_OLD_DAYS:="10"}
: ${ADD_ICDB_TO_TAR:="NO"}
#-----------------------------------------------------------------------------------
if [ ! -r ${CFFILE} ]
then
        logger -p user.info -t ${TAG} "no configuration for backup - doing defaults including default cleaning!"
fi
#-----------------------------------------------------------------------------------
# script variables outside CLI
#-----------------------------------------------------------------------------------
BUSTAMP=$(date +%d%m%Y-%H%M%S)
BUROOT="/backup"
BUDSTDIR="${BUROOT}/hapf21-bak-${BUSTAMP}"
TMPDIR="/backup/tmp-${BUSTAMP}-$$"
DETLOG="hapf21-bak-${BUSTAMP}.log"
#-----------------------------------------------------------------------------------
#-----------------------------------------------------------------------------------
mkdir  ${TMPDIR}
chown root:root ${TMPDIR}
chmod 755 ${TMPDIR}
touch ${TMPDIR}/${DETLOG} 
chown root:root ${TMPDIR}/${DETLOG}
chmod 600 ${TMPDIR}/${DETLOG}
echo "starting \"${MYSELF}\" at \"$(date)\" on host \"$(uname -n)\"" | tee -a ${TMPDIR}/${DETLOG}
echo "options: WITH_ICDB=\"${WITH_ICDB}\" INCLUDE_DEFFILES=\"${INCLUDE_DEFFILES}\" KEEP_OLD_DAYS=\"${KEEP_OLD_DAYS}\" ADD_ICDB_TO_TAR=\"${ADD_ICDB_TO_TAR}\"" | tee -a ${TMPDIR}/${DETLOG}
logger -p user.info -t ${TAG} "starting WITH_ICDB=\"${WITH_ICDB}\" INCLUDE_DEFFILES=\"${INCLUDE_DEFFILES}\" KEEP_OLD_DAYS=\"${KEEP_OLD_DAYS}\" ADD_ICDB_TO_TAR=\"${ADD_ICDB_TO_TAR}\""

#-----------------------------------------------------------------------------------
if [ "${INCLUDE_DEFFILES}" = "YES" ]
then
	logger -p user.info -t ${TAG} "adding default files to backup"
	echo "adding default files to backup ..."
	find /root |grep -v ".ssh/id*" >> ${TMPDIR}/${DETLOG}
	echo "... added /root"
	find /home |grep -v ".ssh/id*" >> ${TMPDIR}/${DETLOG}
	echo "... added /home"
	find /etc                      >> ${TMPDIR}/${DETLOG}
	echo "... added /etc"

	if [[ "${ROLE}" == be[1,2] ]] || [ "${ROLE}" = "SingleServer" ] && [ ${DBACT} = "TRUE" ] 
	then
		find /usr/local/certifier/var  >> ${TMPDIR}/${DETLOG}
		echo "... added ~certifier/var"
		find /usr/local/certifier/conf  >> ${TMPDIR}/${DETLOG}
		echo "... added ~certifier/conf"
			
	elif [[ "${ROLE}" == "fe"[1,2,3,4] ]]
	then
		find /usr/local/certifsub/var/pki  >> ${TMPDIR}/${DETLOG}
		echo "... added ~certifsub/var/pki"
		find /usr/local/certifsub/var/odbc.ini >> ${TMPDIR}/${DETLOG}
		echo "... added ~certifsub/var/odbc.ini"
		find /usr/local/certifsub/conf >> ${TMPDIR}/${DETLOG}
		echo "... added ~certifsub/conf"
	fi	
	
	#-----------------------------------------------------------------------------------
fi
if [ -r ${CFFILE} ]
then
	logger -p user.info -t ${TAG} "checking \"${CFFILE}\" for additional files to back up"
	echo "checking \"${CFFILE}\" for additional files to back up"
	while read line 
	do 
		if [ -f "${line}" ] || [ -d "${line}" ]
		then
			find ${line} >> ${TMPDIR}/${DETLOG}
		fi
	done < ${CFFILE}
fi
if [ "$(cat ${TMPDIR}/${DETLOG}|wc -l)" -gt 2 ]
then
	echo "... archiving"
	sync && (tar -cf ${TMPDIR}/hapf21-OSfiles-${BUSTAMP}.tar ${TMPDIR}/${DETLOG} &>/dev/null) 
	rc="$(ls ${TMPDIR}/hapf21-OSfiles-${BUSTAMP}.tar &>/dev/null)$?"
	[ ${rc} -eq 0 ] || (logger -p user.info -t ${TAG} "ERROR: could not create archive \"${TMPDIR}/hapf21-OSfiles-${BUSTAMP}.tar\"")
	sync && (tar -rf ${TMPDIR}/hapf21-OSfiles-${BUSTAMP}.tar $(cat ${TMPDIR}/${DETLOG}|grep "^/"|cut -d' ' -f1) &>/dev/null)
	rc="$(ls ${TMPDIR}/hapf21-OSfiles-${BUSTAMP}.tar &>/dev/null)$?"
	[ ${rc} -eq 0 ] || (logger -p user.info -t ${TAG} "ERROR: can not update archive \"${TMPDIR}/hapf21-OSfiles-${BUSTAMP}.tar\"")
	gzip -9 ${TMPDIR}/hapf21-OSfiles-${BUSTAMP}.tar
	SIZSTR="$(ls -l ${TMPDIR}/hapf21-OSfiles-${BUSTAMP}.tar.gz|awk '{print $5}') or $(ls -lh ${TMPDIR}/hapf21-OSfiles-${BUSTAMP}.tar.gz|awk '{print $5}')"
	logger -p user.info -t ${TAG} "backup of OS files ended with status \"${rc}\" - size ${SIZSTR}" 
	echo "backup of OS files ended with status \"${rc}\" - size ${SIZSTR}"
fi
#-----------------------------------------------------------------------------------
if [ "${WITH_ICDB}" = "YES" ] && [ "${DBACT}" = "TRUE" ]
then
	CERTIFIER_DBCONN="$(fetch_dbpass)"	
	echo "running database online backup"  
	/opt/sqlanywhere12/bin64s/dbbackup -c "${CERTIFIER_DBCONN}" -x -d ${TMPDIR} ; rc=$?
	[ ${rc} -eq 0 ] || logger -p user.warn -t ${TAG} "WARNING: dbbackup exited with non zero status ${rc}"
	sync && sleep 1
	chown certfier:daemon ${TMPDIR}/certifier.db &>/dev/nul
	chown certfier:daemon ${TMPDIR}/certifier.log &>/dev/nul 	

	if [ "${ADD_ICDB_TO_TAR}" = "YES" ]
	then
		rc1="$(tar -cf ${TMPDIR}/cadb-${BUSTAMP}.tar  ${TMPDIR}/certifier.db &>/dev/null)$?"
		rc2="$(tar -rf ${TMPDIR}/cadb-${BUSTAMP}.tar  ${TMPDIR}/certifier.log &>/dev/null)$?"

		if [ "${rc1}" -eq 0 ] && [ "${rc2}" -eq 0 ] 
		then
			rm -f ${TMPDIR}/certifier.db
			rm -f ${TMPDIR}/certifier.log
			logger -p user.info -t ${TAG} "added certifier backup to archive \"cadb-${BUSTAMP}.tar\""
			gzip -9 ${TMPDIR}/cadb-${BUSTAMP}.tar
			DBBUARC="${TMPDIR}/cadb-${BUSTAMP}.tar.gz"
		else 
			logger -p user.warn -t ${TAG} "problem creating a tar archive of db backup!"
		fi
		
	else
			DBBUARC="${TMPDIR}"
	fi
	SIZSTR="$(du -b ${DBBUARC}) or $(du -h ${DBBUARC})"
	[ ${rc} -eq 0 ] && echo "database online backup done successfully"
	[ ${rc} -ne 0 ] && echo "database online backup done with errors"
	logger -p user.info -t ${TAG} "database online backup done dbbackup exited with status \"${rc}\""
fi	
#-----------------------------------------------------------------------------------
if [ "${KEEP_OLD_DAYS}" -ge 0 ]
then
	PATTERN="hapf21-bak-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9][0-9][0-9]"
	sync && DELD=( $(find ${BUROOT} -type d -name "${PATTERN}" -mtime +${KEEP_OLD_DAYS} -print ) ) && sync
	OLDS=${#DELD[@]} ; let i=0;
	echo "found \"${OLDS}\" old backups to delete..."
	while [ ! -z "${DELD[$i]}" ]
	do
		rm -rf ${DELD[$i]}
		logger -p user.info -t ${TAG} "deleted old backup ${DELD[$i]}"
		echo "pruning old backup ${DELD[$i]}"
		let i=$i+1
	done
fi
#-----------------------------------------------------------------------------------
[ -f ${BUDSTDIR} ] && (logger -p user.info -t ${TAG} "WARNING: backup destination directory already exists ... wait a minute or two before you try again!"; exit 1)
mkdir ${BUDSTDIR}
CURLINK="${BUROOT}/hapf21-bak-current"
[ -h "${CURLINK}" ] && rm -f ${CURLINK}
[ -d "${CURLINK}" ] || [ -f "${CURLINK}" ] && (mv -f ${CURLINK} ${CURLINK}_before-${BUSTAMP}.sav)
ln -s ${BUDSTDIR} ${CURLINK} || logger -p user.warn -t ${TAG} "WARNING: can not create softlink pointing to recent backup directory"
mv -f ${TMPDIR}/* ${BUDSTDIR}
if  [ "${WITH_ICDB}" = "YES" ] && [ "${ADD_ICDB_TO_TAR}" = "YES" ]
then
	tar -cf ${BUDSTDIR}/hapf21-bak-${BUSTAMP}.tar ${BUDSTDIR}/cadb-${BUSTAMP}.tar.gz &>/dev/null
	tar -rf ${BUDSTDIR}/hapf21-bak-${BUSTAMP}.tar ${BUDSTDIR}/hapf21-OSfiles-${BUSTAMP}.tar.gz &>/dev/null
	tar -rf ${BUDSTDIR}/hapf21-bak-${BUSTAMP}.tar ${BUDSTDIR}/hapf21-bak-${BUSTAMP}.log  &>/dev/null
	sync && rm -f  ${BUDSTDIR}/hapf21-OSfiles-${BUSTAMP}.tar.gz  ${BUDSTDIR}/cadb-${BUSTAMP}.tar.gz
fi
rm -rf ${TMPDIR}
logger -p user.info -t ${TAG} "backup placed into ${BUDSTDIR} script ended at $(date) on host $(uname -n)"
echo "created backup in ${BUROOT} with stamp ${TSTAMP} - exiting"
