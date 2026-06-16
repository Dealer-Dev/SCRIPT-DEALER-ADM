#!/bin/bash

clear

echo ""
echo "=================================="
echo "      DEALER ADM TELEGRAM BOT"
echo "=================================="
echo ""

read -p "Token del Bot: " BOT_TOKEN
read -p "Admin ID: " ADMIN_ID

[ -z "$BOT_TOKEN" ] && exit 1
[ -z "$ADMIN_ID" ] && exit 1

echo ""
echo "Instalando dependencias..."

apt update -y >/dev/null 2>&1

apt install -y python3 python3-pip python3-venv wget >/dev/null 2>&1

mkdir -p /etc/dealer-adm/bot

rm -rf /etc/dealer-adm/bot/venv

python3 -m venv /etc/dealer-adm/bot/venv

wget -q -O /tmp/dealer_requirements.txt 
"https://raw.githubusercontent.com/Dealer-Dev/SCRIPT-DEALER-ADM/main/telegram/requirements.txt"

/etc/dealer-adm/bot/venv/bin/pip install --upgrade pip >/dev/null 2>&1
/etc/dealer-adm/bot/venv/bin/pip install -r /tmp/dealer_requirements.txt

echo ""
echo "Descargando archivos..."

wget -q -O /etc/dealer-adm/bot/bot.py 
"https://raw.githubusercontent.com/Dealer-Dev/SCRIPT-DEALER-ADM/main/telegram/bot.py"

wget -q -O /etc/dealer-adm/bot/dealer_api.sh 
"https://raw.githubusercontent.com/Dealer-Dev/SCRIPT-DEALER-ADM/main/telegram/dealer_api.sh"

chmod +x /etc/dealer-adm/bot/dealer_api.sh

echo ""
echo "Configurando bot..."

BOT_TOKEN_ENV="$BOT_TOKEN" ADMIN_ID_ENV="$ADMIN_ID" python3 << 'EOF'
from pathlib import Path
import os

ruta = Path("/etc/dealer-adm/bot/bot.py")

texto = ruta.read_text()

texto = texto.replace(
'BOT_TOKEN = "TOKEN_AQUI"',
f'BOT_TOKEN = "{os.environ["BOT_TOKEN_ENV"]}"'
)

texto = texto.replace(
'ADMIN_ID = 123456789',
f'ADMIN_ID = {os.environ["ADMIN_ID_ENV"]}'
)

ruta.write_text(texto)
EOF

echo ""
echo "Verificando configuracion..."

grep "BOT_TOKEN =" /etc/dealer-adm/bot/bot.py
grep "ADMIN_ID =" /etc/dealer-adm/bot/bot.py

echo ""
echo "Creando servicio..."

cat > /etc/systemd/system/dealer-bot.service << EOF
[Unit]
Description=Dealer Adm Telegram Bot
After=network.target

[Service]
Type=simple
ExecStart=/etc/dealer-adm/bot/venv/bin/python /etc/dealer-adm/bot/bot.py
WorkingDirectory=/etc/dealer-adm/bot
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable dealer-bot >/dev/null 2>&1
systemctl restart dealer-bot

echo ""
echo "=================================="
echo " BOT INSTALADO CORRECTAMENTE"
echo "=================================="
echo ""

sleep 2

systemctl --no-pager status dealer-bot
