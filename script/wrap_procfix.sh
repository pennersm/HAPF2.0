#!/bin/bash
###########################################################################
# NSN INSTA HAPF2.1 SCRIPT
#--------------------------------------------------------------------------
# Script default name   : ~script/wrap_procfix.sh
# Configure version     : mkks61f.pl
# Media set             : PF21I51RH63-12
# File generated        : 03.01.2013 MPe
#
###########################################################################
export -p  MYSELF="wrap_procfix.sh"
TAG=$MYSELF

INITSCR=$1
rc=1

 [ $# -lt 1 ] && logger -p user.err -t ${TAG}  "incorrect number of arguments - exiting" && exit $rc 
 [ ! -x ${INITSCR} ] && logger -p user.err -t ${TAG}  "no executable rc-init script to wrap - exiting" && exit $rc


SNMPCONF="/etc/snmp/snmpd.conf"
PROCFIX="$(grep procfix ${SNMPCONF}|grep -v "^[[:blank:]]*#"|awk -v INITNAM="${INITSCR}" '($4==INITNAM){print$2}')"
PIDFILE="$(grep procfix ${SNMPCONF}|grep -v "^[[:blank:]]*#"|awk -v INITNAM="${INITSCR}" '($4==INITNAM){print$5}')"

# we really trust that the init-script basename is the complete name of the daemon
# we also do not allow more than one instance of each process, meaning, ntpd can die to the last before we act
# those constraints are action points for HAPF2.5
PROC=$(basename ${PROCFIX})
PROCPID=$(ps --no-headers -fC ${PROC}|awk -v PRNAM="${PROCFIX}" '(($3=="1") && ($8=PRNAM)){print$2}')
if [ $(ps --no-headers -fC ${PROC}|awk -v PRNAM="${PROCFIX}" '(($3=="1") && ($8=PRNAM)){print$2}'|wc -l) -ge 2 ]
then
	logger -p user.err ${TAG} "process ${PROC} status unclear because more than 1 instance running - dont know what to do"
	exit 1
fi
logger -p user.debug -t ${TAG} "supervising \"${PROCFIX}\" under PID \"${PROCPID}\""

: ${PIDFILE:="/var/run/${PROC}.pid"}
FILEPID=$(cat ${PIDFILE} 2>/dev/null )
logger -p user.debug -t ${TAG} "trying \"${PIDFILE}\" with PID \"`cat ${PIDFILE} 2>/dev/null`\""
echo "$PROCPID - $PROCFIX - $FILEPID"
	if [ -z "`echo ${PROCPID} | tr -d '[0-9]'`" ] && [ ! -z "${PROCPID}" ]
	then
		if [ "${FILEPID}" = "${PROCPID}" ]
		then
			logger -p user.debug -t ${TAG} "verified running \"${PROCFIX}\" under PID \"${PROCPID}\""	
			rc=0
		else
			${INITSCR} stop &>/dev/null
			sleep 2
			kill `pidof ${PROC}` &>/dev/null
			rc=$( ${INITSCR} start &>/dev/null)$?
			logger -p user.warn ${TAG} "PID mismatch \"${PROC}\" - restarted and got exit \"${rc}\" from rc-init" 
			logger -p user.debug ${TAG} "new pidfile \"${PIDFILE}\" for PID \"$(cat ${PIDFILE} 2>/dev/null)\""
		fi

	elif ( [  -z "${FILEPID}" ] && [ -z "${PROCPID}" ] )
	then
		INITSTAT=$( ${INITSCR} status |tr --squeeze-repeats '  '| tr "\n" " "|awk '{print$2$3}'  )
		if [ "${INITSTAT}" != "isstopped" ]
		then
			INITSTAT=$( ${INITSCR} status |tr --squeeze-repeats '  '| tr "\n" " ")
			logger -p user.warn ${TAG} "odd status of ${PROC} reported: \"${INITSTAT}\"
			rc=$( ${INITSCR} restart &>/dev/null)$?
			logger -p user.warn ${TAG} "restarted ${PROC} and got exit \"${rc}\" from rc-init"
		else
			logger -p user.warn ${TAG} "process ${PROC} seems to be halted clean - no action taken"
			logger -p user.debug ${TAG} "checking rc-init status of ${PROC} as \"${INITSTAT}\""
			rc=3	
		fi
	elif [ -z "${PROCPID}" ] && [ ! -z "{$FILEPID}" ]
	then
		rc=$( ${INITSCR} restart &>/dev/null)$?
		logger -p user.warn ${TAG} "PID is dead \"${PROC}\" - restarted and got exit \"${rc}\" from rc-init"
		logger -p user.debug ${TAG} "new pidfile \"${PIDFILE}\" for PID \"$(cat ${PIDFILE} 2>/dev/null)\""
	else
		logger -p user.err ${TAG} "process ${PROC} status totaly unclear - dont know what to do"
		rc=1
	fi
exit $rc
