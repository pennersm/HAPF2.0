#!/bin/bash
###########################################################################
# NSN INSTA HAPF2.1 RAPID SETUP CONFIG GENERATOR SCRIPT
#--------------------------------------------------------------------------
# Script default name   : ~script/config_netsnmp.sh
# Configure version     : mkks62f.pl
# Media set             : PF21I52RH63-12
# File generated        : 03.01.2013 MPe
#
###########################################################################
export -p  MYSELF="config_netsnmp.sh"
#
shf_logit "#-----------------------------------------------------------------"
shf_logit "starting to run script ${MYSELF}"
shf_logit "#-----------------------------------------------------------------"
#
ROLE=$1           ;  if [ -z ${ROLE}    ] ; then exit ; fi

shf_set_index
shf_logit "Using Role $ROLE in here, configure index $X"
shf_logit "${NOW} using ARGS: `echo $*`"
shf_logit "creating file to log command outputs: ${SHELLOG}"

SNMPUSER=$2       ;  : ${SNMPUSER:="certifier"}
                     : ${SNMPV3PASSPHRASE[$X]:="certifier_passphrase"}
                     : ${SNMPV2COMMUNITY[$X]:="pki_v2community"}
                     : ${SYSLOC[$X]:="localhost-trapconverter"}
                     : ${SYSCON[$X]:="root@localhost"}
MON_CSUB_ON_FE="no"
REMTRPRT="162"
LOCTRPRT="162"
# Monitor Timers in seconds and Parameters for Platform Supervision 
PROCMT="60"     # process Monitoring Intervall
DSKMT="600"     # disk monitoring intervall
LNKMT="60"      # interface/link monitoring intervall
DSKFULL="30%"   # on less diskspace free send trap
export -p SNMPUSER ; shf_logit "exported ${SNMPUSER} as SNMP USM user for later HAPF2.1 scripts"
export -p SHELLOG=${INSTDIR}/${MYSELF}.${ROLE}.${NOW}.shell.log

cat /dev/null > ${SHELLOG}
echo "starting shellog for ${NOW} ${MYSELF} `date`" &>> ${SHELLOG}
set &>> ${SHELLOG}
echo "=======================================================================" &>> ${SHELLOG}
#
##############################################################################
FILE="/etc/sysconfig/snmpd"
shf_tag_cffile ${FILE} "no-backup"

	cat <<-EODPARM >> ${FILE}
		OPTIONS="-LS0-4d -Lf /dev/null -p /var/run/snmpd.pid"
	EODPARM

	chown root:root ${FILE}
	chmod 0644 ${FILE}
	shf_logit "`cat ${FILE}|wc -l` lines as : \"`ls -la ${FILE}`\""
	shf_fshow ${FILE}
#
##############################################################################
#
FILE="/etc/snmp/snmp.conf"
shf_tag_cffile ${FILE} "no-backup"

	cat <<-EOSNMP >> ${FILE}
		mibs +ALL
	EOSNMP
	chown root:root ${FILE}
	chmod 0600 ${FILE}
	shf_logit "`cat ${FILE}|wc -l` lines as : \"`ls -la ${FILE}`\""
	shf_fshow ${FILE}
#
#-----------------------------------------------------------------------------
#-----------------------------------------------------------------------------
MYENGID="certifier"
case ${ENGINID[$X]} in
        "from engine.conf")
                shf_logit "Will use default engine ID \"certifier\" for now (rpm anyway not installed yet)"
                MYENGID="certifier"
                ;;
        "from eth0 IPv4")
                shf_logit "Will build  engine ID based on eth0 IPv4 address"
                MYENGID="engineIDType 1"
                ;;
        "from eth0 MAC")
                shf_logit "Will build  engine ID based on eth0 MAC address"
                MYENGID="engineIDType 2"
                ;;
	*)
		shf_logit "Will use default engine ID \"certifier\" for now (rpm anyway not installed yet)"
		MYENGID="certifier"
		;;			
esac
#-----------------------------------------------------------------------------
if [ ! -z "${SNMPTRAPRCVIP[$X]}" ] 
then
	CFV2LIN[0]="trap2sink    ${SNMPTRAPRCVIP[$X]}   ${SNMPV2COMMUNITY[$X]} ${REMTRPRT}"
	shf_logit "will configure SNMPv2c trap destination  ${SNMPTRAPRCVIP[$X]} for community ${SNMPV2COMMUNITY[$X]}"
fi
#-----------------------------------------------------------------------------
if [ ! -z "${SNMPINFORMRCVIP[$X]}" ]
then
	CFV2LIN[1]="informsink   ${SNMPINFORMRCVIP[$X]} ${SNMPV2COMMUNITY[$X]} ${REMTRPRT}"
	shf_logit "will configure SNMPv2c informs to ${SNMPINFORMRCVIP[$X]} for community ${SNMPV2COMMUNITY[$X]}"
fi	
#-----------------------------------------------------------------------------
if [ "${MONITOR_LDAP[$X]}" = "yes" ]; then idx=6; else idx=5; fi
#---
if [ "${ROLE:0:2}" = "be" ]; then cRole="certifier"; fi
if [ "${ROLE:0:2}" = "fe" ]; then cRole="certifsub"; fi
if [ "${ROLE:0:2}" = "SingleServer" ]; then cRole="certifier"; fi
#---
LDAPMON[1]="proc slapd"
LDAPMON[2]="procfix slapd /usr/sbin/wrap_procfix /etc/init.d/slapd"
LDAPMON[3]="monitor -r ${PROCMT} -e ldapDead    -i -o prNames.${idx} -o prErrMessage.${idx} "ldapProcCheck"    prErrorFlag.${idx} != 0"
LDAPMON[4]="setEvent ldapDead     prErrFix.${idx} = 1"
LDAPMON[5]="notificationEvent ldapDead    mteTriggerFired"
LDAPMON[6]="#"
#---
let idx=$idx+1
FEMON[1]="proc ssh-ca-server"
FEMON[2]="procfix ssh-ca-server /usr/sbin/wrap_procfix /etc/init.d/${cRole} /var/run/ssh-ca-server.pid"
FEMON[3]="monitor -r ${PROCMT} -e certServDead   -i -o prNames.${idx} -o prErrMessage.${idx} \"certServCheck\"    prErrorFlag.${idx} != 0"
FEMON[4]="setEvent certServDead prErrFix.${idx} = 1"
FEMON[5]="notificationEvent certServDead mteTriggerFired"
FEMON[6]="#"
#---
let idx=$idx+1
BEMON[1]="proc ssh-ca-engine"
BEMON[2]="procfix ssh-ca-engine /usr/sbin/wrap_procfix /etc/init.d/${cRole} /var/run/ssh-ca-engine.pid"
BEMON[3]="monitor -r ${PROCMT} -e certEngDead   -i -o prNames.${idx} -o prErrMessage.${idx} \"certEngCheck\"    prErrorFlag.${idx} != 0"
BEMON[4]="setEvent certEngDead prErrFix.${idx} = 1"
BEMON[5]="notificationEvent certEngDead mteTriggerFired"
BEMON[6]="#"
#---
let idx=$idx+1
HSMMON[1]="proc hardserver"
HSMMON[2]="procfix hardserver /usr/sbin/wrap_procfix /etc/init.d/nc_hardserver"
HSMMON[3]="monitor -r ${PROCMT} -e hsmHardsDead   -i -o prNames.${idx} -o prErrMessage.${idx} \"hsmHardsCheck\"    prErrorFlag.${idx} != 0"
HSMMON[4]="setEvent hsmHardsDead prErrFix.${idx} = 1"
HSMMON[5]="notificationEvent hsmHardsDead mteTriggerFired"
HSMMON[6]="#"
#---
REM="#"
#---
#---
if [[ "${ROLE}" == "be"[1,2] ]] 
then
	unset LDAPMON FEMON BEMON HSMMON
fi
if [[ "${ROLE}" == "fe"[1-4] ]]
then
	unset BEMON HSMMON
	if [ "${MONITOR_LDAP[$X]}" = "no" ]; then
		unset LDAPMON
	fi
	if [ "${MON_CSUB_ON_FE}" = "no" ]; then
		unset FEMON
	fi
fi
if [ "${ROLE}" = "SingleServer" ]
then
	if [ "${MONITOR_LDAP[$X]}" = "no" ]; then
		unset LDAPMON
	fi
	if [ "${USE_HSM[$X]}" = "no" ]; then
		unset HSMMON
	fi
fi
#-----------------------------------------------------------------------------
#-----------------------------------------------------------------------------
if [ "${SNMPV3CONV[$X]}" = "yes" ]
then

	FILE="/etc/snmp/snmptrapd.conf"
	shf_tag_cffile ${FILE} "no-backup"
	
	cat <<-ETRAPD >> ${FILE}
	
	# We recommend you to remove the lines containing createUser directives
	# Those are only needed for clean initialisation and can be removed later
	# USM info is stored persistant and encrypted in /var/lib/net-snmp/

	snmpTrapdAddr 127.0.0.1:${LOCTRPRT}
	createUser -e "INSERT-CERTIFIER-ENGINE-ID-HERE" ${SNMPUSER} SHA ${SNMPV3PASSPHRASE[$X]}
	authUser log,execute,net certifier
	pidFile /var/run/snmptrapd.pid
	traphandle default /etc/snmp/hapf21handler.sh
	
	ETRAPD
	chown root:root ${FILE}
	chmod 644  ${FILE}
	shf_logit "prepared trap receiver config for local snmp conversion loop  \"$(ls -l ${FILE})\""	
	shf_logit "WARNING: you must later add the certifier application engine ID to the createUser directive"

	FILE="/etc/snmp/hapf21handler.sh"
	cat  <<-TRAPHDL > ${FILE}
	#!/bin/bash
	###########################################################################
	# NSN INSTA HAPF2.1 SCRIPT
	#--------------------------------------------------------------------------
	# Script default name   : hapf21handler.sh
	# Configure version     : mkks62e.pl
	# Media set             : PF21I51RH63-12
	# File generated        : 19.06.2013 MPe
	#
	###########################################################################
	TRAPRECEIVER="${SNMPTRAPRCVIP[$X]}:${REMTRPRT}"
	V2TRAPCOMMUNITY="-c ${SNMPV2COMMUNITY[$X]}"
	SNMPVERSION="-v 2c"
	LOGPRIO="daemon.error"
	CONVNAME="[trapconverter]"
	############################################################################
	read host
	read ip
	i=0;k=0
	vars=
	while read TRP
	do
	        let i=\$i+1
	        BIND[\$i]=\${TRP}
	done
	############################################################################
	if [ "\${BIND[1]:0:35}" = "DISMAN-EVENT-MIB::sysUpTimeInstance" ]
	then
	        TIMETICKS=\$(echo \${BIND[1]}|cut -d' ' -f2)
	else
	        logger -p \${LOGPRIO} -t \${CONVNAME} "can not decode sysUpTimeInstance in snmpv3 trap - no conversion"
	fi
	if [ "\${BIND[2]:0:25}" = "SNMPv2-MIB::snmpTrapOID.0" ]
	then
	        TRAPOID=\$(echo \${BIND[2]}|cut -d' ' -f2)
	else
	        logger -p \${LOGPRIO} -t \${CONVNAME} "can not decode snmpTrapOID in snmpv3 trap - no conversion"
	fi
	############################################################################
	VARBINDS="";
	for k in \$(seq 3 \${i})
	do
	        VBIND=( \$(echo \${BIND[\$k]}) )
	        if [ "\${VBIND[0]:0:19}" = "INSTA-PKIMGMT-MIB::" ]
	        then
	                OID="\${VBIND[0]}" ; unset VBIND[0]
	                VAL="\$( echo \${VBIND[@]}|tr [:blank:] _ )"
	        else
	                logger -p ${LOGPRIO} -t ${CONVNAME} "can not decode varbind in v3 trap"
	        fi
	        VARBINDS="\${VARBINDS} \${OID} = \${VAL}"
	done
	############################################################################
	snmptrap \${SNMPVERSION} \${V2TRAPCOMMUNITY} \${TRAPRECEIVER} \${TIMETICKS} \${TRAPOID} \${VARBINDS}
	TRAPHDL
	chown root:root ${FILE}
	chmod 755 ${FILE}
	shf_logit "prepared trap handler for local snmp conversion loop  \"$(ls -l ${FILE})\""
	shf_logit "will fire converted insta traps to ${SNMPTRAPRCVIP[$X]}:${REMTRPRT} community ${SNMPV2COMMUNITY[$X]}"
fi
#-----------------------------------------------------------------------------
FILE="/etc/snmp/snmpd.conf"
shf_tag_cffile ${FILE} "no-backup"

        cat <<-ESNMPD >> ${FILE}
		# We recommend you to remove the lines containing createUser directives
		# Those are only needed for clean initialisation and can be removed later
		# USM info is stored persistant and encrypted in /var/lib/net-snmp/
		engineID ${MYENGID}
		#########################################################################
		agentaddress ${IPADDReth0[X]}
		leave_pidfile no
		syslocation ${SYSLOC[$X]}
		sysContact ${SYSCON[$X]}
		#
		maxGetbulkRepeats 64
		maxGetbulkResponses 64
		#########################################################################
		rocommunity ${SNMPV2COMMUNITY[$X]}
		#########################################################################
		createUser pkisuper  SHA pkisuper_passphrase AES pkisuper_passphrase
		createUser ${SNMPUSER} SHA ${SNMPV3PASSPHRASE[$X]} DES
		rwuser internal
		#
		###########################################################################
		com2sec pkisuper default ${SNMPV2COMMUNITY[$X]}
		group redhat usm pkisuper
		group pki    usm ${SNMPUSER}
		#
		view all         included .iso.org.dod.internet
		view mib2        included .iso.org.dod.internet.mgmt.mib-2
		view mib2        included .iso.org.dod.internet.private.enterprises
		view insta       included .iso.org.dod.internet.private.enterprises.insta
		#
		access redhat     "" usm priv exact mib2  none mib2
		access pki        "" usm auth exact insta none insta
		#
		#########################################################################
		# Host Resources MIB
		#
		proc crond
		procfix crond /usr/sbin/wrap_procfix /etc/init.d/crond 
		#	
		proc auditd
		procfix auditd /usr/sbin/wrap_procfix /etc/init.d/auditd 
		#
		proc rsyslogd
		procfix rsyslogd /usr/sbin/wrap_procfix /etc/init.d/rsyslog
		#
		proc sshd
		procfix sshd /usr/sbin/wrap_procfix /etc/init.d/sshd 
		#
		proc ntpd
		procfix ntpd /usr/sbin/wrap_procfix /etc/init.d/ntpd 
		#
		${LDAPMON[1]}
		${LDAPMON[2]}
		${LDAPMON[6]}
		${FEMON[1]}
		${FEMON[2]}
		${FEMON[6]}
		${BEMON[1]}
		${BEMON[2]}
		${BEMON[6]}
		${HSMMON[1]}
		${HSMMON[2]}
		${HSMMON[6]}
		#
		disk / ${DSKFULL}
		disk /backup ${DSKFULL}
		disk /usr/local/certifier ${DSKFULL}
		#
		########################################################################
		trapcommunity ${SNMPV2COMMUNITY[$X]}
		${CFV2LIN[0]}
		${CFV2LIN[1]}
		#
		agentSecName internal
		#
		#FIRES:
		# always trap 1.3.6.1.2.88.2.0.1 (MTE trigger) with below -o additional varbinds:
		# 1.3.6.1.4.1.2021.2.1.2.X is procname & 1.3.6.1.4.1.2021.2.1.101.X is text in prErrMessage X=1..6 
		monitor -r ${PROCMT} -e cronDead     -i -o prNames.1 -o prErrMessage.1 "cronProcCheck"    prErrorFlag.1 != 0
		monitor -r ${PROCMT} -e auditDead    -i -o prNames.2 -o prErrMessage.2 "auditProcCheck"   prErrorFlag.2 != 0
		monitor -r ${PROCMT} -e syslogDead   -i -o prNames.3 -o prErrMessage.3 "syslogProcCheck"  prErrorFlag.3 != 0
		monitor -r ${PROCMT} -e sshDead      -i -o prNames.4 -o prErrMessage.4 "sshProcCheck"     prErrorFlag.4 != 0
		monitor -r ${PROCMT} -e ntpDead      -i -o prNames.5 -o prErrMessage.5 "ntpProcCheck"     prErrorFlag.5 != 0
		${LDAPMON[3]}
		${FEMON[3]}
		${BEMON[3]}
		${HSMMON[3]}
		#
		setEvent cronDead     prErrFix.1 = 1
		setEvent auditDead    prErrFix.2 = 1
		setEvent syslogDead   prErrFix.3 = 1
		setEvent sshDead      prErrFix.4 = 1
		setEvent ntpDead      prErrFix.5 = 1
		${LDAPMON[4]}
		${FEMON[4]}
		${BEMON[4]}
		${HSMMON[4]}
		#
		notificationEvent cronDead     mteTriggerFired
		notificationEvent auditDead    mteTriggerFired
		notificationEvent syslogDead   mteTriggerFired
		notificationEvent sshDead      mteTriggerFired
		notificationEvent ntpDead      mteTriggerFired
		${LDAPMON[5]}
		${FEMON[5]}
		${BEMON[5]}
		${HSMMON[5]}
		#
		monitor -r ${DSKMT} -e fsFull  -o dskPath -o dskErrorMsg "fsCheck" dskErrorFlag != 0
		monitor -r ${DSKMT} -e fsClear -o dskPath                "fsClear" dskErrorFlag == 0
		notificationEvent fsFull mteTriggerFired
		notificationEvent fsClear mteTriggerFired
		#
		monitor -s -r ${LNKMT} -e linkUpTrap   "Generate linkUp"   ifOperStatus != 2
		monitor -s -r ${LNKMT} -e linkDownTrap "Generate linkDown" ifOperStatus == 2
		notificationEvent  linkUpTrap    linkUp   ifIndex ifDescr ifAdminStatus ifOperStatus
		notificationEvent  linkDownTrap  linkDown ifIndex ifDescr ifAdminStatus ifOperStatus
		#       
		#########################################################################
	ESNMPD
	chown root:root ${FILE}
	chmod 0644 ${FILE}
	sed -i '/^$/d' ${FILE}
	shf_logit "`cat ${FILE}|wc -l` lines as : `ls -la ${FILE}`"
	shf_fshow ${FILE}
	shf_logit "WARNING: ${FILE} contains default account info that needs manual changing after setup"
#
#-----------------------------------------------------------------------------
FILE="${INSTDIR}/script/watch_snmpd.sh"

if [ ! -r ${FILE} ]
then
        shf_logit "can not find ${FILE}  - platform supervision will be incomplete unless you fix this manually"
else
        cp -f ${FILE} /usr/sbin/watch_snmpd
        chmod 500 ${FILE}
        chown root:root ${FILE}
        shf_logit "copied platform file into place \"`ls -l ${FILE}`\""
fi
#-----------------------------------------------------------------------------
FILE="/etc/init.d/snmpd"
FLAG="/var/run/snmpd-cleanstoped"
	cp -p ${FILE} ${BACKDIR}/$(basename ${FILE}).${ROLE}.${NOW}
	sed -e "/^ *stop)/ a \\        touch ${FLAG}" ${FILE} > ${FILE}.tmp && sync
	sed -e "/^ *start)/ a \\        rm -f ${FLAG} &>/dev/null" ${FILE}.tmp > ${FILE} && sync
	rm -f ${FILE}.tmp &>/dev/null
	shf_logit "patched init script near \"stop)\" call: \"`grep "touch ${FLAG}" ${FILE}|tr "\n" " "|tr --squeeze-repeats ' '`\"" 
	shf_logit "patched init script near \"start)\" call: \"`grep "rm -f ${FLAG}" ${FILE}|tr "\n" " "|tr --squeeze-repeats ' '`\""
	
#-----------------------------------------------------------------------------
FILE="${INSTDIR}/script/wrap_procfix.sh"

if [ ! -r ${FILE} ]
then
	shf_logit "can not find ${FILE}  - platform supervision will be incomplete unless you fix this manually"
else
	cp -f ${FILE} /usr/sbin/wrap_procfix
	chmod 500 ${FILE}
	chown root:root ${FILE}
	shf_logit "copied platform file into place \"`ls -l ${FILE}`\""
fi
#-----------------------------------------------------------------------------
FILE="/etc/sysconfig/rsyslog"
INITSCR="/etc/init.d/rsyslog"
NEWPIDF="/var/run/rsyslogd.pid"
DEFPIDF="/var/run/syslogd.pid"
if [ -w ${FILE} ] 
then
	${INITSCR} stop &>/dev/null &&
	shf_tag_cffile ${FILE} "no-backup"
	cat <<-KSYSLG >> ${FILE}
		SYSLOGD_OPTIONS="-c 4 -Q -x"
		PIDFILE="${NEWPIDF}"
	KSYSLG
	shf_logit "changed syslog parameters in \"`ls -la ${FILE}`\" added \"`grep PIDFILE= ${FILE}`\""
	DEFPIDFILE=$(grep  "PIDFILE=" ${INITSCR}|grep -v "^[[:blank:]]*#"|awk -F= '($1=="PIDFILE"){print$2}')
	rm -f ${DEFPIDFILE} &>/dev/null
	ln -s ${NEWPIDF} ${DEFPIDF}
	sed -i 's/syslogd.pid/rsyslog.pid/' /etc/logrotate.d/syslog
	shf_logit "changed logrotate configuration to look for new syslog PID file"
	SYSLHUP=$( ${INITSCR} restart &>/dev/null)$?
	sleep 2
	shf_logit "restart of syslog brought exit \"${SYSLHUP}\" now running PID \"`cat ${NEWPIDF}`\""

else
	shf_logit "can not change syslog startup options in \"`ls -la ${FILE}`\""
fi
chown root:root ${FILE}
chmod 0644 ${FILE}

shf_logit "#-----------------------------------------------------------------"
shf_logit "leaving script ${MYSELF}"
shf_logit "#-----------------------------------------------------------------"
