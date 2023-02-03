#! /bin/bash

if [ $# -eq 0 ]; then
   echo "Must supply a site name."
   exit;
fi

echo "Setting up Skupper for Site $1"
skupper init --site-name $1 --console-auth=internal --console-user=admin --console-password=password

token=$1"-token.yaml"
echo "Exporting token $token"
skupper token create --token-type cert $token

