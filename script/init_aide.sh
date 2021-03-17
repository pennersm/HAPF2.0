#!/bin/bash
###########################################################################
# NSN INSTA HAPF2.1 PLATFORM SCRIPT
#--------------------------------------------------------------------------
# Script default name   : ~script/init_aide.sh
# Configure version     : mkks62f.pl
# Media set             : PF21I52RH63-12
# File generated        : 03.01.2013 MPe
#
###########################################################################
unalias -a &>/dev/null
export -p  MYSELF="init_aide.sh"
TAG=$MYSELF
AIDEFLAG="/root/.do_aide_init"

if [ "$1" = "--interactive" ]
then
	logger -p user.debug -t ${TAG} "aide initialisation called in interactive mode"
	BRC="/root/.bashrc"
	BRCTAIL="`tail -n 1 ${BRC}`"
	if [ "${BRCTAIL}" = "/root/init_aide.sh" ]
	then
		sed '$d' < ${BRC} > ${BRC}.tmp
		mv -f ${BRC}.tmp ${BRC}
	fi
	echo "/root/.bashrc" > ${AIDEFLAG}
fi
	
if [ -f ${AIDEFLAG} ] 
then
        logger -p user.debug -t ${TAG} "starting script to (re-)initialize AIDE intrusion detection"
        HORSE=$(cat ${AIDEFLAG})
else
        logger -p user.info -t ${TAG} "aide initialisation procedure called but no flagfile found!"
        exit 1
fi

if [ -f $HORSE ]
then
	clear
        trap "" 2 20
        printf "\n\n\tYour system is prepared to run AIDE advanced intrusion detection environment"
        printf "\n\tAIDE needs to re-initialize to reflect changes done during installation phases"
	printf "\n\tafter its first database was built. You must allow this script to continue !"
        printf "\n\tin order to use AIDE without obtaining a high number of false positives."
	printf "\n\tThe initialization will take approximately 2-4 minutes. It is executed only"
        printf "\n\tthis one time and requires your patience!!!" 
	printf "\n\tYou can also init aide at any time by running \"/root/init_aide.sh --interactive\""
	printf "\n\n\tMAKE SURE THAT ALL UNNECCESSARY FILESYSTEMS (USB, /boot/efi, ...) ARE UNMOUNTED!"
	printf "\n\t=============================================================================="
	printf "\n\t type [OK] to start (re)-initialising AIDE now"
	printf "\n\t type [NO] to skip init (asks again on next login)\n"
	DUMMY=""; printf "\t"
	
	until [[ "$DUMMY" = "OK" || "$DUMMY" = "NO" ]]
	do
		read -s DUMMY
	done
	case ${DUMMY} in
		OK)
			umount /boot/efi &>/dev/null
			umount /media    &>/dev/null
			umount /mnt      &>/dev/null
			clear
			START="`date +%H:%M:%S`"
			printf "\n\tStarting to (re-)initialize at ${START}, please be patient"
        		aide --init > /tmp/aide.init &&
        		if [ $? -eq 0 ]
        		then
				END="`date +%H:%M:%S`"
				printf "\n\tdone at ${END}, AIDE database re-initialized!\n\n"
                		sync
				MYDB=$(grep "^### AIDE database at" /tmp/aide.init |awk '{print$3}')
                		mv -f /var/lib/aide/aide.db.gz /var/lib/aide/aide.db.gz.old &>/dev/null
                		cp -f /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz
                		logger -p user.info -t ${TAG} "initialized aide db \"cat ${MYDB}\""
                		sed '$d' < ${HORSE} > ${HORSE}.tmp
            		    	mv -f ${HORSE}.tmp ${HORSE}
                		rm -f ${AIDEFLAG}
        		fi
		;;
		NO)
			logger -p user.info -t ${TAG} "initializion of AIDE postponed for later"
			printf "\n\tPlease allow AIDE (re-)initialisation at a later time\n\n"
			return 0 &>/dev/null
			
		;;
	esac
else
        logger -p user.info -t ${TAG} "can not find file indicated in aide initialisation flag: \"${HORSE}\""
fi
