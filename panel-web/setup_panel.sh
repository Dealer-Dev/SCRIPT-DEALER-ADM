#!/bin/bash
# =======================================================
# INSTALADOR AUTOMÁTICO PANEL WEB SINGLE VPS (PUERTO 81)
# =======================================================

if [ "$EUID" -ne 0 ]; then
    echo "❌ Por favor ejecuta este script como root."
    exit 1
fi

echo -e "\n=== 🚀 CONFIGURANDO SERVIDOR WEB Y PANEL ===\n"

# 1. Instalar Apache, PHP y MariaDB
echo "⏳ Instalando Apache, PHP y DB..."
apt update -y > /dev/null 2>&1
DEBIAN_FRONTEND=noninteractive apt install -y apache2 mariadb-server mariadb-client php libapache2-mod-php php-mysqli php-curl curl wget > /dev/null 2>&1

# 2. Configurar Apache en Puerto 81
echo "⏳ Configurando Apache en el puerto 81..."
sed -i 's/Listen 80/Listen 81/' /etc/apache2/ports.conf
sed -i 's/<VirtualHost \*:80>/<VirtualHost *:81>/' /etc/apache2/sites-available/000-default.conf

systemctl restart apache2 mariadb
systemctl enable apache2 mariadb

# 3. Datos y Credenciales de BD
DB_HOST="localhost"
DB_NAME="dealer_panel"
DB_USER="dealer_db_user"

DB_PASS=$(openssl rand -hex 12)
ADMIN_USER="admin_$(openssl rand -hex 3)"
ADMIN_PASS=$(openssl rand -base64 9 | tr -d '=+/' | cut -c1-12)

echo "⏳ Configurando Base de Datos..."

mysql <<EOF
CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$DB_USER'@'$DB_HOST' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'$DB_HOST';
FLUSH PRIVILEGES;

USE \`$DB_NAME\`;

-- Tabla de Usuarios
CREATE TABLE IF NOT EXISTS \`users\` (
  \`id\` INT AUTO_INCREMENT PRIMARY KEY,
  \`username\` VARCHAR(50) NOT NULL UNIQUE,
  \`password\` VARCHAR(255) NOT NULL,
  \`credits\` INT NOT NULL DEFAULT 0,
  \`role\` ENUM('admin', 'reseller') NOT NULL DEFAULT 'reseller'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Tabla de Cuentas creadas localmente
CREATE TABLE IF NOT EXISTS \`ssh_accounts\` (
  \`id\` INT AUTO_INCREMENT PRIMARY KEY,
  \`reseller\` VARCHAR(50) NOT NULL,
  \`username\` VARCHAR(100) NOT NULL,
  \`password\` VARCHAR(100) NOT NULL,
  \`type\` VARCHAR(20) NOT NULL,
  \`reference_name\` VARCHAR(100) DEFAULT NULL,
  \`expires\` DATE NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO \`users\` (\`username\`, \`password\`, \`credits\`, \`role\`) 
VALUES ('$ADMIN_USER', '$ADMIN_PASS', 9999, 'admin');
EOF

# 4. Descargar Frontend
WEB_DIR="/var/www/html"
echo "⏳ Descargando interfaz del Panel Web..."

rm -f $WEB_DIR/index.html

REPO_URL="https://raw.githubusercontent.com/Dealer-Dev/SCRIPT-DEALER-ADM/main/panel-web"
FILES=("admin.php" "login.php" "reseller.php" "mis_usuarios.php" "load_vps.php" "online.php" "logout.php" "logo.png")

for file in "${FILES[@]}"; do
    wget -q -O "$WEB_DIR/$file" "$REPO_URL/$file"
done

echo "<?php header('Location: login.php'); exit(); ?>" > "$WEB_DIR/index.php"

# 5. Generar db.php
cat > $WEB_DIR/db.php << EOF
<?php
\$host = "$DB_HOST";
\$user = "$DB_USER";
\$pass = "$DB_PASS";
\$db   = "$DB_NAME";

\$conn = new mysqli(\$host, \$user, \$pass, \$db);

if (\$conn->connect_error) {
    die("Error de conexión a la base de datos.");
}
?>
EOF

# Permisos para ejecutar comandos de sistema desde PHP (www-data)
chown -R www-data:www-data $WEB_DIR
chmod -R 755 $WEB_DIR

# Permitir a www-data usar useradd/usermod/userdel sin contraseña si usas comandos del sistema
echo "www-data ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/panel_web
chmod 0440 /etc/sudoers.d/panel_web

# Firewall
ufw allow 81/tcp > /dev/null 2>&1
iptables -I INPUT -p tcp --dport 81 -j ACCEPT 2>/dev/null

SERVER_IP=$(curl -s -4 ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')

echo -e "\n============================================="
echo -e " ¡PANEL WEB INSTALADO CORRECTAMENTE!"
echo -e "============================================="
echo -e " 🌐 URL Panel:  http://$SERVER_IP:81/login.php"
echo -e " 👤 Usuario:    \033[1;33m$ADMIN_USER\033[0m"
echo -e " 🔑 Contraseña: \033[1;32m$ADMIN_PASS\033[0m"
echo -e "=============================================\n"
