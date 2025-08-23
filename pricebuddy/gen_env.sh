echo "Genering Variables in pricebuddy"

cat <<EOF > my.env
APP_USER_EMAIL: admin@example.com
APP_USER_PASSWORD: admin
MYSQL_PASSWORD: $(openssl rand -base64 12)
MYSQL_ROOT_PASSWORD: $(openssl rand -base64 12)
EOF
