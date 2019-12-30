#!/bin/bash
DATE=`date +%Y-%m-%d`
COUNT=1
REPORT="PATCH_UPDATE_REPORT_${DATE}.csv"
cat /dev/null > $REPORT
echo "Sno, Date, Current Package, Updated Package" >> ${REPORT}
PACKAGE=(`yum check-update | awk 'p; /Loaded plugins:/ {p=1}' | sed '/^$/d' | awk '{print $1}' | tr '\n' ' '`)
sleep 1
LEN=${#PACKAGE[@]}

#use for loop read all packages
for (( i=0; i<${LEN}; i++ ))
do
        old_pkgname_version=(`yum list --showduplicates ${PACKAGE[$i]} | awk 'p; /Installed Packages/ {p=1}' | awk 'NR==1''{print $1"_"$2}'`)
        sleep 1
        if [ $? -eq  "0" ]
        then
                #yum -y update ${PACKAGE[$i]}
		yum -y update --exclude=java* ${PACKAGE[$i]}

                sleep 2
                VERSION=(`yum list installed |  grep ${PACKAGE[$i]} | awk '{print $1}'`)
                RELEASE=(`yum list installed |  grep ${PACKAGE[$i]} | awk '{print $2}'`)
                echo "${COUNT}, `date +%Y-%m-%d`, ${old_pkgname_version}, ${VERSION}-${RELEASE}" >> ${REPORT}
                let COUNT=COUNT+1

        fi
done
