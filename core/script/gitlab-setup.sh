#! /bin/bash

DOMAIN_NAME=git.dumblearner.click
DIR="/home/ubuntu"

# gitlab

snap install docker
mkdir -p $DIR/gitlab/config
mkdir -p $DIR/gitlab/logs
mkdir -p $DIR/gitlab/data

# nginx

# apt install nginx -y
# systemctl enable nginx

# certbot  

# apt update
# apt install certbot python3-certbot-nginx -y

# tee /etc/nginx/sites-available/default << EOF
# server {
#     server_name ${DOMAIN_NAME}; # managed by Certbot

#     listen [::]:443 ssl ipv6only=on;
#     listen 443 ssl;

#     location / {
#             proxy_pass http://127.0.0.1:80;
#             proxy_set_header Host \$host;
#             proxy_set_header X-Real-IP \$remote_addr;
#             proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
#             proxy_set_header X-Forwarded-Proto https;
#     }
# }
# EOF

# test

# tee /etc/nginx/sites-available/default << EOF
# server {
#     listen [::]:80;
#     listen 80;

#     location / {
#             proxy_pass http://127.0.0.1:80;
#             proxy_set_header Host \$host;
#             proxy_set_header X-Real-IP \$remote_addr;
#             proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
#             proxy_set_header X-Forwarded-Proto https;
#     }
# }
# EOF

# systemctl reload nginx

## Manual

# export DOMAIN_NAME=git.dumblearner.click
# export DIR="/home/ubuntu"
# certbot --nginx -d $DOMAIN_NAME --register-unsafely-without-email --agree-tos
# docker run --detach --hostname $DOMAIN_NAME --env GITLAB_OMNIBUS_CONFIG="external_url 'https://$DOMAIN_NAME'" \
#   --network host --name gitlab --restart always \
#   --volume $DIR/gitlab/config:/etc/gitlab \
#   --volume $DIR/gitlab/logs:/var/log/gitlab \
#   --volume $DIR/gitlab/data:/var/opt/gitlab \
#   --shm-size 256m \
#   gitlab/gitlab-ce:17.0.1-ce.0