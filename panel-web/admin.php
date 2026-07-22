<?php
ini_set('display_errors', 1);
error_reporting(E_ALL);
session_start();
include __DIR__ . "/db.php";

if(!isset($_SESSION['user']) || $_SESSION['role'] != 'admin'){
    header("Location: login.php");
    exit();
}

// Estadísticas para Single VPS
$total_resellers = $conn->query("SELECT COUNT(*) total FROM users WHERE role='reseller'")->fetch_assoc()['total'];
$total_accounts  = $conn->query("SELECT COUNT(*) total FROM ssh_accounts")->fetch_assoc()['total'];
$total_credits   = $conn->query("SELECT SUM(credits) total FROM users WHERE role='reseller'")->fetch_assoc()['total'] ?? 0;

// GESTIONAR CREDITOS
if(isset($_POST['guardar_creditos'])){
    $reseller_id = intval($_POST['reseller_id']);
    $sumar = intval($_POST['credits_sumar']);
    $restar = intval($_POST['credits_restar']);

    if($sumar > 0){
        $conn->query("UPDATE users SET credits = credits + $sumar WHERE id='$reseller_id'");
    }
    if($restar > 0){
        $conn->query("UPDATE users SET credits = GREATEST(credits - $restar, 0) WHERE id='$reseller_id'");
    }

    header("Location: admin.php");
    exit();
}

// CREAR RESELLER
if(isset($_POST['crear_reseller'])){
    $user = trim($_POST['username']);
    $pass = trim($_POST['password']);
    $cred = intval($_POST['credits']);

    $exist = $conn->query("SELECT id FROM users WHERE username='$user'");
    if($exist->num_rows > 0){
        $error = "El usuario ya existe";
    } else {
        $conn->query("INSERT INTO users (username, password, credits, role) VALUES ('$user', '$pass', '$cred', 'reseller')");
        header("Location: admin.php");
        exit();
    }
}

// ELIMINAR RESELLER
if(isset($_POST['delete_user'])){
    $id = intval($_POST['delete_user']);
    $conn->query("DELETE FROM users WHERE id='$id'");
    header("Location: admin.php");
    exit();
}

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
.actions{margin-top:25px;display:flex;gap:15px;}
.action-btn{border:none;padding:15px 22px;border-radius:12px;color:#fff;font-size:15px;font-weight:600;cursor:pointer;}
.btn-reseller{background:linear-gradient(135deg,#6610f2,#d63384);}
.btn-credit{background:linear-gradient(135deg,#16a34a,#22c55e);}
.table-card{background:#fff;margin-top:25px;padding:20px;border-radius:16px;box-shadow:0 4px 20px rgba(0,0,0,0.05);}
table{width:100%;border-collapse:collapse;margin-top:15px;}
th{background:#0f172a;color:#fff;padding:12px;text-align:center;}
td{padding:12px;text-align:center;border-bottom:1px solid #eee;}
.badge{background:#0d6efd;color:#fff;padding:5px 10px;border-radius:15px;font-size:12px;}
.btn-small{border:none;padding:6px 12px;border-radius:8px;color:#fff;cursor:pointer;}
.btn-delete{background:#dc3545;}
.modal{position:fixed;top:0;left:0;width:100%;height:100%;background:rgba(0,0,0,0.5);display:none;justify-content:center;align-items:center;z-index:999;}
.modal-box{background:#fff;width:90%;max-width:500px;padding:25px;border-radius:16px;}
input,select{width:100%;padding:12px;margin-top:10px;border-radius:8px;border:1px solid #ddd;}
.modal-btn{width:100%;margin-top:15px;padding:12px;border:none;border-radius:8px;color:#fff;font-weight:600;cursor:pointer;background:#0d6efd;}
.close-btn{background:#6b7280;}
</style>
</head>
<body>
<div class="header">
    <h2>⚡ Panel Admin - Single VPS</h2>
    <div>Admin: <b><?php echo $_SESSION['user']; ?></b> <a href="logout.php" class="logout">Salir</a></div>
</div>

<div class="container">
    <div class="stats">
        <div class="stat-card"><h3>Revendedores</h3><h1><?php echo $total_resellers; ?></h1></div>
        <div class="stat-card"><h3>Cuentas Creadas</h3><h1><?php echo $total_accounts; ?></h1></div>
        <div class="stat-card"><h3>Créditos Repartidos</h3><h1><?php echo $total_credits; ?></h1></div>
    </div>

    <div class="actions">
        <button class="action-btn btn-reseller" onclick="openModal('resellerModal')">👤 Crear Revendedor</button>
        <button class="action-btn btn-credit" onclick="openModal('assignModal')">💳 Gestionar Créditos</button>
    </div>

    <div class="table-card">
        <h3>Lista de Revendedores</h3>
        <table>
            <tr><th>ID</th><th>Usuario</th><th>Password</th><th>Créditos</th><th>Acciones</th></tr>
            <?php while($r = $resellers->fetch_assoc()){ ?>
            <tr>
                <td><?php echo $r['id']; ?></td>
                <td><?php echo $r['username']; ?></td>
                <td><?php echo $r['password']; ?></td>
                <td><span class="badge"><?php echo $r['credits']; ?></span></td>
                <td>
                    <button class="btn-small btn-delete" onclick="confirmDeleteUser(<?php echo $r['id']; ?>)">Eliminar</button>
                </td>
            </tr>
            <?php } ?>
        </table>
    </div>
</div>

<!-- MODAL CREAR RESELLER -->
<div class="modal" id="resellerModal">
    <div class="modal-box">
        <h3>Crear Revendedor</h3>
        <form method="POST">
            <input name="username" placeholder="Usuario" required>
            <input name="password" placeholder="Password" required>
            <input type="number" name="credits" placeholder="Créditos Iniciales" value="0" required>
            <button name="crear_reseller" class="modal-btn">Crear</button>
            <button type="button" class="modal-btn close-btn" onclick="closeModal('resellerModal')">Cancelar</button>
        </form>
    </div>
</div>

<!-- MODAL CREDITOS -->
<div class="modal" id="assignModal">
    <div class="modal-box">
        <h3>Gestionar Créditos</h3>
        <form method="POST">
            <select name="reseller_id" required>
                <option value="">Seleccionar Revendedor</option>
                <?php
                $u_sel = $conn->query("SELECT * FROM users WHERE role='reseller' ORDER BY username ASC");
                while($u = $u_sel->fetch_assoc()){
                    echo "<option value='".$u['id']."'>".$u['username']." (Actuales: ".$u['credits'].")</option>";
                }
                ?>
            </select>
            <input type="number" name="credits_sumar" placeholder="Cantidad a sumar (Opcional)">
            <input type="number" name="credits_restar" placeholder="Cantidad a restar (Opcional)">
            <button name="guardar_creditos" class="modal-btn">Guardar Cambios</button>
            <button type="button" class="modal-btn close-btn" onclick="closeModal('assignModal')">Cancelar</button>
        </form>
    </div>
</div>

<!-- MODAL DELETE -->
<div class="modal" id="deleteUserModal">
    <div class="modal-box" style="text-align:center;">
        <h3> ¿Eliminar Revendedor?</h3>
        <form method="POST">
            <input type="hidden" name="delete_user" id="delete_user_id">
            <button class="modal-btn" style="background:#dc3545;">Sí, Eliminar</button>
            <button type="button" class="modal-btn close-btn" onclick="closeModal('deleteUserModal')">Cancelar</button>
        </form>
    </div>
</div>

<script>
function openModal(id){ document.getElementById(id).style.display = "flex"; }
function closeModal(id){ document.getElementById(id).style.display = "none"; }
function confirmDeleteUser(id){ openModal('deleteUserModal'); document.getElementById('delete_user_id').value = id; }
</script>
</body>
</html>
