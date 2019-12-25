#!/bin/bash 
#title           :lc_deletion.sh
#description     :This script will delete the  launch-configuration which is not being use.
#author          :arunkumar 
#date            :20-Dec-2017
#version         :1.0



log_file="/tmp/lc-delete-old.log"
email_from="alerts@jar.com"
email_rcpts="alerts@jar.com"
email_subject="project : Deletion of old Launch Configuration"
mail="$(which mail)"

cat /dev/null > $log_file

send_success_email() {
$mail -s "\"$email_subject[SUCCES]\"" -a "From:$email_from"  $email_rcpts < $log_file
}

send_failure_email() {
$mail -s "\"$email_subject[FAILURE]\"" -a "From:$email_from"  $email_rcpts < $log_file
}



in_array() {
    local hay needle=$1
    shift
    for hay; do
        [[ $hay == $needle ]] && return 0
    done
    return 1
}

# Get all launch configuration names that have been created for this AWS account
allconfigs=$(aws autoscaling describe-launch-configurations --region ap-south-1 --output json | jq '.LaunchConfigurations[].LaunchConfigurationName' | sed s/\"//g)
configs=($allconfigs)

# Get all active launch configurations names that are currently associated with running instances 
allinstances=$(aws autoscaling describe-auto-scaling-instances --region ap-south-1 --output json | jq '.AutoScalingInstances[].LaunchConfigurationName' | sed s/\"//g)
instances=($allinstances)

# Get all active launch configuration names that are currently associated with launch configuration groups
allgroups=$(aws autoscaling describe-auto-scaling-groups --region ap-south-1 --output json | jq  '.AutoScalingGroups[].LaunchConfigurationName' | sed s/\"//g)
groups=($allgroups)

# merge group configs and active instances configs into one array.  We need to keep them, and remove the rest
groupsandinstances=(`for R in "${instances[@]}" "${groups[@]}" ; do echo "$R" ; done | sort -du`)

#Loop through all configs and check against active ones to determine whether they need to be deleted
for i in "${configs[@]}"
do
#        echo $i
        in_array $i "${groupisandinstances[@]}" && echo active ${i} || echo deleting ${i} `aws autoscaling delete-launch-configuration --launch-configuration-name ${i} --region ap-south-1` | tee -a $log_file
	if [ $? -eq 0 ]; then
		send_success_email
	else
		send_failure_email
	fi
#        in_array $i "${groupsandinstances[@]}" && echo active ${i} || echo deleting ${i}

done


