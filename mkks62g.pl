#!/usr/bin/perl
###########################################################################
# NSN INSTA HAPF2.1 RAPID SETUP GENERATOR 
#--------------------------------------------------------------------------
#  Dynamic creation of kickstart files for installation of Insta CA
#  Nokia Siemens Networks (C) 2010
#  mario.penners@nsn.com
#  version 4.4, 14.07.2013 
#
# Script default name   : ~/mkks62.exe
# Configure version     : mkks62g.pl
# Media set             : PF21I52RH64-12
#
###########################################################################
use File::Copy::Recursive qw(fcopy rcopy dircopy fmove rmove dirmove);
use File::Basename;
use IO::Handle;
use Cwd ; $here = getcwd ;
#--------------------------------------------------------------------------
#      M E T A E N V
#--------------------------------------------------------------------------
			$GENVERS="mkks62g.pl";
			$MEDSET="PF21I52RH64-12";
#--------------------------------------------------------------------------
# INSTDIR is TO where files from USB installmedia will be copied on servers
$INSTDIR="/tmp/Installmedia";
#--------------------------------------------------------------------------
# MTDIR is where the USB media will be mounted during install phase1 and phase2
$MTDIR="/media";
#--------------------------------------------------------------------------
#MAINFLAG is where the METAENV is defined persistently
$MAINFLAG="/etc/hapf21.flag";
#--------------------------------------------------------------------------
#HAPFCF is where later during operation the config files for the platform will be found
$HAPFCF="/etc/hapf21.d";
#--------------------------------------------------------------------------
# NOW is a common timestamp throughout entire fileset of an installation
($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =  localtime(time);
$NOW=sprintf("%02d%02d%04d%02d%02d",$mday,($mon+1),($year+1900),$hour,$min);
#--------------------------------------------------------------------------
# Backdir is where dist-files are stored if we overwrite them during install
$BACKDIR=$INSTDIR."/backup";
#--------------------------------------------------------------------------
# HACFGFILE is where configuration parameters are left for the ICertifier resource agent 
# and also for the IPaddr2a resource agent eg for FE rebind to IPs
$HACFGFILE=$HAPFCF."/ICertifier-ha.cfg";
#--------------------------------------------------------------------------
#--------------------------------------------------------------------------
$MYFILE=$ARGV[0];
$PlanningData="Planning Data";
$CONFIGURE="$here/configure.sh";
$RHEL="RHEL64";
#
#
$PSET=();$PNAME=();$KSROLE=();
@ROLES=();@PLANP=();
@NEWONES=();@OLDONES=();
# 
#============================================================================
#    READ THE EXCEL FILE
#============================================================================
#
@EXTENSION  = split /\./,$MYFILE;
$XLVER      = lc(@EXTENSION[scalar(@EXTENSION)-1]);
#
# use ParseExcel for the old (<excel7) file versions
if ( $XLVER eq "xls"  ) {
	use Spreadsheet::ParseExcel;
	my $EXCEL = new Spreadsheet::ParseExcel;
	my $WBOOK = $EXCEL->Parse($MYFILE);
	my $NSHEET = $WBOOK->{SheetCount};
#	
	foreach my $NSHEET (0 .. $NSHEET - 1) {
		$CurrentSheet = $WBOOK->{Worksheet}[$NSHEET];
		$SheetName = $CurrentSheet->{Name};
		if ( $SheetName eq $PlanningData ) {
			print "\n\n\tParsing Worksheet $SheetName .... \n";
			foreach my $COL ( 2 ..  ($CurrentSheet->{MaxCol}-1)) {
				$KSROLE= $CurrentSheet->{Cells}[0][$COL]->Value;
				push ( @ROLES, $KSROLE );
				foreach $LIN ( 1 .. $CurrentSheet->{MaxRow}) {
					$PNAME= $CurrentSheet->{Cells}[$LIN][1]->Value;
					push ( @PLANP, $PNAME );
					$PVAL=$CurrentSheet->{Cells}[$LIN][$COL]->Value;
					$PVAL =~ s/[\r\n]//g;
					$PVAL =~ s/^\s+//; 
					$PVAL =~ s/\s+$//;
					$PSET{$PNAME,$KSROLE}="$PVAL";
				}			
			}
	   	} 
	}
} 
# or use XLSX for new excel versions
elsif (( $XLVER eq "xlsx" )||($XLVER eq "xlsm")) {
	use Spreadsheet::XLSX;
	my $EXCEL = Spreadsheet::XLSX -> new ($MYFILE, $converter);
#
	foreach my $NSHEET (@{$EXCEL->{Worksheet}}) {
    		$SheetName = $NSHEET->{Name};
			if ( $SheetName eq $PlanningData ) {
				print "\n\n\tParsing Worksheet $SheetName .... \n";
				foreach my $COL ( 2 ..  ($NSHEET->{MaxCol})) {
					$KSROLE= $NSHEET->{Cells}[0][$COL]->Value;
					push (@ROLES, $KSROLE);
						foreach $LIN ( 1 .. $NSHEET->{MaxRow}) {						
							$PNAME= $NSHEET->{Cells}[$LIN][1]->Value;	
							push (@PLANP, $PNAME);
							$PVAL= $NSHEET->{Cells}[$LIN][$COL];
							if ( $PVAL ) {
								$PVAL= $NSHEET->{Cells}[$LIN][$COL]->Value;
								$PVAL =~ s/[\r\n]//g;
								$PVAL =~ s/^\s+//; 
								$PVAL =~ s/\s+$//;
								$PSET{$PNAME,$KSROLE}="$PVAL";	
							}
							
						}
				}
			}
	}
}
# or can not understand needed version
else {
die "\n\n Can not determine excel version, no kickstart files created !! \n";
}
#============================================================================
#    MARK THIS PARTICULAR SETUP WITH A STAMP
#============================================================================
$STAMP="$here/stampfile.txt";
if ( -f $STAMP ) { &backup_file($STAMP) } ;
open (STMPF,">$STAMP")||die "cannot open Stamp File \n";
STMPF->autoflush(1);
push (@NEWONES, $STAMP);

print STMPF "NOW=\"".$NOW."\"\n";
print STMPF "MEDSET=\"".$MEDSET."\"\n";
print STMPF "GENVERS=\"".$GENVERS."\"\n";
close(STMPF);
&make_unixfile($STAMP);
#
#
#============================================================================
#     CREATE CONFIGURE.SH
#============================================================================
#
if ( -f $CONFIGURE ) { &backup_file($CONFIGURE) } ;
open (CONSCR,">$CONFIGURE")||die "cannot open $CONFIGURE \n";
push (@NEWONES, $CONFIGURE);
CONSCR->autoflush(1);
print CONSCR "#!/bin/bash\n";
%seen = (); @ALLROLES = grep { ! $seen{$_} ++ } @ROLES;
%seen = (); @ALLPARMS = grep { ! $seen{$_} ++ } @PLANP;
$LASTROLE=();
foreach $MYROLE ( @ALLROLES ) {
#
	if ( $MYROLE eq "SingleServer" ) {$X=0};
	if ( $MYROLE eq "fe1" ) {$X=1};
	if ( $MYROLE eq "fe2" ) {$X=2};
	if ( $MYROLE eq "be1" ) {$X=3};
	if ( $MYROLE eq "be2" ) {$X=4};
	if ( $MYROLE eq "fe3" ) {$X=5};
	if ( $MYROLE eq "fe4" ) {$X=6};
	if (( $X ne 0 ) && ( $X % 2 == 0 )) { $HA="SBY" }
	else                                { $HA="ACT" };
#
		foreach $MYPAR  ( @ALLPARMS ) {
			if ( ( $HA eq "SBY" ) && (!($PSET{$MYPAR,$MYROLE})) && ($PSET{$MYPAR,$LASTROLE}) ) {
				$PSET{$MYPAR,$MYROLE}=$PSET{$MYPAR,$LASTROLE};
			}
#				print $MYPAR."[".$MYROLE."]"." = ".$PSET{$MYPAR,$MYROLE}."\n";	
				if ( $PSET{$MYPAR,$MYROLE} ) {
					print CONSCR $MYPAR."[".$X."]"."=\"".$PSET{$MYPAR,$MYROLE}."\"\n";			
				}
		}
		$LASTROLE=$MYROLE;
	}

# ---------------------------------------------	
#     Add static parameters for METAENV
# ---------------------------------------------
print CONSCR "NOW=\"".$NOW."\"\n";
print CONSCR "INSTDIR=\"".$INSTDIR."\"\n";
print CONSCR "MTDIR=\"".$MTDIR."\"\n";
print CONSCR "GENVERS=\"".$GENVERS."\"\n"; 
print CONSCR "BACKDIR=\"".$BACKDIR."\"\n";
print CONSCR "MEDSET=\"".$MEDSET."\"\n";
print CONSCR "HAPFCF=\"".${HAPFCF}."\"\n";
print CONSCR "HACFGFILE=\"".${HACFGFILE}."\"\n";
print CONSCR "MAINFLAG=\"".$MAINFLAG."\"\n";
# ---------------------------------------------
close(CONSCR);
&make_unixfile($CONFIGURE);
open STDERR, '>/dev/null';
system("chown root:root $CONFIGURE");
system ("chmod -f 744 $CONFIGURE");
close(STDERR);
#
#===================================================================================
#     CREATE KICKSTART FILES
#===================================================================================
#
foreach $MYROLE ( @ALLROLES ) {
if (( $PSET{"CREATE_ROLE",$MYROLE} eq "yes" ) && ( $MYROLE ne "SingleServer" )) {
	$LOGFILE=$INSTDIR."/instlog-nsn.".$MYROLE.".".$NOW.".log";
	$KSFILE="$here/ks-".$MYROLE.".cfg";
	if ( -f $KSFILE) { &backup_file($KSFILE) } ;
	open (UTLIST,">$KSFILE")||die "cannot open Kickstart File $OUTFILE \n";
	UTLIST->autoflush(1); 
	$LKSFIL=basename($KSFILE);
	push (@NEWONES, $KSFILE);
#===================================================================================
#start creating kickstart file for role, you can edit the kickstart below if needed
# (and if you dont know what you are doing there you gotta fix it alone later ;)
	print UTLIST <<EOK1
#===================================================================================
#
#     ---- NSN / Insta CA server ----
#  Kickstartfile, generated automatically for
#  $MYROLE, $PSET{"HOSTNAME",$MYROLE}
#  OAM IP $PSET{"IPADDReth0",$MYROLE}
#  config creation : $NOW
#  
# http://fedoraproject.org/wiki/Anaconda/Kickstart
# http://www.mail-archive.com/rhelv5-list@redhat.com/msg06776.html
# http://wiki.centos.org/TipsAndTricks/KickStart
# invoke with : linux text ks=hd:sd[X]{y}:/ks.cfg
#
install
text
key --skip
monitor --noprobe
lang en_US.UTF-8
keyboard us
firstboot --disable
timezone --utc $PSET{"TIMEZONE",$MYROLE}
#
######################################################################
# basic host security configuration
#
rootpw --iscrypted \$1\$Z.WA/G5T\$/maSQ0xeitUM7ziBQb6AU.
firewall --enabled --port=22:tcp 
authconfig --enableshadow --passalgo=sha512
selinux --disabled
#
######################################################################
# network interface configuration
#
network --device eth0 --bootproto=static --onboot=yes --hostname=$PSET{"HOSTNAME",$MYROLE} --gateway=$PSET{"DEFGW",$MYROLE} --ip=$PSET{"IPADDReth0",$MYROLE} --netmask=$PSET{"NETMASKeth0",$MYROLE} 
network --device eth1 --bootproto=dhcp --onboot=no
network --device eth2 --bootproto=dhcp --onboot=no
network --device eth3 --bootproto=dhcp --onboot=no
#
######################################################################
# File system configuration
#
bootloader --location=mbr      --driveorder=$PSET{"INITIALDSKDEVPREFIX",$MYROLE}
clearpart  --all  --initlabel  --drives=$PSET{"INITIALDSKDEVPREFIX",$MYROLE}
part /.recovery              --asprimary    --fstype=ext4    --ondisk=$PSET{"INITIALDSKDEVPREFIX",$MYROLE} --size=$PSET{"SIZRECO",$MYROLE}
part /boot                   --asprimary    --fstype=ext4    --ondisk=$PSET{"INITIALDSKDEVPREFIX",$MYROLE} --size=$PSET{"SIZBOOT",$MYROLE}      
part /                       --asprimary    --fstype=ext4    --ondisk=$PSET{"INITIALDSKDEVPREFIX",$MYROLE} --size=$PSET{"SIZROOT",$MYROLE}     
part /var                                   --fstype=ext4    --ondisk=$PSET{"INITIALDSKDEVPREFIX",$MYROLE} --size=$PSET{"SIZEVAR",$MYROLE}     
part /usr/local/certifier    		    --fstype=ext4    --ondisk=$PSET{"INITIALDSKDEVPREFIX",$MYROLE} --size=$PSET{"SIZCERTIFIER",$MYROLE}     
part /backup                 --grow         --fstype=ext4    --ondisk=$PSET{"INITIALDSKDEVPREFIX",$MYROLE} --size=$PSET{"SIZBACKUP",$MYROLE}      
part swap                                                    --ondisk=$PSET{"INITIALDSKDEVPREFIX",$MYROLE} --size=$PSET{"SIZSWAP",$MYROLE}
#
######################################################################
# packages to install
#
%packages --nobase
aide
dialog
gnutls
libaio
libibverbs
librdmacm
libxslt
lsof
mailcap
man
net-snmp
net-snmp-utils
nmap
ntp
openhpi
OpenIPMI
OpenIPMI-libs
openldap
openldap-servers
openldap-clients
openssh
openssh-clients
openssh-server
openssl
perl-TimeDate
perl-HTML-Tagset
perl-HTML-Parser
perl-IO-Compress-Base
perl-Compress-Raw-Zlib
perl-IO-Compress-Zlib
perl-Compress-Zlib
perl-URI
perl-libwww-perl
perl-XML-Parser
policycoreutils-python
sos
strace
sysstat
tcpdump
traceroute
vconfig
vlock
w3m
wget
yum
#
######################################################################
# pre-install operations
#
#%pre 
#%end
######################################################################
# post-install operations
#http://www.linuxjournal.com/content/bash-redirections-using-exec
#
%post
chvt 3
exec </dev/tty3 >/dev/tty3
#---------------------------------------------------------------------
NOW="$NOW"
INSTDIR="$INSTDIR" 
HAPFCF="$HAPFCF"
HACFGFILE="$HACFGFILE"
MTDIR="$MTDIR"
GENVERS="$GENVERS"
BACKDIR="$BACKDIR"
MEDSET="$MEDSET"
MAINFLAG="$MAINFLAG"
LOGFILE="$LOGFILE"
GENHOST="$PSET{"HOSTNAME",$MYROLE}"
GENROLE="$MYROLE"
#---------------------------------------------------------------------
mkdir \$INSTDIR
mkdir \$INSTDIR/backup                                               |tee -a \$LOGFILE 2>&1
mount $PSET{"PENDRVUSBDEVICE",$MYROLE} \$MTDIR                                              |tee -a \$LOGFILE 2>&1  
cp -rp /media/$LKSFIL \$INSTDIR                                   |tee -a \$LOGFILE 2>&1 	
cp -rp /media/rpms  \$INSTDIR                                        |tee -a \$LOGFILE 2>&1 
cp -rp /media/script  \$INSTDIR                                      |tee -a \$LOGFILE 2>&1 
cp -rp /media/insta \$INSTDIR                                        |tee -a \$LOGFILE 2>&1 
cp -rp /media/configure.sh \$INSTDIR                                 |tee -a \$LOGFILE 2>&1
[ -d "/media/hsmsw" ] && cp -rp /media/hsmsw \$INSTDIR               |tee -a \$LOGFILE 2>&1  
[ -d "/media/rhpatches" ] && cp -rp /media/rhpatches \$INSTDIR       |tee -a \$LOGFILE 2>&1  
[ "$PSET{"INSTALL_HWMGMT",$MYROLE}" = "yes" ] && cp -rp /media/orahwm \$INSTDIR                 |tee -a \$LOGFILE 2>&1
mkdir $HAPFCF 
chown root:root $HAPFCF 
chmod 755 $HAPFCF 
ls -dl $HAPFCF                                            |tee -a \$LOGFILE 2>&1
#---------------------------------------------------------------------
echo "start kickstart installation of \$GENHOST"                     |tee -a \$LOGFILE 2>&1
echo "starting at \`date\` with configure-timestamp $NOW"     |tee -a \$LOGFILE 2>&1
printf \"\\n\\n\\n\"                                                     |tee -a \$LOGFILE 2>&1
cd / ; umount /media  ; df -h                                       |tee -a \$LOGFILE 2>&1
echo "Importing GPG key for http://packages.atrpms.net/dist/el6/drbd/" |tee -a \$LOGFILE 2>&1
rpm --import $INSTDIR/rpms/RPM-GPG-KEY.atrpms              |tee -a \$LOGFILE 2>&1
echo "Installing non-standard RedHat RPMs in \$INSTDIR"              |tee -a \$LOGFILE 2>&1   
rpm -Uvh $INSTDIR/rpms/kernel*                             |tee -a \$LOGFILE 2>&1
rpm -Uvh $INSTDIR/rpms/atrpm*                              |tee -a \$LOGFILE 2>&1
rpm -Uvh $INSTDIR/rpms/perl*                               |tee -a \$LOGFILE 2>&1
rpm -Uvh $INSTDIR/rpms/drbd*                               |tee -a \$LOGFILE 2>&1
rpm -Uvh $INSTDIR/rpms/cluster-g*                          |tee -a \$LOGFILE 2>&1
rpm -Uvh $INSTDIR/rpms/coro*                               |tee -a \$LOGFILE 2>&1
rpm -Uvh --nodeps $INSTDIR/rpms/resource-agent*            |tee -a \$LOGFILE 2>&1
rpm -Uvh $INSTDIR/rpms/clusterlib*                         |tee -a \$LOGFILE 2>&1
rpm -Uvh $INSTDIR/rpms/libqb*                              |tee -a \$LOGFILE 2>&1
rpm -Uvh $INSTDIR/rpms/pacemak*                            |tee -a \$LOGFILE 2>&1
rpm -Uvh $INSTDIR/rpms/pssh*                               |tee -a $LOGFILE 2>&1
rpm -Uvh --nodeps $INSTDIR/rpms/crmsh*                     |tee -a $LOGFILE 2>&1
[ -d "$INSTDIR/orahwm" ] && ( rpm -Uvh $INSTDIR/orahwm/*.rpm |tee -a \$LOGFILE 2>&1 )
#
#---------------------------------------------------------------------
#
. \$INSTDIR/configure.sh           
. \$INSTDIR/script/config_functions.sh
sleep 1
. \$INSTDIR/script/install_patches.sh $MYROLE
. \$INSTDIR/script/config_network.sh  $MYROLE                                          
. \$INSTDIR/script/config_security.sh $MYROLE                                  
sleep 1
#
#---------------------------------------------------------------------
#
cat <<EFLAG  >$MAINFLAG                                       
INSTDIR=$INSTDIR
MTDIR=$MTDIR
GENVERS=$GENVERS
BACKDIR=$BACKDIR
HAPFCF=$HAPFCF
HACFGFILE=$HACFGFILE
MEDSET=$MEDSET
MAINFLAG=$MAINFLAG
LOGFILE=$LOGFILE
GENHOST=$PSET{"HOSTNAME",$MYROLE}
GENROLE=$MYROLE
NOW=$NOW
DATE=`date "+%d%m%Y%H%M"`
STARTP2="YES"
RUN[1]="$HAPFCF/configure.sh"
RUN[2]="$HAPFCF/config_functions.sh"
EFLAG
#
cp -p $INSTDIR/configure.sh $HAPFCF
cp -p $INSTDIR/script/config_functions.sh $HAPFCF
echo " set flagfile for first restart:"                             |tee -a \$LOGFILE 2>&1  
ls -la $MAINFLAG                                             |tee -a \$LOGFILE 2>&1  
mv -f /etc/rc.d/rc.local \$INSTDIR/backup/rc.local.\$GENHOST.\$NOW     |tee -a \$LOGFILE 2>&1
cp -f $INSTDIR/script/phase2.sh /etc/rc.d/rc.local         |tee -a \$LOGFILE 2>&1
#
printf \"\\n\\n\\n PHASE 1 of \$NOW ended at \`date\`\\n\"                   |tee -a \$LOGFILE 2>&1
#------------------------------------------------------------------------------
chvt 1
exec </dev/tty1 >/dev/tty1
%end
#
#
#
#  End of Kickstartfile
# 
#===================================================================================
EOK1
#
#
;
print UTLIST "\n";
close (UTLIST);
&make_unixfile($KSFILE);
} ;# for role
} ;# on if role = "yes"
#====================================================================================
#
# SINGLE SERVER OR LAB SETUP BELOW IS MORE GENERIC THAN HAPF2.1 DEFAULT INSTALL
# -----------------------------------------------------------------------------
# Its easier and better readable if we treat SingleServer completely independent 
# rather than mixing the kickstartfiles and make them error-prone to edit later
#
if ($PSET{"CREATE_ROLE","SingleServer"} eq "yes" ) {
	$MYROLE="SingleServer";
	$LOGFILE=$INSTDIR."/instlog-nsn.".$MYROLE.".".$NOW.".log";
	$SSKSFIL="$here/ks-".$MYROLE.".cfg";
	
	if ($PSET{"VLAN1ID",$MYROLE}) {
		$NET1LINE="network --device eth1 --bootproto=dhcp --onboot=no";
		$NET2LINE="network --device eth2 --bootproto=dhcp --onboot=no";
	} else {
		$NET1LINE="#network --device eth1 --bootproto=dhcp --onboot=no";
		$NET2LINE="#network --device eth2 --bootproto=dhcp --onboot=no";
	};

	if ( -f $SSKSFIL ) { &backup_file($SSKSFIL) } ;	
	open (SSKS,">$SSKSFIL")||die "cannot open Kickstart File $OUTFILE \n";
	SSKS->autoflush(1);
	$LSKSFIL=basename($SSKSFIL);
	push (@NEWONES, $SSKSFIL);
#===================================================================================
#start creating kickstart file for role, you can edit the kickstart below if needed
# (and if you dont know what you are doing there you gotta fix it alone later ;)
	print SSKS <<EOK2
#===================================================================================
#
#     ---- NSN / Insta CA server ----
#  Kickstartfile, generated automatically for
#  $MYROLE, $PSET{"HOSTNAME",$MYROLE}
#  OAM IP $PSET{"IPADDReth0",$MYROLE}
#  config creation : $NOW
#  
# http://fedoraproject.org/wiki/Anaconda/Kickstart
# http://www.mail-archive.com/rhelv5-list@redhat.com/msg06776.html
# http://wiki.centos.org/TipsAndTricks/KickStart
# invoke with : linux text ks=hd:sd[X]{y}:/ks.cfg
#
#     !!! SINGLE SERVER IS NOT SUPPORTED FOR PRODUCTION NETWORKS !!!
#
install
text
key --skip
monitor --noprobe
lang en_US.UTF-8
keyboard us
firstboot --disable
timezone --utc $PSET{"TIMEZONE",$MYROLE}
#
######################################################################
# basic host security configuration
#
rootpw --iscrypted \$1\$Z.WA/G5T\$/maSQ0xeitUM7ziBQb6AU.
firewall --enabled --port=22:tcp 
authconfig --enableshadow --passalgo=sha512
selinux --disabled
#
######################################################################
# network interface configuration
#
network --device eth0 --bootproto=static --onboot=yes --hostname=$PSET{"HOSTNAME",$MYROLE} --gateway=$PSET{"DEFGW",$MYROLE} --ip=$PSET{"IPADDReth0",$MYROLE} --netmask=$PSET{"NETMASKeth0",$MYROLE}
# Additional Network Interfaces for SingleServer are only defined if VLANs are used 
$NET1LINE
$NET2LINE
#
######################################################################
# File system configuration
#
bootloader --location=mbr      --driveorder=$PSET{"INITIALDSKDEVPREFIX",$MYROLE}
clearpart  --all  --initlabel  --drives=$PSET{"INITIALDSKDEVPREFIX",$MYROLE}
part /.recovery              --asprimary    --fstype=ext4    --ondisk=$PSET{"INITIALDSKDEVPREFIX",$MYROLE} --size=$PSET{"SIZRECO",$MYROLE}
part /boot                   --asprimary    --fstype=ext4    --ondisk=$PSET{"INITIALDSKDEVPREFIX",$MYROLE} --size=$PSET{"SIZBOOT",$MYROLE}      
part /                       --asprimary    --fstype=ext4    --ondisk=$PSET{"INITIALDSKDEVPREFIX",$MYROLE} --size=$PSET{"SIZROOT",$MYROLE}     
part /var                                   --fstype=ext4    --ondisk=$PSET{"INITIALDSKDEVPREFIX",$MYROLE} --size=$PSET{"SIZEVAR",$MYROLE}     
part /usr/local/certifier                   --fstype=ext4    --ondisk=$PSET{"INITIALDSKDEVPREFIX",$MYROLE} --size=$PSET{"SIZCERTIFIER",$MYROLE}     
part /backup                 --grow         --fstype=ext4    --ondisk=$PSET{"INITIALDSKDEVPREFIX",$MYROLE} --size=$PSET{"SIZBACKUP",$MYROLE}      
part swap                                                    --ondisk=$PSET{"INITIALDSKDEVPREFIX",$MYROLE} --size=$PSET{"SIZSWAP",$MYROLE}
#
######################################################################
# packages to install
#
%packages --nobase
aide
dialog
gnutls
libaio
libibverbs
librdmacm
libxslt
lsof
mailcap
man
net-snmp
net-snmp-utils
nmap
ntp
openhpi
OpenIPMI
OpenIPMI-libs
openldap
openldap-servers
openldap-clients
openssh
openssh-clients
openssh-server
openssl
perl-TimeDate
perl-HTML-Tagset
perl-HTML-Parser
perl-IO-Compress-Base
perl-Compress-Raw-Zlib
perl-IO-Compress-Zlib
perl-Compress-Zlib
perl-URI
perl-libwww-perl
perl-XML-Parser
policycoreutils-python
sos
strace
sysstat
tcpdump
traceroute
vconfig
vlock
w3m
wget
yum
#
######################################################################
# pre-install operations
#
#%pre 
#%end
######################################################################
# post-install operations
#http://www.linuxjournal.com/content/bash-redirections-using-exec
#
%post
chvt 3
exec </dev/tty3 >/dev/tty3
#---------------------------------------------------------------------
NOW="$NOW"
INSTDIR="$INSTDIR"
MTDIR="$MTDIR"
GENVERS="$GENVERS"
HAPFCF="$HAPFCF"
HACFGFILE="$HACFGFILE"
BACKDIR="$BACKDIR"
MEDSET="$MEDSET"
MAINFLAG="$MAINFLAG"
LOGFILE="$LOGFILE"
GENHOST="$PSET{"HOSTNAME",$MYROLE}"
GENROLE="$MYROLE"
#---------------------------------------------------------------------
mkdir \$INSTDIR  
mkdir \$INSTDIR/backup                                                    |tee -a \$LOGFILE 2>&1
mount $PSET{"PENDRVUSBDEVICE",$MYROLE} \$MTDIR                            |tee -a \$LOGFILE 2>&1  
cp -rp /media/$LSKSFIL \$INSTDIR                                          |tee -a \$LOGFILE 2>&1 	
cp -rp /media/rpms  \$INSTDIR/rpms                                |tee -a \$LOGFILE 2>&1 
cp -rp /media/script  \$INSTDIR                                           |tee -a \$LOGFILE 2>&1 
cp -rp /media/insta \$INSTDIR                                             |tee -a \$LOGFILE 2>&1 
cp -rp /media/configure.sh \$INSTDIR                                      |tee -a \$LOGFILE 2>&1
[ -d "/media/hsmsw" ] && cp -rp /media/hsmsw \$INSTDIR               |tee -a \$LOGFILE 2>&1  
[ -d "/media/rhpatches" ] && cp -rp /media/rhpatches \$INSTDIR       |tee -a \$LOGFILE 2>&1  
[ "$PSET{"INSTALL_HWMGMT",$MYROLE}" = "yes" ] && cp -rp /media/orahmp \$INSTDIR            |tee -a \$LOGFILE 2>&1
mkdir $HAPFCF 
chown root:root $HAPFCF 
chmod 755 $HAPFCF 
ls -ld $HAPFCF                                                |tee -a \$LOGFILE 2>&1
#---------------------------------------------------------------------
echo "start kickstart installation of $GENHOST"                           |tee -a \$LOGFILE 2>&1
echo "starting at \`date\` with configure-timestamp \$NOW"                |tee -a \$LOGFILE 2>&1
printf \"\\n\\n\\n\"                                                      |tee -a \$LOGFILE 2>&1
cd / ; umount /media  ; df -h                                             |tee -a \$LOGFILE 2>&1
echo "Importing GPG key for http://packages.atrpms.net" |tee -a \$LOGFILE 2>&1
rpm --import $INSTDIR/rpms/RPM-GPG-KEY.atrpms              |tee -a \$LOGFILE 2>&1
rpm -Uvh $INSTDIR/rpms/kernel*                                            |tee -a \$LOGFILE 2>&1
rpm -Uvh $INSTDIR/rpms/atrpm*                                             |tee -a \$LOGFILE 2>&1
rpm -Uvh $INSTDIR/rpms/perl*                                              |tee -a \$LOGFILE 2>&1
[ -d "$INSTDIR/orahwm" ] && ( rpm -Uvh $INSTDIR/orahwm/*.rpm |tee -a \$LOGFILE 2>&1 )
#
. \$INSTDIR/configure.sh           
. \$INSTDIR/script/config_functions.sh
sleep 1
. \$INSTDIR/script/install_patches.sh $MYROLE
. \$INSTDIR/script/config_network.sh  $MYROLE                                          
. \$INSTDIR/script/config_security.sh $MYROLE                                  
sleep 1
#
#---------------------------------------------------------------------
#
cat <<EFLAG  >$MAINFLAG                                     
INSTDIR=$INSTDIR
MTDIR=$MTDIR
GENVERS=$GENVERS
BACKDIR=$BACKDIR
HAPFCF=$HAPFCF
HACFGFILE=$HACFGFILE
MEDSET=$MEDSET
MAINFLAG=$MAINFLAG
LOGFILE=$LOGFILE
GENHOST=$PSET{"HOSTNAME",$MYROLE}
GENROLE=$MYROLE
NOW=$NOW
DATE=`date "+%d%m%Y%H%M"`
STARTP2=YES
RUN[1]=$HAPFCF/configure.sh
RUN[2]=$HAPFCF/config_functions.sh
EFLAG
#
cp -p $INSTDIR/configure.sh $HAPFCF
cp -p $INSTDIR/script/config_functions.sh $HAPFCF
#
echo " set flagfile for first restart:"                                   |tee -a \$LOGFILE 2>&1  
ls -la /var/tmp/first.flag                                                |tee -a \$LOGFILE 2>&1  
mv -f /etc/rc.d/rc.local \$INSTDIR/backup/rc.local.\$GENHOST.\$NOW        |tee -a \$LOGFILE 2>&1
cp -f $INSTDIR/script/phase2.sh /etc/rc.d/rc.local                        |tee -a \$LOGFILE 2>&1
#
printf \"\\n\\n\\n PHASE 1 of \$NOW ended at \`date\`\\n\"                |tee -a \$LOGFILE 2>&1
#------------------------------------------------------------------------------
chvt 1
exec </dev/tty1 >/dev/tty1
%end
#
#
#
#  End of Kickstartfile
# 
#===================================================================================
EOK2
#
#
;
print SSKS "\n";
close (SSKS);
&make_unixfile($SSKSFIL);
} # for role SingleServer
#===================================================================================
#      CREATE SYSLINUX.CFG
#===================================================================================
#
$SYSLINUX="$here/syslinux.cfg";
$NICETEXT = ();
$NICETEXT{"be1"} = " (Primary CA Backend)\n";
$NICETEXT{"be2"} = " (Secondary CA Backend)\n";
$NICETEXT{"fe1"} = " (Primary CA Frontend)\n";
$NICETEXT{"fe2"} = " (Secondary CA Frontend)\n";
$NICETEXT{"fe3"} = " (Primary CA X-tra-Frontend)\n";
$NICETEXT{"fe4"} = " (Secondary CA Xtra-Frontend)\n";
$NICETEXT{"SingleServer"}= " (SingleServer - only Testlab - no HA)\n";
#
push (@NEWONES,$SYSLINUX);
if ( -f $SYSLINUX ) { &backup_file($SYSLINUX) } ;
open (SYSLIN,">$SYSLINUX")||die "cannot open Boot-Menu config File $SYSLINUX \n";
SYSLIN->autoflush(1);
#===================================================================================
# start creating syslinux.cfg file
#
print SYSLIN <<EOSL
###########################################################################
# NSN INSTA HAPF2.1 PLATFORM SCRIPT
#--------------------------------------------------------------------------
# Script default name   : syslinux.cfg
# Media set             : $MEDSET
# configure.sh          : $NOW
###########################################################################
#
default menu.c32
MENU TITLE NSN INSTA HAPF2.1 RAPID SETUP
EOSL
;
#
#-----------------------------------------------------------------------------------
foreach $MYROLE ( @ALLROLES ) {
	if ( $PSET{"CREATE_ROLE",$MYROLE} eq "yes" ) {
		@USBD=split /\//,$PSET{"PENDRVUSBDEVICE",$MYROLE};
#
#===================================================================================
# continue and append active roles
#
print SYSLIN "## -- Auto-Install + config " . $MYROLE . " -- ##\nLABEL " . $MYROLE . "\nMENU LABEL " . $PSET{"HOSTNAME",$MYROLE} . $NICETEXT{$MYROLE};
print SYSLIN "KERNEL " . $RHEL . "/isolinux/vmlinuz\nAPPEND linux initrd=" . $RHEL . "/isolinux/initrd.img method=hd:" . @USBD[2] . ":/" . $RHEL . " ks=hd:" . @USBD[2] . ":/ks-" . $MYROLE. ".cfg\n";
}
}
close(SYSLIN);
&make_unixfile($OUTFILE);
#===================================================================================
#    END OF MKKS PROCEDURE
#===================================================================================
print "\n CREATED NEW FILES FOR INSTALLATION " . $NOW;
print "\n ===============================================\n";
foreach $FILE ( @NEWONES ) { print $FILE . "\n" };
if (  @OLDONES ) {
	print "\n SAVED OLD FILES FROM PREVIOUS SET:";
	print "\n ===============================================\n";
	foreach $FILE ( @OLDONES ) { 
		@OLD = split /\./,$FILE;
		$PASTFILE=@OLD[0].".cfg";
		print "savecopy: old " . $PASTFILE . "\t==>\t" . $FILE ."\n"; 
	}
}
print "\n\n Press any key to continue . . .\n";
$DUMMY=<STDIN>; exit 0;
print "\n";
#===================================================================================

sub backup_file {
	my $OLDFILE=$_[0];
	open(INFILE,"<$OLDFILE");
	$FOUND=1;
	while ($line = <INFILE>) {
		if ( $line =~ m/^NOW=\"\d{12}\"/ || $line =~ m/^# configure.sh          : \d{12}/ ) 
		{
			@OLDNOW=split(/=/,$line);
			chomp(@OLDNOW[1]);
			@OLDNOW[1] =~ s/\"//g;
			if ( basename($OLDFILE) eq "syslinux.cfg" ) {
				@OLDNOW=split(/:/,$line);				
				chomp(@OLDNOW[1]);
				@OLDNOW[1] =~ s/^\s+//;
				@OLDNOW[1] =~ s/\s+$//;
			}

			$NEWFILE=$OLDFILE . "." . @OLDNOW[1];
			push (@OLDONES, $NEWFILE);
			fmove($OLDFILE,$NEWFILE);
			$FOUND=0;
		}
		last if $FOUND == 0;
	}
	close(INFILE);
}
#===================================================================================
sub make_unixfile {

	my $DOSFILE=$_[0];
	fmove($DOSFILE,'./tempconv.txt');

	open(INFILE,"<./tempconv.txt");
	open(OUTFIL,">$DOSFILE");
	OUTFIL->autoflush(1);
	binmode(OUTFIL);
	local $\ = "\cJ";	
	while ($line = <INFILE>) {
		$line =~ s/\r|\n//g;
		print OUTFIL "${line}";
	}
#	print OUTFIL "#converted to Unix lineends...\n";
	close(OUTFIL);
	close(INFILE);
	unlink("./tempconv.txt");
}
