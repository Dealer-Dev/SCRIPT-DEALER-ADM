#!/bin/bash

export DEALER_API_MODE=1

source /usr/local/bin/menu

ACCION="$1"

case "$ACCION" in

    agregar)

        # agregar user pass dias limite admin_id admin_nombre

        crear_usuario_ssh_api \
        "$2" \
        "$3" \
        "$4" \
        "$5" \
        "$6" \
        "$7"

    ;;

    token)

        # token nombre token dias admin_id admin_nombre

        crear_usuario_token_api \
        "$2" \
        "$3" \
        "$4" \
        "$5" \
        "$6"

    ;;

    hwid)

        # hwid nombre hwid dias admin_id admin_nombre

        crear_usuario_hwid_api \
        "$2" \
        "$3" \
        "$4" \
        "$5" \
        "$6"

    ;;

    renovar)

        # renovar usuario dias admin_id owner_id

        renovar_usuario_api \
        "$2" \
        "$3" \
        "$4" \
        "$5"

    ;;

    eliminar)

        # eliminar usuario admin_id owner_id

        eliminar_usuario_api \
        "$2" \
        "$3" \
        "$4"

    ;;

    usuarios)

        # usuarios admin_id owner_id

        listar_usuarios_api \
        "$2" \
        "$3"

    ;;

    online)

        # online admin_id owner_id

        usuarios_online_api \
        "$2" \
        "$3"

    ;;

    *)
        echo "ERROR"
    ;;

esac
