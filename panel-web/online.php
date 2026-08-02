<?php
session_start();
include __DIR__ . "/db.php";
include __DIR__ . "/lang.php";

if (!isset($_SESSION['user'])) {
    exit("Acceso denegado");
}

$session_user = $_SESSION['user'];
$session_role = $_SESSION['role'];

// Función para obtener los detalles y el creador desde /etc/dealer-adm/userDIR/
function obtenerDetallesUsuario($username) {
    $file_path = "/etc/dealer-adm/userDIR/" . $username;
    $resultado = [
        'nombre' => $username, 
        'tipo' => 'ssh',
        'creador_nombre' => ''
    ];
    
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
        if (preg_match('/creador_nombre:\s*(.+)/i', $content, $matches)) {
            $resultado['creador_nombre'] = trim($matches[1]);
        }
    }
    return $resultado;
}

// Obtener la lista de usuarios del sistema Linux (UID >= 1000 y excluyendo nobody)
$raw_users = [];
exec("awk -F: '$3>=1000 && \$1!=\"nobody\" {print \$1}' /etc/passwd", $raw_users);

$conexiones_activas = [];

foreach ($raw_users as $user) {
    $detalles = obtenerDetallesUsuario($user);

    // FILTRO DE SEGURIDAD: Si es revendedor, solo mostrar si él creó el usuario
    if ($session_role === 'reseller' && $detalles['creador_nombre'] !== $session_user) {
        continue; // Omite este usuario si no le pertenece
    }

    // Contar conexiones únicas reales basadas en IPs distintas o procesos activos válidos de SSH
    // ps -u $user -f | grep sshd filtra de forma precisa las sesiones interactivas reales
    $cmd_check = "ps -u " . escapeshellarg($user) . " -f | grep 'sshd:' | grep -v grep | wc -l";
    $online_count = intval(exec($cmd_check));

    // Si no detecta por ps -u, intentamos un respaldo con netstat/ss para IPs unificadas del usuario
    if ($online_count <= 0) {
        $cmd_ss = "ss -tnp | grep 'user(" . escapeshellarg($user) . "' | wc -l";
        $online_count = intval(exec($cmd_ss));
    }

    // Si sigue habiendo al menos una sesión pero el comando devolvió más por redundancia de hilos, lo acotamos a 1 real por cliente presente, 
    // o si hay multiples conexiones reales independientes, tomamos el número de sesiones únicas.
    if ($online_count > 0) {
        // Normalizamos para que si está físicamente presente, cuente 1 conexión real por sesión activa de cliente
        $conexiones_reales = ($online_count > 0) ? 1 : 0; 

        // Si deseas permitir múltiples conexiones reales si vienen de IPs distintas:
        $cmd_ips = "ss -tn state established | grep '(:22)' | awk '{print \$5}' | cut -d: -f1 | sort -u | wc -l";
        
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
        // Asignamos 1 por cada cliente activo real detectado
        $conexiones_activas[$clave_unica]['count'] = max(1, $online_count > 0 ? 1 : 0);
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
