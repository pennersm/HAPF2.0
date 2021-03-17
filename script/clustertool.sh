#!/bin/bash
# NSN INSTA HAPF2.1 PLATFORM SCRIPT
#--------------------------------------------------------------------------
# Script default name   : ~script/clustertool.sh
# Configure version     : mkks61f.pl
# Media set             : PF21I52RH63-12
# File generated        : 03.01.2013 MPe
#
###########################################################################
TSTAMP=$(date +%Y%m%d-%H%M%S)
export -p  MYSELF="clustertool.sh" ; TAG=$MYSELF
#----------------------------------------------------------------------------------
if [ "`whoami`" != "root" ]
then
        logger -p user.info -t ${TAG} "attempt to run \"${MYSELF}\" as \"`whoami`\" was rejected"
        echo "only root is allowed to execute \"${MYSELF}\""
        exit 1
fi
: ${MAINFLAG:="/etc/hapf21.flag"}
: ${SETNSNENV:="/etc/hapf21.d/setnsnenv.sh"}
if [ ! -f ${MAINFLAG} ] || [ ! -x ${SETNSNENV} ]
then
        echo "not a complete HAPF2.1 installation"
        logger -p user.info -t ${TAG} "ERROR: stopping attempt to run \"${MYSELF}\" in incomplete environment"
        exit 1
else
        source ${MAINFLAG}
        ROLE="${GENROLE}"
	. ${SETNSNENV} ${ROLE}
	echo "started for Role \"${ROLE}\" with args \"$*\""
fi
shf_debug_break () {
        shf_cont () { : ; } ;
        echo "---------------- enter \"shf_cont\" to resume ------------------"
        unset line
        DBP="#-DEBUG-#"
        while [ "$line" != "shf_cont" ]
        do
                echo -n $DBP
                read line
                eval $line
        done
}
#========================================================================================
usage() {
bold=$(tput bold)
normal=$(tput sgr0)
printf "\n ${bold}USAGE:${normal}\n"
printf "\t cluster handling script for HAPF2.1\n"
printf "\t -----------------------------------------------------------------------\n"
printf "\t clustertool.sh switch [file]}\n\n"
printf "\t ${bold}--empty-config${normal} [file]\n"
printf "\t Delete existing pacemaker configuration and leave empty CIB.\n"
printf "\t All resources are first halted, then deleted, then cibadmin -e is issued, finally check for orphans\n"
printf "\t Mind that his could always hang or at least leave some orphaned resources especially without stonithd\n"
printf "\t After the procedure is completed, crm_mon will show nodes as \"UNCLEAN\" until they are onilne again\n"
printf "\t hence do always wait about 1min. for both nodes to be ONLINE again before taking further action\n" 
printf "\t Previous config is saved into file or ${HAPFCF}/backup/clusterconfig_${ROLE}_{TIMESTAMP}.xml\n\n"
printf "\t ${bold}--[stop|start|restart]${normal}\n"
printf "\t Issue service corosync {argument} command on both nodes\n\n"
printf "\t ${bold}--stop-resources${normal}\n"
printf "\t Will halt all configured resources but leave the cluster running\n\n"
printf "\t ${bold}--start-resources${normal}\n"
printf "\t Will reverse above mentioned and start all resources that have been stoped before\n\n"
printf "\t ${bold}--replace-xml${normal} file\n"
printf "\t Replace existing CIB by the one described in file.\n"
printf "\t Old CIB is always dumped into /root/cibconf-${ROLE}-$(uname -n)-{TIMESTAMP}.xml\n\n"
printf "\t ${bold}--run-crm${normal} file\n"
printf "\t Feed file into crm shell. \n"
printf "\t Parse only crm commands, recognize comments and use variables in existing shell\n\n"
printf "\t ${bold}--show-failcounts${normal}\n"
printf "\t Check for configured resources and list their failcounts\n\n"
printf "\t ${bold}--reset-failcounts${normal}\n"
printf "\t Check for configured resources and reset their failcounts\n\n"
printf "\t ${bold}--list-resources${normal}\n"
printf "\t Check for configured resources and list. \n\n"
printf "\t ${bold}--unmigrate${normal}\n"
printf "\t Search for cli-standby- location constraints and resource-unmigrate what comes after. \n\n"
return 2
}
#========================================================================================
stop_cluster() {
	echo "trying to stop cluster services ..."
	rc1="$( /etc/init.d/corosync stop > /dev/null )$?" &&
	rc2="$( ssh ${HOSTNAME[$Y]} -- /etc/init.d/corosync stop > /dev/null )$?"

	if [ "${rc1}" = "0" ] && [ "${rc2}" = "0" ]; then
		shf_logit "cluster \"${HOSTNAME[$X]}\" -- \"${HOSTNAME[$Y]}\" is now stopped"
		rc=0
	else
		shf_logit "can not or not entirely stop running cluster - exiting"
		rc=1
	fi
	return ${rc}
}
#----------------------------------------------------------------------------------------
start_cluster() {
	echo "trying to start cluster services ..."
	rc1="$( /etc/init.d/corosync start &> /dev/null )$?" &&
	rc2="$( ssh ${HOSTNAME[$Y]} -- /etc/init.d/corosync start &> /dev/null )$?"
	
	if [ "${rc1}" = "0" ] && [ "${rc2}" = "0" ]; then
		shf_logit "cluster start commands executed and received exit 0"
		rc=0
	else
		shf_logit "ERROR: cluster start commands executed and received non-zero exit"
		rc=1
	fi
	return ${rc}
}
#----------------------------------------------------------------------------------------
restart() {
	stop_cluster; rc=$?
	if [ ${rc} -eq 0 ]; then
		start_cluster; rc=$?
	else
		shf_logit "can not properly stop cluster - halt exited with \"${rc}\""
	fi
	return ${rc}
}
#----------------------------------------------------------------------------------------
empty_config() {
	local BUFILE=$1 
	: ${BUFILE:="${HAPFCF}/backup/clusterconfig_${ROLE}_${TSTAMP}.xml"}
	if [ ! -w "$(dirname ${BUFILE})" ]; then
		echo "can not create backup of local cib in \"${BUFILE}\" - exiting"
		rc=1
	else
		cibadmin --query > ${BUFILE}
		shf_logit "created backup of local cib in \"${BUFILE}\""
 		crm_verify --xml-file=${BUFILE}; rc=$?
		if [ "${rc}" = "0" ]; then 
			
			crm_attribute --attr-name stop-orphan-resources --attr-value=TRUE &>/dev/null

			local RESOURCES=( $(crm_resource -l) )
			for RES in ${RESOURCES[@]}; do
				crm resource stop ${RES} &>/dev/null &&
				crm configure delete ${RES} &>/dev/null
			done

			cibadmin -E --force ; sleep 1
			[ "$( crm_resource -l &>1 |grep "NO resources configured"|wc -l )" = "1" ] && rc=0
			shf_logit "cluster configuration emptied"
			
		else
			shf_logit "can not empty cluster config"
			rc=1
		fi
	fi
	
	ORPHANS=( $(crm_mon -1|grep ORPHANED|awk '{print $1}') )
	if [ ${#ORPHANS[@]} -gt 0 ]; then
		shf_logit "still ${#ORPHANS[@]} orphans alive: ${ORPHANS[@]}"
		shf_logit "trying to restart cluster and kill orphans"
		restart; rc=$?
	fi				
	return ${rc}
}	
#----------------------------------------------------------------------------------------
feedin_config_crm() {
	CRMCF=$1
	if [ ! -r ${CRMCF} ] ; then
		echo "can not read file \"${CRMCF}\""
		return 5
	else
		sed -e 's/^[ \t]*//; s/#[^#]*$//; /^$/d; /#/d' ${CRMCF}| while read LINE
		do
			shf_crm $LINE 
			rc=$?; [ ${rc} = "0" ] || break 
		done
	fi
	return ${rc}
}
#----------------------------------------------------------------------------------------
list_resources() {
	local RSC NRES i
	local RESOURCES=( $(crm configure show|grep "^primitive "|cut -d' ' -f 2) )
	let NRES=${#RESOURCES[@]}-1

	local CLONES=( $(crm configure show|grep "^clone "|cut -d' ' -f 2) )
	local MSSETS=( $(crm configure show|grep "^ms "|cut -d' ' -f 2) )

	let i=0; for RSC in ${CLONES[@]} ${MSSETS[@]}
	do
		DELCLONE[$i]=$(crm configure show|awk -v R="${RSC}" '($2==R){print $3}')
		let i=$i+1
	done

	let i=0; for i in $(seq 0 ${NRES})
	do for RSC in ${DELCLONE[@]}; do
		[ "${RESOURCES[$i]}" = "${RSC}" ] && unset RESOURCES[$i]
	done; let i=$i+1; done
	
	RESOURCES=( ${RESOURCES[@]} ${CLONES[@]} ${MSSETS[@]} )

	if [ "${#RESOURCES[@]}" = "0" ] ; then
		echo "can not find any clustered resources here"
		rc=7
	else
		rc=0
		echo ${RESOURCES[@]}|tr ' ' '\n'	
	fi
	return ${rc}
}
#----------------------------------------------------------------------------------------
stopstart_resources() {
	unset RESOURCES RESRC NRSC TARGTST ACTION PATT READY
	case $1 in
		start) TARGTST="up";  ACTION="start";PATT="runningon:" ;;
		stop)  TARGTST="down";ACTION="stop"; PATT="NOTrunning" ;;
	esac
	
	local RESOURCES=( $(list_resources) )
	let NRSC=${#RESOURCES[@]}-1
	
	for rsc in $(seq 0 $NRSC); do RSTAT[$rsc]="undef"; done
	READY="no"
	while [ "${READY}" = "no" ]
	do
		for rsc in $(seq 0 ${NRSC})
		do  if [ "${RSTAT[$rsc]}" != "${TARGTST}" ]; then
			echo "trying to ${ACTION} ${RESOURCES[$rsc]} ... "
			crm resource ${ACTION} ${RESOURCES[$rsc]}
			sleep 2
			[ "$(crm_resource --resource ${RESOURCES[$rsc]} --locate|awk '{print$3$4}')"  = "${PATT}" ] && RSTAT[$rsc]="${TARGTST}"
		fi; done

		READY="yes"

		for rsc in $(seq 0 ${NRSC})
		do 
			[ "${RSTAT[$rsc]}" = "${TARGTST}" ] && READY="no"
		done 
	done
	return 0 
}
#----------------------------------------------------------------------------------------
show_failcounts() {
	local RESOURCES=( $(list_resources) )
	rc="$(list_resources &>/dev/null)$?"
	bold=$(tput bold)
	normal=$(tput sgr0)
	here="$(tput lines)"; let go=$here+2
	echo ; c1=25; c2=45
	tput cup $go $c1
	printf "${bold}${HOSTNAME[$X]}";tput cup $go $c2 ;printf "${HOSTNAME[$Y]}\n${normal}"
	for RES in "${RESOURCES[@]}"
	do
		HXFC="$(crm resource failcount ${RES} show ${HOSTNAME[$X]}|cut -d' ' -f4)"
		HYFC="$(crm resource failcount ${RES} show ${HOSTNAME[$Y]}|cut -d' ' -f4)"
		printf "${RES}";let go=$go+1
		tput cup $go $c1; printf "${HXFC}"; tput cup $go $c2; printf "${HYFC}\n"
	done
	echo
	return ${rc}
}
#----------------------------------------------------------------------------------------
reset_failcounts() {
	local RESOURCES=( $(list_resources) )
	rc=1
	for RES in ${RESOURCES[@]}
	do
		rc1="$(crm resource failcount ${RES} set ${HOSTNAME[$X]} 0 &>/dev/null)$?"
		rc2="$(crm resource failcount ${RES} set ${HOSTNAME[$Y]} 0 &>/dev/null)$?"
		crm resource cleanup ${RES}
		sleep 1
		if [ ! "${rc1}" = "0" ] || [ ! "${rc2}" = "0" ] ; then
			echo "problem when resetting failcounts, try manual actions please"
			rc=1	
			break
		else
			rc=0
		fi
	done
	return ${rc}
}
#----------------------------------------------------------------------------------------
increase_admin_epoch() {
	LASTF=$1
	if [ "$(grep "admin_epoch=" ${LASTF}|wc -l)" = "1" ]; then
		MYLINE=( $(grep "admin_epoch=" ${LASTF}) )
		for PARAM in ${MYLINE[@]}; do
			PN="$(echo ${PARAM}|cut -d'=' -f1)"
			PV="$(echo ${PARAM}|cut -d'=' -f2|tr -d '"')"
			[ "${PN}" = "admin_epoch" ] && RPV=${PV}
		done
		PV="$RPV"; let NPV=${PV}+1
	else
		rc=6; shf_logit "ERROR: can not find a distinct admin_epoch parameter"
	fi
	
	if [ -z "$(echo $NPV|tr -d [:digit:])" ]; then
		OLDEPOCH="admin_epoch=\"${PV}\"" ; NEWEPOCH="admin_epoch=\"${NPV}\""
		sed -i s/${OLDEPOCH}/${NEWEPOCH}/ ${LASTF}
		rc=$?
		[ $rc -eq 0 ] && echo ${NEWEPOCH}
	fi
	sync && return $rc	
}
#----------------------------------------------------------------------------------------
feedin_config_xml() {
        XMLCF=$1
        if [ ! -r ${XMLCF} ] ; then
                shf_logit "can not read file \"${XMLCF}\""
                rc=5
        elif ( crm_verify -x ${XMLCF} ); then
		BUFILE="/root/cibconf-${ROLE}-$(uname -n)-${TSTAMP}.xml"
		cibadmin --query > ${BUFILE}
		shf_logit "savedumped running CIB XML to \"${BUFILE}\""
		NAE="$(increase_admin_epoch ${XMLCF})"
		[ $? -eq 0 ] && cibadmin --replace --xml-file ${XMLCF}
		rc=$?
		echo "New admin epoch set to \"${NAE}\""
		shf_logit "replaced running config with \"${XMLCF}\" and got exit \"${rc}\""
	else
		rc=6
		echo "problem with the XML file you specified - exiting \"${rc}\""
	fi
	return ${rc}
}
#----------------------------------------------------------------------------------------
unmigrate() {
	rc=99; prc=99
	while [ "$(crm configure show|grep -m 1 "^location cli-standby"|wc -l)" != "0" ]
	do
		CLICONSTR=( $(crm configure show|grep -m 1 "^location cli-standby") )
		UMIGRATME=${CLICONSTR[1]#cli-standby-}
		echo "trying to unmigrate ${UMIGRATME} ..."
		crm resource unmigrate ${UMIGRATME}; rc=$?
		if [ "${rc}" != "0" ]; then
			echo "... NOK attempt exited with ${rc}"  
			prc=1
		fi
	done
	[ "${prc}" = "99" ] || rc=1
	return $rc
}
#========================================================================================
[ $# = 0 ] && usage
while [ $# !=  0 ]
do
        case $1 in
	-e|--empty-config)
		BUFILE=$2
		: ${BUFILE:="${HAPFCF}/backup/clusterconfig_${ROLE}_${TSTAMP}.xml"}
		empty_config ${BUFILE}
		rc=$?
	;;
	--stop)
		shf_logit "invoked to stop cluster services"
		stop_cluster
		rc=$?
	;;
	-s|--start)
		shf_logit "invoked to start cluster services"
		start_cluster
		rc=$?
	;;
	-rs|--stop-resources)
		shf_logit "invoked to stop all resources in active cluster"
		stopstart_resources stop
		rc=$?
	;;
	-ss|--start-resources)
		shf_logit "invoked to start all resources in active cluster"
		stopstart_resources start
		rc=$?
	;;
	-hs|--restart)
		shf_logit "invoked to restart cluster services"
		stop_cluster; rc=$?
		if [ ${rc} -eq 0 ]; then 
			start_cluster; rc=$?
		else
			shf_logit "can not stop cluster - halt exited with \"${rc}\""
		fi
	;;
	-x|--replace-xml)
		shf_logit "invoked to replace CIB by XML"
		XMLCFFILE=$2; [ ! -z "${XMLCFFILE}" ] || usage
		feedin_config_xml ${XMLCFFILE}
		rc=$?
		shift
	;;
	-f|--run-crm)
		CRMCFFILE=$2;
		if [ -z "${CRMCFFILE}" ]; then
			shf_logit "missing argument crm file" 
			rc=2
		else
			shf_logit "applying crm command file ${CRMCFFILE}"
			feedin_config_crm ${CRMCFFILE}
			rc=$?
		fi
		shift
	;;
	-c|--show-failcounts)
		show_failcounts
		rc=$?
	;;
	-r|--reset-failcounts)
		reset_failcounts
		rc=$?
		crm resource reprobe
	;;
	-l|--list-resources)
		RESOURCES=( $(list_resources) )
		rc=$?
		echo; echo "RESOURCES:"
		echo ${RESOURCES[@]}|tr --squeeze-repeats ' ' '\n'
		echo
	;;
	-u|--unmigrate)
		unmigrate
		rc=$?
	;;
	*)
		usage
	;;
esac ; shift ; done
echo "ending \"${MYSELF}\" with exit \"${rc}\""
exit $rc
