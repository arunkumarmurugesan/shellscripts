#!/bin/bash
arr=($( aws ec2 describe-instances --query 'Reservations[*].Instances[*].[PrivateIpAddress,Tags[?Key==`Name`].Value]' --region ap-southeast-1 --output text --profile Uat))
echo "repo_lists=" > repo_lists.properties
truncate -s 0 repo_lists.txt
for ((i=0;i<=${#arr[@]};i=i+2))
do
echo ${arr[@]:i:2} | awk '{printf "%s", $1":"$2}' | awk '{printf "%s,", $1}' >> repo_lists.txt
#repo_list=`cat repo_lists.properties`
#echo $repo_list
#sed -i '${/repo_lists=/s/$/'"$repo_list"'/}'  repo_lists.properties
done
repo_list=`cat repo_lists.txt | rev | cut -c39- | rev`
sed -ie 's@repo_lists=@&'"$repo_list"'@' repo_lists.properties
