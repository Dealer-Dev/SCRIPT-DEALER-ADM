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

apt install -y \
python3 \
python3-pip >/dev/null 2>&1

wget -q -O /tmp/dealer_requirements.txt \
https://raw.githubusercontent.com/Dealer-Dev/SCRIPT-DEALER-ADM/main/telegram/requirements.txt

python3 -m pip install --break-system-packages -r /tmp/dealer_requirements.txt

mkdir -p /etc/dealer-adm/bot

echo ""
echo "Descargando archivos..."

wget -q -O /etc/dealer-adm/bot/bot.py \
https://raw.githubusercontent.com/Dealer-Dev/SCRIPT-DEALER-ADM/main/telegram/bot.py

wget -q -O /etc/dealer-adm/bot/dealer_api.sh \
https://raw.githubusercontent.com/Dealer-Dev/SCRIPT-DEALER-ADM/main/telegram/dealer_api.sh

chmod +x /etc/dealer-adm/bot/dealer_api.sh

echo ""
echo "Configurando bot..."

sed -i "s|BOT_TOKEN = \"TOKEN_AQUI\"|BOT_TOKEN = \"$BOT_TOKEN\"|g" \
/etc/dealer-adm/bot/bot.py

sed -i "s|ADMIN_ID = 123456789|ADMIN_ID = $ADMIN_ID|g" \
/etc/dealer-adm/bot/bot.py

echo ""
echo "Creando servicio..."

cat > /etc/systemd/system/dealer-bot.service << EOF
[Unit]
Description=Dealer Adm Telegram Bot
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 /etc/dealer-adm/bot/bot.py
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

systemctl --no-pager status dealer-bot
