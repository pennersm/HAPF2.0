#!/bin/bash
###########################################################################
# NSN INSTA HAPF2.1 RAPID SETUP CONFIG GENERATOR SCRIPT
#--------------------------------------------------------------------------
# Script default name   : ~script/config_ntpclnt.sh
# Configure version     : mkks62f.pl
# Media set             : PF21I52RH63-12
# File generated        : 03.01.2013 MPe
#
###########################################################################
export -p  MYSELF="config_ntpclnt.sh"
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
FILE="/etc/ntp.conf"
shf_logit "preparing ${FILE} for ${ROLE}"
shf_tag_cffile "${FILE}" "no-backup"

[ ! -z ${NTPSERVER1[$X]} ] && NTPSLIN1="server ${NTPSERVER1[$X]} preempt" || NTPSLIN1=""
[ ! -z ${NTPSERVER2[$X]} ] && NTPSLIN2="server ${NTPSERVER2[$X]} preempt" || NTPSLIN2=""
[ ! -z ${NTPSERVER3[$X]} ] && NTPSLIN3="server ${NTPSERVER3[$X]} preempt" || NTPSLIN3=""
[ ! -z ${NTPSERVER4[$X]} ] && NTPSLIN4="restrict ${NTPSERVER1[$X]}"       || NTPSLIN4=""
[ ! -z ${NTPSERVER5[$X]} ] && NTPSLIN5="restrict ${NTPSERVER2[$X]}"       || NTPSLIN5=""
[ ! -z ${NTPSERVER6[$X]} ] && NTPSLIN6="restrict ${NTPSERVER3[$X]}"       || NTPSLIN6=""

	cat <<-EONTP >>${FILE}
		driftfile /var/lib/ntp/drift
		restrict default nopeer
		restrict 127.0.0.1
		restrict ${IPADDReth0[$X]} mask ${NETMASKeth0[$X]} nomodify notrap

		server 127.127.1.0 
		fudge  127.127.1.0 stratum 10
		
		# uncomment the following lines to enable ntp security
		# ntp with asymmetric keys: 
		#crypto
		#includefile /etc/ntp/crypto/pw
		#
		# ntp with symmetric keys
		#keys /etc/ntp/keys
		#trustedkey 4 8 42
		#requestkey 8
		#controlkey 8
		
		#statistics clockstats cryptostats loopstats peerstats			

		${NTPSLIN1}
		${NTPSLIN2}
		${NTPSLIN3}
		${NTPSLIN4}
		${NTPSLIN5}
		${NTPSLIN6}
	EONTP
chmod 644 ${FILE}
chown root:root ${FILE}
shf_logit "configured ntp servers: `grep server ${FILE}|awk '($1=="server"){print$2}'|tr "\n" " "`"
#-----------------------------------------------------------------------------
FILE="/etc/step-tickers" 
shf_tag_cffile ${FILE} "no-backup"
[ ! -z ${NTPSERVER1[$X]} ] && echo ${NTPSERVER1[$X]} >> ${FILE}
[ ! -z ${NTPSERVER2[$X]} ] && echo ${NTPSERVER2[$X]} >> ${FILE}
[ ! -z ${NTPSERVER3[$X]} ] && echo ${NTPSERVER3[$X]} >> ${FILE}
sync
chmod 0600 ${FILE}
chown root:root ${FILE}
shf_logit "added step-tickers ntpdate should adjust your clock at next restart of ntpd"
#-----------------------------------------------------------------------------
FILE="/etc/sysconfig/clock"
shf_tag_cffile ${FILE} "no-backup"
	cat <<-EOCLOCK >>${FILE}
		ZONE="${TIMEZONE[$X]}"
		UTC="true"
		ARC="false"
	EOCLOCK
shf_logit "configured time to UTC in \"$(ls -l ${FILE}|tr --squeeze-repeats ' ')\""
shf_logit "setting system HW clock \"$(hwclock --utc)\""
if [ -f "/usr/share/zoneinfo/${TIMEZONE[$X]}" ]; then
	ln -sf /usr/share/zoneinfo/${TIMEZONE[$X]} /etc/localtime 
	sync && shf_logit "linked zonefile: \"$(ls -l /etc/localtime|cut -d' ' -f 9-11)\"" 
else
	shf_logit "ERROR: can not find zonefile \"/usr/share/zoneinfo/${TIMEZONE[$X]}\""
fi
#-----------------------------------------------------------------------------
shf_logit "#-----------------------------------------------------------------"
shf_logit "leaving script ${MYSELF}"
shf_logit "#-----------------------------------------------------------------"
