<?php
session_start();
include __DIR__ . "/db.php";
include __DIR__ . "/lang.php";

if (!isset($_SESSION['user']) || $_SESSION['role'] != 'reseller') {
    header("Location: login.php");
    exit();
}

$username = $_SESSION['user'];
$stmt = $conn->prepare("SELECT * FROM users WHERE username=?");
$stmt->bind_param("s", $username);
$stmt->execute();
$reseller = $stmt->get_result()->fetch_assoc();

// Archivo de contraseña Token personalizada del revendedor
$reseller_token_pass_file = "/etc/dealer-adm/resellers/token_pass_" . $username . ".txt";

// GUARDAR CONTRASEÑA TOKEN GLOBAL DEL REVENDEDOR
if(isset($_POST['guardar_token_pass'])){
    $new_t_pass = trim($_POST['custom_token_pass']);
    if (!file_exists('/etc/dealer-adm/resellers')) {
        exec("sudo mkdir -p /etc/dealer-adm/resellers && sudo chmod 777 /etc/dealer-adm/resellers");
    }
    if(!empty($new_t_pass)){
        file_put_contents($reseller_token_pass_file, $new_t_pass);
    } else {
        file_put_contents($reseller_token_pass_file, "dealer");
    }
    header("Location: reseller.php?token_pass_ok=1");
    exit();
}

// Obtener la contraseña token actual del revendedor (por defecto 'dealer')
$token_pass_actual = file_exists($reseller_token_pass_file) ? trim(file_get_contents($reseller_token_pass_file)) : "dealer";
if(empty($token_pass_actual)) { $token_pass_actual = "dealer"; }

if(isset($_POST['crear_ssh'])){
    if($reseller['credits'] <= 0){
        header("Location: reseller.php?error=1");
        exit();
    }

    $tipo = $_POST['tipo'];
    
    if($tipo == "ssh"){
        $ssh_user = trim($_POST['ssh_user']);
        $ssh_pass = trim($_POST['ssh_pass']);
        $ref = $ssh_user;
    } elseif($tipo == "token"){
        $ssh_user = trim($_POST['token_user']);
        $ssh_pass = $token_pass_actual;
        $ref = trim($_POST['ref_token']);
    } elseif($tipo == "hwid"){
        $ssh_user = trim($_POST['hwid']);
        $ssh_pass = trim($_POST['hwid']);
        $ref = trim($_POST['ref_hwid']);
    }

    if(empty($ssh_user) || empty($ssh_pass)){
        header("Location: reseller.php?error=3");
        exit();
    }

    $expire_date = date("Y-m-d", strtotime("+30 days"));
    
    // Crear usuario real en Linux forzando permisos de shell y contraseña limpia
    $cmd_system = "sudo useradd -M -s /bin/false -e $expire_date $ssh_user && echo '$ssh_user:$ssh_pass' | sudo chpasswd && sudo chage -E $expire_date -M 99999 -m 0 -I -1 -W 7 $ssh_user && sudo usermod -f 0 $ssh_user";
    exec($cmd_system);

    $file_content = "tipo: $tipo\nnombre: $ref\nusuario: $ssh_user\npassword: $ssh_pass\nfecha: $expire_date\nlimite: 1\ncreador_id: 0\ncreador_nombre: $username";
    
    $tmp_file = tempnam(sys_get_temp_dir(), 'usr_');
    file_put_contents($tmp_file, $file_content);
    exec("sudo mkdir -p /etc/dealer-adm/userDIR/ && sudo mv $tmp_file /etc/dealer-adm/userDIR/$ssh_user && sudo chmod 644 /etc/dealer-adm/userDIR/$ssh_user");

    if(file_exists('/etc/hysteria/config.json')){
        $sync_hys = "python3 -c \"
import json, os
p = '/etc/hysteria/config.json'
if os.path.exists(p):
    try:
        with open(p, 'r') as f: c = json.load(f)
        auth = c.get('auth', {})
        cfg = auth.get('config', [])
        if not isinstance(cfg, list): cfg = []
        entry = '$ssh_user:$ssh_pass'
        if entry not in cfg:
            cfg.append(entry)
            c['auth']['config'] = cfg
            with open(p, 'w') as f: json.dump(c, f, indent=2)
    except Exception:
        pass
\" && sudo systemctl restart hysteria-server >/dev/null 2>&1";
        exec($sync_hys);
    }

    $conn->query("UPDATE users SET credits = credits - 1 WHERE id='".$reseller['id']."'");
    $conn->query("INSERT INTO ssh_accounts (reseller, username, password, type, reference_name, expires) 
                  VALUES ('$username', '$ssh_user', '$ssh_pass', '$tipo', '$ref', '$expire_date')");

    header("Location: reseller.php?ok=1&tipo=$tipo&ref=".urlencode($ref)."&u=".urlencode($ssh_user)."&p=".urlencode($ssh_pass)."&e=$expire_date");
    exit();
}

// Cargar IP y Dominio
$server_ip = $_SERVER['SERVER_ADDR'] ?? exec("curl -s -4 ifconfig.me") ?? "127.0.0.1";
$cf_domain = file_exists('/etc/dealer-adm/cf_domain') ? trim(file_get_contents('/etc/dealer-adm/cf_domain')) : '';

// LECTURA DE PERMISOS INDIVIDUALES DEL RESELLER
$perm_file = '/etc/dealer-adm/resellers/' . $username . '.json';
$reseller_perms = file_exists($perm_file) ? json_decode(file_get_contents($perm_file), true) : ['show_gcp' => 1, 'show_cf' => 1];

$payload_gcp = ($reseller_perms['show_gcp'] ?? 0) && file_exists('/etc/dealer-adm/payload_gcp.txt') ? trim(file_get_contents('/etc/dealer-adm/payload_gcp.txt')) : '';
$payload_cf  = ($reseller_perms['show_cf'] ?? 0) && file_exists('/etc/dealer-adm/payload_cloudfront.txt') ? trim(file_get_contents('/etc/dealer-adm/payload_cloudfront.txt')) : '';
?>
<!DOCTYPE html>
<html>
<head>
<title><?php echo __('reseller_title'); ?></title>
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<style>
*{box-sizing:border-box;}
body{margin:0;font-family:'Segoe UI',sans-serif;background:#f4f6f9;}
.container{max-width:550px;margin:30px auto;background:#fff;padding:25px;border-radius:18px;box-shadow:0 8px 30px rgba(0,0,0,0.06);}
.credit-badge{background:#198754;color:#fff;padding:8px 15px;border-radius:20px;display:inline-block;margin-top:10px;font-weight:600;}
select,input{width:100%;padding:12px;margin-top:12px;border-radius:10px;border:1px solid #ddd;}
button,.btn-copy{width:100%;margin-top:12px;padding:12px;border:none;border-radius:10px;background:linear-gradient(135deg,#0d6efd,#6610f2);color:#fff;font-weight:600;cursor:pointer;}
.btn-online{background:linear-gradient(135deg,#0dcaf0,#0d6efd);margin-top:12px;}
.btn-tpass{background:linear-gradient(135deg,#eab308,#ca8a04);margin-top:10px;display:none;}
.btn-copy{background:#198754;}
.links{margin-top:20px;display:flex;justify-content:space-between;}
.links a{text-decoration:none;font-weight:600;}
.modal{position:fixed;top:0;left:0;width:100%;height:100%;background:rgba(0,0,0,0.5);display:none;align-items:center;justify-content:center;z-index:999;}
.modal-box{background:#fff;padding:25px;border-radius:16px;width:90%;max-width:380px;text-align:left;max-height:85vh;overflow-y:auto;}
.modal-box h3{margin-top:0;text-align:center;}
.info-row{margin-bottom:8px;font-size:14px;}
.info-row b{color:#333;}
.payload-box{background:#f8f9fa;border:1px solid #e9ecef;padding:10px;border-radius:8px;font-family:monospace;font-size:12px;word-break:break-all;margin-top:5px;max-height:80px;overflow-y:auto;}
</style>
</head>
<body>
<div class="container">
    <h2><?php echo __('user'); ?>: <?php echo htmlspecialchars($username); ?></h2>
    <div class="credit-badge"><?php echo __('available_credits'); ?>: <?php echo $reseller['credits']; ?></div>

    <button class="btn-online" onclick="cargarOnline()"><?php echo __('view_online'); ?></button>

    <h3 style="margin-top:25px;"><?php echo __('create_account'); ?></h3>
    <select id="tipo" onchange="cambiarTipo()">
        <option value="ssh"><?php echo __('ssh_normal'); ?></option>
        <option value="token"><?php echo __('token_user'); ?></option>
        <option value="hwid"><?php echo __('hwid_user'); ?></option>
    </select>

    <!-- BOTÓN DE CONTRASEÑA TOKEN GLOBAL (SOLO VISIBLE EN TOKEN) -->
    <button id="btn_token_pass" class="btn-tpass" onclick="openModal('tokenPassModal')">🔑 Contraseña Token (Actual: <?php echo htmlspecialchars($token_pass_actual); ?>)</button>

    <form method="POST">
        <div id="form_ssh"><input name="ssh_user" placeholder="<?php echo __('user'); ?>"><input name="ssh_pass" placeholder="<?php echo __('pass'); ?>"></div>
        <div id="form_token" style="display:none;"><input name="ref_token" placeholder="<?php echo __('ref_name'); ?>"><input name="token_user" placeholder="<?php echo __('token_user'); ?>"></div>
        <div id="form_hwid" style="display:none;"><input name="ref_hwid" placeholder="<?php echo __('ref_name'); ?>"><input name="hwid" placeholder="<?php echo __('hwid_user'); ?>"></div>
        <input type="hidden" name="tipo" id="tipo_input" value="ssh">
        <button name="crear_ssh"><?php echo __('create_account'); ?></button>
    </form>

    <div class="links">
        <a href="mis_usuarios.php" style="color:#6610f2;"><?php echo __('my_users'); ?></a>
        <a href="logout.php" style="color:#dc3545;"><?php echo __('logout'); ?></a>
    </div>
</div>

<!-- MODAL CONFIGURAR PASS TOKEN GLOBAL -->
<div class="modal" id="tokenPassModal">
    <div class="modal-box">
        <h3>🔑 Contraseña Token Global</h3>
        <form method="POST">
            <p style="font-size:13px; color:#666;">Define la contraseña por defecto para todas las cuentas de tipo Token que crees.</p>
            <label style="font-weight:600; font-size:14px;">Nueva Contraseña Token:</label>
            <input name="custom_token_pass" value="<?php echo htmlspecialchars($token_pass_actual); ?>" placeholder="dealer" required>
            
            <button name="guardar_token_pass" style="background:#198754; margin-top:15px;">Guardar Contraseña</button>
            <button type="button" style="background:#6c757d; margin-top:8px;" onclick="closeModal('tokenPassModal')">Cancelar</button>
        </form>
    </div>
</div>

<!-- MODAL ONLINE -->
<div class="modal" id="onlineModal">
    <div class="modal-box" style="text-align:center;">
        <h3>👥 <?php echo __('view_online'); ?></h3>
        <div id="onlineContent">...</div>
        <button type="button" style="background:#6c757d;margin-top:15px;" onclick="closeModal('onlineModal')"><?php echo __('close'); ?></button>
    </div>
</div>

<script>
function cambiarTipo(){
    let t = document.getElementById("tipo").value;
    document.getElementById("tipo_input").value = t;
    
    document.getElementById("form_ssh").style.display = "none";
    document.getElementById("form_token").style.display = "none";
    document.getElementById("form_hwid").style.display = "none";
    
    document.getElementById("form_" + t).style.display = "block";

    const btnTokenPass = document.getElementById("btn_token_pass");
    if (t === "token") {
        btnTokenPass.style.display = "block";
    } else {
        btnTokenPass.style.display = "none";
    }
}

function openModal(id){ document.getElementById(id).style.display = "flex"; }
function closeModal(id){ document.getElementById(id).style.display = "none"; }

function cargarOnline(){
    openModal('onlineModal');
    document.getElementById('onlineContent').innerHTML = "...";
    fetch('online.php')
        .then(res => res.text())
        .then(data => { document.getElementById('onlineContent').innerHTML = data; });
}

function copiarTexto(elementId, buttonId){
    let text = document.getElementById(elementId).innerText;
    navigator.clipboard.writeText(text).then(() => {
        let btn = document.getElementById(buttonId);
        btn.innerText = "¡Copiado!";
        setTimeout(() => { btn.innerText = "📋 Copiar Payload"; }, 2000);
    });
}
</script>

<?php if(isset($_GET['ok'])): ?>
<?php
    $ok_tipo = $_GET['tipo'] ?? 'ssh';
    $ok_ref  = $_GET['ref'] ?? '';
    $ok_u    = $_GET['u'] ?? '';
    $ok_p    = $_GET['p'] ?? '';
    $ok_e    = $_GET['e'] ?? '';
?>
<div class="modal" style="display:flex;">
    <div class="modal-box">
        <h3>Usuario Creado</h3>
        <div class="info-row"><b>IP VPS:</b> <code><?php echo htmlspecialchars($server_ip); ?></code></div>
        
        <?php if(!empty($cf_domain)): ?>
            <div class="info-row"><b>Dominio Cloudflare:</b> <code><?php echo htmlspecialchars($cf_domain); ?></code></div>
        <?php endif; ?>

        <?php if($ok_tipo == 'ssh'): ?>
            <div class="info-row"><b>Usuario:</b> <code><?php echo htmlspecialchars($ok_u); ?></code></div>
            <div class="info-row"><b>Contraseña:</b> <code><?php echo htmlspecialchars($ok_p); ?></code></div>
        <?php elseif($ok_tipo == 'token'): ?>
            <div class="info-row"><b>Nombre:</b> <code><?php echo htmlspecialchars($ok_ref); ?></code></div>
            <div class="info-row"><b>Token:</b> <code><?php echo htmlspecialchars($ok_u); ?></code></div>
            <div class="info-row"><b>Contraseña Token:</b> <code><?php echo htmlspecialchars($ok_p); ?></code></div>
        <?php elseif($ok_tipo == 'hwid'): ?>
            <div class="info-row"><b>Nombre:</b> <code><?php echo htmlspecialchars($ok_ref); ?></code></div>
            <div class="info-row"><b>HWID:</b> <code><?php echo htmlspecialchars($ok_u); ?></code></div>
        <?php endif; ?>

        <div class="info-row"><b>Expiración:</b> <?php echo htmlspecialchars($ok_e); ?></div>

        <!-- PAYLOAD GCP -->
        <?php if(!empty($payload_gcp)): ?>
            <hr style="margin:12px 0;border:0;border-top:1px solid #eee;">
            <div class="info-row"><b>Payload GCP:</b></div>
            <div class="payload-box" id="payload_gcp_text"><?php echo htmlspecialchars($payload_gcp); ?></div>
            <button id="btn_cp_gcp" class="btn-copy" onclick="copiarTexto('payload_gcp_text', 'btn_cp_gcp')">📋 Copiar Payload GCP</button>
        <?php endif; ?>

        <!-- PAYLOAD CLOUDFRONT -->
        <?php if(!empty($payload_cf)): ?>
            <hr style="margin:12px 0;border:0;border-top:1px solid #eee;">
            <div class="info-row"><b>Payload CloudFront:</b></div>
            <div class="payload-box" id="payload_cf_text"><?php echo htmlspecialchars($payload_cf); ?></div>
            <button id="btn_cp_cf" class="btn-copy" onclick="copiarTexto('payload_cf_text', 'btn_cp_cf')">📋 Copiar Payload CloudFront</button>
        <?php endif; ?>

        <button onclick="window.location.href='reseller.php'" style="background:#6c757d;margin-top:15px;">Cerrar</button>
    </div>
</div>
<?php endif; ?>
</body>
</html>
