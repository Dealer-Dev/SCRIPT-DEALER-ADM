<?php
if (session_status() === PHP_SESSION_NONE) {
    session_start();
}

// Guardar idioma en la sesión si se pasa por GET
if (isset($_GET['set_lang'])) {
    $lang = $_GET['set_lang'];
    if (in_array($lang, ['es', 'en', 'fr'])) {
        $_SESSION['lang'] = $lang;
    }
}

// Idioma por defecto: Español
$current_lang = $_SESSION['lang'] ?? 'es';

$translations = [
    'es' => [
        'login_welcome'    => 'Bienvenido',
        'login_subtitle'   => 'Gestión local de usuarios SSH, Token y HWID en tu VPS',
        'login_btn'        => 'Iniciar Sesión',
        'user'             => 'Usuario',
        'pass'             => 'Contraseña',
        'err_credentials'  => 'Credenciales incorrectas',
        'logout'           => 'Salir',
        'resellers'        => 'Revendedores',
        'created_accts'    => 'Cuentas Creadas',
        'credits_shared'   => 'Créditos Repartidos',
        'view_online'      => '📡 Ver Conectados',
        'create_reseller'  => '👤 Crear Revendedor',
        'manage_credits'   => '💳 Gestionar Créditos',
        'my_users'         => 'Mis usuarios creados',
        'create_account'   => 'Crear Cuenta',
        'status'           => 'Estado',
        'action'           => 'Acción',
        'connected_1'      => '🟢 1 Conectado',
        'connected_n'      => '🔴 %d Conectados',
        'no_online'        => '📡 No hay usuarios conectados en este momento.',
        'close'            => 'Cerrar',
        'back'             => '← Volver',
        'reseller_title'   => 'Panel Revendedor',
        'available_credits'=> '💰 Créditos disponibles',
        'initial_credits'  => 'Créditos Iniciales',
        'cancel'           => 'Cancelar',
        'save'             => 'Guardar Cambios',
        'delete'           => 'Eliminar',
        'delete_confirm'   => '⚠️ ¿Eliminar Revendedor?',
        'delete_user_conf' => '¿Eliminar usuario?',
        'ssh_normal'       => 'SSH Normal',
        'token_user'       => 'Token',
        'hwid_user'        => 'HWID',
        'ref_name'         => 'Nombre Referencia',
        'created_users_title' => 'Mis Usuarios Creados',
        'expires'          => 'Expira',
        'type'             => 'Tipo',
        'admin_panel_title'=> '⚡ Panel Admin - Single VPS',
        'reseller_list'    => 'Lista de Revendedores'
    ],
    'en' => [
        'login_welcome'    => 'Welcome',
        'login_subtitle'   => 'Local management of SSH, Token and HWID users on your VPS',
        'login_btn'        => 'Sign In',
        'user'             => 'Username',
        'pass'             => 'Password',
        'err_credentials'  => 'Incorrect credentials',
        'logout'           => 'Logout',
        'resellers'        => 'Resellers',
        'created_accts'    => 'Created Accounts',
        'credits_shared'   => 'Distributed Credits',
        'view_online'      => '📡 View Online',
        'create_reseller'  => '👤 Create Reseller',
        'manage_credits'   => '💳 Manage Credits',
        'my_users'         => 'My created users',
        'create_account'   => 'Create Account',
        'status'           => 'Status',
        'action'           => 'Action',
        'connected_1'      => '🟢 1 Connected',
        'connected_n'      => '🔴 %d Connected',
        'no_online'        => '📡 No online users at this moment.',
        'close'            => 'Close',
        'back'             => '← Back',
        'reseller_title'   => 'Reseller Panel',
        'available_credits'=> '💰 Available credits',
        'initial_credits'  => 'Initial Credits',
        'cancel'           => 'Cancel',
        'save'             => 'Save Changes',
        'delete'           => 'Delete',
        'delete_confirm'   => '⚠️ Delete Reseller?',
        'delete_user_conf' => 'Delete user?',
        'ssh_normal'       => 'SSH Normal',
        'token_user'       => 'Token',
        'hwid_user'        => 'HWID',
        'ref_name'         => 'Reference Name',
        'created_users_title' => 'My Created Users',
        'expires'          => 'Expires',
        'type'             => 'Type',
        'admin_panel_title'=> '⚡ Admin Panel - Single VPS',
        'reseller_list'    => 'Resellers List'
    ],
    'fr' => [
        'login_welcome'    => 'Bienvenue',
        'login_subtitle'   => 'Gestion locale des utilisateurs SSH, Token et HWID sur votre VPS',
        'login_btn'        => 'Se Connecter',
        'user'             => 'Utilisateur',
        'pass'             => 'Mot de passe',
        'err_credentials'  => 'Identifiants incorrects',
        'logout'           => 'Quitter',
        'resellers'        => 'Revendeurs',
        'created_accts'    => 'Comptes Créés',
        'credits_shared'   => 'Crédits Distribués',
        'view_online'      => '📡 Voir En Ligne',
        'create_reseller'  => '👤 Créer Revendeur',
        'manage_credits'   => '💳 Gérer Crédits',
        'my_users'         => 'Mes utilisateurs créés',
        'create_account'   => 'Créer un Compte',
        'status'           => 'Statut',
        'action'           => 'Action',
        'connected_1'      => '🟢 1 Connecté',
        'connected_n'      => '🔴 %d Connectés',
        'no_online'        => '📡 Aucun utilisateur connecté pour le moment.',
        'close'            => 'Fermer',
        'back'             => '← Retour',
        'reseller_title'   => 'Panneau Revendeur',
        'available_credits'=> '💰 Crédits disponibles',
        'initial_credits'  => 'Crédits Initiaux',
        'cancel'           => 'Annuler',
        'save'             => 'Enregistrer',
        'delete'           => 'Supprimer',
        'delete_confirm'   => '⚠️ Supprimer le revendeur?',
        'delete_user_conf' => 'Supprimer l\'utilisateur?',
        'ssh_normal'       => 'SSH Normal',
        'token_user'       => 'Token',
        'hwid_user'        => 'HWID',
        'ref_name'         => 'Nom de Référence',
        'created_users_title' => 'Mes Utilisateurs Créés',
        'expires'          => 'Expire',
        'type'             => 'Type',
        'admin_panel_title'=> '⚡ Panneau Admin - Single VPS',
        'reseller_list'    => 'Liste des Revendeurs'
    ]
];

function __($key) {
    global $translations, $current_lang;
    return $translations[$current_lang][$key] ?? $translations['es'][$key] ?? $key;
}
?>
