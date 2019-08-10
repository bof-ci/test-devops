#!/bin/sh
set -o allexport

source /.env

exec "$@"