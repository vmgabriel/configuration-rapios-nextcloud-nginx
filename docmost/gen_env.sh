echo "Genering Variables in DocMost"

cat <<EOF > .env
POSTGRES_USER=docmost
POSTGRES_PASSWORD=$(openssl rand -base64 20)
APP_SECRET=$(openssl rand -base64 20)
EOF
