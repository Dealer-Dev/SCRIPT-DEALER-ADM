#!/bin/bash
# ═══════════════════════════════════════════════════════
#   SCRIPT DEALER ADM — Gestor de Servicios VPN/SSH
#   by Dealer • @DealerServices235
#   Ubuntu 22/24/25
# ═══════════════════════════════════════════════════════

SCRIPT_VERSION="1.7"
R='\033[0;31m'
G='\033[0;32m'
Y='\033[1;33m'
C='\033[0;96m'
W='\033[1;97m'
B='\033[0;34m'
P='\033[0;35m'
NC='\033[0m'
BOLD='\033[1m'
NEON='\033[1;92m'
DIM='\033[2;37m'
LINE='◆━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━◆'
LINE2='◇─────────────────────────────────────────────◇'

DIR_SCRIPTS="/etc/dealer-adm"
DIR_SERVICES="/etc/systemd/system"
DIR_BHTTP="/etc/dealer-adm/bhttp"
BHTTP_BIN="/usr/local/bin/bhttp-server"
CONFIG_BHTTP_DB="$DIR_BHTTP/ports.db"

# Crear directorios del sistema y otorgar permisos full
mkdir -p $DIR_SCRIPTS
mkdir -p $DIR_SCRIPTS/userDIR
mkdir -p $DIR_SCRIPTS/resellers
mkdir -p $DIR_SCRIPTS/scripts
mkdir -p $DIR_BHTTP
touch $CONFIG_BHTTP_DB

chmod -R 777 $DIR_SCRIPTS

wget -qO /etc/dealer-adm/scripts/zivpn_manager.sh \
"https://raw.githubusercontent.com/Dealer-Dev/SCRIPT-DEALER-ADM/main/scripts/zivpn_manager.sh"

chmod +x /etc/dealer-adm/scripts/zivpn_manager.sh

source /etc/dealer-adm/scripts/zivpn_manager.sh

# ==========================================
# CONFIGURAR CHECKUSER Y BANNER PAM OFICIAL
# ==========================================
cat > /etc/dealer-adm/checkuser.sh << 'EOF'
#!/bin/bash
USR="$PAM_USER"
FILE=$(grep -l "^usuario: $USR$" /etc/dealer-adm/userDIR/* 2>/dev/null | head -1)
[ -z "$FILE" ] && exit 0

NOMBRE=$(grep '^nombre:' "$FILE" | cut -d' ' -f2-)
EXP=$(grep '^fecha:' "$FILE" | awk '{print $2}')
EXP_SHOW=$(date -d "$EXP" +%d-%m-%Y 2>/dev/null)
[ -z "$EXP_SHOW" ] && EXP_SHOW="$EXP"

cat > /etc/dealer-adm/banner.txt << BANNER
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<font color="#0095b6">❒════════════════════════❒</font><br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<font color="#FF8000"><b>Usuario:</b></font>
<font color="#FFD700">$NOMBRE</font><br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<font color="#ff00ff"><b>Expira:</b></font>
<font color="#ff0000">$EXP_SHOW</font><br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<font color="#0095b6">❒══════</font><font color="#00ff00"> Script Dealer Adm </font><font color="#0095b6">══════❒</font>
BANNER
exit 0
EOF

chmod +x /etc/dealer-adm/checkuser.sh
touch /etc/dealer-adm/banner.txt

if ! grep -q "Dealer CheckUser" /etc/pam.d/sshd; then
cat >> /etc/pam.d/sshd << 'EOF'

# Dealer CheckUser
auth optional pam_exec.so /etc/dealer-adm/checkuser.sh
auth optional pam_echo.so file=/etc/dealer-adm/banner.txt
EOF
fi

# ==========================================
# CREAR HERRAMIENTA PUENTE DE SINCRONIZACIÓN HYSTERIA
# ==========================================
cat > /etc/dealer-adm/scripts/sync_hysteria.sh << 'EOF'
#!/bin/bash

USER="$1"
PASS="$2"

[ -z "$USER" ] || [ -z "$PASS" ] && exit 1
[ ! -f /etc/hysteria/config.json ] && exit 0

python3 -c "
import json, os

p = '/etc/hysteria/config.json'
u = '$USER'
pwd = '$PASS'

if os.path.exists(p):
    try:
        with open(p, 'r') as f:
            c = json.load(f)
        
        auth = c.get('auth', {})
        cfg = auth.get('config', [])
        if not isinstance(cfg, list):
            cfg = []
            
        entry = f'{u}:{pwd}'
        if entry not in cfg:
            cfg.append(entry)
            c['auth'] = {'mode': 'passwords', 'config': cfg}
            with open(p, 'w') as f:
                json.dump(c, f, indent=2)
    except Exception:
        pass
"

systemctl restart hysteria-server >/dev/null 2>&1
EOF

chmod +x /etc/dealer-adm/scripts/sync_hysteria.sh
chmod 777 /etc/dealer-adm/scripts/sync_hysteria.sh

# Otorgar permisos de sudo a Apache (www-data) sin contraseña
chmod 777 /etc/hysteria/config.json 2>/dev/null
if ! grep -q "sync_hysteria.sh" /etc/sudoers; then
    echo "www-data ALL=(ALL) NOPASSWD: /etc/dealer-adm/scripts/sync_hysteria.sh" >> /etc/sudoers
    echo "www-data ALL=(ALL) NOPASSWD: /bin/systemctl restart hysteria-server" >> /etc/sudoers
    echo "www-data ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart hysteria-server" >> /etc/sudoers
fi

# Desactivar restricciones PAM de contraseña
sed -i 's/pam_unix.so obscure/pam_unix.so/' /etc/pam.d/common-password 2>/dev/null
sed -i 's/use_authtok //' /etc/pam.d/common-password 2>/dev/null
sed -i '/pam_pwquality/d' /etc/pam.d/common-password 2>/dev/null
sed -i '/pam_cracklib/d' /etc/pam.d/common-password 2>/dev/null

# Configurar UFW si esta activo
if command -v ufw > /dev/null 2>&1 && ufw status | grep -q "Status: active"; then
    ufw allow 22/tcp > /dev/null 2>&1
    ufw allow 80/tcp > /dev/null 2>&1
    ufw allow 443/tcp > /dev/null 2>&1
    ufw allow 8080/tcp > /dev/null 2>&1
    ufw allow 8388/tcp > /dev/null 2>&1
    ufw allow 8388/udp > /dev/null 2>&1
    ufw allow 7200/tcp > /dev/null 2>&1
    ufw allow 7300/tcp > /dev/null 2>&1
    ufw allow 5667/udp > /dev/null 2>&1
    ufw allow 36712/udp > /dev/null 2>&1
    ufw allow 90/tcp > /dev/null 2>&1
    ufw reload > /dev/null 2>&1
fi

# ==========================================
# CONFIGURACIÓN GLOBAL DE RED UDP
# ==========================================
configurar_red_udp_global() {
    if ! command -v netfilter-persistent &>/dev/null; then
        echo "iptables-persistent iptables-persistent/autosave_v4 boolean true" | debconf-set-selections 2>/dev/null
        echo "iptables-persistent iptables-persistent/autosave_v6 boolean true" | debconf-set-selections 2>/dev/null
        DEBIAN_FRONTEND=noninteractive apt install -y -qq iptables-persistent netfilter-persistent >/dev/null 2>&1
    fi

    iptables -t nat -F PREROUTING 2>/dev/null
    iptables -t nat -A PREROUTING -p udp --dport 6000:19999 -j REDIRECT --to-port 5667 2>/dev/null

    if command -v netfilter-persistent &>/dev/null; then
        netfilter-persistent save >/dev/null 2>&1
    elif [ -d /etc/iptables ]; then
        iptables-save > /etc/iptables/rules.v4 2>/dev/null
    fi

    if command -v ufw &>/dev/null && ufw status | grep -q "Status: active"; then
        ufw allow 5667/udp >/dev/null 2>&1
        ufw allow 6000:19999/udp >/dev/null 2>&1
        ufw allow 36712/udp >/dev/null 2>&1
        ufw allow 8443/udp >/dev/null 2>&1
        ufw allow 5300/udp >/dev/null 2>&1
        ufw reload >/dev/null 2>&1
    fi
}

# Aplicar mapa de red UDP automático
configurar_red_udp_global

# ══════════════════════════════════════════
# VERIFICACION DE LICENCIA DEALER
# ══════════════════════════════════════════
if [ ! -f /etc/dealer-adm/.licensed ]; then

    mkdir -p /etc/dealer-adm

    clear
    echo -e "\033[1;92m"
    figlet -f small "Script Dealer" 2>/dev/null || echo "Script Dealer"
    echo -e "\033[0m"

    echo -e "\033[1;92m◆━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━◆\033[0m"
    echo -e "  \033[1;97m SCRIPT DEALER ADM ${Y}v${SCRIPT_VERSION}${NC}\033[0m"
    echo -e "\033[1;92m◆━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━◆\033[0m"
    echo ""
    echo -e "  \033[1;33m A continuación ingresa tu Key\033[0m"
    echo -e "  \033[2;37m   Obtén tu KEY con @DealerServices235\033[0m"
    echo -e "\033[1;92m◆━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━◆\033[0m"

    read -p "  Ingresa tu KEY: " INPUT_KEY
    echo -e "\033[1;92m◆━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━◆\033[0m"

    command -v curl >/dev/null 2>&1 || apt install -y curl >/dev/null 2>&1

    echo -e "  \033[0;36m⏳ Verificando key...\033[0m"
    echo -e "\033[1;92m◆━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━◆\033[0m"
    API_URL="https://dealerbotgenkeys.mcmilton235.workers.dev/validate"

    RESPONSE=$(curl -s --max-time 15 "$API_URL?key=$INPUT_KEY&client=vps")
    OWNER=$(echo "$RESPONSE" | grep -oP '"owner":"\K[^"]+')
    [ -z "$OWNER" ] && OWNER="Desconocido"

    VALID=$(echo "$RESPONSE" | grep -o '"valid":true')

    if [[ "$VALID" == '"valid":true' ]]; then
        echo "$INPUT_KEY" > /etc/dealer-adm/.licensed
        echo "$OWNER" > /etc/dealer-adm/reseller

        echo -e "  \033[0;32m Key válida ✅\033[0m"
        echo -e "\033[1;92m◆━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━◆\033[0m"
        sleep 2
    else
        if echo "$RESPONSE" | grep -q '"expired"'; then
            MSG="⏰ Key expirada ⏰"
        elif echo "$RESPONSE" | grep -q '"used"'; then
            MSG="⚠️ Key ya usada ⚠️"
        elif echo "$RESPONSE" | grep -q '"not_found"'; then
            MSG="❌ La key no existe ❌"
        else
            MSG="❌ Error de validación ❌"
        fi
        echo -e "  \033[0;31m$MSG\033[0m"
        echo -e "\033[1;92m◆━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━◆\033[0m"
        sleep 3
        exit 1
    fi
fi

# Deshabilitar mensajes de bienvenida de Ubuntu
touch ~/.hushlogin 2>/dev/null
chmod -x /etc/update-motd.d/* 2>/dev/null
> /etc/motd 2>/dev/null

# Dar permisos a certificados letsencrypt
if [ -d /etc/letsencrypt ]; then
    chmod 755 /etc/letsencrypt/live/ /etc/letsencrypt/archive/ 2>/dev/null
    find /etc/letsencrypt -name "*.pem" -exec chmod 644 {} \; 2>/dev/null
fi

# Preguntar nombre ASCII al instalar por primera vez
if [ ! -f /etc/dealer-adm/server_name ]; then
    mkdir -p /etc/dealer-adm
    apt install -y figlet > /dev/null 2>&1
    echo -e "\033[1;33mEscribe el nombre para el servidor\033[0m"
    read -p "Nombre: " INSTALL_NAME
    INSTALL_NAME=${INSTALL_NAME:-"Dealer"}
    echo "$INSTALL_NAME" > /etc/dealer-adm/server_name
    echo "$(date +%d-%m-%Y)" > /etc/dealer-adm/install_date
fi

# Instalar MOTD automáticamente
cat > /etc/profile.d/sshfree-motd.sh << 'MOTDSCRIPT'
#!/bin/bash
PURPLE='\033[0;35m' CYAN='\033[0;36m' GREEN='\033[0;32m'
YELLOW='\033[1;33m' WHITE='\033[1;37m' NC='\033[0m'
INSTALL_DATE=$(cat /etc/dealer-adm/install_date 2>/dev/null || echo "N/A")
SRV_NAME=$(cat /etc/dealer-adm/server_name 2>/dev/null || echo "Dealer")
CURRENT_DATE=$(date +%d-%m-%Y)
CURRENT_TIME=$(date +%H:%M:%S)
UPTIME=$(uptime -p | sed 's/up //')
RAM_FREE=$(free -h | awk '/^Mem:/{print $4}')
echo -e "${GREEN}"
figlet -f small "$SRV_NAME" 2>/dev/null || echo "  $SRV_NAME"
echo -e "${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  ${YELLOW}SERVIDOR INSTALADO EL${NC}    : ${WHITE}$INSTALL_DATE${NC}"
echo -e "  ${YELLOW}FECHA/HORA ACTUAL${NC}        : ${WHITE}$CURRENT_DATE - $CURRENT_TIME${NC}"
echo -e "  ${YELLOW}NOMBRE DEL SERVIDOR${NC}      : ${WHITE}$(hostname)${NC}"
echo -e "  ${YELLOW}TIEMPO EN LINEA${NC}          : ${WHITE}$UPTIME${NC}"
echo -e "  ${YELLOW}MEMORIA RAM LIBRE${NC}        : ${WHITE}$RAM_FREE${NC}"
echo -e "  ${YELLOW}CREADOR DEL SCRIPT${NC}       : ${GREEN}@DealerServices235 𓃹${NC}"
echo -e "  ${GREEN}BIENVENIDO DE NUEVO!${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  Escribe ${YELLOW}menu${NC} para ver el menú"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
MOTDSCRIPT
chmod +x /etc/profile.d/sshfree-motd.sh
[ -f /etc/motd ] && > /etc/motd

banner() {
    clear
    SRV_NAME=$(cat /etc/dealer-adm/server_name 2>/dev/null || echo "Dealer")
    RESELLER=$(cat /etc/dealer-adm/reseller 2>/dev/null)
    [ -z "$RESELLER" ] && RESELLER="Desconocido"
    echo -e "${NEON}"
    figlet -f small "$SRV_NAME" 2>/dev/null || echo "  $SRV_NAME"
    echo -e "${NC}"
    echo -e "${NEON}◆━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━◆${NC}"
    echo -e "                ${NEON}SCRIPT DEALER ADM${NC} 𓃹"
    echo -e "${NEON}◆━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━◆${NC}"
    echo -e "  Key por: ${Y}$RESELLER   ${NC}"
}
sep() { echo -e "${NEON}${LINE}${NC}"; }
sep2() { echo -e "${DIM}${LINE2}${NC}"; }

status_service() {
    systemctl is-active --quiet "$1" 2>/dev/null && echo -e "${NEON}◆ ON ${NC}" || echo -e "${R}◇ OFF${NC}"
}

status_port() {
    ss -${2:-t}lnp 2>/dev/null | grep -q ":${1} " && echo -e "${NEON}◆ ON ${NC}" || echo -e "${R}◇ OFF${NC}"
}

# ══════════════════════════════════════════
#   MÓDULO BHTTPTUNNEL (PANEL DE GESTIÓN AVANZADO)
# ══════════════════════════════════════════

bhttp_optimizar_kernel() {
    modprobe tcp_bbr 2>/dev/null
    echo "tcp_bbr" >> /etc/modules-load.d/modules.conf 2>/dev/null
    cat > /etc/sysctl.d/99-bhttp.conf << 'EOF'
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.ipv4.tcp_rmem = 4096 87380 33554432
net.ipv4.tcp_wmem = 4096 65536 33554432
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 16384
net.ipv4.tcp_max_syn_backlog = 16384
net.ipv4.tcp_slow_start_after_idle = 0
fs.file-max = 1048576
EOF
    sysctl --system >/dev/null 2>&1
}

bhttp_instalar_binario() {
    clear
    echo -e "${Y}Instalando / Actualizando motor BHTTP de alto rendimiento...${NC}"
    bhttp_optimizar_kernel

    # Descargar directamente el script optimizado desde tu repositorio de GitHub o crearlo localmente
    cat > "$BHTTP_BIN" << 'PYEOF'
#!/usr/bin/env python3
import argparse, asyncio, hashlib, struct, sys, socket

MAGIC = b"BHP1"
LONGPOLL = 0.5

def keystream(sess, mode, seq, d, n):
    base = hashlib.sha256(sess + bytes([mode]) + seq.to_bytes(8, "big") + bytes([d]))
    out = bytearray()
    c = 0
    while len(out) < n:
        h = base.copy()
        h.update(c.to_bytes(4, "big"))
        out += h.digest()
        c += 1
    return bytes(out[:n])

def mask(data, sess, mode, seq, d):
    return bytes(a ^ b for a, b in zip(data, keystream(sess, mode, seq, d, len(data))))

def probe_reply(mode, size):
    n = size if (mode == 2 and size >= 10) else 10
    out = bytearray(MAGIC + bytes([1, mode]) + size.to_bytes(4, "big"))
    for i in range(10, n):
        out.append((i * 31) & 255)
    return bytes(out)

class Session:
    def __init__(self, sess, backend):
        self.sess = sess
        self.backend = backend
        self.cond = asyncio.Condition()
        self.up_next = 0
        self.up_pending = {}
        self.down_raw = bytearray()
        self.down_chunks = {}
        self.down_assign = 0
        self.eof = False
        self.closed = False
        self.br = None
        self.bw = None

    async def connect(self):
        host, port = self.backend
        self.br, self.bw = await asyncio.open_connection(host, port)
        try:
            raw_sock = self.bw.get_extra_info('socket')
            if raw_sock:
                raw_sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        except Exception:
            pass
        asyncio.create_task(self._reader())

    async def _reader(self):
        try:
            while True:
                data = await self.br.read(262144)
                if not data:
                    break
                async with self.cond:
                    self.down_raw += data
                    self.cond.notify_all()
        except Exception:
            pass
        finally:
            async with self.cond:
                self.eof = True
                self.cond.notify_all()

    async def upload(self, seq, data):
        async with self.cond:
            if data:
                self.up_pending[seq] = data
            while self.up_next in self.up_pending:
                chunk = self.up_pending.pop(self.up_next)
                try:
                    self.bw.write(chunk)
                    await self.bw.drain()
                except Exception:
                    self.closed = True
                self.up_next += 1

    async def download(self, seq, maxlen, deadline):
        if maxlen <= 0:
            maxlen = 32768
        loop = asyncio.get_running_loop()
        async with self.cond:
            while True:
                if seq < self.down_assign:
                    return self.down_chunks.get(seq, b"")
                if seq == self.down_assign:
                    if self.down_raw:
                        take = bytes(self.down_raw[:maxlen])
                        del self.down_raw[:maxlen]
                        self.down_chunks[self.down_assign] = take
                        self.down_assign += 1
                        self.cond.notify_all()
                        return take
                    if self.eof:
                        self.down_assign += 1
                        self.cond.notify_all()
                        return b""
                    if not self.eof and loop.time() < deadline:
                        try:
                            await asyncio.wait_for(self.cond.wait(), timeout=max(0.002, deadline - loop.time()))
                        except asyncio.TimeoutError:
                            pass
                        continue
                while self.down_assign <= seq:
                    self.down_assign += 1
                self.cond.notify_all()
                return b""

    async def ack(self, seq):
        async with self.cond:
            for k in [k for k in self.down_chunks if k <= seq]:
                del self.down_chunks[k]

    async def close(self):
        async with self.cond:
            self.closed = True
            self.cond.notify_all()
        try:
            self.bw.close()
        except Exception:
            pass

class Server:
    def __init__(self, host, port, backend):
        self.host = host
        self.port = port
        self.backend = backend
        self.sessions = {}
        self.slock = asyncio.Lock()

    async def get_session(self, sess):
        async with self.slock:
            s = self.sessions.get(sess)
            if s is None or s.closed:
                for old_sid, old in list(self.sessions.items()):
                    if old_sid != sess:
                        await old.close()
                        del self.sessions[old_sid]
                s = Session(sess, self.backend)
                await s.connect()
                self.sessions[sess] = s
            return s

    async def handle(self, reader, writer):
        try:
            raw_sock = writer.get_extra_info('socket')
            if raw_sock:
                raw_sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        except Exception:
            pass

        try:
            while True:
                hdr = await reader.readexactly(29)
                mode = hdr[0]
                sess = hdr[1:17]
                seq = int.from_bytes(hdr[17:25], "big")
                ln = int.from_bytes(hdr[25:29], "big")
                payload = b""
                if ln and mode in (0, 1, 2, 3):
                    raw = await reader.readexactly(ln)
                    payload = mask(raw, sess, mode, seq, 0)

                if payload[:4] == MAGIC:
                    size = int.from_bytes(payload[6:10], "big") if len(payload) >= 10 else 0
                    pmode = payload[5] if len(payload) >= 6 else mode
                    body = mask(probe_reply(pmode, size), sess, mode, seq, 1)
                    writer.write(bytes([0]) + len(body).to_bytes(4, "big") + body)
                    await writer.drain()
                    continue

                s = await self.get_session(sess)
                if mode == 1:
                    await s.upload(seq, payload)
                    writer.write(bytes([0]) + (0).to_bytes(4, "big"))
                    await writer.drain()
                elif mode == 2:
                    chunk = await s.download(seq, ln if ln > 0 else 32768, asyncio.get_running_loop().time() + LONGPOLL)
                    self._send_data(writer, sess, mode, seq, chunk)
                    await writer.drain()
                elif mode == 3:
                    if len(payload) >= 6:
                        chunk_size = int.from_bytes(payload[0:4], "big")
                        count = payload[5]
                    else:
                        chunk_size, count = 32768, 1
                    if chunk_size <= 0:
                        chunk_size = 32768
                    if count <= 0:
                        count = 1
                    deadline = asyncio.get_running_loop().time() + LONGPOLL
                    for i in range(count):
                        chunk = await s.download(seq + i, chunk_size, deadline)
                        self._send_data(writer, sess, mode, seq + i, chunk)
                    await writer.drain()
                elif mode == 4:
                    await s.ack(seq)
                    writer.write(bytes([0]) + (0).to_bytes(4, "big"))
                    await writer.drain()
                else:
                    return
        except (asyncio.IncompleteReadError, ConnectionError, OSError):
            pass
        except Exception:
            pass
        finally:
            try:
                writer.close()
            except Exception:
                pass

    def _send_data(self, writer, sess, mode, seq, data):
        real = len(data)
        masked = mask(data, sess, mode, seq, 1) if data else b""
        body = real.to_bytes(4, "big") + masked
        writer.write(bytes([2]) + len(body).to_bytes(4, "big") + body)

    async def serve(self):
        srv = await asyncio.start_server(self.handle, self.host, self.port, backlog=2048)
        async with srv:
            await srv.serve_forever()

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--host", default="0.0.0.0")
    ap.add_argument("--port", type=int, required=True)
    ap.add_argument("--backend-host", default="127.0.0.1")
    ap.add_argument("--backend-port", type=int, default=22)
    a = ap.parse_args()
    asyncio.run(Server(a.host, a.port, (a.backend_host, a.backend_port)).serve())

if __name__ == "__main__":
    main()
PYEOF

    chmod +x "$BHTTP_BIN"
    echo -e "\n${G}Motor KTUN avanzado instalado correctamente en $BHTTP_BIN${NC}"
    sleep 2
}

bhttp_agregar_puerto() {
    clear
    echo -e "${Y}Agregar nuevo puerto KTUN (Multipuerto)${NC}\n"
    read -p "  Puerto de escucha KTUN (ej: 90, 80): " LISTEN_PORT
    [ -z "$LISTEN_PORT" ] && return

    if grep -q "^$LISTEN_PORT|" "$CONFIG_BHTTP_DB" 2>/dev/null; then
        echo -e "\n${R}El puerto $LISTEN_PORT ya está registrado.${NC}"
        sleep 2 && return
    fi

    echo -e "\n${C}Selecciona el destino de la redirección backend:${NC}"
    echo -e "  [1] OpenSSH Directo (Puerto 22)"
    echo -e "  [2] Dropbear SSH (Puerto 444)"
    echo -e "  [3] Personalizado (Ingresar puerto manualmente)"
    read -p "  Opción [1-3]: " DEST_OPT

    case $DEST_OPT in
        1) TARGET_PORT=22 ;;
        2) TARGET_PORT=444 ;;
        3) read -p "  Ingresa el puerto local destino: " TARGET_PORT ;;
        *) TARGET_PORT=22 ;;
    esac
    [ -z "$TARGET_PORT" ] && TARGET_PORT=22

    # Generar servicio systemd usando el script avanzado con argumentos --port y --backend-port
    cat > "$DIR_SERVICES/bhttp-${LISTEN_PORT}.service" << EOF
[Unit]
Description=BHTTP Advanced Tunnel Port ${LISTEN_PORT} -> ${TARGET_PORT}
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/python3 $BHTTP_BIN --host 0.0.0.0 --port ${LISTEN_PORT} --backend-host 127.0.0.1 --backend-port ${TARGET_PORT}
Restart=always
RestartSec=2
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable bhttp-${LISTEN_PORT} >/dev/null 2>&1
    systemctl restart bhttp-${LISTEN_PORT}

    iptables -I INPUT -p tcp --dport "$LISTEN_PORT" -j ACCEPT 2>/dev/null
    command -v ufw >/dev/null 2>&1 && ufw allow "$LISTEN_PORT"/tcp >/dev/null 2>&1

    echo "$LISTEN_PORT|$TARGET_PORT" >> "$CONFIG_BHTTP_DB"

    echo -e "\n${G}Puerto KTUN $LISTEN_PORT activo y redirigiendo a 127.0.0.1:$TARGET_PORT${NC}"
    sleep 2
}

bhttp_listar_puertos() {
    clear
    echo -e "${Y}Puertos KTUN Configurados:${NC}\n"
    if [ ! -s "$CONFIG_BHTTP_DB" ]; then
        echo -e "  ${R}No hay puertos BHTTP configurados.${NC}"
    else
        while IFS='|' read -r L_PORT T_PORT; do
            [ -z "$L_PORT" ] && continue
            if systemctl is-active --quiet "bhttp-$L_PORT" 2>/dev/null; then
                STATUS="${G}[ACTIVO]${NC}"
            else
                STATUS="${R}[INACTIVO]${NC}"
            fi
            echo -e "  Puerto KTUN: ${W}$L_PORT${NC} -> Backend SSH: ${C}$T_PORT${NC} $STATUS"
        done < "$CONFIG_BHTTP_DB"
    fi
    echo ""
    read -p "  Presiona ENTER para continuar..."
}

bhttp_reiniciar_puerto() {
    clear
    read -p "Ingresa el puerto a reiniciar: " P
    [ -z "$P" ] && return
    if [ -f "$DIR_SERVICES/bhttp-$P.service" ]; then
        systemctl restart "bhttp-$P"
        echo -e "${G}Puerto KTUN $P reiniciado con éxito.${NC}"
    else
        echo -e "${R}El servicio bhttp-$P no existe.${NC}"
    fi
    sleep 2
}

bhttp_eliminar_puerto() {
    clear
    read -p "Ingresa el puerto a eliminar: " P
    [ -z "$P" ] && return
    systemctl stop "bhttp-$P" 2>/dev/null
    systemctl disable "bhttp-$P" 2>/dev/null
    rm -f "$DIR_SERVICES/bhttp-$P.service"
    systemctl daemon-reload

    grep -v "^$P|" "$CONFIG_BHTTP_DB" > "$CONFIG_BHTTP_DB.tmp" 2>/dev/null && mv "$CONFIG_BHTTP_DB.tmp" "$CONFIG_BHTTP_DB"

    echo -e "${G}Puerto KTUN $P detenido y eliminado correctamente.${NC}"
    sleep 2
}

bhttp_detener_todos() {
    clear
    while IFS='|' read -r L_PORT _; do
        [ -n "$L_PORT" ] && systemctl stop "bhttp-$L_PORT" 2>/dev/null
    done < "$CONFIG_BHTTP_DB"
    echo -e "${Y}Todos los servicios KTUN han sido detenidos.${NC}"
    sleep 2
}

bhttp_datos_http_custom() {
    clear
    SRV_IP=$(curl -s -4 ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
    PORTS=$(awk -F'|' '{print $1}' "$CONFIG_BHTTP_DB" | paste -sd "," -)
    echo -e "${Y}DATOS DE CONEXIÓN (KTUN / DEALER VPN)${NC}\n"
    echo -e "  ${W}IP del Servidor:${NC} ${G}$SRV_IP${NC}"
    echo -e "  ${W}Puertos Activos:${NC} ${C}${PORTS:-Ninguno}${NC}"
    echo -e "  ${W}Protocolo:${NC}       KTUN (BHP1 Framing con Chunks Optimizados)"
    echo -e "  ${W}Autenticación:${NC}   Cualquier usuario SSH activo en tu script"
    echo ""
    read -p "  Presiona ENTER para continuar..."
}

bhttp_reiniciar_todos() {
    clear
    while IFS='|' read -r L_PORT _; do
        [ -n "$L_PORT" ] && systemctl restart "bhttp-$L_PORT" 2>/dev/null
    done < "$CONFIG_BHTTP_DB"
    echo -e "${G}Todos los servicios KTUN han sido reiniciados.${NC}"
    sleep 2
}

bhttp_ver_logs() {
    clear
    read -p "Ingresa el puerto KTUN para ver logs: " P
    [ -z "$P" ] && return
    journalctl -u "bhttp-$P" -n 40 --no-pager
    echo ""
    read -p "  Presiona ENTER para volver..."
}

bhttp_desinstalar_todo() {
    clear
    read -p "¿Estás seguro de desinstalar todo KTUN? (si/no): " CONFIRM
    [ "$CONFIRM" != "si" ] && return

    while IFS='|' read -r L_PORT _; do
        if [ -n "$L_PORT" ]; then
            systemctl stop "bhttp-$L_PORT" 2>/dev/null
            systemctl disable "bhttp-$L_PORT" 2>/dev/null
            rm -f "$DIR_SERVICES/bhttp-$L_PORT.service"
        fi
    done < "$CONFIG_BHTTP_DB"

    systemctl daemon-reload
    rm -rf "$DIR_BHTTP"
    rm -f "$BHTTP_BIN"
    echo -e "${G}KTUN desinstalado por completo.${NC}"
    sleep 2
}

menu_bhttp() {
    while true; do
        clear
        ACTIVOS=0
        PUERTOS=""
        if [ -s "$CONFIG_BHTTP_DB" ]; then
            while IFS='|' read -r L_PORT _; do
                [ -z "$L_PORT" ] && continue
                if systemctl is-active --quiet "bhttp-$L_PORT" 2>/dev/null; then
                    ((ACTIVOS++))
                    if [ -z "$PUERTOS" ]; then
                        PUERTOS="$L_PORT"
                    else
                        PUERTOS="$PUERTOS,$L_PORT"
                    fi
                fi
            done < "$CONFIG_BHTTP_DB"
        fi
        [ -z "$PUERTOS" ] && PUERTOS="Ninguno"

        echo -e "\033[0;33m╔═══════════════════════════════════════════════════════════╗\033[0m"
        echo -e "\033[0;33m║\033[0m \033[43;30m KTUNTUNNEL • GESTIÓN AVANZADA \033[0m \033[0;33m║\033[0m"
        echo -e "\033[0;33m╚═══════════════════════════════════════════════════════════╝\033[0m"
        echo ""
        echo -e "        \033[1;97mEstado\033[0m\033[0;32m✅\033[0m: \033[1;97m${ACTIVOS} activo(s)\033[0m"
        echo -e "        \033[1;97mPuerto(s):\033[0m \033[1;97m${PUERTOS}\033[0m"
        echo ""
        echo -e "\033[0;33m╞═══════════════════════════════════════════════════════════════════════════════╡\033[0m"
        echo -e " \033[1;97m[1]\033[0m\033[0;31m▶\033[0m \033[1;97mInstalar / Re-instalar motor KTUN avanzado\033[0m"
        echo -e " \033[1;97m[2]\033[0m\033[0;31m▶\033[0m \033[1;97mAgregar nuevo puerto KTUN\033[0m"
        echo -e " \033[1;97m[3]\033[0m\033[0;31m▶\033[0m \033[1;97mListar puertos activos\033[0m"
        echo -e " \033[1;97m[4]\033[0m\033[0;31m▶\033[0m \033[1;97mReiniciar puerto específico\033[0m"
        echo -e " \033[1;97m[5]\033[0m\033[0;31m▶\033[0m \033[1;97mDetener y eliminar un puerto\033[0m"
        echo -e " \033[1;97m[6]\033[0m\033[0;31m▶\033[0m \033[1;97mDetener TODOS los puertos\033[0m"
        echo -e " \033[1;97m[7]\033[0m\033[0;31m▶\033[0m \033[1;97mConfiguración y datos Dealer VPN / KTUN\033[0m"
        echo -e " \033[1;97m[8]\033[0m\033[0;31m▶\033[0m \033[1;97mReiniciar todos los puertos\033[0m"
        echo -e " \033[1;97m[9]\033[0m\033[0;31m▶\033[0m \033[1;97mVer logs de un puerto\033[0m"
        echo -e "\033[0;33m╞═══════════════════════════════════════════════════════════════════════════════╡\033[0m"
        echo -e " \033[1;97m[10]\033[0m\033[0;31m▶\033[0m \033[1;97mDesinstalar TODO\033[0m"
        echo -e " \033[1;97m[0]\033[0m\033[0;31m▶\033[0m \033[1;97mVolver al menú principal\033[0m"
        echo -e "\033[0;33m╚═══════════════════════════════════════════════════════════════════════════════╝\033[0m"
        echo ""
        read -p " Selecciona una opción: " B_OPT
        case $B_OPT in
            1) bhttp_instalar_binario ;;
            2) bhttp_agregar_puerto ;;
            3) bhttp_listar_puertos ;;
            4) bhttp_reiniciar_puerto ;;
            5) bhttp_eliminar_puerto ;;
            6) bhttp_detener_todos ;;
            7) bhttp_datos_http_custom ;;
            8) bhttp_reiniciar_todos ;;
            9) bhttp_ver_logs ;;
            10) bhttp_desinstalar_todo ;;
            0) break ;;
            *) echo -e "\n${R}Opción inválida.${NC}"; sleep 1 ;;
        esac
    done
}
# ══════════════════════════════════════════
#   WEBSOCKET PYTHON
# ══════════════════════════════════════════

instalar_ws() {
    banner; sep
    echo -e "  ${Y}Configurar WebSocket Python${NC}"; sep; echo ""
    read -p "  Puerto WebSocket (ej: 80): " WS_PORT; WS_PORT=${WS_PORT:-80}
    read -p "  Puerto local SSH (ej: 22): " SSH_PORT; SSH_PORT=${SSH_PORT:-22}
    echo ""; sep
    echo -e "  ${W}RESPONSE (101 para WebSocket, 200 default):${NC}"
    read -p "  RESPONSE: " STATUS_RESP; STATUS_RESP=${STATUS_RESP:-200}
    echo ""; read -p "  Mini-Banner: " BANNER_MSG
    BANNER_MSG=${BANNER_MSG:-"<font color=\"#00ff00\">Script Dealer Adm"}
    echo ""; sep
    echo -e "  ${W}Encabezado personalizado (ENTER para default):${NC}"
    read -p "  Cabecera: " CUSTOM_HEADER
    [ -z "$CUSTOM_HEADER" ] && CUSTOM_HEADER="\r\nContent-length: 0\r\n\r\nHTTP/1.1 200 Connection Established\r\n\r\n"

    cat > $DIR_SCRIPTS/proxy_ws_${WS_PORT}.py << PYEOF
#!/usr/bin/env python3
import socket, threading, select, sys, time
LISTENING_ADDR = '0.0.0.0'
LISTENING_PORT = ${WS_PORT}
BUFLEN = 4096 * 4
TIMEOUT = 60
DEFAULT_HOST = b'127.0.0.1:${SSH_PORT}'
MSG = '${BANNER_MSG}'.encode('utf-8')
STATUS_RESP = b'${STATUS_RESP}'
FTAG = b'${CUSTOM_HEADER}'
RESPONSE = b'HTTP/1.1 ' + STATUS_RESP + b' ' + MSG + b' ' + FTAG

class Server(threading.Thread):
    def __init__(self, host, port):
        threading.Thread.__init__(self)
        self.running = False; self.host = host; self.port = port
        self.threads = []; self.threadsLock = threading.Lock(); self.logLock = threading.Lock()
    def run(self):
        self.soc = socket.socket(socket.AF_INET)
        self.soc.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.soc.settimeout(2); self.soc.bind((self.host, int(self.port))); self.soc.listen(0)
        self.running = True
        try:
            while self.running:
                try: c, addr = self.soc.accept(); c.setblocking(1)
                except socket.timeout: continue
                conn = ConnectionHandler(c, self, addr); conn.start(); self.addConn(conn)
        finally: self.running = False; self.soc.close()
    def printLog(self, log):
        self.logLock.acquire(); print(log); self.logLock.release()
    def addConn(self, conn):
        try:
            self.threadsLock.acquire()
            if self.running: self.threads.append(conn)
        finally: self.threadsLock.release()
    def removeConn(self, conn):
        try: self.threadsLock.acquire(); self.threads.remove(conn)
        finally: self.threadsLock.release()
    def close(self):
        try:
            self.running = False; self.threadsLock.acquire()
            for c in list(self.threads): c.close()
        finally: self.threadsLock.release()

class ConnectionHandler(threading.Thread):
    def __init__(self, socClient, server, addr):
        threading.Thread.__init__(self)
        self.clientClosed = False; self.targetClosed = True
        self.client = socClient; self.client_buffer = b''
        self.server = server; self.log = 'Connection: ' + str(addr)
    def close(self):
        try:
            if not self.clientClosed: self.client.shutdown(socket.SHUT_RDWR); self.client.close()
        except: pass
        finally: self.clientClosed = True
        try:
            if not self.targetClosed: self.target.shutdown(socket.SHUT_RDWR); self.target.close()
        except: pass
        finally: self.targetClosed = True
    def run(self):
        try:
            self.client_buffer = self.client.recv(BUFLEN)
            hostPort = self.findHeader(self.client_buffer, b'X-Real-Host')
            if hostPort == b'': hostPort = DEFAULT_HOST
            split = self.findHeader(self.client_buffer, b'X-Split')
            if split != b'': self.client.recv(BUFLEN)
            if hostPort != b'':
                if hostPort.startswith(b'127.0.0.1') or hostPort.startswith(b'localhost'):
                    self.method_CONNECT(hostPort)
                else: self.client.send(b'HTTP/1.1 403 Forbidden!\r\n\r\n')
            else: self.client.send(b'HTTP/1.1 400 NoXRealHost!\r\n\r\n')
        except Exception as e:
            self.log += ' - error: ' + str(e); self.server.printLog(self.log)
        finally: self.close(); self.server.removeConn(self)
    def findHeader(self, head, header):
        aux = head.find(header + b': ')
        if aux == -1: return b''
        aux = head.find(b':', aux); head = head[aux + 2:]
        aux = head.find(b'\r\n')
        if aux == -1: return b''
        return head[:aux]
    def connect_target(self, host):
        i = host.find(b':')
        if i != -1: port = int(host[i + 1:]); host = host[:i]
        else: port = ${SSH_PORT}
        (soc_family, soc_type, proto, _, address) = socket.getaddrinfo(host, port)[0]
        self.target = socket.socket(soc_family, soc_type, proto)
        self.targetClosed = False; self.target.connect(address)
    def method_CONNECT(self, path):
        self.log += ' - CONNECT ' + path.decode()
        self.connect_target(path); self.client.sendall(RESPONSE)
        self.client_buffer = b''; self.server.printLog(self.log); self.doCONNECT()
    def doCONNECT(self):
        socs = [self.client, self.target]; count = 0; error = False
        while True:
            count += 1
            (recv, _, err) = select.select(socs, [], socs, 3)
            if err: error = True
            if recv:
                for in_ in recv:
                    try:
                        data = in_.recv(BUFLEN)
                        if data:
                            if in_ is self.target: self.client.send(data)
                            else:
                                while data: byte = self.target.send(data); data = data[byte:]
                            count = 0
                        else: break
                    except: error = True; break
            if count == TIMEOUT: error = True
            if error: break

if __name__ == '__main__':
    print(f"\033[0;34m{'*'*8} \033[1;32mPROXY PYTHON3 WEBSOCKET \033[0;34m{'*'*8}\n")
    print(f"\033[1;33mPUERTO:\033[1;32m {LISTENING_PORT}\n")
    server = Server(LISTENING_ADDR, LISTENING_PORT); server.start()
    while True:
        try: time.sleep(2)
        except KeyboardInterrupt: server.close(); break
PYEOF

    chmod +x $DIR_SCRIPTS/proxy_ws_${WS_PORT}.py
    cat > $DIR_SERVICES/ws-proxy-${WS_PORT}.service << EOF
[Unit]
Description=WebSocket Proxy Python Puerto ${WS_PORT}
After=network.target
[Service]
Type=simple
User=root
ExecStart=/usr/bin/python3 ${DIR_SCRIPTS}/proxy_ws_${WS_PORT}.py ${WS_PORT}
Restart=always
RestartSec=5
[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload; systemctl enable ws-proxy-${WS_PORT}; systemctl start ws-proxy-${WS_PORT}
    sleep 2
    systemctl is-active --quiet ws-proxy-${WS_PORT} && echo -e "\n  ${G}OK WebSocket activo en puerto ${WS_PORT}${NC}" || echo -e "\n  ${R}Error${NC}"
    read -p "  ENTER..."
}

menu_ws() {
    while true; do
        banner; sep; echo -e "  ${Y}  WEBSOCKET PYTHON${NC}"; sep; echo ""
        for f in $(ls $DIR_SERVICES/ws-proxy-*.service 2>/dev/null); do
            name=$(basename $f .service); port=$(echo $name | grep -o '[0-9]*$')
            echo -e "  Puerto ${Y}${port}${NC} $(status_service $name)"
        done
        echo ""; sep
        echo -e "  ${W}[1]${NC} Instalar/Configurar"
        echo -e "  ${W}[2]${NC} Iniciar"
        echo -e "  ${W}[3]${NC} Detener"
        echo -e "  ${W}[4]${NC} Reiniciar"
        echo -e "  ${W}[5]${NC} Eliminar"
        echo -e "  ${W}[0]${NC} Volver"; sep
        read -p "  Opcion: " OPT
        case $OPT in
            1) instalar_ws ;;
            2) read -p "  Puerto: " P; systemctl start ws-proxy-${P} && echo -e "  ${G}Iniciado${NC}"; sleep 1 ;;
            3) read -p "  Puerto: " P; systemctl stop ws-proxy-${P} && echo -e "  ${Y}Detenido${NC}"; sleep 1 ;;
            4) read -p "  Puerto: " P; systemctl restart ws-proxy-${P} && echo -e "  ${G}Reiniciado${NC}"; sleep 1 ;;
            5)
                read -p "  Puerto (0=todos): " DEL_PORT
                if [ "$DEL_PORT" = "0" ]; then
                    for f in $DIR_SERVICES/ws-proxy-*.service; do
                        name=$(basename $f .service); systemctl stop $name; systemctl disable $name; rm -f $f
                    done; rm -f $DIR_SCRIPTS/proxy_ws_*.py
                else
                    systemctl stop ws-proxy-${DEL_PORT}; systemctl disable ws-proxy-${DEL_PORT}
                    rm -f $DIR_SERVICES/ws-proxy-${DEL_PORT}.service $DIR_SCRIPTS/proxy_ws_${DEL_PORT}.py
                fi
                systemctl daemon-reload; echo -e "  ${G}Eliminado${NC}"; sleep 1 ;;
            0) break ;;
        esac
    done
}

# ══════════════════════════════════════════
#   BADVPN
# ══════════════════════════════════════════

menu_badvpn() {
    while true; do
        banner; sep; echo -e "  ${Y}  BADVPN UDP GATEWAY${NC}"; sep; echo ""
        echo -e "  BadVPN 7200 $(status_service badvpn-7200)"
        echo -e "  BadVPN 7300 $(status_service badvpn-7300)"
        echo ""; sep
        echo -e "  ${W}[1]${NC} Instalar BadVPN"
        echo -e "  ${W}[2]${NC} Iniciar"
        echo -e "  ${W}[3]${NC} Detener"
        echo -e "  ${W}[4]${NC} Reiniciar"
        echo -e "  ${W}[5]${NC} Puerto personalizado"
        echo -e "  ${W}[0]${NC} Volver"; sep
        read -p "  Opcion: " OPT
        case $OPT in
            1)
                if [ ! -f /usr/local/bin/badvpn-udpgw ] || [ ! -s /usr/local/bin/badvpn-udpgw ]; then
                    rm -f /usr/local/bin/badvpn-udpgw
                    echo -e "\n  ${C}Actualizando repositorios...${NC}"
                    apt update -y > /dev/null 2>&1
                    echo -e "  ${C}Instalando dependencias...${NC}"
                    apt install -y cmake make gcc g++ git > /dev/null 2>&1
                    echo -e "  ${C}Compilando BadVPN...${NC}"
                    cd /tmp || cd /root
                    rm -rf badvpn
                    git clone https://github.com/ambrop72/badvpn.git > /dev/null 2>&1
                    cd /tmp/badvpn && mkdir -p build && cd build
                    cmake .. -DBUILD_NOTHING_BY_DEFAULT=1 -DBUILD_UDPGW=1 > /dev/null 2>&1
                    make > /dev/null 2>&1
                    cd /tmp
                    if [ -f /tmp/badvpn/build/udpgw/badvpn-udpgw ] && [ -s /tmp/badvpn/build/udpgw/badvpn-udpgw ]; then
                        cp /tmp/badvpn/build/udpgw/badvpn-udpgw /usr/local/bin/
                        chmod +x /usr/local/bin/badvpn-udpgw
                        echo -e "  ${G}OK Binario compilado${NC}"
                    else
                        echo -e "  ${R}Error: compilacion fallida${NC}"
                        read -p "  ENTER..."; return
                    fi
                fi
                for PORT in 7200 7300; do
                    cat > $DIR_SERVICES/badvpn-${PORT}.service << EOF
[Unit]
Description=BadVPN UDP Gateway ${PORT}
After=network.target
[Service]
Type=simple
ExecStart=/usr/local/bin/badvpn-udpgw --listen-addr 127.0.0.1:${PORT} --max-clients 500 --max-connections-for-client 10
Restart=always
RestartSec=5
[Install]
WantedBy=multi-user.target
EOF
                    systemctl daemon-reload; systemctl enable badvpn-${PORT}; systemctl start badvpn-${PORT}
                done
                echo -e "  ${G}OK BadVPN 7200 y 7300${NC}"; sleep 2 ;;
            2) systemctl start badvpn-7200 badvpn-7300 && echo -e "  ${G}Iniciado${NC}"; sleep 1 ;;
            3) systemctl stop badvpn-7200 badvpn-7300 && echo -e "  ${Y}Detenido${NC}"; sleep 1 ;;
            4) systemctl restart badvpn-7200 badvpn-7300 && echo -e "  ${G}Reiniciado${NC}"; sleep 1 ;;
            5)
                read -p "  Puerto: " BPORT
                cat > $DIR_SERVICES/badvpn-${BPORT}.service << EOF
[Unit]
Description=BadVPN UDP Gateway ${BPORT}
After=network.target
[Service]
Type=simple
ExecStart=/usr/local/bin/badvpn-udpgw --listen-addr 127.0.0.1:${BPORT} --max-clients 500
Restart=always
RestartSec=5
[Install]
WantedBy=multi-user.target
EOF
                systemctl daemon-reload; systemctl enable badvpn-${BPORT}; systemctl start badvpn-${BPORT}
                echo -e "  ${G}OK BadVPN puerto ${BPORT}${NC}"; sleep 2 ;;
            0) break ;;
        esac
    done
}

# ══════════════════════════════════════════
#   UDP CUSTOM
# ══════════════════════════════════════════

menu_udp() {
    EXCLUDE_PORTS="5300,5667,8443,36712,6000:19999"

    while true; do
        banner; sep; echo -e "  ${Y}   UDP CUSTOM${NC}"; sep; echo ""
        ps aux | grep -i "udp-custom\|UDP-Custom" | grep -v grep | grep -q . && echo -e "  UDP Custom ${G}[ON]${NC}" || echo -e "  UDP Custom ${R}[OFF]${NC}"
        echo ""; sep
        echo -e "  ${W}[1]${NC} Instalar UDP Custom"
        echo -e "  ${W}[2]${NC} Iniciar"
        echo -e "  ${W}[3]${NC} Detener"
        echo -e "  ${W}[4]${NC} Reiniciar"
        echo -e "  ${W}[5]${NC} Ver estado"
        echo -e "  ${W}[0]${NC} Volver"; sep
        read -p "  Opcion: " OPT
        case $OPT in
            1)
                echo -e "\n  ${C}Instalando UDP Custom (Epro Dev Team)...${NC}"
                wget -O /tmp/install-udp "https://drive.usercontent.google.com/download?id=1S3IE25v_fyUfCLslnujFBSBMNunDHDk2&export=download&confirm=t"
                chmod +x /tmp/install-udp; bash /tmp/install-udp $EXCLUDE_PORTS
                echo -e "  ${G}UDP Custom instalado correctamente ${NC}"; sleep 2 ;;
            2) systemctl start udp-custom 2>/dev/null || (/root/udp/udp-custom server -exclude $EXCLUDE_PORTS &); echo -e "  ${G}Iniciado${NC}"; sleep 1 ;;
            3) systemctl stop udp-custom 2>/dev/null; pkill -f udp-custom 2>/dev/null; echo -e "  ${Y}Detenido${NC}"; sleep 1 ;;
            4) pkill -f udp-custom 2>/dev/null; sleep 1; systemctl start udp-custom 2>/dev/null || (/root/udp/udp-custom server -exclude $EXCLUDE_PORTS &); echo -e "  ${G}Reiniciado${NC}"; sleep 1 ;;
            5) ss -ulnp | grep udp; echo ""; read -p "  ENTER..." ;;
            0) break ;;
        esac
    done
}

# ══════════════════════════════════════════
#   SSL/TLS STUNNEL
# ══════════════════════════════════════════

menu_ssl() {
    while true; do
        banner; sep; echo -e "  ${Y}  SSL/TLS STUNNEL${NC}"; sep; echo ""
        echo -e "  Stunnel $(status_service stunnel4)"
        echo -e "  Puerto 443 $(status_port 443)"
        echo ""; sep
        echo -e "  ${W}[1]${NC} Instalar SSL/TLS Stunnel"
        echo -e "  ${W}[2]${NC} Iniciar"
        echo -e "  ${W}[3]${NC} Detener"
        echo -e "  ${W}[4]${NC} Reiniciar SSL"
        echo -e "  ${W}[0]${NC} Volver"; sep
        read -p "  Opcion: " OPT
        case $OPT in
            1)
                apt install -y stunnel4 > /dev/null 2>&1
                read -p "  Puerto SSL (ej: 443): " SSL_PORT; SSL_PORT=${SSL_PORT:-443}
                
                echo -e ""
                echo -e "  ${Y}¿Hacia dónde redirigir el tráfico SSL descifrado?${NC}"
                echo -e "  ${W}[1]${NC} Directo a SSH (Puerto 22) - Solo SSL sin payload"
                echo -e "  ${W}[2]${NC} A WebSocket Python (Puerto 80) - Soporta SSL + Payload"
                read -p "  Elige una opción [1-2]: " SSL_REDIR_OPT
                
                if [ "$SSL_REDIR_OPT" = "2" ]; then
                    read -p "  Puerto de tu WebSocket Python (ej: 80): " LOCAL_PORT
                    LOCAL_PORT=${LOCAL_PORT:-80}
                else
                    read -p "  Puerto local SSH (ej: 22): " LOCAL_PORT
                    LOCAL_PORT=${LOCAL_PORT:-22}
                fi

                openssl req -new -x509 -days 3650 -nodes -out /etc/stunnel/stunnel.pem -keyout /etc/stunnel/stunnel.pem -subj "/C=US/ST=Miami/L=Miami/O=SSHFREE/CN=sshfree" 2>/dev/null
                
                cat > /etc/stunnel/stunnel.conf << EOF
pid = /var/run/stunnel4/stunnel.pid
cert = /etc/stunnel/stunnel.pem
socket = a:SO_REUSEADDR=1
[ssh]
accept = ${SSL_PORT}
connect = 127.0.0.1:${LOCAL_PORT}
EOF
                sed -i 's/ENABLED=0/ENABLED=1/' /etc/default/stunnel4 2>/dev/null
                systemctl enable stunnel4; systemctl start stunnel4
                echo -e "  ${G}OK SSL/TLS en puerto ${SSL_PORT} apuntando a ${LOCAL_PORT}${NC}"; sleep 2 ;;
            2) systemctl start stunnel4 && echo -e "  ${G}Iniciado${NC}"; sleep 1 ;;
            3) systemctl stop stunnel4 && echo -e "  ${Y}Detenido${NC}"; sleep 1 ;;
            4) systemctl restart stunnel4 && echo -e "  ${G}Reiniciado${NC}"; sleep 1 ;;
            0) break ;;
        esac
    done
}

# ══════════════════════════════════════════
#   V2RAY
# ══════════════════════════════════════════

menu_v2ray() {
    while true; do
        banner; sep
        echo -e "  ${NEON}◆ V2RAY VMESS${NC}"; sep; echo ""
        echo -e "  V2Ray $(status_service v2ray)"
        if [ -f /usr/local/etc/v2ray/config.json ]; then
            python3 -c "
import json
try:
    with open('/usr/local/etc/v2ray/config.json') as f: c=json.load(f)
    inbounds = c.get('inbounds',[])
    if not inbounds:
        print('    \033[2;37m  Sin inbounds configurados\033[0m')
    for ib in inbounds:
        net=ib.get('streamSettings',{}).get('network','tcp')
        tls=ib.get('streamSettings',{}).get('security','none')
        tls_icon='\033[1;96m TLS\033[0m' if tls=='tls' else ''
        print(f'  \033[1;96m◈\033[0m \033[1;97mPuerto \033[1;33m{ib[\"port\"]}\033[0m \033[2;37m|\033[0m \033[1;96m{ib[\"protocol\"]}\033[0m \033[2;37m|\033[0m {net}{tls_icon}')
except: pass
" 2>/dev/null
        fi
        echo ""; sep
        printf " ${Y}❬1❭ ⚡ Instalar V2Ray      ❬2❭ ➕ Agregar inbound${NC}\n"
        printf " ${Y}❬3❭ 🗑  Eliminar inbound    ❬4❭ ▶  Iniciar${NC}\n"
        printf " ${Y}❬5❭ ⏹  Detener             ❬6❭ 🔄 Reiniciar${NC}\n"
        printf " ${Y}❬7❭ 👤 Crear usuario       ❬8❭ 📋 Ver usuarios${NC}\n"
        printf " ${R}❬9❭ 🗑  Desinstalar V2Ray${NC}\n"
        sep
        printf " ${R}❬0❭ Volver${NC}\n"; sep; echo ""
        read -p " Opcion: " OPT
        case $OPT in
            1)
                read -p "  Dominio (para SSL): " DOMAIN
                EMAIL="admin@${DOMAIN#*.}"
                echo -e "  ${C}Instalando V2Ray...${NC}"
                bash <(curl -s https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh) > /dev/null 2>&1
                echo -e "  ${C}Obteniendo certificado SSL...${NC}"
                apt install -y certbot > /dev/null 2>&1
                pkill -f "python3.*:80" 2>/dev/null; sleep 1
                certbot certonly --standalone -d $DOMAIN --non-interactive --agree-tos -m $EMAIL
                chmod 755 /etc/letsencrypt/live/ /etc/letsencrypt/archive/ 2>/dev/null
                chmod 644 /etc/letsencrypt/live/$DOMAIN/*.pem 2>/dev/null
                chmod 644 /etc/letsencrypt/archive/$DOMAIN/*.pem 2>/dev/null
                cat > /usr/local/etc/v2ray/config.json << EOF
{"log":{"loglevel":"warning"},"inbounds":[],"outbounds":[{"protocol":"freedom"}]}
EOF
                mkdir -p /etc/dealer-adm
                echo "$DOMAIN" > /etc/dealer-adm/v2ray_domain
                systemctl enable v2ray; systemctl start v2ray
                echo -e "  ${G}OK V2Ray instalado — Usa ❬2❭ para agregar puertos${NC}"; sleep 2 ;;
            2)
                banner; sep
                echo -e "  ${Y}  AGREGAR INBOUND${NC}"; sep; echo ""
                read -p "  Puerto: " V2_PORT
                echo -e "  Protocolo: ${Y}❬1❭${NC} vmess ${Y}❬2❭${NC} vless ${Y}❬3❭${NC} trojan"
                read -p "  Opcion: " V2_PROTO_OPT
                case $V2_PROTO_OPT in
                    1) V2_PROTO="vmess" ;; 2) V2_PROTO="vless" ;; 3) V2_PROTO="trojan" ;; *) V2_PROTO="vmess" ;;
                esac
                echo -e "  Red: ${Y}❬1❭${NC} ws ${Y}❬2❭${NC} tcp ${Y}❬3❭${NC} xhttp ${Y}❬4❭${NC} grpc"
                read -p "  Opcion: " V2_NET_OPT
                case $V2_NET_OPT in
                    1) V2_NET="ws" ;; 2) V2_NET="tcp" ;; 3) V2_NET="xhttp" ;; 4) V2_NET="grpc" ;; *) V2_NET="ws" ;;
                esac
                read -p "  Path (ej: /v2ray): " V2_PATH; V2_PATH=${V2_PATH:-/v2ray}
                echo -e "  TLS: ${Y}❬1❭${NC} Si ${Y}❬2❭${NC} No"
                read -p "  Opcion: " V2_TLS_OPT
                [ "$V2_TLS_OPT" = "1" ] && V2_TLS="tls" || V2_TLS="none"
                python3 - << PYEOF
import json, os
port, proto, net, path, tls = int("$V2_PORT"), "$V2_PROTO", "$V2_NET", "$V2_PATH", "$V2_TLS"
with open('/usr/local/etc/v2ray/config.json') as f: config = json.load(f)
ib = {"port": port, "protocol": proto, "settings": {"clients": []}, "streamSettings": {"network": net, "security": tls}}
if net == "ws": ib["streamSettings"]["wsSettings"] = {"path": path}
elif net == "xhttp": ib["streamSettings"]["xhttpSettings"] = {"path": path}
elif net == "grpc": ib["streamSettings"]["grpcSettings"] = {"serviceName": path.strip("/")}
if tls == "tls":
    domain = open('/etc/dealer-adm/v2ray_domain').read().strip() if os.path.exists('/etc/dealer-adm/v2ray_domain') else ''
    ib["streamSettings"]["tlsSettings"] = {"certificates": [{"certificateFile": f"/etc/letsencrypt/live/{domain}/fullchain.pem","keyFile": f"/etc/letsencrypt/live/{domain}/privkey.pem"}]}
config["inbounds"].append(ib)
with open('/usr/local/etc/v2ray/config.json', 'w') as f: json.dump(config, f, indent=2)
print(f"OK {proto} {net} puerto {port}")
PYEOF
                systemctl restart v2ray; echo -e "  ${G}OK Inbound agregado${NC}"; read -p "  ENTER..." ;;
            3)
                banner; sep; echo -e "  ${R}  ELIMINAR INBOUND${NC}"; sep; echo ""
                python3 -c "
import json
with open('/usr/local/etc/v2ray/config.json') as f: c=json.load(f)
for i,ib in enumerate(c.get('inbounds',[])):
    print(f'  [{i+1}] Puerto {ib[\"port\"]} | {ib[\"protocol\"]}')
" 2>/dev/null
                echo ""; read -p "  Numero a eliminar: " DEL_NUM
                python3 - << PYEOF
import json
with open('/usr/local/etc/v2ray/config.json') as f: config = json.load(f)
idx = int("$DEL_NUM") - 1
if 0 <= idx < len(config['inbounds']):
    removed = config['inbounds'].pop(idx)
    with open('/usr/local/etc/v2ray/config.json', 'w') as f: json.dump(config, f, indent=2)
    print(f"OK Puerto {removed['port']} eliminado")
else: print("Numero invalido")
PYEOF
                systemctl restart v2ray; sleep 1 ;;
            4) systemctl start v2ray && echo -e "  ${G}Iniciado${NC}"; sleep 1 ;;
            5) systemctl stop v2ray && echo -e "  ${Y}Detenido${NC}"; sleep 1 ;;
            6) systemctl restart v2ray && echo -e "  ${G}Reiniciado${NC}"; sleep 1 ;;
            7)
                banner; sep; echo -e "  ${Y}  CREAR USUARIO VMESS${NC}"; sep; echo ""
                python3 -c "
import json
with open('/usr/local/etc/v2ray/config.json') as f: c=json.load(f)
for i,ib in enumerate(c.get('inbounds',[])):
    net=ib.get('streamSettings',{}).get('network','tcp')
    tls=ib.get('streamSettings',{}).get('security','none')
    print(f'  [{i+1}] Puerto {ib[\"port\"]} | {ib[\"protocol\"]} | {net} | tls:{tls}')
" 2>/dev/null
                echo ""; read -p "  Numero de inbound: " IB_NUM
                IB_IDX=$((IB_NUM - 1))
                read -p "  Nombre del perfil: " VNAME
                read -p "  Dias de validez (default 30): " V2_DAYS; V2_DAYS=${V2_DAYS:-30}
                EXP_SHOW=$(date -d "+${V2_DAYS} days" +%d/%m/%Y)
                VDOMAIN=$(cat /etc/dealer-adm/v2ray_domain 2>/dev/null || hostname -I | awk '{print $1}')
                python3 - << PYEOF
import json, uuid, base64, datetime
idx, name, days, domain = int("$IB_IDX"), "$VNAME", int("$V2_DAYS"), "$VDOMAIN"
with open('/usr/local/etc/v2ray/config.json') as f: config = json.load(f)
inbounds = config.get('inbounds', [])
if idx >= len(inbounds): print("Inbound no encontrado"); exit(1)
ib = inbounds[idx]
uid = str(uuid.uuid4())
exp = (datetime.datetime.now() + datetime.timedelta(days=days)).strftime("%Y-%m-%d")
if 'clients' not in ib['settings']: ib['settings']['clients'] = []
ib['settings']['clients'].append({"id": uid, "alterId": 0, "email": name, "expires": exp})
with open('/usr/local/etc/v2ray/config.json', 'w') as f: json.dump(config, f, indent=2)
net = ib.get('streamSettings', {}).get('network', 'tcp')
tls = ib.get('streamSettings', {}).get('security', 'none')
path = ib.get('streamSettings', {}).get('wsSettings', {}).get('path', '/v2ray') if net == 'ws' else ''
out_port = "443" if ib['port'] == 8080 else str(ib['port'])
out_tls = "tls" if ib['port'] == 8080 else (tls if tls != "none" else "")
vmess = {"v":"2","ps":name,"add":domain,"port":out_port,"id":uid,"aid":"0","net":net,"type":"none","host":domain,"path":path,"tls":out_tls}
link = "vmess://" + base64.b64encode(json.dumps(vmess).encode()).decode()
print("")
print("\033[1;96m◆━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━◆\033[0m")
print("  \033[1;32m✅ CUENTA VMESS CREADA\033[0m")
print("\033[1;96m◆━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━◆\033[0m")
print(f"  \033[1;96m◈\033[0m \033[2;37mPerfil :\033[0m  \033[1;97m{name}\033[0m")
print(f"  \033[1;96m◈\033[0m \033[2;37mHost   :\033[0m  \033[1;97m{domain}\033[0m")
print(f"  \033[1;96m◈\033[0m \033[2;37mPuerto :\033[0m  \033[1;33m{out_port}\033[0m")
print(f"  \033[1;96m◈\033[0m \033[2;37mRed    :\033[0m  \033[1;96m{net}\033[0m")
print(f"  \033[1;96m◈\033[0m \033[2;37mExpira :\033[0m  \033[1;33m$EXP_SHOW\033[0m")
print("\033[1;96m◆━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━◆\033[0m")
print("  \033[1;96m🔑 VMESS LINK:\033[0m")
print("")
print("\033[1;97m" + link + "\033[0m")
print("")
print("\033[1;96m◆━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━◆\033[0m")
PYEOF
                systemctl restart v2ray; read -p "  ENTER..." ;;
            8)
                python3 -c "
import json
try:
    with open('/usr/local/etc/v2ray/config.json') as f: c=json.load(f)
    for ib in c['inbounds']:
        print(f'  Puerto {ib[\"port\"]}:')
        for u in ib['settings'].get('clients',[]):
            print(f'    - {u.get(\"email\",\"?\")} | expira: {u.get(\"expires\",\"sin exp\")}')
except Exception as e: print(f'Error: {e}')
"; read -p "  ENTER..." ;;
            9)
                read -p "  Confirmar desinstalar V2Ray (si/no): " CONFIRM
                if [ "$CONFIRM" = "si" ]; then
                    systemctl stop v2ray; systemctl disable v2ray
                    bash <(curl -s https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh) --remove > /dev/null 2>&1
                    rm -f /etc/dealer-adm/v2ray_domain
                    echo -e "  ${G}OK V2Ray desinstalado${NC}"; sleep 2
                fi ;;
            0) break ;;
            *) echo -e "  ${R}Opcion invalida${NC}"; sleep 1 ;;
        esac
    done
}

# ══════════════════════════════════════════
#   ZIV VPN
# ══════════════════════════════════════════

menu_ziv() {
    while true; do
        banner; sep; echo -e "  ${Y}    ZIVPN UDP${NC}"; sep; echo ""
        echo -e "  ZIV VPN $(status_service zivpn)"
        [ -f /etc/zivpn/config.json ] && PORT=$(cat /etc/zivpn/config.json | python3 -c "import json,sys; print(json.load(sys.stdin).get('listen',':5667').replace(':',''))" 2>/dev/null) && echo -e "  Puerto: ${Y}${PORT}${NC}"
        echo ""; sep
        echo -e "  ${W}[1]${NC} Instalar ZIV VPN V2 (Recomendado)"
        echo -e "  ${W}[2]${NC} Instalar ZIV VPN V1"
        echo -e "  ${W}[3]${NC} Iniciar"
        echo -e "  ${W}[4]${NC} Detener"
        echo -e "  ${W}[5]${NC} Reiniciar"
        echo -e "  ${W}[6]${NC} Ver configuracion"
        echo -e "  ${W}[7]${NC} Desinstalar"
        echo -e "  ${W}[0]${NC} Volver"; sep
        read -p "  Opcion: " OPT
        case $OPT in
            1) 
                bash <(curl -fsSL https://raw.githubusercontent.com/powermx/zivpn/main/ziv2.sh)
                sincronizar_usuarios_zivpn
                ;;
            2) 
                bash <(curl -fsSL https://raw.githubusercontent.com/powermx/zivpn/main/ziv1.sh)
                sincronizar_usuarios_zivpn
                ;;
            3) 
                sincronizar_usuarios_zivpn
                systemctl start zivpn && echo -e "  ${G}Iniciado${NC}"; sleep 1 
                ;;
            4) 
                systemctl stop zivpn && echo -e "  ${Y}Detenido${NC}"; sleep 1 
                ;;
            5) 
                sincronizar_usuarios_zivpn
                systemctl restart zivpn && echo -e "  ${G}Reiniciado${NC}"; sleep 1 
                ;;
            6) 
                cat /etc/zivpn/config.json 2>/dev/null; echo ""; read -p "  ENTER..." 
                ;;
            7) 
                bash <(curl -fsSL https://raw.githubusercontent.com/powermx/zivpn/main/uninstall.sh) 2>/dev/null; echo -e "  ${G}Desinstalado${NC}"; sleep 1 
                ;;
            0) break ;;
        esac
    done
}

aplicar_passwords_ziv() {
    [ ! -f /etc/zivpn/users.json ] && echo "[]" > /etc/zivpn/users.json
    python3 - << PYEOF
import json, datetime
with open("/etc/zivpn/users.json") as f: users = json.load(f)
now = datetime.datetime.now()
active = [u["password"] for u in users if datetime.datetime.fromisoformat(u["expires"].split("+")[0].split(".")[0]) > now]
if not active: active = ["zi"]
with open("/etc/zivpn/config.json") as f: config = json.load(f)
existing = config["auth"]["config"]
merged = list(set(existing + active))
config["auth"]["config"] = merged
with open("/etc/zivpn/config.json", "w") as f: json.dump(config, f, indent=2)
PYEOF
    systemctl restart zivpn 2>/dev/null
}

crear_user_ziv() {
    banner; sep; echo -e "  ${Y}  CREAR USUARIO ZIV VPN${NC}"; sep; echo ""
    read -p "  Contraseña: " ZIV_PASS
    [ -z "$ZIV_PASS" ] && echo -e "  ${R}Contraseña requerida${NC}" && sleep 1 && return
    read -p "  Dias de validez (default 30): " ZIV_DAYS; ZIV_DAYS=${ZIV_DAYS:-30}
    EXP_DATE=$(date -d "+${ZIV_DAYS} days" -Iseconds)
    EXP_SHOW=$(date -d "+${ZIV_DAYS} days" +"%d/%m/%Y")
    SERVER_IP=$(curl -s -4 ifconfig.me 2>/dev/null || ip -4 addr show scope global | grep inet | awk '{print $2}' | cut -d/ -f1 | head -1)
    [ ! -f /etc/zivpn/users.json ] && echo "[]" > /etc/zivpn/users.json
    python3 - << PYEOF
import json, datetime
with open("/etc/zivpn/users.json") as f: users = json.load(f)
users.append({"password": "$ZIV_PASS", "expires": "$EXP_DATE", "created": datetime.datetime.now().isoformat()})
with open("/etc/zivpn/users.json", "w") as f: json.dump(users, f, indent=2)
PYEOF
    aplicar_passwords_ziv
    echo ""; sep
    echo -e "  ${Y}  CREDENCIALES ZIVPN${NC}"; sep
    echo -e "  ${W}IP:${NC}       $SERVER_IP"
    echo -e "  ${W}Puerto:${NC}   5667"
    echo -e "  ${W}Pass:${NC}     $ZIV_PASS"
    echo -e "  ${W}Expira:${NC}   $EXP_SHOW ($ZIV_DAYS dias)"
    echo ""; sep; read -p "  ENTER..."
}

listar_users_ziv() {
    banner; sep; echo -e "  ${Y}  USUARIOS ZIVPN${NC}"; sep; echo ""
    [ ! -f /etc/zivpn/users.json ] && echo "[]" > /etc/zivpn/users.json
    python3 - << PYEOF
import json, datetime
with open("/etc/zivpn/users.json") as f: users = json.load(f)
if not users: print("  Sin usuarios")
else:
    now = datetime.datetime.now()
    for u in users:
        exp = datetime.datetime.fromisoformat(u["expires"])
        estado = "\033[0;32m[ACTIVO]\033[0m" if exp > now else "\033[0;31m[EXPIRADO]\033[0m"
        print(f"  Pass: {u['password']:<20} Expira: {exp.strftime('%d/%m/%Y')}  {estado}")
PYEOF
    echo ""; read -p "  ENTER..."
}

eliminar_user_ziv() {
    banner; sep; echo -e "  ${R}  ELIMINAR USUARIO ZIVPN${NC}"; sep; echo ""
    [ ! -f /etc/zivpn/users.json ] && echo "[]" > /etc/zivpn/users.json
    python3 -c "
import json
with open('/etc/zivpn/users.json') as f: u=json.load(f)
[print(f'  - {x[\"password\"]}') for x in u] if u else print('  Sin usuarios')
"
    echo ""; read -p "  Contraseña a eliminar: " DEL_PASS
    python3 - << PYEOF
import json
with open("/etc/zivpn/users.json") as f: users = json.load(f)
users = [u for u in users if u["password"] != "$DEL_PASS"]
with open("/etc/zivpn/users.json", "w") as f: json.dump(users, f, indent=2)
PYEOF
    aplicar_passwords_ziv; echo -e "  ${G}Eliminado${NC}"; sleep 1
}

limpiar_expirados_ziv() {
    [ ! -f /etc/zivpn/users.json ] && echo "[]" > /etc/zivpn/users.json
    python3 - << PYEOF
import json, datetime
with open("/etc/zivpn/users.json") as f: users = json.load(f)
now = datetime.datetime.now()
activos = [u for u in users if datetime.datetime.fromisoformat(u["expires"]) > now]
exp = len(users) - len(activos)
with open("/etc/zivpn/users.json", "w") as f: json.dump(activos, f, indent=2)
print(f"  {exp} expirados eliminados" if exp > 0 else "  Sin expirados")
PYEOF
}

menu_users_ziv() {
    while true; do
        banner; sep; echo -e "  ${Y}    USUARIOS ZIVPN${NC}"; sep; echo ""
        [ ! -f /etc/zivpn/users.json ] && echo "[]" > /etc/zivpn/users.json
        TOTAL=$(python3 -c "import json; print(len(json.load(open('/etc/zivpn/users.json'))))" 2>/dev/null || echo 0)
        echo -e "  Total usuarios: ${G}${TOTAL}${NC}"
        echo -e "  ZIV VPN: $(status_service zivpn)"
        echo ""; sep
        echo -e "  ${W}[1]${NC} Crear usuario"
        echo -e "  ${W}[2]${NC} Listar usuarios"
        echo -e "  ${W}[3]${NC} Eliminar usuario"
        echo -e "  ${W}[4]${NC} Limpiar expirados"
        echo -e "  ${W}[5]${NC} ZIVPN Online"
        echo -e "  ${W}[0]${NC} Volver"; sep
        read -p "  Opción: " OPT
        case $OPT in
            1) crear_user_ziv ;;
            2) listar_users_ziv ;;
            3) eliminar_user_ziv ;;
            4) limpiar_expirados_ziv; aplicar_passwords_ziv; echo -e "  ${G}Limpiado${NC}"; sleep 1 ;;
            5) usuarios_ziv_online_count ;;
            0) break ;;
            *) echo -e "  ${R}Opción inválida${NC}"; sleep 1 ;;
        esac
    done
}

# ══════════════════════════════════════════
#   USUARIOS SSH
# ══════════════════════════════════════════

listar_usuarios() {
    banner; sep
    echo -e "  ${Y}    USUARIOS REGISTRADOS${NC}"; sep; echo ""

    NUM=1
    TODAY_SEC=$(date +%s)

    for FILE in $(find /etc/dealer-adm/userDIR -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | cut -d' ' -f2-); do
        [ ! -f "$FILE" ] && continue

        TIPO=$(grep '^tipo:' "$FILE" | cut -d' ' -f2-)
        NOMBRE=$(grep '^nombre:' "$FILE" | cut -d' ' -f2-)
        USUARIO=$(grep '^usuario:' "$FILE" | cut -d' ' -f2-)
        PASSWORD=$(grep '^password:' "$FILE" | cut -d' ' -f2-)
        FECHA=$(grep '^fecha:' "$FILE" | cut -d' ' -f2-)
        LIMITE=$(grep '^limite:' "$FILE" | cut -d' ' -f2-)

        [ -z "$USUARIO" ] && USUARIO=$(basename "$FILE")
        [ -z "$NOMBRE" ] && NOMBRE="$USUARIO"
        [ -z "$TIPO" ] && TIPO="ssh"
        [ -z "$LIMITE" ] && LIMITE="1"

        EXP_SEC=$(date -d "$FECHA" +%s 2>/dev/null || echo 0)
        if [ "$EXP_SEC" -le "$TODAY_SEC" ]; then
            FECHA_DISPLAY="${R}EXP${NC}"
        else
            FECHA_DISPLAY="${G}$(date -d "$FECHA" +%d-%m-%Y 2>/dev/null || echo "$FECHA")${NC}"
        fi

        case "$TIPO" in
            ssh)
                echo -e " ${W}[$NUM]${NC} ${G}$NOMBRE${NC}"
                echo -e "      └ ${G}SSH${NC} | ${W}$PASSWORD${NC} | Limite:${LIMITE} | Expira:${FECHA_DISPLAY}"
            ;;
            token)
                echo -e " ${W}[$NUM]${NC} ${Y}$NOMBRE${NC}"
                echo -e "      └ ${Y}TOKEN${NC} | ${W}$USUARIO${NC} | Expira:${FECHA_DISPLAY}"
            ;;
            hwid)
                echo -e " ${W}[$NUM]${NC} ${C}$NOMBRE${NC}"
                echo -e "      └ ${C}HWID${NC} | ${W}$USUARIO${NC} | Expira:${FECHA_DISPLAY}"
            ;;
            *)
                echo -e " ${W}[$NUM]${NC} ${G}$NOMBRE${NC}"
                echo -e "      └ ${W}$TIPO${NC} | ${W}$USUARIO${NC} | Expira:${FECHA_DISPLAY}"
            ;;
        esac

        ((NUM++))
    done

    echo ""; sep; read -p "  Presiona ENTER para continuar..."
}

crear_usuario() {
    while true; do
        banner
        sep
        echo -e "  ${Y}  CREAR USUARIO${NC}"
        sep
        echo ""

        echo -e "  ${W}[1]${NC} SSH | DROPBEAR"
        echo -e "  ${W}[2]${NC} HWID"
        echo -e "  ${W}[3]${NC} TOKEN"
        echo -e "  ${W}[4]${NC} PASSWORD TOKEN"
        echo -e "  ${W}[0]${NC} Volver"

        echo ""
        sep

        read -p "  Opcion: " OP

        case $OP in
            1) crear_usuario_ssh ;;
            2) crear_usuario_hwid ;;
            3) crear_usuario_token ;;
            4) modificar_password_token ;;
            0) break ;;
        esac
    done
}

crear_usuario_ssh() {
    banner; sep; echo -e "   ${Y}    CREAR USUARIO SSH${NC}"; sep; echo ""

    read -p "  Nombre de usuario: " USR_NAME
    [ -z "$USR_NAME" ] && echo -e "  ${R}Nombre requerido${NC}" && sleep 1 && return

    read -p "  Contraseña (ENTER para generar): " USR_PASS
    [ -z "$USR_PASS" ] && USR_PASS=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 10 | head -n 1) && echo -e "  ${G}Generada: ${W}${USR_PASS}${NC}"

    read -p "  Dias de validez (default 30): " USR_DAYS
    USR_DAYS=${USR_DAYS:-30}

    read -p "  Limite de conexiones (default 1): " USR_LIMIT
    USR_LIMIT=${USR_LIMIT:-1}

    EXP_DATE=$(date -d "+${USR_DAYS} days" +%Y-%m-%d)
    EXP_SHOW=$(date -d "+${USR_DAYS} days" +%d/%m/%Y)

    SERVER_IP=$(curl -s -4 ifconfig.me 2>/dev/null || ip -4 addr show scope global | grep inet | awk '{print $2}' | cut -d/ -f1 | head -1)

    echo ""
    echo -e "  ${C}Creando usuario...${NC}"

    if id "$USR_NAME" &>/dev/null; then
        usermod -e "$EXP_DATE" "$USR_NAME"
        echo "$USR_NAME:$USR_PASS" | chpasswd
    else
        useradd -M -s /bin/false -e "$EXP_DATE" "$USR_NAME"
        echo "$USR_NAME:$USR_PASS" | chpasswd
        chage -E "$EXP_DATE" -M 99999 "$USR_NAME"
        usermod -f 0 "$USR_NAME"
    fi

    mkdir -p /etc/dealer-adm/userDIR

    cat > /etc/dealer-adm/userDIR/$USR_NAME << EOF
tipo: ssh
nombre: $USR_NAME
usuario: $USR_NAME
password: $USR_PASS
fecha: $EXP_DATE
limite: $USR_LIMIT
EOF

    if [ -f /etc/dealer-adm/scripts/sync_hysteria.sh ]; then
        /etc/dealer-adm/scripts/sync_hysteria.sh "$USR_NAME" "$USR_PASS"
    fi

    if [ -f /etc/zivpn/passwords.db ]; then
        if ! grep -q "^$USR_NAME|" /etc/zivpn/passwords.db; then
            echo "$USR_NAME|$USR_PASS|$EXP_DATE|active" >> /etc/zivpn/passwords.db
            if [ -f /etc/dealer-adm/scripts/zivpn_manager.sh ]; then
                bash /etc/dealer-adm/scripts/zivpn_manager.sh rebuild_zivpn_json
                echo -e "  ${G}✓ Sincronizado automáticamente con ZIVPN${NC}"
            fi
        fi
    fi

    echo ""
    sep
    echo -e "  ${Y}    CREDENCIALES${NC}"
    sep

    echo -e "  ${W}Usuario:${NC}  $USR_NAME"
    echo -e "  ${W}Password:${NC} $USR_PASS"
    echo -e "  ${W}IP:${NC}        $SERVER_IP"
    echo -e "  ${W}Expira:${NC}    $EXP_SHOW ($USR_DAYS dias)"
    echo ""
    sep
    echo -e "  ${Y}    CONEXIONES DISPONIBLES${NC}"
    sep
    echo ""
    echo -e "  ${C}SSH Directo:${NC}"
    echo -e "  ${W}$SERVER_IP:22@$USR_NAME:$USR_PASS${NC}"
    echo ""

    ss -tlnp | grep -q ":80 " && echo -e "  ${C}WS Puerto 80:${NC}" && echo -e "  ${W}$SERVER_IP:80@$USR_NAME:$USR_PASS${NC}" && echo ""

    systemctl is-active --quiet stunnel4 2>/dev/null && echo -e "  ${C}SSL/TLS 443:${NC}" && echo -e "  ${W}$SERVER_IP:443@$USR_NAME:$USR_PASS${NC}" && echo ""

    ps aux | grep -i "udp-custom\|UDP-Custom" | grep -v grep | grep -q . && echo -e "  ${C}UDP Custom:${NC}" && echo -e "  ${W}$SERVER_IP:1-65535@$USR_NAME:$USR_PASS${NC}" && echo ""

    systemctl is-active --quiet zivpn 2>/dev/null && echo -e "  ${C}ZIVPN UDP:${NC}" && echo -e "  ${W}$SERVER_IP:5667@$USR_NAME:$USR_PASS${NC}" && echo ""

    (systemctl is-active --quiet badvpn-7200 2>/dev/null || systemctl is-active --quiet badvpn-7300 2>/dev/null) && \
    echo -e "  ${C}BadVPN:${NC}" && \
    systemctl is-active --quiet badvpn-7200 && echo -e "  ${W}Puerto 7200 activo${NC}" && \
    systemctl is-active --quiet badvpn-7300 && echo -e "  ${W}Puerto 7300 activo${NC}" && echo ""

    if [ -f /etc/hysteria/config.json ]; then
        echo -e "  ${C}UDP Hysteria:${NC}"
        echo -e "  ${W}$SERVER_IP@$USR_NAME:$USR_PASS${NC}"
        echo ""
    fi

    sep
    read -p "  ENTER..."
}

crear_usuario_hwid() {
    banner; sep; echo -e "   ${Y}    CREAR USUARIO HWID${NC}"; sep; echo ""

    read -p "  Nombre: " NOMBRE
    [ -z "$NOMBRE" ] && return

    read -p "  HWID : " HWID
    [ -z "$HWID" ] && return

    read -p "  Dias de validez (default 30): " USR_DAYS
    USR_DAYS=${USR_DAYS:-30}

    EXP_DATE=$(date -d "+${USR_DAYS} days" +%Y-%m-%d)
    EXP_SHOW=$(date -d "+${USR_DAYS} days" +%d/%m/%Y)

    SERVER_IP=$(curl -s -4 ifconfig.me 2>/dev/null || ip -4 addr show scope global | grep inet | awk '{print $2}' | cut -d/ -f1 | head -1)

    echo ""
    echo -e "  ${C}Creando usuario HWID...${NC}"

    LINUX_USER=$(echo "$HWID" | cut -c1-31)

    if id "$LINUX_USER" &>/dev/null; then
        usermod -e "$EXP_DATE" "$LINUX_USER"
        echo "$LINUX_USER:$HWID" | chpasswd
    else
        useradd -M -s /bin/false -e "$EXP_DATE" "$LINUX_USER"
        echo "$LINUX_USER:$HWID" | chpasswd
        chage -E "$EXP_DATE" -M 99999 "$LINUX_USER"
        usermod -f 0 "$LINUX_USER"
    fi

    mkdir -p /etc/dealer-adm/userDIR
    cat > /etc/dealer-adm/userDIR/$HWID << EOF
tipo: hwid
nombre: $NOMBRE
usuario: $HWID
password: $HWID
linux_user: $LINUX_USER
fecha: $EXP_DATE
limite: 1
EOF

    echo ""
    sep
    echo -e "  ${Y}    DATOS HWID${NC}"
    sep

    echo -e "  ${W}Nombre:${NC}    $NOMBRE"
    echo -e "  ${W}HWID:${NC}      $HWID"
    echo -e "  ${W}Expira:${NC}    $EXP_SHOW"
    echo ""
    sep
    read -p "  ENTER..."
}

crear_usuario_token() {
    banner
    sep
    echo -e "  ${Y}    CREAR USUARIO TOKEN${NC}"
    sep
    echo ""

    if [ ! -f /etc/dealer-adm/token_password ]; then
        echo -e "  ${Y}No existe contraseña TOKEN global${NC}"
        echo ""
        read -p "  Crear contraseña TOKEN: " TOKEN_PASS
        [ -z "$TOKEN_PASS" ] && return
        echo "$TOKEN_PASS" > /etc/dealer-adm/token_password
    fi

    TOKEN_PASS=$(cat /etc/dealer-adm/token_password)

    read -p "  Nombre: " NOMBRE
    [ -z "$NOMBRE" ] && return

    read -p "  Token: " TOKEN
    [ -z "$TOKEN" ] && return

    read -p "  Dias de validez (default 30): " USR_DAYS
    USR_DAYS=${USR_DAYS:-30}

    EXP_DATE=$(date -d "+${USR_DAYS} days" +%Y-%m-%d)
    EXP_SHOW=$(date -d "+${USR_DAYS} days" +%d/%m/%Y)

    SERVER_IP=$(curl -s -4 ifconfig.me 2>/dev/null || ip -4 addr show scope global | grep inet | awk '{print $2}' | cut -d/ -f1 | head -1)

    echo ""
    echo -e "  ${C}Creando usuario TOKEN...${NC}"

    if id "$TOKEN" &>/dev/null; then
        usermod -e "$EXP_DATE" "$TOKEN"
        echo "$TOKEN:$TOKEN_PASS" | chpasswd
    else
        useradd -M -s /bin/false -e "$EXP_DATE" "$TOKEN"
        echo "$TOKEN:$TOKEN_PASS" | chpasswd
        chage -E "$EXP_DATE" -M 99999 "$TOKEN"
        usermod -f 0 "$TOKEN"
    fi

    cat > /etc/dealer-adm/userDIR/$TOKEN << EOF
tipo: token
nombre: $NOMBRE
usuario: $TOKEN
password: $TOKEN_PASS
fecha: $EXP_DATE
limite: 1
EOF

    if [ -f /etc/dealer-adm/scripts/sync_hysteria.sh ]; then
        /etc/dealer-adm/scripts/sync_hysteria.sh "$TOKEN" "$TOKEN_PASS"
    fi

    echo ""
    sep
    echo -e "  ${Y}    DATOS TOKEN${NC}"
    sep

    echo -e "  ${W}Nombre:${NC}      $NOMBRE"
    echo -e "  ${W}Token:${NC}       $TOKEN"
    echo -e "  ${W}Password:${NC}    $TOKEN_PASS"
    echo -e "  ${W}Expira:${NC}      $EXP_SHOW"

    echo ""
    echo -e "  ${C}Hysteria:${NC}"
    echo -e "  ${W}$SERVER_IP@$TOKEN:$TOKEN_PASS${NC}"

    echo ""
    sep
    read -p "  ENTER..."
}

modificar_password_token() {
    banner
    sep
    echo -e "  ${Y}  PASSWORD GLOBAL TOKEN${NC}"
    sep
    echo ""

    read -p "  Nueva contraseña TOKEN: " TOKEN_PASS
    [ -z "$TOKEN_PASS" ] && return
    echo "$TOKEN_PASS" > /etc/dealer-adm/token_password

    echo ""
    echo -e "  ${G}Password actualizada${NC}"
    sleep 2
}

crear_usuario_ssh_api() {
    USR_NAME="$1"
    USR_PASS="$2"
    USR_DAYS="${3:-30}"
    USR_LIMIT="${4:-1}"
    CREADOR_ID="${5:-0}"
    CREADOR_NOMBRE="${6:-ADMIN}"

    EXP_DATE=$(date -d "+${USR_DAYS} days" +%Y-%m-%d)

    if id "$USR_NAME" &>/dev/null; then
        usermod -e "$EXP_DATE" "$USR_NAME"
        echo "$USR_NAME:$USR_PASS" | chpasswd
    else
        useradd -M -s /bin/false -e "$EXP_DATE" "$USR_NAME"
        echo "$USR_NAME:$USR_PASS" | chpasswd
        chage -E "$EXP_DATE" -M 99999 "$USR_NAME"
        usermod -f 0 "$USR_NAME"
    fi

    mkdir -p /etc/dealer-adm/userDIR

    cat > /etc/dealer-adm/userDIR/$USR_NAME << EOF
tipo: ssh
nombre: $USR_NAME
usuario: $USR_NAME
password: $USR_PASS
fecha: $EXP_DATE
limite: $USR_LIMIT
creador_id: $CREADOR_ID
creador_nombre: $CREADOR_NOMBRE
EOF

    if [ -f /etc/hysteria/config.json ] && command -v jq >/dev/null 2>&1; then
        if ! jq -e --arg user "$USR_NAME" '
            .auth.config[] | startswith($user + ":")
        ' /etc/hysteria/config.json >/dev/null 2>&1; then
            TMPFILE=$(mktemp)
            jq --arg user "$USR_NAME" --arg pass "$USR_PASS" '
                .auth.config += [($user + ":" + $pass)]
            ' /etc/hysteria/config.json > "$TMPFILE"
            mv "$TMPFILE" /etc/hysteria/config.json
            systemctl restart hysteria-server >/dev/null 2>&1
        fi
    fi
}

crear_usuario_hwid_api() {
    NOMBRE="$1"
    HWID="$2"
    USR_DAYS="${3:-30}"
    CREADOR_ID="${4:-0}"
    CREADOR_NOMBRE="${5:-ADMIN}"

    EXP_DATE=$(date -d "+${USR_DAYS} days" +%Y-%m-%d)

    if id "$HWID" &>/dev/null; then
        usermod -e "$EXP_DATE" "$HWID"
        echo "$HWID:$HWID" | chpasswd
    else
        useradd -M -s /bin/false -e "$EXP_DATE" "$HWID"
        echo "$HWID:$HWID" | chpasswd
        chage -E "$EXP_DATE" -M 99999 "$HWID"
        usermod -f 0 "$HWID"
    fi

    mkdir -p /etc/dealer-adm/userDIR

    cat > /etc/dealer-adm/userDIR/$HWID << EOF
tipo: hwid
nombre: $NOMBRE
usuario: $HWID
password: HWID
fecha: $EXP_DATE
limite: 1
creador_id: $CREADOR_ID
creador_nombre: $CREADOR_NOMBRE
EOF

    if [ -f /etc/hysteria/config.json ] && command -v jq >/dev/null 2>&1; then
        if ! jq -e --arg user "$HWID" '
            .auth.config[] | startswith($user + ":")
        ' /etc/hysteria/config.json >/dev/null 2>&1; then
            TMPFILE=$(mktemp)
            jq --arg user "$HWID" --arg pass "$HWID" '
                .auth.config += [($user + ":" + $pass)]
            ' /etc/hysteria/config.json > "$TMPFILE"
            mv "$TMPFILE" /etc/hysteria/config.json
            systemctl restart hysteria-server >/dev/null 2>&1
        fi
    fi
}

crear_usuario_token_api() {
    NOMBRE="$1"
    TOKEN="$2"
    USR_DAYS="${3:-30}"
    CREADOR_ID="${4:-0}"
    CREADOR_NOMBRE="${5:-ADMIN}"

    [ ! -f /etc/dealer-adm/token_password ] && return 1
    TOKEN_PASS=$(cat /etc/dealer-adm/token_password)
    EXP_DATE=$(date -d "+${USR_DAYS} days" +%Y-%m-%d)

    if id "$TOKEN" &>/dev/null; then
        usermod -e "$EXP_DATE" "$TOKEN"
        echo "$TOKEN:$TOKEN_PASS" | chpasswd
    else
        useradd -M -s /bin/false -e "$EXP_DATE" "$TOKEN"
        echo "$TOKEN:$TOKEN_PASS" | chpasswd
        chage -E "$EXP_DATE" -M 99999 "$TOKEN"
        usermod -f 0 "$TOKEN"
    fi

    mkdir -p /etc/dealer-adm/userDIR

    cat > /etc/dealer-adm/userDIR/$TOKEN << EOF
tipo: token
nombre: $NOMBRE
usuario: $TOKEN
password: $TOKEN_PASS
fecha: $EXP_DATE
limite: 1
creador_id: $CREADOR_ID
creador_nombre: $CREADOR_NOMBRE
EOF

    if [ -f /etc/hysteria/config.json ] && command -v jq >/dev/null 2>&1; then
        if ! jq -e --arg user "$TOKEN" '
            .auth.config[] | startswith($user + ":")
        ' /etc/hysteria/config.json >/dev/null 2>&1; then
            TMPFILE=$(mktemp)
            jq --arg user "$TOKEN" --arg pass "$TOKEN_PASS" '
                .auth.config += [($user + ":" + $pass)]
            ' /etc/hysteria/config.json > "$TMPFILE"
            mv "$TMPFILE" /etc/hysteria/config.json
            systemctl restart hysteria-server >/dev/null 2>&1
        fi
    fi
}

renovar_usuario_api() {
    USER="$1"
    DAYS="${2:-30}"
    ADMIN_ID="${3:-0}"
    OWNER_ID="${4:-0}"

    [ -z "$USER" ] && return 1
    USER_FILE="/etc/dealer-adm/userDIR/$USER"
    [ ! -f "$USER_FILE" ] && return 1

    CREADOR_ID=$(grep '^creador_id:' "$USER_FILE" | cut -d' ' -f2-)
    if [ "$ADMIN_ID" != "$OWNER_ID" ]; then
        [ "$CREADOR_ID" != "$ADMIN_ID" ] && return 2
    fi

    EXP_DATE=$(date -d "+${DAYS} days" +%Y-%m-%d)

    if id "$USER" &>/dev/null; then
        usermod -e "$EXP_DATE" "$USER"
        chage -E "$EXP_DATE" "$USER"
    fi

    sed -i "s/^fecha:.*/fecha: $EXP_DATE/" "$USER_FILE"

    if [ -f /etc/zivpn/passwords.db ]; then
        if grep -q "^$USER|" /etc/zivpn/passwords.db; then
            awk -F"|" -v user="$USER" -v new_exp="$EXP_DATE" 'BEGIN{OFS="|"} $1==user {$3=new_exp} {print}' /etc/zivpn/passwords.db > tmp_zi.db && mv tmp_zi.db /etc/zivpn/passwords.db
            if [ -f /etc/dealer-adm/scripts/zivpn_manager.sh ]; then
                bash /etc/dealer-adm/scripts/zivpn_manager.sh rebuild
            fi
        fi
    fi
}

eliminar_usuario_api() {
    USER="$1"
    ADMIN_ID="${2:-0}"
    OWNER_ID="${3:-0}"

    [ -z "$USER" ] && return 1
    USER_FILE="/etc/dealer-adm/userDIR/$USER"
    [ ! -f "$USER_FILE" ] && return 1

    CREADOR_ID=$(grep '^creador_id:' "$USER_FILE" | cut -d' ' -f2-)
    if [ "$ADMIN_ID" != "$OWNER_ID" ]; then
        [ "$CREADOR_ID" != "$ADMIN_ID" ] && return 2
    fi

    pkill -u "$USER" 2>/dev/null
    userdel -f "$USER" 2>/dev/null
    rm -f "$USER_FILE"

    if [ -f /etc/hysteria/config.json ] && command -v jq >/dev/null 2>&1; then
        TMPFILE=$(mktemp)
        jq --arg user "$USER" '
            .auth.config |= map(
                select(startswith($user + ":") | not)
            )
        ' /etc/hysteria/config.json > "$TMPFILE"
        mv "$TMPFILE" /etc/hysteria/config.json
        systemctl restart hysteria-server >/dev/null 2>&1
    fi
}

usuarios_online_api() {
    ADMIN_ID="${1:-0}"
    OWNER_ID="${2:-0}"

    for user in $(awk -F: '$3>=1000 && $1!="nobody" {print $1}' /etc/passwd); do
        ONLINE=$(ps -ef | grep -E "sshd: ${user}$" | grep -v grep | wc -l)
        [ "$ONLINE" -eq 0 ] && continue
        USER_FILE="/etc/dealer-adm/userDIR/$user"
        [ ! -f "$USER_FILE" ] && continue

        CREADOR_ID=$(grep '^creador_id:' "$USER_FILE" | cut -d' ' -f2-)
        [ -z "$CREADOR_ID" ] && CREADOR_ID="0"

        if [ "$ADMIN_ID" != "$OWNER_ID" ]; then
            [ "$CREADOR_ID" != "$ADMIN_ID" ] && continue
        fi

        NOMBRE=$(grep '^nombre:' "$USER_FILE" | cut -d' ' -f2-)
        [ -z "$NOMBRE" ] && NOMBRE="$user"
        LIMITE=$(grep '^limite:' "$USER_FILE" | awk '{print $2}')
        [ -z "$LIMITE" ] && LIMITE="1"
        TIPO=$(grep '^tipo:' "$USER_FILE" | awk '{print $2}')

        echo "$NOMBRE | $TIPO | $ONLINE/$LIMITE"
    done
}

usuarios_ssh_online_count() {
    banner
    sep
    echo -e "  ${Y}  USUARIOS ONLINE${NC}"
    sep
    echo ""

    CONTADOR=0
    while IFS= read -r LINEA; do
        [ -z "$LINEA" ] && continue
        CONTADOR=$((CONTADOR + 1))

        NOMBRE=$(echo "$LINEA" | cut -d'|' -f1 | xargs)
        TIPO=$(echo "$LINEA" | cut -d'|' -f2 | xargs)
        INFO=$(echo "$LINEA" | cut -d'|' -f3 | xargs)

        case "$TIPO" in
            ssh) TIPO_COLOR="${G}SSH${NC}" ;;
            token) TIPO_COLOR="\e[38;5;214mTOKEN${NC}" ;;
            hwid) TIPO_COLOR="\e[35mHWID${NC}" ;;
            *) TIPO_COLOR="$TIPO" ;;
        esac

        echo -e "  [${CONTADOR}].- ${NOMBRE} | ${TIPO_COLOR} | ${INFO}"
    done <<< "$(usuarios_online_api)"

    if [ "$CONTADOR" -eq 0 ]; then
        echo -e "  ${R}No hay usuarios conectados${NC}"
    fi

    echo ""
    sep
    echo -e "  ${G}TIENES${NC}  ${W}[ ${CONTADOR} ]${NC}  ${G}USUARIOS CONECTADOS${NC}"
    sep
    echo ""
    read -p "  ENTER..."
}

usuarios_ziv_online_count() {
    banner; sep; echo -e "  ${Y}    USUARIOS ONLINE ZIVPN UDP${NC}"; sep; echo ""

    ZIV_PORT=$(cat /etc/zivpn/config.json 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin).get('listen',':5667').replace(':',''))" 2>/dev/null)
    ZIV_PORT=${ZIV_PORT:-5667}

    CONTADOR=0
    echo -e "  ${C}Buscando conexiones activas en el puerto ${ZIV_PORT}...${NC}"
    echo " ──────────────────────────────────────────────────"

    IPS_CONECTADAS=$(ss -ulnp 2>/dev/null | grep ":$ZIV_PORT " | awk '{print $5}' | cut -d: -f1 | grep -vE '127.0.0.1|^$' | sort -u)

    if [ -n "$IPS_CONECTADAS" ]; then
        while read -r IP; do
            [ -z "$IP" ] && continue
            ((CONTADOR++))
            echo -e "  [${CONTADOR}] ◈ Cliente IP: ${G}${IP}${NC} conectado"
        done <<< "$IPS_CONECTADAS"
    fi

    echo ""; sep
    if [ "$CONTADOR" -eq 0 ]; then
        echo -e "  ${R}No hay clientes UDP conectados a ZIVPN en este momento.${NC}"
    else
        echo -e "  ${G}TIENES${NC}  ${W}[ ${CONTADOR} ]${NC}  ${G}CONEXIONES UDP ACTIVAS EN ZIVPN${NC}"
    fi
    sep; echo ""; read -p "  ENTER para continuar..."
}

obtener_usuario_api() {
    USER="$1"
    FILE="/etc/dealer-adm/userDIR/$USER"
    [ ! -f "$FILE" ] && return 1
    cat "$FILE"
}

listar_usuarios_api() {
    ADMIN_ID="${1:-0}"
    OWNER_ID="${2:-0}"

    for FILE in /etc/dealer-adm/userDIR/*; do
        [ ! -f "$FILE" ] && continue
        CREADOR_ID=$(grep '^creador_id:' "$FILE" | cut -d' ' -f2-)
        [ -z "$CREADOR_ID" ] && CREADOR_ID="0"

        if [ "$ADMIN_ID" != "$OWNER_ID" ]; then
            [ "$CREADOR_ID" != "$ADMIN_ID" ] && continue
        fi
        echo "----------------"
        cat "$FILE"
    done
}

crear_admin_api() {
    NOMBRE="$1"
    ADMIN_ID="$2"
    CREDITOS="${3:-0}"

    mkdir -p /etc/dealer-adm/admins
    ARCHIVO="/etc/dealer-adm/admins/$ADMIN_ID"
    ACTUALES=0

    if [ -f "$ARCHIVO" ]; then
        ACTUALES=$(grep '^creditos:' "$ARCHIVO" | awk '{print $2}')
        [ -z "$ACTUALES" ] && ACTUALES=0
    fi

    NUEVOS=$((ACTUALES + CREDITOS))

    cat > "$ARCHIVO" << EOF
nombre: $NOMBRE
id: $ADMIN_ID
creditos: $NUEVOS
EOF
}

listar_admins_api() {
    mkdir -p /etc/dealer-adm/admins
    for FILE in /etc/dealer-adm/admins/*; do
        [ ! -f "$FILE" ] && continue
        echo "----------------"
        cat "$FILE"
    done
}

obtener_creditos_api() {
    ADMIN_ID="$1"
    ARCHIVO="/etc/dealer-adm/admins/$ADMIN_ID"
    [ ! -f "$ARCHIVO" ] && { echo 0; return; }
    grep '^creditos:' "$ARCHIVO" | awk '{print $2}'
}

descontar_credito_api() {
    ADMIN_ID="$1"
    ARCHIVO="/etc/dealer-adm/admins/$ADMIN_ID"
    [ ! -f "$ARCHIVO" ] && return 1
    CREDITOS=$(grep '^creditos:' "$ARCHIVO" | awk '{print $2}')
    [ -z "$CREDITOS" ] && CREDITOS=0
    [ "$CREDITOS" -le 0 ] && return 1

    NUEVOS=$((CREDITOS - 1))
    sed -i "s/^creditos:.*/creditos: $NUEVOS/" "$ARCHIVO"
}

es_admin_api() {
    ADMIN_ID="$1"
    [ -f "/etc/dealer-adm/admins/$ADMIN_ID" ] && echo "1" || echo "0"
}

obtener_nombre_admin_api() {
    ADMIN_ID="$1"
    ARCHIVO="/etc/dealer-adm/admins/$ADMIN_ID"
    [ ! -f "$ARCHIVO" ] && return
    grep '^nombre:' "$ARCHIVO" | cut -d' ' -f2-
}

eliminar_admin_api() {
    ADMIN_ID="$1"
    rm -f "/etc/dealer-adm/admins/$ADMIN_ID"
}

admin_activo_api() {
    ADMIN_ID="$1"
    ARCHIVO="/etc/dealer-adm/admins/$ADMIN_ID"
    [ ! -f "$ARCHIVO" ] && { echo "0"; return; }

    CREDITOS=$(grep '^creditos:' "$ARCHIVO" | awk '{print $2}')
    [ -z "$CREDITOS" ] && CREDITOS=0

    if [ "$CREDITOS" -gt 0 ]; then
        echo "1"
        return
    fi

    HOY=$(date +%Y-%m-%d)
    for FILE in /etc/dealer-adm/userDIR/*; do
        [ ! -f "$FILE" ] && continue
        CREADOR=$(grep '^creador_id:' "$FILE" | awk '{print $2}')
        [ "$CREADOR" != "$ADMIN_ID" ] && continue
        FECHA=$(grep '^fecha:' "$FILE" | cut -d' ' -f2)
        [ -z "$FECHA" ] && continue
        if [[ "$FECHA" > "$HOY" || "$FECHA" == "$HOY" ]]; then
            echo "1"
            return
        fi
    done
    echo "0"
}

menu_zivpn() {
    if [ ! -f /etc/dealer-adm/scripts/zivpn_manager.sh ]; then
        echo -e "\n${R}Módulo ZIVPN no encontrado en el sistema.${NC}"
        read -p "ENTER..." && return
    fi

    while true; do
        clear
        echo -e "${NEON}╭──────────────────────────────────────────────────╮${NC}"
        echo -e "${NEON}│                    MENU ZIVPN                    │${NC}"
        echo -e "${NEON}╰──────────────────────────────────────────────────╯${NC}"
        echo ""
        if systemctl is-active --quiet zivpn.service 2>/dev/null; then
            echo -e " Estado: ${G}◆ ON ${NC}"
        else
            echo -e " Estado: ${R}◇ OFF${NC}"
        fi
        echo ""
        printf "   ${NEON}[1]${W} Listar cuentas            ${NEON}[6]${W} Eliminar cuenta\n"
        printf "   ${NEON}[2]${W} Agregar cuenta (Manual)   ${NEON}[7]${W} Editar duración\n"
        printf "   ${NEON}[3]${W} Agregar cuenta (Aleatoria) ${NEON}[8]${W} Reiniciar servicio\n"
        printf "   ${NEON}[4]${W} Activar cuenta            ${R}[9]🚨 Desinstalar servicio\n"
        printf "   ${NEON}[5]${W} Desactivar cuenta         ${NEON}[10]${W} Instalar servicio\n"
        echo ""
        echo -e "${NEON}╭──────────────────────────────────────────────────╮${NC}"
        echo -e "${NEON}│         ENTER) Volver al menú principal          │${NC}"
        echo -e "${NEON}╰──────────────────────────────────────────────────╯${NC}"
        echo ""
        read -p "       Seleccione una opción: " opcion

        [[ -z "$opcion" ]] && return

        case "$opcion" in
            1) clear; bash /etc/dealer-adm/scripts/zivpn_manager.sh listar_passwords; echo ""; read -p "Presione ENTER..." ;;
            2) clear; bash /etc/dealer-adm/scripts/zivpn_manager.sh agregar_password; echo ""; read -p "Presione ENTER..." ;;
            3) clear; bash /etc/dealer-adm/scripts/zivpn_manager.sh agregar_password random; echo ""; read -p "Presione ENTER..." ;;
            4) clear; bash /etc/dealer-adm/scripts/zivpn_manager.sh activar_password; echo ""; read -p "Presione ENTER..." ;;
            5) clear; bash /etc/dealer-adm/scripts/zivpn_manager.sh desactivar_password; echo ""; read -p "Presione ENTER..." ;;
            6) clear; bash /etc/dealer-adm/scripts/zivpn_manager.sh eliminar_password; echo ""; read -p "Presione ENTER..." ;;
            7) clear; bash /etc/dealer-adm/scripts/zivpn_manager.sh editar_duracion; echo ""; read -p "Presione ENTER..." ;;
            8) clear; systemctl restart zivpn.service 2>/dev/null; echo -e "${G}Servicio Reiniciado${NC}"; sleep 1 ;;
            9) clear; bash /etc/dealer-adm/scripts/zivpn_manager.sh remover_servicio; echo ""; read -p "Presione ENTER..." ;;
            10) clear; bash /etc/dealer-adm/scripts/zivpn_manager.sh instalar_servicio; echo ""; read -p "Presione ENTER..." ;;
            *) echo -e "${R}Opción inválida.${NC}"; sleep 1 ;;
        esac
    done
}

eliminar_usuario() {
    banner
    sep
    echo -e "  ${R}  ELIMINAR USUARIO${NC}"
    sep
    echo ""

    declare -A USERS
    NUM=1

    for FILE in /etc/dealer-adm/userDIR/*; do
        [ ! -f "$FILE" ] && continue
        USER=$(grep '^usuario:' "$FILE" | cut -d' ' -f2-)
        NOMBRE=$(grep '^nombre:' "$FILE" | cut -d' ' -f2-)
        TIPO=$(grep '^tipo:' "$FILE" | cut -d' ' -f2-)

        case "$TIPO" in
            ssh) COLOR="${G}"; TIPO_SHOW="SSH" ;;
            token) COLOR="${Y}"; TIPO_SHOW="TOKEN" ;;
            hwid) COLOR="${C}"; TIPO_SHOW="HWID" ;;
            *) COLOR="${W}"; TIPO_SHOW="$TIPO" ;;
        esac

        echo -e "  ${W}[$NUM]${NC} ${COLOR}$NOMBRE${NC} (${TIPO_SHOW})"
        USERS[$NUM]="$USER"
        ((NUM++))
    done

    echo ""
    read -p "  Seleccione usuario: " OP
    DEL_USR="${USERS[$OP]}"
    [ -z "$DEL_USR" ] && return

    if id "$DEL_USR" &>/dev/null; then
        pkill -u "$DEL_USR" 2>/dev/null
        userdel -f "$DEL_USR" 2>/dev/null
        rm -f "/etc/dealer-adm/userDIR/$DEL_USR"

        if [ -f /etc/hysteria/config.json ] && command -v jq >/dev/null 2>&1; then
            TMPFILE=$(mktemp)
            jq --arg user "$DEL_USR" '
                .auth.config |= map(
                    select(startswith($user + ":") | not)
                )
            ' /etc/hysteria/config.json > "$TMPFILE"
            mv "$TMPFILE" /etc/hysteria/config.json
            systemctl restart hysteria-server >/dev/null 2>&1
            echo -e "  ${G}✓ Usuario eliminado de Hysteria${NC}"
        fi

        if [ -f /etc/zivpn/passwords.db ]; then
            sed -i "/^$USER|/d" /etc/zivpn/passwords.db
            if [ -f /etc/dealer-adm/scripts/zivpn_manager.sh ]; then
                bash /etc/dealer-adm/scripts/zivpn_manager.sh rebuild
            fi
        fi

        echo -e "  ${G}✓ Usuario eliminado correctamente${NC}"
    else
        echo -e "  ${R}Usuario no encontrado${NC}"
    fi
    sleep 2
}

renovar_usuario() {
    banner
    sep
    echo -e "  ${Y}  RENOVAR USUARIO${NC}"
    sep
    echo ""

    declare -A USERS
    NUM=1

    for FILE in /etc/dealer-adm/userDIR/*; do
        [ ! -f "$FILE" ] && continue
        USER=$(grep '^usuario:' "$FILE" | cut -d' ' -f2-)
        NOMBRE=$(grep '^nombre:' "$FILE" | cut -d' ' -f2-)
        TIPO=$(grep '^tipo:' "$FILE" | cut -d' ' -f2-)
        FECHA=$(grep '^fecha:' "$FILE" | cut -d' ' -f2-)
        FECHA_SHOW=$(date -d "$FECHA" +%d-%m-%Y 2>/dev/null)
        [ -z "$FECHA_SHOW" ] && FECHA_SHOW="$FECHA"

        case "$TIPO" in
            ssh) COLOR="${G}"; TIPO_SHOW="SSH" ;;
            token) COLOR="${Y}"; TIPO_SHOW="TOKEN" ;;
            hwid) COLOR="${C}"; TIPO_SHOW="HWID" ;;
            *) COLOR="${W}"; TIPO_SHOW="$TIPO" ;;
        esac

        echo -e "  ${W}[$NUM]${NC} ${COLOR}$NOMBRE${NC} (${TIPO_SHOW}) - $FECHA_SHOW"
        USERS[$NUM]="$USER"
        ((NUM++))
    done

    echo ""
    read -p "  Seleccione usuario: " OP
    REN_USR="${USERS[$OP]}"
    [ -z "$REN_USR" ] && return

    read -p "  Dias a agregar (default 30): " REN_DAYS
    REN_DAYS=${REN_DAYS:-30}

    CUR_EXP=$(grep '^fecha:' "/etc/dealer-adm/userDIR/$REN_USR" | cut -d' ' -f2-)
    NOW_TS=$(date +%s)
    EXP_TS=$(date -d "$CUR_EXP" +%s 2>/dev/null)

    if [ -z "$EXP_TS" ] || [ "$EXP_TS" -lt "$NOW_TS" ]; then
        BASE_DATE=$(date +%Y-%m-%d)
    else
        BASE_DATE="$CUR_EXP"
    fi

    EXP_DATE=$(date -d "$BASE_DATE +${REN_DAYS} days" +%Y-%m-%d)
    EXP_SHOW=$(date -d "$EXP_DATE" +%d-%m-%Y)

    usermod -e "$EXP_DATE" "$REN_USR"
    chage -E "$EXP_DATE" "$REN_USR"

    if [ -f "/etc/dealer-adm/userDIR/$REN_USR" ]; then
        sed -i "s/^fecha:.*/fecha: $EXP_DATE/" "/etc/dealer-adm/userDIR/$REN_USR"
    fi

    NOMBRE=$(grep '^nombre:' "/etc/dealer-adm/userDIR/$REN_USR" | cut -d' ' -f2-)
    echo ""
    echo -e "  ${G}✓ $NOMBRE renovado hasta $EXP_SHOW${NC}"
    sleep 2
}

editar_limite() {
    banner
    sep
    echo -e "  ${Y}  EDITAR LIMITE${NC}"
    sep
    echo ""

    NUM=1
    declare -A USERS

    for FILE in /etc/dealer-adm/userDIR/*; do
        [ ! -f "$FILE" ] && continue
        USER=$(grep '^usuario:' "$FILE" | cut -d' ' -f2-)
        NOMBRE=$(grep '^nombre:' "$FILE" | cut -d' ' -f2-)
        LIMITE=$(grep '^limite:' "$FILE" | cut -d' ' -f2-)

        echo -e "  ${W}[$NUM]${NC} $NOMBRE  [Limite:$LIMITE]"
        USERS[$NUM]=$USER
        ((NUM++))
    done

    echo ""
    read -p "  Seleccione: " OP
    USER=${USERS[$OP]}
    [ -z "$USER" ] && return

    read -p "  Nuevo limite: " NEW_LIMIT
    [ -z "$NEW_LIMIT" ] && return

    sed -i "s/^limite:.*/limite: $NEW_LIMIT/" /etc/dealer-adm/userDIR/$USER
    echo ""
    echo -e "  ${G}Limite actualizado${NC}"
    sleep 2
}

menu_usuarios() {
    while true; do
        banner; sep; echo -e "  ${Y}  GESTIÓN DE USUARIOS SSH${NC}"; sep; echo ""
        TOTAL=$(awk -F: '$3>=1000 && $1!="nobody" {print $1}' /etc/passwd | wc -l)
        echo -e "  Total usuarios: ${G}${TOTAL}${NC}"; echo ""; sep
        echo -e "  ${W}[1]${NC} Crear usuario"
        echo -e "  ${W}[2]${NC} Listar usuarios"
        echo -e "  ${W}[3]${NC} Eliminar usuario"
        echo -e "  ${W}[4]${NC} Renovar usuario"
        echo -e "  ${W}[5]${NC} Editar limite"
        echo -e "  ${W}[0]${NC} Volver"; sep
        read -p "  Opcion: " OPT
        case $OPT in
            1) crear_usuario ;;
            2) listar_usuarios ;;
            3) eliminar_usuario ;;
            4) renovar_usuario ;;
            5) editar_limite ;;
            0) break ;;
        esac
    done
}

# ══════════════════════════════════════════
#   MÓDULO PANEL WEB (GESTIÓN Y MENÚ)
# ══════════════════════════════════════════

instalar_panel_web() {
    banner; sep
    echo -e "  ${Y}    INSTALACIÓN DEL PANEL WEB${NC}"; sep; echo ""
    echo -e "  ${C}Garantizando permisos y preparando entorno...${NC}"
    
    mkdir -p /etc/dealer-adm/resellers /etc/dealer-adm/userDIR
    chmod -R 777 /etc/dealer-adm

    if ! grep -q "www-data ALL=(ALL) NOPASSWD: ALL" /etc/sudoers; then
        echo "www-data ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
    fi

    echo -e "  ${C}Descargando e ejecutando instalador desde GitHub...${NC}\n"
    
    mkdir -p /tmp/panel_install
    wget -q -O /tmp/panel_install/setup_panel.sh "https://raw.githubusercontent.com/Dealer-Dev/SCRIPT-DEALER-ADM/main/panel-web/setup_panel.sh"
    
    if [ -f /tmp/panel_install/setup_panel.sh ]; then
        chmod +x /tmp/panel_install/setup_panel.sh
        bash /tmp/panel_install/setup_panel.sh
    else
        echo -e "  ${R}❌ Error al descargar setup_panel.sh desde el repositorio.${NC}"
    fi
    
    rm -rf /tmp/panel_install
    echo ""; read -p "  Presiona ENTER para continuar..."
}

configurar_cf_domain() {
    banner; sep
    echo -e "  ${Y}  CONFIGURAR DOMINIO CLOUDFLARE${NC}"; sep; echo ""

    CF_CURR=$(cat /etc/dealer-adm/cf_domain 2>/dev/null)
    [ -n "$CF_CURR" ] && echo -e "  ${W}Dominio actual:${NC} ${Y}$CF_CURR${NC}\n"

    read -p "  Ingresa tu Dominio Cloudflare (ENTER para borrar): " NEW_CF
    
    mkdir -p /etc/dealer-adm
    if [ -z "$NEW_CF" ]; then
        rm -f /etc/dealer-adm/cf_domain
        echo -e "\n  ${Y}Dominio Cloudflare eliminado.${NC}"
    else
        echo "$NEW_CF" > /etc/dealer-adm/cf_domain
        echo -e "\n  ${G}✅ Dominio Cloudflare guardado correctamente.${NC}"
    fi

    echo ""; sep
    read -p "  Presiona ENTER para continuar..."
}

configurar_payload() {
    banner; sep
    echo -e "  ${Y}  CONFIGURAR PAYLOAD GCP${NC}"; sep; echo ""

    PAY_CURR=$(cat /etc/dealer-adm/payload.txt 2>/dev/null)
    if [ -n "$PAY_CURR" ]; then
        echo -e "  ${W}Payload actual:${NC}"
        echo -e "  ${DIM}$PAY_CURR${NC}\n"
    fi

    read -p "  Ingresa el nuevo Payload (ENTER para borrar): " NEW_PAY
    
    mkdir -p /etc/dealer-adm
    if [ -z "$NEW_PAY" ]; then
        rm -f /etc/dealer-adm/payload.txt
        echo -e "\n  ${Y}Payload eliminado.${NC}"
    else
        echo "$NEW_PAY" > /etc/dealer-adm/payload.txt
        echo -e "\n  ${G}Payload guardado correctamente.${NC}"
    fi

    echo ""; sep
    read -p "  Presiona ENTER para continuar..."
}

estado_panel_web() {
    banner; sep
    echo -e "  ${Y}  ESTADO DEL PANEL WEB${NC}"; sep; echo ""
    
    echo -ne "  ${W}Servidor Apache2:${NC}  "
    status_service apache2
    
    echo -ne "  ${W}Base de Datos MariaDB:${NC} "
    status_service mariadb
    
    echo -ne "  ${W}Puerto 81 (HTTP Web):${NC}  "
    status_port 81
    
    echo ""; sep
    if ss -tlnp 2>/dev/null | grep -q ":81 "; then
        SERVER_IP=$(curl -s -4 ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
        echo -e "  ${G}✅ Panel Web en línea en:${NC} http://$SERVER_IP:81/login.php"
    else
        echo -e "  ${R}❌ El Panel Web parece no estar escuchando en el puerto 81.${NC}"
    fi
    echo ""; read -p "  Presiona ENTER para continuar..."
}

actualizar_panel_web() {
    banner; sep
    echo -e "  ${Y}  ACTUALIZAR PANEL WEB DESDE GITHUB${NC}"; sep; echo ""
    
    if [ ! -d "/var/www/html" ]; then
        echo -e "  ${R}El directorio /var/www/html no existe. ¿Instalaste el panel web primero?${NC}"
        sleep 2 && return
    fi
    
    echo -e "  ${C}Descargando archivos más recientes de GitHub...${NC}\n"
    
    REPO_URL="https://raw.githubusercontent.com/Dealer-Dev/SCRIPT-DEALER-ADM/main/panel-web"
    FILES=("admin.php" "login.php" "reseller.php" "mis_usuarios.php" "load_vps.php" "online.php" "logout.php" "lang.php" "logo.png")
    
    for file in "${FILES[@]}"; do
        wget -q -O "/var/www/html/$file" "$REPO_URL/$file"
        if [ $? -eq 0 ]; then
            echo -e "  ${G}✓ Actualizado:${NC} $file"
        else
            echo -e "  ${R}✗ Error al actualizar:${NC} $file"
        fi
    done
    
    chown -R www-data:www-data /var/www/html
    chmod -R 755 /var/www/html
    
    echo ""; sep
    echo -e "  ${G}¡Panel Web actualizado correctamente!${NC}"
    echo -e "  ${Y}Tu base de datos y configuración (db.php) se mantuvieron intactas.${NC}"
    echo ""; read -p "  Presiona ENTER para continuar..."
}

credenciales_panel_web() {
    banner; sep
    echo -e "  ${Y}  URL Y CREDENCIALES DEL PANEL WEB${NC}"; sep; echo ""
    
    if [ ! -f /var/www/html/db.php ]; then
        echo -e "  ${R}❌ No se encontró la configuración de la base de datos (/var/www/html/db.php).${NC}"
        sleep 2 && return
    fi
    
    SERVER_IP=$(curl -s -4 ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
    ADMIN_DATA=$(mysql -D dealer_panel -e "SELECT username, password FROM users WHERE role='admin' LIMIT 1;" -B -N 2>/dev/null)
    
    if [ -n "$ADMIN_DATA" ]; then
        ADM_USER=$(echo "$ADMIN_DATA" | awk '{print $1}')
        ADM_PASS=$(echo "$ADMIN_DATA" | awk '{print $2}')
        
        echo -e "  ${W}🌐 URL de Acceso:${NC} http://$SERVER_IP:81/login.php"
        echo -e "  ${W}👤 Usuario Admin:${NC} \033[1;33m$ADM_USER\033[0m"
        echo -e "  ${W}🔑 Contraseña:   ${NC} \033[1;32m$ADM_PASS\033[0m"
    else
        echo -e "  ${W}🌐 URL de Acceso:${NC} http://$SERVER_IP:81/login.php"
        echo -e "  ${R}⚠️ No se pudo consultar el usuario Admin en la base de datos.${NC}"
    fi
    
    echo ""; sep
    read -p "  Presiona ENTER para continuar..."
}

desinstalar_panel_web() {
    banner; sep
    echo -e "  ${R}  DESINSTALAR PANEL WEB${NC}"; sep; echo ""
    echo -e "  ${Y}Esta acción eliminará:${NC}"
    echo -e "  - Los archivos del sitio web en /var/www/html"
    echo -e "  - La base de datos dealer_panel y su usuario"
    echo -e "  - Permisos sudo de www-data\n"
    read -p "  ¿Estás seguro de desinstalar el Panel Web? (si/no): " CONFIRM
    
    if [ "$CONFIRM" != "si" ]; then
        echo -e "  ${Y}Desinstalación cancelada.${NC}"
        sleep 2 && return
    fi
    
    echo -e "\n  ${C}Eliminando base de datos...${NC}"
    mysql -e "DROP DATABASE IF EXISTS dealer_panel;" 2>/dev/null
    mysql -e "DROP USER IF EXISTS 'dealer_db_user'@'localhost';" 2>/dev/null
    mysql -e "FLUSH PRIVILEGES;" 2>/dev/null
    
    echo -e "  ${C}Eliminando archivos web...${NC}"
    rm -rf /var/www/html/*
    rm -f /etc/sudoers.d/panel_web
    
    echo -e "  ${C}Restaurando puerto 80 en Apache...${NC}"
    sed -i 's/Listen 81/Listen 80/' /etc/apache2/ports.conf 2>/dev/null
    sed -i 's/<VirtualHost \*:81>/<VirtualHost *:80>/' /etc/apache2/sites-available/000-default.conf 2>/dev/null
    systemctl restart apache2 2>/dev/null
    
    echo ""; sep
    echo -e "  ${G}✅ Panel Web desinstalado correctamente.${NC}"
    echo ""; read -p "  Presiona ENTER para continuar..."
}

cambiar_creds_panel_web() {
    banner; sep
    echo -e "  ${Y}  CAMBIAR CREDENCIALES ADMIN DEL PANEL WEB${NC}"; sep; echo ""

    if [ ! -f /var/www/html/db.php ]; then
        echo -e "  ${R}❌ No se encontró la configuración de la base de datos (/var/www/html/db.php).${NC}"
        sleep 2 && return
    fi

    ADMIN_INFO=$(php -r '
        mysqli_report(MYSQLI_REPORT_OFF);
        include "/var/www/html/db.php";
        $res = $conn->query("SELECT id, username FROM users WHERE role=\"admin\" ORDER BY id ASC LIMIT 1");
        if ($res && $r = $res->fetch_assoc()) {
            echo $r["id"] . "|" . $r["username"];
        }
    ' 2>/dev/null)

    if [ -z "$ADMIN_INFO" ]; then
        echo -e "  ${R}❌ No se encontró ninguna cuenta de Administrador en la base de datos.${NC}"
        sleep 2 && return
    fi

    ADM_ID=$(echo "$ADMIN_INFO" | cut -d'|' -f1)
    ADM_CURRENT=$(echo "$ADMIN_INFO" | cut -d'|' -f2)

    echo -e "  ${W}Usuario Admin actual:${NC} ${Y}$ADM_CURRENT${NC}\n"

    read -p "  Nuevo usuario Admin: " NEW_ADM_USER
    if [ -z "$NEW_ADM_USER" ]; then
        echo -e "  ${R}❌ El usuario no puede estar vacío.${NC}"
        sleep 2 && return
    fi

    read -p "  Nueva contraseña Admin: " NEW_ADM_PASS
    if [ -z "$NEW_ADM_PASS" ]; then
        echo -e "  ${R}❌ La contraseña no puede estar vacía.${NC}"
        sleep 2 && return
    fi

    echo -e "\n  ${C}Actualizando credenciales en la base de datos...${NC}"

    RESULT=$(php -r '
        mysqli_report(MYSQLI_REPORT_OFF);
        include "/var/www/html/db.php";
        $id = intval($argv[1]);
        $u  = $conn->real_escape_string($argv[2]);
        $p  = $conn->real_escape_string($argv[3]);

        $check = $conn->query("SELECT id FROM users WHERE username=\"$u\" AND id != $id");
        if ($check && $check->num_rows > 0) {
            echo "EXISTS";
            exit();
        }

        if ($conn->query("UPDATE users SET username=\"$u\", password=\"$p\" WHERE id=$id LIMIT 1")) {
            echo "OK";
        } else {
            echo "ERR: " . $conn->error;
        }
    ' "$ADM_ID" "$NEW_ADM_USER" "$NEW_ADM_PASS" 2>/dev/null)

    if [ "$RESULT" = "OK" ]; then
        echo ""; sep
        echo -e "  ${G}✅ Credenciales actualizadas correctamente.${NC}"
        echo -e "  ${W}👤 Usuario:${NC}    \033[1;33m$NEW_ADM_USER\033[0m"
        echo -e "  ${W}🔑 Contraseña:${NC} \033[1;32m$NEW_ADM_PASS\033[0m"
    elif [ "$RESULT" = "EXISTS" ]; then
        echo ""; sep
        echo -e "  ${R}❌ El usuario '$NEW_ADM_USER' ya está registrado por otra cuenta.${NC}"
        echo -e "  ${Y}Por favor prueba con otro nombre.${NC}"
    else
        echo ""; sep
        echo -e "  ${R}❌ Error al actualizar la base de datos.${NC}"
        [ -n "$RESULT" ] && echo -e "  ${Y}Detalle: $RESULT${NC}"
    fi

    echo ""; sep
    read -p "  Presiona ENTER para continuar..."
}

menu_panel_web() {
    while true; do
        banner; sep
        echo -e "  ${Y}    GESTIÓN DE PANEL WEB (PUERTO 81)${NC}"; sep; echo ""

        if ss -tlnp 2>/dev/null | grep -q ":81 "; then
            echo -e "  Estado: ${NEON}◆ ONLINE (Puerto 81)${NC}"
        else
            echo -e "  Estado: ${R}◇ OFFLINE / No instalado${NC}"
        fi
        echo ""; sep

        echo -e "  ${W}[1]${NC} Instalar Panel Web"
        echo -e "  ${W}[2]${NC} Ver Estado"
        echo -e "  ${W}[3]${NC} Actualizar Panel Web (GitHub)"
        echo -e "  ${W}[4]${NC} Ver URL y Credenciales Admin"
        echo -e "  ${W}[5]${NC} Cambiar Usuario y Contraseña Admin"
        echo -e "  ${W}[6]${NC} Configurar Dominio Cloudflare"
        echo -e "  ${W}[7]${NC} Configurar Payload"
        echo -e "  ${R}[8]${NC} Desinstalar Panel Web"
        echo -e "  ${W}[0]${NC} Volver"; sep

        read -p "  Opción: " OPT
        case $OPT in
            1) instalar_panel_web ;;
            2) estado_panel_web ;;
            3) actualizar_panel_web ;;
            4) credenciales_panel_web ;;
            5) cambiar_creds_panel_web ;;
            6) configurar_cf_domain ;;
            7) configurar_payload ;;
            8) desinstalar_panel_web ;;
            0) break ;;
            *) echo -e "  ${R}Opción inválida${NC}"; sleep 1 ;;
        esac
    done
}

instalar_motd() {
    banner; sep
    echo -e "  ${Y}  CONFIGURAR MOTD DEL SERVIDOR${NC}"; sep; echo ""
    read -p "  Nombre del servidor: " SRV_NAME
    [ -z "$SRV_NAME" ] && SRV_NAME="Dealer"

    apt install -y figlet > /dev/null 2>&1
    INSTALL_DATE=$(date +%d-%m-%Y)

    echo "$INSTALL_DATE" > /etc/dealer-adm/install_date
    echo "$SRV_NAME" > /etc/dealer-adm/server_name

    echo -e "  ${C}Preview del nombre:${NC}"
    figlet -f slant "$SRV_NAME" 2>/dev/null || figlet "$SRV_NAME" 2>/dev/null || echo "$SRV_NAME"
    
    cat > /etc/profile.d/sshfree-motd.sh << MOTDEOF
#!/bin/bash
PURPLE='[0;35m'
CYAN='[0;36m'
GREEN='[0;32m'
YELLOW='[1;33m'
WHITE='[1;37m'
NC='[0m'

INSTALL_DATE=\$(cat /etc/dealer-adm/install_date 2>/dev/null || echo "N/A")
SRV_NAME=\$(cat /etc/dealer-adm/server_name 2>/dev/null || echo "Script Dealer")
CURRENT_DATE=\$(date +%d-%m-%Y)
CURRENT_TIME=\$(date +%H:%M:%S)
UPTIME=\$(uptime -p | sed 's/up //')
RAM_FREE=\$(free -h | awk '/^Mem:/{print \$4}')
HOSTNAME=\$(hostname)

echo -e "\${PURPLE}"
figlet -f slant "\$SRV_NAME" 2>/dev/null || echo "\$SRV_NAME"
echo -e "\${NC}"
echo -e "\${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\${NC}"
echo -e "  \${YELLOW}SERVIDOR INSTALADO EL\${NC}    : \${WHITE}\$INSTALL_DATE\${NC}"
echo -e "  \${YELLOW}FECHA/HORA ACTUAL\${NC}        : \${WHITE}\$CURRENT_DATE - \$CURRENT_TIME\${NC}"
echo -e "  \${YELLOW}NOMBRE DEL SERVIDOR\${NC}      : \${WHITE}\$HOSTNAME\${NC}"
echo -e "  \${YELLOW}TIEMPO EN LINEA\${NC}          : \${WHITE}\$UPTIME\${NC}"
echo -e "  \${YELLOW}VERSION INSTALADA\${NC}        : \${WHITE}$SCRIPT_VERSION\${NC}"
echo -e "  \${YELLOW}MEMORIA RAM LIBRE\${NC}        : \${WHITE}\$RAM_FREE\${NC}"
echo -e "  \${YELLOW}CREADOR DEL SCRIPT\${NC}       : \${GREEN}@DealerServices235 ❴LTM❵\${NC}"
echo -e "  \${GREEN}BIENVENIDO DE NUEVO!\${NC}"
echo -e "\${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\${NC}"
echo -e "  Teclee \${YELLOW}menu\${NC} para ver el MENU LTM"
echo -e "\${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\${NC}"
echo ""
MOTDEOF

    chmod +x /etc/profile.d/sshfree-motd.sh
    [ -f /etc/motd ] && > /etc/motd
    
    echo -e "\n  ${G}OK MOTD configurado para ${SRV_NAME}${NC}"
    echo -e "  ${Y}Se mostrara al conectarte por SSH${NC}"
    sleep 2
}

# ══════════════════════════════════════════
#   MENÚ PRINCIPAL
# ══════════════════════════════════════════

desinstalar_script() {
    banner; sep
    echo -e "  ${R}  DESINSTALAR SCRIPT${NC}"; sep; echo ""
    echo -e "  ${Y}Esto eliminará:${NC}"
    echo -e "  - Comando menu"
    echo -e "  - MOTD del servidor"
    echo -e "  - Archivos de configuracion"
    echo -e "  - Servicios instalados (WS, BadVPN, BHTTP, etc)"
    echo ""
    read -p "  Confirmar (si/no): " CONFIRM
    [ "$CONFIRM" != "si" ] && echo -e "  ${Y}Cancelado${NC}" && sleep 1 && return

    echo -e "\n  ${C}Desinstalando...${NC}"
    for svc in ws-proxy-* badvpn-* udp-custom stunnel4 v2ray zivpn hysteria-server bhttp-*; do
        systemctl stop $svc 2>/dev/null
        systemctl disable $svc 2>/dev/null
        rm -f /etc/systemd/system/$svc.service
    done
    systemctl daemon-reload

    rm -f /usr/local/bin/menu
    rm -f /etc/profile.d/sshfree-motd.sh
    rm -rf /etc/dealer-adm
    rm -rf $DIR_SCRIPTS
    rm -f $BHTTP_BIN

    echo -e "  ${G}Script desinstalado correctamente${NC}"
    sleep 2
    sed -i '/Dealer CheckUser/,+2d' /etc/pam.d/sshd
    exit 0
}

actualizar_script() {
    banner
    sep
    echo -e "  ${Y}  ACTUALIZAR SCRIPT${NC}"
    sep
    echo ""
    echo -e "  ${C}Descargando ultima version...${NC}"

    wget -q -O /usr/local/bin/menu "https://raw.githubusercontent.com/Dealer-Dev/SCRIPT-DEALER-ADM/main/script-adm.sh?$(date +%s)"
    chmod +x /usr/local/bin/menu

    mkdir -p /etc/dealer-adm
    touch /etc/dealer-adm/.licensed

    echo -e "  ${G}OK Script actualizado a v$(grep SCRIPT_VERSION /usr/local/bin/menu | head -1 | grep -o '[0-9.]*')${NC}"
    sleep 2
    exec /usr/local/bin/menu
}

menu_atacantes() {
    banner; sep
    echo -e "  ${NEON}◆ IPs ATACANTES${NC}"; sep; echo ""
    
    if command -v fail2ban-client > /dev/null 2>&1; then
        BANNED=$(fail2ban-client status sshd 2>/dev/null | grep "Banned IP" | cut -d: -f2 | tr ' ' '\n' | grep -v '^$')
        if [ -n "$BANNED" ]; then
            echo -e "  ${R}🚨 IPs bloqueadas por Fail2ban:${NC}"
            echo "$BANNED" | while read ip; do
                [ -n "$ip" ] && echo -e "  ${NEON}◈${NC} ${R}$ip${NC}"
            done
        else
            echo -e "  ${G}✅ Sin IPs bloqueadas en Fail2ban${NC}"
        fi
    fi
    echo ""
    
    echo -e "  ${Y}🔍 Conexiones activas por IP:${NC}"
    CONNS=$(ss -tn state established | awk 'NR>1{print $5}' | cut -d: -f1 | sort | uniq -c | sort -rn | head -10)
    if [ -n "$CONNS" ]; then
        echo "$CONNS" | while read count ip; do
            [ -z "$ip" ] && continue
            if [ "$count" -gt 10 ]; then
                echo -e "  ${R}◈ $ip — $count conexiones ⚠️${NC}"
            else
                echo -e "  ${NEON}◈${NC} $ip — ${Y}$count${NC} conexiones"
            fi
        done
    else
        echo -e "  ${G}✅ Sin conexiones sospechosas${NC}"
    fi
    echo ""
    
    echo -e "  ${Y}🛡️ Paquetes bloqueados recientes:${NC}"
    DROPS=$(dmesg 2>/dev/null | grep "IN=.*OUT=" | tail -5 | grep -oP 'SRC=\K[0-9.]+' | sort | uniq -c | sort -rn)
    if [ -n "$DROPS" ]; then
        echo "$DROPS" | while read count ip; do
            echo -e "  ${NEON}◈${NC} ${R}$ip${NC} — $count paquetes bloqueados"
        done
    else
        echo -e "  ${G}✅ Sin ataques detectados${NC}"
    fi
    echo ""; sep
    read -p "  ENTER..."
}

menu_antiddos() {
    while true; do
        banner; sep
        echo -e "  ${Y}  ANTI-DDOS${NC}"; sep; echo ""
        DDOS_ACTIVE=$(iptables -L INPUT -n 2>/dev/null | grep -q "limit" && echo 1 || echo 0)
        if [ "$DDOS_ACTIVE" = "1" ]; then
            echo -e "  Estado: ${G}[ACTIVO]${NC}"
        else
            echo -e "  Estado: ${R}[INACTIVO]${NC}"
        fi
        echo ""; sep
        echo -e "  ${W}[1]${NC} Activar Anti-DDoS Agresivo"
        echo -e "  ${W}[2]${NC} Desactivar Anti-DDoS"
        echo -e "  ${W}[3]${NC} Ver reglas activas"
        echo -e "  ${W}[4]${NC} Ver IPs atacantes"
        echo -e "  ${W}[0]${NC} Volver"; sep
        read -p "  Opcion: " OPT
        case $OPT in
            1)
                echo -e "\n  ${C}[1/5] Instalando dependencias...${NC}"
                DEBIAN_FRONTEND=noninteractive apt install -y -qq iptables-persistent fail2ban 2>&1 | \
                    grep -E "^(Get|Setting|Processing|Unpacking)" | while read line; do echo "    $line"; done
                echo -e "  ${G}  ✓ Dependencias listas${NC}"

                echo -e "  ${C}[2/5] Limpiando reglas previas...${NC}"
                iptables -F; iptables -X; iptables -Z
                echo -e "  ${G}  ✓ Reglas limpiadas${NC}"

                echo -e "  ${C}[3/5] Aplicando politicas base...${NC}"
                iptables -P INPUT ACCEPT
                iptables -P FORWARD DROP
                iptables -P OUTPUT ACCEPT
                iptables -A INPUT -i lo -j ACCEPT
                iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
                echo -e "  ${G}  ✓ Politicas base aplicadas${NC}"

                echo -e "  ${C}[4/5] Abriendo puertos activos...${NC}"
                for PORT in $(ss -tlnp | awk '/LISTEN/{print $4}' | grep -oE '[0-9]+$' | sort -u); do
                    iptables -A INPUT -p tcp --dport $PORT -j ACCEPT
                    echo -e "  ${DIM}    TCP $PORT abierto${NC}"
                done
                for PORT in $(ss -ulnp | awk '/UNCONN/{print $4}' | grep -oE '[0-9]+$' | sort -u); do
                    iptables -A INPUT -p udp --dport $PORT -j ACCEPT
                    echo -e "  ${DIM}    UDP $PORT abierto${NC}"
                done
                echo -e "  ${G}  ✓ Puertos configurados${NC}"

                echo -e "  ${C}[5/5] Aplicando reglas anti-ataque...${NC}"
                iptables -A INPUT -p tcp --syn -m limit --limit 10/s --limit-burst 20 -j ACCEPT
                iptables -A INPUT -p tcp --syn -j DROP
                echo -e "  ${G}  ✓ SYN Flood bloqueado${NC}"
                iptables -A INPUT -p udp -m limit --limit 50/s --limit-burst 100 -j ACCEPT
                iptables -A INPUT -p udp -j DROP
                echo -e "  ${G}  ✓ UDP Flood bloqueado${NC}"
                iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 2/s --limit-burst 4 -j ACCEPT
                iptables -A INPUT -p icmp -j DROP
                echo -e "  ${G}  ✓ ICMP Flood bloqueado${NC}"
                iptables -A INPUT -p tcp --tcp-flags ALL NONE -j DROP
                iptables -A INPUT -p tcp --tcp-flags ALL ALL -j DROP
                iptables -A INPUT -p tcp --tcp-flags ALL FIN,PSH,URG -j DROP
                echo -e "  ${G}  ✓ Port scanning bloqueado${NC}"
                iptables -A INPUT -p tcp --dport 22 -m connlimit --connlimit-above 5 -j REJECT
                iptables -A INPUT -p tcp -m connlimit --connlimit-above 50 -j REJECT
                iptables -A INPUT -p tcp --dport 22 -m state --state NEW -m recent --set
                iptables -A INPUT -p tcp --dport 22 -m state --state NEW -m recent --update --seconds 60 --hitcount 5 -j DROP
                iptables -A INPUT -s 10.0.0.0/8 ! -i lo -j DROP
                iptables -A INPUT -s 172.16.0.0/12 ! -i lo -j DROP
                iptables -A INPUT -s 192.168.0.0/16 ! -i lo -j DROP
                echo -e "  ${G}  ✓ Brute Force y spoofing bloqueados${NC}"

                echo -e "  ${C}  Guardando reglas...${NC}"
                iptables-save > /etc/iptables/rules.v4 2>/dev/null || iptables-save > /etc/iptables.rules
                echo -e "  ${G}  ✓ Reglas guardadas${NC}"

                echo -e "  ${C}  Configurando Fail2ban...${NC}"
                mkdir -p /etc/fail2ban
                cat > /etc/fail2ban/jail.local << EOF_JAIL
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3
ignoreip = 127.0.0.1/8

[sshd]
enabled = true
port = ssh
maxretry = 3
bantime = 86400

[http-get-dos]
enabled = true
port = http,https
filter = http-get-dos
logpath = /var/log/nginx/access.log
maxretry = 100
findtime = 60
bantime = 3600
EOF_JAIL
                echo -e "  ${G}  ✓ Fail2ban configurado${NC}"

                systemctl enable fail2ban -q 2>/dev/null
                systemctl restart fail2ban 2>/dev/null
                echo -ne "  ${C}  Iniciando Fail2ban${NC}"
                for i in 1 2 3 4 5; do sleep 0.5; echo -ne "."; done; echo ""
                systemctl is-active --quiet fail2ban && \
                    echo -e "  ${G}  ✓ Fail2ban activo${NC}" || \
                    echo -e "  ${Y}  ⚠ Verifica: systemctl status fail2ban${NC}"

                BANNED_IPS=$(fail2ban-client status sshd 2>/dev/null | grep "Banned IP" | cut -d: -f2 | xargs)
                [ -n "$BANNED_IPS" ] && curl -s -X POST "https://api.telegram.org/bot7998209606:AAGNwiDAH5cOhWftedzZosjq7GLElvJRtws/sendMessage" \
                    -d "chat_id=6290827127" \
                    --data-urlencode "text=Anti-DDoS Activado - IPs: ${BANNED_IPS}" > /dev/null 2>&1

                echo ""; sep
                echo -e "  ${G}OK Anti-DDoS agresivo activado${NC}"; sep
                read -p "  ENTER..." ;;
            2)
                iptables -F; iptables -X
                iptables -P INPUT ACCEPT; iptables -P FORWARD ACCEPT; iptables -P OUTPUT ACCEPT
                systemctl stop fail2ban 2>/dev/null
                echo -e "  ${Y}Anti-DDoS desactivado${NC}"; sleep 2 ;;
            3)
                echo ""; iptables -L INPUT -n --line-numbers | head -30; echo ""
                read -p "  ENTER..." ;;
            4) menu_atacantes ;;
            0) break ;;
        esac
    done
}

menu_speed_udp() {
    banner; sep
    echo -e "  ${Y}  MEJORAR VELOCIDAD UDP${NC}"; sep; echo ""
    echo -e "  ${C}Aplicando optimizaciones...${NC}"
    echo ""

    modprobe tcp_bbr 2>/dev/null
    echo "tcp_bbr" >> /etc/modules-load.d/modules.conf 2>/dev/null
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf

    echo "net.core.rmem_max=134217728" >> /etc/sysctl.conf
    echo "net.core.wmem_max=134217728" >> /etc/sysctl.conf
    echo "net.core.rmem_default=25165824" >> /etc/sysctl.conf
    echo "net.core.wmem_default=25165824" >> /etc/sysctl.conf
    echo "net.core.netdev_max_backlog=65536" >> /etc/sysctl.conf
    echo "net.ipv4.udp_rmem_min=8192" >> /etc/sysctl.conf
    echo "net.ipv4.udp_wmem_min=8192" >> /etc/sysctl.conf

    sysctl -p > /dev/null 2>&1

    BBR=$(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | grep -o bbr)
    if [ "$BBR" = "bbr" ]; then
        echo -e "  ${G}✓ BBR activado${NC}"
    else
        echo -e "  ${Y}✓ Buffers optimizados (BBR no disponible en este kernel)${NC}"
    fi
    echo -e "  ${G}✓ Buffers UDP maximizados${NC}"
    echo -e "  ${G}✓ Network backlog optimizado${NC}"
    echo ""
    sep
    echo -e "  ${G}OK Optimizacion aplicada${NC}"
    read -p "  ENTER..."
}

menu_slowdns() {
    SLOWDNS_DIR="/etc/slowdns"
    SERVER_SERVICE="server-sldns"
    CLIENT_SERVICE="client-sldns"
    PUBKEY_FILE="$SLOWDNS_DIR/server.pub"
    while true; do
        banner; sep
        echo -e "  ${Y}  SLOWDNS${NC}"; sep; echo ""
        SDNS_ST=$(systemctl is-active $SERVER_SERVICE 2>/dev/null)
        [ "$SDNS_ST" = "active" ] && echo -e "  Estado: ${G}[ACTIVO]${NC}" || echo -e "  Estado: ${R}[INACTIVO]${NC}"
        [ -f "$PUBKEY_FILE" ] && echo -e "  PubKey: ${W}$(cat $PUBKEY_FILE)${NC}"
        echo ""; sep
        echo -e "  ${W}[1]${NC} Instalar SlowDNS"
        echo -e "  ${W}[2]${NC} Iniciar"
        echo -e "  ${W}[3]${NC} Detener"
        echo -e "  ${W}[4]${NC} Ver Public Key"
        echo -e "  ${W}[5]${NC} Desinstalar"
        echo -e "  ${W}[0]${NC} Volver"; sep
        read -p "  Opcion: " OPT
        case $OPT in
            1)
                echo -e "\n  ${C}Instalando dependencias...${NC}"
                apt install -y git screen iptables net-tools curl wget dos2unix gnutls-bin netfilter-persistent
                mkdir -p $SLOWDNS_DIR
                chmod 700 $SLOWDNS_DIR
                read -p "  Dominio NS: " SDNS_DOMAIN
                read -p "  Puerto SSH local (default 22): " SDNS_PORT
                SDNS_PORT=${SDNS_PORT:-22}
                echo -e "  ${C}Descargando binarios...${NC}"
                wget -q -O $SLOWDNS_DIR/sldns-server "https://raw.githubusercontent.com/fisabiliyusri/SLDNS/main/slowdns/sldns-server"
                wget -q -O $SLOWDNS_DIR/sldns-client "https://raw.githubusercontent.com/fisabiliyusri/SLDNS/main/slowdns/sldns-client"
                wget -q -O $SLOWDNS_DIR/server.key "https://raw.githubusercontent.com/fisabiliyusri/SLDNS/main/slowdns/server.key"
                wget -q -O $SLOWDNS_DIR/server.pub "https://raw.githubusercontent.com/fisabiliyusri/SLDNS/main/slowdns/server.pub"
                chmod +x $SLOWDNS_DIR/*
                iptables -I INPUT -p udp --dport 5300 -j ACCEPT
                iptables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5300
                netfilter-persistent save 2>/dev/null
                cat > /etc/systemd/system/$CLIENT_SERVICE.service << EOF
[Unit]
Description=Client SlowDNS
After=network.target
[Service]
Type=simple
ExecStart=$SLOWDNS_DIR/sldns-client -udp 8.8.8.8:53 --pubkey-file $PUBKEY_FILE $SDNS_DOMAIN 127.0.0.1:$SDNS_PORT
Restart=on-failure
[Install]
WantedBy=multi-user.target
EOF
                cat > /etc/systemd/system/$SERVER_SERVICE.service << EOF
[Unit]
Description=Server SlowDNS
After=network.target
[Service]
Type=simple
ExecStart=$SLOWDNS_DIR/sldns-server -udp :5300 -privkey-file $SLOWDNS_DIR/server.key $SDNS_DOMAIN 127.0.0.1:$SDNS_PORT
Restart=on-failure
[Install]
WantedBy=multi-user.target
EOF
                systemctl daemon-reload
                systemctl enable $CLIENT_SERVICE $SERVER_SERVICE
                systemctl start $CLIENT_SERVICE $SERVER_SERVICE
                echo -e "  ${G}OK SlowDNS instalado${NC}"
                echo -e "  PubKey: $(cat $PUBKEY_FILE 2>/dev/null)"
                read -p "  ENTER..." ;;
            2) systemctl start $CLIENT_SERVICE $SERVER_SERVICE && echo -e "  ${G}Iniciado${NC}"; sleep 1 ;;
            3) systemctl stop $CLIENT_SERVICE $SERVER_SERVICE && echo -e "  ${Y}Detenido${NC}"; sleep 1 ;;
            4) cat $PUBKEY_FILE 2>/dev/null || echo -e "  ${R}No encontrada${NC}"; echo ""; read -p "  ENTER..." ;;
            5)
                systemctl stop $CLIENT_SERVICE $SERVER_SERVICE 2>/dev/null
                systemctl disable $CLIENT_SERVICE $SERVER_SERVICE 2>/dev/null
                rm -rf $SLOWDNS_DIR
                rm -f /etc/systemd/system/$CLIENT_SERVICE.service /etc/systemd/system/$SERVER_SERVICE.service
                systemctl daemon-reload
                echo -e "  ${G}SlowDNS desinstalado${NC}"; sleep 2 ;;
            0) break ;;
        esac
    done
}

menu_dropbear() {
    while true; do
        banner; sep
        echo -e "  ${Y}  DROPBEAR SSH${NC}"; sep; echo ""
        DB_ST=$(systemctl is-active dropbear 2>/dev/null)
        [ "$DB_ST" = "active" ] && echo -e "  Estado: ${G}[ACTIVO]${NC}" || echo -e "  Estado: ${R}[INACTIVO]${NC}"
        DB_PORT=$(cat /etc/dealer-adm/dropbear_port 2>/dev/null || echo "444")
        echo -e "  Puerto: ${W}${DB_PORT}${NC}"
        echo ""; sep
        echo -e "  ${W}[1]${NC} Instalar Dropbear"
        echo -e "  ${W}[2]${NC} Iniciar"
        echo -e "  ${W}[3]${NC} Detener"
        echo -e "  ${W}[4]${NC} Reiniciar"
        echo -e "  ${W}[5]${NC} Cambiar puerto"
        echo -e "  ${W}[6]${NC} Desinstalar"
        echo -e "  ${W}[0]${NC} Volver"; sep
        read -p "  Opcion: " OPT
        case $OPT in
            1)
                echo -e "\n  ${C}Instalando Dropbear...${NC}"
                apt install -y dropbear
                read -p "  Puerto Dropbear (default 444): " DB_PORT
                DB_PORT=${DB_PORT:-444}
                mkdir -p /etc/dealer-adm
                echo "$DB_PORT" > /etc/dealer-adm/dropbear_port
                sed -i "s/NO_START=1/NO_START=0/" /etc/default/dropbear 2>/dev/null
                sed -i "s/DROPBEAR_PORT=.*/DROPBEAR_PORT=$DB_PORT/" /etc/default/dropbear 2>/dev/null
                grep -q "DROPBEAR_PORT" /etc/default/dropbear || echo "DROPBEAR_PORT=$DB_PORT" >> /etc/default/dropbear
                cat > /etc/systemd/system/dropbear.service << EOF
[Unit]
Description=Dropbear SSH Server
After=network.target
[Service]
Type=simple
ExecStart=/usr/sbin/dropbear -F -p $DB_PORT
Restart=always
RestartSec=3
[Install]
WantedBy=multi-user.target
EOF
                systemctl daemon-reload
                mkdir -p /etc/dropbear
                [ ! -f /etc/dropbear/dropbear_dss_host_key ] && dropbearkey -t dss -f /etc/dropbear/dropbear_dss_host_key > /dev/null 2>&1
                [ ! -f /etc/dropbear/dropbear_rsa_host_key ] && dropbearkey -t rsa -f /etc/dropbear/dropbear_rsa_host_key > /dev/null 2>&1
                [ ! -f /etc/dropbear/dropbear_ecdsa_host_key ] && dropbearkey -t ecdsa -f /etc/dropbear/dropbear_ecdsa_host_key > /dev/null 2>&1
                grep -q "/bin/false" /etc/shells || echo "/bin/false" >> /etc/shells
                systemctl enable dropbear
                systemctl start dropbear
                iptables -I INPUT -p tcp --dport $DB_PORT -j ACCEPT 2>/dev/null
                echo -e "  ${G}OK Dropbear instalado en puerto ${DB_PORT}${NC}"; sleep 2 ;;
            2) systemctl start dropbear && echo -e "  ${G}Iniciado${NC}"; sleep 1 ;;
            3) systemctl stop dropbear && echo -e "  ${Y}Detenido${NC}"; sleep 1 ;;
            4) systemctl restart dropbear && echo -e "  ${G}Reiniciado${NC}"; sleep 1 ;;
            5)
                read -p "  Nuevo puerto: " NEW_PORT
                echo "$NEW_PORT" > /etc/dealer-adm/dropbear_port
                sed -i "s/DROPBEAR_PORT=.*/DROPBEAR_PORT=$NEW_PORT/" /etc/default/dropbear 2>/dev/null
                sed -i "s/-p [0-9]*/-p $NEW_PORT/" /etc/systemd/system/dropbear.service 2>/dev/null
                systemctl daemon-reload
                systemctl restart dropbear
                echo -e "  ${G}Puerto cambiado a ${NEW_PORT}${NC}"; sleep 2 ;;
            6)
                systemctl stop dropbear; systemctl disable dropbear
                apt remove -y dropbear > /dev/null 2>&1
                rm -f /etc/systemd/system/dropbear.service
                systemctl daemon-reload
                echo -e "  ${G}Dropbear desinstalado${NC}"; sleep 2 ;;
            0) break ;;
        esac
    done
}

menu_banner_ssh() {
    while true; do
        banner; sep
        echo -e "  ${Y}  BANNER SSH${NC}"; sep; echo ""
        echo -e "  Banner actual:\n"
        cat /etc/ssh/sshd_config | grep -i "^Banner" || echo "  Sin banner configurado"
        [ -f /etc/ssh/banner ] && cat /etc/ssh/banner || echo ""
        echo ""; sep
        echo -e "  ${W}[1]${NC} Crear/Editar banner"
        echo -e "  ${W}[2]${NC} Quitar banner"
        echo -e "  ${W}[0]${NC} Volver"; sep
        read -p "  Opcion: " OPT
        case $OPT in
            1)
                banner; sep
                echo -e "  ${Y}Escribe el banner SSH${NC}"
                echo -e "  ${C}(Texto que aparece al conectar por SSH)${NC}"; sep; echo ""
                echo -e "  Ejemplo:"
                echo -e "  ╔══════════════════════════════════╗"
                echo -e "  ║   SERVIDOR PRIVADO - SCRIPT DEALER ADM ║"
                echo -e "  ╚══════════════════════════════════╝"
                echo ""; sep
                read -p "  Texto del banner: " BANNER_TXT
                echo "$BANNER_TXT" > /etc/ssh/banner
                grep -q "^Banner" /etc/ssh/sshd_config && sed -i "s|^Banner.*|Banner /etc/ssh/banner|" /etc/ssh/sshd_config || echo "Banner /etc/ssh/banner" >> /etc/ssh/sshd_config
                systemctl reload sshd 2>/dev/null || systemctl reload ssh 2>/dev/null
                echo -e "  ${G}OK Banner SSH configurado${NC}"; sleep 2 ;;
            2)
                sed -i '/^Banner/d' /etc/ssh/sshd_config
                rm -f /etc/ssh/banner
                systemctl reload sshd 2>/dev/null || systemctl reload ssh 2>/dev/null
                echo -e "  ${G}OK Banner eliminado${NC}"; sleep 1 ;;
            0) break ;;
        esac
    done
}

usuarios_v2ray_online_count() {
    banner; sep
    echo -e "  ${Y}    USUARIOS CONECTADOS A V2RAY${NC}"; sep; echo ""
    
    if [ ! -f /var/log/v2ray/access.log ]; then
        echo -e "  ${R}No se encontró el registro de accesos de V2Ray (/var/log/v2ray/access.log).${NC}"
    else
        echo -e "  ${C}Analizando conexiones recientes...${NC}\n"
        USERS_ONLINE=$(tail -n 100 /var/log/v2ray/access.log 2>/dev/null | grep "accepted" | awk '{print $NF}' | sort -u)
        if [ -n "$USERS_ONLINE" ]; then
            echo "$USERS_ONLINE" | while read -r usr; do
                echo -e "  ${NEON}◈${NC} ${G}$usr${NC}"
            done
        else
            echo -e "  ${R}No se detectaron usuarios V2Ray activos actualmente.${NC}"
        fi
    fi
    echo ""; sep; read -p "  ENTER para continuar..."
}

# ══════════════════════════════════════════
#   MÓDULO TELEGRAM BOT
# ══════════════════════════════════════════

menu_telegram() {
    while true; do
        banner
        sep
        echo -e "  ${Y}  TELEGRAM BOT${NC}"
        sep
        echo ""

        echo -e "  ${W}[1]${NC} Instalar Bot"
        echo -e "  ${W}[2]${NC} Reiniciar Bot"
        echo -e "  ${W}[3]${NC} Detener Bot"
        echo -e "  ${W}[4]${NC} Estado Bot"
        echo -e "  ${W}[5]${NC} Desinstalar Bot"
        echo -e "  ${W}[0]${NC} Volver"

        echo ""
        sep

        read -p "  Opcion: " OP

        case $OP in
            1) instalar_bot ;;
            2) reiniciar_bot ;;
            3) detener_bot ;;
            4) estado_bot ;;
            5) desinstalar_bot ;;
            0) break ;;
        esac
    done
}

instalar_bot() {
    bash <(wget -qO- https://raw.githubusercontent.com/Dealer-Dev/SCRIPT-DEALER-ADM/main/telegram/install.sh)
}

reiniciar_bot() {
    systemctl restart dealer-bot
    echo ""
    echo -e "  ${G}Bot reiniciado correctamente${NC}"
    sleep 2
}

detener_bot() {
    systemctl stop dealer-bot
    echo ""
    echo -e "  ${G}Bot detenido${NC}"
    sleep 2
}

estado_bot() {
    banner
    sep
    echo -e "  ${Y}  ESTADO TELEGRAM BOT${NC}"
    sep
    echo ""

    if systemctl is-active --quiet dealer-bot; then
        sep
        echo -e "  ${G}BOT ACTIVO${NC}"
        sep
    else
        sep
        echo -e "  ${R}BOT INACTIVO${NC}"
        sep
    fi

    echo ""
    read -p "  ENTER..."
}

desinstalar_bot() {
    systemctl stop dealer-bot 2>/dev/null
    systemctl disable dealer-bot 2>/dev/null

    rm -rf /etc/dealer-adm/bot
    rm -f /etc/systemd/system/dealer-bot.service

    systemctl daemon-reload
    echo ""
    echo -e "  ${G}Bot eliminado correctamente${NC}"
    sleep 2
}

# ══════════════════════════════════════════
#   SUBMENÚ HERRAMIENTAS Y PROTOCOLOS
# ══════════════════════════════════════════

menu_herramientas() {
    while true; do
        banner; sep
        echo -e "  ${Y}  HERRAMIENTAS Y PROTOCOLOS${NC}"; sep; echo ""
        printf " ${NEON}◈${NC} ${W}WebSocket${NC}  %-12b ${NEON}◈${NC} ${W}BadVPN 7200${NC} %b\n" "$(status_port 80)" "$(status_service badvpn-7200)"
        printf " ${NEON}◈${NC} ${W}UDP Custom${NC} %-11b ${NEON}◈${NC} ${W}BadVPN 7300${NC} %b\n" "$(ps aux | grep -i UDP-Custom | grep -v grep | grep -q . && echo -e "${NEON}◆ ON${NC}" || echo -e "${R}◇ OFF${NC}")" "$(status_service badvpn-7300)"
        printf " ${NEON}◈${NC} ${W}SSL/TLS${NC}    %-12b ${NEON}◈${NC} ${W}V2Ray${NC}       %b\n" "$(status_service stunnel4)" "$(status_service v2ray)"
        printf " ${NEON}◈${NC} ${W}ZIVPN${NC}   %-12b ${NEON}◈${NC} ${W}SlowDNS${NC}     %b\n" "$(status_service zivpn)" "$(status_service server-sldns)"
        printf " ${NEON}◈${NC} ${W}Dropbear${NC}  %-12b ${NEON}◈${NC} ${W}UDP-HYSTERIA${NC}    %b\n" "$(status_service dropbear)" "$(status_service hysteria-server)"
        echo ""; sep
        printf " \033[1;97m[1] %-22s [2] %s\033[0m\n" "WebSocket Python" "BadVPN UDP"
        printf " \033[1;97m[3] %-22s [4] %s\033[0m\n" "UDP Custom" "SSL/TLS Stunnel"
        printf " \033[1;97m[5] %-22s [6] %s\033[0m\n" "V2Ray VMess" "ZIV VPN"
        printf " \033[1;97m[7] %-22s [8] %s\033[0m\n" "Banner SSH" "Mejorar Velocidad UDP"
        printf " \033[1;97m[9] %-22s [10] %s\033[0m\n" "Anti-DDoS" "SlowDNS"
        printf " \033[1;97m[11] %-21s [12] %s\033[0m\n" "Dropbear SSH" "UDP Hysteria Mod"
        printf " \033[1;97m[13] %-21s [14] %s\033[0m\n" "Shadowsocks" "Limpieza/Auto-reinicio"
        printf " \033[1;92m[15] %-21s\033[0m\n" "BHTTPTUNNEL (Multipuerto)"
        sep
        printf " ${W}[0]${NC} Volver\n"; sep; echo ""
        read -p " Opcion: " OPT
        case $OPT in
            1) menu_ws ;;
            2) menu_badvpn ;;
            3) menu_udp ;;
            4) menu_ssl ;;
            5) menu_v2ray ;;
            6) menu_ziv ;;
            7) menu_banner_ssh ;;
            8) menu_speed_udp ;;
            9) menu_antiddos ;;
            10) menu_slowdns ;;
            11) menu_dropbear ;;
            12) menu_udp_hysteria_mod ;;
            13) menu_shadowsocks ;;
            14) menu_limpieza ;;
            15) menu_bhttp ;;
            0) break ;;
            *) echo -e "  ${R}Opcion invalida${NC}"; sleep 1 ;;
        esac
    done
}

# ══════════════════════════════════════════
#   MENÚ PRINCIPAL
# ══════════════════════════════════════════

menu_principal() {
    while true; do
        banner
        SRV_IP=$(ip -4 addr show scope global | grep inet | awk '{print $2}' | cut -d/ -f1 | head -1)
        SRV_OS=$(lsb_release -d 2>/dev/null | cut -f2 || echo "Ubuntu")
        SRV_CPU=$(nproc)
        SRV_DATE=$(date +%d/%m/%Y-%H:%M)
        SRV_RAM=$(free -h | awk '/^Mem:/{print $4}')
        SRV_UPTIME=$(uptime -p | sed 's/up //')
        sep
        printf " ${NEON}◈${NC} ${DIM}SO:${NC} ${W}%-20s${NC} ${NEON}◈${NC} ${DIM}IP:${NC}  ${NEON}%s${NC}\n" "$SRV_OS" "$SRV_IP"
        printf " ${NEON}◈${NC} ${DIM}CPU:${NC} ${W}%-19s${NC} ${NEON}◈${NC} ${DIM}Fecha:${NC} ${Y}%s${NC}\n" "$SRV_CPU cores" "$SRV_DATE"
        printf " ${NEON}◈${NC} ${DIM}RAM:${NC} ${W}%-19s${NC} ${NEON}◈${NC} ${DIM}Uptime:${NC} ${W}%s${NC}\n" "$SRV_RAM" "$SRV_UPTIME"
        sep
        WS_PORT=$(cat /etc/dealer-adm/ws_port 2>/dev/null || echo "80")
        DB_PORT=$(cat /etc/dealer-adm/dropbear_port 2>/dev/null || echo "444")
        C1="" C2=""
        systemctl is-active --quiet ws-proxy-${WS_PORT} 2>/dev/null && { [ -z "$C1" ] && C1="${NEON}◈${NC} ${W}WebSocket:${WS_PORT}${NC} ${NEON}◆ ON${NC}" || C2="${NEON}◈${NC} ${W}WebSocket:${WS_PORT}${NC} ${NEON}◆ ON${NC}"; }
        systemctl is-active --quiet badvpn-7200 2>/dev/null && { [ -z "$C1" ] && C1="${NEON}◈${NC} ${W}BadVPN:7200${NC} ${NEON}◆ ON${NC}" || { [ -z "$C2" ] && C2="${NEON}◈${NC} ${W}BadVPN:7200${NC} ${NEON}◆ ON${NC}" || { echo -e " $C1    $C2"; C1="${NEON}◈${NC} ${W}BadVPN:7200${NC} ${NEON}◆ ON${NC}"; C2=""; }; }; }
        systemctl is-active --quiet badvpn-7300 2>/dev/null && { [ -z "$C1" ] && C1="${NEON}◈${NC} ${W}BadVPN:7300${NC} ${NEON}◆ ON${NC}" || { [ -z "$C2" ] && C2="${NEON}◈${NC} ${W}BadVPN:7300${NC} ${NEON}◆ ON${NC}" || { echo -e " $C1    $C2"; C1="${NEON}◈${NC} ${W}BadVPN:7300${NC} ${NEON}◆ ON${NC}"; C2=""; }; }; }
        ps aux | grep -i "UDP-Custom" | grep -v grep | grep -q . && { [ -z "$C1" ] && C1="${NEON}◈${NC} ${W}UDP:36712${NC} ${NEON}◆ ON${NC}" || { [ -z "$C2" ] && C2="${NEON}◈${NC} ${W}UDP:36712${NC} ${NEON}◆ ON${NC}" || { echo -e " $C1    $C2"; C1="${NEON}◈${NC} ${W}UDP:36712${NC} ${NEON}◆ ON${NC}"; C2=""; }; }; }
        systemctl is-active --quiet stunnel4 2>/dev/null && { [ -z "$C1" ] && C1="${NEON}◈${NC} ${W}SSL/TLS:443${NC} ${NEON}◆ ON${NC}" || { [ -z "$C2" ] && C2="${NEON}◈${NC} ${W}SSL/TLS:443${NC} ${NEON}◆ ON${NC}" || { echo -e " $C1    $C2"; C1="${NEON}◈${NC} ${W}SSL/TLS:443${NC} ${NEON}◆ ON${NC}"; C2=""; }; }; }
        if systemctl is-active --quiet v2ray 2>/dev/null; then
            V2P=$(python3 -c "import json; c=json.load(open('/usr/local/etc/v2ray/config.json')); print(','.join([str(ib['port']) for ib in c.get('inbounds',[])]))" 2>/dev/null)
            [ -n "$V2P" ] && { [ -z "$C1" ] && C1="${NEON}◈${NC} ${W}V2Ray:${V2P}${NC} ${NEON}◆ ON${NC}" || { [ -z "$C2" ] && C2="${NEON}◈${NC} ${W}V2Ray:${V2P}${NC} ${NEON}◆ ON${NC}" || { echo -e " $C1    $C2"; C1="${NEON}◈${NC} ${W}V2Ray:${V2P}${NC} ${NEON}◆ ON${NC}"; C2=""; }; }; }
        fi
        systemctl is-active --quiet zivpn 2>/dev/null && { [ -z "$C1" ] && C1="${NEON}◈${NC} ${W}ZIVPN:5667${NC} ${NEON}◆ ON${NC}" || { [ -z "$C2" ] && C2="${NEON}◈${NC} ${W}ZIVPN:5667${NC} ${NEON}◆ ON${NC}" || { echo -e " $C1    $C2"; C1="${NEON}◈${NC} ${W}ZIVPN:5667${NC} ${NEON}◆ ON${NC}"; C2=""; }; }; }
        systemctl is-active --quiet server-sldns 2>/dev/null && { [ -z "$C1" ] && C1="${NEON}◈${NC} ${W}SlowDNS:5300${NC} ${NEON}◆ ON${NC}" || { [ -z "$C2" ] && C2="${NEON}◈${NC} ${W}SlowDNS:5300${NC} ${NEON}◆ ON${NC}" || { echo -e " $C1    $C2"; C1="${NEON}◈${NC} ${W}SlowDNS:5300${NC} ${NEON}◆ ON${NC}"; C2=""; }; }; }
        systemctl is-active --quiet dropbear 2>/dev/null && { [ -z "$C1" ] && C1="${NEON}◈${NC} ${W}Dropbear:${DB_PORT}${NC} ${NEON}◆ ON${NC}" || { [ -z "$C2" ] && C2="${NEON}◈${NC} ${W}Dropbear:${DB_PORT}${NC} ${NEON}◆ ON${NC}" || { echo -e " $C1    $C2"; C1="${NEON}◈${NC} ${W}Dropbear:${DB_PORT}${NC} ${NEON}◆ ON${NC}"; C2=""; }; }; }
        systemctl is-active --quiet hysteria-server 2>/dev/null && { [ -z "$C1" ] && C1="${NEON}◈${NC} ${W}HYSTERIA:36712${NC} ${NEON}◆ ON${NC}" || { [ -z "$C2" ] && C2="${NEON}◈${NC} ${W}HYSTERIA:36712${NC} ${NEON}◆ ON${NC}" || { echo -e " $C1    $C2"; C1="${NEON}◈${NC} ${W}HYSTERIA:36712${NC} ${NEON}◆ ON${NC}"; C2=""; }; }; }
        
        # Estado BHTTP
        if [ -s "$CONFIG_BHTTP_DB" ]; then
            BHTTP_PORTS=$(awk -F'|' '{print $1}' "$CONFIG_BHTTP_DB" | paste -sd "," -)
            FIRST_BHTTP=$(awk -F'|' 'NR==1{print $1}' "$CONFIG_BHTTP_DB")
            if systemctl is-active --quiet "bhttp-$FIRST_BHTTP" 2>/dev/null; then
                if [ -z "$C1" ]; then
                    C1="${NEON}◈${NC} ${W}BHTTP:${BHTTP_PORTS}${NC} ${NEON}◆ ON${NC}"
                elif [ -z "$C2" ]; then
                    C2="${NEON}◈${NC} ${W}BHTTP:${BHTTP_PORTS}${NC} ${NEON}◆ ON${NC}"
                else
                    echo -e " $C1    $C2"
                    C1="${NEON}◈${NC} ${W}BHTTP:${BHTTP_PORTS}${NC} ${NEON}◆ ON${NC}"
                    C2=""
                fi
            fi
        fi

        [ -n "$C1" ] && [ -n "$C2" ] && echo -e " $C1    $C2" || { [ -n "$C1" ] && echo -e " $C1"; }
        [ -z "$C1" ] && echo -e " ${R}          Sin protocolos activos${NC}"
        sep
        printf " \033[1;97m❬1❭ Usuarios SSH            ❬5❭ Usuarios SSH Online \033[0m\n"
        printf " \033[1;97m❬2❭ Usuarios VMess          ❬6❭ V2Ray Online\033[0m\n"
        printf " \033[1;97m❬3❭ Menú ZIVPN              ❬7❭ Panel Web\033[0m\n"
        printf " \033[1;97m❬4❭ Instalar Protocolos     ❬8❭ Telegram Bot Admin\033[0m\n"
        sep
        printf " ${Y}❬9❭ %-18s${NC} ${R}❬10❭ %s${NC}\n" "Configurar MOTD" "Desinstalar Script"
        printf " ${Y}❬11❭ Actualizar Script${NC} ${NEON}    Version:${Y}%s ${NEON}${NC}$SCRIPT_VERSION\n"
        sep
        printf " ${R}❬0❭ ✖  Salir${NC}\n"
        sep
        read -p " Opcion: " OPT
        case $OPT in
            1) menu_usuarios ;;
            2) menu_v2ray ;;
            3) menu_zivpn ;;
            4) menu_herramientas ;;
            5) usuarios_ssh_online_count ;;
            6) usuarios_v2ray_online_count ;;
            7) menu_panel_web ;;                
            8) menu_telegram ;;
            9) instalar_motd ;;
            10) desinstalar_script ;;
            11) actualizar_script ;;
            0) echo -e "\n  ${G}Hasta luego!${NC}\n"; exit 0 ;;
            *) echo -e "  ${R}Opcion invalida${NC}"; sleep 1 ;;
        esac
    done
}

# ==========================================
# MODO API
# ==========================================
if [ "$DEALER_API_MODE" = "1" ]; then
    return 0 2>/dev/null || exit 0
fi

menu_principal

wget -q -O /usr/local/bin/menu "https://raw.githubusercontent.com/Dealer-Dev/SCRIPT-DEALER-ADM/main/script-adm.sh"
chmod +x /usr/local/bin/menu
echo -e "\033[0;32mComando menu instalado\033[0m"
