#!/bin/sh


# this works but requires each var be exported
# source .env
# echo COMPOSE_PROJECT_NAME is [$COMPOSE_PROJECT_NAME]
# export COMPOSE_PROJECT_NAME

# this just exports every var in there:
set -a
. ./.env
set +a

exec /usr/local/bin/testserver --address 0.0.0.0 --cert-file /crt/appserver.crt --key-file /crt/appserver.key --ca-file crt/ca.crt
