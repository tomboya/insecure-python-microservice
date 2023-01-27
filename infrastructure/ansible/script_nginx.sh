#!/bin/bash
DEBIAN_FRONTEND=noninteractive apt update && apt install nginx jq -y
wget https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz
tar -xvzf ngrok-v3-stable-linux-amd64.tgz && mv ngrok /usr/local/bin/
ngrok config add-authtoken 2KmmwsI7Q5qlKbKWTjGZ9E899Hx_55oJbkjaQSkKJoLRypa1d
unlink /etc/nginx/sites-enabled/default
cp /home/ubuntu/insecure-python-microservice/infrastructure/ansible/reverse-proxy.conf /etc/nginx/sites-available/reverse-proxy.conf
ln -s /etc/nginx/sites-available/reverse-proxy.conf /etc/nginx/sites-enabled/reverse-proxy.conf
service nginx restart
sleep 1;
while true;
do
    nohup ngrok http localhost:7777 --log=stdout > /dev/null 2>&1 &
    if ps -auxwww | grep -q ngrok; then
        echo "ngrok successfully started"
        sleep 2;
	echo "URL: $(curl -s localhost:4040/api/tunnels | jq -r '.tunnels[0].public_url')"
        break
    else
        echo "Retrying ngrok start..."
        sleep 5
    fi
done

while true;
do
    nohup istioctl dashboard kiali --address 0.0.0.0 &
    if ps -auxwww | grep -q ngrok; then
        echo "kiali successfully started"
        sleep 2;
	echo "Success with kiali"
        break
    else
        echo "Retrying kiali start..."
        sleep 5
    fi
done
