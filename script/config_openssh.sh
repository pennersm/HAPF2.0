#!/bin/bash
###########################################################################
# NSN INSTA HAPF2.1 RAPID SETUP CONFIG GENERATOR SCRIPT
#--------------------------------------------------------------------------
# Script default name   : ~script/config_openssh.sh
# Configure version     : mkks62f.pl
# Media set             : PF21I52RH63-12
# File generated        : 03.01.2013 MPe
#
###########################################################################
export -p  MYSELF="config_openssh.sh"
shf_logit "#-----------------------------------------------------------------"
shf_logit "starting to run script ${MYSELF}"
shf_logit "#-----------------------------------------------------------------"
#
ROLE=$1           ;  if [ -z ${ROLE}    ] ; then exit ; fi
export -p SHELLOG=${INSTDIR}/${MYSELF}.${ROLE}.${NOW}.shell.log

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
SSHCFDIR="/etc/ssh"
SSHCF[0]="${SSHCFDIR}/sshd_config"
SSHCF[1]="${SSHCFDIR}/ssh_config"
SSHCF[2]="${SSHCFDIR}/ssh_host_dsa_key"
SSHCF[3]="${SSHCFDIR}/ssh_host_dsa_key.pub"
SSHCF[4]="${SSHCFDIR}/ssh_host_key"
SSHCF[5]="${SSHCFDIR}/ssh_host_key.pub"
SSHCF[6]="${SSHCFDIR}/ssh_host_rsa_key"
SSHCF[7]="${SSHCFDIR}/ssh_host_rsa_key.pub"
SSHCF[8]="${SSHCFDIR}/moduli"


if [ -d ${SSHCFDIR} ]
then
	shf_logit "directory ${SSHCFDIR} generated during Installation ${NOW}: `ls -l /etc |grep ssh`"
	shf_fshow ${SSHCFDIR}
else
	shf_logit "WARNING: Must create ${SSHCFDIR} myself, check your sshd options for cf file locations"
	mkdir -p /etc/ssh
fi
for FILE in 1 2 4 6 8 
do
	if [ -f ${SSHCF[$FILE]} ]
	then
		chmod 0500 ${SSHCF[$FILE]}
		chown root:root ${SSHCF[$FILE]}
	else
		shf_logit "WARNING: missing file  ${SSHCF[$FILE]}"
	fi
done
for FILE in 0 3 5 7
do
	if [ -f ${SSHCF[$FILE]} ]
	then
		chmod 0544 ${SSHCF[$FILE]}
		chown root:root ${SSHCF[$FILE]}
	else
		shf_logit "WARNING: missing file  ${SSHCF[$FILE]}"
	fi
done
##############################################################################
FILE=${SSHCF[0]}
if [ ! -z "${OAMHAIP[$X]}" ]; then
	OAMIPLINE="ListenAddress ${OAMHAIP[$X]}"
else
	unset OAMIPLINE
fi
shf_logit "preparing ${FILE} for ${ROLE}"
shf_tag_cffile ${FILE} "no-backup"

	cat <<-EOSSHD >> ${FILE}
		Port 22
		AddressFamily inet
		Protocol 2
		ListenAddress ${IPADDReth0[$X]}
		${OAMIPLINE}

		SyslogFacility AUTH
		LogLevel VERBOSE

		LoginGraceTime 30s
		PermitRootLogin no
		StrictModes yes
		MaxAuthTries 6
		MaxSessions 10

		RSAAuthentication no
		PubkeyAuthentication yes
		AuthorizedKeysFile     .ssh/authorized_keys
		AuthorizedKeysCommand none

		RhostsRSAAuthentication no
		HostbasedAuthentication no
		IgnoreUserKnownHosts yes
		IgnoreRhosts yes

		PermitEmptyPasswords no
		PasswordAuthentication no
		ChallengeResponseAuthentication no

		KerberosAuthentication no

		GSSAPIAuthentication no
		UsePAM yes

		AcceptEnv LANG LC_CTYPE LC_NUMERIC LC_TIME LC_COLLATE LC_MONETARY LC_MESSAGES
		AcceptEnv LC_PAPER LC_NAME LC_ADDRESS LC_TELEPHONE LC_MEASUREMENT
		AcceptEnv LC_IDENTIFICATION LC_ALL LANGUAGE
		
		AllowAgentForwarding no
		AllowTcpForwarding no
		GatewayPorts no
		X11Forwarding no

		PrintMotd yes
		PrintLastLog yes
		TCPKeepAlive yes
		UseLogin no

		UsePrivilegeSeparation yes
		PermitUserEnvironment no
		Compression delayed
		ClientAliveInterval 0
		ClientAliveCountMax 3
		ShowPatchLevel no
		UseDNS no
		PidFile /var/run/sshd.pid
		MaxStartups 10
		PermitTunnel no
		Subsystem       sftp    /usr/libexec/openssh/sftp-server

# We recommend you comment the following lines
# to enforce keybased authentication 
Match User nsn
       PasswordAuthentication yes
Match User root
      PasswordAuthentication yes     
      PermitRootLogin yes
#       
EOSSHD
chown root:root ${FILE}
chmod 0600 ${FILE}
shf_logit "`cat ${FILE}|wc -l` lines as : `ls -la ${FILE}`"
shf_fshow ${FILE}
shf_logit "WARNING: SSH PasswordAuthentication enabled for \"root\" and \"nsn\" in $FILE, you'd better change that"
#
##############################################################################
#
	HOMESSH="/root/.ssh"
	SSHUSER="root"
	CARIER="$(shf_usbdsk)"
	MPOINT="$(cat /proc/mounts|awk -v P="${CARIER}" '($1==P){print$2}')"
	: ${MPOINT:="${MTDIR}"}
	shf_logit "detected usb installmedia \"${CARIER}\" at \"${MPOINT}\"" 
#
##############################################################################
make_new_keys() {
	if [ -d  ${HOMESSH} ]
	then
		tar -cvf /root/old_.ssh.tar ${HOMESSH} &>/dev/null
		shf_logit "savecopied existing ssh data to : `ls -la /root/old_.ssh.tar`"
		shf_fshow tar -tf /root/old_.ssh.tar
		rm -f /root/.ssh/*
	fi
	
	KHASH=`ssh-keygen -t dsa -f ${HOMESSH}/id_dsa -N "" |grep "root@"`
  	shf_logit "generated new SSH DSA key for root: ${KHASH}" 
	cp -f ${HOMESSH}/id_dsa.pub ${HOMESSH}/authorized_keys
  	shf_logit "after adding new key now \"`cat ${HOMESSH}/authorized_keys|wc -l`\" keys  in : `ls -la ${HOMESSH}/authorized_keys`" 

	ssh -o StrictHostKeyChecking=no -o PasswordAuthentication=no ${IPADDReth0[$X]} -- uname   &>/dev/null
	ssh -o StrictHostKeyChecking=no -o PasswordAuthentication=no ${HOSTNAME[$X]} -- uname   &>/dev/null
	shf_logit "currently \"`cat ${HOMESSH}/known_hosts|wc -l`\" lines for known keys in : \"`ls -la ${HOMESSH}/known_hosts`\""
}
if [ ${ROLE} = "be1" -o ${ROLE} = "fe1" -o ${ROLE} = "fe3" -o ${ROLE} = "SingleServer" ]
then
	make_new_keys
fi
#
if [ ${ROLE} = "be1" -o ${ROLE} = "fe1" -o ${ROLE} = "fe3" ]
#-----------------------------------------------------------------------------
then
	shf_logit "prepare transfer of SSH keys to HA peer ${IPADDReth0[$Y]}"

	CARCH="${INSTDIR}/sshconfig-${SSHUSER}.${IPADDReth0[$X]}.${NOW}.tar"
	ARCH=`basename ${CARCH}`
	THERE=`grep " ${MPOINT} " /etc/mtab|awk '{print $2}'`
        PART=`grep " ${MPOINT} " /etc/mtab|awk '{print $1}'`	
	
	tar -Ppcf ${CARCH} ${HOMESSH}
	shf_fshow tar -tf ${CARCH}
	shf_logit "preserved keys in archive: \"`ls -la ${CARCH}`\""

	if [ ${REMOTE_INSTALL[$X]} = "no" ]
	then
		shf_logit "local-install option is chosen, transfer peer ssh keys via USB pendrive"

		if [ "${CARIER}" = "${PART}" ] && [ "${MPOINT}" = "${THERE}" ] && [ -w "${MPOINT}" ]
		then
			rm -f ${MPOINT}/${ARCH}
			sleep 1
			cp  -f ${CARCH} ${MPOINT}
			sync
			shf_fshow ${MPOINT}
			shf_logit "will transport keys in ${CARIER}: \"`ls -la ${MPOINT}|grep ${ARCH}`\""
		else
			shf_logit "WARNING: Can not access the USB pendrive on ${CARIER}"
			shf_logit "WARNING: Will not be able to transport SSH-keys of ${SSHUSER} to peer via USB"
			shf_logit "WARNING: Look for archive ${CARCH} and copy manually to \"${HOMESSH}\" at \"${HOSTNAME[$Y]}\""
		fi
	elif [ ${REMOTE_INSTALL[$X]} = "yes" ]
	then
		shf_logit "remote-install option is chosen, transfer peer ssh keys via ssh"

		echo -n "ssh-dss AAAAB3NzaC1kc3MAAACBANkJzKl51TRZDITH2UUf7jgrFTF3bmklfV042V4kHvEJ8BAVh8SUri5zCHpNJYjs" >>${HOMESSH}/authorized_keys &&
		echo -n "n/bxlxKjy74UU2tNnTP8eQJdlk0MO5nQ9NNCMQm2uMJbSuzh04wVAsfWm7obQ12fow/m5lFc+EVxLzmclxSYzVXc5wQV" >>${HOMESSH}/authorized_keys &&
		echo -n "7L26xRsslmkbrN39AAAAFQCAXWraktn0Iap8l0UtIvwd0I6JVwAAAIEAqm9YTRovIgrlpgeTGUb+OdZ2hEsgrp3IlSK0" >>${HOMESSH}/authorized_keys &&
		echo -n "5+IEjvHVS0SEBDgtigKiqY2TcU6nhpKDjAUPOysoKy/LyJSqXj5um1/Jmygk6bLCKr8QNbLgBBf/hduzTRqSavEoQS52" >>${HOMESSH}/authorized_keys &&
		echo -n "BM0Ozc37Dr0LzlWc04OzYRADyswr+JwbaUa6q1fhNYAAAACBALncx1iF28Vad/XnuSV8M00c21ov9n20GEN7TlBA1iTH" >>${HOMESSH}/authorized_keys &&
		echo -n "Ui+QVhPHMpthjoYaMJbF4j7V0KbNO1ymAocFM1mLzJEVjMuhT3X/FNNNxXAG/j1LoLnwLue8vg0LFkBmDo5bv/EIybfW" >>${HOMESSH}/authorized_keys &&
		echo -n "FeJ4rth1QFSRTBjt0q4iPBZiwy2gxLy1h10B root@factory-key" >>${HOMESSH}/authorized_keys && sleep 1 ; sync
		echo "" >>${HOMESSH}/authorized_keys
		shf_logit "temporarily added factory key to local authorized-keys now having \"`cat ${HOMESSH}/authorized_keys|wc -l`\" keys"	
	else
		shf_logit "WARNING: Can not determine installation method"
		shf_logit "Look for archive ${CARCH} and copy manually to \"${HOMESSH}\" at \"${HOSTNAME[$Y]}\""
	fi
fi
#
#-----------------------------------------------------------------------------		
#
if [ ${ROLE} = "be2" -o ${ROLE} = "fe2" -o ${ROLE} = "fe4" ]
then
	FAIL="UNSPECIFIC"
        CARCH="${MPOINT}/sshconfig-${SSHUSER}.${IPADDReth0[$Y]}.${NOW}.tar"
        MYARCH=`basename ${CARCH}`
	unpack() {
		tar -Ppxvf ${INSTDIR}/${MYARCH}
		if [ $? -eq 0 ]
		then
			shf_logit "unpacked archive `ls ${INSTDIR}/${MYARCH}`"
			shf_fshow tar -tf ${INSTDIR}/${MYARCH}
			return 0
		else
			FAIL="ARCBROKE"
		fi
	}
	#---------------------------------------------------------------------

	if [ -f ${CARCH} ] && [ "${REMOTE_INSTALL[$X]}" = "no" ]
        then
		shf_logit "local-install option is chosen, transfer peer ssh keys via USB pendrive"
                cp -rf ${CARCH} ${INSTDIR}
		unpack

		#----------#		
		[ $? -eq 0 ] && FAIL="NO"
		#----------#

		cp -p ${HOMESSH}/id_dsa ${HOMESSH}/old-peer-key
		TEMPID="${HOMESSH}/old-peer-key"
		shf_logit "temporarily saved peers private key for syncing: \"`ls -la ${TEMPID}`\""
		

	elif [ "${REMOTE_INSTALL[$X]}" = "yes" ] && ( ping -I ${IPADDReth0[$X]} -n -c 5 -q ${IPADDReth0[$Y]} )
	then
		shf_logit "remote-install option is chosen, transfer peer ssh keys via ssh"

		if [ ! -d ${HOMESSH} ]
		then
			mkdir -p ${HOMESSH}
			chmod 700 ${HOMESSH}
			chown root:root ${HOMESSH}
			shf_logit "created directory \"`ls -la /root|grep .ssh`\""
		fi 	
		
		TEMPID="${HOMESSH}/factory-key" ; rm -f ${TEMPID} 2>/dev/null; sync
		echo "-----BEGIN DSA PRIVATE KEY-----" > ${TEMPID} &&
		echo "MIIBvAIBAAKBgQDZCcypedU0WQyEx9lFH+44KxUxd25pJX1dONleJB7xCfAQFYfE" >> ${TEMPID} &&
		echo "lK4ucwh6TSWI7J/28ZcSo8u+FFNrTZ0z/HkCXZZNDDuZ0PTTQjEJtrjCW0rs4dOM" >> ${TEMPID} &&
		echo "FQLH1pu6G0Ndn6MP5uZRXPhFcS85nJcUmM1V3OcEFey9usUbLJZpG6zd/QIVAIBd" >> ${TEMPID} &&
		echo "atqS2fQhqnyXRS0i/B3QjolXAoGBAKpvWE0aLyIK5aYHkxlG/jnWdoRLIK6dyJUi" >> ${TEMPID} &&
		echo "tOfiBI7x1UtEhAQ4LYoCoqmNk3FOp4aSg4wFDzsrKCsvy8iUql4+bptfyZsoJOmy" >> ${TEMPID} &&
		echo "wiq/EDWy4AQX/4Xbs00akmrxKEEudgTNDs3N+w69C85VnNODs2EQA8rMK/icG2lG" >> ${TEMPID} &&
		echo "uqtX4TWAAoGBALncx1iF28Vad/XnuSV8M00c21ov9n20GEN7TlBA1iTHUi+QVhPH" >> ${TEMPID} &&
		echo "MpthjoYaMJbF4j7V0KbNO1ymAocFM1mLzJEVjMuhT3X/FNNNxXAG/j1LoLnwLue8" >> ${TEMPID} &&
		echo "vg0LFkBmDo5bv/EIybfWFeJ4rth1QFSRTBjt0q4iPBZiwy2gxLy1h10BAhQ5Rutk" >> ${TEMPID} &&
		echo "Ya4/ETaOLRq4OeOBEC55ww==" >> ${TEMPID} &&
		echo "-----END DSA PRIVATE KEY-----" >> ${TEMPID} &&
		echo "" >> ${TEMPID}
		sync

		shf_fshow ${TEMPID}
		chmod 600 ${TEMPID}
		shf_logit "temporarily placed factory ID: \"`ls -la ${TEMPID}`\""
		
		let REACHPEER=1 ; let n=0 ; let PTO=180 ; let intrv=30
		while [ ${REACHPEER} -ne 0  ] && [ ${n} -lt ${PTO} ]
		do
			echo " --------------------------------------------------------" &>>${SHELLOG}
			echo "trying to reach ssh on peer" &>>${SHELLOG}
			REACHPEER=$(ssh -o StrictHostKeyChecking=no -o PasswordAuthentication=no -i ${TEMPID} root@${IPADDReth0[$Y]} -- uname -n &>/dev/null )$? &>>${SHELLOG}
			#---------------------#
			[ ${REACHPEER} -eq 0  ] && shf_logit "ssh peer responded ... continuing HAPF setup in remote option" && FAIL="NO" && break
			#---------------------#
			let ttw=${PTO}-$n ; let n=$n+30
			shf_logit "waiting for ssh peer to respond ... ${n} of ${PTO} seconds to timeout gone"
			sleep $intrv
			[ $n -ge ${PTO} ] && shf_logit "timeout  Restart installation of ${HOSTNAME[$X]} after ${IPADDReth0[$Y]} is up with ssh service" && FAIL="SSHTO"
		done

		eval 'scp -B -v -o StrictHostKeyChecking=no -o PasswordAuthentication=no -i ${TEMPID} root@${IPADDReth0[$Y]}:${INSTDIR}/${MYARCH}  ${INSTDIR} ' &>>${SHELLOG}
		sync &&
		shf_logit "fetched ssh keys from peer: \"`ls -la ${INSTDIR}/${MYARCH}`\""
		unpack
		
        else
		FAIL="NOMETHOD"
        fi

	case ${FAIL} in
		"NO")
		#--------------------------------------------------------------------------------------------
			rm -f ${HOMESSH}/id_dsa ; rm -f ${HOMESSH}/id_dsa.pub
			KHASH=`ssh-keygen -t dsa -f ${HOMESSH}/id_dsa -N "" |grep "root@"`
			shf_logit "generated new SSH DSA key for root: ${KHASH}"

			cat ${HOMESSH}/id_dsa.pub >> ${HOMESSH}/authorized_keys
			shf_logit "after adding new key now \"`cat ${HOMESSH}/authorized_keys|wc -l`\" keys  in : `ls -la ${HOMESSH}/authorized_keys`"

			ssh -v -o StrictHostKeyChecking=no -o PasswordAuthentication=no ${IPADDReth0[$X]} -- uname   &>/dev/null
			ssh -v -o StrictHostKeyChecking=no -o PasswordAuthentication=no ${HOSTNAME[$X]} -- uname   &>/dev/null
			shf_logit "currently \"`cat ${HOMESSH}/known_hosts|wc -l`\" lines for known keys in : \"`ls -la ${HOMESSH}/known_hosts`\""

			eval 'scp -B -v -o StrictHostKeyChecking=no -o PasswordAuthentication=no -i ${TEMPID} ${HOMESSH}/known_hosts root@${IPADDReth0[$Y]}:${HOMESSH}/known_hosts'  &>>${SHELLOG}
			eval 'scp -B -v -o StrictHostKeyChecking=no -o PasswordAuthentication=no -i ${TEMPID} ${HOMESSH}/authorized_keys root@${IPADDReth0[$Y]}:${HOMESSH}/authorized_keys '  &>>${SHELLOG}
			if [ "${ROLE}" = "be2" ] 
			then
				ssh -v -o StrictHostKeyChecking=no -o PasswordAuthentication=no root@${IPADDReth0[$Y]} <<-EOSSH >>${SHELLOG}
					cd ${HOMESSH}
					chmod 644 authorized_keys
					chown root:root authorized_keys
					chmod 644 known_hosts
					chown root:root known_hosts
				EOSSH
				rc=$(rm -f ${TEMPID})$?
				shf_logit "cleanup of factory key on local host ended with exit \"${rc}\""
			fi
		#--------------------------------------------------------------------------------------------
		;;
		"SSHTO")
			shf_logit "exiting HAPF remote setup of ${HOSTNAME[Y]} with failure due to ssh timeout"
			shf_debug_break
		;;
		"NOMETHOD")
			shf_logit "WARNING: Problem with specified installation method"
			shf_logit "WARNING: must have ${CARIER} mounted on ${MPOINT} for this step in local install"
			shf_logit "WARNING: or must have connection on eth0 between ${IPADDReth0[$X]} and  ${IPADDReth0[$Y]}"
			shf_logit "WARNING: You will have to copy and unpack ${CARCH} manually among peers"
			shf_fshow echo "exception testing"
			shf_fshow df -h
			shf_fshow dmesg
			shf_fshow ${MPOINT}
			shf_fshow ifconfig -a
			shf_fshow netstat -r
			shf_debug_break
		;;
		"ARCBROKE")
			shf_logit "WARNING: ssh connect OK but I can unpack the archive \"${MYARCH}\""
			shf_logit "WARNING: installation would not succeed without that, exiting"
			shf_debug_break
		;;
		*)
			shf_logit "WARNING: general and unspecified problem fetching the ssh keys from peer"
			shf_logit "WARNING: installation would not succeed without that, exiting"
			shf_debug_break
		;;
	esac
fi
#
#-----------------------------------------------------------------------------
#
rc="$(service sshd restart &>/dev/null	)$?"
shf_logit "restarted openssh daemon using chkconfig and received exit \"${rc}\""
shf_logit "#-----------------------------------------------------------------"
shf_logit "leaving script ${MYSELF}"
shf_logit "#-----------------------------------------------------------------"

