#!/bin/bash
echo "###############################################################################"
echo "#                           KubeKrack                                         #"
echo "#                 A Vulnerable Kubernetes Lab                                 #"
echo "#                  Created by justmorpheus                                    #"
echo "#                 Email: namaste@securitydojo.co.in                           #"
echo "###############################################################################"

echo "###############################################################################"

# Check if git repository is up to date
echo "# Verifying Latest Updates"
if [[ $(git rev-parse HEAD) != $(git ls-remote $(git rev-parse --abbrev-ref @{u} | \
  sed 's/\// /g') | cut -f1) ]]; then
  git pull
fi

echo "# Installing autossh dependency"
OS="$(uname)"
# Check if autossh is already installed
if command -v autossh >/dev/null 2>&1 ; then
  echo "# autossh is already installed. Skipping autossh installation."
else
  # Determines the operating system.

  if [ "${OS}" = "Darwin" ] ; then
    OSEXT="osx"
    echo "# autossh installation in progress"
    brew install autossh
  elif grep -q "Amazon" /etc/os-release; then
    echo "# autossh installation in progress for Amazon Linux"
    sudo yum update -y
    sudo amazon-linux-extras install epel -y
    sudo yum install autossh -y
  elif grep -q "Ubuntu" /etc/os-release; then
    echo "# autossh installation in progress for Ubuntu"
    sudo apt-get update
    sudo apt-get install -y autossh
  elif grep -q "CentOS" /etc/os-release; then
    echo "# autossh installation in progress for Centos"
    sudo yum update -y
    sudo yum install -y autossh
  else
    echo "# Unable to determine the operating system. Install autossh manually."
    exit 1
  fi
fi


echo "# Starting script execution"
echo "# Verifying Terraform Installation"
if ! terraform version > /dev/null ; then
  echo "Terraform is not installed. Exiting script."
  exit 1
fi

echo "# Verifying AWS Configuration in us-east-1"

if ! aws configure list|grep -iq "ACCESS_KEY" ; then
  echo "AWS CLI is not configured. Exiting script."
  exit 1
elif ! aws configure get region | grep -q "us-east-1" ; then
  echo "AWS region is not set to us-west-2. Exiting script."
  exit 1
fi

echo "# Changing directory to infrastructure/terraform"
alias cd_temp="cd infrastructure/terraform"
cd_temp


echo "# Initializing Terraform"
terraform init
echo "# Applying Terraform configuration"
terraform apply --auto-approve
if [ $? -ne 0 ]; then
  echo "terraform apply failed"
  exit 1
fi
echo "# Setting permissions for ec2_key.pem and bastion_key.pem"
chmod 400 ec2_key.pem
chmod 400 bastion_key.pem
#variable
BASTION_HOST_IP=$(terraform output bastion_host_public_ip | tr -d '"')
SLAVE_1=$(terraform output private_ec2_private_ip_slave1 | tr -d '"')

echo "# Copying ssh keys to remote server"
scp -o StrictHostKeyChecking=no -i bastion_key.pem ec2_key.pem ubuntu@$(terraform output bastion_host_public_ip | tr -d '"'):~/
# Check if the key file exists on the server
if ssh -o StrictHostKeyChecking=no -i bastion_key.pem ubuntu@$BASTION_HOST_IP "ls /home/ubuntu/ec2_key.pem" ; then
  echo "Ssh Key file already exists on the server"
else
  echo "Key file not found on the server, copying now"
  scp -o StrictHostKeyChecking=no -i bastion_key.pem ec2_key.pem ubuntu@$BASTION_HOST_IP:~/
fi

echo "# Deployment In Progress."
while true; do
    # use ssh to check the status of user-data on the remote host
    status=$(ssh -i bastion_key.pem -o StrictHostKeyChecking=no ubuntu@$BASTION_HOST_IP "cat /var/log/cloud-init.log|grep 'modules-final: SUCCESS'")

    # check if the command was successful
    if [ $? -eq 0 ]; then
        echo "# User-data complete"
        break
    else
        echo "# User-data in progress"
        sleep 60
    fi
done
echo "# Deployment Is Complete."

echo "# Enabling dynamic port forwarding."
command="ssh -v -D 9090 -f -C -q -N -i bastion_key.pem -o StrictHostKeyChecking=no ubuntu@$BASTION_HOST_IP"

eval $command
if [ $? -eq 0 ]; then
  echo "# Dynamic port forwarding successful"
else
  echo "# Command Failed"
fi
#Additional Check for autossh
autossh -f -M 0 -o "ServerAliveInterval 30" -o "ServerAliveCountMax 3" -D 9090 -i bastion_key.pem -o StrictHostKeyChecking=no ubuntu@$BASTION_HOST_IP

# Check if the URL is accessible
export http_proxy=socks5://127.0.0.1:9090 
export https_proxy=socks5://127.0.0.1:9090
status_code=$(curl --connect-timeout 10 -s -o /dev/null -w "%{http_code}" http://$SLAVE_1:32634)
# Check if the status code is 200 (OK)
if [ $status_code -eq 200 ]; then
  sleep 1;
  echo "# URL is accessible"
else
  echo "# URL is not accessible, re-running SSH command for port forwarding"
  #Not sure auto-ssh actually forwards, it did restart the session
  ssh -D 9090 -f -C -q -N -i bastion_key.pem -o StrictHostKeyChecking=no ubuntu@$BASTION_HOST_IP
  autossh -f -M 0 -o "ServerAliveInterval 30" -o "ServerAliveCountMax 3" -D 9090 -i bastion_key.pem -o StrictHostKeyChecking=no ubuntu@$BASTION_HOST_IP
fi
echo "###############################################################################"
echo "# SOCKS proxy has been enabled on the CLI"
echo "# Enable socks proxy in the browser and forward to localhost:9090."
echo "# Access Web Application Locally: http://$SLAVE_1:32634"
echo "# Access kubernetes Dashboard Locally: http://$SLAVE_1:30033"
echo "# Access Kiali Dashboard Locally: http://$SLAVE_1:20001"
echo "# Run command terraform folder to enabled dynamic port forwarding to access application locally: autossh -f -M 0 -o 'ServerAliveInterval 30' -o 'ServerAliveCountMax 3' -D 9090 -i bastion_key.pem -o StrictHostKeyChecking=no ubuntu@$BASTION_HOST_IP"
# Check if ngrok is running
result=$(ssh -o ProxyCommand="ssh -i bastion_key.pem -W %h:%p -o StrictHostKeyChecking=no ubuntu@$BASTION_HOST_IP" -o StrictHostKeyChecking=no -i ec2_key.pem ubuntu@$SLAVE_1 "ps aux | grep -E 'ngrok http localhost:7777' | grep -v grep")
if [[ ! -z "$result" ]]; then
  # Get the ngrok URL
  url=$(ssh -o ProxyCommand="ssh -i bastion_key.pem -W %h:%p -o StrictHostKeyChecking=no ubuntu@$BASTION_HOST_IP" -o StrictHostKeyChecking=no -i ec2_key.pem ubuntu@$SLAVE_1 "curl --silent http://localhost:4040/api/tunnels|jq '.tunnels[0].public_url'" | tr -d '"')
  echo "# Globally Access Application via: $url/webui"
else
  # Start ngrok and wait for it to start
  ssh -o ProxyCommand="ssh -i bastion_key.pem -W %h:%p -o StrictHostKeyChecking=no ubuntu@$BASTION_HOST_IP" -o StrictHostKeyChecking=no -i ec2_key.pem ubuntu@$SLAVE_1 "nohup ngrok http localhost:7777 --log=stdout > /dev/null 2>&1 &"
  while [[ -z "$result" ]]; do
    result=$(ssh -o ProxyCommand="ssh -i bastion_key.pem -W %h:%p -o StrictHostKeyChecking=no ubuntu@$BASTION_HOST_IP" -o StrictHostKeyChecking=no -i ec2_key.pem ubuntu@$SLAVE_1 "ps aux | grep -E 'ngrok http localhost:7777' | grep -v grep")
    sleep 1
  done
  # Get the ngrok URL
  url=$(ssh -o ProxyCommand="ssh -i bastion_key.pem -W %h:%p -o StrictHostKeyChecking=no ubuntu@$BASTION_HOST_IP" -o StrictHostKeyChecking=no -i ec2_key.pem ubuntu@$SLAVE_1 "curl --silent http://localhost:4040/api/tunnels|jq '.tunnels[0].public_url'" | tr -d '"')
  echo "# Globally Access Application via: $url/webui"
fi

#check kiali
result=$(ssh -o ProxyCommand="ssh -i bastion_key.pem -W %h:%p -o StrictHostKeyChecking=no ubuntu@$BASTION_HOST_IP" -o StrictHostKeyChecking=no -i ec2_key.pem ubuntu@$SLAVE_1 "ps aux | grep -E 'istioctl dashboard kiali' | grep -v grep")
if [[ ! -z "$result" ]]; then
  # Get the kiali URL
  url=$(ssh -o ProxyCommand="ssh -i bastion_key.pem -W %h:%p -o StrictHostKeyChecking=no ubuntu@$BASTION_HOST_IP" -o StrictHostKeyChecking=no -i ec2_key.pem ubuntu@$SLAVE_1 "curl --silent http://localhost:4040/api/tunnels|jq '.tunnels[0].public_url'" | tr -d '"')
  echo "# Access Kiali Dasboard via: $url/kiali"
else
  # Start kiali and wait for it to start
  ssh -o ProxyCommand="ssh -i bastion_key.pem -W %h:%p -o StrictHostKeyChecking=no ubuntu@$BASTION_HOST_IP" -o StrictHostKeyChecking=no -i ec2_key.pem ubuntu@$SLAVE_1 "nohup istioctl dashboard kiali --address 0.0.0.0 &"
  while [[ -z "$result" ]]; do
    result=$(ssh -o ProxyCommand="ssh -i bastion_key.pem -W %h:%p -o StrictHostKeyChecking=no ubuntu@$BASTION_HOST_IP" -o StrictHostKeyChecking=no -i ec2_key.pem ubuntu@$SLAVE_1 "ps aux | grep -E 'istioctl dashboard kiali' | grep -v grep")
    sleep 1
  done
  # Get the kiali URL
  url=$(ssh -o ProxyCommand="ssh -i bastion_key.pem -W %h:%p -o StrictHostKeyChecking=no ubuntu@$BASTION_HOST_IP" -o StrictHostKeyChecking=no -i ec2_key.pem ubuntu@$SLAVE_1 "curl --silent http://localhost:4040/api/tunnels|jq '.tunnels[0].public_url'" | tr -d '"')
  echo "# Access Kiali Dasboard via: $url/kiali"
fi
echo "###############################################################################"



alias cd_back="cd ../../"
cd_back
echo "# To Destroy Lab, run: source post_scrit.sh"

echo "# Script execution complete."

