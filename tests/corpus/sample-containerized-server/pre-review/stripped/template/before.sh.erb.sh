#!/bin/bash
source /appl/profile/zz-csc-env.sh

export PORT=$(find_port)
export PASSWORD=$(create_passwd)
export NGINX_PORT=$PORT
export NGINX_COOKIE=$(echo -n "${PASSWORD}${RANDOM}" | sha1sum | awk '{print $1}')
