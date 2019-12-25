#!/bin/bash 
#title           :monit.sh 
#description     :This script will create install monit to moniter kubelet service.
#OS              :RHEL
#author          :Arunkumar
#date            :4-Dec-2018
#version         :1.0
#usage           :./monit.sh
#detailed docs   : 
#==============================================================================
# set -e

DATE=`date +%Y-%m-%d`
DATE_TIME=`date +%Y-%m-%d-%H:%M`
SCRIPTNAME=$(basename $0)

function msg() {
    local message="$1"
    echo "$DATE_TIME - INFO - $message"
}
function error_exit() {
    local message="$1"
    echo "$DATE_TIME - ERROR - $message" 
    exit 1
}

function write(){
    msg "Writing configuration files"
    echo "check process httpd with pidfile /var/run/httpd/httpd.pid
    group apache
    start program = "\"/bin/systemctl start httpd.service"\"
    stop program = "\"/bin/systemctl start httpd.service"\"
    if failed host 127.0.0.1 port 80
    protocol http then restart
    if 5 restarts within 5 cycles then timeout
    
    check process docker with pidfile /var/run/docker/libcontainerd/docker-containerd.pid
    alert  -alerts@gmail.com only on { timeout,nonexist,resource,pid,connection }
    start program = "\"/bin/systemctl start docker.service"\"
    stop program = "\"/bin/systemctl start docker.service"\"
    if does not exist then restart
    if 5 restarts within 5 cycles then timeout
    check host kubelet-4194 with address 127.0.0.1
    start program = "\"/bin/systemctl start kubelet"\"
    stop program = "\"/bin/systemctl stop kubelet"\"
    if failed port 4194 then restart
    if 5 restarts within 5 cycles then timeout
    check host kubelet-10248 with address 127.0.0.1
    start program = "\"/bin/systemctl start kubelet"\"
    stop program = "\"/bin/systemctl stop kubelet"\"
    if failed port 10248 then restart
    if 5 restarts within 5 cycles then timeout
    check host kubelet-10250 with address 127.0.0.1
    start program = "\"/bin/systemctl start kubelet"\"
    stop program = "\"/bin/systemctl stop kubelet"\"
    if failed port 10250 then restart
    if 5 restarts within 5 cycles then timeout
    check host kubelet-10255 with address 127.0.0.1
    start program = "\"/bin/systemctl start kubelet"\"
    stop program = "\"/bin/systemctl stop kubelet"\"
    if failed port 10255 then restart
    if 5 restarts within 5 cycles then timeout" > /etc/monit.d/monit.conf

    echo "
    set daemon 30
    set logfile /var/log/monit.log
    
    #
    set httpd port 2812 and
    use address 0.0.0.0  # only accept connection from localhost
    allow 0.0.0.0        # allow localhost to connect to the server and
    allow 103.68.105.254
    allow admin:monit      # require user 'admin' with password 'monit'
    allow @monit           # allow users of group 'monit' to connect (rw)
    allow @users readonly  # allow users of group 'users' to connect readonly
    #
    include /etc/monit.d/*" > /etc/monitrc
    msg "Configuration files changed"
}

function start(){
    service monit start
    msg "Monit service started for monitoring"
}

function install(){
    if rpm -qa | grep  httpd && rpm -qa | grep monit && rpm -qa |grep epel; then
      msg "Httpd and Monit already installed."
    else
      msg "Installing Apache server and Monit"
      rpm -ivh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
      yum install httpd -y
      yum install monit -y
      service httpd start
      msg "Apache and Monit Installed"
      write
      start
    fi
}

main(){
    install
}

main
