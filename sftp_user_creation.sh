#!/bin/bash -xe
#title           :SFTP User Creations
#description     :This script will create a SFTP user in SFTP server based on OMv.6
#author          :Arunkumar M
#date            :22-Feb-2017
#==============================================================================
print_help() {
echo -e "Usage: bash $0 --username <username> --password <password> --action <action>"
}

while test -n "$1"; do
   case "$1" in
       --help)
           print_help
           ;;
       -h)
           print_help
           ;;
        --username)
            username=$2
            shift
            ;;
        --password)
            password=$2
            shift
            ;;
        --publickey)
            publickey=$2
            shift
            ;;
        --action)
            action=$2
            shift
            ;;
       *)
            echo "Unknown argument: $1"
            print_help
            ;;
    esac
    shift
done

DATE=`date +%Y-%m-%d`
DATE_TIME=`date +%Y-%m-%d-%H:%M`
LOCATION=/var/lib/jenkins/ansible_jobs/scripts/sftp_keys

msg() {
    local message="$1"
    echo "[$DATE_TIME] [INFO] $message"
}

error_exit() {
    local message="$1"
    echo "[$DATE_TIME] [ERROR] $message" 
    exit 1
}

create_sftp_dir(){
	if [ -d "/sftp/${username}" ]; then
  		msg "The SFTP home directory : /sftp/${username} is exist already"
	else
		mkdir -p /sftp/${username}
		[ $? -eq 0 ] && msg "The SFTP home directory has been created." || error_exit "Unable to create a directory!"
	fi
	chmod 770 /sftp/${username}
	 [ $? -eq 0 ] && msg "Changed the 770 permission to the sftp home directory " || error_exit "Failed to set permission to the sftp home dir"
	chmod g+s /sftp/${username}
	[ $? -eq 0 ] && msg "Applied the group ID to the sftp home dir" || error_exit "Failed to apply the group ID to the sftp home dir"
}

create_user_with_password(){
# Script to add a user to Linux system
if [ $(id -u) -eq 0 ]; then
	egrep "^$username" /etc/passwd >/dev/null
	if [ $? -eq 0 ]; then
		echo "$username exists!"
		exit 1
	else
		pass=$(perl -e 'print crypt($ARGV[0], "password")' $password)
		useradd -g sftpgroup -G extftpgroup -s /sbin/nologin -d /${username} -m -p ${pass}  ${username}
		[ $? -eq 0 ] && msg "User has been added to system!" || error_exit "Failed to add a user!"
		chown ${username}:intftpgroup  /sftp/${username}
		[ $? -eq 0 ] && msg "Changed the ownership as username: ${username} groupname: intftpgroup" || error_exit "Failed to add a user!"
		chage -I -1 -m 0 -M 99999 -E -1 ${username}
		[ $? -eq 0 ] && msg "Set the user to no expire" || error_exit "Failed to set a user to expire!"
	fi
else
	echo "Only root may add a user to the system"
	exit 2
fi
}

create_user_keybased(){
if [ $(id -u) -eq 0 ]; then
        egrep "^$username" /etc/passwd >/dev/null
        if [ $? -eq 0 ]; then
                msg "The user : ${username} already exists!"
                chown ${username}:intftpgroup  /sftp/${username}
                [ $? -eq 0 ] && msg "Changed the ownership as username: ${username} groupname: intftpgroup" || error_exit "Failed to add a user!"
                chage -I -1 -m 0 -M 99999 -E -1 ${username}
                [ $? -eq 0 ] && msg "Set the user to no expire" || error_exit "Failed to set a user to expire!"
        else
                useradd -g sftpgroup -G extftpgroup -s /sbin/nologin -d /${username}  ${username}
                [ $? -eq 0 ] && msg "User has been added to system!" || error_exit "Failed to add a user!"
                chown ${username}:intftpgroup  /sftp/${username}
                [ $? -eq 0 ] && msg "Changed the ownership as username: ${username} groupname: intftpgroup" || error_exit "Failed to add a user!"
                chage -I -1 -m 0 -M 99999 -E -1 ${username}
                [ $? -eq 0 ] && msg "Set the user to no expire" || error_exit "Failed to set a user to expire!"
        fi
else
        msg "Only root may add a user to the system"
        exit 1
fi
	touch /sftp/.ssh/${username}_authorized_keys 
	[ $? -eq 0 ] && msg "Created a authorized_keys" || error_exit "Failed to create a authorized_keys"
	publickey="${publickey}"
	echo "${publickey}" > /sftp/.ssh/${username}_authorized_keys 
	[ $? -eq 0 ] && msg "Copied the public key to authorized_keys" || error_exit "Failed to copy the public key to the authorized_keys"
	chown ${username}:root  /sftp/.ssh/${username}_authorized_keys
	[ $? -eq 0 ] && msg "Applied the ownership username: ${username} groupname: root to authorized_keys" || error_exit "Failed to set the permission to authorized_keys"
	chmod 600 /sftp/.ssh/${username}_authorized_keys
	[ $? -eq 0 ] && msg "Changed the 600 permission to the authoized_keys " || error_exit "Failed to set permission to the authorized_keys"

}

main () {
pass=$(echo $action | tr "," " " | awk '{print $1}')
keybased=$(echo $action | tr "," " " | awk '{print $2}')
msg "Started to create a SFTP user"
create_sftp_dir

if [ "$pass" == "PasswordBased" ] && [ "${keybased}" == "KeyBased" ]; then
    msg "Creating a SFTP user with Password Based and Key Based"
    create_user_with_password
    create_user_keybased
  
elif [ "$action" == "PasswordBased" ]; then
    msg "Creating a SFTP user with Password"
    create_user_with_password

elif [ "$action" == "KeyBased" ]; then
    msg "Creating a SFTP user with Keybased"
    create_user_keybased
fi
}

main

