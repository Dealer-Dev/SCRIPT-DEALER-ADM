#!/bin/bash
# =======================================================
# INSTALADOR AUTOMÁTICO DEL PANEL WEB DEALER
# =======================================================

if [ "$EUID" -ne 0 ]; then
    echo "❌ Por favor ejecuta este script como root."
    exit 1
fi

echo -e "\n===  CONFIGURANDO PANEL WEB AUTOMÁTICAMENTE ===\n"

# 1. Asegurar instalación de MariaDB/MySQL
if ! command -v mysql &> /dev/null; then
    echo "⏳ Instalando servidor de Base de Datos (DealerDB)..."
    apt update -y > /dev/null 2>&1
    DEBIAN_FRONTEND=noninteractive apt install -y mariadb-server mariadb-client php-mysqli > /dev/null 2>&1
    systemctl start mariadb
    systemctl enable mariadb
fi

# 2. Configuración Interna Automática
DB_HOST="localhost"
DB_NAME="dealer_panel"
DB_USER="dealer_db_user"

# Generar contraseña segura y aleatoria para la base de datos
DB_PASS=$(openssl rand -hex 12)

# Generar credenciales aleatorias para el Login del Admin
ADMIN_USER="admin_$(openssl rand -hex 3)"
ADMIN_PASS=$(openssl rand -base64 9 | tr -d '=+/' | cut -c1-12)

echo "⏳ Creando base de datos y tablas..."

# 3. Ejecución directa en MySQL usando el socket local de root
mysql <<EOF
-- Crear Base de Datos
CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Crear Usuario de BD interno y asignarle permisos
CREATE USER IF NOT EXISTS '$DB_USER'@'$DB_HOST' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'$DB_HOST';
FLUSH PRIVILEGES;

USE \`$DB_NAME\`;

-- Tabla de Usuarios
CREATE TABLE IF NOT EXISTS \`users\` (
  \`id\` INT AUTO_INCREMENT PRIMARY KEY,
  \`username\` VARCHAR(50) NOT NULL UNIQUE,
  \`password\` VARCHAR(255) NOT NULL,
  \`role\` ENUM('admin', 'reseller') NOT NULL DEFAULT 'reseller'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Tabla de Servidores VPS
CREATE TABLE IF NOT EXISTS \`vps\` (
  \`id\` INT AUTO_INCREMENT PRIMARY KEY,
  \`name\` VARCHAR(100) NOT NULL,
  \`ip\` VARCHAR(255) NOT NULL,
  \`token\` VARCHAR(255) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Tabla de Créditos por VPS
CREATE TABLE IF NOT EXISTS \`reseller_vps\` (
  \`id\` INT AUTO_INCREMENT PRIMARY KEY,
  \`reseller_id\` INT NOT NULL,
  \`vps_id\` INT NOT NULL,
  \`credits\` INT NOT NULL DEFAULT 0,
  FOREIGN KEY (\`reseller_id\`) REFERENCES \`users\`(\`id\`) ON DELETE CASCADE,
  FOREIGN KEY (\`vps_id\`) REFERENCES \`vps\`(\`id\`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Tabla de Cuentas (SSH, Token, HWID)
CREATE TABLE IF NOT EXISTS \`ssh_accounts\` (
  \`id\` INT AUTO_INCREMENT PRIMARY KEY,
  \`reseller\` VARCHAR(50) NOT NULL,
  \`username\` VARCHAR(100) NOT NULL,
  \`password\` VARCHAR(100) NOT NULL,
  \`type\` VARCHAR(20) NOT NULL,
  \`reference_name\` VARCHAR(100) DEFAULT NULL,
  \`expires\` DATE NOT NULL,
  \`vps_id\` INT NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Registrar el Administrador
INSERT INTO \`users\` (\`username\`, \`password\`, \`role\`) 
VALUES ('$ADMIN_USER', '$ADMIN_PASS', 'admin');
EOF

if [ $? -eq 0 ]; then
    # 4. Generar db.php automático
    cat > db.php << EOF
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

    SERVER_IP=$(curl -s -4 ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')

    echo -e "\n============================================="
    echo -e " ¡PANEL WEB CONFIGURADO CORRECTAMENTE!"
    echo -e "============================================="
    echo -e " 🌐 URL Panel:  http://$SERVER_IP/login.php"
    echo -e " 👤 Usuario:    \033[1;33m$ADMIN_USER\033[0m"
    echo -e " 🔑 Contraseña: \033[1;32m$ADMIN_PASS\033[0m"
    echo -e "=============================================\n"
    echo "⚠️  Guarda estas credenciales para acceder al panel."
else
    echo -e "\n❌ Ocurrió un error al configurar la base de datos."
fi
