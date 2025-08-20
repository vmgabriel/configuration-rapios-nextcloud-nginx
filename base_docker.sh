echo "⏏️  1. Actualizar sistema"
sudo apt update && sudo apt upgrade -y

echo "🔁 2. Instalar dependencias"
sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release

echo "🔻 3. Añadir la clave GPG oficial de Docker"
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo "💠 4. Añadir el repositorio de Docker (usamos 'bullseye' o 'bookworm' según tu versión)"
echo "deb [arch=arm64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(. /etc/os-release && echo $VERSION_CODENAME) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "🔻 5. Actualizar apt"
sudo apt update

echo "❗ 6. Instalar Docker Engine"
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "Add User"
sudo usermod -aG docker $USER
