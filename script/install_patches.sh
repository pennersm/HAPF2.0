#!/bin/bash
###########################################################################
# NSN INSTA HAPF2.1 RAPID SETUP CONFIG GENERATOR SCRIPT
#--------------------------------------------------------------------------
# Script default name   : ~script/install_patches.sh
# Configure version     : mkks62f.pl
# Media set             : PF21I52RH63-12
# File generated        : 03.01.2013 MPe
#
###########################################################################
export -p  MYSELF="install_patches.sh"
if [ "`whoami`" != "root" ]
then
        logger -p user.info -t ${MYSELF} "attempt to run ${MYSELF} as \"`whoami`\" was rejected"
        echo "only root is allowed to install patches - failed attempt will be logged"
        exit 1
fi
#----------------------------------------------------------------------------------
myexit() { 
	if [ "${EXITYPE}" = "soft" ]  
	then
		exit $1 
	else
		kill -TERM $$	
	fi
}
#----------------------------------------------------------------------------------
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

#----------------------------------------------------------------------------------
shf_say() {
        HMS=$(date  +%H:%M:%S)
        HST=$(uname -n)
        MSG="$*"

        TEXT="[${HMS}][${HST}] : ${MSG}"
        [ "${NOPHASE}" = "yes" ] && echo ${TEXT}       |tee -a ${PATCHLOG}
	[ "${NOPHASE}" = "no"  ] && shf_logit "${MSG}" |tee -a ${PATCHLOG}
}
#--------------------------------------------------------------------------------
usage() {
	echo "   Tool to install patches on HAPF2.1"
	echo "   Interactive use only allows 1 option:"
	echo "        -install [ARCHIVE]"
	echo "   Will install all rpms in directory [ARCHIVE] using \"-Uvh\""
	echo "   and will produce a logfile in the HAPF2.1 configuration directory"
	echo ; echo
	myexit 1
}
####################################################################################################
#----------------------------------------------------------------------------------
NUMARGS="$#" ; ALLARGS="$*" ; unset NOPHASE INSTALL PATCHARC ; EXITYPE="hard"
while [ $# != 0 ]
do
	case $1 in
		fe1|fe2|fe3|fe4|be1|be2|SingleServer)
			ROLE=$1; NOPHASE="no"; INSTALL="yes"; EXITYPE="soft"
			
			if [ "${NUMARGS}" -ne 1 ] ;  then
				shf_say "Role specific involvement only works during HAPF2.1 rapid setup - exiting"
				logger -p user.info -t ${MYSELF} "attempt to run hsm-setup in role mode rejected"
				myexit 1
			fi
		;;
		-install)
			NOPHASE="yes";	INSTALL="yes"; EXITYPE="hard"; PATCHARC=$2 	
			shift
		;;
		*)
			usage
		;;
esac; shift; done
#---------------------------------------------------------------------------------
[ "${NUMARGS}" -eq 0 ] && usage
#----------------------------------------------------------------------------------
if [ "${NOPHASE}" = "yes" ] ; then
        : ${MAINFLAG:="/etc/hapf21.flag"}
        if [ ! -f ${MAINFLAG} ]
        then
                echo "not a complete HAPF2.1 installation"
                logger -p user.info -t ${MYSELF} "ERROR: stopping attempt to install patches incomplete environment"
                myexit 2
        else
                source ${MAINFLAG}
                ROLE="${GENROLE}"
		for PHASE1 in ${RUN[@]} ;do source ${PHASE1} ; done
	shf_say "sourced HAPF2.1 environment for ${ROLE} of installation ${NOW}"
        fi
fi
#----------------------------------------------------------------------------------
: ${HAPFCF:="/etc/hapf21.d"}
: ${INSTDIR:="/tmp/Installmedia"}
: ${TMPDIR:="/tmp"}
: ${CLEAN_ON_EXIT:="yes"}
: ${CLEAN_TMP:="yes"}
: ${PATCHARC:="${INSTDIR}/rhpatches"}

SESSION="$(date +%d%m%Y%H%M)"
PATCHLOG="${HAPFCF}/patchlog/patchsession-${NOW}-on-${SESSION}"
[ -d ${HAPFCF}/patchlog ] || (mkdir ${HAPFCF}/patchlog; chown root:root ${HAPFCF}/patchlog)
[ -e ${PATCHARC}  ] || { shf_say "can not find patch archive ${PATCHARC} - exiting"; myexit 1; }

shf_tag_cffile ${PATCHLOG} "no-backup" &>/dev/null
#----------------------------------------------------------------------------------
GPGK[1]="/etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release"
GPGK[2]="/etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-legacy-rhx"
GPGK[3]="/etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-legacy-release"
GPGK[4]="/etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-legacy-former"
shf_say "#-----------------------------------------------------------------"
shf_say "starting to run script ${MYSELF}"
shf_say "#-----------------------------------------------------------------"
shf_index
shf_say "Using Role $ROLE in here, configure index $X"
shf_say "${NOW} using ARGS: ${ALLARGS}"
#
shf_say "patch install script for ${ROLE} having NOPHASE=\"${NOPHASE}\" INSTALL=\"${INSTALL}\""
#----------------------------------------------------------------------------------
shf_say "examining source ${PATCHARC}..."
TARFILE=$( ls ${PATCHARC}|egrep -i ".tar.gz$|.tgz$|.tar$"|wc -l)
RPMFILE=$( ls ${PATCHARC}|egrep -i ".rpm$|.RPM$"|wc -l)  

if [ "${TARFILE}" -eq 1 ] && [ "${RPMFILE}" -eq 0 ]
then
	MYTAR="$(ls ${PATCHARC}|egrep -i ".tar.gz$|.tgz$|.tar$")"
	if [ -f ${PATCHARC} ] 
	then
		FILE="$(readlink -f ${MYTAR})"
		PATCHARC="$(dirname ${FILE})/"
		MYTAR="$(basename ${FILE})"
	fi
	shf_say "using archive \"${MYTAR}\" in directory ${PATCHARC}"

	if [[ ${MYTAR##*.} == [gG][zZ] ]]
	then
		gunzip ${PATCHARC}/${MYTAR}
		MYTAR="${MYTAR%.*}"
	fi

	RPMARCS=( $(tar tf ${PATCHARC}${MYTAR}|egrep  -i ".rpm$|.RPM$") )
	let max=${#RPMARCS[@]}-1
	for i in $(seq 0 $max)
	do
		rc="$(tar -xf ${PATCHARC}${MYTAR} -C ${TMPDIR} ${RPMARCS[$i]})$?"
		[ "${rc}" -eq 0 ] || shf_say "WARNING:unpacking of \"${RPMARCS[$i]}\" from \"${MYTAR}\" exited with \"${rc}\""
		RPMARCS[$i]="${TMPDIR}/${RPMARCS[$i]}"
		let i=$i+1
	done

elif [ "${TARFILE}" -gt 1 ] && [ "${RPMFILE}" -eq 0 ]
then
	shf_say "ambigious arguments dont know which archive to use -exiting "
	myexit 1

elif [ "${RPMFILE}" -ge 1 ] 
then
	RPMARCS=( $(ls ${PATCHARC}|egrep -i ".rpm$|.RPM$") )

elif [ -f "${PATCHARC}" ] && [ "${TARFILE}" -eq 0 ]
then 
	shf_say "only directories or tarballs containing rpm archives are valid arguments"
	myexit 1		

elif [ "${RPMFILE}" -eq 0 ] && [ "${TARFILE}" -eq 0 ]
then
	shf_say "no tar archives and no rpm archives found in \"${PATCHARC}\" - nothing to install";
fi
NUMARCS="${#RPMARCS[@]}"
shf_say "found \"${NUMARCS}\" rpm archives to install in \"${PATCHARC}\""
#----------------------------------------------------------------------------------
for KEY in ${GPGK[@]}
do
	rc="$(rpm --import ${KEY})$?"
	shf_say "importing gpgkey \"$(basename ${KEY})\" with exit \"${rc}\""
done	
#----------------------------------------------------------------------------------
ALLOK="yes" ; RETRY="5" 
	shf_say "installing ... - please be patient"
	 WASHERE=$(pwd); cd "${PATCHARC}" &&
	rpm -Uvh --nodeps *.rpm 2>&1 |tee -a ${PATCHLOG} && sync && sleep 3

#----------------------------------------------------------------------------------
let COUNT=1; BROKEN=("${RPMARCS[@]}")
while [ "${#BROKEN[@]}" != "0" ] && [ "${COUNT}" != "${RETRY}" ]
do
	let REMAIN=${#BROKEN[@]}-1; let j=0; unset BROKEN
	for i in $(seq 0 ${REMAIN})
	do
		OK="$(rpm -q ${RPMARCS[$i]%.*} &>/dev/null)$?"
		if [ "${OK}" != "0"  ] ; then
			BROKEN[$j]=${RPMARCS[$i]}
			let j=$j+1
		fi 
		let i=$i+1
	done

	rpm -Uvh --nodeps ${BROKEN[@]} &>>${PATCHLOG}  && sync && sleep 3
	let COUNT=${COUNT}+1
done
let REMAIN=${#BROKEN[@]}
if [ "${#BROKEN[@]}" != "0" ]; then
	shf_say "WARNING: problems with some rpms \"${REMAIN}\(${CHKLATER}\)\""
	let REMAIN=${#BROKEN[@]}-1
fi

unset i; let BOUND=${NUMARCS}-1; for i in $(seq 0 ${BOUND})
do
	
	OK="$(rpm -q ${RPMARCS[$i]%.*} &>/dev/null)$?"
	sleep 1
	if [ "${OK}" = "0" ] 
	then
		FAC="debug"
		MYMSG="installed successfully rpm -q shows exit \"${OK}\":  \"${RPMARCS[$i]%.*}\""
	else
		ALLOK="no"
		FAC="err"
		MYMSG="WARNING: can not successfully rpm -q for \"${RPMARCS[$i]%.*}\": exit \"${OK}\"" 
	fi	
	logger -p user.${FAC} -t ${MYSELF} "${MYMSG}"
	shf_say	"${MYMSG}" 
done
#----------------------------------------------------------------------------------

	if [ "${ALLOK}" = "yes" ]; then
		shf_say "no errors - all \"${NUMARCS}\" rpms installed with exit 0 - ending session"
	else	
		shf_say "WARNING: there were errors - some rpms might not be installed properly"
	fi
	shf_say "see detailed logfile in \"${PATCHLOG}\""
	
	[ ! -z "${WASHERE}" ] && cd "${WASHERE}"

shf_say "#-----------------------------------------------------------------"
shf_say "leaving script ${MYSELF}"
shf_say "#-----------------------------------------------------------------"
