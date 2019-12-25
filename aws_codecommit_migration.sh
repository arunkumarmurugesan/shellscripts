#!/bin/bash 

while read r; do
  echo $r
  git clone --mirror https://projectdmin@bitbucket.org/projectadmin/$r.git 
  cd $r.git
  git push ssh://git-codecommit.us-east-1.amazonaws.com/v1/repos/$r --all
  git push ssh://git-codecommit.us-east-1.amazonaws.com/v1/repos/$r --tags
  sleep 10
  cd ..
done < repo.txt:
