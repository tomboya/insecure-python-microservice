#!/bin/bash
set +e
echo "###############################################################################"
echo "#                             KubeKrack                                       #"
echo "#                   A Vulnerable Kubernetes Lab                               #"
echo "#                                                                             #"
echo "#                           Deletion Script                                   #"
echo "#                                                                             #"
echo "#                  Thank you for using KubeKrack Lab                          #"
echo "#                                                                             #"
echo "###############################################################################"

if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
    echo "The script was sourced (ran via . post_script.sh or source ppost_script.sh)"
    # Add the rest of your script here
else
    echo "The script was executed directly (ran via bash pre_init.sh)"
    echo "Please run the script using 'source post_script.sh' or '. post_script.sh'"
    exit 1
fi


# Disable the socks proxy
unset http_proxy
unset https_proxy

# Change directory to infrastructure/terraform
alias cd_temp="cd infrastructure/terraform"
cd_temp

# Run terraform destroy command
echo "# Terraform destroy in progress"
terraform destroy --auto-approve -lock=false

# Remove terraform related files and folders
rm -rf .terraform*
rm -rf terraform.tfstate*

# change the directory back to the main
alias cd_temp="cd ../../"
cd_temp

echo "###############################################################################"
echo "# Terraform destroy complete                                                  #"
echo "###############################################################################"
# exit the script with a proper status code
#exit 0
