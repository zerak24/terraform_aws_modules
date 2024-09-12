#! /bin/bash

DIR="/home/ubuntu"
SCRIPT_NAME="gitlab-script.sh"

# gitlab

mkdir -p $DIR/gitlab/config
mkdir -p $DIR/gitlab/logs
mkdir -p $DIR/gitlab/data

# docker

snap install docker

# script

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
-d|--domain (optional) : gitlab domain name (use with init) (ex: git.example.info)
"
      exit 0
      ;;
  esac
done

## main function

case "\${ACTION}" in
  init)
    docker run --detach --hostname \${DOMAIN_NAME} \
      --network host --restart always --name gitlab \
      --volume $DIR/gitlab/config:/etc/gitlab \
      --volume $DIR/gitlab/logs:/var/log/gitlab \
      --volume $DIR/gitlab/data:/var/opt/gitlab \
      --env GITLAB_OMNIBUS_CONFIG="external_url 'https://$DOMAIN_NAME'" \
      --shm-size 256m \
      gitlab/gitlab-ce:17.0.1-ce.0
    ;;
  restart)
    docker restart gitlab
    ;;
  *)
    echo "wrong action"
    exit 0
    ;;
esac
EOF

chmod 4755 $DIR/$SCRIPT_NAME