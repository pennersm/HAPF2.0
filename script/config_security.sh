#!/bin/bash
###########################################################################
# NSN INSTA HAPF2.1 RAPID SETUP CONFIG GENERATOR SCRIPT
#--------------------------------------------------------------------------
# Script default name   : ~script/config_security.sh
# Configure version     : mkks61f.pl
# Media set             : PF21I51RH63-12
# File generated        : 03.01.2013 MPe
#
###########################################################################
export -p  MYSELF="config_security.sh"
shf_logit "#-----------------------------------------------------------------"
shf_logit "starting to run script ${MYSELF}"
shf_logit "#-----------------------------------------------------------------"
#
ROLE=$1           ;  if [ -z ${ROLE}    ] ; then exit ; fi 
DRBDPRT="7789"    ;  # make sure this matches config_drbd arguments 
case ${ROLE} in
	be1|be2|SingleServer)
		CERTDIR="/usr/local/certifier"
	;;
	fe1|fe2|fe3|fe4)
		CERTDIR="/usr/local/certifsub"
	;;
esac
export -p SHELLOG=${INSTDIR}/${MYSELF}.${ROLE}.${NOW}.shell.log

shf_set_index
shf_logit "Using Role $ROLE in here, configure index $X"
shf_logit "${NOW} using ARGS: `echo $*`"
shf_logit "creating file to log command outputs: ${SHELLOG}"

declare -a CRONTAB
let i=1

cat /dev/null > ${SHELLOG}
echo "starting shellog for ${NOW} ${MYSELF} `date`" &>> ${SHELLOG}
set                &>> ${SHELLOG}
authconfig --test  &>> ${SHELLOG}
echo "=======================================================================" &>> ${SHELLOG}
#
####   PASSWORD POLICY   #####
#
MAXVALDAYS="90"
MINVALDAYS="7"
PWMINLEN="8"
PWEXPWARN="14"
PWRETRY="3"
PWLOCK="5"
PWUNLOCK="900"
PWDEEP="9"
SYSUID="500"
#--------------------------------------------------------------------------
#   user environments
#--------------------------------------------------------------------------
# root:
unset HSMPATH
[ "${USE_HSM[$X]}" = "yes" ] && HSMPATH=":/opt/nfast/bin"
FILE="/root/.bashrc"
shf_logit "preparing ${FILE} for ${ROLE} "
shf_tag_cffile ${FILE} "no-backup"
cat <<-ROOTBASHRC >> ${FILE}
	# .bashrc

	# Source global definitions
	if [ -f /etc/bashrc ]; then
		. /etc/bashrc
	fi
	
	# HAPF environment
	 : \${MAINFLAG:="/etc/hapf21.flag"}
	if [ -f \${MAINFLAG} ]; then
	        while read METAENV ; do
	                export -p \$(echo \${METAENV}|grep -v "\[\|#") &>/dev/null
	        done < \${MAINFLAG}
	fi

	# Certifier
	[ -f ${CERTDIR}/bin/ssh-ca-env ] && . ${CERTDIR}/bin/ssh-ca-env
	export -p LD_LIBRARY_PATH=/usr/local/certifier/lib:\$LD_LIBRARY_PATH	

	# User specific aliases and functions
	mx() { ps -ef |awk '((\$8 !~ /^\[/) && (\$3=="1"))'|grep -v /sbin/mingetty; }
	shf() { for PHASE1 in \${RUN[@]}; do source \${PHASE1}; done }
	alias lt="ls --group-directories-first -lti -c --color=none"
	alias snsn="source ${HAPFCF}/setnsnenv.sh"

	export -p TERM="xterm"
	export -p IC="${CERTDIR}"
	export -p CF="${HAPFCF}/configure.sh"
	export -p CFD="${HAPFCF}"	
	export -p PATH="/usr/bin:/bin:/sbin:/usr/sbin:${CERTDIR}/bin${HSMPATH}"
	PS1="[\t][\u@\h \W]# "; export PS1
ROOTBASHRC
shf_logit "set default environment in \"`ls ${FILE}`\""
chown root:root ${FILE}
chmod 644 ${FILE}
#--------------------------------------------------------------------------
# all:
FILE="/etc/skel/.bashrc"
shf_logit "preparing ${FILE} for ${ROLE}"
shf_tag_cffile ${FILE} "no-backup"
cat <<-DEFBASHRC >> ${FILE}
	# .bashrc

	# Source global definitions
	if [ -f /etc/bashrc ]; then
	        . /etc/bashrc
	fi
	
	# HAPF environment
	 : \${MAINFLAG:="/etc/hapf21.flag"}
	if [ -f \${MAINFLAG} ]; then
	        while read METAENV ; do
	                export -p \$(echo \${METAENV}|grep -v "\[\|#") &>/dev/null
	        done < \${MAINFLAG}
	fi
	
	# Certifier environment
	if [ -d "${CERTDIR}/lib" ]; then
	        export -p LD_LIBRARY_PATH=/usr/local/certifier/lib:\$LD_LIBRARY_PATH
	fi
	if [ -x "${CERTDIR}/lib/certifier_user" ] && [ -r "${CERTDIR}/var/odbc.ini" ] ; then
	         . ${CERTDIR}/bin/ssh-ca-env
	fi

	export -p TERM="xterm"
	export -p IC="${CERTDIR}"
	export -p CF="${HAPFCF}/configure.sh"
	export -p CFD="${HAPFCF}"
	# User specific aliases and functions
	alias ll='ls -ltrash --color=none' 
DEFBASHRC
shf_logit "set default environment in \"`ls ${FILE}`\""
chown root:root ${FILE}
chmod 644 ${FILE}
#
###########################################################################
YDIR="/etc/yum.repos.d"
FILE="${YDIR}/rhel-dvd.repo"
: ${MTDIR:="/media"}
rm -f ${YDIR}/* &>/dev/null
shf_tag_cffile ${FILE} "no-backup" 
cat <<-EOYUM >>${FILE}
	[rhel-dvd]
	name=Red Hat Enterprise Linux \$releasever - NSN HAPF2.1
	baseurl=file://${MTDIR}/Server
	enabled=1
	gpgcheck=0
EOYUM
chown root:root ${FILE}
chmod 0644 ${FILE}
shf_logit "repo created mount RedHat Server DVD to \"${MTDIR}\" if you need to use yum later"
###########################################################################
FILE="/etc/modprobe.d/disable_strangefs.conf"
shf_tag_cffile ${FILE} "no-backup"
cat <<-EOWHATFS >>${FILE}
	install freevxfs /bin/true
	install jffs2 /bin/true
	install hfs /bin/true
	install hfsplus /bin/true
	install squashfs /bin/true
	install udf /bin/true
EOWHATFS
chown root:root ${FILE}
chmod 0644 ${FILE}
shf_logit "blocked exotic filesystem drivers from being loaded here \"`ls -la ${FILE}`\""
###########################################################################
FILE="/etc/sysconfig/init"
shf_tag_cffile "${FILE}"
echo "umask 027" >> ${FILE}
chown root:root ${FILE}
chmod 0644 ${FILE}
shf_logit "set daemon umask \"$(grep umask ${FILE}|tr '\n' ' ')\""
#
FILE="/etc/security/limits.conf"
shf_tag_cffile "${FILE}"
echo "*    hard    core    0" >> ${FILE}
chown root:root ${FILE}
chmod 0644 ${FILE}
echo "fs.suid_dumpable = 0" >> /etc/sysctl.conf
shf_logit "defined hard-limit for core dumps in \"${FILE}\""
#
echo "kernel.exec-shield = 1"  >> /etc/sysctl.conf
echo "kernel.randomize_va_space = 1" >> /etc/sysctl.conf
shf_logit "kernel exec shield enabled"
#
###########################################################################
FILE="/etc/rc.d/init.d/reset-bond"
cp ${INSTDIR}/insta/reset-bond  ${FILE}
chmod 755  ${FILE}
chown root:root ${FILE}
shf_logit "created platform file in place \"`ls -l ${FILE}`\""

FILE="/etc/hapf21.d/clustertool.sh"
cp ${INSTDIR}/script/clustertool.sh ${FILE}
chmod 755  ${FILE}
chown root:root ${FILE}
shf_logit "created platform file in place \"`ls -l ${FILE}`\""

###########################################################################
FILE="/etc/inittab"

shf_logit "changing default runlevel in $FILE"
shf_tag_cffile ${FILE} "no-backup"
	cat <<-EOINIT >> ${FILE}
		id:4:initdefault:
	EOINIT
chown root:root ${FILE}
chmod 0644 ${FILE} 
shf_logit "`cat ${FILE}|wc -l` lines as : \"`ls -la ${FILE}`\""
shf_fshow ${FILE}
#
#---------------------------------------------------------------------------
#
shf_logit "setting up runlevels"
for serv in `/sbin/chkconfig |cut -f 1 -d ' '`
do
        /sbin/chkconfig --level 0123456 $serv off
done
/sbin/chkconfig --level 12345   auditd          on
/sbin/chkconfig --level 345     crond           on
/sbin/chkconfig --level 12345   ip6tables       off
/sbin/chkconfig --level 2345    iptables        on
/sbin/chkconfig --level 12345   netconsole      off
/sbin/chkconfig --level 12345   netfs           off
/sbin/chkconfig --level 2345    network         on
/sbin/chkconfig --level 345     ntpd            on
/sbin/chkconfig --level 12345   ntpdate         off
/sbin/chkconfig --level 12345   openhpid        off
/sbin/chkconfig --level 12345   postfix         off
/sbin/chkconfig --level 2345    reset-bond      on
/sbin/chkconfig --level 12345   rdisc           off
/sbin/chkconfig --level 12345   restorecond     off
/sbin/chkconfig --level 12345   rhnsd           off
/sbin/chkconfig --level 12345   rhsmcertd       off
/sbin/chkconfig --level 2345    rsyslog         on
/sbin/chkconfig --level 12345   saslauthd       off
/sbin/chkconfig --level 345     snmpd           on
/sbin/chkconfig --level 2345    sshd            on
/sbin/chkconfig --level 12345   sysstat         on
/sbin/chkconfig --level 12345   udev-post       on
#
if [ "${ROLE}" != "SingleServer" ] 
then
	/sbin/chkconfig --level 45      corosync        on
	/sbin/chkconfig --level 45      pacemaker       on
fi
#
if ( [[ "$ROLE" == "fe"[1-4] ]] || [ "$ROLE" = "SingleServer" ] ) && [ "${MONITOR_LDAP[$X]}" = "yes" ]
then
	/sbin/chkconfig --level 345     slapd           on
else
	/sbin/chkconfig --level 12345   slapd           off
fi
if [[ "${ROLE}" == "be"[1-2] ]] && [ "${SNMPV3CONV[$X]}" = "yes" ]
then
	/sbin/chkconfig --level 345     snmptrapd       on
	shf_logit "enabled additional service snmptrapd because trap-conversion is on and role ${ROLE}"
else
	/sbin/chkconfig --level 12345   snmptrapd       off
fi
# 
shf_fshow /sbin/chkconfig --list |grep ":on"
shf_logit "edited rc levels, now having `chkconfig --list |grep :on|wc -l` basic services on"
#
###########################################################################
# Delete useless files and directories as far as they are known
#
while read FILE; do if [ -e "${FILE}" ]; then
        TYPE="entry"
        if [ -f ${FILE} ]; then TYPE="regular file"; LSC="-l"; fi
        if [ -d ${FILE} ]; then TYPE="directory" ; LSC="-d" ; fi
        shf_logit "deleting useless $TYPE: \"$(ls ${LSC} ${FILE}|tr -s ' ')\""

        rc="$(rm -rf ${FILE} &>/dev/null)$?"
        [ "${rc}" = "0" ] || shf_logit "WARNING: Could not delete \"${FILE}\" rm-command exited \"${rc}\""
else
        shf_logit "WARNING: hapf is configured to delete \"${FILE}\" but could not find it here"
fi; done <<DELFILS
/usr/lib64/games
/usr/local/games
/usr/lib/games
/usr/share/games
/var/lib/games
/var/games
/var/nis
/var/yp
DELFILS
#
###########################################################################
#
shf_logit "setting up users and passwords in \"`ls -l /etc/passwd`\""
	NSNPW="\$6\$eyDFfDfF\$yLFT8G9SJ5mlj24waKApdO5kHzJj9.bijOk6YRkmg/fYhkgewkqySwUIEtkDj1XCAiCDWvYhNbklloIGoXxr60"
	useradd -b /home -m -c "Nokia Siemens Networks" -p ${NSNPW} -s /bin/bash -u 501 nsn  &>> ${SHELLOG}
	chage -d 0 nsn
shf_logit "added user \"nsn\" as `grep \"Nokia Siemens Networks\" /etc/passwd`" 
#	
#---------------------------------------------------------------------------
delete_user () {
	BADIES=$*
	for EUSER in ${BADIES[@]}
	do
		if ( grep ${EUSER} /etc/passwd )
		then
			userdel -fr ${EUSER} &>> ${SHELLOG}
			shf_logit "deleted user ${EUSER} because it is simply not needed"
		else
			shf_logit "user ${EUSER} already erased or never existed here"
		fi
	done
	unset BADIES
}
DELUSER=( lp uucp gopher games ftp )
delete_user ${DELUSER[@]}
#---------------------------------------------------------------------------
lock_user () {
        BADIES=$*
        for EUSER in ${BADIES[@]}
        do
		usermod -L ${EUSER} &>> ${SHELLOG}
		shf_logit "WARNING: locked user ${EUSER}, ${REASON}"	
        done
	unset BADIES
}

shf_logit "locking users with empty shadow-password if any are found"
	EMPTY=( `awk -F: '($2 == "") {print$1}' /etc/shadow` )
	export -p REASON="REASON: empty shadow-password"
	lock_user ${EMPTY[@]}
	unset EMPTY

shf_logit "locking users with empty passwords if any are found"
	EMPTY=( `awk -F: '($2 != "x") {print$1}' /etc/passwd` )
	export -p REASON="REASON: empty or unknown password field"
	lock_user ${EMPTY[@]}
	unset EMPTY

shf_logit "locking non-root users with uid 0 if any are found"
	EMPTY=( `awk -F: '($3 == "0") {print$1}' /etc/passwd|grep -v ^root` )
	export -p REASON="REASON: uid 0 is exclusively for root here!"
	lock_user ${EMPTY[@]}
	unset EMPTY
#
#---------------------------------------------------------------------------
check_nisend () {
	FILE=$1
	if ( grep "^+:" $FILE >/dev/null )
	then
		shf_logit "WARNING: found NIS escape characters in \"`ls -l ${FILE}`\", removing"
		shf_fshow cat ${FILE}
		cat ${FILE}|grep -v "^+:" > ${FILE}.${ROLE}.${NOW}
		cat ${FILE}.${ROLE}.${NOW} > ${FILE}
		rm -f ${FILE}.${ROLE}.${NOW}
	fi
}	
NISIN=( /etc/passwd /etc/group /etc/shadow )
check_nisend ${NISIN[@]} 
#
#---------------------------------------------------------------------------
#
FILE="/etc/login.defs"
shf_logit "preparing ${FILE} for ${ROLE}"
shf_tag_cffile ${FILE} "no-backup"
shf_logit "PW-policy elements set: ${MAXVALDAYS} max-pwd-validity, ${MINVALDAYS} min-pwd-validity, ${PWMINLEN} min-pwd-length, warning will be ${PWEXPWARN} days before expiry."  

	cat <<-LOGDEFS >> $FILE
		MAIL_DIR        /var/spool/mail
		PASS_MAX_DAYS   ${MAXVALDAYS}
		PASS_MIN_DAYS   ${MINVALDAYS}
		PASS_MIN_LEN    ${PWMINLEN}
		PASS_WARN_AGE   ${PWEXPWARN}
		UID_MIN         ${SYSUID} 
		UID_MAX         60000
		GID_MIN         ${SYSUID} 
		GID_MAX         60000
		CREATE_HOME     yes
		UMASK           077
		USERGROUPS_ENAB yes
		ENCRYPT_METHOD  SHA512
		ENV_PATH        PATH=/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/sbin:${CERTDIR}/bin
		LOGIN_RETRIES   5
		LOGIN_TIMEOUT   45
		LASTLOG_ENAB    yes
		LOG_OK_LOGINS   yes
		FAILLOG_ENAB    yes
		SU_NAME         su
		SULOG_FILE      /etc/sulog
		MAIL_CHECK_ENAB no
	LOGDEFS
	chown root:root ${FILE}
        chmod 0644 ${FILE} 
        shf_logit "`cat ${FILE}|wc -l` lines as : `ls -la ${FILE}`"
	shf_fshow ${FILE}
#
#---------------------------------------------------------------------------
#
FILE="/etc/libuser.conf"
shf_logit "preparing ${FILE} for ${ROLE}"
shf_tag_cffile ${FILE} "no-backup"

        cat <<-LIBUSR >> $FILE
		[import]
		login_defs = /etc/login.defs
		default_useradd = /etc/default/useradd

		crypt_style = sha512
		modules = files shadow
		create_modules = files shadow	

		[userdefaults]
		LU_USERNAME = %n
		LU_GIDNUMBER = %u

		[groupdefaults]
		LU_GROUPNAME = %n
		
		[files]
		
		[shadow]
		
		[ldap]
		
		[ldap]
	LIBUSR
        chown root:root ${FILE}
        chmod 0644 ${FILE}
        shf_logit "`cat ${FILE}|wc -l` lines as : `ls -la ${FILE}`"
        shf_fshow ${FILE}
#
#---------------------------------------------------------------------------
#
FILE="/etc/pam.d/system-auth-ac"
shf_logit "preparing ${FILE} for ${ROLE}"
shf_tag_cffile ${FILE} "no-backup"
shf_logit "PW-policy elements set: ${PWRETRY} max-pwd-retries, ${PWMINLEN} min-pwd-length, ${PWDEEP} new pwds before repeat, ${PWLOCK} mistypes before ${PWUNLOCK} sec autolock."

sed '1i\
#%PAM-1.0' ${FILE} > $FILE.${ROLE}.${NOW}
mv -f $FILE.${ROLE}.${NOW} ${FILE}

	cat <<-QOPASS >> ${FILE}
		auth        required      pam_tally2.so deny=${PWLOCK} onerr=fail unlock_time=${PWUNLOCK}
		auth        required      pam_env.so
		auth        sufficient    pam_unix.so nullok try_first_pass
		auth        requisite     pam_succeed_if.so uid >= ${SYSUID} quiet
		auth        required      pam_deny.so

		account     required      pam_tally2.so
		account     required      pam_unix.so
		account     sufficient    pam_localuser.so
		account     sufficient    pam_succeed_if.so uid < ${SYSUID} quiet
		account     required      pam_permit.so

		password    requisite     pam_cracklib.so try_first_pass retry=${PWRETRY} minlen=${PWMINLEN} dcredit=-1 ucredit=-1 ocredit=-1 lcredit=-1
		password    sufficient    pam_unix.so sha512 shadow nullok try_first_pass use_authtok remember=${PWDEEP}
		password    required      pam_deny.so

		session     optional      pam_keyinit.so revoke
		session     required      pam_limits.so
		session     [success=1 default=ignore] pam_succeed_if.so service in crond quiet use_uid
		session     required      pam_unix.so
	QOPASS
        chown root:root ${FILE}
        chmod 0644 ${FILE}
        shf_logit "`cat ${FILE}|wc -l` lines as : `ls -la ${FILE}`"
        shf_fshow ${FILE}
#
#---------------------------------------------------------------------------
################################################################################
#
#   Configure networking additional security / hardening
#
#www.linuxhomenetworking.com/wiki/index.php/Quick_HOWTO_:_Ch14_:_Linux_Firewalls_Using_iptables
#---------------------------------------------------------------------------
shf_logit "setup iptables Firewall - general rules"
FILE="/etc/sysconfig/iptables"
shf_logit "preparing ${FILE} for ${ROLE}"
shf_tag_cffile ${FILE} "no-backup"
#
#============================================================
#  ------------- Firewallpolicy for Backends -------------
#============================================================
#
: ${ICLOGPORT:=515}
unset HSMLINE
if [ "${USE_HSM[$X]}" = "yes" ] 
then
	HSMLINE="-A INPUT -m state --state NEW -m tcp -p tcp --dport ${HARDSER_PORT[$X]} -j ACCEPT"
fi

if [ ${ROLE} = "be1" -o ${ROLE} = "be2" ]
then
	cat <<-BEFW >> ${FILE}
		*filter
		:INPUT ACCEPT [0:0]
		:FORWARD ACCEPT [0:0]
		:OUTPUT ACCEPT [0:0]

		-A INPUT -i lo -j ACCEPT
		-A OUTPUT -o lo -j ACCEPT

		-A OUTPUT -m state --state NEW,ESTABLISHED -j ACCEPT
		-A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
		-A INPUT -p icmp -j ACCEPT

		-A INPUT -p udp --sport 123 --dport 123 -j ACCEPT
		-A INPUT -p udp --dport ${HBMCPORT[$X]} -j ACCEPT
		-A INPUT -p udp --dport 161 -j ACCEPT
		
		-A INPUT -m state --state NEW -m tcp -p tcp --dport 22   -j ACCEPT
		-A INPUT -m state --state NEW -m tcp -p tcp --dport 7001 -j ACCEPT
		-A INPUT -m state --state NEW -m tcp -p tcp --dport 8083 -j ACCEPT
		-A INPUT -m state --state NEW -m tcp -p tcp --dport ${DRBDPRT} -j ACCEPT
		${HSMLINE}
	
		-A INPUT -j REJECT --reject-with icmp-host-prohibited	
		-A FORWARD -j REJECT --reject-with icmp-host-prohibited
		COMMIT
	BEFW
fi
#
#============================================================
#  ------------- Firewallpolicy for Frontends -------------
#============================================================
#
if [ ${ROLE} = "fe1" -o ${ROLE} = "fe2" -o ${ROLE} = "fe3" -o ${ROLE} = "fe4" ]
then
	cat <<-FEFW >> ${FILE}
		*filter
		:INPUT ACCEPT [0:0]
		:FORWARD ACCEPT [0:0]
		:OUTPUT ACCEPT [0:0]

		-A INPUT -i lo -j ACCEPT
		-A OUTPUT -o lo -j ACCEPT	
	
		-A OUTPUT -m state --state NEW,ESTABLISHED -j ACCEPT
		-A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
		-A INPUT -p icmp -j ACCEPT
		
		-A INPUT -p udp --sport 123 --dport 123 -j ACCEPT
		-A INPUT -p udp --dport ${HBMCPORT[$X]} -j ACCEPT
		-A INPUT -p udp --dport 161 -j ACCEPT
		
		-A INPUT -m state --state NEW -m tcp -p tcp --dport 22   -j ACCEPT
		-A INPUT -m state --state NEW -m tcp -p tcp --dport 7001 -j ACCEPT
		-A INPUT -m state --state NEW -m tcp -p tcp --dport 389  -j ACCEPT
		-A INPUT -m state --state NEW -m tcp -p tcp --dport 8080:8090 -j ACCEPT
		
		-A INPUT -j REJECT --reject-with icmp-host-prohibited
		-A FORWARD -j REJECT --reject-with icmp-host-prohibited
		COMMIT
	FEFW
fi
#============================================================
#  ------------- Firewallpolicy for SingleServer -------------
#============================================================
if [ ${ROLE} = "SingleServer" ]
then
	cat <<-SSFW >> ${FILE}
		*filter
		:INPUT ACCEPT [0:0]
		:FORWARD ACCEPT [0:0]
		:OUTPUT ACCEPT [0:0]
		
		-A INPUT -i lo -j ACCEPT
		-A OUTPUT -o lo -j ACCEPT

		-A OUTPUT -m state --state NEW,ESTABLISHED -j ACCEPT
		-A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
		-A INPUT -p icmp -j ACCEPT
		
		-A INPUT -p udp --sport 123 --dport 123 -j ACCEPT
		-A INPUT -p udp --dport 161 -j ACCEPT
		
		-A INPUT -m state --state NEW -m tcp -p tcp --dport 22   -j ACCEPT
		-A INPUT -m state --state NEW -m tcp -p tcp --dport 7001 -j ACCEPT
		-A INPUT -m state --state NEW -m tcp -p tcp --dport 389  -j ACCEPT
		-A INPUT -m state --state NEW -m tcp -p tcp --dport 8080:8090 -j ACCEPT
		
		-A INPUT -j REJECT --reject-with icmp-host-prohibited
		-A FORWARD -j REJECT --reject-with icmp-host-prohibited
		COMMIT
	SSFW
fi
#============================================================
#
        chown root:root ${FILE}
        chmod 0644 ${FILE}
        shf_logit "`cat ${FILE}|wc -l` lines as : `ls -la ${FILE}`"
        shf_fshow ${FILE}
	shf_logit "WARNING: You should check and finetune your FW policy before production use"

	/etc/init.d/iptables stop &>> ${SHELLOG}
	shf_logit "restarted iptables to status : `/etc/init.d/iptables status`"
#
#--------------------------------------------------------------------------
#   HSM sync
#--------------------------------------------------------------------------
if [ "${USE_HSM[$X]}" = "yes" ]
then
	FILE="/usr/sbin/wrap-rfs-sync.sh"
	shf_tag_cffile "${FILE}" "no-backup"
	sed -i "1 i #!/bin/bash" ${FILE}
	cat  <<-HSMSYNC >> ${FILE}
		HSM_PATH="/opt/nfast/kmdata/local"
		#
		PERM[1]="certfier:nfast 0660 key_pkcs11_*"
		PERM[2]="root:nfast 0644 module*"
		PERM[3]="root:nfast 0644 card*"
		PERM[4]="root:nfast 0644 world"
		PERM[5]="root:nfast 2775 sync-store"
		#
		#-------------------------------------------------------------------------------
		rc=99
		#
		rc1="\$(/opt/nfast/bin/rfs-sync --update &>/dev/null)\$?"
		sleep 2; sync ; sleep 1
		rc2="\$(/opt/nfast/bin/rfs-sync --commit &>/dev/null)\$?"
		#
		let i=1;for i in \$(seq 1 \${#PERM[@]}); do
		        FPARM=( $(echo \${PERM[\$i]}) )
		        chown \${FPARM[0]} \${HSM_PATH}/\${FPARM[2]} &>/dev/null
		        chmod \${FPARM[1]} \${HSM_PATH}/\${FPARM[2]} &>/dev/null
		done
		#
		rc=( \$rc1 ) || ( \$rc2 )
		logger -p user.debug -t rfs-sync "HSM synchronisation exited with status \"\${rc}\""
	HSMSYNC
	chmod 0750 ${FILE}
	chown root:root ${FILE}
	shf_logit "prepared wrapper for hsm synchronisation \"$(ls -l ${FILE})\""

	[ "${ROLE}" = "be1" ] && CRTIM="1-56/5 * * * *"
	[ "${ROLE}" = "be2" ] && CRTIM="3-58/5 * * * *"

	CRONTAB[$i]="${CRTIM} /usr/sbin/wrap-rfs-sync.sh &>/dev/null \n"
	let i=$i+1
fi
#
#--------------------------------------------------------------------------
#   Kernel networking parameters
#--------------------------------------------------------------------------
shf_logit "setup kernel networking parameters"
FILE="/etc/sysctl.conf"
shf_tag_cffile "${FILE}"
sed -i '/^$/d' ${FILE}

ctlsys() {
	SETIT="no"
	KPMSET="$(echo $*|tr -d [:blank:])"
	KPMNAM="$(echo ${KPMSET}|cut -d'=' -f 1)"
	KPMVAL="$(echo ${KPMSET}|cut -d'=' -f 2)"
	pex="$(sysctl -q ${KPMNAM} &>/dev/null)$?"
	( grep "${KPMSET}" ${FILE} &>/dev/null ) || SETIT="yes"

	if [ $pex -eq 0 ] && [ ! -z "${KPMNAM}" ] && [ ! -z "${KPMSET}" ] 
	then
		shf_logit "set kernel parameter : `sysctl -w ${KPMSET}`"
		[ "${SETIT}" = "yes" ] && echo "${KPMNAM} = ${KPMVAL}" >> ${FILE}
	else
		shf_logit "WARNING: seems to be an unknown kernel parameter \"${KPMNAM}\""
	fi
}
	ctlsys "net.ipv4.ip_forward = 0"
	ctlsys "net.ipv4.conf.all.send_redirects = 0"
	ctlsys "net.ipv4.conf.default.send_redirects = 0"
	ctlsys "net.ipv4.conf.all.accept_source_route = 0"
        ctlsys "net.ipv4.conf.all.accept_redirects = 0"
        ctlsys "net.ipv4.conf.all.secure_redirects = 0"
        ctlsys "net.ipv4.conf.default.accept_source_route = 0"
        ctlsys "net.ipv4.conf.default.accept_redirects = 0"
        ctlsys "net.ipv4.conf.default.secure_redirects = 0"
        ctlsys "net.ipv4.icmp_echo_ignore_broadcasts = 1"
        ctlsys "net.ipv4.icmp_ignore_bogus_error_responses = 1"
        ctlsys "net.ipv4.tcp_syncookies = 1"
        ctlsys "net.ipv4.conf.all.rp_filter = 1"
        ctlsys "net.ipv4.conf.default.rp_filter = 1"
        ctlsys "net.ipv4.conf.all.log_martians = 0"

#	ctlsys "net.ipv6.conf.default.router_solicitations = 0"
#	ctlsys "net.ipv6.conf.default.accept_ra_rtr_pref = 0"
#	ctlsys "net.ipv6.conf.default.accept_ra_pinfo = 0"
#	ctlsys "net.ipv6.conf.default.accept_ra_defrtr = 0"
#	ctlsys "net.ipv6.conf.default.autoconf = 0"
#	ctlsys "net.ipv6.conf.default.dad_transmits = 0"
#	ctlsys "net.ipv6.conf.default.max_addresses = 1"
chown root:root ${FILE}
chmod 644 ${FILE}		
################################################################################
#
# Configure legal message to display upon login
#
#---------------------------------------------------------------------------
FILE="/etc/motd"
cat <<-EMOTD > ${FILE} 

##########################################################################
  NOTICE TO USERS

  THIS IS A PRIVATE COMPUTER SYSTEM. It is for authorized use only.
  Users (authorized or unauthorized) have no explicit or implicit
  expectation of privacy.

  Any or all uses of this system and all files on this system may
  be intercepted, monitored, recorded, copied, audited, inspected,
  and disclosed to authorized site and law enforcement personnel,
  as well as authorized officials of other agencies, both domestic
  and foreign.  By using this system, the user consents to such
  interception, monitoring, recording, copying, auditing, inspection,
  and disclosure at the discretion of authorized site personnel.

  Unauthorized or improper use of this system may result in
  administrative disciplinary action and civil and criminal penalties.
  By continuing to use this system you indicate your awareness of and
  consent to these terms and conditions of use.   LOG OFF IMMEDIATELY
  if you do not agree to the conditions stated in this warning.

#########################################################################

EMOTD
shf_logit "added \"`cat ${FILE}|wc -l`\" lines of legal message into \"`ls -l ${FILE}`\""
################################################################################
#
# Configure AIDE intrusion detection
#
#---------------------------------------------------------------------------
FILE="/etc/aide.conf"
shf_tag_cffile "${FILE}" "no-backup"

cat <<-AIDECONF >>${FILE}
        @@define DBDIR /var/lib/aide
        @@define LOGDIR /var/log/aide
        database=file:@@{DBDIR}/aide.db.gz
        database_out=file:@@{DBDIR}/aide.db.new.gz
        gzip_dbout=yes
        verbose=5
        report_url=file:@@{LOGDIR}/aide.log
        report_url=stdout

        ALLXTRAHASHES = sha1+rmd160+sha256+sha512+tiger
        EVERYTHING = R+ALLXTRAHASHES
        NORMAL = R+rmd160+sha256
        DIR = p+i+n+u+g+acl+selinux+xattrs
        PERMS = p+i+u+g+acl+selinux
        LOG = p+u+g+selinux
        LSPP = R
        DATAONLY =  p+n+u+g+s+acl+selinux+xattrs+md5+sha256+rmd160+tiger

        #-----------------------------------------------
        /boot                    NORMAL
        /bin                     NORMAL
        /sbin                    NORMAL
        /lib                     NORMAL
        /lib64                   NORMAL
        /opt                     NORMAL
        /usr                     NORMAL
        /root                    NORMAL
        !/usr/tmp

        !${CERTDIR}/var
	${CERTDIR}/sybase/certifier.db    PERMS
	${CERTDIR}/sybase/certifier.log   PERMS
        #-----------------------------------------------

        /etc    PERMS
        !/etc/mtab
        !/etc/.*~
        /etc/exports  NORMAL
        /etc/fstab    NORMAL
        /etc/passwd   NORMAL
        /etc/group    NORMAL
        /etc/gshadow  NORMAL
        /etc/shadow   NORMAL
        /etc/security/opasswd   NORMAL
        /etc/hosts.allow   NORMAL
        /etc/hosts.deny    NORMAL
        /etc/sudoers NORMAL
        /etc/skel NORMAL
        /etc/logrotate.d NORMAL
        /etc/resolv.conf DATAONLY
        /etc/securetty NORMAL
        /etc/profile NORMAL
        /etc/bashrc NORMAL
        /etc/bash_completion.d/ NORMAL
        /etc/login.defs NORMAL
        /etc/profile.d/ NORMAL
        /etc/X11/ NORMAL
        /etc/yum.conf NORMAL
        /etc/yum/ NORMAL
        /etc/yum.repos.d/ NORMAL

        /etc/audit/ LSPP
        /etc/libaudit.conf LSPP
        /etc/cron.allow LSPP
        /etc/cron.deny LSPP
        /etc/cron.d/ LSPP
        /etc/cron.daily/ LSPP
        /etc/cron.hourly/ LSPP
        /etc/cron.monthly/ LSPP
        /etc/cron.weekly/ LSPP
        /etc/crontab LSPP
        /etc/hosts LSPP
        /etc/sysconfig LSPP
        /etc/inittab LSPP
        /etc/grub/ LSPP
        /etc/rc.d LSPP
        /etc/login.defs LSPP
        /etc/securetty LSPP
        /etc/hosts LSPP
        /etc/ld.so.conf LSPP
        /etc/localtime LSPP
        /etc/sysctl.conf LSPP
        /etc/modprobe.conf LSPP
        /etc/modprobe.d LSPP
        /etc/pam.d LSPP
        /etc/security LSPP
        /etc/aliases LSPP
        /etc/postfix LSPP
        /etc/ssh/sshd_config LSPP
        /etc/ssh/ssh_config LSPP
        /etc/issue LSPP
        /etc/issue.net LSPP
        #-----------------------------------------------------
        /var/log   LOG
        /var/run/utmp LOG
        !/var/log/sa
        !/var/log/aide.log

        /var/log/lastlog >
        /var/spool/cron/root LSPP
        !/var/log/and-httpd

        !/opt/nfast/log/ncsnmpd.pid
        !/opt/nfast/log/hardserver.pid
	
        /root/\..* PERMS
AIDECONF
chmod 600 ${FILE}
chown root:root ${FILE}
shf_logit "created aide configuration for ${ROLE} at ${HOSTNAME[X]} in \"`ls -l ${FILE}`\""

INITAIDE="/root/init_aide.sh"
cp -f ${INSTDIR}/script/init_aide.sh ${INITAIDE}
chmod 700 ${INITAIDE} 
chown root:root ${INITAIDE}
#---------------------------------------------------------------------------
# AIDE must be initialized, question is when. Doing it here would not make much sense
# chose any of the 3 YES/NO switches below but make sure to use only one ... 
# -------------------------------------------------------------------------
#MIND: this is the easiest to do but requires users to read and obey 
# IT INFLUENCES SCP COMMANDS! BETTER LEAVE IT
TRIGANOY="NO"
if [ "${TRIGANOY}" != "NO" ] ; then
	FILE="/root/.do_aide_anoy"
#	echo "${FILE}" >> /root/.bashrc ; dont do that here as it messes up later needed sftp
	echo "#!/bin/bash" >> ${FILE}
	shf_tag_cffile ${FILE}
	cat <<-AIDEANOY >>${FILE}
		trap "" 2 20
		clear
		printf "\n\n\tPLEASE INIT AIDE ADVANCED INTRUSION DETECTION ENVIRONMENT"
		printf "\n\tRun the following command to complete AIDE initialisation:"
		printf "\n\n\t        \"${INITAIDE} --interactive\"\n\t"
		lastn="\`tail -n 1 ${FILE}|cut -d' ' -f2\`"
		sed '\$d' < ${FILE} > ${FILE}.tmp
		chmod 0700 ${FILE}.tmp
		mv -f ${FILE}.tmp ${FILE}
		let lastn=\$lastn+5
		echo "# \${lastn}" >> ${FILE}
		let n=1
		while [ \$n -le \$lastn ]
		do
		        printf "!"
		        sleep 1
		        let n=\$n+1
		done
		printf "\n"
		# -50
	AIDEANOY
	chown root:root ${FILE}
	chmod 0700 ${FILE}
	shf_logit "friendly reminder to complete aide initialisation left in \"`ls -l ${FILE}`\""
fi
#---------------------------------------------------------------------------
#MIND: if you TRIGAUTO you wont be able to auto-add each others ssh keys into authorized_keys files
TRIGAUTO="NO"
if [ "${TRIGAUTO}" != "NO" ] ; then
	echo "/root/.bashrc" > /root/.do_aide_init
	echo "source /root/init_aide.sh" >> /root/.bashrc
	shf_logit "left root-trap to start aide db init in \"`ls -l /root/.do_aide_init`\""
else
	shf_logit "aide should be (re)-initialized after install e.g. with \"/root/init_aide.sh --interactive\""
fi
#---------------------------------------------------------------------------
#MIND: if you INSTINIT you have to unmount all USB drives during init is ongoing or it will take very long
#      further its a somewhat queer idea to init IDS before we are done
INSTINIT="NO"
if [ "${INSTINIT}" != "NO" ] ; then
	shf_logit "initializing aide database can take up to 5 minutes be patient"
	rm -rf /tmp/aide.init &>/dev/null
	aide --init > /tmp/aide.init &&
	rc=$? ; if [ ${rc} -eq 0 ]
	then
		sync
		MYDB=$(grep "^### AIDE database at" /tmp/aide.init |awk '{print$3}' )
		shf_logit "initialized aide db \"`echo ${MYDB}`\""

		mv -f /var/lib/aide/aide.db.gz /var/lib/aide/aide.db.gz.old &>/dev/null
		cp -f /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz
		shf_logit "aide database file in place \"`ls -l /var/lib/aide/aide.db.gz`\""

		sha1sum /var/lib/aide/aide.db.gz > ${INSTDIR}/aide_db_integrity
		cp ${INSTDIR}/aide_db_integrity ${MTDIR}
		shf_logit "aide database file checksum created \"`cat ${INSTDIR}/aide_db_integrity`\"" 
	else
		shf_logit "aide database initialisation exited with \"$rc\" - check manually after installation"
fi ; fi
#---------------------------------------------------------------------------
if [ ! -r /etc/aide.conf ]
then
        shf_logit "can not find aide  config file - fix this manually"
else
        CRONTAB[$i]="30 03 * * 7 /usr/sbin/aide --check &>/dev/null \n"
        let i=$i+1
fi
#
################################################################################
#
# Configure cron and system cron jobs
#
#---------------------------------------------------------------------------
FILE="/etc/sysconfig/crond"
shf_logit "preparing ${FILE} for ${ROLE}"
shf_tag_cffile $FILE

cat <<-CRONARGS >> ${FILE}
	CRONDARGS="-m off -s"
CRONARGS
chmod 644 ${FILE}
chown root:root ${FILE}
shf_logit "changed default start arguments for crond in \"`ls -l $FILE`\""

rm -rf /etc/cron.deny
rm -rf /etc/cron.allow
shf_logit "only user root can run cron jobs unless you add cron.allow or cron.deny files"
#---------------------------------------------------------------------------
#---------------------------------------------------------------------------
FILE="${INSTDIR}/script/watch_snmpd.sh"
if [ ! -r ${FILE} ] 
then
	shf_logit "can not find watch_snmpd.sh - platform supervision will be incomplete unless you fix this manually"
else
	cp -f ${FILE} /usr/sbin/watch_snmpd
	chmod 500 ${FILE}
	chown root:root ${FILE}
	shf_logit "copied platform file into place \"`ls -l ${FILE}`\""
	CRONTAB[$i]="*/5 * * * * /usr/sbin/watch_snmpd &>/dev/null \n"
	let i=$i+1
fi
#---------------------------------------------------------------------------
#---------------------------------------------------------------------------
FILE="/etc/logrotate.conf"
if [ ! -r ${FILE} ]
then
	shf_logit "can not find logwatch config file - fix this manually"
else
	CRONTAB[$i]="59 23 * * * /usr/sbin/logrotate -v -s /var/run/logrotate.status -f /etc/logrotate.conf &>/var/log/last_logrotate.log \n"
	let i=$i+1
fi
#---------------------------------------------------------------------------
FREQUENCY="daily" ; KEEP="12" ; LARCD="/var/log/arch"
mkdir ${LARCD} ; chmod 700 ${LARCD} 
shf_logit "created archive directory for rotated logs \"$(ls -dl ${LARCD})\""
#---------------------------------------------------------------------------
shf_tag_cffile "${FILE}" "no-backup"
	cat <<-LOGRMAIN >>${FILE} 
	${FREQUENCY}
	rotate ${KEEP}
	olddir ${LARCD}
	create
	dateext
	nomail
	delaycompress
	compress
	include /etc/logrotate.d
LOGRMAIN
chmod 0644 ${FILE}
chown root:root ${FILE}
shf_logit "created general config for logrotate normal logs will be rotated ${FREQUENCY} and kept ${KEEP}"
#---------------------------------------------------------------------------
FILE="/etc/logrotate.d/wtmp"
shf_tag_cffile "${FILE}" "no-backup"
	cat <<-WTMPL >>${FILE}
	/var/log/wtmp {
	        notifempty
	        nomissingok
	        monthly
	        create 0664 root utmp
	        minsize 1M
	        rotate 1
	}
	/var/log/btmp {
	        notifempty
	        nomissingok
	        monthly
	        create 0600 root utmp
	        minsize 1M
	        rotate 1
        }
WTMPL
chmod 0644 ${FILE}
chown root:root ${FILE}
shf_logit "added rotation rule for wtmp logs in logrotate.d - frequency monthly and keep 1"
#---------------------------------------------------------------------------
FILE="/etc/logrotate.d/syslog"
shf_tag_cffile "${FILE}" "no-backup"
        cat <<-SYSLOG >>${FILE}
	/var/log/cron
	/var/log/messages
	/var/log/secure
	{
	        sharedscripts
	        postrotate
	        /usr/bin/killall -HUP rsyslogd 
	        /bin/chmod 0644 /var/log/messages
	        endscript
	}
SYSLOG
chmod 0644 ${FILE}
chown root:root ${FILE}
shf_logit "added rotation rule for syslogs in logrotate.d - rotation ${FREQUENCY} and kept ${KEEP}"
#---------------------------------------------------------------------------
FILE="/etc/logrotate.d/corosync"
if [ ${ROLE} != "SingleServer" ]; then
	shf_tag_cffile "${FILE}" "no-backup"
	cat <<-CORLOG >>${FILE}
	/var/log/corosync.log
	{
	        missingok
	        create 0660 root root
	        postrotate
	        endscript
	}
CORLOG
chmod 0644 ${FILE}
chown root:root ${FILE}
shf_logit "added rotation rule for corosync.log in logrotate.d - rotation ${FREQUENCY} and kept ${KEEP}"
fi
#---------------------------------------------------------------------------
if [ "${USE_HSM[$X]}" = "yes" ] ; then
	FILE="/etc/logrotate.d/hsmlog"
	HARDSLOG="/var/log/hardserver.log"
	HARDSPID="/var/run/hardserver.pid"
	HSNMPLOG="/var/log/ncsnmpd.log"
	HSNMPPID="/var/run/ncsnmpd.pid"
	RFSYNLOG="/var/log/rfs-sync.log"

	shf_tag_cffile "${FILE}" "no-backup"
	chmod 0664 ${FILE}
	chown root:root ${FILE}
	cat <<-HSMRULE >>${FILE}
		${HARDSLOG}	
		{
		        monthly
		        copytruncate
		}
		${RFSYNLOG}
		{
		        monthly
		        create 0640 root nfast
		        postrotate
		        endscript
		}
HSMRULE
shf_logit "added rotation rules for hsm hardserver in \"$(ls -l ${FILE})\""
fi
if [ "${HARDSER_SNMP_TRAP[X]}" = "yes" ] ; then
	cat <<-HSMLOG >>${FILE}
		/var/log/ncsnmpd.log
		{
		        monthly
		        create 0640 root nfast
		        postrotate
		        /etc/init.d/nc_snmpd restart
		        endscript
		}		

HSMLOG
shf_logit "added rotation rule for hsm snmpagent in \"$(ls -l ${FILE})\""
fi
#
#---------------------------------------------------------------------------
FILE="/etc/logrotate.d/insta"
shf_tag_cffile "${FILE}" "no-backup"
chmod 0644 ${FILE}
chown root:root ${FILE}
if [[ ${ROLE} != fe[1,2,3,4] ]]; then ENGLOG="/var/log/engine.log"; fi 
cat <<-ICLRULE >>${FILE}
	${ENGLOG}
	/var/log/server.log
	        {
	        sharedscripts
	        create 600 certfier daemon
	        postrotate
	        /usr/bin/killall -HUP rsyslogd
	        endscript
	        }
ICLRULE
sync ; sed -i '/^$/d' ${FILE}
shf_logit "added rotation rule for certifier debug in \"$(ls -l ${FILE})\""
#---------------------------------------------------------------------------
FILE="/etc/logrotate.d/aide"
[ -f "${FILE}" ] && rm -f ${FILE}
shf_tag_cffile "${FILE}" "no-backup"
chmod 0644 ${FILE}
chown root:root ${FILE}
cat <<-AIROT >> ${FILE}
	/var/log/aide/*.log {
	        weekly
		notifempty
	        missingok
	        rotate 4
	        minsize 100k
	        copytruncate
	        compress
	}
AIROT
shf_logit "added rotation rule for aide in \"$(ls -l ${FILE})\""
#---------------------------------------------------------------------------
FILE="${INSTDIR}/script/daily_backup.sh"
if [ ! -r ${FILE} ]
then
        shf_logit "can not find daily_backup.sh - routine backup can not be done unless you fix this manually"
else
        cp -f ${FILE} /usr/sbin/daily_backup.sh
        chmod 500 ${FILE}
        chown root:root ${FILE}
        shf_logit "copied platform file into place \"`ls -l ${FILE}`\""
        CRONTAB[$i]="55 03 * * * /usr/sbin/daily_backup.sh &>/dev/null \n"
        let i=$i+1
fi
if [[ "${ROLE}" == "be"[1,2] ]] || [ "${ROLE}" = "SingleServer" ]
then
	FILE="${HAPFCF}/.dbacc_init"	
	touch ${FILE}
	chown root:root 
	chmod 0400 ${FILE}
	chattr +i ${FILE}
	shf_logit "created empty gui-access info file - add gui \"username:password\" for unattended db-backups"
fi
#---------------------------------------------------------------------------
FILE="/usr/sbin/watch_performance"
cp -f "${INSTDIR}/script/watch_performance.sh" ${FILE}
chmod 500 ${FILE}
chown root:root ${FILE}
shf_logit "copied platform file into place \"`ls -l ${FILE}`\""
PERFDIR="$(grep -m 1 ": \${LOGDIR:=" ${FILE}|sed -e 's/^[[:space:]]*//'|cut -d'"' -f2)"
if ( mkdir -p ${PERFDIR} &>/dev/null ) ; then
	CRONTAB[$i]="1 0 * * * ${FILE} --start-observ &>/dev/null \n"
	let i=$i+1
	chmod 755 ${PERFDIR}
	shf_logit "created directory for performance measurements \"`ls -ld ${PERFDIR}`\""
fi
#---------------------------------------------------------------------------
FILE="/etc/sysconfig/hapf2-watch_fs"
shf_tag_cffile "${FILE}"
shf_logit "preparing filesystem watch script"
PARTS=( `awk '($1=="part"){print$2}' ${INSTDIR}/ks-${ROLE}.cfg` )
for FS in "${PARTS[@]}"
do 
	if [ "${FS}" != "swap" ]
	then
		echo "${FS}=\"hapf-partition\"" >> ${FILE}
		shf_logit "will watch files on ${FS}"
	else
		shf_logit "skipping swap partition from fs watch"
	fi
done

cat <<-SPECFILES >>${FILE}
#---------------Files with special permissions	
	/usr/bin/ssh-agent="allow_SUID"
	/usr/bin/write="allow_SUID"
	/usr/bin/newgrp="allow_SUID"
	/usr/bin/sudo="allow_SUID"
	/usr/bin/chsh="allow_SUID"
	/usr/bin/chfn="allow_SUID"
	/usr/bin/wall="allow_SUID"
	/usr/bin/sudoedit="allow_SUID"
	/usr/bin/passwd="allow_SUID"
	/usr/bin/gpasswd="allow_SUID"
	/usr/bin/chage="allow_SUID"
	/usr/bin/crontab="allow_SUID"
	/usr/libexec/utempter/utempter="allow_SUID"
	/usr/libexec/openssh/ssh-keysign="allow_SUID"
	/usr/libexec/pt_chown="allow_SUID"
	/usr/sbin/postqueue="allow_SUID"
	/usr/sbin/userhelper="allow_SUID"
	/usr/sbin/postdrop="allow_SUID"
	/usr/sbin/usernetctl="allow_SUID"
	/bin/umount="allow_SUID"
	/bin/su="allow_SUID"
	/bin/ping="allow_SUID"
	/bin/ping6="allow_SUID"
	/bin/mount="allow_SUID"
	/sbin/unix_chkpwd="allow_SUID"
	/sbin/netreport="allow_SUID"
	/sbin/pam_timestamp_check="allow_SUID"
SPECFILES
chmod 600 ${FILE}
chown root:root ${FILE}
shf_logit "created platform file in place \"`ls -l ${FILE}`\""

FILE="${INSTDIR}/script/watch_fs.sh"
if [ ! -r ${FILE} ]
then
	shf_logit "can not find watch_fs.sh - platform supervision will be incomplete unless you fix this manually"
else
	cp -f ${FILE} /usr/sbin/watch_fs
	chmod 500 ${FILE}
	chown root:root ${FILE}
	shf_logit "copied platform file into place \"`ls -l ${FILE}`\""
	CRONTAB[$i]="45 22 * * * /usr/sbin/watch_fs &>/dev/null \n"
	let i=$i+1	
fi
#---------------------------------------------------------------------------
# track that loging did never go off in case you might see longer periods of silence
FILE="/usr/bin/tictoc"
shf_tag_cffile "${FILE}"
sed -i '1i #!/bin/bash' ${FILE}

cat <<-TICTOC >>${FILE}
	TAG="TickTock"
	PRI="auth.notice"
	MESSAGE=" Another hour wrapped in peace: \$(date)"
	logger -p \$PRI -t \$TAG \$MESSAGE
TICTOC

chown root:root ${FILE}
chmod 550 ${FILE}
CRONTAB[$i]="0 * * * * ${FILE} &>/dev/null \n"
shf_logit "created tictoc indicator as heartbeat in case of silent periods"

#---------------------------------------------------------------------------
# disable anacron usage
FILE="/etc/cron.hourly/jobs.deny"
shf_tag_cffile "${FILE}"
echo "0anacron" >>${FILE}
chown root:root ${FILE}
chmod 622 ${FILE}
shf_logit "creating denial entry for anacron: \"$(ls -l $FILE)\""
while read FILE; do
	[ -f ${FILE} ] && (rm -rf ${FILE}; shf_logit "deleted anacron job \"${FILE}\"")
done << DELANA
/etc/cron.daily/logrotate
/etc/cron.daily/rhsmd
DELANA
#
#---------------------------------------------------------------------------
# define the jobs to /var/spool/cron/root cronjobs
#---------------------------------------------------------------------------
FILE="/root/system-cronjobs"
echo   "#-------------------------------default HAPF21 cronjobs-----------------------" >${FILE}
	let i=1
	while [ $i -le ${#CRONTAB[@]} ]
	do
		if [ ! -z "${CRONTAB[$i]}" ]
		then
			printf "${CRONTAB[$i]}"                                        >>${FILE}
			shf_logit "added system crontab for root \"`printf "${CRONTAB[$i]}"`\""
		fi
	let i=$i+1
	done
echo   "#---------------------------------end HAPF21 cronjobs-------------------------">>${FILE}
chmod 644 ${FILE}
chown root:root ${FILE}
cp -p ${FILE} /var/spool/cron/root
shf_logit "configured \"`cat /var/spool/cron/root|grep -v ^#|wc -l`\" cronjobs for root  in \"`ls -l /var/spool/cron/root`\""
/etc/init.d/crond restart &>/dev/null; rc=$?
shf_logit "crond restarted with rc=\"$rc\" now running \"`ps --no-headers -fC crond|tr --squeeze-repeats " "`\""
#
shf_logit "#-----------------------------------------------------------------"
shf_logit "leaving script ${MYSELF}"
shf_logit "#-----------------------------------------------------------------"

