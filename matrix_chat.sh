#!/bin/bash

set -e

echo "======================================"
echo " Multi Organization Matrix Installer"
echo "======================================"

echo "Cleaning previous Matrix setup..."

docker rm -f $(docker ps -a --format '{{.Names}}' | grep -E 'synapse_|admin_') 2>/dev/null || true
rm -rf /opt/matrix
rm -f /etc/nginx/sites-enabled/matrix
rm -f /etc/nginx/sites-available/matrix

echo "Cleanup completed."

read -p "How many organizations (domains)? " ORG_COUNT
read -p "Enter SSL email: " EMAIL

INSTALL_DIR="/opt/matrix"

apt update -y
apt install -y docker.io docker-compose nginx certbot python3-certbot-nginx

systemctl enable docker
systemctl start docker

mkdir -p $INSTALL_DIR
mkdir -p $INSTALL_DIR/certs

BASE_PORT=8008
ADMIN_PORT=8081

declare -a DOMAINS
declare -a SAFE_NAMES
declare -a PORTS
declare -a ADMIN_PORTS

echo ""
echo "Enter domains"

for ((i=0;i<ORG_COUNT;i++))
do
read -p "Domain $((i+1)): " DOMAIN

SAFE=$(echo $DOMAIN | tr '.' '_')

DOMAINS[$i]=$DOMAIN
SAFE_NAMES[$i]=$SAFE
PORTS[$i]=$((BASE_PORT+i))
ADMIN_PORTS[$i]=$((ADMIN_PORT+i))

mkdir -p $INSTALL_DIR/$SAFE

docker run -it --rm \
-v $INSTALL_DIR/$SAFE:/data \
-e SYNAPSE_SERVER_NAME=$DOMAIN \
-e SYNAPSE_REPORT_STATS=no \
matrixdotorg/synapse:latest generate

done

echo "Adding federation whitelist..."

for ((i=0;i<ORG_COUNT;i++))
do

SAFE=${SAFE_NAMES[$i]}
FILE=$INSTALL_DIR/$SAFE/homeserver.yaml

echo "" >> $FILE
echo "federation_domain_whitelist:" >> $FILE

for DOMAIN in "${DOMAINS[@]}"
do
echo "  - $DOMAIN" >> $FILE
done

done

echo "Generating docker-compose..."

cat <<EOF > $INSTALL_DIR/docker-compose.yml
version: "3"

services:
EOF

for ((i=0;i<ORG_COUNT;i++))
do

SAFE=${SAFE_NAMES[$i]}
PORT=${PORTS[$i]}
ADMIN=${ADMIN_PORTS[$i]}

cat <<EOF >> $INSTALL_DIR/docker-compose.yml

  synapse_$SAFE:
    image: matrixdotorg/synapse:latest
    container_name: synapse_$SAFE
    restart: always
    volumes:
      - ./$SAFE:/data
    ports:
      - "$PORT:8008"

  admin_$SAFE:
    image: awesometechnologies/synapse-admin
    container_name: admin_$SAFE
    restart: always
    ports:
      - "$ADMIN:80"

EOF

done

cd $INSTALL_DIR
docker-compose up -d

echo "Waiting for Synapse servers to start..."

sleep 40

echo "Generating SSL certificates..."

systemctl stop nginx || true

CERT_DOMAINS=""
for DOMAIN in "${DOMAINS[@]}"
do
CERT_DOMAINS="$CERT_DOMAINS -d $DOMAIN"
done

certbot certonly --standalone \
$CERT_DOMAINS \
--agree-tos \
-m $EMAIL \
--non-interactive

FIRST_DOMAIN=${DOMAINS[0]}

cp /etc/letsencrypt/live/$FIRST_DOMAIN/fullchain.pem $INSTALL_DIR/certs/
cp /etc/letsencrypt/live/$FIRST_DOMAIN/privkey.pem $INSTALL_DIR/certs

echo "Generating nginx configuration..."

for ((i=0;i<ORG_COUNT;i++))
do

DOMAIN=${DOMAINS[$i]}
SAFE=${SAFE_NAMES[$i]}
PORT=${PORTS[$i]}
ADMIN=${ADMIN_PORTS[$i]}

cat <<EOF >> /etc/nginx/sites-available/matrix

server {

listen 443 ssl;
server_name $DOMAIN;

ssl_certificate $INSTALL_DIR/certs/fullchain.pem;
ssl_certificate_key $INSTALL_DIR/certs/privkey.pem;

location /.well-known/matrix/server {
default_type application/json;
return 200 '{"m.server": "$DOMAIN:8448"}';
}

location /.well-known/matrix/client {
default_type application/json;
return 200 '{"m.homeserver": {"base_url": "https://$DOMAIN"}}';
}

location / {
proxy_pass http://localhost:$PORT;
proxy_set_header Host \$host;
}

location /admin/ {
proxy_pass http://localhost:$ADMIN/;
proxy_set_header Host \$host;
}

}

server {

listen 8448 ssl;
server_name $DOMAIN;

ssl_certificate $INSTALL_DIR/certs/fullchain.pem;
ssl_certificate_key $INSTALL_DIR/certs/privkey.pem;

location / {
proxy_pass http://localhost:$PORT;
proxy_set_header Host \$host;
}

}

EOF

done

ln -s /etc/nginx/sites-available/matrix /etc/nginx/sites-enabled/

nginx -t
systemctl restart nginx

echo "Creating admin users..."

for ((i=0;i<ORG_COUNT;i++))
do

SAFE=${SAFE_NAMES[$i]}

docker exec synapse_$SAFE register_new_matrix_user \
-c /data/homeserver.yaml \
-u admin \
-p admin@123 \
-a \
http://localhost:8008 || true

done

echo "Setting up SSL auto renewal..."

(crontab -l 2>/dev/null; echo "0 3 * * * certbot renew --quiet && systemctl reload nginx") | crontab -

echo ""
echo "======================================"
echo " Installation Completed"
echo "======================================"

for DOMAIN in "${DOMAINS[@]}"
do
echo "Chat URL: https://$DOMAIN"
echo "Admin URL: https://$DOMAIN/admin"
echo ""
done

echo "Admin login:"
echo "username: admin"
echo "password: admin@123"
