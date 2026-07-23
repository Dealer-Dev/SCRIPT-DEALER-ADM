<?php
session_start();
include __DIR__ . "/db.php";

if (!isset($_SESSION['user']) || $_SESSION['role'] != 'reseller') {
    header("Location: login.php");
    exit();
}

$username = $_SESSION['user'];
$stmt = $conn->prepare("SELECT * FROM users WHERE username=?");
$stmt->bind_param("s", $username);
$stmt->execute();
$reseller = $stmt->get_result()->fetch_assoc();

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
        $ssh_pass = "dealer";
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
    
    // 1. Crear usuario SSH real en Linux
    $cmd_system = "sudo useradd -M -s /bin/false -e $expire_date $ssh_user && echo '$ssh_user:$ssh_pass' | sudo chpasswd && sudo chage -E $expire_date -M 99999 $ssh_user && sudo usermod -f 0 $ssh_user";
    exec($cmd_system);

    // 2. Crear archivo de registro en /etc/dealer-adm/userDIR/
    $file_content = "tipo: $tipo\nnombre: $ref\nusuario: $ssh_user\npassword: $ssh_pass\nfecha: $expire_date\nlimite: 1\ncreador_id: 0\ncreador_nombre: $username";
    
    $tmp_file = tempnam(sys_get_temp_dir(), 'usr_');
    file_put_contents($tmp_file, $file_content);
    exec("sudo mkdir -p /etc/dealer-adm/userDIR/ && sudo mv $tmp_file /etc/dealer-adm/userDIR/$ssh_user && sudo chmod 644 /etc/dealer-adm/userDIR/$ssh_user");

    // 3. Sincronizar con Hysteria si existe
    if(file_exists('/etc/hysteria/config.json')){
        $sync_hys = "python3 -c \"
import json, os
p = '/etc/hysteria/config.json'
if os.path.exists(p):
    with open(p) as f: c=json.load(f)
    cfg = c.get('auth',{}).get('config',[])
    entry = '$ssh_user:$ssh_pass'
    if entry not in cfg: cfg.append(entry); c['auth']['config']=cfg
    with open(p,'w') as f: json.dump(c,f,indent=2)
\" && sudo systemctl restart hysteria-server >/dev/null 2>&1";
        exec($sync_hys);
    }

    // 4. Actualizar Base de Datos Web
    $conn->query("UPDATE users SET credits = credits - 1 WHERE id='".$reseller['id']."'");
    $conn->query("INSERT INTO ssh_accounts (reseller, username, password, type, reference_name, expires) 
                  VALUES ('$username', '$ssh_user', '$ssh_pass', '$tipo', '$ref', '$expire_date')");

    header("Location: reseller.php?ok=1&tipo=$tipo&ref=".urlencode($ref)."&u=".urlencode($ssh_user)."&p=".urlencode($ssh_pass)."&e=$expire_date");
    exit();
}
?>
<!DOCTYPE html>
<html>
<head>
<title>Panel Revendedor</title>
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<style>
*{box-sizing:border-box;}
body{margin:0;font-family:'Segoe UI',sans-serif;background:#f4f6f9;}
.container{max-width:550px;margin:30px auto;background:#fff;padding:25px;border-radius:18px;box-shadow:0 8px 30px rgba(0,0,0,0.06);}
.credit-badge{background:#198754;color:#fff;padding:8px 15px;border-radius:20px;display:inline-block;margin-top:10px;font-weight:600;}
select,input{width:100%;padding:12px;margin-top:12px;border-radius:10px;border:1px solid #ddd;}
button{width:100%;margin-top:18px;padding:12px;border:none;border-radius:10px;background:linear-gradient(135deg,#0d6efd,#6610f2);color:#fff;font-weight:600;cursor:pointer;}
.btn-online{background:linear-gradient(135deg,#0dcaf0,#0d6efd);margin-top:12px;}
.links{margin-top:20px;display:flex;justify-content:space-between;}
.links a{text-decoration:none;font-weight:600;}
.modal{position:fixed;top:0;left:0;width:100%;height:100%;background:rgba(0,0,0,0.5);display:none;align-items:center;justify-content:center;z-index:999;}
.modal-box{background:#fff;padding:25px;border-radius:16px;width:320px;text-align:center;max-height:80vh;overflow-y:auto;}
</style>
</head>
<body>
<div class="container">
    <h2>Revendedor: <?php echo htmlspecialchars($username); ?></h2>
    <div class="credit-badge">💰 Créditos disponibles: <?php echo $reseller['credits']; ?></div>

    <button class="btn-online" onclick="cargarOnline()">📡 Ver Conectados</button>

    <h3 style="margin-top:25px;">Crear Cuenta</h3>
    <select id="tipo" onchange="cambiarTipo()">
        <option value="ssh">SSH Normal</option>
        <option value="token">Token</option>
        <option value="hwid">HWID</option>
    </select>

    <form method="POST">
        <div id="form_ssh"><input name="ssh_user" placeholder="Usuario"><input name="ssh_pass" placeholder="Contraseña"></div>
        <div id="form_token" style="display:none;"><input name="ref_token" placeholder="Nombre Referencia"><input name="token_user" placeholder="Token"></div>
        <div id="form_hwid" style="display:none;"><input name="ref_hwid" placeholder="Nombre Referencia"><input name="hwid" placeholder="HWID"></div>
        <input type="hidden" name="tipo" id="tipo_input" value="ssh">
        <button name="crear_ssh">Crear Usuario</button>
    </form>

    <div class="links">
        <a href="mis_usuarios.php" style="color:#6610f2;">Mis usuarios creados</a>
        <a href="logout.php" style="color:#dc3545;">Cerrar sesión</a>
    </div>
</div>

<!-- MODAL ONLINE -->
<div class="modal" id="onlineModal">
    <div class="modal-box">
        <h3>👥 Conectados</h3>
        <div id="onlineContent">Cargando...</div>
        <button type="button" style="background:#6c757d;margin-top:15px;" onclick="closeModal('onlineModal')">Cerrar</button>
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
}

function openModal(id){ document.getElementById(id).style.display = "flex"; }
function closeModal(id){ document.getElementById(id).style.display = "none"; }

function cargarOnline(){
    openModal('onlineModal');
    document.getElementById('onlineContent').innerHTML = "Cargando...";
    fetch('online.php')
        .then(res => res.text())
        .then(data => { document.getElementById('onlineContent').innerHTML = data; });
}
</script>

<?php if(isset($_GET['ok'])): ?>
<div class="modal" style="display:flex;">
    <div class="modal-box">
        <h3>✅ Usuario Creado</h3>
        <p><b>Usuario/Ref:</b> <?php echo htmlspecialchars($_GET['u']); ?></p>
        <p><b>Pass/Valor:</b> <?php echo htmlspecialchars($_GET['p']); ?></p>
        <p><b>Expira:</b> <?php echo htmlspecialchars($_GET['e']); ?></p>
        <button onclick="window.location.href='reseller.php'">OK</button>
    </div>
</div>
<?php endif; ?>
</body>
</html>
