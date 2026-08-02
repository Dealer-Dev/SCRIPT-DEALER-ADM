<?php
session_start();
include __DIR__ . "/db.php";
include __DIR__ . "/lang.php";

if (!isset($_SESSION['user'])) {
    exit("Acceso denegado");
}

$session_user = $_SESSION['user'];
$session_role = $_SESSION['role'];

// Función para obtener los detalles desde /etc/dealer-adm/userDIR/
function obtenerDetallesUsuario($username) {
    $file_path = "/etc/dealer-adm/userDIR/" . $username;
    $resultado = ['nombre' => $username, 'tipo' => 'ssh'];
    
    if (file_exists($file_path)) {
        $content = file_get_contents($file_path);
        if (preg_match('/nombre:\s*(.+)/i', $content, $matches)) {
            $nombre = trim($matches[1]);
            if (!empty($nombre)) {
                $resultado['nombre'] = $nombre;
            }
        }
        if (preg_match('/tipo:\s*(.+)/i', $content, $matches)) {
            $tipo = trim($matches[1]);
            if (!empty($tipo)) {
                $resultado['tipo'] = strtolower($tipo);
            }
        }
    }
    return $resultado;
}

// Obtener la lista de usuarios del sistema Linux (UID >= 1000 y excluyendo nobody)
$raw_users = [];
exec("awk -F: '$3>=1000 && \$1!=\"nobody\" {print \$1}' /etc/passwd", $raw_users);

// Mapear conexiones activas recopilando la información de cada usuario
$conexiones_activas = [];

foreach ($raw_users as $user) {
    $cmd_ssh = "ps -ef | grep -E 'sshd: " . escapeshellarg($user) . "' | grep -v grep | wc -l";
    $online_count = intval(exec($cmd_ssh));

    if ($online_count > 0) {
        $detalles = obtenerDetallesUsuario($user);
        $nombre_mostrar = $detalles['nombre'];
        $tipo_mostrar = $detalles['tipo'];

        $clave_unica = $nombre_mostrar . '|' . $tipo_mostrar;

        if (!isset($conexiones_activas[$clave_unica])) {
            $conexiones_activas[$clave_unica] = [
                'nombre' => $nombre_mostrar,
                'tipo' => $tipo_mostrar,
                'count' => 0
            ];
        }
        $conexiones_activas[$clave_unica]['count'] += $online_count;
    }
}
?>

<style>
.online-table { width: 100%; border-collapse: collapse; margin-top: 5px; text-align: left; }
.online-table th { background: #0f172a; color: #fff; padding: 10px; font-size: 13px; text-align: center; }
.online-table td { padding: 10px; border-bottom: 1px solid #eee; font-size: 13px; text-align: center; }
.badge-online { background: #198754; color: #fff; padding: 4px 10px; border-radius: 12px; font-size: 11px; font-weight: 600; display: inline-flex; align-items: center; gap: 5px; }
.badge-online-multi { background: #dc3545; color: #fff; padding: 4px 10px; border-radius: 12px; font-size: 11px; font-weight: 600; display: inline-flex; align-items: center; gap: 5px; }
.badge-type-online { background: #6c757d; color: #fff; padding: 3px 8px; border-radius: 6px; font-size: 10px; text-transform: uppercase; font-weight: 700; }
.dot { width: 8px; height: 8px; background: #fff; border-radius: 50%; display: inline-block; }
</style>

<div style="font-size: 16px; font-weight: bold; margin-bottom: 10px; color: #1e293b; display: flex; align-items: center; gap: 8px;">
    👥 📡 Usuarios Conectados
</div>

<table class="online-table">
    <thead>
        <tr>
            <th style="width: 50px;">N°</th>
            <th>Usuario</th>
            <th>Tipo</th>
            <th>Estado</th>
        </tr>
    </thead>
    <tbody>
        <?php if (empty($conexiones_activas)): ?>
            <tr>
                <td colspan="4" style="padding: 20px; color: #64748b; text-align: center;">No hay usuarios conectados actualmente.</td>
            </tr>
        <?php else: ?>
            <?php $i = 1; foreach ($conexiones_activas as $datos): ?>
                <tr>
                    <td><b><?php echo $i++; ?></b></td>
                    <td><b><?php echo htmlspecialchars($datos['nombre']); ?></b></td>
                    <td><span class="badge-type-online"><?php echo htmlspecialchars($datos['tipo']); ?></span></td>
                    <td>
                        <?php if ($datos['count'] > 1): ?>
                            <span class="badge-online-multi"><span class="dot"></span> <?php echo $datos['count']; ?> Conectados</span>
                        <?php else: ?>
                            <span class="badge-online"><span class="dot"></span> 1 Conectado</span>
                        <?php endif; ?>
                    </td>
                </tr>
            <?php endforeach; ?>
        <?php endif; ?>
    </tbody>
</table>
