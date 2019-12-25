#!/bin/bash
DATE=`date +%F`
TIME=`date +%H-%M-%S`
MAILLOG=/var/lib/rundeck/scripts/dd-downtime/log/dd_downtime_mailog_${DATE}-${TIME}.log


while test -n "$1"; do
   case "$1" in
       --help)
           print_help
           ;;
       -h)
           print_help
           ;;
        --tag_name)
           TAG_NAME=$2
            shift
            ;;	
        --hours)
            HOURS=$2
            shift
            ;;
       *)
            echo "Unknown argument: $1"
            print_help
            ;;
    esac
    shift
done

api_key=xxx
app_key=xxx
echo $TAG_NAME

start=$(date +%s)
end=$(date +%s -d "+$HOURS hours")
for i in `$TAG_NAME`
do 
curl -X POST -H "Content-type: application/json" \
-d '{
      "scope": "purpose:'${i}'",
      "start": '"${start}"',
      "end": '"${end}"',
      "message": "Scheduled Downtime.. '@arunkumar.murugesan@jar.com'"
     }' \
    "https://app.datadoghq.com/api/v1/downtime?api_key=${api_key}&application_key=${app_key}" | tee -a $MAILLOG
done
