#!/bin/bash
###########################################################################
# NSN INSTA HAPF2.1 RAPID SETUP CONFIG GENERATOR SCRIPT
#--------------------------------------------------------------------------
# Script default name   : ~script/config_hsm.sh
# Configure version     : mkks62f.pl
# Media set             : PF21I52RH63-12
# File generated        : 03.01.2013 MPe
#
###########################################################################
export -p  MYSELF="config_hsm.sh"
#
if [ "`whoami`" != "root" ]
then
        logger -p user.info -t ${MYSELF} "attempt to run hsm-setup as \"`whoami`\" was rejected"
        echo "only root is allowed to install and configure hsm modules"
        exit 1
fi
#----------------------------------------------------------------------------------
myexit() { 
	if [ "${EXITYPE}" = "soft" ]  
	then
		return $1 
	else
		kill -TERM $$ &>/dev/null	
	fi
}
shf_say() {
        HMS=$(date  +%H:%M:%S)
        HST=$(uname -n)
        MSG="$*"

        TEXT="[${HMS}][${HST}] : ${MSG}"
        echo ${TEXT}
	[ "${NOPHASE}" = "no" ] && shf_logit "${MSG}" &>/dev/null
}
#--------------------------------------------------------------------------------
usage() {
	echo "Tool to install HSM Software and activate HSM Supervision on HAPF2.1"
	echo "Interactive use only allows 3 options:"
	echo
	echo "-installsw [ARCHIVE]"
	echo "Will install HSM SW from tar-file [ARCHIVE] and start the SW"
	echo
	echo "-activate"
	echo "Will activate previously installed SW for supervision by HAPF2.1"
	echo "This is only possible if the SW is properly installed, processes"
	echo "running and the HSM is in a proper state of operation"
	echo
	echo "-deactivate"
	echo "Will deactivate HSM supervision in the engine.conf immediately and "
	echo "regardless of the hsm status"
	echo
	echo "-init_rfs"
	echo "Will only initialize hsm synchronisation via rfs-sync. Cronjobs are"
	echo "not added by this tool but should be added by hapf21 platform."
	echo
	echo "example:"
	echo " ./config_hsm.sh -installsw /media/localfile.tar -activate"
	echo
	echo "A PROPER STATE OF OPERATION FOR THE HSM:"
	echo "- HSM nfp driver loaded"
	echo "- hardserver process running"
	echo "- configured operator card in reader"
	echo ; echo
	myexit 1
}

#--------------------------------------------------------------------------------
setup_rfs-sync() {
	local ROLE=$1
	local rc=5
	
	[[ "${ROLE}" == "be"[1,2] ]] || return 0
	if ( ping  -q -c 2 ${HARDSER_BIND_IP[$Y]} ) ; then
		rc="$(exec 5<>/dev/tcp/${HARDSER_BIND_IP[$Y]}/${HARDSER_PORT[$Y]} &>/dev/null)$?"; 5<&-; 5>&-
	fi

	if [ "${rc}" -eq "0" ] 
	then
		st1="$(${HSMDIR}/bin/rfs-setup --gang-client --write-noauth ${HARDSER_BIND_IP[$Y]} &>/dev/null)$?"
		st2="$(${HSMDIR}/bin/rfs-sync --setup -p ${HARDSER_PORT[$Y]} --no-authenticate ${HARDSER_BIND_IP[$Y]} &>/dev/null)$?"
	else
		if [ "${ROLE}" = "be2" ]  ; then
			shf_say "ERROR: configuration of rfs-sync not possible, can not reach \"${HARDSER_BIND_IP[$Y]}:${HARDSER_PORT[$Y]}\""
			shf_say "ERROR: try to troubleshoot networking between \"${HBIF[$X]}\" interfaces on Layer 3"
			shf_say "ERROR: use \"${MYSELF} -init_rfs\" to initialize rfs-sync when both BEs are available"
		elif [ "${ROLE}" = "be1" ] && [ "${INSTALL}" = "yes" ]; then
			shf_say "WARNING: rfs peer \"${HARDSER_BIND_IP[$Y]}:${HARDSER_PORT[$Y]}\" not available yet"
		else
			shf_say "ERROR: \"${HARDSER_BIND_IP[$Y]}:${HARDSER_PORT[$Y]}\" unreachable at this moment"
			shf_say "ERROR: use \"${MYSELF} -init_rfs\" to initialize rfs-sync when both BEs are available"
			st="99"
		fi
	fi

	st=( $st1 ) || ( $st2 )
	shf_say "initialization of cross-rfs-sync ended with exit \"${st}\""
	${HSMDIR}/scripts/init.d/hardserver restart
	rc=$?; shf_say "restarting nfast hardserver ended with exit \"${rc}\""
}

#--------------------------------------------------------------------------------
build_hsm_config_files() {

        HARDSERCONF="${HSMDIR}/kmdata/config/config"
        NFASNMPCONF="${HSMDIR}/etc/snmp/snmpd.conf"

        cp -f ${HARDSERCONF}  ${HARDSERCONF}.${ROLE}.${NOW}.dist
        mv -f ${HARDSERCONF}  ${BACKDIR}/$(basename ${HARDSERCONF}).${ROLE}.${NOW}.dist
        shf_tag_cffile "${HARDSERCONF}" "no-backup" &>/dev/null
        sed -i "1 i syntax-version=1" ${HARDSERCONF}

        : ${HARDSER_BIND_IP[$X]:="INADDR_ANY"}
        : ${HARDSER_PORT[$X]:="9004"}

	cat <<-HARDS >> ${HARDSERCONF}
		[server_settings]
		loglevel=warning
		logdetail=FLAGS
		connect_retry=30
		connect_keepalive=10
		connect_broken=180
		#
		[server_remotecomms]
		impath_port=${HARDSER_PORT[$X]}
		impath_addr=${HARDSER_BIND_IP[$X]}
		#
		[server_startup]
		unix_socket_name=/dev/nfast/nserver
		unix_privsocket_name=/dev/nfast/priv/privnserver
		nonpriv_port=0
		priv_port=0
		#
		[nethsm_imports]
		#
		[load_seemachine]
		#
		[slot_imports]
		#
		[slot_exports]
		#
		[rfs_sync_client]
		#
		[remote_file_system]
		# this section will be added by rfs-setup tool
		# ---------------------------------------------------------------
	HARDS
	if [ "${ROLE}" != "SingleServer" ] 
        then
                echo "remote_ip=${HARDSER_BIND_IP[$Y]}" >> ${HARDSERCONF}
        fi
        chown nfast:nfast ${HARDSERCONF}
        chmod 0644 ${HARDSERCONF}
	shf_say "built hardserver config file \"$(ls -l ${HARDSERCONF})\""
        
        
        if [ "${SNMPENA[$X]}" = "yes" ] && [ "${HARDSER_SNMP_TRAP}" = "yes" ]
        then
                cp -f ${NFASNMPCONF}  ${NFASNMPCONF}.${ROLE}.${NOW}.dist
                mv -f ${NFASNMPCONF} ${BACKDIR}/$(basename ${NFASNMPCONF}).${ROLE}.${NOW}.dist &>/dev/null
                shf_tag_cffile "${NFASNMPCONF}" "no-backup" &>/dev/null

		cat <<-NFASNMP >> ${NFASNMPCONF}
			agentuser ncsnmpd
			agentgroup ncsnmpd
			syslocation ${SYSLOC[$X]}
			syscontact  ${SYSCON[$X]}
			trapcommunity ${SNMPV2COMMUNITY[$X]}
			trap2sink ${SNMPTRAPRCVIP[$X]}
		NFASNMP
		chown ncsnmpd:ncsnmpd ${NFASNMPCONF}
		chmod 644 ${NFASNMPCONF}
		shf_say "built nfast snmp config  \"$(ls -l ${NFASNMPCONF})\""
	fi
#---------------------------------------------------------------------------------------------------------

	NFINITSCR="${HSMDIR}/scripts/init.d/drivers"
	ln -s ${NFINITSCR} /etc/rc.d/init.d/nc_drivers
	LINE=2
	sed -i "${LINE} i # chkconfig: 345 45 55" ${NFINITSCR} ; let LINE=${LINE}+1
	sed -i "${LINE} i # description: NFAST PCIe 500 Solo nfp driver rc-init" ${NFINITSCR} ;  let LINE=${LINE}+1
	sed -i "${LINE} i NFAST_SERVERLOGLEVEL=notice" ${NFINITSCR} ; let LINE=${LINE}+1
	sed -i "${LINE} i export NFAST_SERVERLOGLEVEL" ${NFINITSCR} ; let LINE=${LINE}+1
	chkconfig --add nc_drivers
	chkconfig --level 0123456 nc_drivers off
	chkconfig --level 345 nc_drivers on
	shf_say "enabled rc-init control \"$(chkconfig --list nc_drivers|tr '\t' ' '| tr --squeeze-repeats ' ')\""

	NFINITSCR="${HSMDIR}/scripts/init.d/hardserver"
	ln -s ${NFINITSCR} /etc/rc.d/init.d/nc_hardserver 2>/dev/null
	LINE=2
	sed -i "${LINE} i # chkconfig: 345 50 50" ${NFINITSCR}; let LINE=${LINE}+1
	sed -i "${LINE} i # description: NFAST PCIe 500 Solo hardserver daemon" ${NFINITSCR};  let LINE=${LINE}+1
	chkconfig --add nc_hardserver
	chkconfig --level 0123456 nc_hardserver off
	chkconfig --level 345 nc_hardserver on
	shf_say "enabled rc-init control \"$(chkconfig --list nc_hardserver|tr '\t' ' '| tr --squeeze-repeats ' ')\""

	NFINITSCR="${HSMDIR}/scripts/init.d/ncsnmpd"
	ln -s ${NFINITSCR} /etc/rc.d/init.d/nc_ncsnmpd 2>/dev/null
	LINE=2
	sed -i "${LINE} i # chkconfig: 345 90 10" ${NFINITSCR}; let LINE=${LINE}+1
	sed -i "${LINE} i # description: NFAST PCIe 500 Solo hardserver daemon" ${NFINITSCR};  let LINE=${LINE}+1
	chkconfig --add nc_ncsnmpd
	chkconfig --level 0123456 nc_ncsnmpd off

        if [ "${SNMPENA[$X]}" = "yes" ] && [ "${HARDSER_SNMP_TRAP}" = "yes" ]
        then
		chkconfig --level 345 nc_ncsnmpd on
		shf_say "enabled rc-init control \"$(chkconfig --list nc_ncsnmpd|tr '\t' ' '| tr --squeeze-repeats ' ')\""
	else
		shf_say "nfast snmpd not started automatically: \"$(chkconfig --list nc_ncsnmpd|tr '\t' ' '| tr --squeeze-repeats ' ')\""
		service nc_ncsnmpd stop
	fi
#---------------------------------------------------------------------------------------------------------
	setup_rfs-sync ${ROLE}	
#---------------------------------------------------------------------------------------------------------

	LOGS="/var/log"
	PIDS="/var/run"
	DEFDIR="${HSMDIR}/log"
	: ${HSMDIR:="/opt/nfast"}

	mk_log() {
		local LOGFILE=$1	
		local LOGOWN=$2
		: ${LOGOWN:="root:root"}	

		if [ -f "${DEFDIR}/${LOGFILE}.log" ]; 
		then
			mv ${DEFDIR}/${LOGFILE}.log $LOGS
			shf_say "moved \"${LOGFILE}.log\" to \"$(ls -l ${LOGS}/${LOGFILE}.log)\""
		else
			touch ${LOGS}/${LOGFILE}.log			
			chown ${LOGOWN} ${LOGS}/${LOGFILE}.log
			chmod 0640 ${LOGS}/${LOGFILE}.log
			shf_say "created hsm log \"$(ls -l ${LOGS}/${LOGFILE}.log)\""
		fi
		ln -s ${LOGS}/${LOGFILE}.log ${DEFDIR}/${LOGFILE}.log
		shf_say "created log softlink for compatibility \"$(ls -l ${DEFDIR}|grep ${LOGFILE}.log|tr -s ' ')\""	
	}

	for HSMFIL in hardserver ncsnmpd rfs-sync
	do
		ln -s ${DEFDIR}/${HSMFIL}.pid ${PIDS}/${HSMFIL}.pid
		shf_say "created pidfile softlink for compatibility \"$(ls -l ${DEFDIR}|grep ${LOGFILE}.pid|tr -s ' ')\""
		mk_log ${HSMFIL} 
	done

#---------------------------------------------------------------------------------------------------------

	BUCONF="${HAPFCF}/hapf2-backup"
	
	if [ ! -f "${BUCONF}" ]; then
		touch ${BUCONF}
		echo "# configuration file for daily backup - additional files"
		chown root:root ${BUCONF}
		chmod 0640 ${BUCONF}
		shf_say "created config file for custom backup \"$(ls -l ${BUCONF}|tr -s ' ')\""
	fi
	
	if [ -f "${BUCONF}" ] && [ ! -w "${BUCONF}" ]; then
		shf_say "WARNING: can not write into \"$(ls -l ${BUCONF})\""
		shf_say "WARNING: add hsm security worlds manually to the backup definition"
		shf_say "WARNING: ... and dont forget to add the certifier PINS file as well"
		return 1
	fi

	if [ -f "${BUCONF}" ] && [ -w "${BUCONF}" ]; then
		cat <<-BUFIL >> ${BUCONF}
		        ${HSMDIR}/kmdata
		        /usr/local/certifier/var/pins
			/usr/local/certifier/acl
		BUFIL
	fi
}
#--------------------------------------------------------------------------------

####################################################################################################
#----------------------------------------------------------------------------------
####################################################################################################
shf_set_index &>/dev/null
NOPHASE="no";NUMARGS="$#" ; ALLARGS="$*"
shf_say "#-----------------------------------------------------------------"
shf_say "starting to run script ${MYSELF}"
shf_say "#-----------------------------------------------------------------"
unset NOPHASE ACTIVATE INSTALL HSMSW HSMARC HSM_SW_ARC DEACT ENGCONF
while [ $# != 0 ]
do
	case $1 in
		be1|be2|SingleServer)
			ROLE=$1; NOPHASE="no"; EXITYPE="soft"
			if [ "${USE_HSM[$X]}" = "yes" ] && [ "${NUMARGS}" -eq 1 ] ; then
				INSTALL="yes"; 	ACTIVATE="yes"
			elif [ "${USE_HSM[$X]}" = "no" ] && [ "${NUMARGS}" -eq 1 ] ;  then
				shf_say "hsm option disabled for $1"
			else
				shf_say "Role specific involvement only works during HAPF2.1 rapid setup - exiting"
				logger -p user.info -t ${MYSELF} "attempt to run hsm-setup in role mode rejected"
				exit 1
			fi
		;;
		fe1|fe2|fe3|fe4)
			shf_say "no hsm option at all possible for FE role - so please dont worry ..."
			ROLE=$1; NOPHASE="no" ; ACTIVATE="no" ; INSTALL="no" ; EXITYPE="soft"
		;;
		-installsw)
			NOPHASE="yes";	INSTALL="yes"; EXITYPE="hard"; HSMSW=$2 	
			[ -z ${HSMSW} ] && HSMSW="$(pwd)"
			HSMSW="$(readlink -f ${HSMSW})"
			shift
		;;
		-activate)
			NOPHASE="yes";  ACTIVATE="yes"; EXITYPE="hard"
		;;
		-deactivate)
			NOPHASE="yes"; EXITYPE="hard"; DEACT="yes"
		;;
		-init_rfs)
			NOPHASE="yes"; EXITYPE="hard"; setup_rfs-sync ${ROLE}
		;;
		*)
			usage
		;;
esac; shift; done
#---------------------------------------------------------------------------------
# MedSet 12 - July 2013:
HSMDIR="/opt/nfast" ; export -p HSMDIR
KNVERS=$(uname -r)
TARFILE="opt_nfast-${KNVERS}.tar.gz"
PKCSDRIVER="${HSMDIR}/toolkits/pkcs11/libcknfast.so"
#----------------------------------------------------------------------------------
NOTARED="$(echo ${TARFILE}|sed 's/.gz$//;s/.tgz$//;s/.tar$//;s/.$//')"

if [ "${NOPHASE}" = "yes" ] ; then
        : ${MAINFLAG:="/etc/hapf21.flag"}
        if [ ! -f ${MAINFLAG} ]
        then
                echo "not a complete HAPF20 installation"
                logger -p user.info -t ${MYSELF} "ERROR: stopping attempt to install hsm in incomplete environment"
                myexit 2
        else
                source ${MAINFLAG}
                ROLE="${GENROLE}"
		for PHASE1 in ${RUN[@]} ;do source ${PHASE1} ; done
		shf_say "sourced HAPF21 environment for ${ROLE} of installation ${NOW}"
        fi
fi
#----------------------------------------------------------------------------------
if [ "${INSTALL}" = "yes" ] && [ "${NOPHASE}" = "yes" ] && [ -e ${HSMSW} ] 
then
	if [ -d ${HSMSW} ]
	then
		ARCS="$(ls -A ${HSMSW}|egrep -i ".tar.gz$|.tgz$|.tar$"|grep ${NOTARED}|wc -l)"
		if [ "${ARCS}" -gt 1 ] ; then  shf_say "ambigious arguments dont know which archive to use -exiting " ; myexit 1; fi
		if [ "${ARCS}" -eq 0 ] ; then  shf_say "no tar archives found in \"${HSMSW}\" - nothing to install" ; myexit 1; fi

		HSM_SW_ARC="$(ls ${HSMSW}|egrep -i ".tar.gz$|.tgz$|.tar$"|grep ${NOTARED})"
		if [ -z "${HSM_SW_ARC}" ]
		then 
			shf_say "ERROR: Can not find HSM drivers in ${HSMSW}"
			myexit 1
		fi

	elif [ -f ${HSMSW} ] && [ "$(ls ${HSMSW}|egrep -i ".tar.gz$|.tgz$|.tar$"|grep ${NOTARED}|wc -l)" -eq 1 ]
	then
		HSM_SW_ARC="$(basename ${HSMSW})"
		HSMSW="$(dirname ${HSMSW})"
	fi

elif [ "${INSTALL}" = "yes" ] && [ "${NOPHASE}" = "yes" ] && [ ! -e ${HSMSW} ] 
then
	shf_say "ERROR: can not find driver software in ${HSMSW}" 
	myexit 1 
fi
####################################################################################################
####################################################################################################
export -p SHELLOG=${INSTDIR}/${MYSELF}.${ROLE}.${NOW}.shell.log
shf_set_index
#
shf_say "Using Role $ROLE in here, configure index $X"
shf_say "${NOW} using ARGS: ${ALLARGS}"
shf_say "creating file to log command outputs: ${SHELLOG}"
#
cat /dev/null > ${SHELLOG}
echo "starting shellog for ${NOW} ${MYSELF} `date`" &>> ${SHELLOG}
set &>> ${SHELLOG}
echo "====================================================================================" &>> ${SHELLOG}
#
if [ "${DEACT}" != "yes" ]; then
	shf_say "hsm install script for ${ROLE} having NOPHASE=\"${NOPHASE}\" INSTALL=\"${INSTALL}\" ACTIVATE=\"${ACTIVATE}\""
else
	shf_say "hsm install script for ${ROLE} going to deactivate hsm supervision"
fi
#
if [ "${INSTALL}" = "yes" ]; then
#=========================================================================================
	[ ! -d "${HSMDIR}" ] && ( mkdir ${HSMDIR} ; shf_say "created hsm directory \"$(dir -dl ${HSMDIR})\"")
	HSMUSR="nfast"    ; ID1="503"
	SNMPUSR="ncsnmpd" ; ID2="504"
	: ${HSMSW:=${INSTDIR}/hsmsw}
	: ${HSM_SW_ARC:="${TARFILE}"}
#
	shf_say "install drivers using archive ${HSM_SW_ARC} in directory ${HSMSW}"

	if [ ! -f ${HSMSW}/${HSM_SW_ARC} ] ; then shf_say "ERROR: can not find hsm drivers ${HSM_SW_ARC}"; myexit 3; fi
	if [ "$(ls ${HSMSW}|egrep -i ".tar.gz$|.tgz$"|grep ${NOTARED}|wc -l)" -eq 1 ] ; then
		(gunzip ${HSMSW}/${HSM_SW_ARC} &>/dev/null)
		HSM_SW_ARC="${TARFILE%.*}"
	fi
	rc="$(tar -xvf ${HSMSW}/${HSM_SW_ARC} -C ${HSMDIR}/.. &>> $SHELLOG)$?"
	shf_say "untar of hsm drivers arc \"$( ls -l ${HSMSW}/${HSM_SW_ARC})\" exited with \"${rc}\""
	gzip -9  ${HSMSW}/${HSM_SW_ARC} &>/dev/null

	[ $(ls ${HSMSW}/pciutil*  2>/dev/null) ] && NUMFIL="$(ls ${HSMSW}/pciutil*|wc -l  2>/dev/null)"
	if [ "${NUMFIL}" = "1" ] 
	then  
		rpm -Uvh ${HSMSW}/pciutil* &>>${SHELLOG} 
		shf_say "installation of pci utilities: \"$(rpm -q pciutils)\""
	elif [ ! -x "$(which lspci 2>/dev/null)" ]
	then
		shf_say "WARNING: can neither install nor find lspci utility - no possibility to probe hsm card"
	fi
#
#--------------------------------------------------------------------------------------
#
	if ( ! id ${HSMUSR} &>/dev/null ) ; then
		useradd -d ${HSMDIR} -u ${ID1} -c "Thales NCipher PCIe" -s /bin/bash ${HSMUSR} &>/dev/null
		for UDEFLT in $(ls -A /etc/skel); do rm -f ${HSMDIR}/${UDEFLT} &>/dev/null ; done
		chown -R ${HSMUSR}:${HSMUSR} ${HSMDIR}
		shf_say "created user: \"$(cat /etc/passwd|grep ${HSMUSR})\""
	else
		ID1="$(id -g ${HSMUSR})"
	fi
#
	: ${CUSER="certfier"}
	if ( id certfier >/dev/null ) ; then
		unset GLIST
		GRPS="$(id -G ${CUSER}|tr ' ' ',')"
		usermod -G ${GRPS},${ID1} ${CUSER}
		shf_say "added ${CUSER} to group: \"$(cat /etc/group|grep ${ID1}|grep ${CUSER})\""
	fi
#
	if ( ! id ${SNMPUSR} &>/dev/null ) ; then
		useradd -d ${HSMDIR} -u ${ID2} -c "Thales NCipher SNMP daemon" -s /bin/bash ${SNMPUSR} &>/dev/null
		for UDEFLT in $(ls -A /etc/skel); do rm -f ${HSMDIR}/${UDEFLT} &>/dev/null ; done
		shf_say "created user: \"$(cat /etc/passwd|grep ${SNMPUSR})\""
	fi
#
#--------------------------------------------------------------------------------------
	unset ENGCONF
	CRDSHOW=( $(lspci |grep -A 1 "Tundra Semiconductor Corp. Device 8111") )
	if [ "${CRDSHOW[17]}" == "PCI-to-PCI" ] && [ "${CRDSHOW[11]}" == "Co-processor:" ] 
	then
		shf_say "recognised Thales PCIe HSM among visible hardware"
	else
		shf_say "ERROR: can not recognize Thales PCIe HSM among visible hardware"
		shf_say "WARNING: you will not be able to activate the card"
		ENGCONF="no"
		[ "${NOPHASE}" = "yes" ] && myexit 3
	fi
#
	shf_say "calling thales factory configuration script \"${HSMDIR}/sbin/install\""
	if [ -x ${HSMDIR}/sbin/install ]; then
		rc="$( ${HSMDIR}/sbin/install -d &>>${SHELLOG} )$?"
		shf_say "install script for Thales driver software exited \"${rc}\""
	else
		shf_say "ERROR: no executable \"${HSMDIR}/sbin/install\" script found"
	fi
	
	[ "${NOPHASE}" = "no" ] && build_hsm_config_files

	( ${HSMDIR}/scripts/init.d/drivers restart &>/dev/null )    || shf_say "WARNING: restart hsm drivers produced exit \"$?\"" 
	( ${HSMDIR}/scripts/init.d/hardserver  restart &>/dev/null )|| shf_say "WARNING: restart hsm daemon produced exit \"$?\""
	if [ ${HARDSER_SNMP_TRAP[$X]} = "yes" ]; then
	( ${HSMDIR}/scripts/init.d/ncsnmpd restart &>/dev/null )    || shf_say "WARNING: restart hsm snmp daemon produced exit \"$?\""
	fi
	[ "${HARDSER_SNMP_TRAP[$X]}" = "no" ] &&  ${HSMDIR}/scripts/init.d/ncsnmpd stop &>/dev/null
	 shf_say "halted ncsnmpd because it is set as disabled in hapf20 config"
 
	lsmod  &>> ${SHELLOG}
	ps -ef &>> ${SHELLOG}
	lspci  &>> ${SHELLOG}
fi
#=========================================================================================
if [ "${ACTIVATE}" = "yes" ]; then
#--------------------------------------------------------------------------------------
	[ -x ${HSMDIR}/bin/enquiry ]  || ( shf_say "can not find or execute nfast enquiry utility - exiting" ; myexit 3)
	[ -x ${HSMDIR}/bin/nfkminfo ] || ( shf_say "can not find or execute nfast nfkminfo utility - exiting" ; myexit 3)

	if ( ${HSMDIR}/bin/enquiry &>/dev/null ) 
	then
		HARDSERSTAT="$( ${HSMDIR}/bin/enquiry|grep -A 1 "^Server:"|grep "^ enquiry reply flags"|cut -d' ' -f6)"
	else
		shf_say "unable to run nfast enquiry utility - not possible to verify status of the hardserver process"
#		myexit 3
	fi
	if [ ! -z "${HARDSERSTAT}" ] && [[ "${HARDSERSTAT}" != [Ff]"ailed" ]]
	then
	#--------------------------------------------------------------------------------------
		PCISTAT="$( ${HSMDIR}/bin/enquiry|grep -A 1 "^Module #1"|grep "^ enquiry reply flags"|cut -d' ' -f6)"
		if [ ! -z "${PCISTAT}" ] && [[ "${PCISTAT}" != [Ff]"ailed" ]]
		then
			shf_fshow ${HSMDIR}/bin/enquiry
			shf_fshow ${HSMDIR}/bin/nfkminfo
			WORLD=( $(${HSMDIR}/bin/nfkminfo|grep -A 3 "^World") )
			unset WORLD[0]; unset WORLD[1]; unset WORLD[2]; unset WORLD[3] 
			shf_say "found card and reader with status: \"${WORLD[@]}\""

			USEABL=( $(${HSMDIR}/bin/nfkminfo|grep -A 3 "^Module #1$") )
			case ${USEABL[6]} in
				Factory)
					shf_say "Smartcard in mode \"Factory\" - automatic supervision by HAPF21 will not be activated now"
					shf_say "you need to format and configure the smartcards if you want to activate HAPF21 supervision"
					;;
				Usable)
					 shf_say "module status is \"${USEABL[6]}\" - you have already configured hsm smartcards"
					;;
				PreInitMode)
					shf_say "WARNING: your card is in PreInit mode - create security worlds and then put the switch to \"operational\""
					;;
				*)
					shf_say "WARNING: unclear module status is \"${USEABL[6]}\"... continuing without drawing consequence"
					;;
			esac

			OKCARD=( $(${HSMDIR}/bin/nfkminfo|grep -A 4 "^Module #1 Slot #") )
			[ "${OKCARD[13]}" = "state" ] && SLOT[0]="${OKCARD[15]}"
			[ "${OKCARD[29]}" = "state" ] && SLOT[1]="${OKCARD[31]}"
			unset RDRSTAT
			for CARD in ${SLOT[@]}
			do
				case ${CARD} in 
					Operator)
						RDRSTAT="${RDRSTAT}o"
					;;
					Empty)
						RDRSTAT="${RDRSTAT}e"
					;;
					Unformatted)
						RDRSTAT="${RDRSTAT}u"
					;;
					*)
						RDRSTAT="${RDRSTAT}0"
					;;
				esac
				shf_say "card in cardreader found with status \"${CARD}\""
			done
		
			OPCRDS="$(echo $RDRSTAT|grep -o "o"|wc -l)"
			EMCRDS="$(echo $RDRSTAT|grep -o "e"|wc -l)"
			UFCRDS="$(echo $RDRSTAT|grep -o "u"|wc -l)"
			UNKNWN="$(echo $RDRSTAT|grep -o "0"|wc -l)"
			let UNUSBL=${EMCRDS}+${UFCRDS}+${UNKNWN}

			if [ "${OPCRDS}" -ge 1 ]
			then
				shf_say "preconfigured operator cardset found will enable hsm supervision in HAPF20"
				ENGCONF="yes"
			elif [ "${EMCRDS}" -ge 2 ]
			then
				shf_say "WARNING: no smartcards found in reader - make sure it is working and cabled"
				ENGCONF="no"
			elif [ ${UNUSBL} -ge 2 ]  
			then
				shf_say "WARNING: smartcards in reader are not yet configured - will not enable hsm supervision in HAPF20"
				shf_say "configure the smartcards and then manually activate hsm in HAPF20 configuration"
				ENGCONF="no"
			else
				shf_say "ERROR: can not determine status of any smartcards in the card reader device"
				ENGCONF="no"
			fi
		else
			shf_say "WARNING: your hardserver process sems to be running but not accesssing the card properly"
			shf_say "WARNING: verify that the mode switch on the back of the card is in position \"operational\""
			shf_say "WARNING: verify PCI HW and cabling of the card reader device is done properly"
			shf_say "WARNING: ICertifier resource agent will not be able to supervise your HSM module"
			ENGCONF="no"
			myexit 3
		fi
	else
		shf_say "your hardserver process is not accessing the hsm module - check if nfp driver works properly"
		myexit 3
	fi
	#--------------------------------------------------------------------------------------
	FILE="/usr/local/certifier/conf/engine.conf"
	if [ -w "${FILE}" ]
	then
		: ${BACKDIR:="$(dirname ${FILE})"}
		: ${NOW:="$(date +%d%m%Y%H%M)"}
		unset ISIN 
		ISIN="$(grep ${PKCSDRIVER} ${FILE}|tr -d [:blank:]|tr -d '"'|grep "^(library${PKCSDRIVER})")"
		if [ ! -z "${ISIN}" ]; then  shf_say "driver ${PKCSDRIVER} is already activated - wont add it again"; ENGCONF="no"; fi
	else
		shf_say "WARNING: config \"${FILE}\" is not available at this stage - HSM supervision can not be activated yet"
		shf_say "WARNING: enable HSM supervision after HAPF20 installation is complete and operator cards are configured"
		shf_say "WARNING: use \"${HAPFCF}/config_hsm.sh -activate\" to enable HSM module supervision"
		ENGCONF="no"
	fi
	if [ -f "${FILE}" ] && [ "${ENGCONF}" = "yes" ]
	then
	#--------------------------------------------------------------------------------------
		shf_say "hsm status meets conditions to enable HAPF20 supervision in certifier conf"
		rc="$(cp -fp ${FILE} ${BACKDIR}/$(basename ${FILE}).${NOW})$?"
		[ "${rc}" -eq 0 ] && shf_say "savecopy of your engine.conf is made to ${BACKDIR}"
		[ "${rc}" -ne 0 ] && (shf_say "ERROR: can not make savecope of engine.conf to ${BACKDIR}" exiting; myexit 3)
		let i=0 ; unset APRNCS ; MATCH="(ek-providers"
		grep -n "${MATCH}" ${FILE} |while read LINE
		do
			LNUM="$(echo ${LINE}|cut -d':' -f1)"
			CONT="$(echo ${LINE}|cut -d':' -f2)"
			
			HERE="$(echo ${CONT}|sed 's/^[ \t]*//;s/[ \t]*$//'|grep "^${MATCH}$"|wc -l)"
			if [ ${HERE} -eq 1 ] 
			then
				sed -i "${LNUM} a; ----- HAPF20 managed entry start tag -----" $FILE ; let LNUM=${LNUM}+1
				sed -i "${LNUM} a (provider (type \"pkcs11\")" $FILE ; let LNUM=${LNUM}+1
				sed -i "${LNUM} a (library \"${PKCSDRIVER}\")"  $FILE ; let LNUM=${LNUM}+1
				sed -i "${LNUM} a (info \"read-only(no) threads(no)\"))" $FILE; let LNUM=${LNUM}+1
				sed -i "${LNUM} a; ----- HAPF20 managed entry end tag -----" $FILE
				shf_say "inline-edited ${FILE} - restart engine to activate changes in certifier"
			fi
		done 
#
	elif [ ! -f "${FILE}" ] && [ "${ENGCONF}" = "yes" ]
	then
		[ "${ROLE}" == "SingleServer" ] && shf_say "ERROR: can not find $FILE make sure /usr/local/certifier is mounted"
		DSKSIT=( $(drbd-overview) )
		if [ "${DSKSIT[1]}" = "Connected" ] && [ "${DSKSIT[3]}" = "UpToDate/UpToDate" ] 
		then
#
			case ${DSKSIT[2]} in
				"Primary/Secondary")
					 shf_say "ERROR: DRBD seems fine but can not find $FILE make sure /usr/local/certifier is mounted"
				;;
				"Secondary/Primary")
					shf_say "the other backend is active - try to run this script on the HA peer"
				;;
			esac
		else
			shf_say "ERROR: unclear DRBD or general disk situation, and no access to $FILE" 
			shf_say "drbd status is \"$(drbd-overview)|tr --squeeze-repeats ' '\""
			shf_say "ERROR: please solve disk issues before mounting certifier and changing \"${FILE}\""
				
		fi
	elif [ "${ACTIVATE}" = "yes" ] && [ "${ENGCONF}" = "no" ] && [ -z ${ISIN} ]
	then
		shf_say "WARNING: hsm supervision has not been activated in ${FILE} due to bad hsm conditions"
	fi
fi	
[ "${ENGCONF}" = "yes" ] && shf_say "ATTENTION: fail in hsm or smartcards will now IMMEDIATELY trigger failover"
#-----------------------------------------------------------------------------------------
if [ "${DEACT}" = "yes" ]; then
#=========================================================================================
	FILE="/usr/local/certifier/conf/engine.conf"
	[ -r ${FILE} ] || (shf_say "can not find ${FILE} on ${ROLE} right now - try the other BE"; myexit 1)
	CMT=";"
	STRLINE=( $(grep -n "^; ----- HAPF20 managed entry start tag -----" ${FILE}|cut -d':' -f1) )
	STPLINE=( $(grep -n "^; ----- HAPF20 managed entry end tag -----" ${FILE}|cut -d':' -f1) )
	[ -z "${STRLINE[0]}" ] && STRLINE[0]="0" ;[ -z "${STPLINE[0]}" ] && STPLINE[0]="0" 
	ISIN="$(grep ${PKCSDRIVER} ${FILE}|tr -d [:blank:]|tr -d '"'|grep "^(library${PKCSDRIVER})")"

	if [ "${#STPLINE[@]}" -eq "${#STRLINE[@]}" ] &&  [ "${STPLINE[0]}" -gt "${STRLINE[0]}" ] 
	then
		let max=${#STRLINE[@]}-1
		CHAIN=( $(seq 0 $max) );RCHAIN=$(echo ${CHAIN[@]}|tac -s' '|tr '\n' ' '|tr --squeeze-repeats ' ')
		for i in ${RCHAIN} 
		do
			sed -i "${STRLINE[$i]},${STPLINE[$i]}d" ${FILE} && sync
		done	
	elif [ -z "${ISIN}" ]
	then
		:
	else
		shf_say "WARNING: can not parse config file - check manually"
	fi

	ISIN="$(grep ${PKCSDRIVER} ${FILE}|tr -d [:blank:]|tr -d '"'|grep "^(library${PKCSDRIVER})")"
	if [ ! -z "${ISIN}" ]
	then  
		shf_say "driver ${PKCSDRIVER} seems crrently active - deactivation not successfull"
		myexit 1
	else
		shf_say "driver named ${PKCSDRIVER} currently not (any more) active"
	fi
fi

shf_say "#-----------------------------------------------------------------"
shf_say "leaving script ${MYSELF}"
shf_say "#-----------------------------------------------------------------"
