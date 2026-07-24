<?php
session_start();
include __DIR__ . "/db.php";
include __DIR__ . "/lang.php";

if (!isset($_SESSION['user']) || $_SESSION['role'] != 'reseller') {
    header("Location: login.php");
    exit();
}

$username = $_SESSION['user'];

// 1. Eliminar usuario
if(isset($_GET['delete'])){
    $id = intval($_GET['delete']);
    $stmt = $conn->prepare("SELECT * FROM ssh_accounts WHERE id=? AND reseller=?");
    $stmt->bind_param("is", $id, $username);
    $stmt->execute();
    $get = $stmt->get_result()->fetch_assoc();

    if($get){
        $user_to_del = $get['username'];

        exec("sudo pkill -u $user_to_del 2>/dev/null; sudo userdel -f $user_to_del 2>/dev/null");
        exec("sudo rm -f /etc/dealer-adm/userDIR/$user_to_del");

        if(file_exists('/etc/hysteria/config.json')){
            $del_hys = "python3 -c \"
import json, os
p = '/etc/hysteria/config.json'
if os.path.exists(p):
    with open(p) as f: c=json.load(f)
    cfg = c.get('auth',{}).get('config',[])
    cfg = [u for u in cfg if not u.startswith('$user_to_del:')]
    c['auth']['config'] = cfg
    with open(p,'w') as f: json.dump(c,f,indent=2)
\" && sudo systemctl restart hysteria-server >/dev/null 2>&1";
            exec($del_hys);
        }

        $conn->query("DELETE FROM ssh_accounts WHERE id='$id'");
    }
    $current_type = isset($_GET['type']) ? "&type=" . urlencode($_GET['type']) : "";
    header("Location: mis_usuarios.php?deleted=1" . $current_type);
    exit();
}

// 2. Definir tipo/filtro activo
$type_filter = isset($_GET['type']) ? trim($_GET['type']) : 'all';
$valid_types = ['ssh', 'token', 'hwid'];

if (in_array($type_filter, $valid_types)) {
    $stmt_list = $conn->prepare("SELECT * FROM ssh_accounts WHERE reseller=? AND type=? ORDER BY id DESC");
    $stmt_list->bind_param("ss", $username, $type_filter);
} else {
    $type_filter = 'all';
    $stmt_list = $conn->prepare("SELECT * FROM ssh_accounts WHERE reseller=? ORDER BY id DESC");
    $stmt_list->bind_param("s", $username);
}

$stmt_list->execute();
$result = $stmt_list->get_result();
?>
<!DOCTYPE html>
<html>
<head>
<title><?php echo __('created_users_title'); ?></title>
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<style>
*{box-sizing:border-box;}
body{font-family:'Segoe UI',sans-serif;background:#f4f6f9;margin:0;padding:20px;}
.container{max-width:950px;margin:auto;}
.header-box{display:flex;justify-content:space-between;align-items:center;margin-bottom:20px;}
.header-box h2{margin:0;color:#111;}

/* Estilo de Pestañas (Tabs) */
.tabs{display:flex;gap:10px;margin-bottom:15px;flex-wrap:wrap;}
.tab-btn{padding:10px 18px;border-radius:10px;background:#e2e8f0;color:#334155;text-decoration:none;font-weight:600;font-size:14px;transition:0.2s;}
.tab-btn:hover{background:#cbd5e1;}
.tab-btn.active{background:#0d6efd;color:#fff;}

.badge-type{padding:4px 10px;border-radius:6px;font-size:11px;font-weight:700;color:#fff;display:inline-block;}
.badge-ssh{background:#0d6efd;}
.badge-token{background:#ffc107;color:#000;}
.badge-hwid{background:#6f42c1;}

table{width:100%;background:#fff;border-collapse:collapse;border-radius:12px;overflow:hidden;box-shadow:0 4px 20px rgba(0,0,0,0.05);}
th{background:#0f172a;color:#fff;padding:12px;text-align:center;font-size:14px;}
td{padding:12px;border-bottom:1px solid #eee;text-align:center;font-size:14px;}
.btn-del{background:#dc3545;color:#fff;border:none;padding:6px 14px;border-radius:6px;cursor:pointer;font-weight:600;}
.btn-del:hover{background:#bb2d3b;}
.empty-msg{padding:25px;text-align:center;color:#64748b;}
</style>
</head>
<body>
<div class="container">
    <div class="header-box">
        <h2><?php echo __('created_users_title'); ?></h2>
        <a href="reseller.php" style="text-decoration:none;color:#0d6efd;font-weight:600;"><?php echo __('back'); ?></a>
    </div>

    <!-- Menú de Pestañas de Filtrado -->
    <div class="tabs">
        <a href="mis_usuarios.php?type=all" class="tab-btn <?php echo ($type_filter == 'all') ? 'active' : ''; ?>">🌐 Todos</a>
        <a href="mis_usuarios.php?type=ssh" class="tab-btn <?php echo ($type_filter == 'ssh') ? 'active' : ''; ?>">🔑 SSH Normal</a>
        <a href="mis_usuarios.php?type=token" class="tab-btn <?php echo ($type_filter == 'type' || $type_filter == 'token') ? 'active' : ''; ?>">🎫 Token</a>
        <a href="mis_usuarios.php?type=hwid" class="tab-btn <?php echo ($type_filter == 'hwid') ? 'active' : ''; ?>">📱 HWID</a>
    </div>

    <table>
        <thead>
            <tr>
                <th><?php echo __('type'); ?></th>
                <th><?php echo __('ref_name'); ?></th>
                <th><?php echo __('user'); ?>/HWID/Token</th>
                <th><?php echo __('expires'); ?></th>
                <th><?php echo __('action'); ?></th>
            </tr>
        </thead>
        <tbody>
            <?php if($result->num_rows == 0): ?>
                <tr>
                    <td colspan="5" class="empty-msg">No se encontraron usuarios registrados en esta categoría.</td>
                </tr>
            <?php else: ?>
                <?php while($row = $result->fetch_assoc()): ?>
                <?php
                    $t = strtolower($row['type']);
                    $badge_class = "badge-ssh";
                    if($t == 'token') $badge_class = "badge-token";
                    if($t == 'hwid') $badge_class = "badge-hwid";
                ?>
                <tr>
                    <td><span class="badge-type <?php echo $badge_class; ?>"><?php echo strtoupper($row['type']); ?></span></td>
                    <td><b><?php echo htmlspecialchars($row['reference_name']); ?></b></td>
                    <td><code><?php echo htmlspecialchars($row['username']); ?></code></td>
                    <td><?php echo htmlspecialchars($row['expires']); ?></td>
                    <td>
                        <a href="mis_usuarios.php?delete=<?php echo $row['id']; ?>&type=<?php echo urlencode($type_filter); ?>" onclick="return confirm('<?php echo __('delete_user_conf'); ?>')">
                            <button class="btn-del"><?php echo __('delete'); ?></button>
                        </a>
                    </td>
                </tr>
                <?php endwhile; ?>
            <?php endif; ?>
        </tbody>
    </table>
</div>
</body>
</html>
