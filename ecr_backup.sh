#!/bin/bash 
#title           :ecr_backup.sh 
#description     :This script will copy the repo into failsafe accounts.
#author          :Arunkumar M
#date            :10-Oct-2019
#version         :1.0
#detailed docs   : 
#==============================================================================
DATE=`date +%Y-%m-%d`
SCRIPTNAME=$(basename $0)
SOURCE_REGION="us-west-2"
DEST_REGION="us-west-2"
SOURCE_REPO="xxxx.dkr.ecr.${SOURCE_REGION}.amazonaws.com" 
DEST_REPO="xxx.dkr.ecr.${DEST_REGION}.amazonaws.com"
SOURCE_PROFILE="dev"
DEST_PROFILE="backup"
AWS=$(which aws)
DOCKER=$(which docker)
LOG="ecr-backup-$DATE.log"
CSV="ecr-backup-$DATE.csv"
true > ${LOG}
true > ${CSV}
declare -a repo_lists=( "xxx/repo1" "xxx/repo2" "xxx/repo3" "xxx/repo4" "xxx/repo5" "xxx/repo6" "xx/repo7" "xx/repo8" "xxx/repo8" "xx/repo9" "xxx/repo10" "xxx/aaa" )

function msg() {
    DATE_TIME=`date +%Y-%m-%d-%H:%M`
    local message="$1"
    echo -e "$DATE_TIME - INFO - $message"
    echo -e "$DATE_TIME - INFO - $message" | tee -a ${LOG} > /dev/null 2>&1
}
function error_exit() {
    DATE_TIME=`date +%Y-%m-%d-%H:%M`
    local message="$1"
    echo -e "$DATE_TIME - ERROR - $message" 
    echo -e "$DATE_TIME - INFO - $message" | tee -a ${LOG} > /dev/null 2>&1
    exit 1
}

function getSourceLogin() {
  eval "$(${AWS} ecr get-login --no-include-email --region ${SOURCE_REGION} --profile $SOURCE_PROFILE)"
  [ $? -eq 0 ] && msg "Login succeeded for source ECR" || error_exit "Aborting!. Unable to login to the source ECR"
}
function getDestLogin(){
  # Define DEST_PROFILE if you configured in the system ie : --profile ${DEST_PROFILE}
  eval "$(${AWS} ecr get-login --no-include-email --region ${DEST_REGION} --profile ${DEST_PROFILE})"
  [ $? -eq 0 ] && msg "Login succeeded for destination ECR" || error_exit "Aborting!. Unable to login to the destination ECR"
}

function createRepository() {
  getSourceLogin
  getDestLogin
  for repo in "${repo_lists[@]}"
  do
    # Define DEST_PROFILE if you configured in the system ie : --profile ${DEST_PROFILE}
    if ${AWS} ecr --region ${DEST_REGION} describe-repositories --repository-name "${repo}" --profile ${DEST_PROFILE}; then
        msg "The repository: $repo is present already"
    else
        msg "The repository: $repo is not present. Hence creating it."
        # Define DEST_PROFILE if you configured in the system ie : --profile ${DEST_PROFILE}
        ${AWS} ecr --region "${DEST_REGION}" create-repository --repository-name "${repo}" --profile ${DEST_PROFILE};
        [ $? -eq 0 ] || error_exit "Aborting!. Unable to create to the repository: ${repo}"
    fi
  done
}
function createAllRepository() {
  getSourceLogin
  getDestLogin
  for repo in $(${AWS} ecr --region ${SOURCE_REGION} describe-repositories --profile ${SOURCE_PROFILE} --output json | jq -r 'map(.[] | .repositoryName ) | join(" ")'); 
  do 
    ${AWS} ecr --region ${DEST_REGION} create-repository --repository-name ${repo} --profile ${DEST_PROFILE}; # Define DEST_PROFILE if you configured in the system ie : --profile ${DEST_PROFILE}
  done
}
function uploadAllImages() {
for repo in $(${AWS} ecr --region ${SOURCE_REGION} describe-repositories --profile ${SOURCE_PROFILE} --output json| jq -r 'map(.[] | .repositoryName ) | join(" ")'); 
do 
  for image in $(${AWS} ecr --region ${SOURCE_REGION} list-images --repository-name $repo --profile ${SOURCE_PROFILE} --output json | jq -r 'map(.[] | .imageTag) | join(" ")'); 
  do 
     ${DOCKER} pull ${SOURCE_REPO}/${repo}:${image}; 
     [ $? -eq 0 ] && msg "The Image : ${image} is pulled from the soure repository : ${SOURCE_REPO}/${repo}" || error_exit "Aborting!. Unable to docker pull : ${SOURCE_REPO}/${repo}"
     ${DOCKER} tag ${SOURCE_REPO}/${repo}:${image} ${DEST_REPO}/${repo}:${image}; 
     [ $? -eq 0 ] && msg "Tagged the Image from soure ${SOURCE_REPO}/${repo}:${image} to ${DEST_REPO}/${repo}:${image}" || error_exit "Aborting!. Unable to docker tag : ${SOURCE_REPO}/${repo}:${image} ${DEST_REPO}/${repo}:${image}"
     ${DOCKER} push ${DEST_REPO}/${repo}:${image}; 
     [ $? -eq 0 ] && msg "Pushed the image to destination repository: ${DEST_REPO}/${repo}:${image}" || error_exit "Aborting!. Unable to docker push: ${DEST_REPO}/${repo}:${image}"
     ${DOCKER} images | grep -w '${repo}' | grep ${image} | awk '{print $3}' | xargs ${DOCKER} rmi
     [ $? -eq 0 ] && msg "Removed the images: ${image} in the local machine" || error_exit "Aborting!. Unable to remove image: ${image} in the local machine"
  done
done 
}
function uploadImages() {
echo -e "NO,SOURCE_REPO,DEST_REPO,IMAGE" > ${CSV}
COUNT=0
for repo in "${repo_lists[@]}"; 
do 
  for image in $(${AWS} ecr describe-images --repository-name ${repo} --region ${SOURCE_REGION} --profile ${SOURCE_PROFILE} --output text --query 'sort_by(imageDetails,& imagePushedAt)[*].imageTags[*]' | tr '\t' '\n'  | tail -10)
  #for image in $(${AWS} ecr --region ${SOURCE_REGION} list-images --repository-name $repo --profile ${SOURCE_PROFILE} --output json | jq -r 'map(.[] | .imageTag) | join(" ")'); 
  do 
     let "COUNT=COUNT+1"
     echo -e "${COUNT},${SOURCE_REPO}/${repo},${DEST_REPO}/${repo},${image}" >> ${CSV}
     ${DOCKER} pull ${SOURCE_REPO}/${repo}:${image} | tee -a ${LOG} > /dev/null 2>&1 
     [ $? -eq 0 ] && msg "The Image : ${image} is pulled from the soure repository : ${SOURCE_REPO}/${repo}" || error_exit "Aborting!. Unable to docker pull : ${SOURCE_REPO}/${repo}"
     ${DOCKER} tag ${SOURCE_REPO}/${repo}:${image} ${DEST_REPO}/${repo}:${image} | tee -a ${LOG} > /dev/null 2>&1 
     [ $? -eq 0 ] && msg "Tagged the Image from soure ${SOURCE_REPO}/${repo}:${image} to ${DEST_REPO}/${repo}:${image}" || error_exit "Aborting!. Unable to docker tag : ${SOURCE_REPO}/${repo}:${image} ${DEST_REPO}/${repo}:${image}"
     ${DOCKER} push ${DEST_REPO}/${repo}:${image} | tee -a ${LOG} > /dev/null 2>&1 
     [ $? -eq 0 ] && msg "Pushed the image to destination repository: ${DEST_REPO}/${repo}:${image}" || error_exit "Aborting!. Unable to docker push: ${DEST_REPO}/${repo}:${image}"
     ${DOCKER} images | awk "{print \$3}" | grep -v "IMAGE" | head -n -1 | xargs ${DOCKER} rmi -f | tee -a ${LOG} > /dev/null 2>&1 
     msg "Removed the images: ${repo}:${image} in the local machine"
     sleep 10
     #${DOCKER} images | grep -w '${repo}' | grep ${image} | awk '{print $3}' | xargs ${DOCKER} rmi --force
     #[ $? -eq 0 ] && msg "Removed the images: ${image} in the local machine" || error_exit "Aborting!. Unable to remove image: ${image} in the local machine"
  done
done 
}

main () {
  createRepository
  uploadImages
}
main

