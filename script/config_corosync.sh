#!/bin/bash
###########################################################################
# NSN INSTA HAPF2.1 RAPID SETUP CONFIG GENERATOR SCRIPT
#--------------------------------------------------------------------------
# Script default name   : ~script/config_corosync.sh
# Configure version     : mkks62f.pl
# Media set             : PF21I52RH63-12
# File generated        : 03.01.2013 MPe
#
###########################################################################
export -p  MYSELF="config_corosync.sh"
shf_logit "#-----------------------------------------------------------------"
shf_logit "starting to run script config_corosync.sh"
shf_logit "#-----------------------------------------------------------------"
#
ROLE=$1           ;  if [ -z ${ROLE}    ] ; then exit ; fi
DRBDDIR=${2%/}    ;  if [ -z ${DRBDDIR} ] ; then exit ; fi
DRBDRES=$3        ;  if [ -z ${DRBDRES} ] ; then exit ; fi
DRBDDEV=$4        ;  if [ -z ${DRBDDEV} ] ; then exit ; fi
HACFGFILE=$5      ; : ${HACFGFILE:="/etc/hapf21.d/ICertifier-ha.cfg"}
export -p SHELLOG=${INSTDIR}/${MYSELF}.${ROLE}.${NOW}.shell.log
shf_set_index

shf_logit "using Role $ROLE in here, configure index $X"
shf_logit "${NOW} using ARGS: `echo $*`"
shf_logit "creating file to log command outputs: ${SHELLOG}"

cat /dev/null > ${SHELLOG}
echo "starting shellog for ${NOW} ${MYSELF} `date`" &>> ${SHELLOG}
set &>> ${SHELLOG}
echo "=======================================================================" &>> ${SHELLOG}
#------------------------------------------------------------------------------
#
: ${MTDIR:="/media"}
: ${CARIER:="$(shf_usbdsk)"}
ensure_usbmount() {
	local rc=1
	MYCARIER="$(shf_usbdsk)" &&
	MYMPOINT="$(cat /proc/mounts|awk -v P="${MYCARIER}" '($1==P){print$2}')"

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
	else
		rc=0
	fi

	echo ${MYMPOINT}
	return $rc
}
#------------------------------------------------------------------------------
# since pacemaker 1.1.8 we get this error about a directory missing so lets simply create it
MISSDIR="/var/lib/pacemaker/cores/root"
if [ ! -d "${MISSDIR}" ] ; then
	mkdir -p ${MISSDIR} &>/dev/null
	chown root:root ${MISSDIR}
	chmod 750 ${MISSDIR}
	shf_logit "created directory \"${MISSDIR}\" to stop pacemaker 1.1.8 from complaining"
fi
#------------------------------------------------------------------------------
RANAM="ICertifier"
RADIR="/usr/lib/ocf/resource.d/nsn"
FILE=${RADIR}/${RANAM}

mkdir ${RADIR} && sync &&
chown root:root ${RADIR}
chmod 755 $RADIR
shf_logit "created directory for NSN resource agent: \"$(ls -dl ${RADIR})\""

if [ -r ${INSTDIR}/insta/${RANAM} ]
then
	rm -f ${FILE}
        cp -f ${INSTDIR}/insta/${RANAM} ${FILE}
	sync &&
        chmod 0755 ${FILE}
        chown root:root ${FILE}
        shf_logit "copied resource agent into place: \"$(ls -la ${FILE})\""
        chcon -R -h system_u:object_r:lib_t:s0 ${FILE}
        shf_logit "changed security context to that of general lib: \"$(ls -Z ${FILE}|tr --squeeze-repeats ' ')\""
else
        shf_logit "can not find resource agent script - Installation will NOT be successfull"
fi

###############################################################################
RANAM="IPaddr2a"
RADIR="/usr/lib/ocf/resource.d/nsn"
FILE=${RADIR}/${RANAM}
cp -f ${INSTDIR}/insta/${RANAM} ${FILE}
chmod 0755 ${FILE}
shf_logit "copied modified \"IPaddr2\" resource agent into place: \"`ls -la ${FILE}`\""
chcon -R -h system_u:object_r:lib_t:s0 ${FILE}
shf_logit "custom correction to IPaddr2 RA will be applied"
#------------------------------------------------------------------------------

if [ ! -z "${OAMHAIP[$X]}" ] && [[ "${ROLE}" = "be"[1,2] ]]
then
	FILE="${HACFGFILE}"
	if [ ! -z "${HACFGFILE}" ]
	then
		echo "REBIND_IP_COMMAND[0]=\"service sshd restart\"" >> ${FILE}
		shf_logit "OAMHAIP \"${OAMHAIP[$X]}\" is used - adding REBIND_IP_COMMAND[0] for sshd"
		chown root:root ${FILE}
		chmod 0600 ${FILE}
	else
		shf_logit "WARNING: you have defined OAMHAIP but HACFGFILE is not set in metaenv"
		shf_logit "WARNING: this means your sshd will not rebind to the OAMHAIP after cluster failover"
		shf_logit "WARNING: maybe your mkks macro and excel sheet do not match versions"
	fi
fi
#------------------------------------------------------------------------------
CORCFDIR="/etc/corosync"
#------------------------------------------------------------------------------

if [ ${ROLE} = "be1" -o ${ROLE} = "fe1" -o ${ROLE} = "fe3" ] 
then
	FILE=${CORCFDIR}/corosync.conf
	shf_logit "creating config $FILE"

	HBNET=`ipcalc -n ${HBIPADDR[$X]} ${HBIPMASK[$X]}|cut -d'=' -f 2`
	shf_logit "using ${HBIPADDR[$X]} ${HBIPMASK[$X]} for net ${HBNET} for primary HA link"
	SBNET=`ipcalc -n ${IPADDReth0[$X]} ${NETMASKeth0[$X]} |cut -d'=' -f 2`
	shf_logit "using ${IPADDReth0[$X]} ${NETMASKeth0[$X]}  for net ${SBNET} for secondary HA link"

	shf_tag_cffile ${FILE} "no-backup"
	cat <<-EOCORO >>$FILE
		compatibility: whitetank
		totem {
		               version: 2
		               rrp_mode: passive
		               secauth: off
		               threads: 0
	                       interface {
		                            ringnumber: 0
		                            bindnetaddr: ${HBNET}
		                            mcastaddr: ${HBMCADDR[$X]}
		                            mcastport: ${HBMCPORT[$X]}
		               }
		               interface {
		                            ringnumber: 1
		                            bindnetaddr: ${SBNET}
		                            mcastaddr: ${HBMCADDR[$X]}
		                            mcastport: ${HBMCPORT[$X]}
		               }

		}
	
		logging {
		               fileline: off
		               to_stderr: yes
		               to_logfile: yes
		               to_syslog: yes
		               logfile: /var/log/corosync.log
		               debug: off
		               timestamp: on
		               logger_subsys {
		                            subsys: AMF
		                            debug: off
		               }
		}
		amf {
		                mode: disabled
		}
		aisexec {
		                user: root
		                group: root
		}
		service {
		                # Load the Pacemaker Cluster Resource Manager
		                name: pacemaker
		                ver:  0
		}
	EOCORO

	chown root:root /etc/corosync/corosync.conf
	chmod 0644 /etc/corosync/corosync.conf
	shf_logit "`cat ${FILE}|wc -l` lines as : `ls -la ${FILE}`"
	shf_fshow ${FILE}
	ln -s /var/log/corosync.log /tmp/corosync.log ; sync && sleep 1
	shf_logit "linked default location in /tmp corosync log from \"$(ls -l /tmp|grep corosync|awk '{print $10" " $11" "$12}')\""
#-----------------------------------------------------------------------------
#============================================================================== 
# 
	FILE="${CORCFDIR}/authkey"

	shf_logit "creating authentication key file ${FILE}... be patient ..."
	shf_fast_entropy on &&
	/usr/sbin/corosync-keygen && sleep 1 && sync
	shf_fast_entropy off &&

	chown root:root ${FILE}
	chmod 0400      ${FILE}
	shf_logit "generated keyfile : \"`ls -la ${FILE}`\""
	shf_fshow ${FILE}	

	CHKSUM=${FILE}-"`md5sum $FILE|awk '{print$1}'`"
	touch ${CHKSUM}
	chown root:root ${FILE}
	chmod 0400      ${FILE}
        shf_logit "key checksum file : \"`ls -la ${CHKSUM}`\""
	shf_fshow ${CORCFDIR}
#-----------------------------------------------------------------------------
	shf_logit "prepare transfer of configuration and authkey to HA peer ${HBIPADDR[$Y]}"

	CARCH="${INSTDIR}/coroconfig.${HBIPADDR[$X]}.${NOW}.tar"

	tar -Ppcf ${CARCH} ${CORCFDIR} && sync &&
	shf_fshow tar -tf ${CARCH}
	shf_logit "preserved config in archive : \"`ls -la ${CARCH}`\""
	
	if [ "${REMOTE_INSTALL[$X]}" = "no" ] && [ ! -z "${CARIER}" ] 
	then
		MPOINT="$(ensure_usbmount)"
		rm -f ${MPOINT}/${CARCH} 2>/dev/null
		cp -f ${CARCH} ${MPOINT}/
		shf_fshow  ${MPOINT}/
		shf_logit "preserved config in archive : \"`ls -la ${CARCH}`\""
		shf_logit "will transport config in ${CARIER}: \"`ls ${MPOINT}|grep coroconfig|grep ${NOW}|grep ${HBIPADDR[$X]}`\""

	elif [ "${REMOTE_INSTALL[$X]}" = "yes" ]
	then
		shf_logit "remote install option in use - peer \"${HOSTNAME[$Y]}\" will fetch archive later via ssh"

	else
		shf_logit "ERROR: can not find USB device to copy config but local install chosen"
		shf_logit "WARNING: Will not be able to transport HA config to peer"
		shf_logit "WARNING: You will have to copy \"${CORCFDIR}\" manually"
		shf_logit "WARNING: Look for archive \"${CARCH}\""
	fi			
fi

#==============================================================================
# 
if [ ${ROLE} = "be2" -o ${ROLE} = "fe2" -o ${ROLE} = "fe4" ] 
then
	MPOINT="$(ensure_usbmount)"
	CARCH="${MPOINT}/coroconfig.${HBIPADDR[$Y]}.${NOW}.tar"
	MYARCH=`basename ${CARCH}`

	unpack() {
		if [ -r ${INSTDIR}/${MYARCH} ]
		then
			tar -Ppxf ${INSTDIR}/${MYARCH}
			if [ $? -eq 0 ]
                	then
				shf_logit "unpacked archive \"`ls -la ${INSTDIR}/${MYARCH}`\""
				shf_fshow tar -tf ${INSTDIR}/${MYARCH}
			else
				shf_logit "WARNING: I found the archive but could not unpack it"
				shf_logit "WARNING: Archive on local disk \"$(ls -la ${INSTDIR}/${MYARCH})\""
                	fi
		else
			shf_logit "ERROR: nothing to unpack - there is no archive \"${INSTDIR}/${MYARCH}\""
		fi
	}
	#---------------------------------------------------------------------

	if [ "${REMOTE_INSTALL[$X]}" = "no" ] && [ ! -z "${CARIER}" ]
	then
		shf_logit "local-install option is chosen, transfer corosync-config via USB stick"
		shf_logit "Archive on USB drive  \"$(ls -la ${MPOINT}/coroconfig.${HBIPADDR[$Y]}.${NOW}.tar)\""
		rc="$(cp -p ${CARCH} ${INSTDIR}/)$?" && sync &&
		shf_logit "archive copied \"$(ls -la ${INSTDIR}/${MYARCH})\""

		if [ -s "${INSTDIR}/${MYARCH}" ] && [ -e "${INSTDIR}/${MYARCH}" ]; then
			unpack
		elif [ ! -s "${INSTDIR}/${MYARCH}" ]; then
			shf_logit "WARNING: Archive on local disk has zero size \"$(ls -la ${INSTDIR}/${MYARCH})\""
		elif [ -s "${CARCH}" ] && [ -e "${CARCH}" ]; then
			shf_logit "WARNING: Problem with the file on USB: \"$(ls -l ${CARCH})\""
		else
			shf_logit "WARNING: could not copy archive \"${CARCH}\" into \"${INSTDIR}\" got exit \"${rc}\" from cp"
		fi

	elif [ "${REMOTE_INSTALL[$X]}" = "yes" ] && ( ping -I ${IPADDReth0[$X]} -n -c 5 -q ${IPADDReth0[$Y]} )
	then
		shf_logit "remote-install option is chosen, fetching corosync-config via ssh"
		cd ${INSTDIR}
		rc=$(scp -o PasswordAuthentication=no root@${IPADDReth0[$Y]}:${INSTDIR}/${MYARCH} . )$?
		[ ${rc} -ne 0 ] && shf_logit "problem occurred while fetching corosync config from \"root@${IPADDReth0[$Y]}:${INSTDIR}/${MYARCH}\""
		unpack

	else
		shf_logit "WARNING: Problem with specified installation method "
		shf_logit "WARNING: must mount \"${CARIER}\" on \"${MPOINT}\" for this step in local install."
		shf_logit "WARNING: or must have connection on eth0 \"${IPADDReth0[$X]}\" and \"${IPADDReth0[$Y]}\" for remote install"
		shf_logit "WARNING: You will have to copy and unpack \"${CARCH}\" manually among peers"
	fi

        ln -s /var/log/corosync.log /tmp/corosync.log ; sync && sleep 1
        shf_logit "linked default location in /tmp corosync log from \"$(ls -l /tmp|grep corosync|awk '{print $9" " $10" "$11}')\""
fi
#

#==============================================================================
WAIT="3"
shf_logit "starting cluster with empty config and sleeping \"${WAIT}\""
	/etc/init.d/corosync restart &>/dev/null && rc=$?
	sleep ${WAIT}
	if [ $rc -ne 0 ] ; then
		shf_logit "WARNING: problem while trying to start corosync got return \"${rc}\" from init script"
		shf_fshow echo "exception testing"
		shf_fshow ps -ef
		shf_fshow tail -n 80 /var/log/messages
		shf_fshow df -h
		shf_fshow du -h --max-deepth=1 /
		shf_fshow du -h --max-deepth=1 /tmp/Installmedia
	fi
shf_logit "corosync init script shows exit \"${rc}\""
COROPID=$(pidof corosync)
COROKID=$(ps --no-headers --ppid ${COROPID}|wc -l)
shf_logit "started corosync with PID ${COROPID}, process having ${COROKID} of 6 childs"
if [ ${COROKID} != "6" ] ; then
	shf_logit "WARNING: there seems to be a mismatch in the number of pacemaker daemons - it should be 6"
fi

#==============================================================================
#  http://www.gossamer-threads.com/lists/linuxha/pacemaker/65928
#
#  monitor timings below are subject to tuning on the target hardware
#  database size and corruption status might also make a big difference
#  -------------------------------------------------------------------
#  : ${DRBDRES:="certifier"}  ;  : ${DRBDDIR:="/usr/local/certifier"}  ; : ${DRBDDEV:="/dev/drbd1"}
   : ${SERVRES:="certifsub"}  ;  : ${SERVDIR:="/usr/local/certifsub"}
#
#
#  
#       monitor-interval  monitor-timeout   startup-timeout     stopdown-timeout
        DRMINT="30"    ;  DRMAINT="10"   ;  DRUTO="240"    ;    DRDTO="100"                  # drbd (see DRSM)
        FSMINT="65"    ;  FSMTO="30"     ;  FSUTO="60"     ;    FSDTO="60"                   # filesystem
        ENGMINT="90"   ;  ENGMTO="30"    ;  ENGUTO="90"    ;    ENGDTO="120"                 # certifier be services
        SRVMINT="60"   ;  SRVMTO="30"    ;  SRVUTO="60"    ;    SRVDTO="90"                  # certifier fe service
        IFMINT="60"    ;  IFTO="20"      ;                                                   # LAN interfaces / VLANs
#  --------------------------------------------------------------------------------------------------------------------
	IFFTO="300"  ;  BEFTO="600"  ;  FEFTO="300"        # Cluster failure timeouts

        let DRMS=${DRMINT}+5 ; let DRMM=${DRMINT}-5        # to not check slave/master at exactly the same moment
#
#==============================================================================
#
if [ ${ROLE} = "be2" -o ${ROLE} = "fe2" -o ${ROLE} = "fe4" ]
then
	if ( ping -I ${HBIPADDR[$X]} -n -c 5 -q ${HBIPADDR[$Y]} &>> ${SHELLOG}  )
        then
        	shf_logit "HA peer host \"${HBIPADDR[$Y]}\" seems to be reachable via \"${HBIPADDR[$X]}\" - good" 
	else
                shf_logit "WARNING: HA peer IP \"${HBIPADDR[$Y]}\" unreachable via \"${HBIPADDR[$X]}\" -  thats bad"
        fi

	shf_logit "creating actual pacemaker configuration: global parameters. Give it some time "
#	
#       -----------------------------------------------------------------------
#       Cluster global settings  
#       -----------------------------------------------------------------------
#
	shf_crm configure property no-quorum-policy="ignore"
	shf_crm configure property stonith-enabled="false"
#	shf_crm configure rsc_defaults resource-stickiness=100

#
#       -----------------------------------------------------------------------
#       IP address related settings
#       -----------------------------------------------------------------------

	shf_logit "creating HA virtual IP addresses per VLAN - only 1 HA IP per VLAN allowed"
	shf_wrap_vlans ; unset ALL_USED_VLANS
	[[ "${ROLE}" == "be"[1,2] ]] && let n=0
	[[ "${ROLE}" == "fe"[1-4] ]] && let n=1
#
	unset OAMNIC
	while [ ! -z "${VLAN[$n]}" ]
	do
		shf_logit "working on parameter set \"${VLAN[$n]}\""
		MYVLAN=( `echo ${VLAN[$n]}` )
		ID=${MYVLAN[0]} ; IP=${MYVLAN[1]} ; MASK=${MYVLAN[2]} ; VIP=${MYVLAN[3]}
		CIDR="$( ipcalc -p ${IP} ${MASK}|awk -F'=' '{print$2}' )"

		if [ -z "`echo ${ID}|sed 's/[0-9]//g'`" ]
		then
			shf_logit "add-to-cluster request for logical network resource: VLAN ID \"${ID}\""
			
			CFDIR="/etc/sysconfig/network-scripts" &&
			VLFL="`find ${CFDIR} -name ifcfg-bond\[0-9]*.${ID}`" &&
			BOND="`echo ${VLFL}|cut -d- -f3|cut -d. -f1`" && sync

			if [ ! "`echo ${BOND:0:4}`" = "bond" ] || [ ! -z "`echo ${BOND:4}|tr -d '[0-9]'`" ]
			then
				shf_logit "ERROR: can not find bonding device for VLAN ${ID}"
			else
				shf_crm configure primitive "vl${ID}" ocf:nsn:IPaddr2a params ip="${VIP}" nic="${BOND}.${ID}:0" cidr_netmask="${CIDR}"
				shf_crm configure monitor vl${ID} ${IFMINT}s:${IFTO}s
				shf_crm resource meta vl${ID} set failure-timeout ${IFFTO}
				: ${OAMNIC:="${BOND}.${OAMVLANID[$X]}"}
			fi	

			ALL_USED_VLANS="`echo ${ALL_USED_VLANS} vl${ID}||sed 's/ *$//g ;s/^ *//g'`"
			
			

		elif [ "`echo ${ID:0:3}`" = "eth" ] && [ -z "`echo ${ID:3}|tr -d '[0-9]'`" ]
		then
			: ${OAMNIC:="eth0"}
			shf_logit "cluster add-request for physical network resource i/f: \"${ID}\""
			shf_crm configure primitive "ph${ID}" ocf:nsn:IPaddr2a params ip="${VIP}" nic="${ID}" cidr_netmask="${CIDR}"
			shf_crm configure monitor ph${ID} ${IFMINT}s:${IFTO}s
			shf_crm resource meta ph${ID} set failure-timeout ${IFFTO}
			ALL_USED_VLANS="${ALL_USED_VLANS} ph${ID}"
		fi
		
		let n=$n+1
	done	

	if [ ! -z "${OAMHAIP[$X]}" ] && [ ! -z "${OAMNIC}" ] && [[ "${ROLE}" == "be"[1,2] ]]
	then
		OAMASK="$( ipcalc -p ${OAMHAIP[$X]} ${OAMNETMASK[$X]}|awk -F'=' '{print$2}' )"
		shf_logit "highly available oam ip \"${OAMHAIP[$X]}/${OAMASK} in ${OAMNIC}\""
		shf_crm configure primitive "oamIP" ocf:nsn:IPaddr2a params ip="${OAMHAIP[$X]}" nic="${OAMNIC}" cidr_netmask="${OAMASK}"
		shf_crm configure monitor "oamIP"  ${IFMINT}s:${IFTO}s
		shf_crm resource meta oamIP set failure-timeout ${IFFTO}

		ALL_USED_VLANS="`echo ${ALL_USED_VLANS} oamIP ||sed 's/ *$//g ;s/^ *//g'`"
	fi
	
        shf_logit "pacemaker config for ${ROLE} will include network resources ${ALL_USED_VLANS}"

fi
#==============================================================================
#
if [[ "${ROLE}" == "fe"[1,2,3,4] ]]; then
	FILE="${HACFGFILE}"
	shf_tag_cffile ${FILE} "no-backup"
	chmod 0644 ${FILE}
	chown root:root ${FILE}
	shf_logit "created empty RA configuration in \"$(ls -l ${FILE}|tr --squeeze-repeats ' '\")" 
fi

if [ ${ROLE} = "be2" ]
then
#
#       -----------------------------------------------------------------------
#       Backend functions 
#       -----------------------------------------------------------------------

	shf_logit "configuring DRBD resources for ${DRBDRES}"

        shf_crm configure primitive drbd_${DRBDRES} ocf:linbit:drbd params drbd_resource="$DRBDRES" op start interval="0" timeout="${DRUTO}s" op stop interval="0" timeout="${DRDTO}s" op monitor role=Master interval="${DRMM}s" op monitor role=Slave interval="${DRMS}s"
        shf_crm configure ms ms_${DRBDRES} drbd_${DRBDRES} meta master-max="1" master-node-max="1" clone-max="2" clone-node-max="1" notify="true"
        shf_crm configure primitive fs_${DRBDRES} ocf:heartbeat:Filesystem params device="${DRBDDEV}" directory="${DRBDDIR}" fstype="ext3" op start interval="0" timeout="${FSUTO}s" op stop interval="0" timeout="${FSDTO}s" op monitor interval="${FSMINT}s" timeout="${FSMTO}s"
	shf_crm resource meta ms_${DRBDRES} set failure-timeout ${BEFTO}
	shf_crm resource meta fs_${DRBDRES} set failure-timeout ${BEFTO}

	shf_crm configure primitive ${DRBDRES}_engine ocf:nsn:ICertifier params certifier_role="be" op monitor interval="${ENGMINT}s" timeout="${ENGMTO}s" op start interval="0" timeout="${ENGUTO}s" op stop interval="0" timeout="${ENGDTO}s"
	shf_crm resource meta ${DRBDRES}_engine set failure-timeout ${BEFTO}	

	shf_crm configure colocation fs_on_drbd inf: fs_${DRBDRES} ms_${DRBDRES}:Master
        shf_crm configure order fs_after_drbd inf: ms_${DRBDRES}:promote fs_${DRBDRES}:start
	
	shf_crm configure group G_${DRBDRES} fs_${DRBDRES} ${ALL_USED_VLANS} ${DRBDRES}_engine	
	shf_crm resource meta G_${DRBDRES} set failure-timeout ${BEFTO}
	shf_crm configure location prefer-be1 G_${DRBDRES} 100: ${HOSTNAME[$Y]}

	sleep 2

	shf_crm resource cleanup drbd_${DRBDRES}   
	shf_crm resource cleanup fs_${DRBDRES}
	shf_crm resource cleanup ${DRBDRES}_engine 
	
fi
if [[ ${ROLE} == "fe"[2,4] ]]
then
#
#       -----------------------------------------------------------------------
#       Frontend functions
#       -----------------------------------------------------------------------
#	http://oss.clusterlabs.org/pipermail/pacemaker/2011-October/011616.html
#
	shf_logit "configuring server resources for ${ROLE}"

	shf_crm configure primitive ${SERVRES}_server ocf:nsn:ICertifier params certifier_role="fe" op monitor interval="${SRVMINT}s" timeout="${SRVMTO}s" op start interval="0" timeout="${SRVUTO}s" op stop interval="0" timeout="${SRVDTO}s"	
	shf_crm configure clone ${SERVRES}_service ${SERVRES}_server meta clone-node-max="1" globally-unique="false" clone-max="2"

	shf_crm configure group G_${SERVRES} ${ALL_USED_VLANS} 
	shf_crm configure location prefer-fe1 G_${SERVRES} 100: ${HOSTNAME[$Y]}
	
	shf_crm resource meta ${SERVRES}_server set failure-timeout ${FEFTO}
	shf_crm resource meta G_${SERVRES} set failure-timeout ${FEFTO}
	
	shf_crm configure order rebind_service inf: G_${SERVRES}:start ${SERVRES}_service
fi
#==============================================================================
sleep 3 ; sync
if [ ${ROLE} != "SingleServer" ]; then 
	ISFILE="$(chmod 660 /var/lib/heartbeat/crm/cib-[1-9].raw.sig &>/dev/null)$?"
	          chmod 660 /var/lib/heartbeat/crm/cib-[1-9].[0-9].raw.sig &>/dev/null

	[ "${ISFILE}" = "0" ] && shf_logit "corrected odd a+w permissions in /var/lib/heartbeat/crm" 
fi
#==============================================================================
shf_logit "#-----------------------------------------------------------------"
shf_logit " Leaving  script ${MYSELF} "
shf_logit "#-----------------------------------------------------------------"
