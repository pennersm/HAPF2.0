#!/bin/bash
###########################################################################
# NSN INSTA HAPF2.1 RAPID SETUP CONFIG GENERATOR SCRIPT
#--------------------------------------------------------------------------
# Script default name   : ~script/config_syslog.sh
# Configure version     : mkks62f.pl
# Media set             : PF21I52RH63-12
# File generated        : 03.01.2013 MPe
#
###########################################################################
export -p  MYSELF="config_syslog.sh"
#
shf_logit "#-----------------------------------------------------------------"
shf_logit "starting to run script ${MYSELF}"
shf_logit "#-----------------------------------------------------------------"
#
ROLE=$1 ; [ $# -ne 1 ] && exit 1
export -p SHELLOG=${INSTDIR}/${MYSELF}.${ROLE}.${NOW}.shell.log
shf_set_index
#
shf_logit "Using Role $ROLE in here, configure index $X"
shf_logit "${NOW} using ARGS: `echo $*`"
shf_logit "creating file to log command outputs: ${SHELLOG}"
#
cat /dev/null > ${SHELLOG}
echo "starting shellog for ${NOW} ${MYSELF} `date`" &>> ${SHELLOG}
set &>> ${SHELLOG}
echo "=======================================================================" &>> ${SHELLOG}
#
shf_logit "WARNING: developers shall mind that /etc/sysconfig/rsyslog is already handled in config_netsnmp - didnt touch it here"
#
#--------------------------------------------------------------------------
RSYSLDIR="/var/spool/rsyslog"
#--------------------------------------------------------------------------
FILE="/etc/rsyslog.conf"
SYSLOGINIT="/etc/init.d/rsyslog"

ENGINE_LOG="/var/log/engine.log" 
SERVER_LOG="/var/log/server.log" 
ENGINE_OLD="/usr/local/certifier/var/log/engine.log"
SERVER_OLD="/usr/local/certifier/var/log/server.log"

sed -i /local0.debug/d ${FILE} &>/dev/null
sed -i /local1.debug/d ${FILE} &>/dev/null
sed -i /Syslog/d ${FILE} &>/dev/null

mk_log() {
	local LOGFILE=$1
	[ -f ${LOGFILE} ] || touch "${LOGFILE}" 
	chown certfier:daemon ${LOGFILE}
	chmod 600 ${LOGFILE}
	shf_logit "created file for certifer debug \"${LOGFILE}\""
}

case ${ROLE} in 
	be1|be2)
		mk_log ${ENGINE_LOG}
		mk_log ${SERVER_LOG}

		if [ -d "$(dirname ${ENGINE_OLD})"  ]; then
			[ -f ${ENGINE_OLD} ] && mv ${ENGINE_OLD} ${ENGINE_LOG}
			[ -f ${SERVER_OLD} ] && mv ${SERVER_OLD} ${SERVER_LOG}
			ln -s ${ENGINE_LOG} ${ENGINE_OLD}
			ln -s ${SERVER_LOG} ${SERVER_OLD}
		fi	

		LOGLIN[0]="local0.debug                        -${ENGINE_LOG}"
		LOGLIN[1]="local1.debug                        -${SERVER_LOG}"
		;;
	fe1|fe2|fe3|fe4)
		mk_log mk_log ${SERVER_LOG}
		LOGLIN[0]=""
		LOGLIN[1]="local1.debug                        -${SERVER_LOG}"
		;;
	SingleServer)
		mk_log ${ENGINE_LOG}
		mk_log ${SERVER_LOG}
		LOGLIN[0]="local0.debug                        -${ENGINE_LOG}"
		LOGLIN[1]="local1.debug                        -${SERVER_LOG}"
		;;
esac
#--------------------------------------------------------------------------
#--------------------------------------------------------------------------
: ${SYSL_TSTAMP[$X]:="default"}

case ${SYSL_TSTAMP[$X]} in
	"traditional")
		TIMEFORM="\$ActionFileDefaultTemplate RSYSLOG_TraditionalFileFormat"
		shf_logit "will use regular timestamp format"
		;;
	"RFC3339")
		unset TIMEFORM
		shf_logit "will use high-precision timestamps according rfc3339"
		;;
	"default")
		TIMEFORM="\$ActionFileDefaultTemplate RSYSLOG_TraditionalFileFormat"
		shf_logit "changing rsyslog default from rfc3339 timestamps to regular format"
		;;
esac

#--------------------------------------------------------------------------
if [ "${REMOTE_SYSLOG[$X]}" = "yes" ]
then
	case ${SYSLOG_PROTO[$X]} in
		udp|UDP)
			SRVSTR="@${RSYSLOGIP[$X]}:${RSYSLOGPORT[$X]}"
		;;
		tcp|TCP)
			SRVSTR="@@${RSYSLOGIP[$X]}:${RSYSLOGPORT[$X]}"
		;;
		relp|RELP)
			SRVSTR=":omrelp:${RSYSLOGIP[$X]}:${RSYSLOGPORT[$X]}"
		;;
	esac
#
FWDRULE="\
\n\$WorkDirectory\t${RSYSLDIR}\n\
\$ActionQueueFileName\trsyslog_diskQ\n\
\$ActionQueueMaxDiskSpace\t1g\n\
\$ActionQueueSaveOnShutdown\ton\n\
\$ActionQueueType\tLinkedList\n\
\$ActionResumeRetryCount\t-1\n\
*.*\t${SRVSTR}\n" 
	
mkdir -p ${RSYSLDIR}
chown root:root ${RSYSLDIR}
chmod 766 ${RSYSLDIR}
shf_logit "created workdir for syslog \"$(ls -ld ${RSYSLDIR})\""

fi
#--------------------------------------------------------------------------

shf_tag_cffile ${FILE} "no-backup"
cat <<-EOSYSL >> ${FILE}
	# Syslog configuration for Insta Certifier main installation BEGIN
	${LOGLIN[0]}
	${LOGLIN[1]}
	# Syslog configuration for Insta Certifier main installation END
	\$ModLoad imuxsock.so    # provides support for local system logging (e.g. via logger command)
	\$ModLoad imklog.so      # provides kernel logging support (previously done by rklogd)
	${TIMEFORM}
	*.info;mail.none;authpriv.none;cron.none                /var/log/messages
	authpriv.*                                              /var/log/secure
	mail.*                                                  /var/log/maillog
	cron.*                                                  /var/log/cron
	*.emerg                                                 *
	local7.*                                                /var/log/boot.log
EOSYSL
#
printf "${FWDRULE}" >> ${FILE}
#
chown root:root ${FILE}
chmod 0644 ${FILE}
sed -i '/^$/d' ${FILE}
shf_logit "`cat ${FILE}|wc -l` lines as : `ls -la ${FILE}`"
shf_fshow ${FILE} &&
shf_logit "modified $(ls -l ${FILE}|tr --squeeze-repeats ' ') for HAPF2.1 compliance" 
#
rc="$( ${SYSLOGINIT} restart &>/dev/null)$?"
shf_logit "restarted syslogd with new config and got exit \"${rc}\""
#--------------------------------------------------------------------------
#--------------------------------------------------------------------------
shf_logit "#-----------------------------------------------------------------"
shf_logit "leaving script ${MYSELF}"
shf_logit "#-----------------------------------------------------------------"
