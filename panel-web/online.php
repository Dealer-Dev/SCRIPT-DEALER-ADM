<?php
session_start();
if (!isset($_SESSION['user'])) {
    exit("Acceso denegado");
}

include __DIR__ . "/db.php";
$current_user = $_SESSION['user'];
$role = $_SESSION['role'];

// Obtener todas las instancias de procesos sshd pertenecientes a usuarios no-root
exec("ps -ef | grep sshd | grep -v root | grep -v grep | awk '{print $1}'", $output_raw);

// Contar el número de conexiones por cada usuario
$counts_all = array_count_values(array_filter($output_raw));

$usuarios_online = [];

foreach($counts_all as $u => $count){
    $u = trim($u);
    if(empty($u) || $u == "sshd") continue;

    // Filtrar por revendedor si no es administrador
    if($role == 'reseller'){
        $check = $conn->query("SELECT id FROM ssh_accounts WHERE username='$u' AND reseller='$current_user'");
        if($check && $check->num_rows > 0){
            $usuarios_online[$u] = $count;
        }
    } else {
        $usuarios_online[$u] = $count;
    }
}

if(empty($usuarios_online)){
    echo "<div style='padding:20px;text-align:center;color:#666;'>📡 No hay usuarios conectados en este momento.</div>";
} else {
    echo "<table style='width:100%;border-collapse:collapse;margin-top:10px;'>";
    echo "<tr style='background:#0f172a;color:#fff;'>
            <th style='padding:10px;'>Usuario</th>
            <th style='padding:10px;'>Conexiones</th>
            <th style='padding:10px;'>Estado</th>
          </tr>";

    foreach($usuarios_online as $usr => $count){
        // Definir color del badge según la cantidad de conexiones
        if ($count == 1) {
            $badge_style = "background:#198754;"; // Verde
            $text_status = "🟢 1 Conectado";
        } else {
            $badge_style = "background:#dc3545;"; // Rojo
            $text_status = "🔴 {$count} Conectados";
        }

        echo "<tr style='border-bottom:1px solid #eee;'>";
        echo "<td style='padding:10px;text-align:center;'><b>".htmlspecialchars($usr)."</b></td>";
        echo "<td style='padding:10px;text-align:center;'><b>{$count}</b></td>";
        echo "<td style='padding:10px;text-align:center;'>
                <span style='{$badge_style}color:#fff;padding:4px 12px;border-radius:12px;font-size:12px;font-weight:600;'>
                    {$text_status}
                </span>
              </td>";
        echo "</tr>";
    }
    echo "</table>";
}
?>
