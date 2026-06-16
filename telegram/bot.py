#!/usr/bin/env python3

import subprocess

from telegram.ext import (
    Updater,
    CommandHandler
)

# ==========================================
# CONFIG
# ==========================================

BOT_TOKEN = "TOKEN_AQUI"

ADMIN_ID = 123456789

API = "/etc/dealer-adm/bot/dealer_api.sh"

# ==========================================
# SEGURIDAD
# ==========================================

def autorizado(update):

    return update.effective_user.id == ADMIN_ID

# ==========================================
# START
# ==========================================

def start(update, context):

    if not autorizado(update):
        return

    update.message.reply_text(
        "🤖 Dealer Adm Bot Online\n\n"
        "/agregar user pass dias limite\n"
        "/token nombre token dias\n"
        "/hwid nombre hwid dias\n"
        "/renovar usuario dias\n"
        "/eliminar usuario\n"
        "/usuarios\n"
        "/online"
    )

# ==========================================
# AGREGAR SSH
# ==========================================

def agregar(update, context):

    if not autorizado(update):
        return

    try:

        user = context.args[0]
        passwd = context.args[1]
        dias = context.args[2]
        limite = context.args[3]

        subprocess.run([
            API,
            "agregar",
            user,
            passwd,
            dias,
            limite
        ])

        update.message.reply_text(
            f"Usuario SSH creado\n\n"
            f"Usuario: {user}\n"
            f"Password: {passwd}\n"
            f"Dias: {dias}\n"
            f"Limite: {limite}"
        )

    except:

        update.message.reply_text(
            "Uso:\n"
            "/agregar usuario password dias limite"
        )

# ==========================================
# TOKEN
# ==========================================

def token(update, context):

    if not autorizado(update):
        return

    try:

        nombre = context.args[0]
        tokenv = context.args[1]
        dias = context.args[2]

        subprocess.run([
            API,
            "token",
            nombre,
            tokenv,
            dias
        ])

        update.message.reply_text(
            f"Usuario TOKEN creado\n\n"
            f"Nombre: {nombre}\n"
            f"Token: {tokenv}"
        )

    except:

        update.message.reply_text(
            "Uso:\n"
            "/token nombre token dias"
        )

# ==========================================
# HWID
# ==========================================

def hwid(update, context):

    if not autorizado(update):
        return

    try:

        nombre = context.args[0]
        hwidv = context.args[1]
        dias = context.args[2]

        subprocess.run([
            API,
            "hwid",
            nombre,
            hwidv,
            dias
        ])

        update.message.reply_text(
            f"Usuario HWID creado\n\n"
            f"Nombre: {nombre}\n"
            f"HWID: {hwidv}"
        )

    except:

        update.message.reply_text(
            "Uso:\n"
            "/hwid nombre hwid dias"
        )

# ==========================================
# RENOVAR
# ==========================================

def renovar(update, context):

    if not autorizado(update):
        return

    try:

        usuario = context.args[0]
        dias = context.args[1]

        subprocess.run([
            API,
            "renovar",
            usuario,
            dias
        ])

        update.message.reply_text(
            f"Renovado\n\n"
            f"Usuario: {usuario}\n"
            f"Dias: {dias}"
        )

    except:

        update.message.reply_text(
            "Uso:\n"
            "/renovar usuario dias"
        )

# ==========================================
# ELIMINAR
# ==========================================

def eliminar(update, context):

    if not autorizado(update):
        return

    try:

        usuario = context.args[0]

        subprocess.run([
            API,
            "eliminar",
            usuario
        ])

        update.message.reply_text(
            f"Usuario eliminado:\n{usuario}"
        )

    except:

        update.message.reply_text(
            "Uso:\n"
            "/eliminar usuario"
        )

# ==========================================
# USUARIOS
# ==========================================

def usuarios(update, context):

    if not autorizado(update):
        return

    salida = subprocess.check_output(
        [API, "usuarios"]
    ).decode()

    update.message.reply_text(
        salida if salida else "Sin usuarios"
    )

# ==========================================
# ONLINE
# ==========================================

def online(update, context):

    if not autorizado(update):
        return

    salida = subprocess.check_output(
        [API, "online"]
    ).decode()

    update.message.reply_text(
        salida if salida else "Sin usuarios online"
    )

# ==========================================
# MAIN
# ==========================================

def main():

    updater = Updater(BOT_TOKEN)

    dp = updater.dispatcher

    dp.add_handler(CommandHandler("start", start))

    dp.add_handler(CommandHandler("agregar", agregar))
    dp.add_handler(CommandHandler("token", token))
    dp.add_handler(CommandHandler("hwid", hwid))

    dp.add_handler(CommandHandler("renovar", renovar))
    dp.add_handler(CommandHandler("eliminar", eliminar))

    dp.add_handler(CommandHandler("usuarios", usuarios))
    dp.add_handler(CommandHandler("online", online))

    updater.start_polling()
    updater.idle()

if __name__ == "__main__":
    main()
