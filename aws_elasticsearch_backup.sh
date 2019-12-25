#!/bin/bash
REGION_NAME=us-west-2
S3BUCKET_NAME=cloud-prod-us-backups
REPO_PATH=elasticsearch
ES_HOST="ip|url"
ES_PORT=6100
CURL_SNAP=http://$ES_HOST:$ES_PORT/_snapshot/elasticsearch
RETENTION_DAY=15
TODAY=`date +%F`
YESTERDAY=`date +%F --date "1 days ago"`
N_DAYS_AGO=`date +%F --date "$RETENTION_DAY days ago"`
RESTORE_DAY=1
RESTORE_DAYS_AGO=`date +%F --date "$RESTORE_DAY days ago"`
SCRIPT_HOME=/var/lib/rundeck/scripts/prod/elasticsearch
LOG_FILE=$SCRIPT_HOME/log/es-$TODAY.log


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
       *)
            echo "Unknown argument: $1"
            print_help
            ;;
   esac
    shift
done

create_s3_repo(){
curl -XPUT '$CURL_SNAP' -d '{
    "type": "s3",
    "settings": {
        "bucket": "$S3BUCKET_NAME",
        "region": "$REGION_NAME",
        "base_path": "elasticsearch"
    }
}'
}

create_es_snapshot(){
curl -XPUT "$CURL_SNAP/snapshot_$TODAY?wait_for_completion=true" >> $LOG_FILE
}

list_es_snapshot(){
curl -XGET "$CURL_SNAP/_all?pretty" >> $LOG_FILE
}

check_es_snapshot(){
curl -XGET "$CURL_SNAP/_status?pretty" >> $LOG_FILE
}

delete_es_snapshot(){
curl -XDELETE "$CURL_SNAP/snapshot_$N_DAYS_AGO?wait_for_completion=true" >> $LOG_FILE
}

restore_es_snapshot(){
curl -XPOST "$CURL_SNAP/snapshot_$RESTORE_DAYS_AGO/_restore"
}


if [ "$ACTION" = "create-es-snapshot" ];then
create_es_snapshot
check_es_snapshot
list_es_snapshot
elif [ "$ACTION" = "create-es-repo" ];then
create_s3_repo
elif [ "$ACTION" = "delete-es-snapshot" ];then
delete_es_snapshot
list_es_snapshot
elif [ "$ACTION" = "list-es-snapshot" ];then
list_es_snapshot
elif [ "$ACTION" = "restore-es-snapshot" ];then
restore_es_snapshot
elif [ "$ACTION" = "check_es_snapshot" ];then
check_es_snapshot
else
echo "Unknown Action Type"
fi
