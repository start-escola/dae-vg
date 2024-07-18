#!/bin/sh

envsubst '$DOMAIN $SSL_CERTIFICATE_PATH $SSL_CERTIFICATE_KEY_PATH' < /etc/nginx/nginx.conf > /etc/nginx/nginx.conf.tmp
mv /etc/nginx/nginx.conf.tmp /etc/nginx/nginx.conf

nginx -g 'daemon off;'
