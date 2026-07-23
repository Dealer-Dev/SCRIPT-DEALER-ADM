<?php
if (session_status() === PHP_SESSION_NONE) {
    session_start();
}

// 1. Cambiar idioma si el usuario selecciona uno
if (isset($_GET['set_lang'])) {
    $lang = $_GET['set_lang'];
    if (in_array($lang, ['es', 'en', 'fr'])) {
        $_SESSION['lang'] = $lang;
    }
}

// 2. Definir idioma por defecto (Español)
$current_lang = $_SESSION['lang'] ?? 'es';

// 3. Diccionario de traducciones
$translations = [
    'es' => [
        'welcome'       => 'Bienvenido',
        'login_title'   => 'Iniciar Sesión',
        'user'          => 'Usuario',
        'pass'          => 'Contraseña',
        'logout'        => 'Cerrar sesión',
        'resellers'     => 'Revendedores',
        'created_accts' => 'Cuentas Creadas',
        'credits'       => 'Créditos Repartidos',
        'view_online'   => '📡 Ver Conectados',
        'create_reseller' => '👤 Crear Revendedor',
        'manage_credits'  => '💳 Gestionar Créditos',
        'my_users'      => 'Mis usuarios creados',
        'create_account'=> 'Crear Cuenta',
        'type'          => 'Tipo',
        'action'        => 'Acción',
        'online_users'  => '👥 Usuarios Conectados',
        'status'        => 'Estado',
        'connected_1'   => '🟢 1 Conectado',
        'connected_n'   => '🔴 %d Conectados',
        'no_online'     => '📡 No hay usuarios conectados en este momento.',
        'close'         => 'Cerrar',
    ],
    'en' => [
        'welcome'       => 'Welcome',
        'login_title'   => 'Login',
        'user'          => 'Username',
        'pass'          => 'Password',
        'logout'        => 'Logout',
        'resellers'     => 'Resellers',
        'created_accts' => 'Created Accounts',
        'credits'       => 'Distributed Credits',
        'view_online'   => '📡 View Online',
        'create_reseller' => '👤 Create Reseller',
        'manage_credits'  => '💳 Manage Credits',
        'my_users'      => 'My created users',
        'create_account'=> 'Create Account',
        'type'          => 'Type',
        'action'        => 'Action',
        'online_users'  => '👥 Online Users',
        'status'        => 'Status',
        'connected_1'   => '🟢 1 Connected',
        'connected_n'   => '🔴 %d Connected',
        'no_online'     => '📡 No online users at this moment.',
        'close'         => 'Close',
    ],
    'fr' => [
        'welcome'       => 'Bienvenue',
        'login_title'   => 'Connexion',
        'user'          => 'Utilisateur',
        'pass'          => 'Mot de passe',
        'logout'        => 'Déconnexion',
        'resellers'     => 'Revendeurs',
        'created_accts' => 'Comptes Créés',
        'credits'       => 'Crédits Distribués',
        'view_online'   => '📡 Voir En Ligne',
        'create_reseller' => '👤 Créer Revendeur',
        'manage_credits'  => '💳 Gérer Crédits',
        'my_users'      => 'Mes utilisateurs créés',
        'create_account'=> 'Créer un Compte',
        'type'          => 'Type',
        'action'        => 'Action',
        'online_users'  => '👥 Utilisateurs En Ligne',
        'status'        => 'Statut',
        'connected_1'   => '🟢 1 Connecté',
        'connected_n'   => '🔴 %d Connectés',
        'no_online'     => '📡 Aucun utilisateur connecté pour le moment.',
        'close'         => 'Fermer',
    ]
];

// Función helper para obtener texto traducido
function __($key) {
    global $translations, $current_lang;
    return $translations[$current_lang][$key] ?? $translations['es'][$key] ?? $key;
}
?>
