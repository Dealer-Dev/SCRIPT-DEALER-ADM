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

python3 -m venv /etc/dealer-adm/bot/venv || {
echo "ERROR creando entorno virtual"
exit 1
}

wget -q -O /tmp/dealer_requirements.txt "https://raw.githubusercontent.com/Dealer-Dev/SCRIPT-DEALER-ADM/main/telegram/requirements.txt"

[ ! -f /tmp/dealer_requirements.txt ] && {
echo "ERROR descargando requirements.txt"
exit 1
}

/etc/dealer-adm/bot/venv/bin/pip install --upgrade pip >/dev/null 2>&1

/etc/dealer-adm/bot/venv/bin/pip install -r /tmp/dealer_requirements.txt || {
echo "ERROR instalando dependencias Python"
exit 1
}

echo ""
echo "Descargando archivos..."

wget -q -O /etc/dealer-adm/bot/bot.py "https://raw.githubusercontent.com/Dealer-Dev/SCRIPT-DEALER-ADM/main/telegram/bot.py"

wget -q -O /etc/dealer-adm/bot/dealer_api.sh "https://raw.githubusercontent.com/Dealer-Dev/SCRIPT-DEALER-ADM/main/telegram/dealer_api.sh"

[ ! -f /etc/dealer-adm/bot/bot.py ] && {
echo "ERROR descargando bot.py"
exit 1
}

[ ! -f /etc/dealer-adm/bot/dealer_api.sh ] && {
echo "ERROR descargando dealer_api.sh"
exit 1
}

chmod +x /etc/dealer-adm/bot/dealer_api.sh

echo ""
echo "Creando servicio..."

cat > /etc/systemd/system/dealer-bot.service << EOF
[Unit]
Description=Dealer Adm Telegram Bot
After=network.target

[Service]
Type=simple
Environment="BOT_TOKEN=$BOT_TOKEN"
Environment="ADMIN_ID=$ADMIN_ID"
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

sleep 3

echo ""
echo "=================================="
echo " BOT INSTALADO CORRECTAMENTE"
echo "=================================="
echo ""

echo "Archivos instalados:"
ls -lah /etc/dealer-adm/bot/

echo ""
systemctl --no-pager status dealer-bot
