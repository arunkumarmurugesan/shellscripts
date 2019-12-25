#!/bin/bash -x

#This script is to do log rotation of all standard logs present in Example Project.
#This script runs at midnight everyday

#By default, log-location is assumed as /srv/webapps/example.com/logs/

#log_files is array of logs that are written in both admin and all prod servers
#Ordered in alphabatic-wise. If new logs are to be added, please maintain the ordering
log_files=(analytic_fail.log analyticsLog.out  autosearch_request.log
           mysql_profile_no_where_clause.log mysql_profile_queries.log)


previous_day=$(date --date=yesterday +%d-%m-%Y)
Log_file="/srv/webapps/example.com/logs/log-rotation.log"
cat /dev/null > $Log_file

echo "======================================" | tee -a $Log_file

echo "Started Processing log files on `date`" | tee -a $Log_file


echo "Delete all the .gz file older than 3 days" | tee -a $Log_file
find /srv/webapps/example.com/logs/  -name '*.gz' -mtime +3 -delete | tee -a $Log_file

err = 0 
for filename in "${log_files[@]}"
do
    filepath=/srv/webapps/example.com/logs/$filename
    #check if file is present and its not empty
    echo "Processing file: $filepath" | tee -a $Log_file
    if [ -s $filepath ]
    then
        cp $filepath $filepath.$previous_day
		if [ $? -eq 0 ]; then
			echo "Successfully copied the actual log $filepath to $filepath.$previous_day" 
		else
			echo "Unsuccessful of copied" | tee -a $Log_file
			err =1
		fi
        >$filepath
		if [ $? -eq 0 ]; then
			echo "Successfully Nullified the actual log file: $filepath" 
		else
			echo "Unsuccessful of Nullified" | tee -a $Log_file
			err=1
		fi
        #rsync
        gzip -9 --rsyncable $filepath.$previous_day
		if [ $? -eq 0 ]; then
			echo "Successfully compressed the new log file : $filepath.$previous_day" 
		else
			echo "Unsuccessful of compressed the new log file: $filepath.$previous_day" | tee -a $Log_file
			err =1
		fi
        echo "Done log-rotation for date-$previous_day: $filepath" | tee -a $Log_file
		
    else
        echo "Skipped $filepath as its not present or empty" | tee -a $Log_file
    fi
done

echo "End Processing log files on `date`" | tee -a $Log_file
echo "======================================" | tee -a $Log_file


if [ $err -eq "1" ];then
	mail -s "BB Rotation is Completed with Errors"  alerts@mijar.com -- -f  alerts@mijar.com < $Log_file;
fi

