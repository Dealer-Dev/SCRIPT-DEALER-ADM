<?php
session_start();
include __DIR__ . "/db.php";

if (!isset($_SESSION['user']) || $_SESSION['role'] != 'reseller') {
    header("Location: login.php");
    exit();
}

$username = $_SESSION['user'];

// ELIMINAR USUARIO
if(isset($_GET['delete'])){
    $id = intval($_GET['delete']);
    $get = $conn->query("SELECT * FROM ssh_accounts WHERE id='$id' AND reseller='$username'")->fetch_assoc();

    if($get){
        $user_to_del = $get['username'];
        exec("sudo userdel -f $user_to_del");
        $conn->query("DELETE FROM ssh_accounts WHERE id='$id'");
    }
    header("Location: mis_usuarios.php");
    exit();
}

$result = $conn->query("SELECT * FROM ssh_accounts WHERE reseller='$username' ORDER BY id DESC");
?>
<!DOCTYPE html>
<html>
<head>
<title>Mis Usuarios</title>
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<style>
body{font-family:'Segoe UI',sans-serif;background:#f4f6f9;margin:0;padding:20px;}
.container{max-width:900px;margin:auto;}
table{width:100%;background:#fff;border-collapse:collapse;margin-top:20px;border-radius:12px;overflow:hidden;box-shadow:0 4px 20px rgba(0,0,0,0.05);}
th{background:#111827;color:#fff;padding:12px;text-align:center;}
td{padding:12px;border-bottom:1px solid #eee;text-align:center;}
.btn-del{background:#dc3545;color:#fff;border:none;padding:6px 12px;border-radius:6px;cursor:pointer;}
</style>
</head>
<body>
<div class="container">
    <div style="display:flex;justify-content:space-between;align-items:center;">
        <h2>Mis Usuarios Creados</h2>
        <a href="reseller.php" style="text-decoration:none;color:#0d6efd;font-weight:600;">← Volver</a>
    </div>

    <table>
        <tr>
            <th>Tipo</th>
            <th>Nombre/Ref</th>
            <th>Usuario/HWID/Token</th>
            <th>Expira</th>
            <th>Acción</th>
        </tr>
        <?php while($row = $result->fetch_assoc()): ?>
        <tr>
            <td><b><?php echo strtoupper($row['type']); ?></b></td>
            <td><?php echo htmlspecialchars($row['reference_name']); ?></td>
            <td><?php echo htmlspecialchars($row['username']); ?></td>
            <td><?php echo $row['expires']; ?></td>
            <td>
                <a href="mis_usuarios.php?delete=<?php echo $row['id']; ?>" onclick="return confirm('¿Eliminar usuario?')">
                    <button class="btn-del">Eliminar</button>
                </a>
            </td>
        </tr>
        <?php endwhile; ?>
    </table>
</div>
</body>
</html>
