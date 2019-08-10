#!/bin/bash
set -o allexport

. .env

ip=$(hostname -i)
/usr/local/bin/testserver -address $ip
