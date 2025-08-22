echo "Genering Variables in Nextcloud"

cat <<EOF > .env
MYSQL_ROOT_PASSWORD=$(openssl rand -base64 12)
MYSQL_DATABASE=nextcloud
MYSQL_USER=nextcloud
MYSQL_PASSWORD=$(openssl rand -base64 12)

EOF
