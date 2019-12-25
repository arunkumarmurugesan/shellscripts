#!/bin/bash 
#title           :deployer_k8s_utils.sh 
#description     :This script will create the kops cluster with high availability.
#author          :Arunkumar M
#date            :10-Oct-2018
#version         :1.0
#usage           :./deployer_k8s_utils.sh --action <action> --env <environment> --kubeversion <kubeversion>
#detailed docs   : 
#==============================================================================
set -e

DATE=`date +%Y-%m-%d`
DATE_TIME=`date +%Y-%m-%d-%H:%M`
SCRIPTNAME=$(basename $0)
TERRAFORM=$(which terraform)
KOPS=$(which kops)
LOG="terraform-$DATE.log"

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
      echo -e "Usage: ${SCRIPTNAME} --action <action> --env <environment> --kubeversion <kubeversion>"
      echo "  Note: mandatory parameters --action <action> --env <environment>"
      echo "  --action <action>"
      echo -e "\tinit"
      echo -e "\tcreateCluster"
      echo -e "\tdestroyCluster"
      echo -e "\tupgradeClusterVersion"
      echo -e "\tchangeInstanceGroup"
      echo "  --env <environment>"
      echo -e "\tprod"
      echo -e "\tdev"
      echo -e "\tdemo"
      echo -e "\tstaging"
      echo "  --kubeversion <kubeversion>"
      echo -e "\t1.10.3\n\t1.10.5\n\t1.10.7"
      echo "  Note: we can upgrade only aforementioned version's since the kops latest version is 10"

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
        --action)
            ACTION=$2
            shift
            ;;
        --env)
            ENV=$2
            shift
            ;;
        --kubeversion)
            KUBEVERSION=$2
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

#print_help
function install_jq () {
  if [ "`which jq`" ]; then
    echo -e "`(jq --version)` had been installed already."
  else
    JQ=/usr/bin/jq
    curl https://stedolan.github.io/jq/download/linux64/jq > $JQ && chmod +x $JQ
   echo -e "Installed `(jq --version)`"
  fi
}

function install_terraform () {
  #Check if terraform is installed
  if [ "`which terraform`" ]; then
    echo -e "`(terraform --version)` had been installed already."
  else
    # Install terraform here
    echo -e "Installing terraform."
    wget https://releases.hashicorp.com/terraform/0.11.8/terraform_0.11.8_linux_amd64.zip
    unzip terraform_0.11.8_linux_amd64.zip
    sudo mv terraform /usr/local/bin/
    echo -e "Installed `(terraform --version)`"
  fi
}

function install_kops () {
   if [ "`which kops`" ]; then
     echo -e "`(kops version)` had been installed already."
   else 
     echo -e "Installing kops."
     wget -O kops https://github.com/kubernetes/kops/releases/download/$(curl -s https://api.github.com/repos/kubernetes/kops/releases/latest | grep tag_name | cut -d '"' -f 4)/kops-linux-amd64
     chmod +x ./kops
     sudo mv ./kops /usr/local/bin/
     echo -e "Installed `(kops --version)`"
   fi
}

#After creating the EC2 cluster with the configured instances etc, wait for Amazon to start them and pass checks
function validateCluster {
  while [ 1 ]; do
      source variable.sh
      ${KOPS} validate cluster ${NAME} && break || sleep 30
  done;

}

function initDeployCluster () {
      cat /dev/null > ${LOG}
      install_jq
      install_terraform
      install_kops
      # Terraform init - initialize
      ${TERRAFORM} init | tee -a ${LOG} > /dev/null 2>&1
      [ $? -eq 0 ] && msg "Successfully initiated the terraform init." || error_exit "Exection Failed: Cloud not able to initialize terraform init"
      # Terraform plan to create the VPC/RDS/ES/SG.
      ${TERRAFORM} plan | tee -a ${LOG} > /dev/null 2>&1
      [ $? -eq 0 ] && msg "Successfully initiated the terraform plan to the VPC/RDS/ES/SG." || error_exit "Exection Failed: Cloud not able to initialize terraform plan to the VPC/RDS/ES/SG"
      # Terraform apply - create the aws VPC/RDS/ES/SG resources
      echo "yes" | ${TERRAFORM} apply | tee -a ${LOG}
      [ $? -eq 0 ] && msg "Successfully created the VPC/RDS/ES/SG." || error_exit "Exection Failed: Cloud not able to create the VPC/RDS/ES/SG."
      # Get the value from the Terraform and assign to the variables
      source variable.sh  
      # Create the Kops Cluster
      ${KOPS} create cluster  --kubernetes-version ${KUBEVER} --master-zones ${ZONES} --zones ${ZONES} --dns-zone ${DNS_ZONE}  --vpc ${VPC_ID} --node-count ${NODE_COUNT} --master-count ${MASTER_COUNT} --master-size ${MASTER_INSTANCE_TYPE} --node-size ${NODE_INSTANCE_TYPE} --state ${KOPS_STATE_STORE} --image ${IMAGE_ID} --topology private --api-loadbalancer-type public --networking calico  --dns private --authorization RBAC --cloud aws --target=terraform  --out=. ${NAME}
      [ $? -eq 0 ] && msg "Successfully initiated the Kops cluster creation" || error_exit "Exection Failed: Cloud not able to initialize the kops cluster creation"
      # Get the cluster configuration in yaml file in order to change the VPC attributes  
      ${KOPS} get cluster ${NAME} -o yaml > cp-kubernetes.yaml
      [ $? -eq 0 ] && msg "Get the cluster configuration in the yaml." || error_exit "Exection Failed: Cloud not able to get the kops cluster yaml"
      # Update the cluster configuration 
      natgatway=($(terraform output -json nat_gateway_ids | jq -r '.value|join(",")' | tr ',' '\n'))
      private=($(terraform output -json private_subnet_ids | jq -r '.value|join(",")' |tr ',' '\n' ))
      public=($(terraform output -json public_subnet_ids | jq -r '.value|join(",")' | tr ',' '\n'))
      val=$(grep -A1 -ir "vpc_cidr" variables.tf | awk '{print $3}' | grep -v "{" | awk -F'"' '{print $2}' | awk -F"." '{print $1}')
      sed -ie "s/- cidr: ${val}.0.32.0\/19/- egress: ${natgatway[0]}\n    id: ${private[0]}/" ${env}-kubernetes.yaml
      sed -ie "s/- cidr: ${val}.0.64.0\/19/- egress: ${natgatway[1]}\n    id: ${private[1]}/" ${env}-kubernetes.yaml
      sed -ie "s/- cidr: ${val}.0.96.0\/19/- egress: ${natgatway[2]}\n    id: ${private[2]}/" ${env}-kubernetes.yaml
      sed -ie "s/- cidr: ${val}.0.0.0\/22/- id: ${public[0]}/" cp-kubernetes.yaml
      sed -ie "s/- cidr: ${val}.0.4.0\/22/- id: ${public[1]}/" cp-kubernetes.yaml
      sed -ie "s/- cidr: ${val}.0.8.0\/22/- id: ${public[2]}/" cp-kubernetes.yaml
      # Replace the cluster yaml with updated cluster configurations
      ${KOPS} replace -f cp-kubernetes.yaml
      [ $? -eq 0 ] && msg "Replaced the kubernetes yaml" || error_exit "Exection Failed: Cloud not able to replace the kubernetes yaml."
      # Update the Cluster 
      ${KOPS} update cluster --out=. --target=terraform ${NAME}
      [ $? -eq 0 ] && msg "The kubernetes cluster creation is updated in terraform." || error_exit "Exection Failed: Cloud not able to update the kubernetes cluster."
      # Remove the ssh access in cluster configuration
      sed -ie '/ssh-external-to-master-0-0-0-0--0/,+7d' kubernetes.tf
      sed -ie '/ssh-external-to-node-0-0-0-0--0/,+7d' kubernetes.tf
      # Terraform plan - for kops cluster creation
      ${TERRAFORM} plan | tee -a ${LOG} > /dev/null 2>&1
      [ $? -eq 0 ] && msg "Successfully initiated the terraform plan for kops cluster creation" || error_exit "Exection Failed: Cloud not able to initialize terraform plan for kops cluster creation"
      # Terraform apply - Create the Kops Cluster
      echo "yes" | ${TERRAFORM} apply  | tee -a ${LOG}
      [ $? -eq 0 ] && msg "Successfully created the Kops cluster." || error_exit "Exection Failed: Cloud not able to create the Kops cluster."
      # Terraform Output - Print the ALL resources created by Terraform
      msg "The Cluster has been created successfully. Please find the resources details below."
      ${TERRAFORM} output -json 
      python aws-security-fix.py -r us-east-1 -s3 ntxtdevopslogs -e arunkumar.murugesan@nutanix.com -k all
      validateCluster
}

function createCluster () {
     cat /dev/null > ${LOG}
     install_jq
     install_terraform
     install_kops
     env=$(echo $ENV | awk '{print tolower($0)}')
     mkdir -p $env
     pushd $env
     cp -r ../override.tf ../outputs.tf ../main.tf ../modules ../variables.tf ../variable.sh .
     rm -rf cp-kubernetes* kubernetes.* data terraform*
     # Terraform init - initialize
     ${TERRAFORM} init | tee -a ${LOG} > /dev/null 2>&1
     [ $? -eq 0 ] && msg "Successfully initiated the the terraform init." || error_exit "Exection Failed: Cloud not able to initialize terraform init"
     # Terraform apply - create the aws VPC/RDS/ES/SG resources
      ${TERRAFORM} apply -auto-approve | tee -a ${LOG} > /dev/null 2>&1
      [ $? -eq 0 ] && msg "Successfully created the VPC/RDS/ES/SG." || error_exit "Exection Failed: Cloud not able to create the VPC/RDS/ES/SG."
     source variable.sh
     # Create the Kops Cluster
     #${KOPS} create cluster  --master-zones ${ZONES} --zones ${ZONES} --dns-zone ${DNS_ZONE}  --vpc ${VPC_ID}  --master-size ${MASTER_INSTANCE_TYPE} --node-size ${NODE_INSTANCE_TYPE} --state ${KOPS_STATE_STORE}  --topology private --api-loadbalancer-type public --networking calico  --dns private --authorization RBAC --cloud aws --target=terraform  --out=. ${NAME}
     # Create the kops cluster with required paramaters.
     ${KOPS} create cluster  --master-zones $ZONES --zones $ZONES --dns-zone $(terraform output private_zone_id) --vpc $(terraform output vpc_ids) --networking calico --topology private  --api-loadbalancer-type public --dns private --authorization RBAC --target=terraform --out=. ${NAME}

     # Get the cluster configuration in yaml file in order to change the VPC attributes  
     ${KOPS} get cluster ${NAME} -o yaml > ${env}-kubernetes.yaml
     # Update the cluster configuration 
     val=$(grep -A1 -ir "vpc_cidr" variables.tf | awk '{print $3}' | grep -v "{" | awk -F'"' '{print $2}' | awk -F"." '{print $1"."$2}')
     natgatway=($(terraform output -json nat_gateway_ids | jq -r '.value|join(",")' | tr ',' '\n'))
     private=($(terraform output -json private_subnet_ids | jq -r '.value|join(",")' |tr ',' '\n' ))
     public=($(terraform output -json public_subnet_ids | jq -r '.value|join(",")' | tr ',' '\n'))
     sed -ie "s/- cidr: ${val}.32.0\/19/- egress: ${natgatway[0]}\n    id: ${private[0]}/" ${env}-kubernetes.yaml
     sed -ie "s/- cidr: ${val}.64.0\/19/- egress: ${natgatway[1]}\n    id: ${private[1]}/" ${env}-kubernetes.yaml
     sed -ie "s/- cidr: ${val}.96.0\/19/- egress: ${natgatway[2]}\n    id: ${private[2]}/" ${env}-kubernetes.yaml
     sed -ie "s/- cidr: ${val}.0.0\/22/- id: ${public[0]}/" ${env}-kubernetes.yaml
     sed -ie "s/- cidr: ${val}.4.0\/22/- id: ${public[1]}/" ${env}-kubernetes.yaml
     sed -ie "s/- cidr: ${val}.8.0\/22/- id: ${public[2]}/" ${env}-kubernetes.yaml
     # Replace the cluster yaml with updated cluster configurations
     ${KOPS} replace -f ${env}-kubernetes.yaml
     [ $? -eq 0 ] && msg "Replaced the kubernetes yaml" || error_exit "Exection Failed: Cloud not able to replace the kubernetes yaml."
     # Update the Cluster 
     ${KOPS} update cluster --out=. --target=terraform ${NAME} 
     [ $? -eq 0 ] && msg "The kubernetes cluster has been updated." || error_exit "Exection Failed: Cloud not able to update the kubernetes cluster."
     # Remove the ssh access in cluster configuration
     sed -ie '/ssh-external-to-master-0-0-0-0--0/,+7d' kubernetes.tf
     sed -ie '/ssh-external-to-node-0-0-0-0--0/,+7d' kubernetes.tf
     # Terraform apply - Create the Kops Cluster
     ${TERRAFORM} apply -auto-approve  | tee -a ${LOG}
     [ $? -eq 0 ] && msg "The terraform apply is initialized and created the Kops cluster successfully." || error_exit "Exection Failed: Cloud not able to create the Kops cluster."
     python aws-security-fix.py -r us-east-1 -s3 ntxtdevopslogs -e arunkumar.murugesan@nutanix.com -k k8s
     validateCluster
     popd
}

function destoryCluster () {
  if [ ${ENV} = "prod" ]; then
      # Remove the cluster terraform files
      rm -rf cp-kubernetes.yaml* 
      # Terraform destroy - Clean up the cluster
      ${TERRAFORM} destroy -auto-approve
      [ $? -eq 0 ] && msg "The Cluster has been destroyed successfully." || error_exit "Exection Failed: Cloud not able to destroy the cluster"
  else
     env_lc=$(echo $ENV | awk '{print tolower($0)}')
     pushd $env_lc
     ${TERRAFORM} destroy -auto-approve
     [ $? -eq 0 ] && msg "The Cluster has been destroyed successfully." || error_exit "Exection Failed: Cloud not able to destroy the cluster"
     popd
 fi
}

function upgradeClusterVersion () {

  if [ ${ENV} = "prod" ]; then
     ${KOPS} get cluster ${NAME} -o yaml > ${KUBEVERSION}-upgrade.yaml
     sed -ie "/kubernetesVersion/c\  kubernetesVersion: ${KUBEVERSION}" ${KUBEVERSION}-upgrade.yaml
     ${KOPS} replace -f ${KUBEVERSION}-upgrade.yaml
     ${KOPS} update cluster --out=. --target=terraform ${NAME}
     [ $? -eq 0 ] && msg "Successfully updated the cluster version in terraform." || error_exit "Exection Failed: Cloud not able to update the cluster version in terraform"
     sed -ie '/ssh-external-to-master-0-0-0-0--0/,+7d' kubernetes.tf
     sed -ie '/ssh-external-to-node-0-0-0-0--0/,+7d' kubernetes.tf
     ${TERRAFORM} plan | tee -a "upgrade-${LOG}" > /dev/null 2>&1
     ${TERRAFORM} apply -auto-approve | tee -a "upgrade-${LOG}" > /dev/null 2>&1
     [ $? -eq 0 ] && msg "Applied the changes in cluster." || error_exit "Exection Failed: Cloud not able to apply the changes in the cluster"
     ${KOPS} rolling-update cluster ${NAME} --yes | tee -a "upgrade-${LOG}" 
     [ $? -eq 0 ] && msg "Successfully rolling-updated the cluster" || error_exit "Exection Failed: Cloud not able to rolling-update the cluster"
  else
     env_lc=$(echo $ENV | awk '{print tolower($0)}')
     pushd $env_lc
     source variable.sh
     validateCluster
     ${KOPS} get cluster ${NAME} -o yaml > ${KUBEVERSION}-upgrade.yaml
     sed -ie "/kubernetesVersion/c\  kubernetesVersion: ${KUBEVERSION}" ${KUBEVERSION}-upgrade.yaml
     ${KOPS} replace -f ${KUBEVERSION}-upgrade.yaml
     ${KOPS} update cluster --out=. --target=terraform ${NAME}
     [ $? -eq 0 ] && msg "Successfully updated the cluster version in terraform." || error_exit "Exection Failed: Cloud not able to update the cluster version in terraform"
     sed -ie '/ssh-external-to-master-0-0-0-0--0/,+7d' kubernetes.tf
     sed -ie '/ssh-external-to-node-0-0-0-0--0/,+7d' kubernetes.tf
     ${TERRAFORM} plan | tee -a "upgrade-${LOG}" > /dev/null 2>&1
     ${TERRAFORM} apply -auto-approve | tee -a "upgrade-${LOG}" > /dev/null 2>&1
     [ $? -eq 0 ] && msg "Applied the changes in cluster." || error_exit "Exection Failed: Cloud not able to apply the changes in the cluster"
     ${KOPS} rolling-update cluster ${NAME} --yes |  tee -a "upgrade-${LOG}" 
     [ $? -eq 0 ] && msg "Successfully rolling updated the cluster" || error_exit "Exection Failed: Cloud not able to rolling-update the cluster"
     # Call the validation function
     validateCluster
     popd
  fi
}

function changeNodeInstanceType () {
  source variable.sh
  ${KOPS} get ig nodes -o yaml > instancegroup.yaml
  sed -ie "/machineType:/c\  machineType: ${NODE_INSTANCE_TYPE}" instancegroup.yaml
  cat instancegroup.yaml | ${KOPS} replace -f -
  ${KOPS} update cluster --out=. --target=terraform ${NAME} | tee -a "instancegroup-${LOG}" > /dev/null 2>&1
  sed -ie '/ssh-external-to-master-0-0-0-0--0/,+7d' kubernetes.tf
  sed -ie '/ssh-external-to-node-0-0-0-0--0/,+7d' kubernetes.tf
  ${TERRAFORM} plan | tee -a "instancegroup-${LOG}" > /dev/null 2>&1
  ${TERRAFORM} apply -auto-approve
  rm instancegroup.yaml
  ${KOPS} rolling-update cluster ${NAME} --yes 
  validateCluster
}

main () {

if [ "$ACTION" = "init" ];then
    initDeployCluster
elif [ "$ACTION" = "createCluster" ];then
    createCluster
elif [ "$ACTION" = "destroyCluster" ];then
    destoryCluster
elif [ "$ACTION" = "upgradeClusterVersion" ]; then
   upgradeClusterVersion
elif [ "$ACTION" = "changeInstanceGroup" ]; then
   changeNodeInstanceType
   echo "hi"
else
   print_help
fi

}

main
