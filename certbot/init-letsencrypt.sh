#!/bin/bash

if ! [ -x "$(command -v docker-compose)" ]; then
  echo 'Error: docker-compose is not installed.' >&2
  exit 1
fi

domains=(dae.varzeagrande.mt.gov.br www.dae.varzeagrande.mt.gov.br)
rsa_key_size=4096
data_path="./certbot"
email="wilson.mesquita@s2corporate.com.br" # Adicionar um endereço válido é fortemente recomendado
staging=0 # Defina como 1 se estiver testando sua configuração para evitar atingir limites de solicitação

if [ -d "$data_path" ]; then
  read -p "Dados existentes encontrados para $domains. Continuar e substituir o certificado existente? (y/N) " decision
  if [ "$decision" != "Y" ] && [ "$decision" != "y" ]; then
    exit
  fi
fi

if [ ! -e "$data_path/conf/options-ssl-nginx.conf" ] || [ ! -e "$data_path/conf/ssl-dhparams.pem" ]; then
  echo "### Baixando parâmetros TLS recomendados ..."
  mkdir -p "$data_path/conf"
  curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf > "$data_path/conf/options-ssl-nginx.conf"
  curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot/certbot/ssl-dhparams.pem > "$data_path/conf/ssl-dhparams.pem"
  echo
fi

echo "### Criando certificado dummy para $domains ..."
path="/etc/letsencrypt/live/$domains"
mkdir -p "$data_path/conf/live/$domains"
docker-compose run --rm --entrypoint "\
  openssl req -x509 -nodes -newkey rsa:$rsa_key_size -days 1 \
    -keyout '$path/privkey.pem' \
    -out '$path/fullchain.pem' \
    -subj '/CN=localhost'" certbot
echo

echo "### Iniciando nginx ..."
docker-compose up --force-recreate -d nginx
echo

echo "### Deletando certificado dummy para $domains ..."
docker-compose run --rm --entrypoint "\
  rm -Rf /etc/letsencrypt/live/$domains && \
  rm -Rf /etc/letsencrypt/archive/$domains && \
  rm -Rf /etc/letsencrypt/renewal/$domains.conf" certbot
echo

echo "### Solicitando certificado Let's Encrypt para $domains ..."
# Junta $domains a argumentos -d
domain_args=""
for domain in "${domains[@]}"; do
  domain_args="$domain_args -d $domain"
done

# Seleciona o argumento de email apropriado
case "$email" in
  "") email_arg="--register-unsafely-without-email" ;;
  *) email_arg="--email $email" ;;
esac

# Habilita o modo de teste se necessário
if [ $staging != "0" ]; then staging_arg="--staging"; fi

docker-compose run --rm --entrypoint "\
  certbot certonly --webroot -w /var/www/certbot \
    $staging_arg \
    $email_arg \
    $domain_args \
    --rsa-key-size $rsa_key_size \
    --agree-tos \
    --force-renewal \
    --preferred-challenges http \
    --ipv4" certbot
echo

echo "### Recarregando nginx ..."
docker-compose exec nginx nginx -s reload
