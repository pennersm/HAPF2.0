#!/bin/bash
###########################################################################
# NSN INSTA HAPF2.1 RAPID SETUP CONFIG GENERATOR SCRIPT 
#--------------------------------------------------------------------------
# Script default name   : ~script/config_drbd.sh
# Configure version     : mkks62f.pl
# Media set             : PF21I52RH63-12
# File generated        : 03.01.2013 MPe
# 
###########################################################################
export -p  MYSELF="config_drbd.sh"
shf_logit "#-----------------------------------------------------------------"
shf_logit "starting to run script ${MYSELF}"
shf_logit "#-----------------------------------------------------------------"
#
ROLE=$1           ;  if [ -z ${ROLE}    ] ; then exit ; fi 
DRBDDIR=${2%/}    ;  if [ -z ${DRBDDIR} ] ; then exit ; fi
DRBDRES=$3        ;  if [ -z ${DRBDRES} ] ; then exit ; fi
DRBDDEV=$4        ;  if [ -z ${DRBDDEV} ] ; then exit ; fi
DRBDPRT=$5        ;  if [ -z ${DRBDPRT} ] ; then exit ; fi
SYNC_TO=$6	  ;  if [ ! -z "$(echo ${SYNC_TO}|tr -d [:digit:])" ]; then exit ; fi

export -p SHELLOG=${INSTDIR}/${MYSELF}.${ROLE}.${NOW}.shell.log

: ${SYNC_TO:="1080"}

shf_set_index
shf_logit "Using Role $ROLE in here, configure index $X"
shf_logit "${NOW} using ARGS: `echo $*`"
shf_logit "creating file to log command outputs: ${SHELLOG}"

cat /dev/null > ${SHELLOG}
echo "starting shellog for ${NOW} ${MYSELF} `date`" &>> ${SHELLOG}
set &>> ${SHELLOG}
echo "=======================================================================" &>> ${SHELLOG}
#
##############################################################################
# below due to "bug" in RH packaging :  built option prefix no match 
# http://www.gossamer-threads.com/lists/drbd/users/16651
# track this and remove below workaround later
mkdir -p /var/lib/drbd >& /dev/null
ln -s /etc/drbd.conf /var/lib/drbd/drbd-minor-1.conf 
shf_logit "RHEL packagin symlink error workaround applied: `ls /var/lib/drbd/`"
###############################################################################
# another issues is that the cluster comes often up in sb-0pri and the bahaviour 
# is neither understood by me nor automatically resolved with the built-in 
# procedures. So we configure "disconnect" as the main sb-policy and deliver
# a simple handler here to clean the mess as good as possible
SBHANDLER="/etc/drbd.d/startup_sbhelper"
##############################################################################
#
mount -a
shf_fshow df
if [ ${ROLE} = "be1" -o ${ROLE} = "be2" ]
then
	PARTSTR=`cat /etc/fstab| grep -v "#"|grep ${DRBDDIR}|awk '{print$1}'`
	if [ -z "${PARTSTR}" ] 
	then
        	echo "exception testing, can not find partition for ${DRBDDIR}" &>> ${SHELLOG}
		shf_fshow /etc/fstab
		find /dev/disk                                                  &>> ${SHELLOG} 
		df -h                                                           &>> ${SHELLOG}
		PARTSTR=`df|grep ${DRBDDIR}|awk '{print$1}'`
		if ( echo ${PARTSTR} | grep "/dev/drbd"                         &>> ${SHELLOG})
		then
			shf_logit "WARNING: device ${PARTSTR} is mounted on ${DRBDDIR}"
		fi 
	fi

	shf_fshow echo ${PARTSTR}

	shf_logit "Checking /etc/fstab : `echo ${PARTSTR}|tr --squeeze-repeats '  '| tr \"\n\" \" \"`"

	if [ ! -z "${PARTSTR}" ] && [ `echo ${PARTSTR}|cut -d'=' -f 1` = "UUID"  ]
	then
		shf_logit "found ${PARTSTR} for ${DRBDDIR}"
		PDRBD=`findfs ${PARTSTR}`                                      &>> ${SHELLOG}
	elif [ ! -z "${PARTSTR}" ] && [ `df |grep ${PARTSTR}|awk '{print$1}'` = ${PARTSTR} ]
	then
		PDRBD=${PARTSTR}
		shf_logit "found ${PDRBD} for ${DRBDDIR}"
	else
        	shf_logit "ERROR: did not find any partition related to mountpoint ${DRBDDIR} "
        	exit 3
	fi
	shf_fshow echo ${PDRBD}
fi
#
#=============================================================================
if [ ${ROLE} = "be1" -o ${ROLE} = "be2" ]
then
	FILE="/etc/drbd.d/global_common.conf"
	RESFIL=${FILE}

	shf_logit "preparing ${FILE} for ${ROLE}"
	shf_tag_cffile ${FILE} "no-backup"

	cat <<-EOGDRBD >> ${FILE}
	global {
	          usage-count no;	
	}
	common {
	          protocol C;
	          handlers { split-brain "${SBHANDLER}";
	          }
	          startup {
	                     outdated-wfc-timeout 15;
	                     degr-wfc-timeout 15;
	                     wfc-timeout 35;
	          }
	          disk {
	                     on-io-error detach;
	          }
	          net {
	                     allow-two-primaries yes;	
	                     after-sb-0pri disconnect;
	                     after-sb-1pri discard-secondary;
	                     after-sb-2pri disconnect;
	          }
	          syncer {
	          }
	}
	EOGDRBD
	chown root:root ${FILE}
	chmod 0644 ${FILE}
	shf_logit "`cat ${FILE}|wc -l` lines as : `ls -la ${FILE} `"
	shf_fshow ${FILE}
fi
#
#
#-----------------------------------------------------------------------------
if [ ${ROLE} = "be1" -o ${ROLE} = "be2" ]
then
	FILE="/etc/drbd.conf"

	shf_logit "preparing ${FILE} for ${ROLE}"
	shf_tag_cffile ${FILE} "no-backup"

	cat <<-EORDRBD >> ${FILE} 
	include ${RESFIL};
	resource ${DRBDRES} {
	                     device ${DRBDDEV};
	                     disk ${PDRBD};
	                     meta-disk internal;
	                     syncer {
	                              rate 850M;
	                              verify-alg crc32c;
	                     }
	                     net {
	                     }
	                     on ${HOSTNAME[$X]} {
	                                     address ${HBIPADDR[$X]}:${DRBDPRT};
	                     }
	                     on ${HOSTNAME[$Y]} {
	                                     address ${HBIPADDR[$Y]}:${DRBDPRT};
	                     }
	}
	EORDRBD
	chown root:root ${FILE}
	chmod 0644 ${FILE} 
        shf_logit "`cat ${FILE}|wc -l` lines as : `ls -la ${FILE}`"
	shf_fshow ${FILE}
fi
#
#-----------------------------------------------------------------------------
#
if [ ${ROLE} = "be1" -o ${ROLE} = "be2" ]
then
FILE="/etc/fstab"
	printf '\n\n%80s\n' | tr ' ' '.'                                          &>> ${SHELLOG}
        echo   "Configuring DRBD device and creating filesystem "                 &>> ${SHELLOG}
	shf_logit "removing \"${PDRBD}\" from \"${FILE}\""
	if [ -b ${PDRBD} ] 
	then
		cp -f ${FILE} ${BACKDIR}/`basename ${FILE}`.${ROLE}.${NOW}	
		cat ${FILE} |grep  -v "^[[:blank:]]*#" > ${FILE}.${ROLE}.${NOW}
	        	
		if [ $? -eq "0" ]
		then
			shf_tag_cffile ${FILE} "no-backup"
			cat  ${FILE}.${ROLE}.${NOW} |grep -v ${DRBDDIR}|grep -v "/boot/efi" >> ${FILE}
			chown root:root ${FILE} 
			chmod 0644 ${FILE}				
			shf_logit "`cat ${FILE}|wc -l` lines as : \"`ls -la ${FILE}`\""
			shf_fshow ${FILE}
		else
			shf_logit "ERROR: ${FILE} unchanged, cant find partition for mountpoint ${DRBDDIR}"
			echo "exception testing: Can not find partition to mount" &>> ${SHELLOG}
			shf_fshow /etc/fstab
			shf_fshow /etc/mtab                                         
		fi
		rm -rf ${FILE}.${ROLE}.${NOW} &>/dev/null

		shf_logit "preparing ${DRBDDEV} to be mounted on ${DRBDDIR}"
               		umount -vf ${DRBDDIR} &>> ${SHELLOG}
			if [ $? -ne 0 ] 
			then
				echo "can not unmount ${DRBDDEV}, try kill all with fuser" &>> ${SHELLOG}
				fuser -cu  ${DRBDDIR}  &>> ${SHELLOG}
				fuser -cku ${DRBDDIR}  &>> ${SHELLOG}
				umount -vf ${DRBDDIR}  &>> ${SHELLOG}
			fi

  		shf_logit "erasing existing Filesystem on ${PDRBD}"
       			dd if=/dev/zero of=${PDRBD} bs=512 count=256 &>> ${SHELLOG}

		shf_logit "running create-md for ${DRBDRES} on ${DRBDDEV}"
			drbdadm create-md ${DRBDRES} &>> ${SHELLOG}
			if [ $? -ne "0" ]
                        then
                                shf_logit "WARNING: problem while creating md"
                        fi

			modprobe drbd    &>> ${SHELLOG}
			if [ $? -ne "0" ]
                        then
                                shf_logit "WARNING: problem while loading driver"
                        fi
		shf_logit "loaded driver: `lsmod|grep drbd|tr --squeeze-repeats '  '| tr \"\n\" \" \"`"
		shf_logit "starting device $DRBDDEV"
			drbdadm up ${DRBDRES} &>> ${SHELLOG}
			if [ $? -ne "0" ]
			then
				shf_logit "WARNING: problem while starting device"
			fi
			shf_logit "initial drbd device created: \"`drbd-overview|tr \"\n\" \" \"|tr --squeeze-repeats '  '`\""
 
	else    
               shf_logit "ERROR: Can not find Blockdevice ${PDRBD}"
	fi
fi
#
#-----------------------------------------------------------------------------
#
if [ ${ROLE} = "be2" ]
then
        shf_logit "trying to attach to DRBD peer on ${HOSTNAME[Y]}"
	if ( ping -I ${HBIPADDR[$X]} -n -c 5 -q ${HBIPADDR[$Y]} &>> ${SHELLOG}  )
	then
		drbdadm primary --force ${DRBDRES}
		
		let i=0; shf_logit "now waiting drbd peers to sync - hold your horses for max \"${SYNC_TO}\"s"
		while [ -z "`drbd-overview|awk '(($2=="Connected") && ($4=="UpToDate/UpToDate")){print$3}'`" ] && [ $i -le "${SYNC_TO}" ]
		do
			[ $(($i%90)) -eq 0 ] && shf_logit "still syncing with drbd peer: \"`drbd-overview|tr \"\n\" \" \"|tr --squeeze-repeats '  '`\""
			sleep 1 ; let i=$i+1
		done
		[ $i -ge "${SYNC_TO}" ] && shf_logit "wait timeout - continuing as is: \"`drbd-overview|tr \"\n\" \" \"|tr --squeeze-repeats '  '`\""


		mkfs -t ext3 ${DRBDDEV}   &>> ${SHELLOG}
		shf_logit "filesystem of type ext3 created for ${DRBDRES}"
		mount -o rw ${DRBDDEV} ${DRBDDIR} 
		if [ $? -ne 0 ]
		then
			shf_logit "ERROR: Can not mount ${DRBDDEV} at ${DRBDDIR} exiting"
			exit 1
		else
			shf_logit "mounted : \"`df -h|grep $DRBDDEV|tr \"\n\" \" \"|tr --squeeze-repeats '  '`\""
		fi

	else
		shf_logit "ERROR: host ${HOSTNAME[$Y]} seems to be unreachable on ${HBIPADDRESS[$Y]}"
	fi
	
fi	
#
#-----------------------------------------------------------------------------
if [ ${ROLE} = "be1" -o ${ROLE} = "be2" ]
then
	FILE="${SBHANDLER}" 
	cat <<-EOWRKRND >> ${FILE}
		#!/bin/bash
		nodes=( \$(crm node show) )
		node1=${HOSTNAME[$X]}
		node2=${HOSTNAME[$Y]}
		if [ "\${nodes[1]}" = "normal" ] && [ "\${nodes[3]}" = "normal" ]
		then
		      n1stat=( \$(ssh  -o StrictHostKeyChecking=no root@\${node1} -- drbd-overview) )
		      n2stat=( \$(ssh  -o StrictHostKeyChecking=no root@\${node1} -- drbd-overview) )
	
		      doit="1:certifier/0 Connected Secondary/Secondary UpToDate/UpToDate C r-----"

		      if [ "\$(echo \${n1stat[@]})" = "\${doit}" ] &&  [ "\$(echo \${n2stat[@]})" = "\${doit}" ]
		      then
		            ssh  -o StrictHostKeyChecking=no root@\${node1} -- drbdadm primary certifier
			    logger -p user.info -t hapf21-drbd-workaround "kicked ${node1} to be primary: \$(drbd-overview|tr --squeeze-repeats ' ')" 
		      fi
		fi
	EOWRKRND
	chown root:root ${FILE}
	chmod 0755 ${FILE} 
	shf_logit "added workaround for stuck DRBD cluster issue: \"`ls -la ${FILE}|tr --squeeze-repeats '  ' `\""
fi
#-----------------------------------------------------------------------------
#
shf_logit "DRBD status on ${ROLE}: \"`drbd-overview|tr \"\n\" \" \"|tr --squeeze-repeats '  '`\""
shf_logit "#-----------------------------------------------------------------"
shf_logit "leaving script ${MYSELF}"
shf_logit "#-----------------------------------------------------------------"
echo "ending at `date`" &>> ${SHELLOG}
