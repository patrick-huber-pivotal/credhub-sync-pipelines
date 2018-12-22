#!/bin/bash

export CREDHUB_CLI_VERSION=$(cat credhub-cli/version)

echo "extracting credhub cli version $CREDHUB_CLI_VERSION"
tar zxf credhub-cli/credhub-linux-$CREDHUB_CLI_VERSION.tgz
chmod +x credhub-cli/credhub
mv credhub-cli/credhub /usr/local/bin/credhub

export YQ_CLI_VERSION=$(cat yq-cli/version)

echo "installing yq cli version $YQ_CLI_VERSION"
chmod +x yq-cli/yq_linux_amd64
mv yq-cli/yq_linux_amd64 /usr/local/bin/yq

echo "exporting credhub secrets"
mkdir scratch
credhub find -n $CREDHUB_PATH > scratch/creds.yml

echo "finding credential paths"
yq r scratch/creds.yml credentials[*].name | while read name; do    
    relative_path=$(echo $name | sed -e "s|^$CREDHUB_PATH||" -e 's:/*$::')
    new_path=$(echo $CREDHUB_MIRROR_PATH | sed -e 's:/*$::')    
    new_path="$new_path/$relative_path"
    
    echo "synch $name to $new_path"

    cred=$(credhub get -n $name | sed -e "s|$name|$new_path|")

    cred_value=$(echo $cred | yq r - value)
    cred_type=$(echo $cred | yq r - type)

    case "$cred_type" in
        value)
            credhub set -n $new_path -t value \
              --value $cred_value
            ;;
        json)
            credhub set -n $new_path -t json \
              --value $cred_value
            ;;
        password)
            credhub set -n $new_path -t password \
              --password $cred_value
            ;;
        user)
            credhub set -n $new_path -t user \
              --password $(echo $cred_value | yq r - password ) \
              --username $(echo $cred_value | yq r - username)
            ;;
        ssh)
            credhub set -n $new_path -t ssh \
              --private $(echo $cred_value | yq r - private_key) \
              --public $(echo $cred_value | yq r - public_key)
            ;;
        rsa)
            credhub set -n $new_path -t rsa \
              --private $(echo $cred_value | yq r - private_key) \
              --public $(echo $cred_value | yq r - public_key)
            ;;
        certificate)
            credhub set -n $new_path -t certificate \
              --private $(echo $cred_value | yq r - private_key) \
              --public $(echo $cred_value | yq r - certificate) \
              --ca-name $(echo $cred_value | yq r - root)
            ;;
    esac
done

echo "cleaning up"
rm -rf scratch