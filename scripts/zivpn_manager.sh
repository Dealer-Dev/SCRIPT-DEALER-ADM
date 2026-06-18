CONFIG_FILE="/etc/zivpn/config.json"
DB_FILE="/etc/zivpn/passwords.db"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
ORANGE='\033[38;5;208m'
WHITE='\033[1;37m'
RESET='\033[0m'
BRED='\033[1;31m'

generar_password() {
    head /dev/urandom | tr -dc A-Za-z0-9 | head -c 8
}

# Verificar expiraciones
verificar_expiraciones() {
    today=$(date +%Y-%m-%d)
    while IFS="|" read -r pass exp status; do
        if [[ "$status" == "active" && "$exp" < "$today" ]]; then
            # Marcar como inactiva en DB
            sed -i "s|^$pass|$pass|;s|active|inactive|" "$DB_FILE"
            # Quitar del config.json
            jq --arg pass "$pass" '.auth.config -= [$pass]' "$CONFIG_FILE" > tmp.$$.json && mv tmp.$$.json "$CONFIG_FILE"
            echo -e "${YELLOW}⚠ Contraseña expirada y desactivada automáticamente:${NC} $pass"
        fi
    done < "$DB_FILE"
}

# Listar contraseñas con fecha de expiración y días restantes
listar_passwords() {
    echo -e "\n${CYAN}	=== Lista de contraseñas ===${NC}"
    if [[ ! -s "$DB_FILE" ]]; then
        echo -e "${YELLOW}No hay contraseñas registradas.${NC}"
        return
    fi

    printf "  %-5s %-15s %-12s %-15s %-10s\n" "N°" "Contraseña" "Expira" "Días restantes" "Estado"
    echo " -----------------------------------------------------------------"

    num=1
    while IFS="|" read -r pass exp status; do
        today=$(date +%Y-%m-%d)
        dleft=$(( ( $(date -d "$exp" +%s) - $(date -d "$today" +%s) ) / 86400 ))

        if [[ "$dleft" -lt 0 ]]; then
            dleft=0
            status="expired"
        fi

        printf "  %-5s %-15s %-12s %-15s %-10s\n" "$num" "$pass" "$exp" "$dleft días" "$status"
        ((num++))
		echo 
		echo
    done < "$DB_FILE"
}
# Agregar contraseña manual o aleatoria
agregar_password() {
    if [[ "$1" == "random" ]]; then
        pass=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 8)
        echo -e "${YELLOW}Se generó contraseña aleatoria:${NC} $pass"
    else
        read -p "Ingrese la nueva contraseña: " pass
    fi

    # Validar duración en días (solo números, entre 1 y 365)
    while true; do
        read -p "Duración en días (1-365): " dias
        if [[ "$dias" =~ ^[0-9]+$ && "$dias" -ge 1 && "$dias" -le 365 ]]; then
            break
        else
            echo -e "${RED}✘ Ingrese un número válido entre 1 y 365.${NC}"
        fi
    done

    exp=$(date -d "+$dias days" +%Y-%m-%d)

    # Guardar en DB
    echo "$pass|$exp|active" >> "$DB_FILE"

    # Agregar al JSON
    jq --arg pass "$pass" '.auth.config += [$pass]' "$CONFIG_FILE" > tmp.$$.json && mv tmp.$$.json "$CONFIG_FILE"

    echo -e "${GREEN}✔ Contraseña añadida:${NC} $pass (expira el $exp)"
	systemctl restart udp-custom.service 2>/dev/null
	systemctl restart zivpn.service 2>/dev/null
}

# Desactivar contraseña
desactivar_password() {
[[ ! -f "$DB_FILE" ]] && {
        echo -e "${RED}Base de datos no encontrada.${NC}"
        return
    }
    listar_passwords
    read -p "Ingrese el número de la contraseña a desactivar: " num
    pass=$(awk -F"|" -v n="$num" 'NR==n {print $1}' "$DB_FILE")

    if [[ -z "$pass" ]]; then
        echo -e "${RED}✘ Número inválido.${NC}"
        return
    fi

    # Marcar como inactiva en DB
    sed -i "${num}s/active/inactive/" "$DB_FILE"

    # Remover de config.json
    jq --arg pass "$pass" '.auth.config -= [$pass]' "$CONFIG_FILE" > tmp.$$.json && mv tmp.$$.json "$CONFIG_FILE"

    echo -e "${GREEN}✔ Contraseña desactivada:${NC} $pass"
	systemctl restart udp-custom.service 2>/dev/null
	systemctl restart zivpn.service 2>/dev/null
}

# Activar contraseña
activar_password() {
[[ ! -f "$DB_FILE" ]] && {
        echo -e "${RED}Base de datos no encontrada.${NC}"
        return
    }
    listar_passwords
    read -p "Ingrese el número de la contraseña a activar: " num
    pass=$(awk -F"|" -v n="$num" 'NR==n {print $1}' "$DB_FILE")
    exp=$(awk -F"|" -v n="$num" 'NR==n {print $2}' "$DB_FILE")

    if [[ -z "$pass" ]]; then
        echo -e "${RED}✘ Número inválido.${NC}"
        return
    fi

    today=$(date +%Y-%m-%d)
    if [[ "$exp" < "$today" ]]; then
        echo -e "${RED}✘ No se puede activar, la contraseña ya expiró (${exp}).${NC}"
        return
    fi

    # Marcar como activa en DB
    sed -i "${num}s/inactive/active/" "$DB_FILE"

    # Agregar a config.json
    jq --arg pass "$pass" '.auth.config += [$pass]' "$CONFIG_FILE" > tmp.$$.json && mv tmp.$$.json "$CONFIG_FILE"

    echo -e "${GREEN}✔ Contraseña activada:${NC} $pass"
	systemctl restart udp-custom.service 2>/dev/null
	systemctl restart zivpn.service 2>/dev/null
}
# Eliminar completamente una contraseña
eliminar_password() {
[[ ! -f "$DB_FILE" ]] && {
        echo -e "${RED}Base de datos no encontrada.${NC}"
        return
    }
listar_passwords
read -p "Ingrese el número de la contraseña a eliminar: " num
    pass=$(awk -F"|" -v n="$num" 'NR==n {print $1}' "$DB_FILE")

    if [[ -z "$pass" ]]; then
        echo -e "${RED}✘ Número inválido.${NC}"
        return
    fi

    # Quitar del DB (borrar línea)
    sed -i "${num}d" "$DB_FILE"

    # Quitar del config.json por si sigue activa
    jq --arg pass "$pass" '.auth.config -= [$pass]' "$CONFIG_FILE" > tmp.$$.json && mv tmp.$$.json "$CONFIG_FILE"

    echo -e "${GREEN}✔ Contraseña eliminada completamente:${NC} $pass"
	systemctl restart udp-custom.service 2>/dev/null
	systemctl restart zivpn.service 2>/dev/null
}

# Editar duración (fecha de expiración) de una contraseña
editar_duracion() {
[[ ! -f "$DB_FILE" ]] && {
        echo -e "${RED}Base de datos no encontrada.${NC}"
        return
    }
    listar_passwords
    read -p "Ingrese el número de la contraseña a editar: " num
    pass=$(awk -F"|" -v n="$num" 'NR==n {print $1}' "$DB_FILE")

    if [[ -z "$pass" ]]; then
        echo -e "${RED}✘ Número inválido.${NC}"
        return
    fi

    # Validar nueva duración
    while true; do
        read -p "Nueva duración en días (1-365): " dias
        if [[ "$dias" =~ ^[0-9]+$ && "$dias" -ge 1 && "$dias" -le 365 ]]; then
            break
        else
            echo -e "${RED}✘ Ingrese un número válido entre 1 y 365.${NC}"
        fi
    done

    new_exp=$(date -d "+$dias days" +%Y-%m-%d)

    # Reemplazar la fecha en el archivo DB
    awk -F"|" -v n="$num" -v new_exp="$new_exp" 'BEGIN{OFS="|"} NR==n {$2=new_exp} {print}' "$DB_FILE" > tmp.$$.db && mv tmp.$$.db "$DB_FILE"

    echo -e "${GREEN}✔ Duración actualizada:${NC} $pass ahora expira el $new_exp"
	systemctl restart udp-custom.service 2>/dev/null
	systemctl restart zivpn.service 2>/dev/null
}

remover_servicio() {
    echo -e "${RED}⚠ ATENCIÓN:${NC} Esto eliminará ZiVPN del sistema."
    read -p "¿Está seguro que desea continuar? (s/n): " confirmacion

    if [[ "$confirmacion" != "s" && "$confirmacion" != "S" ]]; then
        echo -e "${YELLOW}Operación cancelada.${NC}"
        return
    fi

    echo -e "${YELLOW}Desinstalando ZiVPN...${NC}"

    systemctl stop zivpn.service 1>/dev/null 2>/dev/null
    systemctl stop zivpn_backfill.service 1>/dev/null 2>/dev/null
    systemctl disable zivpn.service 1>/dev/null 2>/dev/null
    systemctl disable zivpn_backfill.service 1>/dev/null 2>/dev/null

    rm -f /etc/systemd/system/zivpn.service 1>/dev/null 2>/dev/null
    rm -f /etc/systemd/system/zivpn_backfill.service 1>/dev/null 2>/dev/null

    killall zivpn 1>/dev/null 2>/dev/null

    rm -rf /etc/zivpn 1>/dev/null 2>/dev/null
    rm -f /usr/local/bin/zivpn 1>/dev/null 2>/dev/null

    if pgrep "zivpn" >/dev/null; then
        echo -e "${RED}✘ El servidor sigue en ejecución.${NC}"
    else
        echo -e "${GREEN}✔ El servidor está detenido.${NC}"
    fi

    if [[ -e "/usr/local/bin/zivpn" ]]; then
        echo -e "${RED}✘ Archivos residuales detectados, intente nuevamente.${NC}"
    else
        echo -e "${GREEN}✔ ZiVPN eliminado correctamente.${NC}"
    fi

    echo -e "${YELLOW}Limpiando caché y swap...${NC}"
    echo 3 > /proc/sys/vm/drop_caches
    sysctl -w vm.drop_caches=3 >/dev/null 2>&1
    swapoff -a && swapon -a
	systemctl restart udp-custom.service 2>/dev/null
    echo -e "${GREEN}✔ Limpieza completada.${NC}"
}
estado_servicio() {
    if systemctl is-active --quiet zivpn.service; then
        echo -e " ${GREEN}Estado: Activo${NC}"
    elif systemctl is-failed --quiet zivpn.service; then
        echo -e " ${RED}Estado: Fallido${NC}"
    else
        echo -e " ${YELLOW}Estado: Inactivo/Detenido${NC}"
    fi
}
reiniciar_servicio() {
    echo -e "${YELLOW}Reiniciando ZiVPN...${NC}"
    systemctl restart zivpn.service 2>/dev/null
    systemctl restart zivpn_backfill.service 2>/dev/null
	systemctl restart udp-custom.service 2>/dev/null
    sleep 1
    if systemctl is-active --quiet zivpn.service; then
        echo -e "${GREEN}✔ ZiVPN se reinició correctamente.${NC}"
    else
        echo -e "${RED}✘ Error: ZiVPN no se pudo reiniciar.${NC}"
    fi
}

instalar_servicio () {
	ARCH=$(uname -m)
case "$ARCH" in
    "x86_64"|"amd64")
        BINARY_URL="https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-amd64"
        ARCH_NAME="AMD64"
        ;;
    "aarch64"|"arm64")
        BINARY_URL="https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-arm64"
        ARCH_NAME="ARM64"
        ;;
    *)
        echo -e "${RED}[ERROR] Arquitectura no soportada: $ARCH${NC}" 1>&2
        exit 1
        ;;
esac

echo -e "${GREEN}=== Instalador ZIVPN UDP para $ARCH_NAME ===${NC}"
systemctl stop udp-custom
systemctl stop zivpn.service 1> /dev/null 2> /dev/null
echo -e "${YELLOW}Descargando servicio UDP para $ARCH_NAME...${NC}"
wget "$BINARY_URL" -O /usr/local/bin/zivpn 1> /dev/null 2> /dev/null
if [ $? -ne 0 ]; then
    echo -e "${RED}Error al descargar el binario para $ARCH_NAME${NC}" 1>&2
    exit 1
fi

chmod +x /usr/local/bin/zivpn
mkdir -p /etc/zivpn 1> /dev/null 2> /dev/null
touch /etc/zivpn/passwords.db
wget https://raw.githubusercontent.com/zahidbd2/udp-zivpn/main/config.json -O /etc/zivpn/config.json 1> /dev/null 2> /dev/null

echo -e "${YELLOW}Generando certificados SSL...${NC}"
openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 \
    -subj "/C=US/ST=California/L=Los Angeles/O=Example Corp/OU=IT Department/CN=zivpn" \
    -keyout "/etc/zivpn/zivpn.key" -out "/etc/zivpn/zivpn.crt"

# Optimización de red
sysctl -w net.core.rmem_max=16777216 1> /dev/null 2> /dev/null
sysctl -w net.core.wmem_max=16777216 1> /dev/null 2> /dev/null

# Creación del servicio systemd
cat <<EOF > /etc/systemd/system/zivpn.service
[Unit]
Description=zivpn VPN Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/etc/zivpn
ExecStart=/usr/local/bin/zivpn server -c /etc/zivpn/config.json
Restart=always
RestartSec=3
Environment=ZIVPN_LOG_LEVEL=info
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF

# Generación de contraseña aleatoria
echo -e "${YELLOW}Generando contraseña aleatoria para ZIVPN UDP...${NC}"
sleep 2
RANDOM_PASS=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 8)
config=("$RANDOM_PASS")
new_config_str="\"config\": [$(printf "\"%s\"," "${config[@]}" | sed 's/,$//')]"
sed -i -E "s/\"config\": ?\[[[:space:]]*\"zi\"[[:space:]]*\]/${new_config_str}/g" /etc/zivpn/config.json

# Habilitar e iniciar el servicio
systemctl daemon-reload
systemctl enable zivpn.service
systemctl start zivpn.service
systemctl restart udp-custom.service 2>/dev/null
systemctl restart zivpn.service 2>/dev/null

# Configuración de iptables
DEFAULT_IFACE=$(ip -4 route ls | awk '/default/ {print $5; exit}')

# Eliminar regla anterior si existe
iptables -t nat -D PREROUTING -i "$DEFAULT_IFACE" -p udp --dport 6000:19999 -j DNAT --to-destination :5667 2>/dev/null

# Insertar ZiVPN con prioridad alta
iptables -t nat -I PREROUTING 2 -i "$DEFAULT_IFACE" -p udp --dport 6000:19999 -j DNAT --to-destination :5667

# Abrir puertos si UFW está instalado
if command -v ufw >/dev/null 2>&1; then
    ufw allow 6000:19999/udp >/dev/null 2>&1
    ufw allow 5667/udp >/dev/null 2>&1
fi

#Instalar JQ para gestion en base de datos
apt-get install -y jq > /dev/null 2>&1

# Limpieza final
rm -f zi.* 1> /dev/null 2> /dev/null

EXPIRE_SCRIPT="/usr/local/bin/zivpn-expire.sh"

echo -e "\e[33mInstalando verificador de expiraciones de ZiVPN...\e[0m"
sleep 2

# Crear script
cat > "$EXPIRE_SCRIPT" <<'EOF'
#!/bin/bash
CONFIG_FILE="/etc/zivpn/config.json"
DB_FILE="/etc/zivpn/passwords.db"
LOG_FILE="/var/log/zivpn-expire.log"

today=$(date +%Y-%m-%d)
[[ ! -f "$DB_FILE" ]] && exit 0

changed=0

while IFS="|" read -r pass exp status; do
    if [[ "$status" == "active" && "$exp" < "$today" ]]; then
        sed -i "s|^$pass|$pass|;s|active|inactive|" "$DB_FILE"
        jq --arg pass "$pass" '.auth.config -= [$pass]' "$CONFIG_FILE" > tmp.$$.json && mv tmp.$$.json "$CONFIG_FILE"
        echo "$(date) - Contraseña expirada y desactivada: $pass" >> "$LOG_FILE"
        changed=1
    fi
done < "$DB_FILE"

if [[ $changed -eq 1 ]]; then
    systemctl restart zivpn.service
    echo "$(date) - Servicio reiniciado por expiración de usuarios" >> "$LOG_FILE"
fi
EOF

chmod +x "$EXPIRE_SCRIPT"

# Configurar cron (cada hora)
(crontab -l 2>/dev/null; echo "0 * * * * $EXPIRE_SCRIPT") | crontab -
echo -e "${GREEN}=== Instalación completada con éxito! ===${NC}"
echo -e "${YELLOW}Contraseña generada automáticamente: ${GREEN}$RANDOM_PASS${NC}"
echo -e "${YELLOW}Puertos habilitados: ${GREEN}UDP 6000-19999 y 5667${NC}"
echo -e "${YELLOW}Arquitectura detectada: ${GREEN}$ARCH_NAME${NC}"
echo -e "\e[32m✔ Los usuarios expirados se eliminan en cada hora. \e[0m"
}

