#!/bin/bash
# ═══════════════════════════════════════════════════════
#   ZIVPN MANAGER — Módulo de Gestión (Usuario:Contraseña)
#   Formato unificado estilo UDP Hysteria Mod
# ═══════════════════════════════════════════════════════

CONFIG_FILE="/etc/zivpn/config.json"
DB_FILE="/etc/zivpn/passwords.db"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
ORANGE='\033[1;92m'
WHITE='\033[1;37m'
RESET='\033[0m'
BRED='\033[1;31m'

generar_password() {
    head /dev/urandom | tr -dc A-Za-z0-9 | head -c 8
}

# Regenerar el JSON basado únicamente en usuarios activos en la DB
rebuild_zivpn_json() {
    [[ ! -f "$DB_FILE" ]] && return
    [[ ! -f "$CONFIG_FILE" ]] && return

    # Vaciar el array del config.json de forma segura antes de reconstruir
    jq '.auth.config = []' "$CONFIG_FILE" > /tmp/tmp_ziv.json && mv /tmp/tmp_ziv.json "$CONFIG_FILE"

    # Leer la DB e inyectar en formato estricto 'usuario:contraseña'
    while IFS="|" read -r user pass exp status; do
        if [[ "$status" == "active" && -n "$user" && -n "$pass" ]]; then
            jq --arg account "$user:$pass" '.auth.config += [$account]' "$CONFIG_FILE" > /tmp/tmp_ziv.json && mv /tmp/tmp_ziv.json "$CONFIG_FILE"
        fi
    done < "$DB_FILE"

    systemctl restart zivpn.service 2>/dev/null
}

# Alias para compatibilidad con llamadas de rebuild
rebuild() {
    rebuild_zivpn_json
}

# Verificar expiraciones mediante Cron o ejecución manual
verificar_expiraciones() {
    [[ ! -f "$DB_FILE" ]] && return
    today=$(date +%Y-%m-%d)
    changed=0

    tmp_db="/tmp/tmp_db.$$.db"
    touch "$tmp_db"

    while IFS="|" read -r user pass exp status; do
        if [[ "$status" == "active" && "$exp" < "$today" ]]; then
            echo "$user|$pass|$exp|inactive" >> "$tmp_db"
            echo -e "${YELLOW}⚠ Cuenta ZIVPN expirada y desactivada:${NC} $user"
            changed=1
        else
            echo "$user|$pass|$exp|$status" >> "$tmp_db"
        fi
    done < "$DB_FILE"
    mv "$tmp_db" "$DB_FILE"

    if [[ $changed -eq 1 ]]; then
        rebuild_zivpn_json
    fi
}

# Listar cuentas con formato unificado
listar_passwords() {
    echo -e "\n${CYAN}    === Lista de Cuentas ZIVPN ===${NC}"
    if [[ ! -s "$DB_FILE" ]]; then
        echo -e "${YELLOW}No hay cuentas registradas.${NC}"
        return
    fi

    printf "  %-4s %-15s %-15s %-12s %-14s %-10s\n" "N°" "Usuario" "Contraseña" "Expira" "Días rest." "Estado"
    echo " ----------------------------------------------------------------────────"

    num=1
    today=$(date +%Y-%m-%d)
    today_ts=$(date -d "$today" +%s 2>/dev/null || echo 0)

    while IFS="|" read -r user pass exp status; do
        [[ -z "$user" ]] && continue
        exp_ts=$(date -d "$exp" +%s 2>/dev/null || echo 0)

        if [[ "$exp_ts" -eq 0 || "$today_ts" -eq 0 ]]; then
            dleft="N/A"
        else
            dleft=$(( (exp_ts - today_ts) / 86400 ))
        fi

        if [[ "$dleft" != "N/A" && "$dleft" -lt 0 ]]; then
            dleft=0
            status="expired"
        fi

        dleft_str="${dleft} días"
        [[ "$dleft" -eq 1 ]] && dleft_str="1 día"

        printf "  %-4s %-15s %-15s %-12s %-14s %-10s\n" "$num" "$user" "$pass" "$exp" "$dleft_str" "$status"
        ((num++))
    done < "$DB_FILE"
    echo ""
}

# Agregar usuario de forma manual o aleatoria
agregar_password() {
    if [[ "$1" == "random" ]]; then
        user="user$(head /dev/urandom | tr -dc 0-9 | head -c 4)"
        pass=$(generar_password)
        echo -e "${YELLOW}Se generó cuenta aleatoria:${NC} User: $user | Pass: $pass"
    else
        read -p "Ingrese el nombre de usuario: " user
        if [[ "$user" =~ [\|:] || -z "$user" ]]; then
            echo -e "${RED}✘ Usuario inválido o vacío.${NC}" && return
        fi
        read -p "Ingrese la contraseña: " pass
    fi

    [[ -z "$pass" ]] && echo -e "${RED}✘ La contraseña no puede estar vacía.${NC}" && return

    if grep -q "^$user|" "$DB_FILE" 2>/dev/null; then
        echo -e "${RED}✘ El usuario '$user' ya existe en la base de datos.${NC}" && return
    fi

    while true; do
        read -p "Duración en días (1-365): " dias
        if [[ "$dias" =~ ^[0-9]+$ && "$dias" -ge 1 && "$dias" -le 365 ]]; then
            break
        else
            echo -e "${RED}✘ Ingrese un número válido entre 1 y 365.${NC}"
        fi
    done

    exp=$(date -d "+$dias days" +%Y-%m-%d)

    echo "$user|$pass|$exp|active" >> "$DB_FILE"

    rebuild_zivpn_json

    echo -e "${GREEN}✔ Cuenta ZIVPN añadida con éxito:${NC} $user:$pass (Expira el $exp)"
}

# Desactivar cuenta temporalmente
desactivar_password() {
    [[ ! -f "$DB_FILE" ]] && { echo -e "${RED}Base de datos no encontrada.${NC}"; return; }
    listar_passwords
    read -p "Ingrese el número de la cuenta a desactivar: " num

    total_lines=$(grep -c '^' "$DB_FILE")
    if [[ ! "$num" =~ ^[0-9]+$ || "$num" -le 0 || "$num" -gt "$total_lines" ]]; then
        echo -e "${RED}✘ Número inválido.${NC}" && return
    fi

    sed -i "${num}s/active$/inactive/" "$DB_FILE"

    rebuild_zivpn_json
    echo -e "${GREEN}✔ Cuenta desactivada correctamente.${NC}"
}

# Activar cuenta existente
activar_password() {
    [[ ! -f "$DB_FILE" ]] && { echo -e "${RED}Base de datos no encontrada.${NC}"; return; }
    listar_passwords
    read -p "Ingrese el número de la cuenta a activar: " num

    total_lines=$(grep -c '^' "$DB_FILE")
    if [[ ! "$num" =~ ^[0-9]+$ || "$num" -le 0 || "$num" -gt "$total_lines" ]]; then
        echo -e "${RED}✘ Número inválido.${NC}" && return
    fi

    exp=$(awk -F"|" -v n="$num" 'NR==n {print $3}' "$DB_FILE")
    today=$(date +%Y-%m-%d)
    if [[ "$exp" < "$today" ]]; then
        echo -e "${RED}✘ No se puede activar, la cuenta ya expiró (${exp}). Renuévela primero.${NC}"
        return
    fi

    sed -i "${num}s/inactive$/active/" "$DB_FILE"

    rebuild_zivpn_json
    echo -e "${GREEN}✔ Cuenta reactivada correctamente.${NC}"
}

# Eliminar por completo de la DB
eliminar_password() {
    [[ ! -f "$DB_FILE" ]] && { echo -e "${RED}Base de datos no encontrada.${NC}"; return; }
    listar_passwords
    read -p "Ingrese el número de la cuenta a eliminar: " num

    total_lines=$(grep -c '^' "$DB_FILE")
    if [[ ! "$num" =~ ^[0-9]+$ || "$num" -le 0 || "$num" -gt "$total_lines" ]]; then
        echo -e "${RED}✘ Número inválido.${NC}" && return
    fi

    sed -i "${num}d" "$DB_FILE"

    rebuild_zivpn_json
    echo -e "${GREEN}✔ Cuenta eliminada por completo.${NC}"
}

# Modificar los días de validez
editar_duracion() {
    [[ ! -f "$DB_FILE" ]] && { echo -e "${RED}Base de datos no encontrada.${NC}"; return; }
    listar_passwords
    read -p "Ingrese el número de la cuenta a editar: " num

    total_lines=$(grep -c '^' "$DB_FILE")
    if [[ ! "$num" =~ ^[0-9]+$ || "$num" -le 0 || "$num" -gt "$total_lines" ]]; then
        echo -e "${RED}✘ Número inválido.${NC}" && return
    fi

    while true; do
        read -p "Nueva duración en días desde hoy (1-365): " dias
        if [[ "$dias" =~ ^[0-9]+$ && "$dias" -ge 1 && "$dias" -le 365 ]]; then
            break
        else
            echo -e "${RED}✘ Ingrese un número válido.${NC}"
        fi
    done

    new_exp=$(date -d "+$dias days" +%Y-%m-%d)

    awk -F"|" -v n="$num" -v new_exp="$new_exp" 'BEGIN{OFS="|"} NR==n {$3=new_exp} {print}' "$DB_FILE" > /tmp/tmp_db.$$.db && mv /tmp/tmp_db.$$.db "$DB_FILE"

    rebuild_zivpn_json
    echo -e "${GREEN}✔ Fecha de expiración actualizada correctamente.${NC}"
}

remover_servicio() {
    echo -e "${RED}⚠ ATENCIÓN:${NC} Esto eliminará completamente ZiVPN del sistema."
    read -p "¿Está seguro? (s/n): " confirmacion
    [[ "$confirmacion" != "s" && "$confirmacion" != "S" ]] && return

    systemctl stop zivpn.service 2>/dev/null
    systemctl disable zivpn.service 2>/dev/null
    rm -f /etc/systemd/system/zivpn.service
    killall zivpn 2>/dev/null
    rm -rf /etc/zivpn
    rm -f /usr/local/bin/zivpn

    crontab -l 2>/dev/null | grep -v "zivpn-expire.sh" | crontab -
    rm -f /usr/local/bin/zivpn-expire.sh
    echo -e "${GREEN}✔ ZiVPN desinstalado.${NC}"
}

estado_servicio() {
    if systemctl is-active --quiet zivpn.service; then
        echo -e " ${GREEN}Estado: Activo${NC}"
    else
        echo -e " ${RED}Estado: Inactivo${NC}"
    fi
}

reiniciar_servicio() {
    systemctl restart zivpn.service 2>/dev/null
    echo -e "${GREEN}✔ Servicio reiniciado.${NC}"
}

instalar_servicio () {
    ARCH=$(uname -m)
    case "$ARCH" in
        "x86_64"|"amd64") BINARY_URL="https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-amd64" ;;
        "aarch64"|"arm64") BINARY_URL="https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn-linux-arm64" ;;
        *) exit 1 ;;
    esac

    systemctl stop zivpn.service 2>/dev/null
    wget "$BINARY_URL" -O /usr/local/bin/zivpn >/dev/null 2>&1
    chmod +x /usr/local/bin/zivpn
    mkdir -p /etc/zivpn

    apt-get install -y jq > /dev/null 2>&1
    touch /etc/zivpn/passwords.db
    wget https://raw.githubusercontent.com/zahidbd2/udp-zivpn/main/config.json -O /etc/zivpn/config.json >/dev/null 2>&1

    # Crear certificados
    openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 \
        -subj "/C=US/ST=California/L=Los Angeles/O=Example Corp/CN=zivpn" \
        -keyout "/etc/zivpn/zivpn.key" -out "/etc/zivpn/zivpn.crt"

    # Systemd Service
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

    # Configurar cuenta inicial en base de datos
    init_user="admin"
    init_pass=$(generar_password)
    init_exp=$(date -d "+30 days" +%Y-%m-%d)
    echo "$init_user|$init_pass|$init_exp|active" > /etc/zivpn/passwords.db

    systemctl daemon-reload
    systemctl enable zivpn.service
    rebuild_zivpn_json

    # Reglas IPTABLES de redirección de puertos dinámicos de forma segura
    iptables -t nat -A PREROUTING -p udp --dport 6000:19999 -j REDIRECT --to-port 5667 2>/dev/null

    EXPIRE_SCRIPT="/usr/local/bin/zivpn-expire.sh"
    cat > "$EXPIRE_SCRIPT" <<'EOF'
#!/bin/bash
/etc/dealer-adm/scripts/zivpn_manager.sh verificar_expiraciones
EOF
    chmod +x "$EXPIRE_SCRIPT"
    (crontab -l 2>/dev/null | grep -v "zivpn-expire.sh"; echo "0 * * * * $EXPIRE_SCRIPT") | crontab -

    echo -e "${GREEN}=== ZiVPN Multicuenta Instalado ===${NC}"
    echo -e "${YELLOW}Primer cuenta por defecto: ${GREEN}$init_user:$init_pass${NC}"
}

# =======================================================
# CONTROLADOR DE EJECUCIÓN (INTERNO / EXTERNO)
# =======================================================
if [[ -n "$1" ]]; then
    if type "$1" &>/dev/null; then
        "$1"
    else
        echo -e "${RED}✘ Función no reconocida: $1${NC}"
    fi
else
    listar_passwords
fi
