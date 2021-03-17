#!/bin/bash
###########################################################################
# NSN INSTA HAPF2.1 RAPID SETUP CONFIG GENERATOR SCRIPT
#--------------------------------------------------------------------------
# Script default name   : ~script/config_insta.sh
# Configure version     : mkks62f.pl
# Media set             : PF21I52RH63-12
# File generated        : 03.01.2013 MPe
#
###########################################################################
export -p  MYSELF="config_insta.sh"
shf_logit "#-----------------------------------------------------------------"
shf_logit "starting to run script ${MYSELF}"
shf_logit "#-----------------------------------------------------------------"
#
ROLE=$1           ;  if [ -z "${ROLE}"    ] ; then exit ; fi
DRBDDEV=$2        ;  : ${DRBDDEV:="/dev/drbd1"}
shf_set_index
shf_logit "Using Role $ROLE in here, configure index $X"

CUSER=$2          ;  : ${CUSER:="certfier"}
CGROUP=$3         ;  : ${CGROUP:="daemon"}
                     : ${SNMPUSER:="certifier"}
                     : ${SNMPV3PASSPHRASE[$X]:="certifier_passphrase"}
DRBDRES=$4        ;  : ${DRBDRES:="certifier"}
export -p SHELLOG=${INSTDIR}/${MYSELF}.${ROLE}.${NOW}.shell.log
shf_logit "${NOW} using ARGS: `echo $*`"
shf_logit "will pass on: Unix user ${CUSER}:${CGROUP} USM user ${SNMPUSER} pass ${SNMPV3PASSPHRASE[$X]}" 
shf_logit "creating file to log command outputs: ${SHELLOG}"
EXIT_ON_FAIL="HARD"
cat /dev/null > ${SHELLOG}
echo "starting shellog for ${NOW} ${MYSELF} `date`" &>> ${SHELLOG}
set &>> ${SHELLOG}
echo "=======================================================================" &>> ${SHELLOG}
#
case ${ROLE} in 
	be1|be2|SingleServer)
		MYDIR="/usr/local/certifier"
		MYNAM="certifier"
		
		if [ ! -z "${SNMPV3PASSPHRASE[$X]}" ]; then
			CCMD="${INSTDIR}/insta/ssh-encrypt"
			chown root:root ${CCMD}
			chmod +x ${CCMD}
			[ -x "${CCMD}" ] || shf_logit "ERROR: can not find or execute tool to encrypt snmpv3 passphrase"

			ICSNMPPASS="$( echo ${SNMPV3PASSPHRASE[$X]}|${CCMD} -E -s -x -c aes-cbc )"
			shf_logit "encrypted certifier snmp passphrase for engine.conf to \"${ICSNMPPASS}\""
		fi

	;;
	fe1|fe2|fe3|fe4)
		MYDIR="/usr/local/certifsub"
		MYNAM="certifsub"
		FROMKS="/usr/local/certifier"	
		OLDNAM=`basename ${FROMKS}`
		FILE="/etc/fstab"
		
		umount ${FROMKS} &>/dev/null
		mv ${FROMKS} ${MYDIR} &>/dev/null
		cp -f ${FILE} ${BACKDIR}/`basename ${FILE}`.${ROLE}.${NOW}
		cat ${FILE} |grep -v "boot/efi"  > ${FILE}.tmp
		sed s/${OLDNAM}/${MYNAM}/g ${FILE}.tmp  > ${FILE}
		rc=$(mount -o rw -a)$?
		[ ${rc} -ne 0 ] &&  shf_logit "ERROR: mount new mountpoint ${MYNAM} returned with ${rc}"
		shf_logit "new mountpoint in ${FILE}: \"`grep ${MYDIR} ${FILE}|tr --squeeze-repeats ' '|tr  "\n" " "`\""
		shf_logit "${MYNAM} is active as: \"`grep ${MYNAM} /etc/mtab`\""
	;;
	*)
		shf_logit "can not assign mapping for role ${ROLE}, exiting"
		return 3
	;;
esac

shf_logit "starting in directory ${MYDIR} as ${MYNAM}"
#==============================================================================
		shf_fshow rpm -e ${MYNAM}
		shf_fshow rpm -Uvh "${INSTDIR}/insta/${MYNAM}*.rpm"
		shf_logit "installed insta ${MYNAM} rpm: \"`rpm -q ${MYNAM}`\""

#------------------------------------------------------------------------------
FILE="/usr/local/${MYNAM}/lib/license-data.lic"
MYLIC="${INSTDIR}/insta/license-data.lic"

if [ -r ${MYLIC} ]
then	
	rm -f ${FILE}
	cp -f ${MYLIC} ${FILE}
	chmod 0640 ${FILE}
	chown ${CUSER}:${CGROUP} ${FILE} 2>/dev/null
	shf_logit "copied license file into place: \"`ls -la ${FILE}`\""
	shf_fshow ${FILE}
else
	shf_logit "can not find license file - you will have to copy it manually after installation "
fi		
#------------------------------------------------------------------------------
SCRIPT="${MYDIR}/ssh-ca-setup-nsn-${MYNAM}.sh"
CASETUP="${INSTDIR}/insta/ssh-ca-setup-nsn-${MYNAM}.sh"

if [ -r ${CASETUP} ]
then	
	cp -f ${CASETUP} ${SCRIPT}
	chmod 0750 ${SCRIPT}
	chown root:root ${SCRIPT}
	shf_logit "copied customized setup script into place: \"`ls -la ${SCRIPT}`\""
else
	shf_logit "can not find nsn setup script - your installation will NOT be successfull"
fi		

#------------------------------------------------------------------------------
FETOOL="${MYDIR}/bin/enrolfe"
ERTOOL="${INSTDIR}/insta/enrolfe"

if [ -r ${ERTOOL} ]

then   
        cp -f ${ERTOOL} ${FETOOL}
        chmod 0750 ${FETOOL}
        chown ${CUSER}:${CGROUP} ${FETOOL} 2>/dev/null
        shf_logit "copied FE enrolement script into place: \"`ls -la ${FETOOL}`\""

	ln -s /usr/local/${MYNAM}/lib/libodbc.so.1 /lib64/tls/
	shf_logit "softlinked odbc client lib for enrolments to \"/lib64/tls\""
else
        shf_logit "can not find tool to enroll FE - your installation will *NOT* be successfull"
fi

###############################################################################
#------------------------------------------------------------------------------
# leave the logic of Insta setup script as untouched as possible
# interactive dialogue should be avoided by exporting whats needed
# 	
case ${ROLE} in
	be1|be2|SingleServer)
		export -p efile="/dev/random"	
		export -p cuser="${CUSER}"
		export -p SNMP_USER="${SNMPUSER}"
		export -p SNMP_PASSWORD="${ICSNMPPASS}"
		
		shf_fast_entropy on

		shf_logit "sourcing external script : `ls -l ${SCRIPT}`" 
		. ${SCRIPT} ${ROLE} ${SNMPENA[$X]} |tee -a ${SHELLOG}; rc=$?
		export -p  MYSELF="config_insta.sh"
		shf_logit "back with return $rc from external script : `ls -l ${SCRIPT}`"
		kill %1 &>/dev/null 
		sleep 1
		
		shf_fast_entropy off
	;;
#------------------------------------------------------------------------------
	fe1|fe2|fe3|fe4)
	
		SYSDEFIP=`awk -F '\"' '/address/ {print $2}' < ${MYDIR}/conf/server-conf.dist|cut -d':' -f 2|sed "s/\///g"` &>>$SHELLOG	
		if [ ! -z "`echo ${SYSDEFIP}|awk -F. '(($1<255) && ($2<255) && ($3<255) && ($4<255)){print$1"."$2"."$3"."$4}'`" ]
		then
			shf_logit "found TLS IP for FE-BE communication in server-conf.dist: ${SYSDEFIP}"
		else
			SYSDEFIP="127.0.0.1"
			shf_logit "assuming default TLS IP for FE-BE communication ${SYSDEFIP}"
		fi	

		DEFPORT=`grep -A 8 "ca-engine" ${MYDIR}/conf/server-conf.dist |cut -d'"' -f2|awk -F: '($1=="tcp"){print$3}'|sed 's/[/]*$//g'`
		if [ -z "`echo ${DEFPORT} | tr -d '[0-9]'`" ] && [ ${DEFPORT} -le 65535 ]
		then 
			shf_logit "found TLS port for FE-BE communication in server-conf.dist: ${DEFPORT}"
		else
			DEFPORT=7001
			shf_logit "assuming default TLS port for FE-BE communication ${DEFPORT}"		
		fi

		if [ ! -z "${LOCALINTIP[$Z]}" ] && ( ping -n -c 5 -q ${LOCALINTIP[$Z]} &> /dev/null) 
		then
			REMBEIP[$X]="${LOCALINTIP[$Z]}:${DEFPORT}"
			shf_logit "probe success - suggesting IP address for FE-BE communication to tcp://${REMBEIP[$X]}"
		elif [ -z "${LOCALINTIP[$Z]}" ] && [ ! -z "${VLAN1IPvirtual[$Z]}" ] && ( ping -n -c 5 -q ${VLAN1IPvirtual[$Z]} &>/dev/null )
		then
			REMBEIP[$X]="${VLAN1IPvirtual[$Z]}"
			shf_logit "No local IP for FE-BE communication defined - will use remote ${REMBEIP[$X]} in VLAN ${VLAN1ID[$X]}" 
		elif ( ping -n -c 5 -q ${IPADDReth0[$Z]} &>/dev/null ) ; then
			REMBEIP[$X]="${IPADDReth0[$Z]}:${DEFPORT}"
			shf_logit "BE has no reachable HA-IPs and no IP for FE-BE communication defined - assuming remote BE TLS on ${REMBEIP[$X]}:${DEFPORT}"
		elif ( ping -n -c 5 -q ${SYSDEFIP} &>/dev/null ) ; then
			REMBEIP[$X]="tcp://${SYSDEFIP}:${DEFPORT}/"
			shf_logit "No IP for FE-BE communication foun - dassuming remote BE IP as ${REMBEIP[$X]}:${DEFPORT}"
		else
			REMBEIP[$X]="127.0.0.1:${DEFPORT}"
			shf_logit "no IP connection to BE for enrollments can be verified - you MUST enter remote IP manually later" 
		fi
		

		FILE="/etc/profile"
		cp -f ${FILE} ${BACKDIR}/$(basename ${FILE}).${ROLE}.${NOW}
#################################################################################
		echo "${FETOOL} -ip ${REMBEIP[$X]} -isinstall" >> $FILE
		shf_logit "added line to ${FILE}: \"${FETOOL} -ip ${REMBEIP[$X]} -isinstall\""
	;;
esac

#------------------------------------------------------------------------------
###############################################################################	
case ${ROLE} in 
	be1)
		cd / ;shf_fshow rm -rf ${MYDIR}/*
		shf_fshow ${MYDIR}
		shf_logit "left be1 with empty mountpoint \"`ls -l ${MYDIR}`\""
	;;
	be2)
		cd / ;shf_fshow fuser ${MYDIR}; cd ${INSTDIR}/script
		shf_logit "DRBD resource activated on host: \"`drbd-overview`\""
		shf_logit "local DRBD master has active built: \"`du -sh ${MYDIR}|tr --squeeze-repeats ' ' `\" in \"`find ${MYDIR}|wc -l`\" files" 
	;;
	fe1|fe2|fe3|fe4)
		shf_fshow ${MYDIR}
		shf_logit "prepared all in: \"`du -sh ${MYDIR}|tr --squeeze-repeats ' ' `\" in \"`find ${MYDIR}|wc -l`\" files and \"`ls -l /etc/profile`\""
		shf_logit "now do login as root to enroll fe and finish insta installation"  
	;;
esac 
#------------------------------------------------------------------------------
FILE="/etc/init.d/${MYNAM}"
INIT="${INSTDIR}/insta/init-script.sh"

if [ -r ${INIT} ]
then
	mv -f ${FILE} ${INSTDIR}/backup/initscript.dist.${ROLE}.${NOW} &>/dev/null
	cp -f ${INIT} ${FILE}
	chmod 0755 ${FILE}
	chown root:root ${FILE}
	shf_logit "copied init script into place: \"`ls -la ${FILE}`\""
	if [ ${ROLE} != "SingleServer" ] 
	then
		chcon -R -h system_u:object_r:corosync_initrc_exec_t:s0 ${FILE}
		shf_logit "changed security context to that of corosync: \"`ls -Z ${FILE}`\""
	fi
	chkconfig --level 0123456 ${MYNAM} off
	if [ "${ROLE}" != "SingleServer" ] ; then
		shf_logit "disable init-start of ${MYNAM}: \"$(chkconfig |grep certifier|tr '\t' ' ' | tr --squeeze-repeats ' ')\""
	else
		chkconfig --level 45 ${MYNAM} on
		shf_logit "enable init-start of ${MYNAM}: \"$(chkconfig |grep certifier|tr '\t' ' ' | tr --squeeze-repeats ' ')\""
	fi
else
	shf_logit "can not find init-script - you will have to copy it manually after installation "
fi
#------------------------------------------------------------------------------
FILE="/etc/passwd"
NSNPW="\$6\$eyDFfDfF\$yLFT8G9SJ5mlj24waKApdO5kHzJj9.bijOk6YRkmg/fYhkgewkqySwUIEtkDj1XCAiCDWvYhNbklloIGoXxr60"

if [ "`grep "^${CUSER}:" ${FILE}|awk -F: '{print$1}'`" != "${CUSER}" ]
then
	userdel -fr ${CUSER} &>/dev/null
	useradd -b /home -m -c "Insta Certifier user" -p ${NSNPW} -s /bin/bash -g daemon -u 502 ${CUSER} &>/dev/null	
	shf_logit "added user \"`grep "^${CUSER}:" ${FILE}`\""
else
	usermod -p ${NSNPW} ${CUSER} &>/dev/null
	shf_logit "set new password for user \"`grep "^${CUSER}:" ${FILE}`\""
fi
#
#------------------------------------------------------------------------------
FILE="${MYDIR}/conf/engine.conf"

if [ "${ROLE}" = "be2" ]
then
	[ -f ${FILE} ] || shf_logit "ERROR: can not find \"${FILE}\" to patch it with engine ID and type"

	putline() {
		local INSTR="$*"
		LOOKFOR="$(echo ${INSTR}|cut -d'"' -f 1)"
		LINE="$(sed -n "/${LOOKFOR}/=" ${FILE})"
		NLIN="$(sed -n "/${LOOKFOR}/=" ${FILE}|wc -l)"

		if [ ${NLIN} -eq 1 ]; then
			sed -i "${LINE}d" ${FILE}
			sed -i "${LINE}i ${INSTR}" ${FILE}
			shf_logit "changed line \"${LINE}\" in engine.conf to \"${INSTR}\""
		else
			shf_logit "ERROR: ambigious entries for engine.conf file stays unchanged"
		fi
	}
			
	case ${ENGINID[$X]} in
		"from eth0 IPv4")
			putline \(engine-id-type \"ipv4\"\)
			putline \(nic \"eth0\"\)
		;;
		"from etho mac")
			putline \(engine-id-type \"mac\"\)
			putline \(nic \"eth0\"\)
		;;
		"from engine.conf")
			putline \(engine-id-type \"text\"\)
			putline \(engine-id \"certifier\"\)
		;;
		*)
		shf_logit "ERROR: unexpected engineID \"${ENGINID[$X]}\" dont know what to do engine.conf stays unchanged"
		;;
	esac
fi
#------------------------------------------------------------------------------
edit_scmconf() {
	FILE=$1
	OLDLINE="$2"
	NEWLINE="$3"

	if [ ! -w "${FILE}" ]; then 
		shf_logit "ERROR: can not write or access \"${FILE}\" for edit"
		shf_logit "ERROR: no change \"${NEWLINE}\" done"
	fi

	CURENT=( $(grep "${OLDLINE}" ${FILE} |tr -d [:blank:]) )
	LOOKFORLINE="$(echo ${OLDLINE}|tr -d [:blank:])"
	if [ "${CURENT[0]}" = "${LOOKFORLINE}" ] && [ "${#CURENT[@]}" = "1" ]
	then
		LINE=$(grep -n "${OLDLINE}" ${FILE} | cut -d':' -f1)
		sed -i "${LINE} d" ${FILE}
		sed -i "${LINE} a ${NEWLINE}" ${FILE}
		shf_logit "\"${FILE}\" insert: \"${NEWLINE}\""
	else
		shf_logit "ERROR: can not insert \"${NEWLINE}\" into \"${FILE}\" due to ambigious matchpattern"
	fi
	}

case ${ROLE} in
	be2|SingleServer)
		edit_scmconf "${MYDIR}/conf/engine.conf" "(keep-alive 0)" "\ (keep-alive 60)"
#		edit_scmconf "${MYDIR}/conf/engine.conf" "(pid-directory \"./var/run\")" "\ (pid-directory \"/var/run\")"
	;;
	fe1|fe2|fe3|fe4)
		edit_scmconf "${MYDIR}/conf/server.conf.dist" "(keep-alive 0)" "\ (keep-alive 60)"
#		edit_scmconf "${MYDIR}/conf/server.conf" "(pid-directory \"./var/run\")" "(pid-directory \"/var/run\")"
	;;
esac		

shf_logit "#-----------------------------------------------------------------"
shf_logit "leaving script ${MYSELF}"
shf_logit "#-----------------------------------------------------------------"
