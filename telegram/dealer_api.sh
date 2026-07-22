#!/bin/bash

export DEALER_API_MODE=1

# Silenciar salida gráfica de la carga de scripts
source /usr/local/bin/menu >/dev/null 2>&1

ACCION="$1"

case "$ACCION" in
    agregar)
        crear_usuario_ssh_api "$2" "$3" "$4" "$5" "$6" "$7"
    ;;
    token)
        crear_usuario_token_api "$2" "$3" "$4" "$5" "$6"
    ;;
    hwid)
        crear_usuario_hwid_api "$2" "$3" "$4" "$5" "$6"
    ;;
    renovar)
        renovar_usuario_api "$2" "$3" "$4" "$5"
    ;;
    eliminar)
        eliminar_usuario_api "$2" "$3" "$4"
    ;;
    usuarios)
        listar_usuarios_api "$2" "$3"
    ;;
    online)
        usuarios_online_api "$2" "$3"
    ;;
    creditos)
        crear_admin_api "$2" "$3" "$4"
    ;;
    admins)
        listar_admins_api
    ;;
    eliminaradmin)
        eliminar_admin_api "$2"
    ;;
    activo)
        admin_activo_api "$2"
    ;;
    creditosdisponibles)
        obtener_creditos_api "$2"
    ;;
    descontarcredito)
        descontar_credito_api "$2"
    ;;
    esadmin)
        es_admin_api "$2"
    ;;
    nombreadmin)
        obtener_nombre_admin_api "$2"
    ;;
    *)
        echo "ERROR"
    ;;
esac
