echo "Genering Variables in Readeck"

cat <<EOF > .env
POSTGRES_PASSWORD=$(openssl rand -base64 14)
EOF
