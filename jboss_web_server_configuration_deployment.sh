#!/bin/bash -x
#title           :Deployment
#description     :This script will disable the loadbalancer on apache configuration so based on that we can do deployment on APP01 and APP02 applications.
#author          :Arunkumar M
#date            :22-Feb-2017
#==============================================================================

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
        --value)
            VALUE=$2
            shift
            ;;
       *)
            echo "Unknown argument: $1"
            print_help
            ;;
    esac
    shift
done

APP01_MAIN_CONF="/etc/httpd/conf/customSettings.conf"
APP01_MAIN_CONF_BKP="/etc/httpd/conf/customSettings.conf_bkp"
JBOSS_CONFIG="/etc/httpd/conf/customJmxSettings.conf"
JBOSS_CONFIG_BKP="/etc/httpd/conf/customJmxSettings.conf_bkp"
APP02Admin="/etc/httpd/conf/customAdminSettings.conf"
APP02Admin_BKP="/etc/httpd/conf/customAdminSettings.conf_bkp"
APP02="/etc/httpd/conf/customApp02Settings.conf"
APP02_BKP="/etc/httpd/conf/customApp02Settings.conf_bkp"


Apache_reload() {
echo -e "\n ---Reload http configuration ---"
sudo /etc/init.d/httpd reload
if [ $? -eq "0" ]; then
   echo "Reloaded http successfully"
fi
}


print_help () {
echo -e "Usage: bash vbox.sh --action <action> --value <value>"
echo -e "Action should be anyone of below values \n 1. microservice01 \n 2. microservice02 \n 3. JBOSS \n -------------------------
                \n if you selected the microservice01 then Value should be anyone of below  \n -------------------------- \n
                 1. microservice01-DISABLE-APPMBOX1
                 2. microservice01-DISABLE-APPMBOX2
                 3. microservice01-ENABLE-APPMBOX1-APPMBOX2
		 \n Example : bash vbox.sh --action microservice01 --value microservice01-DISABLE-APPMBOX1
                 \n if you selected the microservice02 then Value should be anyone of below  \n -------------------------- \n
                 1. microservice02-DISABLE-APPMBOXmicroservice0201
                 2. microservice02-DISABLE-APPMBOXmicroservice0202
                 3. microservice02-ENABLE-APPMBOXmicroservice0201-APPMBOXmicroservice0202
                 \n Example : bash vbox.sh --action microservice02 --value microservice02-DISABLE-APPMBOXmicroservice0201
		 \n if you selected the JBOSS then Value should be anyone of below  \n -------------------------- \n
                 1. PUBLIC-ENABLE-APPMBOXmicroservice0201
                 2. PUBLIC-ENABLE-APPMBOXmicroservice0202
                 3. ADMIN-ENABLE-APPMBOXmicroservice0201
	         4. ADMIN-ENABLE-APPMBOXmicroservice0202
                 \n Example : bash vbox.sh --action JBOSS --value PUBLIC-ENABLE-APPMBOXmicroservice0201"
}


microservice01_app01() {

    sudo cp -f ${APP01_MAIN_CONF_BKP} ${microservice01_project}
    sudo sed -i '3s/^B/#B/' ${APP01_MAIN_CONF}
    sudo sed -i '12s/^B/#B/' ${APP01_MAIN_CONF}
    sudo sed -i '19s/^B/#B/' ${APP01_MAIN_CONF}
    sudo sed -i '27s/^B/#B/' ${APP01_MAIN_CONF}
    sudo sed -i '36s/^B/#B/' ${APP01_MAIN_CONF}
    sudo sed -i '52s/^B/#B/' ${APP01_MAIN_CONF}
    echo -e "\n------Verify the updated microservice01-Pgwy Admin proxy configuration-----"
        sudo sed -n '2,54p'  ${APP01_MAIN_CONF}
        Apache_reload

}

microservice01_app02() {

    sudo cp -f ${APP01_MAIN_CONF_BKP} ${microservice01_project}
    sudo sed -i '4s/^B/#B/' ${APP01_MAIN_CONF}
    sudo sed -i '13s/^B/#B/' ${APP01_MAIN_CONF}
    sudo sed -i '20s/^B/#B/' ${APP01_MAIN_CONF}
    sudo sed -i '28s/^B/#B/' ${APP01_MAIN_CONF}
    sudo sed -i '37s/^B/#B/' ${APP01_MAIN_CONF}
    sudo sed -i '53s/^B/#B/' ${APP01_MAIN_CONF}

    echo -e "\n------Verify the updated microservice01-Pgwy Admin proxy configuration-----"
    sudo sed -n '2,54p'  ${APP01_MAIN_CONF}
        Apache_reload
}


microservice01_app01_app02() {
    sudo cp -f ${APP01_MAIN_CONF_BKP} ${microservice01_project}
    echo -e "\n------Verify the updated microservice01-Pgwy Admin proxy configuration-----"
    sudo sed -n '2,54p'  ${APP01_MAIN_CONF}
        Apache_reload
}

microservice02_app01() {

        sudo cp -f ${APP02_BKP} ${microservice02_Pgwy}
		sudo cp -f ${APP02Admin_BKP} ${microservice02_PgwyAdmin}
        sudo sed -i '6s/^B/#B/' ${APP02}
        sudo sed -i '14s/^B/#B/' ${APP02}
        echo -e "\n------Verify the updated microservice02-Pgwy  proxy configuration-----"
        sudo sed -n '5,9p'  ${APP02}
		echo -e "\n"
		sudo sed -n '13,16p' ${APP02}
        echo -e "\n --------------------------------------------------------------------"
		sudo sed -i '6s/^B/#B/' ${APP02Admin}
		echo -e "\n------Verify the updated microservice02-Pgwy Admin  proxy configuration-----"
        sudo sed -n '5,8p' ${APP02Admin}
        echo -e "\n --------------------------------------------------------------------"
        echo "INFO" "Disabled the node APPMBOXmicroservice0201 in microservice02-Pgwy & microservice02-Pgwy Admin  proxy configurations "
        echo -e "\n ---Reload http configuration ---"
		Apache_reload
}

microservice02_app02() {

		sudo cp -f ${APP02_BKP} ${microservice02_Pgwy}
        sudo cp -f ${APP02Admin_BKP} ${microservice02_PgwyAdmin}
        sudo sed -i '7s/^B/#B/' ${APP02}
        sudo sed -i '15s/^B/#B/' ${APP02}
        echo -e "\n------Verify the updated microservice02-Pgwy proxy configuration-----"
        sudo sed -n '5,9p'  ${APP02}
        echo -e "\n"
        sudo sed -n '13,16p' ${APP02}
        echo -e "\n --------------------------------------------------------------------"
        sudo sed -i '7s/^B/#B/' ${APP02Admin}
        echo -e "\n------Verify the updated microservice02-Pgwy Admin  proxy configuration-----"
        sudo sed -n '5,8p' ${APP02Admin}
        echo -e "\n --------------------------------------------------------------------"
        echo "INFO" "Disabled the node APPMBOXmicroservice0202 in microservice02-Pgwy & microservice02-Pgwy Admin  proxy configurations "
        echo -e "\n ---Reload http configuration ---"
        Apache_reload

}

microservice02_app01_app02() {
		sudo cp -f ${APP02_BKP} ${microservice02_Pgwy}
		sudo cp -f ${APP02Admin_BKP} ${microservice02_PgwyAdmin}
		echo -e "\n------Verify the updated microservice02-Pgwy proxy configuration-----"
        sudo sed -n '5,9p'  ${APP02}
        echo -e "\n"
        sudo sed -n '13,16p' ${APP02}
        echo -e "\n --------------------------------------------------------------------"
        echo -e "\n------Verify the updated microservice02-Pgwy Admin  proxy configuration-----"
        sudo sed -n '5,8p' ${APP02Admin}
        echo -e "\n --------------------------------------------------------------------"
        echo -e "\n ---Reload http configuration ---"
        echo "INFO" "Enabled the node APPMBOXmicroservice0201 & APPMBOXmicroservice0202 in microservice02-Pgwy & microservice02-Pgwy Admin  proxy configurations "
        echo -e "\n ---Reload http configuration ---"
		Apache_reload
}
public_app01() {

	  sudo cp -f ${JBOSS_CONFIG_BKP} ${JBOSS_CONFIG}
	  sudo sed -i '7s/^#//'  ${JBOSS_CONFIG}	  
	  sudo sed -i '3s/^B/#B/' ${JBOSS_CONFIG}
	  sudo sed -i '4s/^B/#B/' ${JBOSS_CONFIG}
	  sudo sed -i '8s/^B/#B/' ${JBOSS_CONFIG}
	  echo -e "\n------Verify the updated Jboss Admin console proxy configuration-----"
	  sudo sed -n '2,9p' ${JBOSS_CONFIG}
	  echo -e "\n --------------------------------------------------------------------"
	  echo "Reloading the http service"
		Apache_reload
}

public_app02() {

        sudo cp -f ${JBOSS_CONFIG_BKP} ${JBOSS_CONFIG}
	echo -e "\n------Verify the updated Jboss Admin console proxy configuration-----"
#        sudo sed -n '2,9p' ${JBOSS_CONFIG}
	sudo sed -i '8s/^#/ /'  ${JBOSS_CONFIG}
	sudo sed -i '8s/^ //'  ${JBOSS_CONFIG}
	sudo sed -i '3s/^B/#B/' ${JBOSS_CONFIG}
	sudo sed -i '4s/^B/#B/' ${JBOSS_CONFIG}
	sudo sed -i '7s/^B/#B/' ${JBOSS_CONFIG}
        echo -e "\n --------------------------------------------------------------------"
		echo "Reloading the http service"
		Apache_reload
}

admin_app01() {
        sudo cp -f ${JBOSS_CONFIG_BKP} ${JBOSS_CONFIG}
	sudo sed -i '3s/^#//'  ${JBOSS_CONFIG}
	sudo sed -i '4s/^B/#B/' ${JBOSS_CONFIG}
	sudo sed -i '7s/^B/#B/' ${JBOSS_CONFIG}
	sudo sed -i '8s/^B/#B/' ${JBOSS_CONFIG}
	echo -e "\n------Verify the updated Jboss Admin console proxy configuration-----"
        sudo sed -n '2,9p' ${JBOSS_CONFIG}
        echo -e "\n --------------------------------------------------------------------"
        echo "Reloading the http service"
		Apache_reload

}

admin_app02() {
	sudo cp -f ${JBOSS_CONFIG_BKP} ${JBOSS_CONFIG}
	sudo sed -i '4s/^#//'  ${JBOSS_CONFIG}
	sudo sed -i '3s/^B/#B/' ${JBOSS_CONFIG}
	sudo sed -i '7s/^B/#B/' ${JBOSS_CONFIG}
	sudo sed -i '8s/^B/#B/' ${JBOSS_CONFIG}
	echo -e "\n------Verify the updated Jboss Admin console proxy configuration-----"
	sudo sed -n '2,9p' ${JBOSS_CONFIG}
	echo "Reloading the http service"
		Apache_reload
}


if [ "$ACTION" = "APP01" ];then
        if [ "$VALUE" = "microservice01-DISABLE-APPMBOX1" ];then
                microservice01_app01;
                exit;
        elif [ "$VALUE" = "microservice01-DISABLE-APPMBOX2" ];then
                microservice01_app02;
                exit;
        elif [ "$VALUE" = "microservice01-ENABLE-APPMBOX1-APPMBOX2" ];then
                microservice01_app01_app02;
                exit;
        else
                echo "Unkown Action"
                print_help
        fi
elif [ "$ACTION" = "APP02" ];then
        if [ "$VALUE" = "microservice02-DISABLE-APPMBOXmicroservice0201" ];then
                microservice02_app01;
                exit;
        elif [ "$VALUE" = "microservice02-DISABLE-APPMBOXmicroservice0202" ];then
                microservice02_app02;
                exit;
        elif [ "$VALUE" = "microservice02-ENABLE-APPMBOXmicroservice0201-APPMBOXmicroservice0202" ];then
                microservice02_app01_app02;
                exit;
        else
                echo "Unknown Action"
                print_help
        fi
elif [ "$ACTION" = "JBOSS" ];then

        if [ "$VALUE" = "PUBLIC-ENABLE-APPMBOXmicroservice0201" ];then
                public_app01;
                exit;
        elif [ "$VALUE" = "PUBLIC-ENABLE-APPMBOXmicroservice0202" ];then
                public_app02;
                exit;
        elif [ "$VALUE" = "ADMIN-ENABLE-APPMBOXmicroservice0201" ];then
                admin_app01;
                exit;
		elif [ "$VALUE" = "ADMIN-ENABLE-APPMBOXmicroservice0202" ];then
                admin_app02;
                exit;
        else
                echo "Unknown Action"
                print_help
        fi
else
echo "Unknown Action"
print_help
fi
