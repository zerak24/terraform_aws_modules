#! /bin/bash

DIR="/home/ubuntu"
SCRIPT_NAME="vault-script.sh"

# vault

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

# docker

snap install docker

# nginx

apt install nginx -y
systemctl enable nginx

# certbot

apt update
apt install certbot python3-certbot-nginx -y

tee /etc/nginx/sites-available/default << EOF
server {
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

## script

tee $DIR/$SCRIPT_NAME << EOF
#! /bin/bash

## tool's flag

while (( "\$#" ))
do
  case "\$1" in
    -a|--action)
      ACTION=\$2
      shift 2
      ;;
    -d|--domain)
      DOMAIN_NAME=\$2
      shift 2
      ;;
    -h|--help)
      echo "
-a|--action            : action want to execute (init, restart)
-d|--domain (optional) : vault domain name (use with init) (ex: vault.example.info)
"
      exit 0
      ;;
  esac
done

## main function

case "\${ACTION}" in
  init)
    certbot --nginx -d \${DOMAIN_NAME} --register-unsafely-without-email --agree-tos
    docker run --detach --hostname \${DOMAIN_NAME} \
      --network host --restart always --name vault \
      --volume $DIR/vault/config:/vault/config \
      --volume $DIR/vault/logs:/vault/logs \
      --volume $DIR/vault/file:/vault/file \
      --entrypoint docker-entrypoint.sh --cap-add=IPC_LOCK \
      vault:1.13.3 vault server -config=vault/config/vault.json
    ;;
  restart)
    docker restart vault
    ;;
  *)
    echo "wrong action"
    exit 0
    ;;
esac
EOF

chmod 4755 $DIR/$SCRIPT_NAME