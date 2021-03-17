#!/bin/bash
###########################################################################
# NSN INSTA HAPF2.0 RAPID SETUP CONFIG GENERATOR SCRIPT
#--------------------------------------------------------------------------
# Script default name   : /etc/rc.d/rc.local
# Configure version     : mkks62e.pl
# Media set             : PF21I52RH63-12
# File generated        : 03.01.2013 MPe
#
###########################################################################
#
 : ${MAINFLAG:="/etc/hapf21.flag"}
#
###########################################################################
   RESMSG="Phase 2 : HAPF2.1 RAPID SETUP RESUME"
###########################################################################
trouble() {
	echo "We are in trouble :"
	cat <<-EXPLAIN 
		A file $MAINFLAG had been expected but not found. The file must be 
		created during the first phase of NSN INSTA HAPF2.1 RAPID SETUP. 

		This file runs scripts of the second phase after anaconda reboot.
		Either the file or one of the scripts it shall run can not be found now!
		Without information contained in this file, installation can not continue.
		
		If you are able to restore the file from somewhere, 
		1)   do so and restore the file
		2)   reboot this server
		3)   All OK when you see a message "${RESMSG}"			 


EXPLAIN
read
}
usbcheck() {
	MYCARIER="$(shf_usbdsk)" &&
	MYMPOINT="$(cat /proc/mounts|awk -v P="${MYCARIER}" '($1==P){print$2}')"
	: ${MTDIR:="/media"}
	local rc=1

	if [ -z "${MYCARIER}" ]
	then
	printf "\n\n\n"
                shf_logit "ERROR: No USB-drive Install media found inserted on this server"
                shf_logit "ERROR: Installation can not succeed like that, you must insert the USB"
                shf_logit "ERROR: Escaping to debug-shell now. If you know what you're doing then:"
                shf_logit "       - insert the USB install media, mount it and enter shf_cont"
                shf_logit "       - you must use the same media as before in the HA peer in local install"
                shf_logit "       - to not carry along the drive from peer chose REMOTE_INSTALL=yes"
                shf_debug_break
        fi

	if [ -z "${MYMPOINT}" ]
	then
		rc="$(mount -o rw ${MYCARIER} ${MTDIR} &>/dev/null)$?"
		sleep 1 ; sync
		MYMPOINT="$(cat /proc/mounts|awk -v P="${MYCARIER}" '($1==P){print$2}')"
		shf_logit "detect and mount USB device \"${MYCARIER}\" to \"${MYMPOINT}\" with exit status \"${rc}\""
	else
		shf_logit "using existing USB device \"${MYCARIER}\" mounted on \"${MYMPOINT}\""
		rc=0
	fi
	return $rc
}
#############################################################################
chvt 3
exec </dev/tty3 >/dev/tty3

if [ -r ${MAINFLAG} ]
then 
	source ${MAINFLAG}
else
	trouble
fi
#----------------------------------------------------------------------------
for PHASE1 in ${RUN[@]}
do
	if [ -f $PHASE1 ]
 	then
 		source $PHASE1
 	else
 		trouble
 	fi
done
usbcheck
#
#############################################################################
export -p  MYSELF="phase2.sh"
ROLE=$GENROLE
export -p SHELLOG=${INSTDIR}/${MYSELF}.${ROLE}.${NOW}.shell.log
shf_set_index

if [ ${STARTP2} = "YES" ]
then
shf_logit "##################################################################"
shf_logit "${RESMSG}"
shf_logit "Resume Time   : `date`"
shf_logit "Continuing with installation $NOW"
shf_logit "Phase 1 was ended            $END"
shf_logit "Using Logfile : $LOGFILE"
shf_logit "Inherited $GENROLE at $GENHOST from $INSTDIR"
shf_logit "#-----------------------------------------------------------------"
#
shf_logit "#-----------------------------------------------------------------"
shf_logit "starting to run script ${MYSELF} "
shf_logit "#-----------------------------------------------------------------"
#
shf_logit "Using Role $ROLE in here, configure index $X"
shf_logit "starting to call scripts - see my exit message at the very end"
###########################################################################
#
USBDRV=$( shf_usbdsk )
if [ -z "${USBDRV}" ]; then
	shf_logit "no USB media found to mount - can not do any Phase 2 without USB stick... "
	exit
else
	shf_logit "found USB Install media at \"${USBDRV}\""
	mount -o rw ${USBDRV} ${MTDIR}  ;  shf_fshow df |grep ${MTDIR}                            
	cd ${INSTDIR}/script   ; shf_fshow pwd
	sleep 2
fi

[[ "${ROLE}" == "be"[1,2] ]] && DRBDRES="certifier"
[[ "${ROLE}" == "fe"[1,2,3,4] ]] && DRBDRES="certifsub"
shf_logit "starting to build a config of type \"${DRBDRES}\""
export -p DRBDRES

if [ ${ROLE} != "SingleServer" ] 
then
	. ${INSTDIR}/script/config_openssh.sh $ROLE
	. ${INSTDIR}/script/config_netsnmp.sh $ROLE
	. ${INSTDIR}/script/config_drbd.sh $ROLE /usr/local/certifier ${DRBDRES} /dev/drbd1 7789 
	. ${INSTDIR}/script/config_insta.sh $ROLE
	. ${INSTDIR}/script/config_syslog.sh $ROLE
	. ${INSTDIR}/script/config_hsm.sh $ROLE
	. ${INSTDIR}/script/config_corosync.sh $ROLE /usr/local/certifier ${DRBDRES} /dev/drbd1 
	. ${INSTDIR}/script/config_ntpclnt.sh $ROLE                          
else
	. ${INSTDIR}/script/config_openssh.sh $ROLE
	. ${INSTDIR}/script/config_netsnmp.sh $ROLE
	. ${INSTDIR}/script/config_insta.sh $ROLE
	. ${INSTDIR}/script/config_syslog.sh $ROLE
	. ${INSTDIR}/script/config_ntpclnt.sh $ROLE
	. ${INSTDIR}/script/config_hsm.sh $ROLE
fi
#	
export -p  MYSELF="phase2.sh"
shf_logit "no more phase 2 scripts defined for execute, start cleaning"
#
cp -f /etc/rc.d/rc.local $BACKDIR/used_phase2.sh.$GENROLE.$NOW               |tee -a $LOGFILE 2>&1   
mv -f $BACKDIR/rc.local.$GENHOST.$NOW /etc/rc.d/rc.local         |tee -a $LOGFILE 2>&1
if [ $? -eq 0 ]
then
	shf_logit "Restored original file /etc/rc.d/rc.local from $NOW"
else
	shf_logit "Problem restoring file /etc/rc.d/rc.local from $NOW"
fi 	 
SHRTFLAG=`basename ${MAINFLAG}`
cp -f ${MAINFLAG} ${INSTDIR}/${SHRTFLAG}.${ROLE}.${NOW}
shf_logit "copied flagfile ${MAINFLAG} to ${INSTDIR}/${SHRTFLAG}.${ROLE}.${NOW}"
#
#--------------------------------------------------------------------------------------------
for DIR in hsmsw backup rhpatches
do
	[ -d "${INSTDIR}/${DIR}" ] && mv -f ${INSTDIR}/${DIR} ${HAPFCF}
	shf_logit "moved \"${INSTDIR}/${DIR}\" into \"$(ls -dl ${HAPFCF}/${DIR})\""
done

cp -f ${INSTDIR}/ks-*.cfg ${HAPFCF}/backup
shf_logit "moved from \"${INSTDIR}\": \"$(ls -l ${HAPFCF}/backup/ks-${ROLE}.cfg)\""
cp -f ${INSTDIR}/script/setnsnenv.sh ${HAPFCF}
shf_logit "moved from \"${INSTDIR}\": \"$(ls -l ${HAPFCF}/setnsnenv.sh)\""

OLDBD="$(grep -n "BACKDIR=" ${MAINFLAG}|cut -d':' -f1)"
sed -i "${OLDBD} d" ${MAINFLAG}; sed -i "${OLDBD} a BACKDIR=${HAPFCF}/backup" ${MAINFLAG}


OLDLOG="$(grep -n "LOGFILE=" ${MAINFLAG}|cut -d':' -f1)"
sed -i "${OLDLOG} d"  ${MAINFLAG}; sed -i "${OLDLOG} a LOGFILE=/var/log/hapf21_postinst.log" ${MAINFLAG}
mkdir ${HAPFCF}/instlog
cp -f ${INSTDIR}/*.log ${HAPFCF}/instlog
mv -f /var/log/anaconda*log ${HAPFCF}/instlog
for ALOG in anaconda-ks.cfg install.log install.log.syslog 
do
	[ -f "/root/${ALOG}" ] && mv -f /root/${ALOG} ${HAPFCF}/instlog
done
ATRPMKEY="${MTDIR}/rhpatches/RPM-GPG-KEY.atrpms"
if [ -f "${ATRPMKEY}" ]; then
	cp ${ATRPMKEY} /etc/pki/rpm-gpg/
	chmod 644 /etc/pki/rpm-gpg/RPM-GPG-KEY.atrpms
fi

: ${CLEANUP_ON_EXIT[$X]:="no"}
if [ "${CLEANUP_ON_EXIT[$X]}" = "yes" ]; then
	rm -f ${INSTDIR}/insta/*.lic
	rm -f ${INSTDIR}/insta/*.rpm
	rm -f ${INSTDIR}/script/*
	chmod 0400 ${INSTDIR}/sshconfig-*.tar
	chmod 0400 ${INSTDIR}/coroconfig.*.tar
	shf_logit "cleaned temporary install directories"
fi

ln -s /var/log/hapf21_postinst.log ${HAPFCF}/hapf21_postinst.log
shf_logit "redirected logfiles and file-backup to post-install locations"
echo "starting post-install log `date` `uname -n`" >  ${HAPFCF}/hapf21_postinst.log
chown root:root  ${HAPFCF}/hapf21_postinst.log
chmod 644  ${HAPFCF}/hapf21_postinst.log
#
shf_logit "Phase 2 : HAPF2.1 RAPID SETUP ENDING"
shf_logit "##################################################################"
############################################################################# 
else
	echo "DEBUG SWITCH SET TO INTERRUPT"
	# program actions below or just take the next
#	exit
#	MYPRMPT="$-DEBUG-$"
#	while :
#	do
#		echo -n ${MYPRMPT}
#		read MYLINE
#		eval ${MYLINE}
#	done
fi
#--------------------------------------------------------------------------
cd /;rc="$(umount ${MTDIR} &>/dev/null)$?"
shf_logit "unmount USB drive on ${MTDIR} exit with \"${rc}\""
shf_logit "#-----------------------------------------------------------------"
shf_logit "leaving script ${MYSELF}"
shf_logit "#-----------------------------------------------------------------"
chvt 1
exec </dev/tty1 >/dev/tty1

