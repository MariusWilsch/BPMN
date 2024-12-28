#!/bin/bash

domains=(veloxpower.store)
email="marius.santiago.wilsch@gmail.com"
data_path="./certbot"

# Create required directories
mkdir -p "$data_path/conf/live/$domains"
mkdir -p "$data_path/www"

# Stop any running containers
docker compose down

# Get initial certificate
docker compose run --rm certbot certonly \
    --webroot \
    --webroot-path /var/www/certbot \
    --email $email \
    --agree-tos \
    --no-eff-email \
    -d $domains \
    -v

# Start the containers
docker compose up -d
