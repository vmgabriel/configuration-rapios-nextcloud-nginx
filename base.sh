echo "🔼 Actualizando Sistema"
sudo apt update && sudo apt upgrade -y

echo "📥 Instalando Emacs"
sudo apt-get install -y emacs-nox

echo "Instalar Tailscale"
curl -fsSL https://tailscale.com/install.sh | sudo bash
