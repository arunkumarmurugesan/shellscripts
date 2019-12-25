#!/bin/bash
#title           :autoscale_lc_ami_update.sh
#description     :This script will create the ami & launch-configuration and update it to respective autocale group.
#author          :Arunkumar M
#date            :16-Dec-2016
#version         :1.0
#usage           :bash autoscale_lc_ami_update.sh --action <action> --tagname <tag_name> --autoscalename <autoscale_name>
#notes           :Install jq and mail to use this script.
#==============================================================================

while test -n "$1"; do
   case "$1" in
       --help)
           print_help
           ;;
       -h)
           print_help
           ;;
        --action)
            ACTION=$2
            shift
            ;;
        --tagname)
            tag_name=$2
            shift
            ;;
        --autoscalename)
            autoscale_name=$2
            shift
            ;;
        --dryrun)
            shift
            ;;
       *)
            echo "Unknown argument: $1"
            print_help
            ;;
    esac
    shift
done

# Default variables can be modified
date=`date +"%d-%b-%y-%H-%M"`
lc_name="example-LC-$date"
region="ap-south-1"
log_file="/tmp/desktop-autoscale-update.log"
email_from="alerts@jar.com"
email_rcpts="alerts@jar.com"
email_subject="Project : Autoscale update: ${lc_name}"
mail="$(which mail)"

cat /dev/null > $log_file

lc_existing_name=$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names $autoscale_name --region $region --output json | jq '.AutoScalingGroups[] | .LaunchConfigurationName' | tr -d '"')
iam_role=$(aws autoscaling describe-launch-configurations --launch-configuration-names $lc_existing_name --region $region --output json | jq '.LaunchConfigurations[] | .IamInstanceProfile' | tr -d '"')
user_data=/var/lib/jenkins/scripts/desktop-user-data.txt
key_name=$(aws autoscaling describe-launch-configurations --launch-configuration-names $lc_existing_name --region $region --output json | jq '.LaunchConfigurations[] | .KeyName' | tr -d '"')
instance_type=$(aws autoscaling describe-launch-configurations --launch-configuration-names $lc_existing_name --region $region --output json | jq '.LaunchConfigurations[] | .InstanceType' | tr -d '"')
#sg_name=$(aws autoscaling describe-launch-configurations --launch-configuration-names $lc_existing_name --region $region --output json | jq '.LaunchConfigurations[] | .SecurityGroups' | tr -d '[' | tr -d ']' | tr -d '[:space:]' | awk -F',' '{print $1" "$2}')
sg_name=$(aws autoscaling describe-launch-configurations --launch-configuration-names $lc_existing_name --region $region --output json | jq '.LaunchConfigurations[] | .SecurityGroups' | tr -d '"' | tr -d '[' | tr -d ']' | tr -d '[:space:]')

print_help () {
echo -e "Usage: ./test.sh --action <action> --tagname <tag_name> --autoscalename <autoscale_name>"
}

send_success_email() {
$mail -s "\"$email_subject[SUCCES]\"" -a "From:$email_from"  $email_rcpts < $log_file
}

send_failure_email() {
$mail -s "\"$email_subject[FAILURE]\"" -a "From:$email_from"  $email_rcpts < $log_file
}


get_instance_id(){
        instance_tag_name=$(aws ec2 describe-instances --filter "Name=instance-state-name,Values=running" --query 'Reservations[*].Instances[*].Tags[?Key==`Name`].Value[]' --output text --region $region | grep -i $tag_name)
        if [[ "${tag_name}" == ${instance_tag_name} ]]
        then
                echo "Given instance tag name is matched" | tee -a $log_file
        else
                echo "Given instance tag name is not match" | tee -a $log_file
                exit
        fi
        instance_ids="$(aws ec2 describe-instances --filter "Name=tag:Name,Values=${instance_tag_name}" "Name=instance-state-name,Values=running" --query 'Reservations[*].Instances[*].{ID:InstanceId}'  --output text --region $region)"
        echo "The instance id of the instance name you selected : $instance_ids" | tee -a $log_file
}

ami_creation(){
        #To create a unique AMI name for this script
        ami_name="$instance_tag_name-$date"
        ami_id="$(aws ec2 create-image --instance-id $instance_ids --name "${ami_name}" --description "${ami_name}" --no-reboot --output json --region $region | jq -r .ImageId)"
        #Showing the AMI name created by AWS
        echo -e "AMI ID is: $ami_id" | tee -a $log_file
        echo $ami_id > /tmp/amiID.txt
        ami_status_tag="available"
        while true
        do
        ami_status="$(aws ec2 describe-images --image-ids $ami_id --region $region --output json | jq '.Images[] | .State' | sed -s "s/^\(\(\"\(.*\)\"\)\|\('\(.*\)'\)\)\$/\\3\\5/g")"
        if [ "$ami_status_tag" == $ami_status ]
        then
            echo -e "ami state is : $ami_status" | tee -a $log_file
            break
        else
            echo -e "ami state is : $ami_status" | tee -a $log_file
        fi
        sleep 20
        done
}
ami_deletion(){
        echo -e "Looking for AMI older than 1 days..\n" | tee -a $log_file
        #Finding AMI older than 1 days which needed to be removed
#        echo "$instance_tag_name-`date +%d-%b-%y --date '1 days ago'`" | cut -d'-' -f1-6 > /tmp/amidel.txt
        old_ami=$(echo "$instance_tag_name-`date +%d-%b-%y --date '1 days ago'`" | cut -d'-' -f1-6)
        old_ami_time=$(echo $ami_name | cut -d'-' -f7-8)
        old_ami_id=$old_ami'-'$old_ami_time
        #Finding Image ID of instance which needed to be Deregistered
        #aws ec2 describe-images --filters "Name=name,Values=`cat /tmp/amidel.txt`" --region $region --output json | grep -i imageid | awk '{ print  $2 }' | tr -d '"' | tr -d "," > /tmp/imageid.txt
	aws ec2 describe-images --filters "Name=name,Values=$old_ami_id" --region $region --output json | grep -i imageid | awk '{ print  $2 }' | tr -d '"' | tr -d "," > /tmp/imageid.txt
        if [[ -s /tmp/imageid.txt ]];
        then
        echo -e "Following AMI is found : `cat /tmp/imageid.txt`\n" | tee -a $log_file

        #Find the snapshots attached to the Image need to be Deregister
        aws ec2 describe-images --image-ids `cat /tmp/imageid.txt`  --region $region --output json | grep snap | awk '{ print  $2 }' | tr -d '"' | tr -d ","  > /tmp/snap.txt

        echo -e "Following are the snapshots associated with it : `cat /tmp/snap.txt`:\n " | tee -a $log_file
        echo -e "Starting the Deregister of AMI... \n" | tee -a $log_file
        #Deregistering the AMI
        aws ec2 deregister-image --image-id `cat /tmp/imageid.txt` --region $region
        echo -e "\nDeleting the associated snapshots.... \n" | tee -a $log_file
        #Deleting snapshots attached to AMI
        for i in `cat /tmp/snap.txt`
        do
            aws ec2 delete-snapshot --snapshot-id $i --region $region ;
        done
        else
            echo -e "No AMI found older than minimum required no of days" | tee -a $log_file
        fi
}

lc_creation(){
        aws autoscaling create-launch-configuration --iam-instance-profile "${iam_role}" --instance-type "${instance_type}" --security-groups ${sg_name} --no-ebs-optimized  --launch-configuration-name "${lc_name}" --image-id "${ami_id}" --key-name "${key_name}" --user-data file://${user_data} --region $region
        if [ $? -eq 0 ]; then
            echo -e "Launch configuration is created : ${lc_name}" | tee -a $log_file
        else
            echo "Launch configuration is not created" | tee -a $log_file
        fi
}
autoscale_update(){
#        aws autoscaling suspend-processes --auto-scaling-group-name "${autoscale_name}" --region $region
        echo "Autoscaling suspended for "${autoscale_name}"" | tee -a $log_file
        aws autoscaling update-auto-scaling-group --auto-scaling-group-name "${autoscale_name}" --launch-configuration-name "${lc_name}" --region $region
        if [ $? -eq 0 ]; then
                        echo -e "Autoscaling updated with new ami id: ${ami_id}  and launch-configuration: ${lc_name}" | tee -a $log_file
        else
            echo "Autoscaling not updated with new ami and launch-configuration" | tee -a $log_file
        fi
 #       aws autoscaling resume-processes --auto-scaling-group-name "${autoscale_name}" --region $region
        echo "Autoscaling resumed for the group "${autoscale_name}"" | tee -a $log_file

}

if [ "$ACTION" = "ami_create" ];then
get_instance_id
ami_creation
ami_deletion
lc_creation
autoscale_update
if [ $? -eq 0 ]; then
send_success_email
else
send_failure_email
fi
else
echo "Unknown Action"
print_help
fi


