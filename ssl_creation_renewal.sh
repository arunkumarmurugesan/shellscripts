#!/bin/bash
#---------------------------------------------------------
#Written By : Arunkumar M
#---------------------------------------------------------

#Required
domain=$1
action=$2
env=$3
commonname=$domain

#Can be modified
password="example@123#!"
DATE=`date '+%Y-%m-%d'`

LOCATION="/var/lib/jenkins/ansible_jobs/scripts/csr"
touch /var/lib/jenkins/ansible_jobs/scripts/csr/ssl_test

ssl_renewal(){

echo | openssl s_client -showcerts -connect $domain:443 > /var/lib/jenkins/ansible_jobs/scripts/csr/ssl_test < /dev/null

country_name=$(cat $LOCATION/ssl_test |  awk '/subject=/ {print;exit}' | awk -F'=' '{print $3}' | awk -F'/' '{print $1}')
state=$(cat $LOCATION/ssl_test |  awk '/subject=/ {print;exit}' | awk -F'=' '{print $4}' | awk -F'/' '{print $1}')
locality_name=$(cat $LOCATION/ssl_test |  awk '/subject=/ {print;exit}' | awk -F'=' '{print $5}' | awk -F'/' '{print $1}')
organizational_unit_name=$(cat $LOCATION/ssl_test |  awk '/subject=/ {print;exit}' | awk -F'=' '{print $7}' | awk -F'/' '{print $1}')
organization_name=$(cat $LOCATION/ssl_test |  awk '/subject=/ {print;exit}' | awk -F'=' '{print $6}' | awk -F'/' '{print $1}')
common_name=$(cat $LOCATION/ssl_test |  awk '/subject=/ {print;exit}' | awk -F'=' '{print $8}')
email_address="arun@gmail.com"

echo "Generating key request for $domain"

#Generate a key
mkdir -p $LOCATION/$env/$domain-$DATE/
cd $LOCATION/$env/$domain-$DATE/;openssl genrsa -des3 -passout pass:$password -out $domain.key 2048 -noout

#Remove passphrase from the key. Comment the line out to keep the passphrase
echo "Removing passphrase from key"
cd $LOCATION/$env/$domain-$DATE/;openssl rsa -in $domain.key -passin pass:$password -out $domain.key

#Create the request
echo "Creating CSR"

cd $LOCATION/$env/$domain-$DATE/;openssl req -sha256 -new -key $domain.key -out $domain.csr -subj "/C=$country_name/ST=$state/L=$locality_name/O=$organization_name/OU=$organizational_unit_name/CN=$common_name/emailAddress=$email_address"
echo "---------------------------"
echo "-----Below is your CSR-----"
echo "---------------------------"
echo
cat $LOCATION/$env/$domain-$DATE/$domain.csr
 
echo
#echo "---------------------------"
#echo "-----Below is your Key-----"
#echo "---------------------------"
#echo
#cat $LOCATION/$env/$domain-$DATE/$domain.key

}

ssl_creation_new(){

#Change to your company details
country="US"
state="California"
locality="San Jose"
organization="Example, Inc."
organizationalunit="IT"
email="aws-ops@gmail.com"

echo "Generating key request for $domain"

#Generate a key
mkdir -p $LOCATION/$env/$domain-$DATE/
cd $LOCATION/$env/$domain-$DATE/;openssl genrsa -des3 -passout pass:$password -out $domain.key 2048 -noout

#Remove passphrase from the key. Comment the line out to keep the passphrase
echo "Removing passphrase from key"
cd $LOCATION/$env/$domain-$DATE/;openssl rsa -in $domain.key -passin pass:$password -out $domain.key

#Create the request
echo "Creating CSR"

cd $LOCATION/$env/$domain-$DATE/;openssl req -new -key $domain.key -out $domain.csr -subj "/C=$country/ST=$state/L=$locality/O=$organization/OU=$organizationalunit/CN=$commonname/emailAddress=$email"
 
echo "---------------------------"
echo "-----Below is your CSR-----"
echo "---------------------------"
echo
cat $LOCATION/$env/$domain-$DATE/$domain.csr
 
echo
#echo "---------------------------"
#echo "-----Below is your Key-----"
#echo "---------------------------"
#echo
#cat $LOCATION/$env/$domain-$DATE/$domain.key

}



if [ -z "$1" ] && [ -z "$2" ] && [ -z "$3" ]
then
    echo "Argument not present."
    echo "Useage $0 [common name] [ssl_renewal or ssl_creation_new] [ PROD or UAT]"
    exit 99
	 
else
	if [ "$action" = "ssl_renewal" ];then
		ssl_renewal
	fi
	if [ "$action" = "ssl_creation_new" ];then
		ssl_creation_new
	fi
fi
