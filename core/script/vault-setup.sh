#! /bin/bash

DOMAIN_NAME=vault.dumblearner.click
DIR="/home/ubuntu"

# vault

snap install docker
mkdir -p $DIR/vault/logs
mkdir -p $DIR/vault/file
mkdir -p $DIR/vault/config
tee $DIR/vault/config/vault.json << EOF
{
  "backend":{
    "file":{
        "path":"/vault/file"
    }
  },
  "listener":{
    "tcp":{
        "address":"[::]:8200",
        "cluster_address":"[::]:8201",
        "tls_disable":1,
    }
  },
  "default_lease_ttl":"24h",
  "max_lease_ttl":"168h", 
  "disable_mlock":true,
  "ui":true,
}
EOF

# nginx

apt install nginx -y
systemctl enable nginx

# certbot

apt update
apt install certbot python3-certbot-nginx -y

tee /etc/nginx/sites-available/default << EOF
server {
    server_name ${DOMAIN_NAME};

    listen [::]:443 ssl ipv6only=on;
    listen 443 ssl;

    location / {
            proxy_pass http://127.0.0.1:8200;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto https;
    }
}
EOF

# test

# tee /etc/nginx/sites-available/default << EOF
# server {

#     listen [::]:80;
#     listen 80;
#     location / {
#             proxy_pass http://127.0.0.1:8200;
#             proxy_set_header Host \$host;
#             proxy_set_header X-Real-IP \$remote_addr;
#             proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
#             proxy_set_header X-Forwarded-Proto https;
#     }
# }
# EOF

systemctl reload nginx

## Manual
# export DOMAIN_NAME=vault.dumblearner.click
# export DIR="/home/ubuntu"
# docker run --detach --network host --restart always --name vault --hostname $DOMAIN_NAME -v $DIR/vault/config:/vault/config -v $DIR/vault/logs:/vault/logs -v $DIR/vault/file:/vault/file --entrypoint docker-entrypoint.sh --cap-add=IPC_LOCK vault:1.13.3 vault server -config=vault/config/vault.json
# certbot --nginx -d $DOMAIN_NAME --register-unsafely-without-email --agree-tos
