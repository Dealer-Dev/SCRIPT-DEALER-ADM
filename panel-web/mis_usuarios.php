<?php
session_start();
include __DIR__ . "/db.php";
include __DIR__ . "/lang.php";

if (!isset($_SESSION['user']) || $_SESSION['role'] != 'reseller') {
    header("Location: login.php");
    exit();
}

$username = $_SESSION['user'];

// 1. Procesar actualización de contraseña (solo SSH)
$update_msg = "";
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['action_type']) && $_POST['action_type'] === 'update_pass') {
    $edit_id = intval($_POST['user_id']);
    $new_pass = trim($_POST['new_password']);

    if (!empty($new_pass)) {
        // Verificar que el usuario pertenezca al reseller y sea de tipo SSH
        $stmt_check = $conn->prepare("SELECT username FROM ssh_accounts WHERE id=? AND reseller=? AND type='ssh'");
        $stmt_check->bind_param("is", $edit_id, $username);
        $stmt_check->execute();
        $user_data = $stmt_check->get_result()->fetch_assoc();

        if ($user_data) {
            $user_to_edit = $user_data['username'];

            // Actualizar contraseña en el sistema Linux del VPS
            $cmd = "echo " . escapeshellarg($user_to_edit . ":" . $new_pass) . " | sudo chpasswd 2>&1";
            exec($cmd);

            // Actualizar en la base de datos
            $stmt_up = $conn->prepare("UPDATE ssh_accounts SET password=? WHERE id=?");
            $stmt_up->bind_param("si", $new_pass, $edit_id);
            $stmt_up->execute();

            $current_type = isset($_GET['type']) ? "&type=" . urlencode($_GET['type']) : "";
            header("Location: mis_usuarios.php?updated=1" . $current_type);
            exit();
        }
    }
}

// 2. Eliminar usuario
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

// 3. Definir tipo/filtro activo
$type_filter = isset($_GET['type']) ? strtolower(trim($_GET['type'])) : 'ssh';
if (!in_array($type_filter, ['ssh', 'token', 'hwid'])) {
    $type_filter = 'ssh';
}

$stmt_list = $conn->prepare("SELECT * FROM ssh_accounts WHERE reseller=? AND type=? ORDER BY id DESC");
$stmt_list->bind_param("ss", $username, $type_filter);
$stmt_list->execute();
$result = $stmt_list->get_result();
$today = date('Y-m-d');
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

/* Pestañas */
.tabs{display:flex;gap:10px;margin-bottom:15px;flex-wrap:wrap;}
.tab-btn{padding:10px 18px;border-radius:10px;background:#e2e8f0;color:#334155;text-decoration:none;font-weight:600;font-size:14px;transition:0.2s;}
.tab-btn:hover{background:#cbd5e1;}
.tab-btn.active{background:#0d6efd;color:#fff;}

table{width:100%;background:#fff;border-collapse:collapse;border-radius:12px;overflow:hidden;box-shadow:0 4px 20px rgba(0,0,0,0.05);}
th{background:#0f172a;color:#fff;padding:12px;text-align:center;font-size:14px;}
td{padding:12px;border-bottom:1px solid #eee;text-align:center;font-size:14px;}

/* Botones de Acción */
.btn-del{background:#dc3545;color:#fff;border:none;padding:6px 14px;border-radius:6px;cursor:pointer;font-weight:600;}
.btn-del:hover{background:#bb2d3b;}
.btn-edit{background:#ffc107;color:#000;border:none;padding:6px 14px;border-radius:6px;cursor:pointer;font-weight:600;margin-right:5px;}
.btn-edit:hover{background:#e0a800;}

.empty-msg{padding:25px;text-align:center;color:#64748b;}
.exp-badge{background:#dc3545;color:#fff;padding:4px 10px;border-radius:6px;font-weight:800;font-size:12px;display:inline-block;}

/* Estilos del Modal */
.modal{display:none;position:fixed;z-index:999;left:0;top:0;width:100%;height:100%;background:rgba(0,0,0,0.5);align-items:center;justify-content:center;}
.modal-content{background:#fff;padding:25px;border-radius:12px;width:100%;max-width:400px;box-shadow:0 10px 25px rgba(0,0,0,0.2);}
.modal-content h3{margin-top:0;margin-bottom:15px;color:#0f172a;}
.form-group{margin-bottom:15px;text-align:left;}
.form-group label{display:block;margin-bottom:5px;font-weight:600;font-size:13px;color:#475569;}
.form-group input{width:100%;padding:10px;border:1px solid #cbd5e1;border-radius:6px;font-size:14px;}
.form-group input[readonly]{background:#f1f5f9;cursor:not-allowed;}
.modal-actions{display:flex;justify-content:flex-end;gap:10px;margin-top:20px;}
.btn-cancel{background:#94a3b8;color:#fff;border:none;padding:8px 16px;border-radius:6px;cursor:pointer;font-weight:600;}
.btn-save{background:#0d6efd;color:#fff;border:none;padding:8px 16px;border-radius:6px;cursor:pointer;font-weight:600;}
</style>
</head>
<body>
<div class="container">
    <div class="header-box">
        <h2><?php echo __('created_users_title'); ?></h2>
        <a href="reseller.php" style="text-decoration:none;color:#0d6efd;font-weight:600;"><?php echo __('back'); ?></a>
    </div>

    <!-- Pestañas -->
    <div class="tabs">
        <a href="mis_usuarios.php?type=ssh" class="tab-btn <?php echo ($type_filter == 'ssh') ? 'active' : ''; ?>">🔑 <?php echo __('ssh_normal'); ?></a>
        <a href="mis_usuarios.php?type=token" class="tab-btn <?php echo ($type_filter == 'token') ? 'active' : ''; ?>">🎫 <?php echo __('token_user'); ?></a>
        <a href="mis_usuarios.php?type=hwid" class="tab-btn <?php echo ($type_filter == 'hwid') ? 'active' : ''; ?>">📱 <?php echo __('hwid_user'); ?></a>
    </div>

    <table>
        <thead>
            <tr>
                <?php if($type_filter == 'ssh'): ?>
                    <th><?php echo __('user'); ?></th>
                    <th><?php echo __('pass'); ?></th>
                <?php elseif($type_filter == 'token'): ?>
                    <th><?php echo __('ref_name'); ?></th>
                    <th><?php echo __('token_user'); ?></th>
                <?php elseif($type_filter == 'hwid'): ?>
                    <th><?php echo __('ref_name'); ?></th>
                    <th><?php echo __('hwid_user'); ?></th>
                <?php endif; ?>
                <th><?php echo __('expiration_date'); ?></th>
                <th><?php echo __('action'); ?></th>
            </tr>
        </thead>
        <tbody>
            <?php if($result->num_rows == 0): ?>
                <tr>
                    <td colspan="4" class="empty-msg">No se encontraron usuarios en esta categoría.</td>
                </tr>
            <?php else: ?>
                <?php while($row = $result->fetch_assoc()): ?>
                <?php
                    $is_expired = ($row['expires'] <= $today);
                ?>
                <tr>
                    <?php if($type_filter == 'ssh'): ?>
                        <td><b><?php echo htmlspecialchars($row['username']); ?></b></td>
                        <td><code><?php echo htmlspecialchars($row['password']); ?></code></td>
                    <?php elseif($type_filter == 'token' || $type_filter == 'hwid'): ?>
                        <td><b><?php echo htmlspecialchars($row['reference_name']); ?></b></td>
                        <td><code><?php echo htmlspecialchars($row['username']); ?></code></td>
                    <?php endif; ?>

                    <td>
                        <?php if($is_expired): ?>
                            <span class="exp-badge">EXP</span>
                        <?php else: ?>
                            <?php echo htmlspecialchars($row['expires']); ?>
                        <?php endif; ?>
                    </td>
                    <td>
                        <div style="display:flex; justify-content:center; align-items:center;">
                            <?php if($type_filter == 'ssh'): ?>
                                <button type="button" class="btn-edit" onclick="openEditModal(<?php echo $row['id']; ?>, '<?php echo htmlspecialchars($row['username'], ENT_QUOTES); ?>', '<?php echo htmlspecialchars($row['password'], ENT_QUOTES); ?>')"><?php echo __('edit'); ?></button>
                            <?php endif; ?>

                            <a href="mis_usuarios.php?delete=<?php echo $row['id']; ?>&type=<?php echo urlencode($type_filter); ?>" onclick="return confirm('<?php echo __('delete_user_conf'); ?>')">
                                <button class="btn-del"><?php echo __('delete'); ?></button>
                            </a>
                        </div>
                    </td>
                </tr>
                <?php endwhile; ?>
            <?php endif; ?>
        </tbody>
    </table>
</div>

<!-- Modal para Editar Contraseña (Solo SSH) -->
<div id="editModal" class="modal">
    <div class="modal-content">
        <h3><?php echo __('edit_ssh_pass'); ?></h3>
        <form method="POST" action="mis_usuarios.php?type=ssh">
            <input type="hidden" name="action_type" value="update_pass">
            <input type="hidden" name="user_id" id="modal_user_id">

            <div class="form-group">
                <label><?php echo __('user'); ?></label>
                <input type="text" id="modal_username" readonly>
            </div>

            <div class="form-group">
                <label><?php echo __('pass'); ?></label>
                <input type="text" name="new_password" id="modal_password" required autocomplete="off">
            </div>

            <div class="modal-actions">
                <button type="button" class="btn-cancel" onclick="closeEditModal()"><?php echo __('cancel'); ?></button>
                <button type="submit" class="btn-save"><?php echo __('save'); ?></button>
            </div>
        </form>
    </div>
</div>

<script>
function openEditModal(id, username, password) {
    document.getElementById('modal_user_id').value = id;
    document.getElementById('modal_username').value = username;
    document.getElementById('modal_password').value = password;
    document.getElementById('editModal').style.display = 'flex';
}

function closeEditModal() {
    document.getElementById('editModal').style.display = 'none';
}

// Cerrar el modal al hacer clic fuera de él
window.onclick = function(event) {
    var modal = document.getElementById('editModal');
    if (event.target == modal) {
        closeEditModal();
    }
}
</script>
</body>
</html>
