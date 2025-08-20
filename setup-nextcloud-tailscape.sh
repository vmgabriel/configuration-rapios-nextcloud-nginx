#!/bin/bash
# setup-nextcloud-tailscale.sh
# Instalación completa de Nextcloud + Nginx + Tailscale en Raspberry Pi OS
# Ejecutar con: sudo bash setup-nextcloud-tailscale.sh

IFS=$'\n\t'

echo "🚀 Iniciando instalación de Nextcloud con Tailscale y Nginx..."

# === 1. Actualizar sistema ===
echo "📦 Actualizando sistema..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl wget git ufw

# === 2. Instalar Docker ===
echo "🐳 Instalando Docker..."
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker pi

# === 3. Instalar Docker Compose (versión moderna) ===
echo "🔧 Instalando Docker Compose..."
DOCKER_CONFIG=${DOCKER_CONFIG:-$HOME/.docker}
mkdir -p $DOCKER_CONFIG/cli-plugins
curl -sSL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-aarch64 -o $DOCKER_CONFIG/cli-plugins/docker-compose
chmod +x $DOCKER_CONFIG/cli-plugins/docker-compose

# === 4. Crear directorios para Nextcloud ===
echo "📁 Creando directorios..."
sudo mkdir -p /opt/nextcloud/{data,config,apps,db,web}
sudo chown -R 1000:1000 /opt/nextcloud
sudo chmod -R 750 /opt/nextcloud

# Página de bienvenida
cat << EOF | sudo tee /opt/nextcloud/web/index.html
<h1>🏠 Mi Nube Local</h1>
<p>Accede a:</p>
<ul>
  <li><a href="/drive">📁 Nextcloud</a></li>
  <li><a href="/web">🌐 Página Web</a></li>
</ul>
<p>Protegido con <strong>Tailscale</strong> 🔐</p>
EOF

# === 5. Crear proyecto Docker ===
mkdir -p /home/pi/nextcloud
cd /home/pi/nextcloud

# === 6. Crear .env ===
cat << EOF > .env
MYSQL_ROOT_PASSWORD=$(openssl rand -base64 12)
MYSQL_PASSWORD=$(openssl rand -base64 12)
NEXTCLOUD_ADMIN_USER=admin
NEXTCLOUD_ADMIN_PASSWORD=$(openssl rand -base64 8 | tr -d "=+/")
EOF

echo "🔐 Contraseñas generadas en .env (¡guárdalas!)"

# === 7. Crear docker-compose.yml ===
cat << 'EOF' > docker-compose.yml
services:
  db:
    image: lscr.io/linuxserver/mariadb:latest
    platform: linux/arm64
    restart: always
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Etc/UTC
      - MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
      - MYSQL_DATABASE=nextcloud
      - MYSQL_USER=nextcloud
      - MYSQL_PASSWORD=${MYSQL_PASSWORD}
      - CUSTOM_MARIADB_OPTS=--binlog-format=ROW --character-set-server=utf8mb4 --collation-server=utf8mb4_unicode_ci --innodb-large-prefix=1 --innodb-file-format=Barracuda
    volumes:
      - /opt/nextcloud/db:/config
    env_file:
      - .env

  nextcloud:
    image: lscr.io/linuxserver/nextcloud:latest
    platform: linux/arm64
    restart: always
    volumes:
      - /opt/nextcloud/data:/var/www/html
      - /opt/nextcloud/config:/var/www/html/config
      - /opt/nextcloud/apps:/var/www/html/custom_apps
      - ./init-nextcloud.sh:/init-nextcloud.sh:ro
    environment:
      - MYSQL_HOST=db
      - MYSQL_DATABASE=nextcloud
      - MYSQL_USER=nextcloud
      - MYSQL_PASSWORD=${MYSQL_PASSWORD}
      - NEXTCLOUD_TRUSTED_DOMAINS=pi.ojos-morpho.ts.net
      - OVERWRITEPROTOCOL=https
    depends_on:
      - db
    command: >
      /bin/sh -c "
      /init-nextcloud.sh &
      /init
      "

  nginx:
    image: nginx:alpine
    platform: linux/arm64
    restart: always
    ports:
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - /opt/nextcloud/web:/usr/share/nginx/html/web
    depends_on:
      - nextcloud
    command: /bin/sh -c "nginx -g 'daemon off;' || (sleep 5 && nginx -g 'daemon off;')"

EOF

# === 8. Crear nginx.conf ===
cat << 'EOF' > nginx.conf
events {
    worker_connections 1024;
}

http {
    client_max_body_size 10G;
    client_body_buffer_size 128k;

    # Habilitar sub_filter
    sub_filter_once off;
    sub_filter_types *;

    server {
        listen 80;
        server_name pi.ojos-morpho.ts.net;

        # === /drive → Nextcloud ===
        location /drive/ {
            proxy_pass http://nextcloud:80/;

            # Encabezados esenciales
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
	    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;

            # Desactivar buffering para WebDAV
            proxy_buffering off;
            proxy_request_buffering off;

            # Timeouts
            client_max_body_size 0;
            proxy_read_timeout 3600s;
            proxy_send_timeout 3600s;

            # Upgrade para WebSockets
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";

            # Reemplazar URLs en la respuesta
            sub_filter 'href="/' 'href="/drive/';
            sub_filter 'src="/' 'src="/drive/';
            sub_filter 'action="/' 'action="/drive/';
            sub_filter 'url("/' 'url("/drive/';
            sub_filter '"/remote.php' '"/drive/remote.php';
            sub_filter '" /status.php' '" /drive/status.php';
        }

        # === /web → Página estática ===
        location /web/ {
            alias /usr/share/nginx/html/web/;
            index index.html;
            try_files $uri $uri/ =404;
        }

        # Redirigir raíz a /web (opcional)
        location = / {
            return 302 /web/;
        }
    }
}

EOF

# === 8.--- Configuration NextCloud Wildcard
echo "Configurando nextcloud con wildcard ..."
cat <<'EEOF' > init_nextcloud.sh
#!/bin/bash
# init-nextcloud.sh
# Configura Nextcloud para funcionar detrás de Nginx en /drive

set -euo pipefail

echo "🔧 Inicializando configuración de Nextcloud..."

# Ruta dentro del contenedor
CONFIG_DIR="/config/www/nextcloud/config"
CONFIG_FILE="$CONFIG_DIR/config.php"
HTACCESS_FILE="/app/www/public/.htaccess"

# Esperar a que el archivo config.php exista
while [ ! -f "$CONFIG_FILE" ]; do
  echo "⏳ Esperando a que config.php se cree..."
  sleep 5
done

# Hacer copia de seguridad
if [ ! -f "$CONFIG_FILE.bak" ]; then
  cp "$CONFIG_FILE" "$CONFIG_FILE.bak"
  echo "✅ Copia de seguridad creada: $CONFIG_FILE.bak"
fi

# Editar config.php
echo "📝 Actualizando config.php..."

# Asegurarse de que las líneas estén presentes
sudo -u abc php << 'EOF'
<?php
$configFile = '$CONFIG_FILE';
$config = include($configFile);

// Configuraciones clave
$config['overwrite.cli.url'] = 'https://pi.ojos-morpho.ts.net/drive';
$config['htaccess.RewriteBase'] = '/drive';
$config['trusted_proxies'] = ['172.18.0.0/16'];
$config['reverse_proxy'] = true;
$config['reverse_proxy_headers'] = ['HTTP_X_FORWARDED_PROTO' => 'https'];

// Escribir de vuelta
file_put_contents($configFile, "<?php\n\$CONFIG = " . var_export($config, true) . ";\n");

echo "✅ config.php actualizado\n";
EOF

# Regenerar .htaccess
echo "🔄 Regenerando .htaccess..."
cd /app/www/public || exit 1
php occ maintenance:update:htaccess
echo "✅ .htaccess regenerado"

echo "✅ Configuración de Nextcloud completada"

EEOF

# === 9. Instalar Tailscale ===
echo "🔐 Instalando Tailscale..."
curl -fsSL https://tailscale.com/install.sh | sh

# === 10. Informar al usuario ===
cat << 'EOF'
🎉 ¡Instalación básica completada!

➡️ Siguiente paso: Iniciar Tailscale
Ejecuta:
  sudo tailscale up

Luego accede desde cualquier dispositivo a:
  https://tupi.tailscale.net/drive

🔐 Tus credenciales de administrador:
EOF

echo "Usuario: $(grep NEXTCLOUD_ADMIN_USER .env | cut -d'=' -f2)"
echo "Contraseña: $(grep NEXTCLOUD_ADMIN_PASSWORD .env | cut -d'=' -f2)"

cat << 'EOF'

📁 Datos almacenados en: /opt/nextcloud/
📄 Configuración en: /home/pi/nextcloud/

💡 Recuerda:
  - Guardar las contraseñas del archivo .env
  - Conectar todos tus dispositivos a Tailscale
  - Acceder solo desde la red Tailscale

¡Tu nube local está lista! 🚀
EOF
