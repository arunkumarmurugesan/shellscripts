#!/bin/bash
#===================================================================================
#
#             	FILE: server_harden_rhel.sh
#
# DESCRIPTION : This script will implement the PCI Security Standards
# WRITTEN BY  : Arunkumar M
# REQUIREMENTS: ---
#     	BUGS: ---
#    	NOTES: ---
#  	COMPANY: Minjar
#  	CREATED: 16/08/2017
# 	REVISION: ---
#===================================================================================
readonly HOSTNAME=`hostname`
readonly LOG="/tmp/${HOSTNAME}_audit_$( date '+%Y-%m-%d.csv')"

#System files
#============================================
readonly SECURETTY="/etc/securetty"
readonly PROFILE="/etc/profile"
#readonly FUNCTIONS="/etc/functions"
readonly ISSUE="/etc/issue.net"
readonly SSHD="/etc/ssh/sshd_config"
#===============================================

readonly BACKUP_DIR="/tmp/backup"
readonly GREEN="\e[0;92m"
readonly RED="\e[0;91m"
readonly WHITE="\e[0m"
readonly BLUE="\e[1;37m"
#set the header for CSV file
echo "S.No,Items,Policy,Compliance(Y/N)" > ${LOG}

backup_file(){

	local file=$1
	local dir_file=`dirname $1`
	local base_file=`basename $1`
	if [ ! -d  ${BACKUP_DIR}/${dir_file} ]
	then
    	mkdir -p ${BACKUP_DIR}/${dir_file}
	fi
	/bin/cp -pr ${file} ${BACKUP_DIR}/${dir_file}/${base_file}-harden
	if [ $? -eq "0" ]
	then
    	echo -e "${GREEN}File backup : ${file} is successfull${WHITE}"
	else
    	echo -e "${RED}File backup : ${file} is unsuccessfull${WHITE}"
	fi
}
   	 


creation_csv(){
    
	local no=$1
	local items=$2
	local policy=$3
	local compliance=$4
	echo "$no, $items, $policy, $compliance " >> ${LOG}
    

}


create_ssh(){

	cat <<EOF> /tmp/sshd_config

#	$OpenBSD: sshd_config,v 1.80 2008/07/02 02:24:18 djm Exp $

# This is the sshd server system-wide configuration file.  See
# sshd_config(5) for more information.

# This sshd was compiled with PATH=/usr/local/bin:/bin:/usr/bin

# The strategy used for options in the default sshd_config shipped with
# OpenSSH is to specify options with their default value where
# possible, but leave them commented.  Uncommented options change a
# default value.

Port 22
#AddressFamily any
#ListenAddress 0.0.0.0
#ListenAddress ::

# Disable legacy (protocol version 1) support in the server for new
# installations. In future the default will change to require explicit
# activation of protocol 1
Protocol 2

# HostKey for protocol version 1
#HostKey /etc/ssh/ssh_host_key
# HostKeys for protocol version 2
#HostKey /etc/ssh/ssh_host_rsa_key
#HostKey /etc/ssh/ssh_host_dsa_key

# Lifetime and size of ephemeral version 1 server key
#KeyRegenerationInterval 1h
#ServerKeyBits 1024

# Logging
# obsoletes QuietMode and FascistLogging
#SyslogFacility AUTH
SyslogFacility AUTHPRIV
#LogLevel INFO

# Authentication:

LoginGraceTime 60
PermitRootLogin no
#StrictModes yes
MaxAuthTries 3    
#MaxSessions 10
AllowUsers rakesh minjar ec2-user   
#RSAAuthentication yes
PubkeyAuthentication yes
#AuthorizedKeysFile	.ssh/authorized_keys
#AuthorizedKeysCommand none
#AuthorizedKeysCommandRunAs nobody

# For this to work you will also need host keys in /etc/ssh/ssh_known_hosts
RhostsRSAAuthentication no
# similar for protocol version 2
HostbasedAuthentication no
# Change to yes if you don't trust ~/.ssh/known_hosts for
RhostsRSAAuthentication no
#IgnoreUserKnownHosts no
# Don't read the user's ~/.rhosts and ~/.shosts files
IgnoreRhosts yes

# To disable tunneled clear text passwords, change to no here!
PermitEmptyPasswords no
PasswordAuthentication yes

# Change to no to disable s/key passwords
#ChallengeResponseAuthentication yes
ChallengeResponseAuthentication no

# Kerberos options
#KerberosAuthentication no
#KerberosOrLocalPasswd yes
#KerberosTicketCleanup yes
#KerberosGetAFSToken no

# GSSAPI options
#GSSAPIAuthentication no
GSSAPIAuthentication yes
#GSSAPICleanupCredentials yes
GSSAPICleanupCredentials yes
#GSSAPIStrictAcceptorCheck yes
#GSSAPIKeyExchange no

# Set this to 'yes' to enable PAM authentication, account processing,
# and session processing. If this is enabled, PAM authentication will
# be allowed through the ChallengeResponseAuthentication and
# PasswordAuthentication.  Depending on your PAM configuration,
# PAM authentication via ChallengeResponseAuthentication may bypass
# the setting of "PermitRootLogin without-password".
# If you just want the PAM account and session checks to run without
# PAM authentication, then enable this but set PasswordAuthentication
# and ChallengeResponseAuthentication to 'no'.
#UsePAM no
UsePAM yes

# Accept locale-related environment variables
AcceptEnv LANG LC_CTYPE LC_NUMERIC LC_TIME LC_COLLATE LC_MONETARY LC_MESSAGES
AcceptEnv LC_PAPER LC_NAME LC_ADDRESS LC_TELEPHONE LC_MEASUREMENT
AcceptEnv LC_IDENTIFICATION LC_ALL LANGUAGE
AcceptEnv XMODIFIERS

#AllowAgentForwarding yes
#AllowTcpForwarding yes
#GatewayPorts no
X11Forwarding yes
#X11DisplayOffset 10
#X11UseLocalhost yes
#PrintMotd yes
#PrintLastLog yes
#TCPKeepAlive yes
#UseLogin no
#UsePrivilegeSeparation yes
#PermitUserEnvironment no
#Compression delayed
#ClientAliveInterval 0
#ClientAliveCountMax 3
#ShowPatchLevel no
#UseDNS yes
#PidFile /var/run/sshd.pid
#MaxStartups 10
#PermitTunnel no
#ChrootDirectory none

# no default banner path
Banner /etc/issue.net

# override default of no subsystems
Subsystem	sftp	/usr/libexec/openssh/sftp-server

# Example of overriding settings on a per-user basis
#Match User anoncvs
#	X11Forwarding no
#	AllowTcpForwarding no
#	ForceCommand cvs server

EOF

}    
authen_harden(){


#1. Checking for UID 0 accounts other than root

	echo -e "${BLUE}1. UID 0 accounts other than root..${WHITE}"
	local zero_uid=(`awk -F: ' ($3 == 0) { print $1 }' /etc/passwd`)
	if [[ ${#zero_uid[@]} -eq "1"  ]] && [[ ${zero_uid[@]} == "root" ]]
	then
    	echo -e "${GREEN}RESULT: Only root account have superuser privilege ${WHITE}"
    	creation_csv "1" "Authentication hardening" "No UID 0 accounts other than root" "YES"
	else
    	creation_csv "1" "Authentication hardening" "No UID 0 accounts other than root" "NO"
    	echo -e "${RED}RESULT: Other users have also superuser privilege.${WHITE}"
	fi
#2. Restrict root logins to system console
	#backup
	echo -e "\n${BLUE}2.Restrict root login..${WHITE}"
	backup_file ${SECURETTY}
    
    	for i in `seq 1 6`
	do
	echo "tty${i}" >> ${SECURETTY}
	done
	for i in `seq 1 11`
	do
	echo "vc/${i}" >> ${SECURETTY}
	done
	echo "console" >> ${SECURETTY}
    	creation_csv "2" "Authentication hardening" "Restrict root logins to system console" "YES"
	#diff
#	diff ${SECURETTY} ${BACKUP_DIR}/${SECURETTY}-harden
	echo -e "${GREEN}RESULT: Restrict root login Completed${WHITE}"


#3.No accounts with empty password fields    
	echo -e "\n${BLUE}3.Accounts with empty password fields..${WHITE}"
	local empty_password=(`awk -F: ' ($2 == " ") { print $1 }' /etc/shadow`)
	if [[ ${#empty_password[@]} -eq "0" ]]
	then
    	echo -e "${GREEN}RESULT: No accounts with empty password fields ${WHITE}"
    	creation_csv "3" "Authentication hardening" "No accounts with empty password fields" "YES"
	else
    	echo -e "${RED}RESULT: Accounts have empty passeord  fields.${WHITE}"
    	create_csv "3" "Authentication hardening" "No accounts with empty password fields" "NO"
	fi


#4. Check the permission of shadow file
	echo -e "\n${BLUE}4.Permission for shadow file..${WHITE}"
	local check_result=`ls -l /etc/shadow   | awk  '{ if (($1 == "----------") && ($3 == "root") && ($4 == "root")) print $4 }'`
	if [[ ${check_result} == "root" ]]
	then
    	echo -e "${GREEN}RESULT: Permission of /etc/shadow file verified ${WHITE}"
            	creation_csv "4" "Authentication hardening" "File Permission of shadow file" "YES"
	else
    	echo -e "${RED}RESULT: Permission of /etc/shadow file not matching with compliance.${WHITE}"
            	creation_csv "4" "Authentication hardening" "File Permission of shadow file" "NO"
	fi

#5. Inactive users timeout  from shell
	echo -e "\n${BLUE}5.Console idle timeout..${WHITE}"
	backup_file ${PROFILE}
	echo TMOUT=900 >> /etc/profile
	TIMEOUT=900 >> /etc/profile
	export readonly TMOUT TIMEOUT >> /etc/profile
	if [[ $? -eq "0" ]]
	then
    	echo -e "${GREEN}RESULT: Implemented console idle timeout of 900secs done ${WHITE}"
    	creation_csv "5" "Authentication hardening" "Inactive users timeout (Time out Feature)" "YES"
	else
    	echo -e "${RED}RESULT: Filed to implement console idle timeout.${WHITE}"
            	creation_csv "5" "Authentication hardening" "Inactive users timeout (Time out Feature)" "NO"
	fi
     
#7. Disable xinetd services
	echo -e "\n${BLUE}7.Disable the xinetd services.${WHITE}"
	local xinetd_service=(chargen chargen-udp cups-lpd daytime  daytime-udp echo echo-udp eklogin finger gssftp imap  imaps ipop2 ipop3 krb5-telnet klogin kshell ktalk ntalk pop3s rexec rlogin rsh rsync servers services sgi_fam talk telnet tftp time time-udp vsftpd wu-ftpd)
	for SERVICE in ${xinetd_service[@]}
	do
    	chkconfig ${SERVICE} off
    	#cat /dev/null
	done
	if [[ $? -eq "0" ]]
	then
    	echo -e "${GREEN}RESULT: xinetd services has been disabled${WHITE}"
    	creation_csv "7" "Identify and shutdown unwanted ports & services" "Disable xinetd services" "YES"
	else
    	echo -e "${RED}RESULT: Unable to disbale the xinetd service${WHITE}"
            	creation_csv "7" "Identify and shutdown unwanted ports & services" "Disable xinetd services" "NO"
	fi

#8.  Disbale the starup service
	echo -e "\n${BLUE}8.Disable the startup services.${WHITE}"
	local startup_service=(apmd canna FreeWnn gpm hpoj innd irda isdn kdcrotate lvs mars-nwe oki4daemon privoxy rstatd rusersd rwalld rwhod spamassassin wine ypbind ypserv yppasswdd portmap smb  lpd tux named webmin kudzu squid cups cups-config-daemon avahi-daemon bluetooth hidd pcscd rpcgssd rpcidmapd)
	for SERVICE in ${startup_service[@]}
	do
    	#service ${SERVICE} stop
    	#chkconfig ${SERVICE} off
    	cat /dev/null
	done
	if [[ $? -eq "0" ]]
    	then
            	echo -e "${GREEN}RESULT: start up services has been disabled${WHITE}"
            	creation_csv "8" "Identify and shutdown unwanted ports & services" "Disable Startup services" "YES"
    	else
            	echo -e "${RED}RESULT: Unable to disbale the startup service${WHITE}"
            	creation_csv "8" "Identify and shutdown unwanted ports & services" "Disable startup services" "NO"
    	fi


#9. Create appropriate warning banners
	echo -e "\n${BLUE}9.Create appropriate warning banner.${WHITE}"
	cat <<EOF> /tmp/issue.net
***************************************************************************
This system is for the use of Authorized Users only
****************************************************************************
EOF
	backup_file ${ISSUE}
	cp /tmp/issue.net ${ISSUE}
	if [[ $? -eq "0" ]]
    	then
            	echo -e "${GREEN}RESULT: Created appropriate warning banners${WHITE}"
            	creation_csv "9" "Authentication hardening" "Create appropriate warning banners" "YES"
    	else
            	echo -e "${RED}RESULT: Unable to Create appropriate warning banners${WHITE}"
            	creation_csv "9" "Authentication hardening" "Create appropriate warning banners" "NO"
    	fi

#.10 SSH hardening
#	echo -e "\n${BLUE}10.Implement ssh hardening..${WHITE}"
	#call function to create sshd configuration
#	create_ssh
#	backup_file ${SSHD}
#	cp /tmp/sshd_config ${SSHD}
#	if [[ $? -eq "0" ]]
 #   	then
  #          	echo -e "${GREEN}RESULT: SSHD server hardening completed ${WHITE}"
   #         	creation_csv "10" "Authentication hardening" "SSH Server hardening" "YES"
  #  	else
   #         	echo -e "${RED}RESULT: Failed to complete the SSH server hardening${WHITE}"
    #        	creation_csv "10" "Authentication hardening" "SSH Server hardening" "NO"
    #	fi

#.11 Password aging
    echo -e "\n${BLUE}11.Implement password aging ..${WHITE}"
    cd /etc/
    alias cp='cp'
    cp -p login.defs login.defs.orig
    cp login.defs login.defs.tmp
    awk '/^#? *PASS_MAX_DAYS/ { print "PASS_MAX_DAYS 90"; next }; { print }' login.defs.tmp > login.defs
    cp login.defs login.defs.tmp
    awk '/^#? *PASS_MIN_DAYS/ { print "PASS_MIN_DAYS 7"; next };
    { print }' login.defs.tmp > login.defs
    cp login.defs login.defs.tmp
    awk '/^#? *PASS_MIN_LEN/ { print "PASS_MIN_LEN 6"; next };
    { print }' login.defs.tmp > login.defs
    cp login.defs login.defs.tmp
    awk '/^#? *PASS_WARN_AGE/ { print "PASS_WARN_AGE 28"; next };
    { print }' login.defs.tmp > login.defs
    if [ "`egrep -l ^PASS_MAX_DAYS login.defs`" == "" ]; then
   	 echo 'PASS_MAX_DAYS 90' >> login.defs
    fi
    if [[ $? -eq "0" ]]
    	then
            	echo -e "${GREEN}RESULT Password Policy  Password aging completed ${WHITE}"
            	creation_csv "11" "Password Policy" "Password aging" "YES"
    	else
            	echo -e "${RED}RESULT: Failed to complete the Password aging${WHITE}"
            	creation_csv "11" "Password Policy" "Password Aging" "NO"
    	fi
		 
#12 force password policy with pam_passwdqc
    echo -e "\n${BLUE}12. Implement force password policy .${WHITE}"
    cd /etc/pam.d
    backup_file system-auth
    cp -p system-auth system-auth.orig
    cp system-auth system-auth.tmp
    awk '($3 ~ /pam_cracklib/ ) { $2 = "required"; $3 = "pam_passwdqc.so"; $4 = "min=disabled,24,12,8,8"; $5 = "max=40 passphrase=0 similar=deny random=0"; $6 = "" };
{print}' system-auth.tmp > system-auth
    if [[ $? -eq "0" ]]
    	then
            	echo -e "${GREEN}RESULT: force password policy completed ${WHITE}"
            	creation_csv "12" "Password Policy" "force password policy " "YES"
    	else
            	echo -e "${RED}RESULT: Failed to complete the force password policy${WHITE}"
            	creation_csv "12" "Password Policy" "force password policy " "NO"
    	fi

    rm system-auth.tmp
    #diff system-auth.orig system-auth

#13. remember last 3 passwords
    echo -e "\n${BLUE}13. Implement password histroy .${WHITE}"
    cd /etc/pam.d
    cp -p system-auth system-auth.orig
    cp system-auth system-auth.tmp
    awk '($1=="password") { if ($3=="pam_unix.so" ) { $3 = "pam_unix.so remember=3" }}; \
    {print}' system-auth.tmp > system-auth
    if [[ $? -eq "0" ]]
    	then
            	echo -e "${GREEN}RESULT: Password Policy  remember last 3 passwords ${WHITE}"
            	creation_csv "13" "Password Policy" "Not allow users to re-use three old passwords" "YES"
    	else
            	echo -e "${RED}RESULT: Failed to remember last 3 passwords${WHITE}"
            	creation_csv "13" "Password Policy" "remember last 3 passwords" "NO"
    	fi
    
    rm system-auth.tmp
    diff system-auth.orig system-auth


#14. lock out account after 3 failed try with pam_tally2
     echo -e "\n${BLUE}14. Implement password password lock.${WHITE}"
    cd /etc/pam.d
    cp -p system-auth system-auth.orig
    sed -i -e '/auth[ \t]* required[ \t]*pam_env.so/ a\auth    	required  	pam_tally2.so onerr=fail deny=3' -e '/account[ \t]*required[ \t]*pam_unix.so/ i\account 	required  	pam_tally2.so onerr=fail' /etc/pam.d/system-auth
    #echo "auth    	required  	pam_tally2.so onerr=fail deny=3" >> system-auth
    #echo "account 	required  	pam_tally2.so onerr=fail" >> system-auth
    if [[ $? -eq "0" ]]
    	then
            	echo -e "${GREEN}RESULT: Password Policy  lock out account after 3 failed try completed ${WHITE}"
            	creation_csv "14" "Password Policy" "lock out account after 3 failed login" "YES"
    	else
            	echo -e "${RED}RESULT: Failed to remember lock out account after 3 failed ${WHITE}"
            	creation_csv "14" "Password Policy" "lock out account after 3 failed try" "NO"
    	fi
    
    
diff system-auth.orig system-auth


    
}
main(){

#Calling the function for Authentication hardening
authen_harden

}

