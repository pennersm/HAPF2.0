#!/bin/bash
###########################################################################
# NSN INSTA HAPF2.1 PLATFORM SCRIPT
#--------------------------------------------------------------------------
# Script default name   : ~script/watch_fs.sh
# Configure version     : mkks61f.pl
# Media set             : PF21I51RH63-12
# File generated        : 03.01.2013 MPe
#
###########################################################################
export -p  MYSELF="watch_fs.sh"
TAG=$MYSELF
CFFILE=$1 ; : ${CFFILE:="/etc/sysconfig/hapf2-watch_fs"}
if [ ! -r ${CFFILE} ]
then
        logger -p user.info -t ${TAG} "no configuration for filewatch exiting"
        exit 1  
fi
#----------------------------------------------------------------------------------
FILE[1]="/etc/passwd"     ;  PERM[1]="-rw-r--r--:root:root"   ; REAL[1]="644"
FILE[2]="/etc/shadow"     ;  PERM[2]="----------:root:root"   ; REAL[2]="000"
FILE[3]="/etc/gshadow"    ;  PERM[3]="----------:root:root"   ; REAL[3]="000"
FILE[4]="/etc/group"      ;  PERM[4]="-rw-r--r--:root:root"   ; REAL[4]="644"

let i=1
while [ $i -le ${#FILE[@]} ]
do
        STAT=$(ls -l ${FILE[i]}|awk '{print$1":"$3":"$4}')&>/dev/null
        if [ "${PERM[$i]}" != "${STAT}" ] 
        then    
                logger -p user.info -t ${TAG} "SECURITY WARNING! permissions of ${FILE[$i]} changed to ${STAT}"
        fi      
        chmod ${REAL[$i]} ${FILE[$i]} &>/dev/null
        chown root:root ${FILE[$i]}   &>/dev/null
        let i=$i+1
done
logger -p user.debug -t ${TAG} "checked for correct permissions on local passwd files"
#----------------------------------------------------------------------------------
CHKPART=( `awk -F= '($2=="\"hapf-partition\""){print$1}' ${CFFILE} `)
for PART in ${CHKPART[@]}
do
        if [ $(mount -l ${PART} 2>/dev/null)$? -eq 32 ]
        then    
                WWDnostick=( `find ${PART} -xdev -type d \( -perm -0002 -a ! -perm -1000 \) -print` )
                WWFnotconf=( `find ${PART} -xdev -type f -perm -0002 -print` )
                SUID=( `find ${PART} -xdev \( -perm -4000 -o -perm -2000 \) -type f -print` )
                NOOWN=( `find ${PART} -xdev \( -nouser -o -nogroup \) -print` )
        else    
                logger -p user.info -t ${TAG} "can not access directory ${PART} - no fs-check possible"
        fi      

        for FILE in ${WWDonostick[@]}
        do      
                logger -p user.debug -t ${TAG} "saw world writable dir without sticky bit ${FILE}"
                if [ -z "$(awk -F= -v AFILE="${FILE}" '(($1==AFILE) && ($2=="\"allow_WWD_nostickb\"")){print$1}' ${CFFILE})" ]
                then    
                        logger -p user.info -t ${TAG} "SECURITY WARNING! world writable dir without sticky bit ${FILE}"
                fi      
        done    
        for FILE in ${WWFnotconf[@]}
        do      
                logger -p user.debug -t ${TAG} "saw world writable file ${FILE}"
                if [ -z "$(awk -F= -v AFILE="${FILE}" '(($1==AFILE) && ($2=="\"allow_WWF\"")){print$1}' ${CFFILE})" ]
                then    
                        logger -p user.info -t ${TAG} "SECURITY WARNING! unknown world writable file ${FILE}"
                fi      
        done    
        for FILE in ${SUID[@]}
        do      
                logger -p user.debug -t ${TAG} "saw SUID/SGID file ${FILE}"
                if [ -z "$(awk -F= -v AFILE="${FILE}" '(($1==AFILE) && ($2=="\"allow_SUID\"")){print$1}' ${CFFILE})" ]
                then    
                        logger -p user.info -t ${TAG} "SECURITY WARNING! unknown SUID/SGID file ${FILE}"
                fi      
        done    
        for FILE in ${NOOWN[@]}
        do      
                logger -p user.info -t ${TAG} "SECURITY WARNING! found file without owner ${FILE}"
        done    
done

