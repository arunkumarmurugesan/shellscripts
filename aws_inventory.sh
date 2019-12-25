#!/bin/bash 
#title           :aws_inventory.sh 
#description     :This script will create the AWS EC2 and EBS Inventory.
#author          :Arunkumar M
#date            :05-Dec-2018
#version         :1.0
#usage           :./aws_inventory.sh --resource <ec2|ebs> --vpcid <vpcid> --region <region>
#detailed docs   : 
#==============================================================================

DATE=`date +%Y-%m-%d`
DATE_TIME=`date +%Y-%m-%d-%H:%M`
SCRIPTNAME=$(basename $0)
AWS_VAR=$(which aws)
LOG="aws-inventory-$DATE.log"
CSV_FILENAME="aws_inventory.csv"
AWS="${AWS_VAR} --region ${REGION}"


function msg() {
    local message="$1"
    echo "$DATE_TIME - INFO - $message"
}
function error_exit() {
    local message="$1"
    echo "$DATE_TIME - ERROR - $message" 
    exit 1
}

function print_help () {
      echo -e "Usage: ${SCRIPTNAME} --resource <ec2|ebs> --vpcid <vpcid> --region <region>"
}

if [ -z "$1" ] && [ -z "$2" ]; then
    print_help
    exit 1
fi 

while test -n "$1"; do
   case "$1" in
       --help)
           print_help
           ;;
       -h)
           print_help
           ;;
        --resource)
            ACTION=$2
            shift
            ;;
        --vpcid)
            VPCID=$2
            shift
            ;;
        --region)
            REGION=$2
            shift
	    ;;
        --dryrun)
            createDryRun
            shift
            ;;
       *)
            echo "Unknown argument: $1"
            print_help
            ;;
    esac
    shift
done


function createEc2Inventory () {
	AWS="${AWS_VAR} --region ${REGION} --output text"
	echo "PrivateIpAddress,PrivateDnsName,InstanceId,KeyName,LaunchTime,ImageId,InstanceType,InstanceName" > aws.csv
	echo "VpcName" > vpc_name.csv
	echo "SubnetName" > subnet_name.csv
	echo "IamInstanceProfile" > iam_role.csv
	echo "AvailabilityZone" > zone.csv
	echo "SecurityGroupName" > sg01.csv
	echo "SecurityGroupId" > sg02.csv

	instance_ids=$(${AWS} ec2 describe-instances --filters Name=vpc-id,Values=${VPCID} --query 'Reservations[*].Instances[*].[InstanceId]')
	[ $? -eq 0 ] || error_exit "Exection Failed: Cloud not able to get the instance_ids"
	for ins_ids in ${instance_ids};do
		${AWS} ec2 describe-vpcs --vpc-ids ${VPCID} --query 'Vpcs[*].Tags[?Key==`Name`].Value[]' >> vpc_name.csv
		[ $? -eq 0 ] || error_exit "Exection Failed: Cloud not able to get the vpc name"
		subnet_id=$(${AWS} ec2 describe-instances --instance-ids ${ins_ids} --query 'Reservations[*].Instances[*].[NetworkInterfaces[].SubnetId]')
		[ $? -eq 0 ] || error_exit "Exection Failed: Cloud not able to get the subnet_id"
		${AWS} ec2 describe-subnets --subnet-ids ${subnet_id} | grep Name | awk '{print $3}' >> subnet_name.csv
		[ $? -eq 0 ] || error_exit "Exection Failed: Cloud not able to get the subnet name"
		${AWS} ec2 describe-instances --instance-ids ${ins_ids} --query 'Reservations[*].Instances[*].[IamInstanceProfile]' | awk '{print $1}' >> iam_role.csv
		[ $? -eq 0 ] || error_exit "Exection Failed: Cloud not able to get the iam rolename"
		${AWS} ec2 describe-instances --instance-ids ${ins_ids}  --query 'Reservations[].Instances[].[Placement]' | awk '{print $1}' >> zone.csv
		[ $? -eq 0 ] || error_exit "Exection Failed: Cloud not able to get the AvailabilityZone"
		${AWS} ec2 describe-instances --instance-ids ${ins_ids} --query 'Reservations[].Instances[].[SecurityGroups[].GroupName]' >> sg01.csv
		[ $? -eq 0 ] || error_exit "Exection Failed: Cloud not able to get the SecurityGroupsName"
		${AWS} ec2 describe-instances --instance-ids ${ins_ids} --query 'Reservations[].Instances[].[SecurityGroups[].GroupId]' >> sg02.csv
		[ $? -eq 0 ] || error_exit "Exection Failed: Cloud not able to get the SecurityGroupsId"
	done
	paste -d, sg01.csv sg02.csv iam_role.csv zone.csv vpc_name.csv subnet_name.csv > test.txt
	${AWS} ec2 describe-instances --filters Name=vpc-id,Values=${VPCID} --query 'Reservations[].Instances[].[PrivateIpAddress,PrivateDnsName,InstanceId,Tags[?Key==`Name`].Value[],KeyName,LaunchTime,ImageId,InstanceType]' | sed '$!N;s/\n/ /' | tr '\t' "," | tr ' ' "," >> aws.csv
	[ $? -eq 0 ] && msg "Successfully generated the EC2 Inventory into CSV file" || error_exit "Exection Failed: Cloud not able to generate Ec2 CSV file"
	paste -d, aws.csv test.txt > "ec2_${CSV_FILENAME}"
	rm -rf vpc_name.csv subnet_name.csv iam_role.csv zone.csv test.txt aws.csv sg01.csv sg02.csv
}

function createVolumeInventory() {
	AWS="${AWS_VAR} --region ${REGION} --output text"
	echo "VolumeIds,AvailabilityZone,VolumeType,Iops,Encrypted,Name" > vol.txt
	echo "InstanceId" > ins.txt
	echo "Device" > device.txt

	instance_ids=$(${AWS} ec2 describe-instances --filters Name=vpc-id,Values=${VPCID} --query 'Reservations[*].Instances[*].[InstanceId]')
	[ $? -eq 0 ] || error_exit "Exection Failed: Cloud not able to get the instance_ids"
	for ins_ids in ${instance_ids};do
		${AWS} ec2 describe-volumes --filters Name=attachment.instance-id,Values=$ins_ids  --query "Volumes[*].[VolumeId,Size,AvailabilityZone,VolumeType,Iops,Encrypted,Tags[?Key==`Name`].Value[]]" --output text | sed '$!N;s/\n/ /' | tr '\t' "," | tr ' ' "," >> vol.txt
		[ $? -eq 0 ] || error_exit "Exection Failed: Cloud not able to get the VolumeIds,AvailabilityZone,VolumeType,Iops,Encrypted"
		${AWS} ec2 describe-volumes --filters Name=attachment.instance-id,Values=$ins_ids  --query "Volumes[*].[Attachments[].InstanceId]" >> ins.txt
		[ $? -eq 0 ] || error_exit "Exection Failed: Cloud not able to get the instance_ids"
		${AWS} ec2 describe-volumes --filters Name=attachment.instance-id,Values=$ins_ids  --query "Volumes[*].[Attachments[].Device]" >> device.txt
		[ $? -eq 0 ] || error_exit "Exection Failed: Cloud not able to get device"

	done
	paste -d, ins.txt device.txt vol.txt > "ebs_${CSV_FILENAME}"
	[ $? -eq 0 ] && msg "Successfully generated the Volumes Inventory into CSV file" || error_exit "Exection Failed: Cloud not able to generate volumes CSV file"
	rm ins.txt vol.txt device.txt

}
main () {

	if [ "$ACTION" = "ec2" ];then
		createEc2Inventory
	elif [ "$ACTION" = "ebs" ];then
    	createVolumeInventory
    else
    	print_help
    fi
}

main


