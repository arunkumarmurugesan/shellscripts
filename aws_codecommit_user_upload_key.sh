#!/bin/bash

/bin/mkdir -p /mnt/aws-codecommit-keys

while read username; do
        random_pass=`openssl rand -base64 10`
        echo $random_pass
        ssh-keygen -t rsa -N "${random_pass}" -C "codecommit-${username}" -f /mnt/aws-codecommit-keys/${username}-key
        pub_key=`cat /mnt/aws-codecommit-keys/${username}-key.pub`
        IFS=""
        key_id=`cd /mnt/aws-codecommit-keys/${username}-key;aws iam upload-ssh-public-key --user-name ${username}  --ssh-public-key-body ${pub_key} --region us-east-1`
        ssh_key_id=`echo $key_id | awk '{print $6}'`
        echo $ssh_key_id
                echo "Username: ${username} Password: ${random_pass}" | tee -a /mnt/aws-codecommit-keys/user-pwd-credentials.txt
cat > /mnt/aws-codecommit-keys/${username}-config << EOF
Host git-codecommit.*.amazonaws.com
        User $ssh_key_id
        IdentityFile ~/.ssh/${username}-key
EOF

done < userlist.txt;
