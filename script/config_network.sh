#!/bin/bash
###########################################################################
# NSN INSTA HAPF2.1 RAPID SETUP CONFIG GENERATOR SCRIPT
#--------------------------------------------------------------------------
# Script default name   : ~script/config_network.sh
# Configure version     : mkks62f.pl
# Media set             : PF21I52RH63-12
# File generated        : 03.01.2013 MPe
#
###########################################################################
export -p  MYSELF="config_network.sh"
#
shf_logit "#-----------------------------------------------------------------"
shf_logit "starting to run script ${MYSELF}"
shf_logit "#-----------------------------------------------------------------"
#
ROLE=$1; if [ -z ${ROLE} ] ; then exit ; fi
export -p SHELLOG=${INSTDIR}/${MYSELF}.${ROLE}.${NOW}.shell.log
#
shf_set_index
shf_logit "using Role $ROLE in here, configure index ${X}"
shf_wrap_vlans
shf_logit "knowing \"${#VLAN[@]}\" network i/f resources here"
shf_logit "${NOW} using ARGS: `echo $*`"
shf_logit "creating file to log command outputs: ${SHELLOG}"
#
cat /dev/null > ${SHELLOG}
echo "starting shellog for ${NOW} ${MYSELF} `date`" &>> ${SHELLOG}
set &>> ${SHELLOG}
echo "=======================================================================" &>> ${SHELLOG}
##############################################################################
#
#  Network drivers and interfaces
#
#-----------------------------------------------------------------------------
#shf_logit "Disabling ipv6 support"
#
#FILE="/etc/sysconfig/network"
#cat $FILE |grep -v "NETWORKING_IPV6="|grep -v "IPV6INIT="|grep -v "### $NOW" >${FILE}.${ROLE}.${NOW}
#rm -f $FILE
#mv -f ${FILE}.${ROLE}.${NOW} $FILE
#cat <<-EOIPV6 >>$FILE
#	### $NOW HAPF2.1 RAPID SETUP ADDITION START 
#	NETWORKING_IPV6=no
#	IPV6INIT=no
#	### $NOW HAPF2.1 RAPID SETUP ADDITION END
#EOIPV6
#chown root:root $FILE
#chmod 0644 $FILE
#shf_logit "`cat $FILE|wc -l` lines as : \"`ls -la $FILE `\""
#shf_fshow $FILE
#
#FILE="/etc/modprobe.d/ipv6.conf"
#rm -f $FILE 2>/dev/null
#shf_tag_cffile "$FILE" "no-backup"
#cat <<-EOIP6D >> $FILE
#	alias net-pf10 off
#	alias ipv6 off
#	options ipv6 disable=1
#EOIP6D
#chown root:root $FILE
#chmod 0644 $FILE
#shf_logit "`cat $FILE|wc -l` lines as : \"`ls -la $FILE `\""
#shf_fshow $FILE

#shf_logit "IPv6 will be disabled for now, contact NSN to re-enable" 
#
#-----------------------------------------------------------------------------
shf_logit "Configure and load 8021q and bonding drivers"
rm -f /etc/sysconfig/ca_lanpf.modules 2>/dev/null

FILE="/etc/modprobe.d/ethtrunk.conf"
shf_tag_cffile "$FILE" "no-backup"
cat <<-EOVLAN >> $FILE
	alias vlan 8021q
	alias bond0 bonding
	options bond0 mode=active-backup miimon=50 num_grat_arp=3 updelay=100
EOVLAN
chown root:root $FILE
chmod 0644 $FILE
shf_logit "`cat $FILE|wc -l` lines as : \"`ls -la $FILE `\""
shf_fshow $FILE

echo "load drivers:"  &>> ${SHELLOG}

modprobe 8021q &&
shf_logit "loading driver 8021q: \"$(lsmod|grep 8021q|tr --squeeze-repeats ' '| tr '\n' ' ')\""

modprobe bonding &&
shf_logit "loading driver bonding: \"$(lsmod|grep bonding|tr --squeeze-repeats ' '| tr '\n' ' ')\""
#
shf_fshow lsmod
#
#-----------------------------------------------------------------------------
if  [ ${ROLE} != "SingleServer" ] || [ ! -z "$VLAN1ID[$X]" ]
then
	let n=0
	while [ ! -z "${VLAN[$n]}" ]
	do
		shf_add_nwif ${VLAN[$n]}
		let n=$n+1
	done
fi
#
#-----------------------------------------------------------------------------
if [[ ${ROLE} == "be"[1,2] ]] && [ ! -z "${OAMHAIP[$X]}" ] && [ -z "`echo ${OAMVLANID[$X]}|sed 's/[0-9]//g'`" ]
then
	FILE="/etc/sysconfig/network-scripts/ifcfg-bond0.${OAMVLANID[$X]}"
	shf_tag_cffile "$FILE" "no-backup"

	cat <<-OAMIF >> ${FILE}
		DEVICE=bond0.${OAMVLANID[$X]}
		ONBOOT=yes
		BOOTPROTO=static
		MTU=1400
		USERCTL=no
		VLAN=yes
	OAMIF
	chown root:root $FILE
	chmod 0644 $FILE
	shf_logit "created new vlan interface for oam ha ip \"bond0.${OAMVLANID[$X]}\"" 
fi	
#-----------------------------------------------------------------------------
FILE="/etc/sysconfig/network-scripts/ifcfg-lo"
shf_tag_cffile "$FILE" "no-backup"
cat <<-EOLO  >> $FILE
	DEVICE=lo
	IPADDR=127.0.0.1
	NETMASK=255.0.0.0
	NETWORK=127.0.0.0
	BROADCAST=127.255.255.255
	ONBOOT=yes
	NAME=loopback
EOLO
shf_logit "loopback config `cat $FILE|wc -l` lines as : \"`ls -la $FILE `\""
#-----------------------------------------------------------------------------
if  [ ${ROLE} != "SingleServer" ]
then
	shf_logit "Creating eth3 dedicated heartbeat link using IP ${HBIPADDR[$X]}"
	FILE="/etc/sysconfig/network-scripts/ifcfg-eth3"
	HWADDR=`cat ${FILE} |grep "HWADDR"`
	#
	shf_tag_cffile "$FILE" "no-backup"
	if [ ! -z "$HWADDR" ]
	then
		shf_logit "keeping anaconda defined MAC \"${HWADDR}\" for eth3 in config"
	else
		MAC="$(shf_get_mac eth3)"
		HWADDR="HWADDR=${MAC}"
		shf_logit "no existing MAC address found for eth3 - using current value \"${MAC}\""
	fi
	cat <<-E3IFCFG  >>$FILE
		DEVICE=eth3
		${HWADDR}
		BOOTPROTO=static
		ONBOOT=yes
		IPADDR=${HBIPADDR[$X]}
		NETMASK=${HBIPMASK[$X]}
	E3IFCFG
	chown root:root $FILE
	chmod 0644 $FILE
	shf_logit "`cat $FILE|wc -l` lines as : \"`ls -la $FILE `\""
	shf_fshow ${FILE}
fi
#
#-----------------------------------------------------------------------------
shf_logit "re-defining eth0 OAM access interface using IP ${IPADDReth0[$X]}"
FILE="/etc/sysconfig/network-scripts/ifcfg-eth0"
HWADDR=`cat ${FILE} |grep "HWADDR"`
#
shf_tag_cffile "${FILE}" "no-backup"
if [ ! -z "${HWADDR}" ]
then
	shf_logit "keeping anaconda defined MAC \"${HWADDR}\" for eth0 in config"
else
	MAC="$(shf_get_mac eth0)"
	HWADDR="HWADDR=${MAC}"
	shf_logit "no existing MAC address found for eth0 - using current value \"${MAC}\""
fi
cat <<-E0IFCFG  >> $FILE
	DEVICE=eth0
	${HWADDR}
	BOOTPROTO=static
	ONBOOT=yes
	IPADDR=${IPADDReth0[$X]}
	NETMASK=${NETMASKeth0[$X]}
E0IFCFG
chown root:root $FILE
chmod 0644 $FILE
shf_logit "`cat $FILE|wc -l` lines as : `ls -la $FILE `"
shf_fshow ${FILE}
#
#-----------------------------------------------------------------------------
FILE="/etc/hosts"
shf_tag_cffile $FILE "no-backup" 
shf_logit "Creating $FILE"
echo "127.0.0.1 localhost localhost.localdomain" >> ${FILE}
[ -z ${DOMAIN[X]} ] || echo "${IPADDR[$X]} ${HOSTNAME[$X]}.${DOMAIN[$X]}" >> ${FILE}
[ -z ${HOSTNAME[0]} ] || echo "${IPADDReth0[0]} ${HOSTNAME[0]}" >> ${FILE}
[ -z ${HOSTNAME[1]} ] || echo "${IPADDReth0[1]} ${HOSTNAME[1]} fe1" >> ${FILE}
[ -z ${HOSTNAME[2]} ] || echo "${IPADDReth0[2]} ${HOSTNAME[2]} fe2" >> ${FILE}
[ -z ${HOSTNAME[3]} ] || echo "${IPADDReth0[3]} ${HOSTNAME[3]} be1" >> ${FILE}
[ -z ${HOSTNAME[4]} ] || echo "${IPADDReth0[4]} ${HOSTNAME[4]} be2" >> ${FILE}
[ -z ${HOSTNAME[3]} ] || echo "${HBIPADDR[3]} ${HOSTNAME[3]}-ha" >> ${FILE}
[ -z ${HOSTNAME[4]} ] || echo "${HBIPADDR[4]} ${HOSTNAME[4]}-ha" >> ${FILE}
[ -z ${HOSTNAME[5]} ] || echo "${IPADDReth0[5]} ${HOSTNAME[5]} fe3" >> ${FILE}
[ -z ${HOSTNAME[6]} ] || echo "${IPADDReth0[6]} ${HOSTNAME[6]} fe4" >> ${FILE}
[ -z ${HOSTNAME[5]} ] || echo "${HBIPADDR[5]} ${HOSTNAME[5]}-ha" >> ${FILE}
[ -z ${HOSTNAME[6]} ] || echo "${HBIPADDR[6]} ${HOSTNAME[6]}-ha" >> ${FILE}
#
chmod 644 ${FILE}
chown root:root ${FILE}
shf_logit "`cat $FILE|wc -l` lines as : `ls -la $FILE `"
shf_fshow ${FILE}
#
#
#-----------------------------------------------------------------------------
if [ -z "${NAMESERVER[$X]}" ]
then

	FILE="/etc/nsswitch.conf"
	shf_logit "Remove DNS from name service lookup"
	shf_tag_cffile ${FILE}	
	
	mv -f ${FILE} ${FILE}.${ROLE}.${NOW} 
	cat ${FILE}.${ROLE}.${NOW} |grep -v "hosts:"|grep -v "### $NOW" > ${FILE}
	cat <<-EODNS >>${FILE}
		### $NOW HAPF2.1 RAPID SETUP ADDITION START
		hosts:      files
		### $NOW HAPF2.1 RAPID SETUP ADDITION STOP
	EODNS
else
	FILE="/etc/resolv.conf"
	shf_logit "Configuring DNS name service lookup"
	shf_tag_cffile ${FILE} "no-backup"
	
	echo "nameserver ${NAMESERVER[$X]}" >> ${FILE}
	[ ! -z "${DOMAIN[X]}" ] && echo "domain ${DOMAIN[$X]}" >> ${FILE}

fi
chown root:root ${FILE}
chmod 0644 ${FILE}
shf_logit "`cat ${FILE}|wc -l` lines as : \"`ls -la ${FILE} `\""
shf_fshow ${FILE}
#
#
#-----------------------------------------------------------------------------
shf_logit "Adding /etc/sysconfig/static-routes (non-interface specific)"
FILE="/etc/sysconfig/static-routes"
shf_tag_cffile $FILE "no-backup"
#
cat <<-ESTR >>$FILE
	any net ${NET1[$X]} netmask ${NETMASK1[$X]} gw ${NETGW1[$X]}
	any net ${NET2[$X]} netmask ${NETMASK2[$X]} gw ${NETGW2[$X]}
	any net ${NET3[$X]} netmask ${NETMASK3[$X]} gw ${NETGW3[$X]}
	any net ${NET4[$X]} netmask ${NETMASK4[$X]} gw ${NETGW4[$X]}
	any net ${NET5[$X]} netmask ${NETMASK5[$X]} gw ${NETGW5[$X]}
	any net ${NET6[$X]} netmask ${NETMASK6[$X]} gw ${NETGW6[$X]}
	any net ${NET7[$X]} netmask ${NETMASK7[$X]} gw ${NETGW7[$X]}
	any net ${NET8[$X]} netmask ${NETMASK8[$X]} gw ${NETGW8[$X]}
	any net ${NET9[$X]} netmask ${NETMASK9[$X]} gw ${NETGW9[$X]}
	any net ${NET10[$X]} netmask ${NETMASK10[$X]} gw ${NETGW10[$X]}
	any net ${NET11[$X]} netmask ${NETMASK11[$X]} gw ${NETGW11[$X]}
	any net ${NET12[$X]} netmask ${NETMASK12[$X]} gw ${NETGW12[$X]}
ESTR
cat $FILE |grep -v "net  netmask  gw" > ${FILE}.${ROLE}.${NOW}
mv -f ${FILE}.${ROLE}.${NOW} $FILE
chown root:root $FILE
chmod 0644 $FILE
shf_logit "`cat $FILE|wc -l` lines as : \"`ls -la $FILE `\""
shf_fshow ${FILE}
#########################################################################
shf_logit "#-----------------------------------------------------------------"
shf_logit "leaving script ${MYSELF}"
shf_logit "#-----------------------------------------------------------------"

