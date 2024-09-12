#! /bin/bash

DIR="/home/ubuntu"
SCRIPT_NAME="pritunl-script.sh"

# pritunl

mkdir -p $DIR/pritunl/data

# docker

snap install docker

# script

tee $DIR/$GITLAB_SCRIPT_NAME << EOF
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
    docker run --detach --user root --hostname mongodb \
      --network bridge --restart always --name mongodb \
      --volume $DIR/pritunl/data:/data/db mongodb/mongodb-community-server:latest
    sleep 3
    docker run --detach --hostname pritunl \
      --network host --network bridge --restart always --name pritunl \
      --env MONGO_URI="mongodb://mongodb:27017/pritunl-zero" \
      --env NODE_ID="5b8e11e4610f990034635e98" \
      pritunl/pritunl-zero
    ;;
  restart)
    docker restart mongodb
    sleep 3
    docker restart pritunl
    ;;
  *)
    echo "wrong action"
    exit 0
    ;;
esac
EOF

chmod 700 $DIR/$GITLAB_SCRIPT_NAME