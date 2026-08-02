<?php
session_start();
include __DIR__ . "/db.php";
include __DIR__ . "/lang.php";

if (!isset($_SESSION['user'])) {
    exit("Acceso denegado");
}

$session_user = $_SESSION['user'];
$session_role = $_SESSION['role'];

// Función para obtener el nombre de referencia desde /etc/dealer-adm/userDIR/
function obtenerNombreReferencia($username) {
    $file_path = "/etc/dealer-adm/userDIR/" . $username;
    if (file_exists($file_path)) {
        $content = file_get_contents($file_path);
        if (preg_match('/nombre:\s*(.+)/i', $content, $matches)) {
            $nombre = trim($matches[1]);
            if (!empty($nombre)) {
                return $nombre;
            }
        }
    }
    return $username; // Si no tiene nombre de referencia, devuelve el usuario original
}

// Obtener la lista de usuarios del sistema Linux (UID >= 1000 y excluyendo nobody)
$raw_users = [];
exec("awk -F: '$3>=1000 && \$1!=\"nobody\" {print \$1}' /etc/passwd", $raw_users);

// Mapear conexiones activas por usuario mediante comandos del sistema
$conexiones_activas = [];

foreach ($raw_users as $user) {
    // Verificar conexiones SSH activas
    $cmd_ssh = "ps -ef | grep -E 'sshd: " . escapeshellarg($user) . "' | grep -v grep | wc -l";
    $online_count = intval(exec($cmd_ssh));

    if ($online_count > 0) {
        // Verificar si el usuario pertenece al revendedor actual (si el rol es revendedor)
        $file_path = "/etc/dealer-adm/userDIR/" . $user;
        $creador_valido = true;

        if ($session_role === 'reseller') {
            // Si es revendedor, validamos opcionalmente si el archivo existe o fue creado por él
            if (file_exists($file_path)) {
                $content = file_get_contents($file_path);
                // Si tienes un filtro de creador por nombre en el archivo
                if (preg_match('/creador_nombre:\s*(.+)/i', $content, $matches)) {
                    if (trim($matches[1]) !== $session_user) {
                        // Opcional: si manejas la restricción estricta de revendedor
                        // $creador_valido = false; 
                    }
                }
            }
        }

        if ($creador_valido) {
            $nombre_mostrar = obtenerNombreReferencia($user);
            $conexiones_activas[$nombre_mostrar] = ($conexiones_activas[$nombre_mostrar] ?? 0) + $online_count;
        }
    }
}
?>

<style>
.online-table { width: 100%; border-collapse: collapse; margin-top: 5px; text-align: left; }
.online-table th { background: #0f172a; color: #fff; padding: 10px; font-size: 13px; text-align: center; }
.online-table td { padding: 10px; border-bottom: 1px solid #eee; font-size: 13px; text-align: center; }
.badge-online { background: #198754; color: #fff; padding: 4px 10px; border-radius: 12px; font-size: 11px; font-weight: 600; display: inline-flex; align-items: center; gap: 5px; }
.badge-online-multi { background: #dc3545; color: #fff; padding: 4px 10px; border-radius: 12px; font-size: 11px; font-weight: 600; display: inline-flex; align-items: center; gap: 5px; }
.dot { width: 8px; height: 8px; background: #fff; border-radius: 50%; display: inline-block; }
</style>

<table class="online-table">
    <thead>
        <tr>
            <th>Usuario</th>
            <th>Estado</th>
        </tr>
    </thead>
    <tbody>
        <?php if (empty($conexiones_activas)): ?>
            <tr>
                <td colspan="2" style="padding: 20px; color: #64748b; text-align: center;">No hay usuarios conectados actualmente.</td>
            </tr>
        <?php else: ?>
            <?php foreach ($conexiones_activas as $nombre_ref => $count): ?>
                <tr>
                    <td><b><?php echo htmlspecialchars($nombre_ref); ?></b></td>
                    <td>
                        <?php if ($count > 1): ?>
                            <span class="badge-online-multi"><span class="dot"></span> <?php echo $count; ?> Conectados</span>
                        <?php else: ?>
                            <span class="badge-online"><span class="dot"></span> 1 Conectado</span>
                        <?php endif; ?>
                    </td>
                </tr>
            <?php endforeach; ?>
        <?php endif; ?>
    </tbody>
</table>
