#!/bin/bash
###################################################################
#Script Name	: db_backup.sh 
#Description	: This script is used for taking the plain SQL dump
#	          from prod instance                                                                             
#Author       	: Arunkumar M
################################################################### 

# Default variables can be modified
DATE_STR=`date +"%d-%b-%y-%H-%M-%S"`
DATE_YEAR=`date +"%Y"`
DATE_MONTH=`date +"%m"`
DATE_TIME=`date +"%d-%b-%y-%H-%M"`

BACKUP_DIR=/mnt/backupdb/dbpg/pg_backup.$DATE_STR
HOST="rds_endpoint"
USERNAME="root"
PORT='65674'
LOG_FILE="/tmp/db_backup.log"
DBNAME="prod_beta"
AWS=$(which aws)
PG_DUMP=$(which pg_dump)

cat /dev/null > $LOG_FILE

if [ ! -d "$BACKUP_DIR" ]; then
  mkdir -p $BACKUP_DIR
fi

function msg() {
    local message="$1"
    echo "$DATE_TIME - INFO - $message"
    echo "$DATE_TIME - INFO - $message" | tee -a ${LOG_FILE} > /dev/null
}
function error_exit() {
    local message="$1"
    echo "$DATE_TIME - ERROR - $message" 
    echo "$DATE_TIME - ERROR - $message" | tee -a ${LOG_FILE} 
    exit 1
}
function output_file_size {
  size=`stat $1 --printf="%s"`
  kb_size=`echo "scale=2; $size / 1024.0" | bc`
  echo "Finished backup for $2 - size is $kb_size KB" | tee -a ${LOG_FILE}
}
function s3_sync() {
  ${AWS} s3 sync .  s3://prod-db-backup/${DATE_YEAR}/${DATE_MONTH}/ 
  [ $? -eq 0 ] && msg "The dump has been uploaded to s3: ${DB_FILE}" || error_exit "Exection Failed: Cloud not able to upload the db dump into s3"
}
function db_backup() {
  msg "Please update the password : PGPASSWORD variable then execute it"
  pushd $BACKUP_DIR > /dev/null
  DB_FILE=$DBNAME-$DATE_STR.sql.gz
  PGPASSWORD='xxxxx' ${PG_DUMP} -h ${HOST} -U ${USERNAME} -p ${PORT} --format custom ${DBNAME} 2>> $LOG_FILE | gzip > $DB_FILE
  [ $? -eq 0 ] && msg "The dump has been taken: ${DB_FILE}" || error_exit "Exection Failed: Cloud not able to take the db dump"
  s3_sync
  output_file_size ${DB_FILE} "${DBNAME}"
  # Delete the older than 2 days folder
  find /mnt/backupdb/dbpg/* -type d -ctime +2 -exec rm -rf {} \;
  popd > /dev/null
}

db_backup
