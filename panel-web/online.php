<?php
session_start();
if (!isset($_SESSION['user'])) {
    exit("Acceso denegado");
}

include __DIR__ . "/db.php";
$current_user = $_SESSION['user'];
$role = $_SESSION['role'];

// 1. Obtener usuarios de Linux conectados por SSH
exec("ps -ef | grep sshd | grep -v root | grep -v grep | awk '{print $3, $8}' | sort | uniq", $output);

// Si no hay con ps, intentar mediante netstat/ss
exec("ps aux | grep sshd | grep -v root | grep -v grep | awk '{print $1}' | sort | uniq", $output_users);
$online_raw = array_filter(array_unique($output_users));

$usuarios_online = [];

foreach($online_raw as $u){
    $u = trim($u);
    if(empty($u) || $u == "sshd") continue;

    // Si es revendedor, filtrar solo sus usuarios creados
    if($role == 'reseller'){
        $check = $conn->query("SELECT id FROM ssh_accounts WHERE username='$u' AND reseller='$current_user'");
        if($check && $check->num_rows > 0){
            $usuarios_online[] = $u;
        }
    } else {
        // El admin ve todos los usuarios SSH conectados
        $usuarios_online[] = $u;
    }
}

if(empty($usuarios_online)){
    echo "<div style='padding:20px;text-align:center;color:#666;'>📡 No hay usuarios conectados en este momento.</div>";
} else {
    echo "<table style='width:100%;border-collapse:collapse;margin-top:10px;'>";
    echo "<tr style='background:#0f172a;color:#fff;'><th style='padding:10px;'>Usuario</th><th style='padding:10px;'>Estado</th></tr>";
    foreach($usuarios_online as $usr){
        echo "<tr style='border-bottom:1px solid #eee;'>";
        echo "<td style='padding:10px;text-align:center;'><b>".htmlspecialchars($usr)."</b></td>";
        echo "<td style='padding:10px;text-align:center;'><span style='background:#198754;color:#fff;padding:4px 10px;border-radius:12px;font-size:12px;'>🟢 Online</span></td>";
        echo "</tr>";
    }
    echo "</table>";
}
?>
