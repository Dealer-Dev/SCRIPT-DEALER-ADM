<?php
ini_set('display_errors', 1);
error_reporting(E_ALL);
session_start();
include __DIR__ . "/db.php";
include __DIR__ . "/lang.php";

if(!isset($_SESSION['user']) || $_SESSION['role'] != 'admin'){
    header("Location: login.php");
    exit();
}

$admin_user = $_SESSION['user'];

// Archivo de contraseña Token personalizada del Admin
$admin_token_pass_file = "/etc/dealer-adm/resellers/token_pass_" . $admin_user . ".txt";

// GUARDAR CONTRASEÑA TOKEN GLOBAL DEL ADMIN
if(isset($_POST['guardar_token_pass_admin'])){
    $new_t_pass = trim($_POST['custom_token_pass']);
    if (!file_exists('/etc/dealer-adm/resellers')) {
        exec("sudo mkdir -p /etc/dealer-adm/resellers && sudo chmod 777 /etc/dealer-adm/resellers");
    }
    if(!empty($new_t_pass)){
        file_put_contents($admin_token_pass_file, $new_t_pass);
    } else {
        file_put_contents($admin_token_pass_file, "dealer");
    }
    header("Location: admin.php?token_pass_ok=1");
    exit();
}

// Obtener la contraseña token actual del Admin (por defecto 'dealer')
$token_pass_admin_actual = file_exists($admin_token_pass_file) ? trim(file_get_contents($admin_token_pass_file)) : "dealer";
if(empty($token_pass_admin_actual)) { $token_pass_admin_actual = "dealer"; }

// Función auxiliar para leer el límite desde el archivo en /etc/dealer-adm/userDIR/
function obtenerLimiteUsuario($usuario) {
    $file_path = "/etc/dealer-adm/userDIR/" . $usuario;
    if (file_exists($file_path)) {
        $content = file_get_contents($file_path);
        if (preg_match('/limite:\s*(\d+)/i', $content, $matches)) {
            return $matches[1];
        }
    }
    return "1";
}

// Función auxiliar para obtener permisos de payload de un reseller
function obtenerPermisosReseller($reseller_username) {
    $file_path = "/etc/dealer-adm/resellers/" . $reseller_username . ".json";
    if (file_exists($file_path)) {
        return json_decode(file_get_contents($file_path), true);
    }
    return ['show_gcp' => 1, 'show_cf' => 1];
}

// Función auxiliar para guardar permisos de payload de un reseller
function guardarPermisosReseller($reseller_username, $show_gcp, $show_cf) {
    if (!file_exists('/etc/dealer-adm/resellers')) {
        exec("sudo mkdir -p /etc/dealer-adm/resellers && sudo chmod 777 /etc/dealer-adm/resellers");
    }
    $file_path = "/etc/dealer-adm/resellers/" . $reseller_username . ".json";
    $data = ['show_gcp' => $show_gcp, 'show_cf' => $show_cf];
    file_put_contents($file_path, json_encode($data));
}

$total_resellers = $conn->query("SELECT COUNT(*) total FROM users WHERE role='reseller'")->fetch_assoc()['total'];
$total_accounts  = $conn->query("SELECT COUNT(*) total FROM ssh_accounts")->fetch_assoc()['total'];
$total_credits   = $conn->query("SELECT SUM(credits) total FROM users WHERE role='reseller'")->fetch_assoc()['total'] ?? 0;

// GUARDAR TEXTO GLOBAL DE LOS PAYLOADS (ADMIN)
if(isset($_POST['guardar_payloads_text'])){
    $gcp_text = $_POST['payload_gcp'] ?? '';
    $cf_text  = $_POST['payload_cf'] ?? '';

    if (!file_exists('/etc/dealer-adm')) {
        exec("sudo mkdir -p /etc/dealer-adm && sudo chmod 777 /etc/dealer-adm");
    }

    file_put_contents('/etc/dealer-adm/payload_gcp.txt', $gcp_text);
    file_put_contents('/etc/dealer-adm/payload_cloudfront.txt', $cf_text);

    header("Location: admin.php?payload_ok=1");
    exit();
}

$payload_gcp = file_exists('/etc/dealer-adm/payload_gcp.txt') ? file_get_contents('/etc/dealer-adm/payload_gcp.txt') : '';
$payload_cf  = file_exists('/etc/dealer-adm/payload_cloudfront.txt') ? file_get_contents('/etc/dealer-adm/payload_cloudfront.txt') : '';

// GUARDAR CRÉDITOS A RESELLER
if(isset($_POST['guardar_creditos'])){
    $reseller_id = intval($_POST['reseller_id']);
    $sumar  = isset($_POST['credits_sumar']) && $_POST['credits_sumar'] !== '' ? intval($_POST['credits_sumar']) : 0;
    $restar = isset($_POST['credits_restar']) && $_POST['credits_restar'] !== '' ? intval($_POST['credits_restar']) : 0;

    if($sumar > 0){
        $conn->query("UPDATE users SET credits = credits + $sumar WHERE id='$reseller_id'");
    }
    if($restar > 0){
        $conn->query("UPDATE users SET credits = GREATEST(credits - $restar, 0) WHERE id='$reseller_id'");
    }

    $stmt_info = $conn->prepare("SELECT username, credits FROM users WHERE id=?");
    $stmt_info->bind_param("i", $reseller_id);
    $stmt_info->execute();
    $res_info = $stmt_info->get_result()->fetch_assoc();

    if($res_info){
        $u_name = urlencode($res_info['username']);
        $new_cred = $res_info['credits'];
        header("Location: admin.php?credits_updated=1&u=$u_name&c=$new_cred");
    } else {
        header("Location: admin.php");
    }
    exit();
}

// CREAR RESELLER CON SWITCHES DE PAYLOAD
if(isset($_POST['crear_reseller'])){
    $user = trim($_POST['username']);
    $pass = trim($_POST['password']);
    $cred = intval($_POST['credits']);
    $show_gcp = isset($_POST['show_gcp']) ? 1 : 0;
    $show_cf  = isset($_POST['show_cf']) ? 1 : 0;

    $exist = $conn->query("SELECT id FROM users WHERE username='$user'");
    if($exist->num_rows > 0){
        $error = "El revendedor ya existe";
    } else {
        $conn->query("INSERT INTO users (username, password, credits, role) VALUES ('$user', '$pass', '$cred', 'reseller')");
        guardarPermisosReseller($user, $show_gcp, $show_cf);
        header("Location: admin.php");
        exit();
    }
}

// EDITAR SWITCHES DE PAYLOAD DE RESELLER EXISTENTE
if(isset($_POST['editar_permisos_reseller'])){
    $reseller_user = trim($_POST['reseller_user']);
    $show_gcp = isset($_POST['edit_show_gcp']) ? 1 : 0;
    $show_cf  = isset($_POST['edit_show_cf']) ? 1 : 0;

    guardarPermisosReseller($reseller_user, $show_gcp, $show_cf);
    header("Location: admin.php");
    exit();
}

// CREAR CUENTA (SSH NORMAL / TOKEN / HWID)
if(isset($_POST['crear_cuenta'])){
    $tipo = $_POST['account_type'];
    $user = trim($_POST['username']);
    $ref_name = isset($_POST['ref_name']) ? trim($_POST['ref_name']) : '';
    $pass = isset($_POST['password']) ? trim($_POST['password']) : '';
    $dias = intval($_POST['exp_days']);
    
    if($tipo === 'token'){
        $limite = 1;
        $ref = $ref_name;
        $pass = $token_pass_admin_actual;
    } elseif($tipo === 'hwid'){
        $limite = 1;
        $ref = $ref_name;
        $pass = $user;
    } else {
        $limite = intval($_POST['ssh_limit']);
        $ref = $user;
    }
    
    $owner = $admin_user;

    $exist = $conn->query("SELECT id FROM ssh_accounts WHERE username='$user'");
    if($exist->num_rows > 0){
        $error = "La cuenta o identificador ya existe";
    } else {
        $expira_date = date('Y-m-d', strtotime("+$dias days"));

        // CREAR USUARIO REAL EN LINUX PARA TODOS LOS TIPOS (SSH, TOKEN, HWID)
        $cmd = "sudo useradd -M -s /bin/false -e $expira_date $user && echo '$user:$pass' | sudo chpasswd && sudo chage -E $expira_date -M 99999 -m 0 -I -1 -W 7 $user && sudo usermod -f 0 $user";
        exec($cmd);

        $file_content = "tipo: $tipo\nnombre: $ref\nusuario: $user\npassword: $pass\nfecha: $expira_date\nlimite: $limite\ncreador_id: 0\ncreador_nombre: $owner";
        $tmp_file = tempnam(sys_get_temp_dir(), 'usr_');
        file_put_contents($tmp_file, $file_content);
        exec("sudo mkdir -p /etc/dealer-adm/userDIR/ && sudo mv $tmp_file /etc/dealer-adm/userDIR/$user && sudo chmod 644 /etc/dealer-adm/userDIR/$user");

        // Sincronización robusta con Hysteria UDP
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
        entry = '$user:$pass'
        if entry not in cfg:
            cfg.append(entry)
            c['auth']['config'] = cfg
            with open(p, 'w') as f: json.dump(c, f, indent=2)
    except Exception:
        pass
\" && sudo systemctl restart hysteria-server >/dev/null 2>&1";
            exec($sync_hys);
        }

        $stmt = $conn->prepare("INSERT INTO ssh_accounts (username, password, expires, reseller, type, reference_name) VALUES (?, ?, ?, ?, ?, ?)");
        $stmt->bind_param("ssssss", $user, $pass, $expira_date, $owner, $tipo, $ref);
        $stmt->execute();

        header("Location: admin.php?ok=1&tipo=$tipo&ref=".urlencode($ref)."&u=".urlencode($user)."&p=".urlencode($pass)."&e=$expira_date&l=$limite");
        exit();
    }
}

// ELIMINAR RESELLER
if(isset($_POST['delete_user'])){
    $id = intval($_POST['delete_user']);
    $stmt_del = $conn->prepare("SELECT username FROM users WHERE id=?");
    $stmt_del->bind_param("i", $id);
    $stmt_del->execute();
    $u_data = $stmt_del->get_result()->fetch_assoc();
    if($u_data) {
        @unlink("/etc/dealer-adm/resellers/" . $u_data['username'] . ".json");
    }
    $conn->query("DELETE FROM users WHERE id='$id'");
    header("Location: admin.php");
    exit();
}

// ELIMINAR CUENTA SSH / TOKEN / HWID
if(isset($_POST['delete_account'])){
    $acc_id = intval($_POST['delete_account']);
    $stmt_acc = $conn->prepare("SELECT username FROM ssh_accounts WHERE id=?");
    $stmt_acc->bind_param("i", $acc_id);
    $stmt_acc->execute();
    $acc_data = $stmt_acc->get_result()->fetch_assoc();

    if($acc_data){
        $user_to_del = $acc_data['username'];
        exec("sudo pkill -u $user_to_del 2>/dev/null; sudo userdel -f $user_to_del 2>/dev/null");
        exec("sudo rm -f /etc/dealer-adm/userDIR/$user_to_del");

        if(file_exists('/etc/hysteria/config.json')){
            $del_hys = "python3 -c \"
import json, os
p = '/etc/hysteria/config.json'
if os.path.exists(p):
    with open(p) as f: c=json.load(f)
    cfg = c.get('auth',{}).get('config',[])
    if isinstance(cfg, list):
        cfg = [u for u in cfg if not u.startswith('$user_to_del:')]
        c['auth']['config'] = cfg
        with open(p,'w') as f: json.dump(c,f,indent=2)
\" && sudo systemctl restart hysteria-server >/dev/null 2>&1";
            exec($del_hys);
        }

        $conn->query("DELETE FROM ssh_accounts WHERE id='$acc_id'");
    }
    
    $tab_redirect = isset($_GET['tab']) ? "?tab=" . urlencode($_GET['tab']) : "";
    $reseller_redirect = isset($_GET['reseller_filter']) ? "&reseller_filter=" . urlencode($_GET['reseller_filter']) : "";
    header("Location: admin.php" . $tab_redirect . $reseller_redirect);
    exit();
}

// Cargar IP VPS y Dominio Cloudflare
$server_ip = $_SERVER['SERVER_ADDR'] ?? exec("curl -s -4 ifconfig.me") ?? "127.0.0.1";
$cf_domain = file_exists('/etc/dealer-adm/cf_domain') ? trim(file_get_contents('/etc/dealer-adm/cf_domain')) : '';

// LISTA DE REVENDEDORES PARA EL MENÚ
$resellers_arr = [];
$resellers_query = $conn->query("SELECT * FROM users WHERE role='reseller' ORDER BY username ASC");
while($r_row = $resellers_query->fetch_assoc()){
    $resellers_arr[] = $r_row;
}

// LÓGICA DE FILTRADO
$tab = $_GET['tab'] ?? 'my_accounts';
$selected_reseller = $_GET['reseller_filter'] ?? '';

if($tab === 'all_accounts'){
    $sql_accounts = "SELECT * FROM ssh_accounts ORDER BY id DESC";
    $stmt_accounts = $conn->prepare($sql_accounts);
} elseif($tab === 'reseller_accounts' && !empty($selected_reseller)) {
    $sql_accounts = "SELECT * FROM ssh_accounts WHERE reseller=? ORDER BY id DESC";
    $stmt_accounts = $conn->prepare($sql_accounts);
    $stmt_accounts->bind_param("s", $selected_reseller);
} else {
    $tab = 'my_accounts';
    $sql_accounts = "SELECT * FROM ssh_accounts WHERE reseller=? ORDER BY id DESC";
    $stmt_accounts = $conn->prepare($sql_accounts);
    $stmt_accounts->bind_param("s", $admin_user);
}

$stmt_accounts->execute();
$accounts_result = $stmt_accounts->get_result();
$today = date('Y-m-d');

$resellers = $conn->query("SELECT * FROM users WHERE role='reseller' ORDER BY id DESC");
?>
<!DOCTYPE html>
<html>
<head>
<title>Admin - Panel Local VPS</title>
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<style>
*{box-sizing:border-box;}
body{margin:0;font-family:'Segoe UI',sans-serif;background:#f4f7fb;}
.header{background:linear-gradient(135deg,#0d6efd,#6610f2);color:#fff;padding:20px;display:flex;justify-content:space-between;align-items:center;}
.logout{background:#fff;color:#111;padding:8px 14px;border-radius:10px;text-decoration:none;font-weight:600;}
.container{padding:25px;max-width:1100px;margin:auto;}
.stats{display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:20px;}
.stat-card{background:#fff;padding:20px;border-radius:16px;box-shadow:0 4px 20px rgba(0,0,0,0.05);}
.stat-card h3{margin:0;font-size:15px;color:#666;}
.stat-card h1{margin:10px 0 0;font-size:32px;color:#111;}
.actions{margin-top:25px;display:flex;gap:15px;flex-wrap:wrap;}
.action-btn{border:none;padding:15px 22px;border-radius:12px;color:#fff;font-size:15px;font-weight:600;cursor:pointer;}
.btn-reseller{background:linear-gradient(135deg,#6610f2,#d63384);}
.btn-create{background:linear-gradient(135deg,#0284c7,#0369a1);}
.btn-payload{background:linear-gradient(135deg,#eab308,#ca8a04);}
.btn-online{background:linear-gradient(135deg,#0dcaf0,#0d6efd);}
.btn-tpass{background:linear-gradient(135deg,#eab308,#ca8a04); margin-top:10px; display:none;}
.table-card{background:#fff;margin-top:25px;padding:20px;border-radius:16px;box-shadow:0 4px 20px rgba(0,0,0,0.05);}
table{width:100%;border-collapse:collapse;margin-top:15px;}
th{background:#0f172a;color:#fff;padding:12px;text-align:center;font-size:14px;}
td{padding:12px;text-align:center;border-bottom:1px solid #eee;font-size:14px;}
.badge{background:#0d6efd;color:#fff;padding:5px 10px;border-radius:15px;font-size:12px;}
.badge-type{background:#6c757d;color:#fff;padding:3px 8px;border-radius:8px;font-size:11px;text-transform:uppercase;}
.exp-badge{background:#dc3545;color:#fff;padding:4px 10px;border-radius:6px;font-weight:800;font-size:12px;}
.btn-small{border:none;padding:6px 12px;border-radius:8px;color:#fff;cursor:pointer;}
.btn-delete{background:#dc3545;}
.btn-credit-act{background:#22c55e;margin-right:5px;}
.btn-edit-perm{background:#17a2b8;margin-right:5px;}

.tabs-container{display:flex;gap:10px;margin-top:15px;flex-wrap:wrap;align-items:center;border-bottom:2px solid #e2e8f0;padding-bottom:12px;}
.tab-link{padding:10px 18px;border-radius:10px;background:#e2e8f0;color:#334155;text-decoration:none;font-weight:600;font-size:14px;transition:0.2s;}
.tab-link:hover{background:#cbd5e1;}
.tab-link.active{background:#0d6efd;color:#fff;}

.tab-select{padding:9px 16px;border-radius:10px;background:#e2e8f0;color:#334155;font-weight:600;font-size:14px;border:none;outline:none;cursor:pointer;margin:0;width:auto;}
.tab-select.active{background:#0d6efd;color:#fff;}

.modal{position:fixed;top:0;left:0;width:100%;height:100%;background:rgba(0,0,0,0.5);display:none;justify-content:center;align-items:center;z-index:999;}
.modal-box{background:#fff;width:90%;max-width:500px;padding:25px;border-radius:16px;max-height:80vh;overflow-y:auto;}
input,select,textarea{width:100%;padding:12px;margin-top:10px;border-radius:8px;border:1px solid #ddd;}
label{font-weight:600;display:block;margin-top:12px;font-size:14px;color:#333;}
.modal-btn{width:100%;margin-top:15px;padding:12px;border:none;border-radius:8px;color:#fff;font-weight:600;cursor:pointer;background:#0d6efd;}
.close-btn{background:#6b7280;}
.alert-error{background:#f8d7da;color:#721c24;padding:12px;border-radius:8px;margin-bottom:15px;}
.switch-box{display:flex;align-items:center;gap:10px;margin-top:10px;background:#f8fafc;padding:10px;border-radius:8px;border:1px solid #e2e8f0;}
.info-row{margin-bottom:8px;font-size:14px;text-align:left;}
.info-row b{color:#333;}
</style>
</head>
<body>
<div class="header">
    <h2><?php echo __('admin_panel_title'); ?></h2>
    <div>Admin: <b><?php echo htmlspecialchars($admin_user); ?></b> <a href="logout.php" class="logout"><?php echo __('logout'); ?></a></div>
</div>

<div class="container">
    <?php if(isset($error)){ echo "<div class='alert-error'>$error</div>"; } ?>

    <div class="stats">
        <div class="stat-card"><h3><?php echo __('resellers'); ?></h3><h1><?php echo $total_resellers; ?></h1></div>
        <div class="stat-card"><h3><?php echo __('created_accts'); ?></h3><h1><?php echo $total_accounts; ?></h1></div>
        <div class="stat-card"><h3><?php echo __('credits_shared'); ?></h3><h1><?php echo $total_credits; ?></h1></div>
    </div>

    <div class="actions">
        <button class="action-btn btn-reseller" onclick="openModal('resellerModal')"><?php echo __('create_reseller'); ?></button>
        <button class="action-btn btn-create" onclick="openModal('createAccountModal')">➕ Crear Cuenta</button>
        <button class="action-btn btn-payload" onclick="openModal('payloadsTextModal')">📝 Editar Textos Payloads</button>
        <button class="action-btn btn-online" onclick="cargarOnline()"><?php echo __('view_online'); ?></button>
    </div>

    <!-- PESTAÑAS CUENTAS -->
    <div class="table-card">
        <h3>📋 Gestión de Cuentas</h3>
        
        <div class="tabs-container">
            <a href="admin.php?tab=my_accounts" class="tab-link <?php echo ($tab === 'my_accounts') ? 'active' : ''; ?>">👤 Mis Cuentas</a>
            <a href="admin.php?tab=all_accounts" class="tab-link <?php echo ($tab === 'all_accounts') ? 'active' : ''; ?>">🌐 Todas las Cuentas</a>

            <select class="tab-select <?php echo ($tab === 'reseller_accounts') ? 'active' : ''; ?>" onchange="if(this.value) location = this.value;">
                <option value="" disabled <?php echo ($tab !== 'reseller_accounts') ? 'selected' : ''; ?>>🏪 Ver Revendedor... ▾</option>
                <?php foreach($resellers_arr as $r_opt): 
                    $is_sel = ($tab === 'reseller_accounts' && $selected_reseller === $r_opt['username']) ? 'selected' : '';
                ?>
                    <option value="admin.php?tab=reseller_accounts&reseller_filter=<?php echo urlencode($r_opt['username']); ?>" <?php echo $is_sel; ?>>
                        👤 <?php echo htmlspecialchars($r_opt['username']); ?>
                    </option>
                <?php endforeach; ?>
            </select>
        </div>

        <table>
            <thead>
                <tr>
                    <th>Tipo</th>
                    <th>Nombre</th>
                    <th>Contraseña/Token/HWID</th>
                    <th>Creador</th>
                    <th>Límite</th>
                    <th>Expiración</th>
                    <th>Acción</th>
                </tr>
            </thead>
            <tbody>
                <?php if($accounts_result->num_rows == 0): ?>
                    <tr><td colspan="7" style="padding:25px; color:#64748b;">No se encontraron cuentas.</td></tr>
                <?php else: ?>
                    <?php while($acc = $accounts_result->fetch_assoc()): ?>
                    <?php 
                        $is_exp = ($acc['expires'] <= $today);
                        $limite_cnt = obtenerLimiteUsuario($acc['username']);
                        $acc_type = strtolower($acc['type']);

                        if ($acc_type === 'token' || $acc_type === 'hwid') {
                            $col_nombre = !empty($acc['reference_name']) ? $acc['reference_name'] : $acc['username'];
                            $col_valor  = $acc['username'];
                        } else {
                            $col_nombre = $acc['username'];
                            $col_valor  = $acc['password'];
                        }
                    ?>
                    <tr>
                        <td><span class="badge-type"><?php echo htmlspecialchars($acc['type']); ?></span></td>
                        <td><b><?php echo htmlspecialchars($col_nombre); ?></b></td>
                        <td><code><?php echo htmlspecialchars($col_valor); ?></code></td>
                        <td><span class="badge"><?php echo htmlspecialchars($acc['reseller']); ?></span></td>
                        <td><b><?php echo htmlspecialchars($limite_cnt); ?></b></td>
                        <td>
                            <?php if($is_exp): ?>
                                <span class="exp-badge">EXP</span>
                            <?php else: ?>
                                <?php echo htmlspecialchars($acc['expires']); ?>
                            <?php endif; ?>
                        </td>
                        <td>
                            <form method="POST" style="display:inline;" onsubmit="return confirm('¿Seguro que deseas eliminar esta cuenta?');">
                                <input type="hidden" name="delete_account" value="<?php echo $acc['id']; ?>">
                                <button type="submit" class="btn-small btn-delete">Eliminar</button>
                            </form>
                        </td>
                    </tr>
                    <?php endwhile; ?>
                <?php endif; ?>
            </tbody>
        </table>
    </div>

    <!-- LISTA DE RESELLERS -->
    <div class="table-card">
        <h3><?php echo __('reseller_list'); ?></h3>
        <table>
            <tr>
                <th>ID</th>
                <th><?php echo __('user'); ?></th>
                <th><?php echo __('pass'); ?></th>
                <th>Créditos</th>
                <th>Permisos Payloads</th>
                <th><?php echo __('action'); ?></th>
            </tr>
            <?php while($r = $resellers->fetch_assoc()){ 
                $perm = obtenerPermisosReseller($r['username']);
            ?>
            <tr>
                <td><?php echo $r['id']; ?></td>
                <td><b><?php echo htmlspecialchars($r['username']); ?></b></td>
                <td><code><?php echo htmlspecialchars($r['password']); ?></code></td>
                <td><span class="badge"><?php echo $r['credits']; ?></span></td>
                <td>
                    <small>
                        GCP: <b><?php echo $perm['show_gcp'] ? '✅ SI' : '❌ NO'; ?></b> | 
                        CF: <b><?php echo $perm['show_cf'] ? '✅ SI' : '❌ NO'; ?></b>
                    </small>
                </td>
                <td>
                    <button class="btn-small btn-credit-act" onclick="abrirGestionCreditos(<?php echo $r['id']; ?>, '<?php echo htmlspecialchars($r['username'], ENT_QUOTES); ?>', <?php echo $r['credits']; ?>)">💳 Créditos</button>
                    <button class="btn-small btn-edit-perm" onclick="abrirEditarPermisos('<?php echo htmlspecialchars($r['username'], ENT_QUOTES); ?>', <?php echo $perm['show_gcp']; ?>, <?php echo $perm['show_cf']; ?>)">⚙️ Permisos</button>
                    <button class="btn-small btn-delete" onclick="confirmDeleteUser(<?php echo $r['id']; ?>)"><?php echo __('delete'); ?></button>
                </td>
            </tr>
            <?php } ?>
        </table>
    </div>
</div>

<!-- MODAL USUARIO CREADO -->
<?php if(isset($_GET['ok'])): ?>
<?php
    $ok_tipo = $_GET['tipo'] ?? 'ssh';
    $ok_ref  = $_GET['ref'] ?? '';
    $ok_u    = $_GET['u'] ?? '';
    $ok_p    = $_GET['p'] ?? '';
    $ok_e    = $_GET['e'] ?? '';
    $ok_l    = $_GET['l'] ?? '1';
?>
<div class="modal" style="display:flex;">
    <div class="modal-box" style="text-align:center;">
        <h3>Usuario Creado</h3>
        <div class="info-row"><b>IP VPS:</b> <code><?php echo htmlspecialchars($server_ip); ?></code></div>
        
        <?php if(!empty($cf_domain)): ?>
            <div class="info-row"><b>Dominio Cloudflare:</b> <code><?php echo htmlspecialchars($cf_domain); ?></code></div>
        <?php endif; ?>

        <?php if($ok_tipo == 'ssh'): ?>
            <div class="info-row"><b>Usuario:</b> <code><?php echo htmlspecialchars($ok_u); ?></code></div>
            <div class="info-row"><b>Contraseña:</b> <code><?php echo htmlspecialchars($ok_p); ?></code></div>
            <div class="info-row"><b>Límite de Conexiones:</b> <code><?php echo htmlspecialchars($ok_l); ?></code></div>
        <?php elseif($ok_tipo == 'token'): ?>
            <div class="info-row"><b>Nombre:</b> <code><?php echo htmlspecialchars($ok_ref); ?></code></div>
            <div class="info-row"><b>Token:</b> <code><?php echo htmlspecialchars($ok_u); ?></code></div>
            <div class="info-row"><b>Contraseña Token:</b> <code><?php echo htmlspecialchars($ok_p); ?></code></div>
        <?php elseif($ok_tipo == 'hwid'): ?>
            <div class="info-row"><b>Nombre:</b> <code><?php echo htmlspecialchars($ok_ref); ?></code></div>
            <div class="info-row"><b>HWID:</b> <code><?php echo htmlspecialchars($ok_u); ?></code></div>
        <?php endif; ?>

        <div class="info-row"><b>Expiración:</b> <?php echo htmlspecialchars($ok_e); ?></div>

        <button onclick="window.location.href='admin.php'" class="modal-btn" style="background:#6c757d; margin-top:15px;">Cerrar</button>
    </div>
</div>
<?php endif; ?>

<!-- MODAL CONFIRMACIÓN DE CRÉDITOS ACTUALIZADOS -->
<?php if(isset($_GET['credits_updated'])): ?>
<?php
    $cred_user = $_GET['u'] ?? '';
    $cred_total = $_GET['c'] ?? '0';
?>
<div class="modal" id="creditsResultModal" style="display:flex;">
    <div class="modal-box" style="text-align:center;">
        <h3 style="color:#16a34a; margin-top:0;">✅ Créditos Actualizados</h3>
        <p style="font-size:15px; margin-top:10px;">
            Revendedor: <b style="color:#0d6efd;"><?php echo htmlspecialchars($cred_user); ?></b>
        </p>
        <div style="margin:20px 0; background:#f8fafc; padding:15px; border-radius:12px; border:1px solid #e2e8f0;">
            <span style="font-size:14px; color:#64748b; font-weight:600;">NUEVO TOTAL DE CRÉDITOS:</span><br>
            <span style="font-size:32px; font-weight:800; color:#16a34a; display:inline-block; margin-top:5px;">
                <?php echo htmlspecialchars($cred_total); ?>
            </span>
        </div>
        <button onclick="window.location.href='admin.php'" class="modal-btn" style="background:#0d6efd;">Aceptar</button>
    </div>
</div>
<?php endif; ?>

<!-- MODAL GESTIÓN DE CRÉDITOS INDIVIDUAL -->
<div class="modal" id="assignModal">
    <div class="modal-box">
        <h3>💳 Gestionar Créditos</h3>
        <form method="POST">
            <input type="hidden" name="reseller_id" id="credit_reseller_id">
            
            <p style="margin-top:5px; margin-bottom:15px; font-size:15px;">
                Revendedor: <b id="credit_reseller_name" style="color:#0d6efd;"></b><br>
                Créditos actuales: <span class="badge" id="credit_reseller_current" style="background:#16a34a;">0</span>
            </p>

            <label>Sumar Créditos (+):</label>
            <input type="number" name="credits_sumar" placeholder="Cantidad a agregar" min="0" value="0">

            <label>Restar Créditos (-):</label>
            <input type="number" name="credits_restar" placeholder="Cantidad a descontar" min="0" value="0">

            <button name="guardar_creditos" class="modal-btn" style="margin-top:20px;">Guardar Créditos</button>
            <button type="button" class="modal-btn close-btn" onclick="closeModal('assignModal')"><?php echo __('cancel'); ?></button>
        </form>
    </div>
</div>

<!-- MODAL CREAR RESELLER CON SWITCHES -->
<div class="modal" id="resellerModal">
    <div class="modal-box">
        <h3><?php echo __('create_reseller'); ?></h3>
        <form method="POST">
            <input name="username" placeholder="<?php echo __('user'); ?>" required>
            <input name="password" placeholder="<?php echo __('pass'); ?>" required>
            <input type="number" name="credits" placeholder="<?php echo __('initial_credits'); ?>" value="0" required>
            
            <label>Permisos de Payloads para este Revendedor:</label>
            <div class="switch-box">
                <input type="checkbox" name="show_gcp" id="create_show_gcp" value="1" checked style="width:auto; margin:0; cursor:pointer;">
                <label for="create_show_gcp" style="margin:0; cursor:pointer;">Permitir Payload GCP</label>
            </div>
            <div class="switch-box">
                <input type="checkbox" name="show_cf" id="create_show_cf" value="1" checked style="width:auto; margin:0; cursor:pointer;">
                <label for="create_show_cf" style="margin:0; cursor:pointer;">Permitir Payload CloudFront</label>
            </div>

            <button name="crear_reseller" class="modal-btn"><?php echo __('create_account'); ?></button>
            <button type="button" class="modal-btn close-btn" onclick="closeModal('resellerModal')"><?php echo __('cancel'); ?></button>
        </form>
    </div>
</div>

<!-- MODAL EDITAR PERMISOS PAYLOAD DE RESELLER EXISTENTE -->
<div class="modal" id="editPermisosModal">
    <div class="modal-box">
        <h3>⚙️ Editar Permisos de Payload</h3>
        <form method="POST">
            <input type="hidden" name="reseller_user" id="edit_reseller_user">
            <p>Revendedor: <b id="lbl_edit_reseller_user" style="color:#0d6efd;"></b></p>
            
            <div class="switch-box">
                <input type="checkbox" name="edit_show_gcp" id="edit_show_gcp" value="1" style="width:auto; margin:0; cursor:pointer;">
                <label for="edit_show_gcp" style="margin:0; cursor:pointer;">Mostrar Payload GCP</label>
            </div>
            <div class="switch-box">
                <input type="checkbox" name="edit_show_cf" id="edit_show_cf" value="1" style="width:auto; margin:0; cursor:pointer;">
                <label for="edit_show_cf" style="margin:0; cursor:pointer;">Mostrar Payload CloudFront</label>
            </div>

            <button name="editar_permisos_reseller" class="modal-btn">Guardar Permisos</button>
            <button type="button" class="modal-btn close-btn" onclick="closeModal('editPermisosModal')"><?php echo __('cancel'); ?></button>
        </form>
    </div>
</div>

<!-- MODAL EDITAR TEXTOS DE PAYLOADS -->
<div class="modal" id="payloadsTextModal">
    <div class="modal-box">
        <h3>📝 Contenido Global de Payloads</h3>
        <form method="POST">
            <label>Payload GCP:</label>
            <textarea name="payload_gcp" rows="3" placeholder="Texto Payload GCP..."><?php echo htmlspecialchars($payload_gcp); ?></textarea>

            <label>Payload CloudFront:</label>
            <textarea name="payload_cf" rows="3" placeholder="Texto Payload CloudFront..."><?php echo htmlspecialchars($payload_cf); ?></textarea>

            <button name="guardar_payloads_text" class="modal-btn" style="margin-top:15px;">Guardar Textos</button>
            <button type="button" class="modal-btn close-btn" onclick="closeModal('payloadsTextModal')"><?php echo __('cancel'); ?></button>
        </form>
    </div>
</div>

<!-- MODAL CREAR CUENTA (ADMIN) -->
<div class="modal" id="createAccountModal">
    <div class="modal-box">
        <h3>➕ Crear Cuenta</h3>
        <form method="POST">
            <label>Tipo de usuario:</label>
            <select name="account_type" id="account_type_select" onchange="actualizarCamposTipoAdmin(this.value)" required>
                <option value="ssh">Usuario SSH Normal</option>
                <option value="token">Token</option>
                <option value="hwid">HWID</option>
            </select>

            <!-- BOTÓN DE PASS TOKEN GLOBAL PARA ADMIN -->
            <button type="button" id="btn_token_pass_admin" class="btn-tpass" onclick="openModal('tokenPassAdminModal')">🔑 Contraseña Token (Actual: <?php echo htmlspecialchars($token_pass_admin_actual); ?>)</button>

            <div id="wrapper_ref_name" style="display:none;">
                <label>Nombre del Cliente (Referencia):</label>
                <input name="ref_name" id="input_ref_name" placeholder="Ej: Juan Pérez">
            </div>

            <label id="lbl_username">Usuario:</label>
            <input name="username" id="input_username" placeholder="Ingrese el usuario" required>

            <div id="wrapper_password">
                <label>Contraseña:</label>
                <input name="password" id="input_password" placeholder="••••••••">
            </div>

            <label>Días de duración:</label>
            <input type="number" name="exp_days" value="30" min="1" required>

            <div id="wrapper_limit">
                <label>Límite de conexiones simultáneas:</label>
                <input type="number" name="ssh_limit" id="input_ssh_limit" value="1" min="1" required>
            </div>

            <button name="crear_cuenta" class="modal-btn">Guardar Cuenta</button>
            <button type="button" class="modal-btn close-btn" onclick="closeModal('createAccountModal')"><?php echo __('cancel'); ?></button>
        </form>
    </div>
</div>

<!-- MODAL CONFIGURAR PASS TOKEN GLOBAL (ADMIN) -->
<div class="modal" id="tokenPassAdminModal">
    <div class="modal-box">
        <h3>🔑 Contraseña Token Global (Admin)</h3>
        <form method="POST">
            <p style="font-size:13px; color:#666;">Define la contraseña por defecto para todas las cuentas Token que crees como Administrador.</p>
            <label style="font-weight:600; font-size:14px;">Nueva Contraseña Token:</label>
            <input name="custom_token_pass" value="<?php echo htmlspecialchars($token_pass_admin_actual); ?>" placeholder="dealer" required>
            
            <button name="guardar_token_pass_admin" class="modal-btn" style="background:#198754; margin-top:15px;">Guardar Contraseña</button>
            <button type="button" class="modal-btn close-btn" onclick="closeModal('tokenPassAdminModal')">Cancelar</button>
        </form>
    </div>
</div>

<!-- MODAL DELETE RESELLER -->
<div class="modal" id="deleteUserModal">
    <div class="modal-box" style="text-align:center;">
        <h3><?php echo __('delete_confirm'); ?></h3>
        <form method="POST">
            <input type="hidden" name="delete_user" id="delete_user_id">
            <button class="modal-btn" style="background:#dc3545;"><?php echo __('delete'); ?></button>
            <button type="button" class="modal-btn close-btn" onclick="closeModal('deleteUserModal')"><?php echo __('cancel'); ?></button>
        </form>
    </div>
</div>

<!-- MODAL ONLINE -->
<div class="modal" id="onlineModal">
    <div class="modal-box">
        <h3>👥 <?php echo __('view_online'); ?></h3>
        <div id="onlineContent">...</div>
        <button type="button" class="modal-btn close-btn" onclick="closeModal('onlineModal')"><?php echo __('close'); ?></button>
    </div>
</div>

<script>
function openModal(id){ document.getElementById(id).style.display = "flex"; }
function closeModal(id){ document.getElementById(id).style.display = "none"; }
function confirmDeleteUser(id){ openModal('deleteUserModal'); document.getElementById('delete_user_id').value = id; }

function abrirGestionCreditos(id, username, creditosActuales) {
    document.getElementById('credit_reseller_id').value = id;
    document.getElementById('credit_reseller_name').innerText = username;
    document.getElementById('credit_reseller_current').innerText = creditosActuales;
    openModal('assignModal');
}

function abrirEditarPermisos(resellerUser, showGcp, showCf){
    document.getElementById('edit_reseller_user').value = resellerUser;
    document.getElementById('lbl_edit_reseller_user').innerText = resellerUser;
    document.getElementById('edit_show_gcp').checked = (showGcp == 1);
    document.getElementById('edit_show_cf').checked = (showCf == 1);
    openModal('editPermisosModal');
}

function actualizarCamposTipoAdmin(tipo){
    const wrapperRefName = document.getElementById('wrapper_ref_name');
    const inputRefName = document.getElementById('input_ref_name');
    const lblUser = document.getElementById('lbl_username');
    const inputUser = document.getElementById('input_username');
    const wrapperPass = document.getElementById('wrapper_password');
    const inputPass = document.getElementById('input_password');
    const wrapperLimit = document.getElementById('wrapper_limit');
    const inputLimit = document.getElementById('input_ssh_limit');
    const btnTokenPass = document.getElementById('btn_token_pass_admin');

    if(tipo === 'ssh'){
        wrapperRefName.style.display = 'none';
        inputRefName.required = false;

        lblUser.innerText = 'Usuario:';
        inputUser.placeholder = '';
        
        wrapperPass.style.display = 'block';
        inputPass.required = true;
        
        wrapperLimit.style.display = 'block';
        inputLimit.required = true;

        btnTokenPass.style.display = 'none';
    } else if(tipo === 'token') {
        wrapperRefName.style.display = 'block';
        inputRefName.required = true;

        lblUser.innerText = 'Token:';
        inputUser.placeholder = '';
        
        wrapperPass.style.display = 'none';
        inputPass.required = false;
        
        wrapperLimit.style.display = 'none';
        inputLimit.required = false;
        inputLimit.value = 1;

        btnTokenPass.style.display = 'block';
    } else if(tipo === 'hwid') {
        wrapperRefName.style.display = 'block';
        inputRefName.required = true;

        lblUser.innerText = 'HWID:';
        inputUser.placeholder = '';
        
        wrapperPass.style.display = 'none';
        inputPass.required = false;
        
        wrapperLimit.style.display = 'none';
        inputLimit.required = false;
        inputLimit.value = 1;

        btnTokenPass.style.display = 'none';
    }
}

function cargarOnline(){
    openModal('onlineModal');
    document.getElementById('onlineContent').innerHTML = "...";
    fetch('online.php')
        .then(res => res.text())
        .then(data => { document.getElementById('onlineContent').innerHTML = data; });
}
</script>
</body>
</html>
