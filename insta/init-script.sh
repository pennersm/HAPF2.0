#!/bin/sh
# chkconfig: 2345 95 05 
# description: LSB compliant startscript for Insta(R) certifier
#
# NOTE: do not use any /etc/init.d/functions as we want to be 
# as independent as possible. Lets do it all here:
#
###########################################################################
# NSN INSTA HAPF2.1 RESOURCE AGENT FOR CERTIFIER
#--------------------------------------------------------------------------
# Script default name   : ~etc/rc.init/init.d/{certifier-role}
# Script version        : 1.3
# Configure version     : mkks62g.pl
# Media set             : PF21I52RH64-12
# File generated        : 13.10.2013 MPe
#
###########################################################################
#
# FUNCTIONALITY:
# - deliver LSB compliant exit-codes (see http://wiki.debian.org/LSBInitScripts)
# - this script is - apart prognam specific INIT INFO section (see LSB),
#   identical for both, frontend (certifsub) and backend (certifier)
# - like in the original version, the script invokes the actual start/stop and 
#   environment definition functions by Insta (R) in $mountdir and below. 
#   Anything here is just "framework around" the actual startscripts in the 
#   certifier root-directories
# - This script comes together with a bugfixed/edited version of ssh-ca-start
#   verify the ssh-ca-start header for version information in the header 
#
# - We start/stop the following processes:
#                                 on BE           on FE   
#      ssh-ca-engine            (always)         (never)
#      ssh-ca-server            (always)         (always)
#      dbeng11                  (always)         (never)
#      certifier-snmp-daemon    (if enabled)     (never)
#
#   NOTE: The script checks in engine.conf if snmp is enabled and starts it only
#         depending on that. This required changes to ssh-ca-start on the BE
#
# - make sure the required number of processes runs after using start option
#   (i.e. not more and not less, but only checking number, not program name)
# - make sure all processes get haltet after using stop option. That means in 
#   some cases -as e.g. frontend with lost TLS peer- that we will need to apply
#   SIGKILL after a timeout for SIGTERM. Timeout is set by variable "threshold"
#   in sub sh_halt_certifier
# - creation of lockfiles in /var/lock/subsys and pidfiles in /var/run as per lsb
#   Those are maintained by the init-script and not by the programs itself. 
#   The binaries maintain different, independent pidfiles in $mountdir/var 
# - some facilitating options as e.g. "debug" or "version" to show the built-nbr
#
#
# OPEN ISSUES:
# - when using "debug" the script doesnt hand back terminal-input to the initiating 
#   shell and its not yet found why that is
#
### BEGIN INIT INFO
# Provides:          /etc/init.d/(certifier || certifsub)
# Required-Start:    /sbin/syslogd /usr/sbin/snmpd
# Required-Stop:     
# Default-Start:     3 4 5
# Default-Stop:      0 1 2 6
# Short-Description: Start certifier services at boot time
# Description:       Start serviceS provided by certifier-engine/certifier server
### END INIT INFO
#
##############################################################################
#
unset valid
cRole=`basename $0`  ; [[ "${cRole:0:3}" == S[0-9]* ]] && cRole=${cRole:3}
prefixdir="/usr/local"
mountdir="${prefixdir}/${cRole}"
myversion="HAPF LSB init v1.2"
#
certifier_server_prog="${mountdir}/bin/ssh-ca-server"
certifier_engine_prog="${mountdir}/bin/ssh-ca-engine"
certifier_db="${mountdir}/sybase/certifier.db"
certifier_snmp_prog="${mountdir}/bin/certifier-snmp-daemon"
certifier_eng_conf="${mountdir}/conf/engine.conf"
#
#==========================================================================
c_validate() {
	
	rc="$(mount ${mountdir} &>/dev/null)$?"
	cat /proc/mounts|grep $cRole|cut -d' ' -f 2>/root/1.txt
	if  [ "$(cat /proc/mounts|grep $cRole|cut -d' ' -f 2)" = "${mountdir}" ]
	then
		export -p valid="yes"
		rc=0
	else
		echo "$cRole filesystem is not mounted here!"
		export -p valid="no"
		rc=4
	fi

	return $rc
}			

sh_get_version() {
	
	if   [ $cRole = "certifier" ] && [ "$valid" = "yes" ]; then
        	insta_env_engine="${mountdir}/bin/ssh-ca-env"
        	clibpath=`grep "LD_LIBRARY_PATH=" ${insta_env_engine}`
        	version=`export $clibpath; ${certifier_engine_prog} -v 2>/dev/null`
		( pidof ${certifier_engine_prog}-debug > /dev/null ) && version="$version (DEBUG)"
	elif [ $cRole = "certifsub" ] && [ "$valid" = "yes" ]; then
		insta_env_server="${mountdir}/ssh-ca-start"
        	clibpath=`grep "LD_LIBRARY_PATH=" ${insta_env_server}` 
		version=`export $clibpath; ${certifier_server_prog} -v 2>/dev/null`
		( pidof ${certifier_server_prog}-debug > /dev/null ) && version="$version (DEBUG)"
	else
        	echo "Can not determine Role"
		version=""
	fi
	
}
#
#==========================================================================
sh_get_processes() {

	estat="";dbline="";sstat="";astat=""			

	if [ $cRole = "certifier" ] ; then
		sstat=`pidof $(basename ${certifier_server_prog})`
		estat=`pidof $(basename ${certifier_engine_prog})`
		astat=`pidof $(basename ${certifier_snmp_prog})`
		dbline=`ps -ef |grep "${certifier_db}" |grep -v "grep"` 
		if [ ! -z "$dbline" ]; then
			dbstat=`echo $dbline|cut -d' ' -f2| grep "^[0-9]*$"`
		fi
	elif [ $cRole = "certifsub" ] ; then
		sstat=`pidof $(basename ${certifier_server_prog})`
	else
		echo "Unknown certifier role $cRole or filesystem not mounted"
		exit 4
	fi

	stat="$sstat $estat $dbstat $astat"
	Astat=( $stat )
	procs=${#Astat[@]}
		
	echo "$stat"
	return $procs
}
#
#==========================================================================
sh_halt_certifier() {

	c_validate && ${mountdir}/ssh-ca-stop
	sleep 5
	
	haveprocs=5;needprocs=0;
	let count=0; let threshold=60
	 	
	while [ $haveprocs -ne $needprocs ]
	do
		nstat=$( sh_get_processes )
		haveprocs=$?				

		if [ $count -le $threshold ]; then
			kill -TERM $nstat  > /dev/null 2>&1
		else
			kill -KILL $nstat  > /dev/null 2>&1
		fi

		sleep 1
		let count=$count+1
	done

	rstat="$( sh_get_processes &>/dev/null )$?"
	if [ "${rstat}" = "0" ]
	then	
		rm -f /var/lock/subsys/${cRole}  > /dev/null 2>&1
		rm -f /var/run/${cRole}.pid      > /dev/null 2>&1
		rm -f /var/run/ssh-ca-server.pid > /dev/null 2>&1
		rm -f /var/run/ssh-ca-engine.pid > /dev/null 2>&1
		rm -f /var/run/certifier-snmp-daemon.pid > /dev/null 2>&1
		rm -f /var/run/dbeng12.pid > /dev/null 2>&1
		rc=0
	else
		rc=1
	fi
	return $rc
}

#==========================================================================
c_usage() {
	sh_get_version
	echo "\

	usage: $0 {start|stop|restart|force-reload|debug|status|version}

	Expects to be able of using ssh-ca-start in $cRole directory.
        Certifier $version 
	" >&2
}
#==========================================================================

c_start() {
	
	c_status
	local status=$?
	sh_get_version
	
	if [ ${cRole} = "certifsub" ]; then needprocs=1; fi
	if [ ${cRole} = "certifier" ]; then 
			needprocs=3;
			(grep -i "snmp (enabled \"true\")" ${certifier_eng_conf} > /dev/null 2>&1) && needprocs=4	
	fi
	haveprocs=0

	 	
	case $status in
		0)
			echo "Insta is already running in role ${cRole} on this host!"
			rc=0
			;;
		1)
			echo "Error: Not all needed processes are running and PID-file exists!"
			rc=1
			;;
		2)
			echo "Error: Not all needed processes are running and subsys locked!"
			rc=2
			;;
		3)	
			if [ -d /var/lock/subsys ]; then
				touch /var/lock/subsys/${cRole}
				sync
			fi

			sh_get_version
			if [ ! -z "$debug" ]; then
				version="$version (DEBUG)\n"
			fi
			printf "Starting Insta ${cRole} ${version}"
                        corelimit="ulimit -S -c ${DAEMON_COREFILE_LIMIT:-0}"
			echo ${mountdir}/ssh-ca-start ${debug} | /bin/su ${certifier_user} &>/dev/null
				sleep 5
				while [ $haveprocs -ne $needprocs ]
				do
					nstat=$( sh_get_processes )
					haveprocs=$?				
					sleep 1
				done
				if [ -d /var/run ]; then
					echo $nstat > /var/run/${cRole}.pid 
					procarr=( $(echo $nstat) )
					[ ! -z "${procarr[0]}" ] && echo ${procarr[0]} > /var/run/ssh-ca-server.pid
					[ ! -z "${procarr[1]}" ] && echo ${procarr[1]} > /var/run/ssh-ca-engine.pid	
					[ ! -z "${procarr[2]}" ] && echo ${procarr[2]} > /var/run/certifier-snmp-daemon.pid
					[ ! -z "${procarr[3]}" ] && echo ${procarr[3]} > /var/run/dbeng12.pid
 				fi
			if [ -z "$debug" ]
			then 
				printf "\t\t[OK]\n"
			else
				printf "\n\n"
			fi
			rc=0
			;;
		*)
			echo "Error: Unclear Status for Insta role ${cRole} on this host"
			rc=1
			;;	
	esac
}
#==========================================================================
c_stop() {
	
	c_status
	local status=$?
	sh_get_version

	case $status in
		0)
			printf "Stopping Insta ${cRole} ${version}\t\t"
				sh_halt_certifier
			[ $? -eq 0 ] && printf "[OK]\n"	
			rc=3			
			;;
		1)
			printf "Trying to cleanly halt ${cRole} and remove lock/PID-files\t"
				sh_halt_certifier
			printf "[OK]\n"	
			rc=3			
			;;
		2)
			printf "Trying to cleanly halt ${cRole} and remove lock/PID-files\t"
				sh_halt_certifier
			printf "[OK]\n"	
			rc=3			
			;;
		3)	
			echo "Certifier seems to be cleanly stoped for role ${cRole} on this host"
			rc=3
			;;			
		*)
			printf "Trying to terminate all procs and clean status files\t\t"
				sh_halt_certifier
				c_status
				if [ $? -eq 3 ] ; then 
					printf "[OK]\n";
					rc=3
				else
					printf "[NOK!]\n";	
					rc=4
				fi			
			;;				
	esac
	return $rc
}

#==========================================================================		
c_status() {

	rc=4		
	nstat=$( sh_get_processes )
	local nprocs=$?

	case $nprocs in
		0)
			rc=3
			(ls -l /var/run/${cRole}.pid      > /dev/null 2>&1) && rc=1
			(ls -l /var/lock/subsys/${cRole}  > /dev/null 2>&1) && rc=2
			;;		
		1)
			if [  `pidof ssh-ca-server` ] && [ $cRole = "certifsub" ]; then 
				rc=0
			else
				rc=4
			fi
			;;
		2)	
			rc=4
			;;
		3)	
			rc=4
			if [ "${valid}" = "yes" ]; then
				entry="$(grep -i "snmp (enabled \"true\"" ${certifier_eng_conf}|tr -d [:blank:])"
				[ "${entry}" = "(snmp(enabled\"true\")" ] || rc=0
			else
				echo "stats unclear - can not determine if ${certifier_snmp_prog} shall be running"
			fi
			;;			
		4)	
			rc=4
			if [ "${valid}" = "yes" ]; then
				entry="$(grep -i "snmp (enabled \"true\"" ${certifier_eng_conf}|tr -d [:blank:])"
				[ "${entry}" = "(snmp(enabled\"true\")" ] && rc=0
			else
				echo "stats unclear - can not determine if ${certifier_snmp_prog} shall be running"
			fi
			;;
		*)
			rc=4				
			;;
	esac		
	
	return $rc
} 

#==========================================================================
#==========================================================================
debug="";rc=4
c_validate &>/dev/null && certifier_user=`cat ${mountdir}/lib/certifier_user` 2>/dev/null

case $1 in
	start)
		if [ $cRole = "certifsub" ]; then
			c_validate && c_stop 
			[ $? -eq 3 ] && c_start; rc=$?
		elif [ $cRole = "certifier" ]; then
			c_validate && c_start; rc=$?
		else
			echo "stats unclear - can not determine my role \"$cRole\""; rc=2
		fi
		;;
	stop)
		c_stop
		rc=$?
		;;
	restart)
		c_validate && c_stop
		if [ $? -eq 3 ]; then 
			c_start
			rc=$?
		fi
  		;;
	force-reload)
 		c_stop
 		sleep 3
		c_validate && c_start
		rc=$?
		;;
	status)
		c_validate && c_status
		rc=$?
		sh_get_version
	
		if [ $rc = 0 ]; then printf "Insta running OK in role ${cRole} ${version}\n"; fi	
		if [ $rc = 1 ]; then echo   "${cRole} dead and /var/run pid file exists"; fi			
		if [ $rc = 2 ]; then echo   "${cRole} dead but subsystem is locked"; fi			
		if [ $rc = 3 ]; then echo   "${cRole} is stopped"; fi
		if [ $rc = 4 ]; then
			echo   "Status is unclear, try to stop or restart certifier"
			( ps -fu certfier|grep debug > /dev/null ) && echo "Some processes seem to run in debug mode ..."
		fi
		;;
	version)
		if [ "${valid}" = "yes" ]
		then
			sh_get_version
			for prog in  ${certifier_engine_prog} ${certifier_server_prog}  ${certifier_snmp_prog} 
			do
				pvers=`export $clibpath; $prog -v 2>/dev/null;`
				if [ "$pvers"  ]; then
					echo "$prog : $pvers"
				fi
			done
		else
			echo "can not determine version of certifier software - maybe $cRole filesystem is not mounted"
		fi
		echo "/etc/init.d/$(basename $0) : ${myversion}"
		;;
	debug)
		printf "\n\n\tUsing debug will not return the control to this terminal unless you [ctrl-c]!\n"
		printf "\tProcesses keep running alive in debug mode after [ctrl-c]'ing this init script\n"
		printf "\tAlternatively you can use ${mountdir}/ssh-ca-start debug to run debug mode\n"
		printf "\n\tMIND: In neither case statusfiles are created in /var/run and /var/lock/subsys\n\n\n"
		
		debug="debug"
		c_stop
		sleep 3
		c_validate && c_start
		rc=$?	
     ;;
	*)
		c_usage
		rc=2
		;;
esac
exit $rc
