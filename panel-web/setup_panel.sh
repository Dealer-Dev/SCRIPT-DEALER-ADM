#!/bin/bash
# =======================================================
# INSTALADOR AUTOMÁTICO PANEL WEB SINGLE VPS (PUERTO 81)
# =======================================================

if [ "$EUID" -ne 0 ]; then
    echo "❌ Por favor ejecuta este script como root."
    exit 1
fi

echo -e "\n===  CONFIGURANDO SERVIDOR WEB Y PANEL ===\n"

# 1. Instalar Apache, PHP y MariaDB
echo " Instalando Apache, PHP y MariaDB...⏳"
apt update -y > /dev/null 2>&1
DEBIAN_FRONTEND=noninteractive apt install -y apache2 mariadb-server mariadb-client php libapache2-mod-php php-mysqli php-curl curl wget > /dev/null 2>&1

# 2. Configurar Apache en Puerto 81
echo " Configurando Apache en el puerto...⏳"
sed -i 's/Listen 80/Listen 81/' /etc/apache2/ports.conf
sed -i 's/<VirtualHost \*:80>/<VirtualHost *:81>/' /etc/apache2/sites-available/000-default.conf

systemctl restart apache2 mariadb
systemctl enable apache2 mariadb

# 3. Credenciales de BD y Admin (Sin caracteres especiales '!')
DB_HOST="localhost"
DB_NAME="dealer_panel"
DB_USER="dealer_db_user"

DB_PASS=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
ADMIN_USER="admin_$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 6 | head -n 1)"
ADMIN_PASS=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 12 | head -n 1)

echo "⏳ Configurando Base de Datos..."

mysql -e "CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -e "CREATE USER IF NOT EXISTS '$DB_USER'@'$DB_HOST' IDENTIFIED BY '$DB_PASS';"
mysql -e "ALTER USER '$DB_USER'@'$DB_HOST' IDENTIFIED BY '$DB_PASS';"
mysql -e "GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'$DB_HOST';"
mysql -e "FLUSH PRIVILEGES;"

mysql -D "$DB_NAME" <<EOF
CREATE TABLE IF NOT EXISTS \`users\` (
  \`id\` INT AUTO_INCREMENT PRIMARY KEY,
  \`username\` VARCHAR(50) NOT NULL UNIQUE,
  \`password\` VARCHAR(255) NOT NULL,
  \`credits\` INT NOT NULL DEFAULT 0,
  \`role\` ENUM('admin', 'reseller') NOT NULL DEFAULT 'reseller'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

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
echo "Descargando interfaz del Panel Web..."

rm -f $WEB_DIR/index.html

REPO_URL="https://raw.githubusercontent.com/Dealer-Dev/SCRIPT-DEALER-ADM/main/panel-web"
FILES=("admin.php" "login.php" "reseller.php" "mis_usuarios.php" "load_vps.php" "online.php" "logout.php" "logo.png")

for file in "${FILES[@]}"; do
    wget -q -O "$WEB_DIR/$file" "$REPO_URL/$file"
done

echo "<?php header('Location: login.php'); exit(); ?>" > "$WEB_DIR/index.php"

# 5. Generar db.php
cat << EOF > $WEB_DIR/db.php
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

# Permisos
chown -R www-data:www-data $WEB_DIR
chmod -R 755 $WEB_DIR

# Permisos sudo para www-data
mkdir -p /etc/dealer-adm/userDIR
echo "www-data ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/panel_web
chmod 0440 /etc/sudoers.d/panel_web

# Firewall
ufw allow 81/tcp > /dev/null 2>&1
iptables -I INPUT -p tcp --dport 81 -j ACCEPT 2>/dev/null

SERVER_IP=$(curl -s -4 ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')

echo -e "\n============================================="
echo -e "      PANEL WEB INSTALADO CORRECTAMENTE"
echo -e "============================================="
echo -e "  URL Panel:  http://$SERVER_IP:81/"
echo -e "  Usuario:    \033[1;33m$ADMIN_USER\033[0m"
echo -e "  Contraseña: \033[1;32m$ADMIN_PASS\033[0m"
echo -e "============================================="
echo -e "            SCRIPT DEALER ADM"
echo -e "=============================================\n"
