#!/bin/bash
###########################################################################
# NSN INSTA HAPF2.1 RAPID SETUP CONFIG GENERATOR SCRIPT COMMON FUNCTIONS
#--------------------------------------------------------------------------
# Script default name 	: ~script/config_functions.sh
# Configure version     : mkks62f.pl
# Media set             : PF21I52RH63-12
# File generated        : 03.01.2013 MPe
# 
###########################################################################
unalias -a
alias ll='ls -ltrash --color=none'
###########################################################################
shf_logit () {
	MYCALL=${MYSELF}
	MYHOST=${GENHOST}
	MYTIME=`date  "+%b %e %H:%M:%S"`
	MYLOG=${LOGFILE} ; : ${LOGFILE:="/var/log/hapf21_postinst.log"}

	echo "${MYTIME} ${MYHOST} ${MYCALL}  $1" |tee -a ${MYLOG}
}
####################---------------------------------------##################
shf_confirm() {
	printf "$*"
	DUMMY=""; while [[ "${DUMMY}" != [y,Y][eE][sS] ]]
	do
		echo "type \"yes\" to continue or abort with [CTRL]-[C]"
		read DUMMY
	done
	return 0
}
####################---------------------------------------##################
shf_fshow () {
	MYFILE="$*"
	MYARGS="$#"
	MYTIME=`date  "+%H-%M-%S"`
	ISACMD="false"
	: ${HAPFCF:="/etc/hapf21.d"}
	: ${SHELLOG:="${HAPFCF}/cmdlog.${MYTIME}.$$"}

	/usr/bin/which `echo "${MYFILE}" |cut -d' ' -f 1` &>/dev/null
	if [ $? = 0 ] ; then ISACMD="true" ;fi

	if [ ${MYARGS} = "1" ] && [ ${ISACMD} = "false" ]
	then
		if [ -r ${MYFILE} ] && [ -f ${MYFILE} ]
		then
			printf '\n\n\n'                          &>> ${SHELLOG}
			printf '%80s\n' | tr ' ' '+'             &>> ${SHELLOG}
                        date                                     &>> ${SHELLOG}
			ls -lai ${MYFILE}                        &>> ${SHELLOG}
			md5sum  ${MYFILE}                        &>> ${SHELLOG}
			printf '\n'                              &>> ${SHELLOG}
			cat ${MYFILE}                            &>> ${SHELLOG}
			printf '\n END OF FILE %s\n' ${MYFILE}   &>> ${SHELLOG}
			printf '%80s\n' | tr ' ' '-'             &>> ${SHELLOG}
		elif [ -r ${MYFILE} ] && [ -d ${MYFILE} ]
		then
                        printf '\n\n\n'                          &>> ${SHELLOG}
                        printf '%80s\n' | tr ' ' '+'             &>> ${SHELLOG}
			date                                     &>> ${SHELLOG}
                        ls -lai ${MYFILE}/..|grep ${MYFILE}      &>> ${SHELLOG}
			ls -trashi ${MYFILE}                     &>> ${SHELLOG}
                        printf '\n END OF FILE %s\n' ${MYFILE}   &>> ${SHELLOG}
                        printf '%80s\n' | tr ' ' '-'             &>> ${SHELLOG}

		else
			shf_logit "shf_show: Can not display ${MYFILE} in ${SHELLOG}"
	  	fi
	elif [ ${ISACMD} = "true" ] 
	then
		printf '\n\n'                                    &>> ${SHELLOG}
		printf '%80s\n' | tr ' ' '+'                     &>> ${SHELLOG}
		date                                             &>> ${SHELLOG}
		printf ' COMMAND: %s\n' ${MYFILE}                &>> ${SHELLOG}
		eval ${MYFILE}                                   &>> ${SHELLOG}              		
	else
		shf_logit "shf_show: No idea what I should do with ${MYCMD}"
	fi
}
####################---------------------------------------##################
shf_fast_entropy() {
	SLOWRAND="/dev/random"
	FASTRAND="/dev/urandom"
	BACKPRND="slow"

	case $1 in
	"on")
		if [ -e "${FASTRAND}" ]; then
			mv "${SLOWRAND}" "${SLOWRAND}.${BACKPRND}"
			mv "${FASTRAND}" "${SLOWRAND}"
			shf_logit "speedup - fast entropy via urandom defaulted"
		else
			shf_logit "fast entropy on requested but \"${FASTRAND}\" not found"
		fi
	;;
	"off")
		if [ -e "${SLOWRAND}.${BACKPRND}" ]; then
			mv "${SLOWRAND}" "${FASTRAND}"
			mv "${SLOWRAND}.${BACKPRND}" "${SLOWRAND}"
			shf_logit "restored normal entropy collection"
		else
			shf_logit "fast entropy off requested but it seems not to be on" 
		fi
	;;
	esac
}
####################---------------------------------------##################
shf_roothd() {

	HDDEV=$(df |awk '($6=="/"){print$1}')
#       HDDEV="/dev/cciss1/c0t3d5"
	DEVPATH=( `echo ${HDDEV}|tr "/" " "` )
	DEPTH=${#DEVPATH[@]}
	
	DSKTYPE=${DEVPATH[$DEPTH-1]}
	PREFIX=$(echo ${DSKTYPE}|tr -d [0-9])
	unset DEVPATH[$DEPTH-1]; unset DEVPATH[0]

	rc=1
	case ${PREFIX} in
		"cdp")
			VEN="HP smart array driver"
			ROOTDSK="${DEVPATH[1]}/$(echo ${DEVPATH[2]}|cut -d'p' -f1)"
			rc=0
		;;
		sd?)
			VEN="Standard sd SCSI"
			[ -z "$(echo ${CTRTYPE:2:1}|tr -d [a-z])" ] && rc=0
			ROOTDSK=${PREFIX}
		;;
		hd?)
			if [ -z "$(echo ${DSKTYPE:2:1}|tr -d [a-d])" ] ; then
				rc=0 ; VEN="Standard IDE"
				ROOTDSK=${PREFIX}
			else
				rc=1 ; VEN="UNKNOWN"
				unset ROOTDSK
			fi
		;;
		md)
			if [ -z "$(echo ${DSKTYPE:2:1}|tr -d [0-9])" ] ; then
				rc=0 ; VEN="Linux MD Software RAID"
				TDSK=$(echo ${DEVPATH[@]}|tr " " "/")"/"$(echo ${DSKTYPE}) 
				ROOTDSK=$(echo ${TDSK}|sed 's/^\///')
			else
				rc=1 ; VEN="UNKNOWN"
				unset ROOTDSK
			fi
		;;
		"lvm")
			VEN="Linux LVM"	
		;;
		*)
			if [[ ${DSKTYPE} == c[0-9]t[0-9]*d[0-9]* ]] ; then
				VEN="generic"
				ROOTDSK=$(echo ${DEVPATH[@]}|tr " " "/")"/"$(echo ${DSKTYPE}|cut -d'd' -f1)
				rc=0
			elif [[ ${DEVPATH[2]} == c[0-9]t[0-9]*d[0-9]*s[0-9]* ]] ; then
				VEN="generic-sliced"
				ROOTDSK=$(echo ${DEVPATH[@]}|tr " " "/")"/"$(echo ${DSKTYPE}|cut -d'd' -f1)
				rc=0
			else
				VEN="UNKNOWN"
				unset ROOTDSK
				rc=1
			fi
		esac

	shf_logit "root disk detection on \"${HDDEV}\" assumes \"${VEN}\" with exit \"$rc\"" &>/dev/null
	echo ${ROOTDSK}
	return $rc	
}
####################---------------------------------------##################
shf_usbdsk() {
	nested_isme() {
			# keep it simple here
			MDIR="$1" ; rc=0
			[ ! -d ${MDIR}/insta ] && rc=1
			[ ! -d ${MDIR}/rpms ] && rc=1
			[ ! -d ${MDIR}/RHEL64 ] && rc=1
			[ ! -d ${MDIR}/script ] && rc=1
			[ "${rc}" != "0" ] && shf_logit "ERROR: USB media found but seems to be no HAPF2.1 install media"
			return ${rc}
	}

	: ${MTDIR="/media"}
	[ ! -d ${MTDIR} ] && mkdir ${MTDIR}

	unset MYUSB ; FNDUSB=1 ; let i=1

	ISHERE=( $(cat /proc/mounts|awk '($3=="vfat"){print$2}') )

	for DOSDIR in ${ISHERE[@]} 
	do
		FNDUSB=$(nested_isme ${DOSDIR})$?
		[ ${FNDUSB} -eq 0 ] && MYUSB=$(cat /proc/mounts|awk -v D="${DOSDIR}" '(($3=="vfat") && ($2==D)){print$1}') 
	done

	NOTHERE=$( shf_roothd )

	while [ ${FNDUSB} -ne 0 ] && [ $i -le 8 ]
	do
		for DSK in {a..z}
		do
			PART="sd${DSK}${i}"
			if [ "${NOTHERE}" != "sd${DSK}" ] ; then

				FNDUSB=$(mount -t vfat /dev/${PART} ${MTDIR} &>/dev/null)$?
				if [ ${FNDUSB} -eq 0 ] && [ $(nested_isme ${MTDIR})$? -eq 0 ]
				then
					MYUSB="/dev/${PART}" 
					umount ${MTDIR} &>/dev/null
					break					
	               		fi
				umount ${MTDIR} &>/dev/null
			fi
		done
		let i=$i+1
		sleep 1
	done
	shf_logit "found USB install media for RHEL64 based medset at ${MYUSB}" &>/dev/null
	echo "${MYUSB}"
	[ "$1" = "replace" ] && export -p PENDRVUSBDEVICE[$X]="${MYUSB}"
	return ${FNDUSB}
}
####################---------------------------------------##################
shf_set_index() {
# fe1 -> 1; fe2 -> 2; be1 -> 3; be2 -> 4; fe3 ->5; fe4 -> 6; SingleServer ->0
# Y == HA peer ; Z == horizontal peer ; odd/impair indexes are HA prefered
	case ${ROLE} in
	"be1")
	X=3;Y=4;
	;;
	"be2")
	X=4;Y=3;
	;;
	"fe1")
	X=1;Y=2;Z=3;
	;;
	"fe2")
	X=2;Y=1;Z=3;
	;;
	"fe3")
	X=5;Y=6;Z=3;
	;;
	"fe4")
	X=6;Y=5;Z=3;
	;;
	"SingleServer")
	X=0
	;;
	*)
	shf_logit "WRONG ROLE REQUESTED - EXITING "
	exit 1
	esac
}
####################---------------------------------------##################
shf_tag_cffile () {

	MYFILE=$1
	SHORT=`basename ${MYFILE}`
        MYCALL=${MYSELF}
	PREVIOUS="UNKNOWN"
	: ${BACKDIR:="${INSTDIR}/backup"}

        if [ ! -d ${BACKDIR} ]; then  mkdir -p ${BACKDIR}; fi
	
	if [ "$2" = "no-backup" ] && [ -f ${MYFILE} ] ; then
		PREVIOUS="Old Values were overwritten"
                rm -f $MYFILE 2>/dev/null
	elif [ "$2" != "no-backup" ] && [ -f ${MYFILE} ] ; then
		if [ ! -w ${MYFILE} ] ; then
                	shf_logit "ERROR: Can not overwrite config ${MYFILE}"
                	exit
		fi
		PREVIOUS="Old Values were preserved"
         	grep  -v "^[[:blank:]]*#" ${MYFILE} > ${MYFILE}.tmp
		mv -f ${MYFILE} "${BACKDIR}/${SHORT}.${ROLE}.${NOW}"
        else 
                PREVIOUS="CREATED NEW FILE" 
        fi

	shf_logit "function tag_cffile: throwing header text into ${MYFILE}"
	
cat <<EOCF >${MYFILE}
################################################################################
# NSN INSTA HAPF2.1 RAPID SETUP AUTO INSTALLATION PROCEDURE
# ---------------------------------------------------------
# File 			: ${MYFILE}
# Generated by          : ${MYCALL}
# generated at 		: `date`
# Configure version 	: ${GENVERS}
# configure.sh          : ${NOW}
# Existing params 	: $PREVIOUS
# Media Set 		: ${MEDSET}
# 
#
################################################################################
EOCF
sync
cat ${MYFILE}.tmp >> ${MYFILE} 2>/dev/null
rm -f ${MYFILE}.tmp 1>&2 >/dev/null
}
####################---------------------------------------##################
shf_crm () {
	RC=3
	MAXTRY=3
	LAP=0
	let DEL=0
	while [ ${RC} -ne 0 ] && [ ${DEL} -le ${MAXTRY} ]
	do
     		crm $*
     		RC=$?	
     		if [ ${RC} -ne 0 ] && [ ${DEL} -ne ${MAXTRY} ]
     		then
     			shf_logit "problem: returned ${RC} when running $*"
			sleep 2
     		elif [ ${DEL} -eq ${MAXTRY} ]
     		then
     			shf_logit "giving up on: $*"
		else
			shf_logit "OK: $*"
     		fi
     		let DEL=${DEL}+1
     		sleep ${LAP}
	done
	return ${RC}
}
####################---------------------------------------##################
shf_wrap_vlans () {
	[ ! -z "${VLAN1ID[$X]}" ]  && VLAN[0]="${VLAN1ID[$X]} ${VLAN1IPADDR[$X]} ${VLAN1MASK[$X]} ${VLAN1IPvirtual[$X]}"
	[ ! -z "${VLAN2ID[$X]}" ]  && VLAN[1]="${VLAN2ID[$X]} ${VLAN2IPADDR[$X]} ${VLAN2MASK[$X]} ${VLAN2IPvirtual[$X]}"
	[ ! -z "${VLAN3ID[$X]}" ]  && VLAN[2]="${VLAN3ID[$X]} ${VLAN3IPADDR[$X]} ${VLAN3MASK[$X]} ${VLAN3IPvirtual[$X]}"
	[ ! -z "${VLAN4ID[$X]}" ]  && VLAN[3]="${VLAN4ID[$X]} ${VLAN4IPADDR[$X]} ${VLAN4MASK[$X]} ${VLAN4IPvirtual[$X]}"
	[ ! -z "${VLAN5ID[$X]}" ]  && VLAN[4]="${VLAN5ID[$X]} ${VLAN5IPADDR[$X]} ${VLAN5MASK[$X]} ${VLAN5IPvirtual[$X]}"
	[ ! -z "${VLAN6ID[$X]}" ]  && VLAN[5]="${VLAN6ID[$X]} ${VLAN6IPADDR[$X]} ${VLAN6MASK[$X]} ${VLAN6IPvirtual[$X]}"
	[ ! -z "${VLAN7ID[$X]}" ]  && VLAN[6]="${VLAN7ID[$X]} ${VLAN7IPADDR[$X]} ${VLAN7MASK[$X]} ${VLAN7IPvirtual[$X]}"
	[ ! -z "${VLAN08ID[$X]}" ] && VLAN[7]="${VLAN8ID[$X]} ${VLAN8IPADDR[$X]} ${VLAN8MASK[$X]} ${VLAN8IPvirtual[$X]}"
	[ ! -z "${VLAN09ID[$X]}" ] && VLAN[8]="${VLAN9ID[$X]} ${VLAN9IPADDR[$X]} ${VLAN9MASK[$X]} ${VLAN9IPvirtual[$X]}"
	[ ! -z "${VLAN10ID[$X]}" ] && VLAN[9]="${VLAN10ID[$X]} ${VLAN10IPADDR[$X]} ${VLAN10MASK[$X]} ${VLAN10IPvirtual[$X]}"
	[ ! -z "${VLAN11ID[$X]}" ] && VLAN[10]="${VLAN11ID[$X]} ${VLAN11IPADDR[$X]} ${VLAN11MASK[$X]} ${VLAN11IPvirtual[$X]}"
	[ ! -z "${VLAN12ID[$X]}" ] && VLAN[11]="${VLAN12ID[$X]} ${VLAN12IPADDR[$X]} ${VLAN12MASK[$X]} ${VLAN12IPvirtual[$X]}"
	[ ! -z "${VLAN13ID[$X]}" ] && VLAN[12]="${VLAN13ID[$X]} ${VLAN13IPADDR[$X]} ${VLAN13MASK[$X]} ${VLAN13IPvirtual[$X]}"
	[ ! -z "${VLAN14ID[$X]}" ] && VLAN[13]="${VLAN14ID[$X]} ${VLAN14IPADDR[$X]} ${VLAN14MASK[$X]} ${VLAN14IPvirtual[$X]}"
	[ ! -z "${VLAN15ID[$X]}" ] && VLAN[14]="${VLAN15ID[$X]} ${VLAN15IPADDR[$X]} ${VLAN15MASK[$X]} ${VLAN15IPvirtual[$X]}"
	for i in {1..15}
	do
        	[ -z "`echo ${VLAN[$i]}|sed  s/' '//g`" ] && unset  VLAN[$i]
	done
}
####################---------------------------------------##################
shf_get_mac () {
	MYIF=$1 ; [ $# -ne 1 ] && shf_logit "WARNING: wrong number of arguments for shf_get_mac" && return 1
	[[ $(ip link show ${MYIF}) ]] || shf_logit "WARNING: did not find a device named \"${MYIF}\"" 
	
	MYMAC=ifconfig ${MYIF}|awk -v IF="${MYIF}" '($1==IF) && ($2=="Link") && ($4=="HWaddr"){print$5}'
	echo ${MYMAC}
}

####################---------------------------------------##################
shf_add_nwif () {
	MYVLAN=( $* )
	ID=${MYVLAN[0]} ; IP=${MYVLAN[1]} ; MASK=${MYVLAN[2]} ; VIP=${MYVLAN[3]}
	shf_logit "entering network resource configuration for \"`echo ${MYVLAN[@]}`\""
	if [ -z "`echo ${ID}|sed 's/[0-9]//g'`" ]
#-----------------------------------------------------------------------------------------------------------
	then
        	shf_logit "definition made for logical network resource: VLAN ID \"${ID}\""
#-----------------------------------------------------------------------------------------------------------
#
	        BOND=${MYVLAN[4]}
		if [ ! "`echo ${BOND:0:4}`" = "bond" ] || [ ! -z "`echo ${BOND:4}|tr -d '[0-9]'`" ]
		then
			BOND="bond0" ; MYVLAN[5]="eth1" ; MYVLAN[6]="eth2" ; unset MYVLAN[7]
			shf_logit "bundling physical i/f \"${MYVLAN[5]}\" and \"${MYVLAN[6]}\" into trunk \"${BOND}\""
		fi
		let i=5 ; ONEMORE="yes"
		while [ ${ONEMORE} != "no" ]
		do
			IFTYP="`expr match ${MYVLAN[$i]} '\(.[a-z]*\)'`"
			IFNBR=${MYVLAN[$i]//$IFTYP/}
			if [ ${IFTYP} = "eth" ] && [ -z "`echo ${IFNBR}|tr -d '[0-9]'`" ]
			then
				MYVLAN[$i]="${IFTYP}${IFNBR}"
				FILE="/etc/sysconfig/network-scripts/ifcfg-${MYVLAN[$i]}"
				shf_tag_cffile $FILE "no-backup"
				shf_logit "assigning physical interface \"${MYVLAN[$i]}\" to \"${BOND}\""
				cat <<-EOETHT >>$FILE
					DEVICE="${MYVLAN[$i]}"
					MTU=1400
					BOOTPROTO=none
					ONBOOT=yes
					MASTER=${BOND}
					SLAVE=yes
					USERCTL=no
				EOETHT
				chown root:root $FILE
				chmod 0644 $FILE
				shf_logit "`cat $FILE|wc -l` lines as : \"`ls -la $FILE `\""
				shf_fshow $FILE
			else
				shf_logit "unsupported physical interface type \"${IFTYP}\""
			fi
			let i=$i+1
			[ -z "${MYVLAN[$i]}" ] && ONEMORE="no"
		done

		FILE="/etc/sysconfig/network-scripts/ifcfg-${BOND}"
		if [ ! -f "${FILE}" ]
		then
			shf_tag_cffile $FILE "no-backup"
			cat <<-EOBND >> $FILE
				DEVICE=${BOND}
				BOOTPROTO=none
				ONBOOT=yes
				USERCTL=no
				MTU=1400
			EOBND
			chown root:root $FILE
			chmod 0644 $FILE
			shf_logit "\"`cat $FILE|wc -l`\" lines as : \"`ls -la $FILE`\" - created interface \"${BOND}\""
			shf_fshow $FILE
		fi

		shf_logit "Creating VLANID \"${ID}\" on \"${BOND}\""
		FILE="/etc/sysconfig/network-scripts/ifcfg-${BOND}.${ID}"
		shf_tag_cffile "${FILE}" "no-backup"
		cat <<-EOVLAN >>${FILE}
			DEVICE=${BOND}.${ID}
			BOOTPROTO=static
			MTU=1400
			VLAN=yes
			IPADDR=${MYVLAN[1]}
			NETMASK=${MYVLAN[2]}
			ONBOOT=yes
			USERCTL=no
		EOVLAN
		chown root:root ${FILE}
		chmod 0644 ${FILE}
		shf_logit "\"`cat ${FILE}|wc -l`\" lines as : \"`ls -la ${FILE}`\""
#-----------------------------------------------------------------------------------------------------------
	else
		shf_logit "definition made for physical network resource: \"${ID}\""
#-----------------------------------------------------------------------------------------------------------
#
		if [ "`echo ${ID:0:3}`" = "eth" ] && [ -z "`echo ${ID:3}|tr -d '[0-9]'`" ]
		then
			FILE="/etc/sysconfig/network-scripts/ifcfg-${ID}"
			HWADDR=`(cat ${FILE} |grep "HWADDR") 2>/dev/null`

			shf_tag_cffile "$FILE" "no-backup"

			if [ ! -z "$HWADDR" ]
			then
				shf_logit "keeping anaconda defined MAC \"${HWADDR}\" for ${ID} in config"
			else
				MAC="$(shf_get_mac ${ID})"
				HWADDR="HWADDR=${MAC}"
				shf_logit "no existing MAC address found for \"${ID}\" - using current value \"${MAC}\""
			fi

			cat <<-EIFCFG >> ${FILE}
				DEVICE=${ID}
				${HWADDR}
				BOOTPROTO=static
				ONBOOT=yes
				IPADDR=${MYVLAN[1]}
				NETMASK=${MYVLAN[2]}
				MTU=1400
				USERCTL=no
			EIFCFG
			chown root:root $FILE
			chmod 0644 $FILE
			shf_logit "\"`cat $FILE|wc -l`\" lines as : \"`ls -la $FILE`\" - created interface \"${ID}\""
		else
			shf_logit "unsupported interface type \"${ID}\""
		fi
fi
}
####################---------------------------------------##################
shf_hsm_stat() {
	unset local verbose
	[ "$1" = "-v" ] && verbose="yes"
	rc=1 
	: ${HSMDIR:="/opt/nfast"}
	TOOL="${HSMDIR}/bin/nfkminfo"
	NUMSLTS="$(${TOOL} |grep  "Module #1 Slot #"|wc -l)"
	let NUMSLTS=$NUMSLTS-1 
	for SLT in $(seq 0 ${NUMSLTS})
	do
		CARDSTAT="$(${TOOL}|grep -A 4 "Module #1 Slot #${SLT}"|grep "^ state"|tr --squeeze-repeats ' '|cut -d' ' -f 4)"
		if [ "${CARDSTAT}" = "Operator" ]; then
		rc=0; shf_logit "operator card found in \"Module #1 Slot #${SLT}\""
		fi
		echo "SLOT-${SLT}: "${CARDSTAT}
		[ "${verbose}" = "yes" ] && shf_logit "hsm smartcard reader SLOT-${SLT}: \"${CARDSTAT}\"" 
	done
	return $rc
}
####################---------------------------------------##################
shf_snmpengineid_to_trapdconf() {
	PERSTRAP="/var/lib/net-snmp/snmpd.conf"
	TRAPDCFG="/etc/snmp/snmptrapd.conf"
	MATCHPAT="INSERT-CERTIFIER-ENGINE-ID-HERE"
	unset ENGID
	if [ -f "${PERSTRAP}" ] 
	then
		ENGID="$(grep -m 1 "oldEngineID" ${PERSTRAP} 2>/dev/null|cut -d' ' -f 2)"
		shf_logit "found SNMP engineID \"${ENGID}\""
		[ -z "${ENGID}" ] && shf_logit "ERROR: Can not find engineID in \"${PERSTRAP}\""
	else
		shf_logit "ERROR: Can not find ${PERSTRAP} you must insert engineID manually"
	fi
	if [ -f "${TRAPDCFG}" ] && [ ! -z "${ENGID}" ]
	then
		sed -i s/${MATCHPAT}/${ENGID}/g ${TRAPDCFG} && sync
		shf_logit "changed line in snmptrapd.conf to: \"$(grep ${ENGID} ${TRAPDCFG})\""
	else
		shf_logit "ERROR: Can not find ${TRAPDCFG} can not update trap conversion with engineID"
	fi
	sleep 2 && service snmptrapd restart && sync && sleep 1
}
####################---------------------------------------##################
shf_debug_break () {
	shf_cont () { : ; } ;
	echo "-MARK:${1}--------------- enter \"shf_cont\" to resume ------------------"
	unset line
	DBP="#-DEBUG-#"
	while [ "$line" != "shf_cont" ] 
	do
		echo -n $DBP
		read line
		eval $line
	done
}
####################---------------------------------------##################
