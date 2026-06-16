#!/bin/bash

source /etc/dealer-adm/dealer_api_functions.sh

ACCION="$1"

case "$ACCION" in

    agregar)
        crear_usuario_ssh_api "$2" "$3" "$4" "$5"
    ;;

    token)
        crear_usuario_token_api "$2" "$3" "$4"
    ;;

    hwid)
        crear_usuario_hwid_api "$2" "$3" "$4"
    ;;

    renovar)
        renovar_usuario_api "$2" "$3"
    ;;

    eliminar)
        eliminar_usuario_api "$2"
    ;;

    usuarios)
        listar_usuarios_api
    ;;

    online)
        usuarios_online_api
    ;;

esac
