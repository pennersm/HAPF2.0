#!/bin/bash
###########################################################################
# NSN INSTA HAPF2.1 PLATFORM SCRIPT
#--------------------------------------------------------------------------
# Script default name   : ~script/hapf_statrep.sh
# Configure version     : mkks62f.pl
# Media set             : PF21I52RH63-12
# File generated        : 03.01.2013 MPe
#
###########################################################################
TSTAMP=$(date +%d%m%Y-%H%M%S)
export -p  MYSELF="hapf_statrep.sh" ; TAG=$MYSELF
#----------------------------------------------------------------------------------
usage() {
bold=$(tput bold)
normal=$(tput sgr0)
printf "\n ${bold}USAGE:${normal}\n"
printf "\n\t Status report for HAPF2.1 Platform and install media integrity\n"
printf "\t -----------------------------------------------------------------------\n"
printf "\t hapf_statrep.sh {-otg} {-d}\n\n"
printf "\t Collects a predefined set of status information either to file or sdtout\n\n"
printf "\t${bold}--getfiles|-g ${normal}\n"
printf "\t Does two important things at a time:\n"
printf "\t 1) Create a catalog of all files on a server along with\n"
printf "\t basic file info such as ownership, size and modification time.\n"
printf "\t 2) Pack this catalog together with a set of predefined configuration files\n"
printf "\t into a tarball.\n"
printf "\t${bold}--diag|-d${normal}\n"
printf "\t Triggers a series of commands to display the status of various subsystems\n"
printf "\t on this server. Results are shown to stdout and also logged into an archive.\n"
printf "\t${bold}--test-media|-t [startpath]${normal}\n"
printf "\t Used to help verifing the integrity of an installation media or its files\n"
printf "\t This tool includes a hardcoded list of files that are needed on a complete\n"
printf "\t installation media along with their md5 checksums.\n"
printf "\t If the optional [startpath] argument is specifed, it will search for those\n"
printf "\t files in this path and show an error message if the file is not found in\n"
printf "\t the expected relative path under [startpath] or if md5sums dontt match.\n"
printf "\t The output will only go to stdout or to a final result file if --outfile\n"
printf "\t had been specified.\n" 
printf "\t If no [startpath] is given the tool will start searching in the current pwd\n"
printf "\n\n\t${bold}EXAMPLES:${normal}\n\n"
printf "\t Collect all available status information and write the output into a file\n"
printf "\t\t hapf_statrep.sh -o /tmp/resultfile.tar -g -d -t\n\n"
printf "\t Verify if a complete installation media is mounted on /media\n"
printf "\t\t hapf_statrep.sh -t /media\n"
printf "\n\n\n"
exit 1
}
#----------------------------------------------------------------------------------
run_command() {
	local CMD=$*
	local RUN="$(echo ${CMD}|sed 's/^[ \t]*//; s/#[^#]*$//; /^$/d; /#/d')"
	if [ ! -z "${RUN}" ] ; then
		echo "#================================================================================="
		echo "running now: $*"
		echo "#================================================================================="
		eval $* ; rc=$?
		echo; echo; echo "last exit status: ${rc}"
	fi
	return ${rc}
}
#----------------------------------------------------------------------------------
make_sum() {
        local FILE=$*
        CHKFILE="$(echo ${FILE}|sed 's/^[ \t]*//; s/#[^#]*$//; /^$/d; /#/d')"

        if [ -f "${CHKFILE}" ] ; then
                SUM=$(md5sum "${CHKFILE}"); rc=$?
                [ "${rc}" = "0" ] && echo $SUM|cut -d' ' -f 1
	elif [ -d "${CHKFILE}" ] ; then
		rc=0
        else
                logger -p user.error -t ${TAG} "ERROR: missing file \"${FILE}\" !!" >&2
                rc=5
        fi
        return ${rc}
}
#----------------------------------------------------------------------------------
#----------------------------------------------------------------------------------
#      START EXEC
#----------------------------------------------------------------------------------
#----------------------------------------------------------------------------------
: ${MAINFLAG:="/etc/hapf21.flag"}
if [ ! -f ${MAINFLAG} ]
then
        echo "WARNING: this host does not have a complete HAPF2.1 environment installed !"
        logger -p user.warn -t ${TAG} "WARNING: attempting to run in incomplete environment"
else
        source ${MAINFLAG}
        ROLE="${GENROLE}"
        logger -p user.debug -t ${TAG} "started for Role \"${ROLE}\""
	: ${ARCDIR:="/backup"}
	: ${DIAGTMP:="${ARCDIR}/diagnose-${ROLE}-${NOW}.txt"}
	: ${ARCFILE:="${ARCDIR}/cfilearc-${ROLE}-${NOW}.tar"}
	: ${MED5CHK:="${ARCDIR}/medm5chk-${ROLE}-${NOW}.txt"}
	: ${FILECAT:="${ARCDIR}/filecata-${ROLE}-${NOW}.txt"}
fi
: ${INSTDIR:="/tmp/Installmedia"} ; [ ! -w ${INSTDIR} ] && mkdir -p ${INSTDIR}
: ${ARCDIR:="."}
#----------------------------------------------------------------------------------

TEST_MEDIA="false" ; GETFILES="false" ; DIAGNOSE="false"
[ $# = 0 ] && usage
while [ $# != 0 ]
do
        case $1 in

	--test-media|-t)
		TEST_MEDIA="true"
                STARTPATH="$2"
		[ ${STARTPATH:0:1} != "-" ] || unset STARTPATH
		: ${STARTPATH:="."}
		: ${MED5CHK:="${ARCDIR}/medm5chk-$(hostname)-${TSTAMP}.txt"}
                shift
        ;;
	--getfiles|-g)
		GETFILES="true"
		: ${ARCFILE:="${ARCDIR}/cfilearc-$(hostname)-${TSTAMP}.tar"}
		: ${FILECAT:="${ARCDIR}/filecata-$(hostname)-${TSTAMP}.txt"}
	;;
	--diag|-d)
		DIAGNOSE="true"
		: ${DIAGTMP:="${ARCDIR}/diagnose-$(hostname)-${TSTAMP}.txt"}
	;;
	*)
		usage
	;;
esac ; shift ; done

	RESULTFILE="${ARCDIR}/diagnose-$(hostname)-${TSTAMP}"

#============================================================================================================================
#----------------------------------------------------------------------------------------------------------------------------
# Following files will be checked - incomplete lists will be indicated:
# md5sum $(find . -type f |sed 's/^.\///'|sort)
#--------------------------------------------------------------------------------------
if [ "${TEST_MEDIA}" = "true" ]
then
        echo "#============================================================="
        echo " processing option --test-media"

	REFSET="PF21I52RH63-12"
	TMPFILE="${MED5CHK}"
	let ECOUNT=0
	printf "verifying md5sums for \"${REFSET}\" :\n\n"
	while read REFMD5 FILE
	do
		MD5=$(make_sum "${STARTPATH}/${FILE}"); rc=$?
		case ${rc} in
		"0")
			FLINE="$(find ${STARTPATH}/${FILE} -type f -printf %Ad-%Am-%AY'\040'%AH:%AM'\040\040\040'%-12s)"
			if [ "${MD5}" = "${REFMD5}" ]; then
				echo "OK   : ${FLINE} ${MD5} ${FILE}" |tee -a ${TMPFILE}
			elif [ -z "${FILE}" ]; then : ;
			else
				echo "NOK  : MISMATCH IN MD5 \"${FILE}\"" |tee -a ${TMPFILE}
				let ECOUNT=$ECOUNT+1
			fi
		;;
		"5")
			echo "ERROR: incomplete media cause  \"${STARTPATH}/${FILE}\" was not found !!!" |tee -a ${TMPFILE}
			let ECOUNT=$ECOUNT+1
		;;
		*)	
			echo "ERROR: internal md5sum function for \"${STARTPATH}/${FILE}\" returned \"${rc}\"" |tee -a ${TMPFILE}
			let ECOUNT=$ECOUNT+1
		;;
		esac
	done <<MEDFILES
#-------------------------------------------------------------------------------------------------------------------------------
977a7a0713afa35cc50c03fc09abc6eb  hsmsw/opt_nfast-2.6.32-358.11.1.el6.x86_64.tar.gz
2ed4347b9b17eaf9a3477f7888b906d7  hsmsw/pciutils-3.1.10-2.el6.x86_64.rpm
b7fd57b100e9354b92a6db2675cd2bc1  insta/certifier-5.2.2-14932.x86_64.rpm
21bc696526fbce214a89cb781ec3a235  insta/certifsub-5.2.2-14932.x86_64.rpm
4d92d39dbee4e4ac0a83b0f712f5f2ed  insta/default_license_file.lic
22ba9a719a8e6a2ac4d27c57dcc6077f  insta/enrolfe
1ec547be4af350aba836e7c9118f0e83  insta/ICertifier
8c8d53ad62b5c6e424ba19d25d9d0092  insta/init-script.sh
d73c337be916c43317349a58bea893c0  insta/IPaddr2a
4d92d39dbee4e4ac0a83b0f712f5f2ed  insta/license-data.lic
abfe62c4ab211800b9c056903a27e383  insta/RELEASE-NOTES.TXT
8db8937a6a23e31b9acd546249464816  insta/reset-bond
986175d51277e609fc2a1197339956f6  insta/sha256sum.txt
07cfcbc573b79d55778ff6ce5d1d4e3c  insta/ssh-ca-setup-nsn-certifier.sh
45800236ee806dbd978a1b6231b6f0fc  insta/ssh-ca-setup-nsn-certifsub.sh
91c20581bc07540d60344bd3dbcc42bd  insta/ssh-encrypt
5d6347843d0e3f4ef1595b086d0cc4d4  ldlinux.sys
ddf856b043bf9d701efc56eff03ee31b  Medset12-blank.xlsm
4fd0a7b699d9c6ff5a87fa1116946723  menu.c32
5ab81790bd6065b4fe7c414d2a56a94c  mkks62.exe
246e5dc179530a05a8df7836999f1d7b  mkks62g.pl
3d88f5050b3beaf0f8b15d583e953a5e  orahwm/ipmiflash-1.8.10.5-3.el6.x86_64.rpm
4c3ef47a123f23c83b9d85afc2c4f35e  orahwm/ipmitool-1.8.10.4-1.el6.x86_64.rpm
522b9a965ff43430929580b0a4b7f37d  orahwm/mstflint-1.4-3.el6.x86_64.rpm
e99108ad5e5f3970478f47c42bb55fa4  orahwm/oracle-hmp-hwmgmt-2.2.6-1.el6.x86_64.rpm
b3fa0991e0212f8791825cd4ccf05de0  orahwm/oracle-hmp-libs-2.2.6-1.el6.x86_64.rpm
01330a077408aed708a3cdcc3977d1f5  orahwm/oracle-hmp-snmp-2.2.6-1.el6.x86_64.rpm
0de8c3c09128f1487d0bdb91f05175fd  orahwm/oracle-hmp-tools-2.2.6-1.el6.x86_64.rpm
c086b9672140adb5e2db4714f0e0f2aa  orahwm/oracle-hmp-tools-biosconfig-2.2.6-1.el6.x86_64.rpm
b38b1153d1f8e2cdf33493c2e987f77d  orahwm/oracle-hmp-tools-ubiosconfig-2.2.6-1.el6.x86_64.rpm
c0e7cea2c75a56310111339cf297d123  orahwm/scli-1.7.3-37.el.i386.rpm
bc221520d208fb9fa40469b148c85c15  RHEL64/images/efiboot.img
49ad0352d0e56ed1b7cdbb2773489aa7  RHEL64/images/efidisk.img
3094f12af95f8a8bed1a69e29a097ed0  RHEL64/images/install.img
fb65e53a6dfcf8987a6d332b40fba1df  RHEL64/images/product.img
b57e0912de6ce8f8f130874a856b666a  RHEL64/images/pxeboot/initrd.img
cf1d8fc653751577ce47a9b6588d8899  RHEL64/images/pxeboot/TRANS.TBL
fdda4b37d52e1d9bcec6253e0ff3489e  RHEL64/images/pxeboot/vmlinuz
1029651cad1efdbecc40616a8d985e3d  RHEL64/images/README
0b16ee21b4f2330779c6eb10053cab28  RHEL64/images/TRANS.TBL
31ce34810ae41a54144c007e8ddec6af  RHEL64/isolinux/boot.cat
3a8800363592a5525bf458a901cc09b9  RHEL64/isolinux/boot.msg
076ebdbe4c4d460b3537910d7c75c15b  RHEL64/isolinux/grub.conf
b57e0912de6ce8f8f130874a856b666a  RHEL64/isolinux/initrd.img
43a325dbc1c97b785bd4022d31b70444  RHEL64/isolinux/isolinux.bin
23e6016bfbb8aa8a5bb4cb9dd5eb5c15  RHEL64/isolinux/isolinux.cfg
99a4dd706cf3cb0bdd65a479c65cf2c1  RHEL64/isolinux/memtest
86430f127651c88a0243195b727a3305  RHEL64/isolinux/splash.jpg
e0d5e34bc8facbac19db401161d48c7f  RHEL64/isolinux/TRANS.TBL
d34918f81190d2a0349346aa8a8e369e  RHEL64/isolinux/vesamenu.c32
fdda4b37d52e1d9bcec6253e0ff3489e  RHEL64/isolinux/vmlinuz
6bfaa27592975fc2ace3d44f823a4e66  RHEL64/nsn-rhel64-custom.iso
8d08951fda5768a805d373d26a561af0  rhpatches/bash-4.1.2-15.el6_4.x86_64.rpm
36cde86c1474dfb9d671a79c165d5c1c  rhpatches/chkconfig-1.3.49.3-2.el6_4.1.x86_64.rpm
bf1738d32e0480f98fd5f799ff9087e2  rhpatches/coreutils-8.4-19.el6_4.2.x86_64.rpm
d664890dc0bcb4cc8894edec4fb09999  rhpatches/coreutils-libs-8.4-19.el6_4.2.x86_64.rpm
938e076c12d1a42c9003c87892f02ad3  rhpatches/curl-7.19.7-37.el6_4.x86_64.rpm
970d73dad6b80ab8794ec51c7bf3dc68  rhpatches/db4-4.7.25-18.el6_4.x86_64.rpm
6a12772a4333c56da8183579503c21a9  rhpatches/db4-utils-4.7.25-18.el6_4.x86_64.rpm
a3ddcf7673d8fbb0596ce7d6dcab5345  rhpatches/dbus-glib-0.86-6.el6_4.x86_64.rpm
0fb046bce39f4a96437a467574ad7c0c  rhpatches/dhclient-4.1.1-34.P1.el6_4.1.x86_64.rpm
89a6f74dc4119691a3a1e4b24fb8e9c0  rhpatches/dhcp-common-4.1.1-34.P1.el6_4.1.x86_64.rpm
ca78c043fabcc2cbc385950db3113ef2  rhpatches/dmidecode-2.11-2.el6_1.x86_64.rpm
b4fdac14ed553e817c50bb0f0ca064f6  rhpatches/e2fsprogs-1.41.12-14.el6_4.2.x86_64.rpm
45380044d56a9e1646fa48a6aa20d1d2  rhpatches/e2fsprogs-libs-1.41.12-14.el6_4.2.x86_64.rpm
bdc8ab0253571524e8644acac4a9ba1b  rhpatches/glibc-2.12-1.107.el6_4.4.x86_64.rpm
f66c7f7be51ce4f5c4674ea0e0f4667f  rhpatches/glibc-common-2.12-1.107.el6_4.4.x86_64.rpm
7491a99fbb8fa9c8b2bc1a20d1f7e0a6  rhpatches/gnutls-2.8.5-10.el6_4.2.x86_64.rpm
e4777f2689fe438eaab34e8c4a561f81  rhpatches/gzip-1.3.12-19.el6_4.x86_64.rpm
6507d47c593dd216eaffe6ef89ed23c8  rhpatches/initscripts-9.03.38-1.el6_4.2.x86_64.rpm
f320444f6be2b57a60ecf86e73acbf89  rhpatches/iputils-20071127-17.el6_4.2.x86_64.rpm
aca8971d65d496a5f716339096bd7d1b  rhpatches/kernel-2.6.32-358.18.1.el6.x86_64.rpm
470fbc9de4c6a67aad4a0f5176fe306b  rhpatches/kernel-firmware-2.6.32-358.18.1.el6.noarch.rpm
5625b97dbc4866ebcb5a0ecabad0db9d  rhpatches/krb5-libs-1.10.3-10.el6_4.6.x86_64.rpm
de101ff63aedac963a29b2ae0bcb6e84  rhpatches/libblkid-2.17.2-12.9.el6_4.3.x86_64.rpm
fdb481d48014e0311c8c44fe1fe0afb8  rhpatches/libcgroup-0.37-7.2.el6_4.x86_64.rpm
df020c20953bf098b985d6158d601b1b  rhpatches/libcom_err-1.41.12-14.el6_4.2.x86_64.rpm
5fa4f4cae3d406e50ed554e521f1c5c2  rhpatches/libcurl-7.19.7-37.el6_4.x86_64.rpm
98a8dcb85ccc5cbd1665bb5f215a772e  rhpatches/libnl-1.1.4-1.el6_4.x86_64.rpm
44287de6fa535ee7783bf183c7b583a9  rhpatches/libselinux-2.0.94-5.3.el6_4.1.x86_64.rpm
79151ae68b024a208c194c7849c5d019  rhpatches/libselinux-python-2.0.94-5.3.el6_4.1.x86_64.rpm
5b3c13b66a052849b4d427b319b36d5e  rhpatches/libselinux-utils-2.0.94-5.3.el6_4.1.x86_64.rpm
e7b6f7450e52ce55c1b5863f2ec04022  rhpatches/libss-1.41.12-14.el6_4.2.x86_64.rpm
a64440994978fb21b407291e585a0668  rhpatches/libuuid-2.17.2-12.9.el6_4.3.x86_64.rpm
a591dc14594b3338eaeebca7263872a9  rhpatches/libxml2-2.7.6-12.el6_4.1.x86_64.rpm
6c80e92a3550fd06dbfb22fdd6588041  rhpatches/libxml2-python-2.7.6-12.el6_4.1.x86_64.rpm
ac73a08196f7eb6e08e98d2be77170f3  rhpatches/module-init-tools-3.9-21.el6_4.x86_64.rpm
6c471de95d2a97a0bd4ceff110a1b384  rhpatches/mysql-libs-5.1.69-1.el6_4.x86_64.rpm
e3d6ec7e9ddb2dc76323f82f56e0df90  rhpatches/net-snmp-5.5-44.el6_4.4.x86_64.rpm
215790e11f4dc377341d067842277421  rhpatches/net-snmp-libs-5.5-44.el6_4.4.x86_64.rpm
58883a43e728299f3a299a47c50e7e83  rhpatches/net-snmp-utils-5.5-44.el6_4.4.x86_64.rpm
6e0c963156e273ed3aedbadc42b3d230  rhpatches/nspr-4.9.5-2.el6_4.x86_64.rpm
d6a43d585505fb715a547b2124924d0e  rhpatches/nss-3.14.3-4.el6_4.x86_64.rpm
cb3990a5f8ac607c3d955050cdaa4766  rhpatches/nss-softokn-3.14.3-3.el6_4.x86_64.rpm
c21834dc203bed0958b19ba85fbe30e6  rhpatches/nss-softokn-freebl-3.14.3-3.el6_4.x86_64.rpm
8a9c0cdc816f79ad832e71e54fbb7f44  rhpatches/nss-sysinit-3.14.3-4.el6_4.x86_64.rpm
9ca3d4371286396ae8ab2e0723de2677  rhpatches/nss-tools-3.14.3-4.el6_4.x86_64.rpm
cecfc86c4c13fc47beabb092c701b157  rhpatches/nss-util-3.14.3-3.el6_4.x86_64.rpm
44e92520b3d2925dc5ddd226c14cae52  rhpatches/openhpi-2.14.1-3.el6_4.3.x86_64.rpm
b55b69587dc3144e0c4b76dac2641afa  rhpatches/openhpi-libs-2.14.1-3.el6_4.3.x86_64.rpm
bb1b0163545c4c259bbf37a5e9e1e212  rhpatches/openldap-2.4.23-32.el6_4.1.x86_64.rpm
b9cf2fe15faeb0dddfc13e03c30645c3  rhpatches/openldap-clients-2.4.23-32.el6_4.1.x86_64.rpm
a6177bb1e91fbf204d50f5e8f286454f  rhpatches/openldap-servers-2.4.23-32.el6_4.1.x86_64.rpm
9d0fd7cdefeff1f09372edca7f3d9c21  rhpatches/openssl-1.0.0-27.el6_4.2.x86_64.rpm
7af4a79603e2d5cbc2116f4cfffd9887  rhpatches/perl-5.10.1-131.el6_4.x86_64.rpm
57300d1cec4b774dcf9a0d75885b7b6f  rhpatches/perl-Compress-Raw-Zlib-2.020-131.el6_4.x86_64.rpm
02429eb774bdb37d0978f557403fb229  rhpatches/perl-Compress-Zlib-2.020-131.el6_4.x86_64.rpm
00a999ada1f089d34fad43aebc24c867  rhpatches/perl-IO-Compress-Base-2.020-131.el6_4.x86_64.rpm
67a81087a7848ba7dda7cf20dcc1a4fd  rhpatches/perl-IO-Compress-Zlib-2.020-131.el6_4.x86_64.rpm
e10531155e487befa3250a35db417509  rhpatches/perl-libs-5.10.1-131.el6_4.x86_64.rpm
6bf587bbc3c123642de187a5c7901984  rhpatches/perl-Module-Pluggable-3.90-131.el6_4.x86_64.rpm
bc7fe93cba75ee00f6ceec46d5026542  rhpatches/perl-Pod-Escapes-1.04-131.el6_4.x86_64.rpm
208cce6d808df02a260ed1b053dec6d5  rhpatches/perl-Pod-Simple-3.13-131.el6_4.x86_64.rpm
345cd1e9e07dc4dac1636e2dca8163ae  rhpatches/perl-version-0.77-131.el6_4.x86_64.rpm
0e7e7ab993b77c91c69f2245b9cbf1dc  rhpatches/python-2.6.6-37.el6_4.x86_64.rpm
90f36ec3be056f1dec150291dc1249ff  rhpatches/python-dmidecode-3.10.13-3.el6_4.x86_64.rpm
18e5333d9aa19aa9cde333ac63757b0b  rhpatches/python-libs-2.6.6-37.el6_4.x86_64.rpm
e2997d3b963eef6f685cec6361706d70  rhpatches/rsyslog-5.8.10-7.el6_4.x86_64.rpm
b101cce9990f36d172e0a535e7c8c743  rhpatches/selinux-policy-3.7.19-195.el6_4.12.noarch.rpm
3e2fb1ab808f745bb6990f3728058272  rhpatches/selinux-policy-targeted-3.7.19-195.el6_4.12.noarch.rpm
4929573603acf47d649c7997047490cc  rhpatches/sos-2.2-38.el6_4.2.noarch.rpm
16f2a463135d39c14cfdc6802bc34be2  rhpatches/subscription-manager-1.1.23.1-1.el6_4.x86_64.rpm
2ee2d3288033181b563d9f0c881ba32c  rhpatches/tzdata-2013c-2.el6.noarch.rpm
bf708c5960a2402e68618751afd18bc9  rhpatches/upstart-0.6.5-12.el6_4.1.x86_64.rpm
73a92cb4cee301cbbd63bbc381bd1316  rhpatches/util-linux-ng-2.17.2-12.9.el6_4.3.x86_64.rpm
b09500b4096b869bad97e8465b683100  rpms/atrpms-75-1.noarch.rpm
e888724e5cf0517bbc9805b3a71d25c1  rpms/cluster-glue-1.0.5-6.el6.x86_64.rpm
3f70b9a2e0d222a65c59a1adee813ada  rpms/cluster-glue-libs-1.0.5-6.el6.x86_64.rpm
0f61667dd632cd9b6c048e768a24113e  rpms/clusterlib-3.0.12.1-49.el6.x86_64.rpm
f6e4b40ca9d6e79fbfe3391e790a1e4f  rpms/cluster-snmp-0.16.2-20.el6.x86_64.rpm
611c0ebf069a2b749c210bd8be406133  rpms/corosync-1.4.1-15.el6.x86_64.rpm
90259fa2d1ef67803ad83d7f43b76cee  rpms/corosynclib-1.4.1-15.el6.x86_64.rpm
c68b9c4b7bba3f7b2d0a0f32bff32f75  rpms/crmsh-1.2.5-55.8.x86_64.rpm
d753a792b576552c249814269fe72018  rpms/drbd-8.4.3-33.el6.x86_64.rpm
bafdb9cf8e8498badd6073f892e3d2d8  rpms/drbd-kmdl-2.6.32-358.11.1.el6-8.4.3-33.el6.x86_64.rpm
832c10200f34911c4796cedfba24c0c3  rpms/kernel-2.6.32-358.11.1.el6.x86_64.rpm
1a776b9014e0b1cacf3cff6c1bd7b9bd  rpms/kernel-firmware-2.6.32-358.11.1.el6.noarch.rpm
2eb9d21133b57406f9fbe3f919b97510  rpms/libqb-0.14.2-3.el6.x86_64.rpm
fe9def3be89250bbbbc4f5cb024416b8  rpms/pacemaker-1.1.8-7.el6.x86_64.rpm
4a498534753c88081562b9cb399be759  rpms/pacemaker-cli-1.1.8-7.el6.x86_64.rpm
fbfb190bad59e6e10bc5dfd38e36a9c4  rpms/pacemaker-cluster-libs-1.1.8-7.el6.x86_64.rpm
31550621e951ca88a5f7b8400219857c  rpms/pacemaker-libs-1.1.8-7.el6.x86_64.rpm
ed2fb87130a62803c05461f870f91068  rpms/perl-Archive-Zip-1.30-2.el6.noarch.rpm
77e8dbb4b4f100ea0306c2ca4a58614b  rpms/perl-XML-Simple-2.14-8.el6.noarch.rpm
0b7bddce9f21bafcbc1445601ef75972  rpms/pssh-2.3.1-15.1.x86_64.rpm
a8d160c8fb35f659ee672bfb0a77c7e8  rpms/resource-agents-3.9.2-21.el6.x86_64.rpm
f929d51a884449aa607c393402b5fd45  rpms/RPM-GPG-KEY.atrpms
3379e8320eec69051fa3cc1956652d93  script/clustertool.sh
759528ceeb285423d41664724aa3a8e0  script/config_corosync.sh
6e87d8d69537c39d3ca3776a27520db2  script/config_drbd.sh
41e0441217f029d29d03958b09f63ce7  script/config_functions.sh
33dcc39d3a4ad50a17255803d97e6335  script/config_hsm.sh
e28ce18a887ca635b3d3b1d2bf385457  script/config_insta.sh
fcd45f98c1aabcd59828d83490e94051  script/config_netsnmp.sh
c9ccc5a4be7212bf7565d4b4252e16b2  script/config_network.sh
580b4a2d498a93277eff148877813a62  script/config_ntpclnt.sh
6feb72615647a16ed563f9a9ef71c6c7  script/config_openssh.sh
6ed74067434a72dff7fdc8dbb717ac49  script/config_security.sh
0b07afc07c2f161f3fea04eec4f18bc7  script/config_syslog.sh
d2903a97efc84a20c8864b77686a364b  script/daily_backup.sh
0258b2f0c4a8a593af44ffefbc560203  script/init_aide.sh
ced9a9da8d4612da2d05c808faa1cdf9  script/install_patches.sh
b74aeb122e2b68a2920b1cc079434ff4  script/phase2.sh
7031a49b6a4524a421e5e941cbf35a62  script/setnsnenv.sh
4dbb01a0d70780d9ba3b43868ab87b32  script/watch_fs.sh
7cd50583489e844732f0baab1742670c  script/watch_performance.sh
5163c31f416a8d7d6fb739b22b1c5761  script/watch_snmpd.sh
6f4b25bff86024815ebd812f479b2b9b  script/wrap_procfix.sh
MEDFILES
	[ "${ECOUNT}" != "0" ] && printf "\n\n\n MEDIA ERROR: there were \"${ECOUNT}\" md5 mismatches !!!\n\n" || printf "\n\n"
	
[ -f ${STARTPATH}/syslinux.cfg ] || printf "MEDIA WARNING: There is no \"syslinux.cfg\" - your media is NOT yet ready to be used for installation!\n"

printf "THIS host was installed using configuration creation-stamp \"${NOW}\"\n"

if [ -f ${STARTPATH}/configure.sh ]; then
	NOWSTAMP="$(grep "NOW=" ${STARTPATH}/configure.sh|cut -d'=' -f 2|tr -d '"' 2>/dev/null)"
	[ "${NOWSTAMP}" = "${NOW}" ] || printf "MEDIA WARNING: ${STARTPATH}/configure.sh has different configuration stamp \"${NOWSTAMP}\"\n"
else
	 printf "MEDIA WARNING: There is no \"configure.sh\" - your media is NOT yet ready to be used for installation!\n"
fi

KICKSTRTS=( $(find ${STARTPATH} -maxdepth 1 -name "ks-???.cfg" 2>/dev/null) )
if [ ${#KICKSTRTS[@]} -gt 0 ]; then
	printf "\n MEDIA INFO: Your media contains kickstart files for the following roles:\n"
	for KS in ${KICKSTRTS[@]}; do B=$(basename ${KS});printf "${B:3:3}\t"; done; printf "\n\n"
	
	for KS in ${KICKSTRTS[@]} ; do
	STP="$(grep -m 1 "NOW=" ${KS}|cut -d'=' -f 2|tr -d '"' 2>/dev/null)"
	[ "${STP}" = "${NOW}" ] || printf "MEDIA WARNING: Kickstart ${KS} has different configuration stamp \"${STP}\"\n"
	done; printf "\n\n"
else
	 printf "\n MEDIA WARNING: There are no Kickstart-files - your media is NOT yet ready to be used for installation!\n\n"
fi
echo "\nmd5check protocol left in file \"${TMPFILE}\" !"
fi
#----------------------------------------------------------------------------------------------------------------------------
#                        END OF FILES TO CHECK
#----------------------------------------------------------------------------------------------------------------------------
#============================================================================================================================
#----------------------------------------------------------------------------------------------------------------------------
#  Following Commands shall be run to generate a report, add more if you feel they are needed :
#
#----------------------------------------------------------------------------------------------------------------------------
if [ "${DIAGNOSE}" = "true" ] 
then
        echo "#============================================================="
        echo " processing option --diagnose"

	TMPFILE="${DIAGTMP}"
	while read CMD; do run_command "${CMD}" 2>&1| tee -a ${TMPFILE}; done <<EOC
#----------------------------------------------------------------------------------------------------------------------------
hostname
dnsdomainname
uname -a
cat /etc/system-release
chkconfig --list
lsmod
ethtool eth0
ethtool eth1
ethtool eth2
ethtool eth3
cat /proc/net/bonding/bond0
ip addr
ip link
ip route
netstat -tunap
crm_mon -1 -tof
crm configure show
cat /proc/drbd
cat /proc/mounts
cat /etc/fstab
rpm -qa |sort 
ps -ef 
crontab -l
/opt/nfast/bin/nfkminfo
/opt/nfast/bin/enquiry
/opt/nfast/bin/rfs-sync -s
/opt/nfast/bin/slotinfo -m 1
EOC
#
echo "diagnostic info left in file \"${TMPFILE}\" !"
fi
#-----------------------------------------------------------------------------------------------------------------------------
#                        END OF COMMANDS TO BE RUN
#-----------------------------------------------------------------------------------------------------------------------------
#============================================================================================================================
#-----------------------------------------------------------------------------------------------------------------------------
# Following Files shall be archived, add more if you feel they are needed for a report:
#
#-----------------------------------------------------------------------------------------------------------------------------
if [ "${GETFILES}" = "true" ]
then
	echo "#============================================================="
	echo " processing option --getfiles"
	echo "MODTIME                 OWNER        PERMISSION          SIZE   FILE" > ${FILECAT}
	printf "creating filecatalog ${FILECAT} ..."
	find / -printf %Ad-%Am-%AY'\040'%AH:%AM'\040'%9u%9g'\040\040'%#M%16s'\040'%p%A\n 1>> ${FILECAT} 2>/dev/null && sync 
	printf "done!\n"
	sleep 1; tar -cf ${ARCFILE} -C ${ARCDIR} $(basename ${FILECAT}) &>/dev/null
	if [ $? -eq 0 ]; then
		echo "appending files to archive ${ARCFILE}:"
	else
		echo "ERROR: Can not create or find archive ${ARCFILE}" 
		exit 1
	fi
	
	let NFIL=0; printf "\n..."; while read FILE; do
		if [ -f "${FILE}" ] || [ -d "${FILE}" ]; then
			printf "${FILE}"
			tar -rf ${ARCFILE} ${FILE} &>/dev/null && sync
			tput cub ${#FILE}; tput el; let NFIL=$NFIL+1
		fi
	done <<EOF
#-----------------------------------------------------------------------------------------------------------------------------
/etc/sysconfig
/etc/openldap
/etc/modprobe.d
/etc/snmp
/etc/drbd.d
/etc/sudoers.d
/etc/ssh
/etc/logrotate.d
/etc/security
/etc/aide.conf
/etc/anacrontab
/etc/bashrc
/etc/crontab
/etc/cron.d
/etc/dron.daily
/etc/cron.hourly
/etc/cron.monthly
/etc/cron.weekly
/etc/crypttab
/etc/csh.cshrc
/etc/csh.login
/etc/dracut.conf
/etc/drbd.conf
/etc/environment
/etc/ethers
/etc/exports
/etc/filesystems
/etc/fstab
/etc/group
/etc/hapf21.flag
/etc/host.conf
/etc/hosts
/etc/hosts.allow
/etc/hosts.deny
/etc/inittab
/etc/inputrc
/etc/issue
/etc/issue.net
/etc/krb5.conf
/etc/ld.so.cache
/etc/ld.so.conf
/etc/libaudit.conf
/etc/libuser.conf
/etc/localtime
/etc/login.defs
/etc/logrotate.conf
/etc/mailcap
/etc/man.config
/etc/mime.types
/etc/mke2fs.conf
/etc/motd
/etc/mtab
/etc/my.cnf
/etc/networks
/etc/nsswitch.conf
/etc/nsswitch.conf.be1.300820121341
/etc/ntp.conf
/etc/passwd
/etc/passwd-
/etc/printcap
/etc/profile
/etc/protocols
/etc/redhat-release
/etc/resolv.conf
/etc/rpc
/etc/rsyslog.conf
/etc/rsyslog.conf.bak
/etc/rwtab
/etc/securetty
/etc/services
/etc/sestatus.conf
/etc/shadow
/etc/shells
/etc/sos.conf
/etc/statetab
/etc/step-tickers
/etc/sudoers
/etc/sudo-ldap.conf
/etc/sysctl.conf
/etc/system-release-cpe
/etc/virc
/etc/wgetrc
/etc/rc.d/init.d/reset-bond
/etc/rc.d/init.d/certifier
/etc/rc.d/init.d/certifsub
/etc/yum.conf
/var/lib/aide
/var/lib/net-snmp
/usr/lib/ocf/resource.d/nsn
/var/lock
/var/run
/var/log
/opt/nfast/kmdata/config
/usr/local/certifier/sybase/authenticate.sql
/usr/local/certifier/conf/engine.conf
/usr/local/certifier/conf/engine-insecure.conf
/usr/local/certifier/conf/server.conf
/usr/local/certifier/conf/server-insecure.conf
/usr/local/certifier/var/pki/cacomm-client.crt
/usr/local/certifier/var/pki/cacomm-client.prv
/usr/local/certifier/var/pki/trust_anchor_crls/
/usr/local/certifier/var/pki/trust_anchor_crls/ok/
/usr/local/certifier/var/pki/trust_anchor_crls/failed/
/usr/local/certifier/var/pki/trusted_cacomm_ca.crt
/usr/local/certifier/var/pins
/usr/local/certifier/var/odbc.ini
/usr/local/certifier/ssh-ca-setup
/usr/local/certifier/ssh-ca-setup-nsn-certifier.sh
/usr/local/certifier/ssh-ca-start
/usr/local/certifier/ssh-ca-stop
/usr/local/certifier/lib/license-data.lic
/usr/local/certifsub/ssh-ca-setup-nsn-certifsub.sh
/usr/local/certifsub/ssh-ca-setup
/usr/local/certifsub/ssh-ca-start
/usr/local/certifsub/ssh-ca-stop
/usr/local/certifsub/var/odbc.ini
/usr/local/certifsub/var/pki/cacomm-client.crt
/usr/local/certifsub/var/pki/cacomm-client.prv
/usr/local/certifsub/var/pki/trusted_cacomm_ca.crt
/usr/local/certifsub/conf/server.conf
/usr/local/certifsub/conf/server-conf.dist
/usr/local/certifsub/conf/server-insecure.conf
/usr/local/certifsub/conf/server-insecure-conf.dist
/tmp/Installmedia/script
/tmp/Installmedia/*.${ROLE}.${NOW}.shell.log
/tmp/Installmedia/instlog-nsn.*
/tmp/Installmedia/configure.sh
/tmp/Installmedia/insta/enrolfe
/tmp/Installmedia/insta/reset-bond
/tmp/Installmedia/insta/ssh-ca-setup-nsn-certifsub.sh
/tmp/Installmedia/insta/ssh-ca-setup-nsn-certifier.sh
/tmp/Installmedia/ks-*
/etc/hapf2?.d/instlog
/etc/hapf2?.d/patchlog
/etc/hapf2?.d/configure.sh
/etc/hapf2?.d/config_functions.sh
/etc/hapf2?.d/ICertifier-ha.cfg
/etc/hapf2?.d/setnsnenv.sh
/etc/hapf2?.flag
/etc/hapf2?.d/hapf2-backup
EOF
#
printf "\"${NFIL}\" files archived !\n"



[ -z "${OUTFILE}" ] && printf "\n\ncollected file catalog and status relevant config files in \"${ARCFILE}\"\n"
sync && sleep 2
fi
OUTFILE=${RESULTFILE}
	printf "\nsummarizing results in \"${OUTFILE}\"\n"
	touch ${OUTFILE}
	if [ "${TEST_MEDIA}" = "true" ]; then
		TMPFILE="${MED5CHK}"
		sed -i '1i #=========================================================================================' ${TMPFILE}
		sed -i '2i # TESTING INSTALLATION MEDIA STARTING AT DIR \"${STARTPATH}\"                             ' ${TMPFILE}
		sed -i '3i # ' ${TMPFILE}; sed -i '4i # ' ${TMPFILE};  sed -i '5i # ' ${TMPFILE}; 
		sync
		tar rf ${OUTFILE} -C ${ARCDIR} $(basename ${MED5CHK}) &>/dev/null && sync && rm -f ${TMPFILE} &>/dev/null
	fi
	if [ "${DIAGNOSE}" = "true" ]; then
		TMPFILE="${DIAGTMP}"
		sed -i '1i #=========================================================================================' ${TMPFILE}
		sed -i '2i # RUNNING DIAGNOSTIC COMMANDS FOR PLATFORM STATUS' ${TMPFILE}
		sed -i '3i # ' ${TMPFILE}; sed -i '4i # ' ${TMPFILE};  sed -i '5i # ' ${TMPFILE}; 
		sync
		tar rf ${OUTFILE} -C ${ARCDIR} $(basename ${DIAGTMP}) &>/dev/null && sync && rm -f ${TMPFILE} &>/dev/null
		
	fi
	if [ "${GETFILES}" = "true" ]; then
		tar rf ${OUTFILE} -C ${ARCDIR} $(basename ${ARCFILE}) &>/dev/null && sync && rm -f ${ARCFILE} &>/dev/null
		tar rf ${OUTFILE} -C ${ARCDIR} $(basename ${FILECAT}) &>/dev/null && sync && rm -f ${FILECAT} &>/dev/null
	fi

	gzip -9 "${RESULTFILE}" ; mv "${RESULTFILE}".gz "${RESULTFILE}".tgz
	printf "\n\n\n please copy ${RESULTFILE}.tgz and send to NSN PKI support\n"
echo
exit
