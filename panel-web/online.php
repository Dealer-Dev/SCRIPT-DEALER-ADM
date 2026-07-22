<?php
session_start();
if (!isset($_SESSION['user'])) {
    exit("Acceso denegado");
}

// Obtener usuarios SSH conectados en la VPS local
exec("ps aux | grep sshd | grep -v root | grep -v grep | awk '{print $1}' | sort | uniq", $output);
$online_users = array_filter($output);

echo "<h3>Usuarios SSH Conectados en esta VPS</h3>";
if(empty($online_users)){
    echo "<p>No hay usuarios conectados en este momento.</p>";
} else {
    echo "<ul>";
    foreach($online_users as $user){
        echo "<li>👤 ".htmlspecialchars($user)."</li>";
    }
    echo "</ul>";
}
?>
