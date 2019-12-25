DATE=`date +%Y-%m-%d`
DATE_TIME=`date +%Y-%m-%d-%H:%M`
DIR_DATE_TIME=`date +%Y%m%d_%H%M`
APP_USER="jboss"
SCRIPTNAME=$(basename $0)
LOG="deploymet-$DATE.log"

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
      echo -e "Usage: ${SCRIPTNAME} --sdirectory <source directory> --ddirectory <deployment directory> --filecopy yes"
}

while test -n "$1"; do
   case "$1" in
       --help)
           print_help
           ;;
       -h)
           print_help
           ;;
        --sdirectory)
            SOURCE_DIR=$2
            shift
            ;;
         --ddirectory)
            DEPLOYMENT_DIR=$2
            shift
            ;;
        --filecopy)
            FILECOPY=$2
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

if [ -z "$1" ] && [ -z "$2" ]; then
    print_help
    exit 1
fi 

function copyFiletoDeployment() {
	pushd ${SOURCE_DIR}
	CHECK_LASTFILE=$(sudo ls -ltrh | grep -v 'total' | awk '{print $9}')
	for i in ${CHECK_LASTFILE};do
		sudo cp -rv ${i} ${DEPLOYMENT_DIR}/
		msg "The file: $i is copied from ${SOURCE_DIR} to ${DEPLOYMENT_DIR}"
		sudo chown $APP_USER:$APP_USER ${DEPLOYMENT_DIR}/${i}
	done
	popd 
}

function createBackup() {
	BACKUP_DIR=$DIR_$DIR_DATE_TIME
	if [ -d "${BACKUP_DIR}" ]; then
	    # Will enter here if $DIRECTORY exists, even if it contains spaces
	    error_exit "Given the directory is already exists: ${BACKUP_DIR}"
	else
		sudo mkdir -p ${BACKUP_DIR}
		msg "Given the directory is not exists: ${BACKUP_DIR}.So created now."
		pushd ${SOURCE_DIR}
		CHECK_LASTFILE=$(sudo ls -ltrh | grep -v 'total' | awk '{print $9}')
		popd
		pushd ${DEPLOYMENT_DIR}
		for i in ${CHECK_LASTFILE};do
			sudo cp -rv ${DEPLOYMENT_DIR}/${i} ${BACKUP_DIR}/
			msg "The file: $i is copied from ${DEPLOYMENT_DIR} to ${BACKUP_DIR}" 
		done
		popd
	fi
}

function stopJboss() {
	 sudo su ${APP_USER} -c /opt/jboss-soa-p/jboss-eap-6.4/bin/stopJboss.sh 
	 msg "The jboss service has been stopped"
}

function startJboss(){
	sudo su ${APP_USER} -c /opt/jboss-soa-p/jboss-eap-6.4/bin/startJboss.sh
	msg "The jboss service has been started"
}


main () {
	if [ "$FILECOPY" = "yes" ];then
		createBackup
		stopJboss
		copyFiletoDeployment
		startJboss
	else
		msg "The files already copied.Hence begin to stop and start the application"
		stopJboss
		startJboss
	fi
}

main

