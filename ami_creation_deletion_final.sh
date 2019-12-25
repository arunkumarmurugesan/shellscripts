#!/bin/bash
#title           :ami_creation_deletion_final.sh.sh
#description     :This script will create the ami & launch-configuration and update it to respective autocale group.
#author                  :Arunkumar M
#date            :16-Dec-2016
#version         :1.0
#usage               :sh ami_creation_deletion_final.sh --action <action> --tagname <tag_name> --autoscalename <autoscale_name>
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
date=`date +"%d-%b-%y-%H-%M-%S"`
lc_name="PROD-LC-$date"
iam_role="int-app-role"
instance_type="c4.xlarge"
sg_name="sg-xxxxx4a7"
log_file="/tmp/autoscale-update.log"
email_from="alerts@jar.com"
email_rcpts="alerts@jar.com"
email_subject="Project : Autoscale update: ${lc_name}"
mail="$(which mail)"

cat /dev/null > $log_file

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
        instance_tag_name=$(aws ec2 describe-instances --filter "Name=instance-state-name,Values=running" --query 'Reservations[*].Instances[*].Tags[?Key==`Name`].Value[]' --output text --region ap-south-1 | grep -i $tag_name)
        if [[ "${tag_name}" == ${instance_tag_name} ]]
        then
                echo "Given instance tag name is matched" | tee -a $log_file
        else
                echo "Given instance tag name is not match" | tee -a $log_file
                exit
        fi
        instance_id="$(aws ec2 describe-instances --filter "Name=tag:Name,Values=${instance_tag_name}" --query 'Reservations[*].Instances[*].{ID:InstanceId}'  --output text --region ap-south-1)"
        echo "The instance id of the instance name you selected : $instance_id" | tee -a $log_file
}

ami_creation(){
		#To create a unique AMI name for this script				
        ami_name="$instance_tag_name-`date +%d-%b-%y`"				
        ami_id="$(aws ec2 create-image --instance-id $instance_id --name "${ami_name}" --description "${ami_name}" --no-reboot --output json --region ap-south-1 | jq -r .ImageId)"
        #Showing the AMI name created by AWS
		echo -e "AMI ID is: $ami_id" | tee -a $log_file
		echo $ami_id > /tmp/amiID.txt
        ami_status_tag="available"
		while true
        do
        ami_status="$(aws ec2 describe-images --image-ids $ami_id --region ap-south-1 --output json | jq '.Images[] | .State' | sed -s "s/^\(\(\"\(.*\)\"\)\|\('\(.*\)'\)\)\$/\\3\\5/g")"
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
		echo -e "Looking for AMI older than 2 days..\n" | tee -a $log_file
		#Finding AMI older than 2 days which needed to be removed
		echo "instance_tag_name-`date +%d%b%y --date '3 days ago'`" > /tmp/amidel.txt
		#Finding Image ID of instance which needed to be Deregistered
		aws ec2 describe-images --filters "Name=name,Values=`cat /tmp/amidel.txt`" | grep -i imageid | awk '{ print  $4 }' > /tmp/imageid.txt
		if [[ -s /tmp/imageid.txt ]];
		then
		echo -e "Following AMI is found : `cat /tmp/imageid.txt`\n" | tee -a $log_file

		#Find the snapshots attached to the Image need to be Deregister
		aws ec2 describe-images --image-ids `cat /tmp/imageid.txt` | grep snap | awk ' { print $4 }' > /tmp/snap.txt

		echo -e "Following are the snapshots associated with it : `cat /tmp/snap.txt`:\n " | tee -a $log_file
		 
		echo -e "Starting the Deregister of AMI... \n" | tee -a $log_file

		#Deregistering the AMI 
		aws ec2 deregister-image --image-id `cat /tmp/imageid.txt`

		echo -e "\nDeleting the associated snapshots.... \n" | tee -a $log_file

		#Deleting snapshots attached to AMI
		for i in `cat /tmp/snap.txt`
		do 
		aws ec2 delete-snapshot --snapshot-id $i ; 
		done

		else
			echo -e "No AMI found older than minimum required no of days" | tee -a $log_file
		fi


}

lc_creation(){
        aws autoscaling create-launch-configuration --iam-instance-profile "${iam_role}" --instance-type "${instance_type}" --security-groups "${sg_name}" --no-ebs-optimized  --launch-configuration-name "${lc_name}" --image-id "${ami_id}" --region ap-south-1
        if [ $? -eq 0 ]; then
            echo -e "Launch configuration is created : ${lc_name}" | tee -a $log_file
        else
            echo "Launch configuration is not created" | tee -a $log_file
        fi
}
autoscale_update(){
        aws autoscaling suspend-processes --auto-scaling-group-name "${autoscale_name}" --region ap-south-1
        echo "Autoscaling suspended for "${autoscale_name}"" | tee -a $log_file
        aws autoscaling update-auto-scaling-group --auto-scaling-group-name "${autoscale_name}" --launch-configuration-name "${lc_name}" --region ap-south-1
        if [ $? -eq 0 ]; then
			echo -e "Autoscaling updated with new ami id: ${ami_id}  and launch-configuration: ${lc_name}" | tee -a $log_file
        else
            echo "Autoscaling not updated with new ami and launch-configuration" | tee -a $log_file
        fi        
        aws autoscaling resume-processes --auto-scaling-group-name "${autoscale_name}" --region ap-south-1
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
