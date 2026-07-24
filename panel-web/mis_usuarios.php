<?php
session_start();
include __DIR__ . "/db.php";
include __DIR__ . "/lang.php";

if (!isset($_SESSION['user']) || $_SESSION['role'] != 'reseller') {
    header("Location: login.php");
    exit();
}

$username = $_SESSION['user'];

if(isset($_GET['delete'])){
    $id = intval($_GET['delete']);
    $stmt = $conn->prepare("SELECT * FROM ssh_accounts WHERE id=? AND reseller=?");
    $stmt->bind_param("is", $id, $username);
    $stmt->execute();
    $get = $stmt->get_result()->fetch_assoc();

    if($get){
        $user_to_del = $get['username'];

        exec("sudo pkill -u $user_to_del 2>/dev/null; sudo userdel -f $user_to_del 2>/dev/null");
        exec("sudo rm -f /etc/dealer-adm/userDIR/$user_to_del");

        if(file_exists('/etc/hysteria/config.json')){
            $del_hys = "python3 -c \"
import json, os
p = '/etc/hysteria/config.json'
if os.path.exists(p):
    with open(p) as f: c=json.load(f)
    cfg = c.get('auth',{}).get('config',[])
    cfg = [u for u in cfg if not u.startswith('$user_to_del:')]
    c['auth']['config'] = cfg
    with open(p,'w') as f: json.dump(c,f,indent=2)
\" && sudo systemctl restart hysteria-server >/dev/null 2>&1";
            exec($del_hys);
        }

        $conn->query("DELETE FROM ssh_accounts WHERE id='$id'");
    }
    header("Location: mis_usuarios.php");
    exit();
}

$stmt_list = $conn->prepare("SELECT * FROM ssh_accounts WHERE reseller=? ORDER BY id DESC");
$stmt_list->bind_param("s", $username);
$stmt_list->execute();
$result = $stmt_list->get_result();
?>
<!DOCTYPE html>
<html>
<head>
<title><?php echo __('created_users_title'); ?></title>
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
        <h2><?php echo __('created_users_title'); ?></h2>
        <a href="reseller.php" style="text-decoration:none;color:#0d6efd;font-weight:600;"><?php echo __('back'); ?></a>
    </div>

    <table>
        <tr>
            <th><?php echo __('type'); ?></th>
            <th><?php echo __('ref_name'); ?></th>
            <th><?php echo __('user'); ?>/HWID/Token</th>
            <th><?php echo __('expires'); ?></th>
            <th><?php echo __('action'); ?></th>
        </tr>
        <?php while($row = $result->fetch_assoc()): ?>
        <tr>
            <td><b><?php echo strtoupper($row['type']); ?></b></td>
            <td><?php echo htmlspecialchars($row['reference_name']); ?></td>
            <td><?php echo htmlspecialchars($row['username']); ?></td>
            <td><?php echo $row['expires']; ?></td>
            <td>
                <a href="mis_usuarios.php?delete=<?php echo $row['id']; ?>" onclick="return confirm('<?php echo __('delete_user_conf'); ?>')">
                    <button class="btn-del"><?php echo __('delete'); ?></button>
                </a>
            </td>
        </tr>
        <?php endwhile; ?>
    </table>
</div>
</body>
</html>
