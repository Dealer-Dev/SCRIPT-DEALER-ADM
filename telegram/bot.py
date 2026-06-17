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
app.add_handler(CommandHandler("creditos", creditos))
app.add_handler(CommandHandler("admins", admins))
app.add_handler(CommandHandler("eliminaradmin", eliminaradmin))


# ==========================================
# AGREGAR SSH
# ==========================================
async def agregar(update: Update, context: ContextTypes.DEFAULT_TYPE):


if not autorizado(update):

    await update.message.reply_text(
        "No tienes permisos en el bot."
    )

    return

try:

    user = context.args[0]
    passwd = context.args[1]
    dias = context.args[2]
    limite = context.args[3]

    user_id = update.effective_user.id
    admin_nombre = update.effective_user.first_name

    if not es_owner(user_id):

        dias = str(min(int(dias), 30))

        creditos = obtener_creditos(user_id)

        if creditos <= 0:

            await update.message.reply_text(
                "❌ No tienes créditos disponibles."
            )

            return

    subprocess.run(
        [
            API,
            "agregar",
            user,
            passwd,
            dias,
            limite,
            str(user_id),
            admin_nombre
        ],
        check=True
    )

    if not es_owner(user_id):

        descontar_credito(user_id)

        creditos_restantes = obtener_creditos(user_id)

    mensaje = (
        f"✅ Usuario SSH creado\n\n"
        f"Usuario: {user}\n"
        f"Password: {passwd}\n"
        f"Días: {dias}\n"
        f"Límite: {limite}"
    )

    if not es_owner(user_id):

        mensaje += (
            f"\n\n💳 Créditos restantes: "
            f"{creditos_restantes}"
        )

    await update.message.reply_text(mensaje)

except Exception as e:

    await update.message.reply_text(
        f"Uso:\n"
        f"/agregar usuario password dias limite\n\n"
        f"Error: {e}"
    )


# ==========================================
# TOKEN
# ==========================================

async def token(update: Update, context: ContextTypes.DEFAULT_TYPE):


if not autorizado(update):

    await update.message.reply_text(
        "No tienes permisos en el bot."
    )

    return

try:

    nombre = context.args[0]
    tokenv = context.args[1]
    dias = context.args[2]

    user_id = update.effective_user.id
    admin_nombre = update.effective_user.first_name

    if not es_owner(user_id):

        dias = str(min(int(dias), 30))

        creditos = obtener_creditos(user_id)

        if creditos <= 0:

            await update.message.reply_text(
                "❌ No tienes créditos disponibles."
            )

            return

    subprocess.run(
        [
            API,
            "token",
            nombre,
            tokenv,
            dias,
            str(user_id),
            admin_nombre
        ],
        check=True
    )

    if not es_owner(user_id):

        descontar_credito(user_id)

        creditos_restantes = obtener_creditos(user_id)

    mensaje = (
        f"✅ Usuario TOKEN creado\n\n"
        f"Nombre: {nombre}\n"
        f"Token: {tokenv}\n"
        f"Días: {dias}"
    )

    if not es_owner(user_id):

        mensaje += (
            f"\n\n💳 Créditos restantes: "
            f"{creditos_restantes}"
        )

    await update.message.reply_text(mensaje)

except Exception as e:

    await update.message.reply_text(
        f"Uso:\n"
        f"/token nombre token dias\n\n"
        f"Error: {e}"
    )



# ==========================================
# HWID
# ==========================================
async def hwid(update: Update, context: ContextTypes.DEFAULT_TYPE):

    if not autorizado(update):

        await update.message.reply_text(
            "No tienes permisos en el bot."
        )

        return

    try:

        nombre = context.args[0]
        hwidv = context.args[1]
        dias = context.args[2]

        user_id = update.effective_user.id
        admin_nombre = update.effective_user.first_name

        if not es_owner(user_id):

            dias = str(min(int(dias), 30))

            creditos = obtener_creditos(user_id)

            if creditos <= 0:

                await update.message.reply_text(
                    "❌ No tienes créditos disponibles."
                )

                return

        subprocess.run(
            [
                API,
                "hwid",
                nombre,
                hwidv,
                dias,
                str(user_id),
                admin_nombre
            ],
            check=True
        )

        if not es_owner(user_id):

            descontar_credito(user_id)

            creditos_restantes = obtener_creditos(user_id)

        mensaje = (
            f"✅ Usuario HWID creado\n\n"
            f"Nombre: {nombre}\n"
            f"HWID: {hwidv}\n"
            f"Días: {dias}"
        )

        if not es_owner(user_id):

            mensaje += (
                f"\n\n💳 Créditos restantes: "
                f"{creditos_restantes}"
            )

        await update.message.reply_text(mensaje)

    except Exception as e:

        await update.message.reply_text(
            f"Uso:\n"
            f"/hwid nombre hwid dias\n\n"
            f"Error: {e}"
        )
# ==========================================
# RENOVAR
# ==========================================

async def renovar(update: Update, context: ContextTypes.DEFAULT_TYPE):

    if not autorizado(update):

        await update.message.reply_text(
            "No tienes permisos en el bot."
        )

        return

    try:

        usuario = context.args[0]
        dias = context.args[1]

        user_id = update.effective_user.id

        if not es_owner(user_id):

            dias = str(min(int(dias), 30))

            creditos = obtener_creditos(user_id)

            if creditos <= 0:

                await update.message.reply_text(
                    "❌ No tienes créditos disponibles."
                )

                return

        subprocess.run(
            [
                API,
                "renovar",
                usuario,
                dias,
                str(user_id),
                str(ADMIN_ID)
            ],
            check=True
        )

        if not es_owner(user_id):

            descontar_credito(user_id)

            creditos_restantes = obtener_creditos(user_id)

        mensaje = (
            f"✅ Usuario renovado\n\n"
            f"Usuario: {usuario}\n"
            f"Días: {dias}"
        )

        if not es_owner(user_id):

            mensaje += (
                f"\n\n💳 Créditos restantes: "
                f"{creditos_restantes}"
            )

        await update.message.reply_text(mensaje)

    except Exception as e:

        await update.message.reply_text(
            f"Uso:\n"
            f"/renovar usuario dias\n\n"
            f"Error: {e}"
        )

# ==========================================
# ELIMINAR
# ==========================================

async def eliminar(update: Update, context: ContextTypes.DEFAULT_TYPE):

    if not autorizado(update):

        await update.message.reply_text(
            "No tienes permisos en el bot."
        )

        return

    try:

        usuario = context.args[0]

        user_id = update.effective_user.id

        subprocess.run(
            [
                API,
                "eliminar",
                usuario,
                str(user_id),
                str(ADMIN_ID)
            ],
            check=True
        )

        await update.message.reply_text(
            f"❌ Usuario eliminado:\n{usuario}"
        )

    except Exception as e:

        await update.message.reply_text(
            f"Uso:\n"
            f"/eliminar usuario\n\n"
            f"Error: {e}"
        )

# ==========================================
# USUARIOS
# ==========================================

async def usuarios(update: Update, context: ContextTypes.DEFAULT_TYPE):

    if not autorizado(update):

        await update.message.reply_text(
            "No tienes permisos en el bot."
        )

        return

    try:

        user_id = update.effective_user.id

        salida = subprocess.check_output(
            [
                API,
                "usuarios",
                str(user_id),
                str(ADMIN_ID)
            ]
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

        await update.message.reply_text(
            "No tienes permisos en el bot."
        )

        return

    try:

        user_id = update.effective_user.id

        salida = subprocess.check_output(
            [
                API,
                "online",
                str(user_id),
                str(ADMIN_ID)
            ]
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
