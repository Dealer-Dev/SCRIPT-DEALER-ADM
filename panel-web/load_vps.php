<?php
session_start();
include __DIR__ . "/db.php";

if (!isset($_SESSION['user']) || $_SESSION['role'] != 'admin') {
    exit("Acceso denegado");
}

// Muestra el resumen del sistema local
$free_ram = shell_exec("free -h | awk '/^Mem:/{print $4}'");
$uptime   = shell_exec("uptime -p");

echo "<div style='padding:15px;text-align:center;'>";
echo "<b>Estado VPS Local:</b><br>";
echo "RAM Libre: " . $free_ram . "<br>";
echo "Uptime: " . $uptime;
echo "</div>";
?>
