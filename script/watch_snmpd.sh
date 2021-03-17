#!/bin/bash
###########################################################################
# NSN INSTA HAPF2.1 SCRIPT
#--------------------------------------------------------------------------
# Script default name   : ~script/watch_snmpd.sh
# Configure version     : mkks61f.pl
# Media set             : PF21I51RH63-12
# File generated        : 03.01.2013 MPe
#
###########################################################################
export -p  MYSELF="watch_snmpd.sh"
DAEMON="/usr/sbin/snmpd"
PIDFILE="/var/run/snmpd.pid"
FOUNDPID=$(cat ${PIDFILE} 2>/dev/null) 
CLEANFLAG="/var/run/snmpd-cleanstoped"
TAG=$MYSELF

logger -p user.debug -t ${TAG} "looking for ${DAEMON} with PID ${FOUNDPID}"
CHECKSTRING=$(ps --no-headers -ef|awk -v PROG="${DAEMON}" '($8==PROG){print$2":"$8}')
logger -p user.debug -t ${TAG} "found \"${CHECKSTRING}\" in pslist"
rc="1"

if ([ -z "${CHECKSTRING}" ] && [ -r ${PIDFILE} ])
then
        logger -p user.info -t ${TAG} "$DAEMON has pidfile but seems to be down - will restart it"
        /etc/init.d/snmpd restart
        rc=$?

elif ( [[ `ps --no-headers -fC snmpd| awk '{print$2}'|sed 's/^[0-9]*//' | wc -l` -eq 1 ]] && [ "${CHECKSTRING}" != "${FOUNDPID}:${DAEMON}" ] )
then
        logger -p user.info -t ${TAG} "${DAEMON} seems running but PID file does not match - will overwrite PID file"
        echo "$(ps --no-headers -fC snmpd|awk '{print$2}')" > ${PIDFILE}
        rc="4"

elif [ -z "${CHECKSTRING}" ]
then
	if [ -f ${CLEANFLAG} ]
	then
		logger -p user.info -t ${TAG} "${DAEMON} seems cleanly stopped - flag set"
		rc=0;
	else
		logger -p user.info -t ${TAG} "${DAEMON} stopped but no flag - restarting it!"
        	/etc/init.d/snmpd restart &>/dev/null
        	rc=$?
	fi
elif [ "${CHECKSTRING}" = "${FOUNDPID}:${DAEMON}" ]
then
       logger -p user.debug -t ${TAG} "${DAEMON} seems up fine and PID file OK"
       rc="0"
		
fi
exit $rc
