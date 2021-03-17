#!/bin/bash
###########################################################################
# NSN INSTA HAPF2.1 PLATFORM SCRIPT
#--------------------------------------------------------------------------
# Script default name   : ~script/setnsnenv.sh
# Configure version     : mkks62f.pl
# Media set             : PF21I52RH63-12
# File generated        : 03.01.2013 MPe
#
###########################################################################
trouble() {
        echo "We are in trouble :"
        cat <<-EXPLAIN
	        METAENV file "${MAINFLAG}" is expected but was not found!
EXPLAIN
}
#############################################################################
: ${MAINFLAG:="/etc/hapf21.flag"}
if [ -r ${MAINFLAG} ]
then
        source ${MAINFLAG} &> /dev/null
else
        trouble
	return 1 &>/dev/null
	exit 1
fi
#----------------------------------------------------------------------------
for PHASE1 in ${RUN[@]}
do
        if [ -f $PHASE1 ]
        then
		echo "... sourching $PHASE1"
                source $PHASE1 &> /dev/null
        else
                trouble
		return 1 &>/dev/null
		exit 1
        fi
done
ROLE=$1 ; : ${ROLE:=$GENROLE}
shf_set_index
shf_logit "rebuilt HAPF21 installation environment for role ${ROLE} on `uname -n`"
