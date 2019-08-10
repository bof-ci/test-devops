#!/bin/bash
set -o allexport

. .env

exec "$@"