<?php
session_start();
include __DIR__ . "/db.php";

if(isset($_POST['login'])){
    $user = trim($_POST['user']);
    $pass = trim($_POST['pass']);

    $stmt = $conn->prepare("SELECT * FROM users WHERE username = ? LIMIT 1");
    $stmt->bind_param("s", $user);
    $stmt->execute();
    $res = $stmt->get_result();

    if($res && $res->num_rows > 0){
        $row = $res->fetch_assoc();
        if($row['password'] === $pass){
            $_SESSION['user'] = $row['username'];
            $_SESSION['role'] = $row['role'];

            if($row['role'] === 'admin'){
                header("Location: admin.php");
            } else {
                header("Location: reseller.php");
            }
            exit();
        } else {
            $error = "Credenciales incorrectas";
        }
    } else {
        $error = "Credenciales incorrectas";
    }
}
?>
<!DOCTYPE html>
<html lang="es">
<head>
<title>Panel Dealer - Iniciar Sesión</title>
<link rel="icon" href="logo.png">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<style>
* { box-sizing: border-box; }
body {
    margin: 0;
    font-family: 'Segoe UI', sans-serif;
    background: #f4f6f9;
    min-height: 100vh;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 20px;
}
.wrapper {
    width: 100%;
    max-width: 900px;
    min-height: 520px;
    background: #fff;
    border-radius: 20px;
    overflow: hidden;
    display: flex;
    box-shadow: 0 10px 35px rgba(0,0,0,0.10);
}
.left {
    flex: 1;
    background: linear-gradient(135deg, #0d6efd, #6610f2);
    color: #fff;
    display: flex;
    flex-direction: column;
    justify-content: center;
    align-items: center;
    padding: 40px;
    text-align: center;
}
.logo-box img {
    width: 110px;
    height: 110px;
    object-fit: contain;
}
.title {
    margin: 15px 0 0;
    font-size: 36px;
    font-weight: 700;
}
.left p {
    opacity: .95;
    font-size: 16px;
    line-height: 1.5;
    max-width: 300px;
    margin-top: 15px;
}
.right {
    flex: 1;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 40px;
}
.box { width: 100%; max-width: 320px; }
.box h2 {
    margin: 0 0 25px;
    color: #222;
    font-size: 32px;
    font-weight: 700;
}
input {
    width: 100%;
    padding: 14px;
    border-radius: 10px;
    border: 1px solid #ddd;
    margin-top: 14px;
    font-size: 15px;
    background: #fafafa;
}
input:focus {
    border-color: #0d6efd;
    outline: none;
    background: #fff;
}
button {
    width: 100%;
    padding: 14px;
    margin-top: 20px;
    border: none;
    border-radius: 10px;
    background: linear-gradient(135deg, #0d6efd, #6610f2);
    color: #fff;
    font-size: 16px;
    font-weight: 600;
    cursor: pointer;
}
.error {
    margin-top: 15px;
    background: #fdecea;
    color: #b02a37;
    padding: 12px;
    border-radius: 8px;
    text-align: center;
    font-size: 14px;
}
@media(max-width: 768px){
    .wrapper { flex-direction: column; }
    .left, .right { padding: 30px 20px; }
}
</style>
</head>
<body>
<div class="wrapper">
    <div class="left">
        <div class="logo-box">
            <img src="logo.png" alt="Logo">
        </div>
        <h1 class="title">Panel Dealer</h1>
        <p>Gestión profesional de usuarios SSH, Token y HWID</p>
    </div>
    <div class="right">
        <div class="box">
            <h2>Bienvenido</h2>
            <form method="POST">
                <input name="user" placeholder="Usuario" required autocomplete="off">
                <input type="password" name="pass" placeholder="Contraseña" required>
                <button type="submit" name="login">Iniciar Sesión</button>
            </form>
            <?php if(isset($error)): ?>
                <div class="error"><?php echo $error; ?></div>
            <?php endif; ?>
        </div>
    </div>
</div>
</body>
</html>
