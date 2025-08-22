echo "Run Nextcloud"
cd nextcloud
chmod +x gen_env.sh
sh ./gen_env.sh
docker compose up --build -d
cd ..

echo "Run Docmost"
cd docmost
chmod +x gen_env.sh
sh ./gen_env.sh
docker compose up --build -d
cd ..


echo "Run Readeck"
cd readeck
chmod +x gen_env.sh
sh ./gen_env.sh
docker compose up --build -d
cd ..

echo "Run komga"
cd komga
docker compose up --build -d
cd ..
