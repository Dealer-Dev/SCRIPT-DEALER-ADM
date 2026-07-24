<?php
session_start();
if (!isset($_SESSION['user'])) {
    exit("Acceso denegado");
}

include __DIR__ . "/db.php";
include __DIR__ . "/lang.php";

$current_user = $_SESSION['user'];
$role = $_SESSION['role'];

// 1. Capturar todos los procesos SSH activos escaneando la línea de comando sshd
exec("ps aux | grep 'sshd:' | grep -v grep", $ps_output);

$connected_counts = [];

foreach ($ps_output as $line) {
    // Extraer el nombre de usuario de patrones como "sshd: usuario [priv]" o "sshd: usuario@pts/1"
    if (preg_match('/sshd:\s*([^@\s\[]+)/', $line, $matches)) {
        $u = trim($matches[1]);
        if (!empty($u) && $u != 'root' && $u != 'sshd') {
            if (!isset($connected_counts[$u])) {
                $connected_counts[$u] = 0;
            }
            $connected_counts[$u]++;
        }
    }
}

$usuarios_online = [];

// 2. Filtrar y relacionar con la base de datos
foreach ($connected_counts as $usr => $count) {
    if ($role == 'reseller') {
        $stmt = $conn->prepare("SELECT reference_name, type FROM ssh_accounts WHERE username=? AND reseller=? LIMIT 1");
        $stmt->bind_param("ss", $usr, $current_user);
    } else {
        $stmt = $conn->prepare("SELECT reference_name, type FROM ssh_accounts WHERE username=? LIMIT 1");
        $stmt->bind_param("s", $usr);
    }
    
    $stmt->execute();
    $res = $stmt->get_result();

    if ($res && $res->num_rows > 0) {
        $row = $res->fetch_assoc();
        $display_name = !empty($row['reference_name']) ? $row['reference_name'] : $usr;
        $usuarios_online[] = [
            'username' => $usr,
            'name'     => $display_name,
            'type'     => strtoupper($row['type']),
            'count'    => $count
        ];
    } elseif ($role == 'admin') {
        // Para usuarios creados fuera del panel (vía terminal root)
        $usuarios_online[] = [
            'username' => $usr,
            'name'     => $usr,
            'type'     => 'SSH',
            'count'    => $count
        ];
    }
}

if (empty($usuarios_online)) {
    echo "<div style='padding:20px;text-align:center;color:#666;'>".__('no_online')."</div>";
} else {
    echo "<table style='width:100%;border-collapse:collapse;margin-top:10px;'>";
    echo "<tr style='background:#0f172a;color:#fff;'>
            <th style='padding:12px;width:50%;text-align:center;'>".__('user')."</th>
            <th style='padding:12px;width:50%;text-align:center;'>".__('status')."</th>
          </tr>";

    foreach ($usuarios_online as $item) {
        $count = $item['count'];
        if ($count == 1) {
            $badge_color = "#198754"; // Verde
            $text_status = __('connected_1');
        } else {
            $badge_color = "#dc3545"; // Rojo
            $text_status = sprintf(__('connected_n'), $count);
        }

        echo "<tr style='border-bottom:1px solid #eee;'>";
        echo "<td style='padding:12px;text-align:center;'>
                <b>".htmlspecialchars($item['name'])."</b>
                <br><small style='color:#666;'>(".$item['type'].")</small>
              </td>";
        echo "<td style='padding:12px;text-align:center;'>
                <span style='background:{$badge_color};color:#fff;padding:6px 14px;border-radius:20px;font-size:13px;font-weight:600;white-space:nowrap;display:inline-block;'>
                    {$text_status}
                </span>
              </td>";
        echo "</tr>";
    }
    echo "</table>";
}
?>
