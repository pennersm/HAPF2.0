#!/bin/bash
###########################################################################
# NSN INSTA HAPF2.1 SCRIPT
#--------------------------------------------------------------------------
# Script default name   : ~script/watch_performance.sh
# Configure version     : mkks61f.pl
# Media set             : PF21I51RH63-12
# File generated        : 03.01.2013 MPe
#
###########################################################################
export -p  MYSELF="watch_performance.sh"
TAG=$MYSELF
FPREFIX=$( hostname )

CFGFILE="/etc/hapf20.d/watch_performance.cf"
 [ -r "${CFGFILE}" ] && . ${CFGFILE}
# else:
: ${LOGDIR:="/var/log/watch_perf"}
: ${OBSTIME:="24h"}
: ${OBSINTV:="5m"}
: ${KEEPOLD:="12d"}
logger -p user.debug -t ${TAG} "invoke ${LOGDIR} OBSTIME=${OBSTIME} OBSINTV=${OBSINTV} KEEPOLD=${KEEPOLD}"
#----------------------------------------------------------------------------------------
bold=$(tput bold)
normal=$(tput sgr0)

usage() {
printf "\n ${bold}USAGE:${normal}\n"
printf "\t Easy interface to start collection of performance data via sadc, e.g. to run directly as cronjob\n"
printf "\t-------------------------------------------------------------------------------------------------\n" 
printf "\t watch_performance.sh [OPTION]\n\n"
printf "\t ${bold}--start-observ${normal}\n"
printf "\t Will start a backgroud job to collect all possible measurements. Duration and number of sampling\n"
printf "\t Intervalls for the collection can be either default (hardcoded) or be defined via ENV variables\n"
printf "\t or set in a configuration file ${CFGFILE}\n"
printf "\t following parameters (along with their default values) define the data collection:\n"
printf "\t LOGDIR \tDefault: /var/log/watch_perf - Direcory to temp-store and archive measurement files\n"
printf "\t OBSTIME \tDefault: 24h - Collecting starts immediately and ends after Xs(econd) or Xh(our) or Xd(ay)\n"
printf "\t OBSINTV \tDefault:  5m - Write every Xs(seocnd) or Xm(inute) or ... a new average value for period\n"
printf "\t KEEPOLD \tDefault: 12d - Files older than Xd(ay) or Xm(inute) ... are deleted from the LOGDIR\n" 
printf "\n\n \t ${bold}--clean-old${normal}\n"
printf "\t Cleaning as specified by the KEEPOLD parameter does not happen by default, but only if the script\n"
printf "\t is onvoked using the --clean-old option. If not, no cleanup will happen in LOGDIR"
printf "\n\n \t ${bold}--show-what${normal}\n" 
printf "\t Gives a brief overview over the reports that can be generated using the sar-command"
printf "\n\n \t ${bold}MIND THE FOLLOWING GENERAL CAVEATS${normal}\n"
printf "\t 1) The --show-what option is not at all complete, read \"man sar\" to get a complete list!\n"
printf "\t 2) Files older than the KEEPOLD parameter will be only removed if the --clean-old is set.\n"
printf "\t 3) You can \"export -p {parameter}=[value] to overwrite defaults without creating a config file\n"
printf "\t    for example:\n"
printf "\t\t\t export -p OBSTIME=5m OBSINTV=1s\n"
printf "\t    will trigger collection of data for 5 minutes in 1second sampling intervals\n"
printf "\t 4) You can of course easily change the \"hardcoded\" presettings in the script itself!\n"
printf "\t 5) You will not be able to run this tool on systems with only one single processor core!\n"
printf "\t    If you have only one core, edit the actual sar command that is started inside --start-observ\n"
printf "\t    (probably by removing the \"M\" directive)\n" 
printf "\t 6) There will be no data written if the LOGDIR is not writable or if package sysstat is not installed\n"
printf "\t    Do also check the regular syslog for indication of problems\n"
printf "\n\n"
}
display_sar_usage() {
printf "\n ${bold}sar -C [-bBdnPqrRSuvWy] [-s {STARTTIME}] [-e {STOPTIME}] [-i {INTERVAL}] [-f {FILE}]${normal}\n"
printf "\n \t following is a quick summary of sar reports that can be generated.\n" 
printf "\n\tDISK (d) AND GENERAL I/O (b) REPORTING:\n"
printf "\t -dp: tps  rd_sec/s  wr_sec/s  avgrq-sz  avgqu-sz  await svctm  %%util\n"
printf "\t -b : tps  rtps  wtps  bread/s  bwrtn/s\n"

printf "\n\tTTY ACTIVITY:\n"
printf "\t -y : rcvin/s xmtin/s  framerr/s  prtyerr/s brk/s ovrun/s\n"
printf "\n\tPAGING (W, B), SWAPPING (S) AND MEMORY (rR)\n"
printf "\t -B : pgpgin/s  pgpgout/s  fault/s  majflt/s  pgfree/s  pgscank/s  pgscand/s  pgsteal/s  %%vmeff\n"
printf "\t -S : kbswpfree  kbswpused  %%swpused  kbswpcad  %%swpcad\n"
printf "\t -r : kbmemfree  kbmemused  %%memused  kbbuffers  kbcached  kbcommit  %%commit\n"

printf "\n\tNETWORK ACTIVITY:\n"
printf "\t -n DEV  : rxpck/s  txpck/s  rxkB/s  txkB/s  rxcmp/s  txcmp/s  rxmcst/s\n"
printf "\t -n EDEV : rxerr/s  txerr/s  coll/s  rxdrop/s  txdrop/s  txcarr/s  rxfram/s  rxfifo/s  txfifo/s\n"
printf "\t -n TCP  : active/s  passive/s  iseg/s  oseg/s\n"
printf "\t -n ETCP : atmptf/s  estres/s  retrans/s  isegerr/s  orsts/s\n"
printf "\t -n IP   : irec/s  fwddgm/s  idel/s  orq/s  asmrq/s  asmok/s  fragok/s  fragcrt/s\n"
printf "\t -n EIP  : ihdrerr/s  iadrerr/s  iukwnpr/s  idisc/s  odisc/s  onort/s  asmf/s  fragf/s\n"
printf "\n\tCPU ACTIVITY:\n" 
printf "\t -P ALL : %%user  %%nice  %%system  %%iowait  %%steal  %%idle\n"
printf "\t -q     : runq-sz  plist-sz  ldavg-1  ldavg-5  ldavg-15\n"
printf "\n\tMIND: That several more reports are possible, see man sar\n\n" 
}
#----------------------------------------------------------------------------------------
shf_valtim() {
	local GIVETIM=$1 ; rc=0
	EXTENS="$(expr match "${GIVETIM}" '.*\([d,D,h,H,m,M,s,S]\)')"
	NSEC="$(echo ${GIVETIM%?})"
	
	[ -z "$(echo ${NSEC}|tr -d [:digit:])" ] || ( logger -p user.error -t ${TAG} "bad config parameter ${GIVETIM}!"; return 6 ) 

	while [[ ! "${EXTENS}" == [s,S] ]]; do
		case ${EXTENS} in
		d|D)
			EXTENS="h"
			let NSEC=${NSEC}*24
		;;
		h|H)
			EXTENS="m"
			let NSEC=${NSEC}*60
		;;
		m|M)
			EXTENS="s"
			let NSEC=${NSEC}*60
		;;
		*)
			logger -p user.error -t ${TAG} "bad config parameter ${GIVETIM}!"
			return 6
		;;
		esac
	done
	
	echo ${NSEC}
	return ${rc}		
}
#----------------------------------------------------------------------------------------
shf_new_file() {
	STARTED="$(date)"
	SEC2END=$1

	STRSTMP=$(date --date "${STARTED}" +%Y%m%d-%H%M%S)
	ENDSTMP=$(date --date "${STARTED} ${SEC2END} seconds" +%Y%m%d-%H%M%S)
	local NEWFILE="${LOGDIR}/${FPREFIX}.${STRSTMP}_to_${ENDSTMP}.sar"

	echo ${NEWFILE}
}
#----------------------------------------------------------------------------------------
validate() {
	myexit() { kill -TERM $$ ; }
	rc=1;
	( rpm -qa |grep "sysstat" &>/dev/null ) || ( logger -p user.error -t ${TAG} "systat package not installed - exiting"; myexit )
	[ -d ${LOGDIR} ] || ( logger -p user.error -t ${TAG} "directory for measurement files does not exist: \"${LOGDIR}\" - exiting"; myexit )
	[ -w ${LOGDIR} ] || ( logger -p user.error -t ${TAG} "directory for measurement files is not writeable: \"${LOGDIR}\" - exiting"; myexit )
	( nohup test [:] &>/dev/null ) || ( logger -p user.warn  -t ${TAG} "can not run jobs with nohup - you wont be able to generate reports!" )
	
	HAVESAR="$(which sar &>/dev/null)$?"
	if [ "${HAVESAR}" = "0" ]; then
		local NUMCPUS="$(sar -r |grep "$(uname -r)"|awk -F\( '{print $NF}'|cut -d' ' -f1)"
		if [ ! -z "$( echo ${NUMCPUS}|tr -d [:digit:])" ]; then
			logger -p user.err  -t ${TAG} "can not find out how many CPUs you have - exiting"
			rc=1
		elif [ "${NUMCPUS}" = "1" ]; then
			logger -p user.debug -t ${TAG} "found 1 CPU core ..."
			export SARCMD="sar -A"
			rc=0
		elif [ "${NUMCPUS}" -ge 2 ]; then
			logger -p user.debug -t ${TAG} "found multiple CPU: ${NUMCPUS} cores"
			export SARCMD="sar -A -P ALL"
			rc=0
		fi 
	else
		logger -p user.warn -t ${TAG} "seems you dont have sar working on this machine - you wont be able to evaluate reports!"
		echo "seems you dont have sar working on this machine - you wont be able to evaluate reports"
		exit 5
	fi
}
#----------------------------------------------------------------------------------------
# some people might prefer to use logrotate for this !
clean_old() {
	rc=1
	local KEEPOLD=$1
	let KEEPTIME=$( shf_valtim ${KEEPOLD} )

	if [ ${KEEPTIME} -le 60 ] ; then
		KEEPTIME="1"
	else
		let KEEPTIME=${KEEPTIME}/60
	fi

	NFILES=$(find ${LOGDIR}/ -type f -name "${FPREFIX}.*.sar" -mmin +${KEEPTIME}|wc -l)
	if [ ${NFILES} -gt 0 ] ; then
		rc="$(find ${LOGDIR} -type f -name "${FPREFIX}.*.sar" -mmin +${KEEPTIME} -delete &>/dev/null)$?"
		logger -p user.info "deletion of ${NFILES} old measurements with exit \"${rc}\""
		echo "deleting old measurements endet with status \"${rc}\""
	else
		logger -p user.debug "no old measurement files found for deletion"
		echo "no old measurement files found for deletion"
		rc=0
	fi
	[ ${rc} -eq 0 ] || logger -p user.info "attempt to delete ${NFILES} measurement exited \"${rc}\"" 	
	

	SFILES=$(find /var/log/sa/ -type f -name "sa*" -mmin +${KEEPTIME}|wc -l)
	if [ ${SFILES} -gt 0 ] ; then
		rc="$(find /var/log/sa/ -type f -name "^sa*" -mmin +${KEEPTIME} -delete &>/dev/null)$?"
		logger -p user.info "deletion of ${NFILES} old tempfiles with exit \"${rc}\""
		echo "deleting old tempfiles endet with status \"${rc}\""
	else
		logger -p user.debug "no old tempfiles found for deletion"
		echo "no old tempfiles found for deletion"
		rc=0
	fi
	[ ${rc} -eq 0 ] || logger -p user.info "attempt to delete ${NFILES} old tempfiles exited \"${rc}\""
 
	return ${rc}
}
#========================================================================================
unset SARCMD
[ $# = 0 ] && usage; validate
#
while [ $# !=  0 ]
do
        case $1 in
	--start-observ)
		INTERVAL="$( shf_valtim ${OBSINTV} )"
		SECSTOGO=$( shf_valtim ${OBSTIME} )
		let NSAMPLES=${SECSTOGO}/${INTERVAL}
		NEWFILE=$( shf_new_file ${SECSTOGO} )
		TMPOUT="/tmp/nohup.out.${RANDOM}"

		rc="$( nohup $SARCMD -o ${NEWFILE} ${INTERVAL} ${NSAMPLES} &> ${TMPOUT} & )$?" && sync
		if [ "${rc}" = "0" ]; then
			JOBID=$(lsof ${TMPOUT}|grep "^sadc"|tr --squeeze-repeats ' '|cut -d' ' -f 2)
			logger -p user.info -t ${TAG} "performance collection started with pid ${JOBID}"
			echo  "performance collection started with pid ${JOBID}"
			rm -f ${TMPOUT}
		else
			logger -p user.warn -t ${TAG} "problem when starting performance data collection: exit \"${rc}\""
			echo "problem when starting performance data collection: exit \"${rc}\""
		fi
	;;
	--clean-old)
		clean_old ${KEEPOLD}
		rc=$?
	;;
	--show-what)
		display_sar_usage
		rc=0
	;;
	*)
		usage
		rc=2
	;;
esac; shift; done
exit ${rc}
