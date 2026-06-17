#!/usr/bin/env python3

import subprocess

from telegram import Update
from telegram.ext import (
    Application,
    CommandHandler,
    ContextTypes
)

# ==========================================
# CONFIG
# ==========================================

import os

BOT_TOKEN = os.getenv("BOT_TOKEN")

ADMIN_ID = int(os.getenv("ADMIN_ID", "0"))

API = "/etc/dealer-adm/bot/dealer_api.sh"

# ==========================================
# SEGURIDAD
# ==========================================

# ==========================================
# PERMISOS
# ==========================================

def es_owner(user_id):

    return user_id == ADMIN_ID


def es_admin(user_id):

    try:

        salida = subprocess.check_output(
            [
                API,
                "esadmin",
                str(user_id)
            ]
        ).decode().strip()

        return salida == "1"

    except:

        return False


def admin_activo(user_id):

    try:

        salida = subprocess.check_output(
            [
                API,
                "activo",
                str(user_id)
            ]
        ).decode().strip()

        return salida == "1"

    except:

        return False


def obtener_creditos(user_id):

    try:

        salida = subprocess.check_output(
            [
                API,
                "creditosdisponibles",
                str(user_id)
            ]
        ).decode().strip()

        return int(salida)

    except:

        return 0


def descontar_credito(user_id):

    subprocess.run(
        [
            API,
            "descontarcredito",
            str(user_id)
        ]
    )


def nombre_admin(user_id):

    try:

        salida = subprocess.check_output(
            [
                API,
                "nombreadmin",
                str(user_id)
            ]
        ).decode().strip()

        return salida

    except:

        return ""

def autorizado(update: Update):

    user_id = update.effective_user.id

    if es_owner(user_id):
        return True

    if es_admin(user_id) and admin_activo(user_id):
        return True

    return False

def es_owner_update(update: Update):

    return update.effective_user.id == ADMIN_ID

# ==========================================
# START
# ==========================================

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):

    if not autorizado(update):

    await update.message.reply_text(
        "No tienes permisos en el bot."
    )

    return

    if es_owner_update(update):

    mensaje = (
        "🤖 Dealer Adm Bot Online\n\n"
        "/agregar usuario password dias limite\n"
        "/token nombre token dias\n"
        "/hwid nombre hwid dias\n"
        "/renovar usuario dias\n"
        "/eliminar usuario\n"
        "/usuarios\n"
        "/online\n\n"
        "/creditos nombre id cantidad\n"
        "/admins\n"
        "/eliminaradmin id"
    )

else:

    mensaje = (
        "🤖 Dealer Revendedor\n\n"
        "/agregar usuario password dias limite\n"
        "/token nombre token dias\n"
        "/hwid nombre hwid dias\n"
        "/renovar usuario dias\n"
        "/eliminar usuario\n"
        "/usuarios\n"
        "/online"
    )
    await update.message.reply_text(mensaje)



# ==========================================
# AGREGAR SSH
# ==========================================

async def agregar(update: Update, context: ContextTypes.DEFAULT_TYPE):

    if not autorizado(update):
        return

    try:

        user = context.args[0]
        passwd = context.args[1]
        dias = context.args[2]
        limite = context.args[3]

        subprocess.run(
            [
                API,
                "agregar",
                user,
                passwd,
                dias,
                limite
            ],
            check=True
        )

        await update.message.reply_text(
            f"✅ Usuario SSH creado\n\n"
            f"Usuario: {user}\n"
            f"Password: {passwd}\n"
            f"Días: {dias}\n"
            f"Límite: {limite}"
        )

    except Exception:

        await update.message.reply_text(
            "Uso:\n"
            "/agregar usuario password dias limite"
        )

# ==========================================
# TOKEN
# ==========================================

async def token(update: Update, context: ContextTypes.DEFAULT_TYPE):

    if not autorizado(update):
        return

    try:

        nombre = context.args[0]
        tokenv = context.args[1]
        dias = context.args[2]

        subprocess.run(
            [
                API,
                "token",
                nombre,
                tokenv,
                dias
            ],
            check=True
        )

        await update.message.reply_text(
            f"✅ Usuario TOKEN creado\n\n"
            f"Nombre: {nombre}\n"
            f"Token: {tokenv}"
        )

    except Exception:

        await update.message.reply_text(
            "Uso:\n"
            "/token nombre token dias"
        )

# ==========================================
# HWID
# ==========================================

async def hwid(update: Update, context: ContextTypes.DEFAULT_TYPE):

    if not autorizado(update):
        return

    try:

        nombre = context.args[0]
        hwidv = context.args[1]
        dias = context.args[2]

        subprocess.run(
            [
                API,
                "hwid",
                nombre,
                hwidv,
                dias
            ],
            check=True
        )

        await update.message.reply_text(
            f"✅ Usuario HWID creado\n\n"
            f"Nombre: {nombre}\n"
            f"HWID: {hwidv}"
        )

    except Exception:

        await update.message.reply_text(
            "Uso:\n"
            "/hwid nombre hwid dias"
        )

# ==========================================
# RENOVAR
# ==========================================

async def renovar(update: Update, context: ContextTypes.DEFAULT_TYPE):

    if not autorizado(update):
        return

    try:

        usuario = context.args[0]
        dias = context.args[1]

        subprocess.run(
            [
                API,
                "renovar",
                usuario,
                dias
            ],
            check=True
        )

        await update.message.reply_text(
            f"✅ Usuario renovado\n\n"
            f"Usuario: {usuario}\n"
            f"Días: {dias}"
        )

    except Exception:

        await update.message.reply_text(
            "Uso:\n"
            "/renovar usuario dias"
        )

# ==========================================
# ELIMINAR
# ==========================================

async def eliminar(update: Update, context: ContextTypes.DEFAULT_TYPE):

    if not autorizado(update):
        return

    try:

        usuario = context.args[0]

        subprocess.run(
            [
                API,
                "eliminar",
                usuario
            ],
            check=True
        )

        await update.message.reply_text(
            f"❌ Usuario eliminado:\n{usuario}"
        )

    except Exception:

        await update.message.reply_text(
            "Uso:\n"
            "/eliminar usuario"
        )

# ==========================================
# USUARIOS
# ==========================================

async def usuarios(update: Update, context: ContextTypes.DEFAULT_TYPE):

    if not autorizado(update):
        return

    try:

        salida = subprocess.check_output(
            [API, "usuarios"]
        ).decode()

        await update.message.reply_text(
            salida if salida else "Sin usuarios"
        )

    except Exception as e:

        await update.message.reply_text(
            f"Error:\n{e}"
        )

# ==========================================
# ONLINE
# ==========================================

async def online(update: Update, context: ContextTypes.DEFAULT_TYPE):

    if not autorizado(update):
        return

    try:

        salida = subprocess.check_output(
            [API, "online"]
        ).decode()

        await update.message.reply_text(
            salida if salida else "Sin usuarios online"
        )

    except Exception as e:

        await update.message.reply_text(
            f"Error:\n{e}"
        )

# ==========================================
# MAIN
# ==========================================

def main():

    app = Application.builder().token(BOT_TOKEN).build()

    app.add_handler(CommandHandler("start", start))

    app.add_handler(CommandHandler("agregar", agregar))
    app.add_handler(CommandHandler("token", token))
    app.add_handler(CommandHandler("hwid", hwid))

    app.add_handler(CommandHandler("renovar", renovar))
    app.add_handler(CommandHandler("eliminar", eliminar))

    app.add_handler(CommandHandler("usuarios", usuarios))
    app.add_handler(CommandHandler("online", online))

    app.run_polling()

if __name__ == "__main__":
    main()
