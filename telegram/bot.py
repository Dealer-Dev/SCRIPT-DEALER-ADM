#!/usr/bin/env python3

import os
import subprocess
from telegram import Update
from telegram.ext import (
    Application,
    CommandHandler,
    ContextTypes
)

# ==========================================
# CONFIGURACIÓN
# ==========================================

BOT_TOKEN = os.getenv("BOT_TOKEN")
ADMIN_ID = int(os.getenv("ADMIN_ID", "0"))
API = "/etc/dealer-adm/bot/dealer_api.sh"

# ==========================================
# FUNCIONES DE SEGURIDAD Y PERMISOS
# ==========================================

def es_owner(user_id: int) -> bool:
    return user_id == ADMIN_ID

def es_admin(user_id: int) -> bool:
    try:
        salida = subprocess.check_output(
            [API, "esadmin", str(user_id)]
        ).decode().strip()
        return "1" in salida
    except Exception:
        return False

def admin_activo(user_id: int) -> bool:
    try:
        salida = subprocess.check_output(
            [API, "activo", str(user_id)]
        ).decode().strip()
        return "1" in salida
    except Exception:
        return False

def obtener_creditos(user_id: int) -> int:
    try:
        salida = subprocess.check_output(
            [API, "creditosdisponibles", str(user_id)]
        ).decode().strip()
        numeros = "".join(c for c in salida if c.isdigit())
        return int(numeros) if numeros else 0
    except Exception:
        return 0

def descontar_credito(user_id: int):
    try:
        subprocess.run(
            [API, "descontarcredito", str(user_id)],
            check=True
        )
    except Exception:
        pass

def nombre_admin(user_id: int) -> str:
    try:
        salida = subprocess.check_output(
            [API, "nombreadmin", str(user_id)]
        ).decode().strip()
        return salida
    except Exception:
        return ""

def autorizado(update: Update) -> bool:
    user_id = update.effective_user.id
    if es_owner(user_id):
        return True
    if es_admin(user_id):
        if admin_activo(user_id) or obtener_creditos(user_id) > 0:
            return True
    return False

# ==========================================
# COMMAND HANDLERS
# ==========================================

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not autorizado(update):
        await update.message.reply_text("❌ No tienes permisos para usar este bot.")
        return

    user_id = update.effective_user.id

    if es_owner(user_id):
        mensaje = (
            "🤖 *Dealer Adm Bot Online*\n\n"
            "📋 *Comandos de Gestión:*\n"
            "▫️ `/agregar` usuario password dias limite\n"
            "▫️ `/token` nombre token dias\n"
            "▫️ `/hwid` nombre hwid dias\n"
            "▫️ `/renovar` usuario dias\n"
            "▫️ `/eliminar` usuario\n"
            "▫️ `/usuarios` - Listar mis usuarios\n"
            "▫️ `/online` - Usuarios conectados\n\n"
            "👑 *Comandos de Administración:*\n"
            "▫️ `/creditos` nombre id cantidad\n"
            "▫️ `/admins` - Listar revendedores\n"
            "▫️ `/eliminaradmin` id"
        )
    else:
        creditos_actuales = obtener_creditos(user_id)
        mensaje = (
            "🤖 *Panel de Revendedor*\n\n"
            f"💳 *Créditos disponibles:* `{creditos_actuales}`\n\n"
            "📋 *Comandos Disponibles:*\n"
            "▫️ `/agregar` usuario password dias limite\n"
            "▫️ `/token` nombre token dias\n"
            "▫️ `/hwid` nombre hwid dias\n"
            "▫️ `/renovar` usuario dias\n"
            "▫️ `/eliminar` usuario\n"
            "▫️ `/usuarios` - Listar mis usuarios\n"
            "▫️ `/online` - Usuarios conectados"
        )

    await update.message.reply_text(mensaje, parse_mode="Markdown")

async def agregar(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not autorizado(update):
        await update.message.reply_text("❌ No tienes permisos.")
        return

    if len(context.args) < 4:
        await update.message.reply_text(
            "⚠️ *Uso correcto:*\n"
            "`/agregar usuario password dias limite`",
            parse_mode="Markdown"
        )
        return

    user = context.args[0]
    passwd = context.args[1]
    dias_raw = context.args[2]
    limite = context.args[3]

    if not dias_raw.isdigit() or not limite.isdigit():
        await update.message.reply_text("❌ Los días y el límite deben ser números enteros.")
        return

    user_id = update.effective_user.id
    admin_nombre = update.effective_user.first_name or "Admin"
    dias = dias_raw

    try:
        if not es_owner(user_id):
            dias = str(min(int(dias_raw), 30))
            creditos = obtener_creditos(user_id)

            if creditos <= 0:
                await update.message.reply_text("❌ No tienes créditos suficientes.")
                return

        subprocess.run(
            [API, "agregar", user, passwd, dias, limite, str(user_id), admin_nombre],
            check=True
        )

        mensaje = (
            f"✅ *Usuario SSH creado*\n\n"
            f"👤 *Usuario:* `{user}`\n"
            f"🔑 *Password:* `{passwd}`\n"
            f"📅 *Días:* {dias}\n"
            f"📱 *Límite:* {limite}"
        )

        if not es_owner(user_id):
            descontar_credito(user_id)
            restantes = obtener_creditos(user_id)
            mensaje += f"\n\n💳 *Créditos restantes:* {restantes}"

        await update.message.reply_text(mensaje, parse_mode="Markdown")

    except Exception as e:
        await update.message.reply_text(f"❌ Error al crear usuario: {e}")

async def token(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not autorizado(update):
        await update.message.reply_text("❌ No tienes permisos.")
        return

    if len(context.args) < 3:
        await update.message.reply_text(
            "⚠️ *Uso correcto:*\n"
            "`/token nombre token dias`",
            parse_mode="Markdown"
        )
        return

    nombre = context.args[0]
    tokenv = context.args[1]
    dias_raw = context.args[2]

    if not dias_raw.isdigit():
        await update.message.reply_text("❌ Los días deben ser un número entero.")
        return

    user_id = update.effective_user.id
    admin_nombre = update.effective_user.first_name or "Admin"
    dias = dias_raw

    try:
        if not es_owner(user_id):
            dias = str(min(int(dias_raw), 30))
            creditos = obtener_creditos(user_id)

            if creditos <= 0:
                await update.message.reply_text("❌ No tienes créditos suficientes.")
                return

        subprocess.run(
            [API, "token", nombre, tokenv, dias, str(user_id), admin_nombre],
            check=True
        )

        mensaje = (
            f"✅ *Usuario TOKEN creado*\n\n"
            f"👤 *Nombre:* `{nombre}`\n"
            f"🎟 *Token:* `{tokenv}`\n"
            f"📅 *Días:* {dias}"
        )

        if not es_owner(user_id):
            descontar_credito(user_id)
            restantes = obtener_creditos(user_id)
            mensaje += f"\n\n💳 *Créditos restantes:* {restantes}"

        await update.message.reply_text(mensaje, parse_mode="Markdown")

    except Exception as e:
        await update.message.reply_text(f"❌ Error al crear TOKEN: {e}")

async def hwid(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not autorizado(update):
        await update.message.reply_text("❌ No tienes permisos.")
        return

    if len(context.args) < 3:
        await update.message.reply_text(
            "⚠️ *Uso correcto:*\n"
            "`/hwid nombre hwid dias`",
            parse_mode="Markdown"
        )
        return

    nombre = context.args[0]
    hwidv = context.args[1]
    dias_raw = context.args[2]

    if not dias_raw.isdigit():
        await update.message.reply_text("❌ Los días deben ser un número entero.")
        return

    user_id = update.effective_user.id
    admin_nombre = update.effective_user.first_name or "Admin"
    dias = dias_raw

    try:
        if not es_owner(user_id):
            dias = str(min(int(dias_raw), 30))
            creditos = obtener_creditos(user_id)

            if creditos <= 0:
                await update.message.reply_text("❌ No tienes créditos suficientes.")
                return

        subprocess.run(
            [API, "hwid", nombre, hwidv, dias, str(user_id), admin_nombre],
            check=True
        )

        mensaje = (
            f"✅ *Usuario HWID creado*\n\n"
            f"👤 *Nombre:* `{nombre}`\n"
            f"🔒 *HWID:* `{hwidv}`\n"
            f"📅 *Días:* {dias}"
        )

        if not es_owner(user_id):
            descontar_credito(user_id)
            restantes = obtener_creditos(user_id)
            mensaje += f"\n\n💳 *Créditos restantes:* {restantes}"

        await update.message.reply_text(mensaje, parse_mode="Markdown")

    except Exception as e:
        await update.message.reply_text(f"❌ Error al crear HWID: {e}")

async def renovar(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not autorizado(update):
        await update.message.reply_text("❌ No tienes permisos.")
        return

    if len(context.args) < 2:
        await update.message.reply_text(
            "⚠️ *Uso correcto:*\n"
            "`/renovar usuario dias`",
            parse_mode="Markdown"
        )
        return

    usuario = context.args[0]
    dias_raw = context.args[1]

    if not dias_raw.isdigit():
        await update.message.reply_text("❌ Los días deben ser un número entero.")
        return

    user_id = update.effective_user.id
    dias = dias_raw

    try:
        if not es_owner(user_id):
            dias = str(min(int(dias_raw), 30))
            creditos = obtener_creditos(user_id)

            if creditos <= 0:
                await update.message.reply_text("❌ No tienes créditos suficientes.")
                return

        subprocess.run(
            [API, "renovar", usuario, dias, str(user_id), str(ADMIN_ID)],
            check=True
        )

        mensaje = (
            f"🔄 *Usuario renovado*\n\n"
            f"👤 *Usuario:* `{usuario}`\n"
            f"📅 *Días sumados:* {dias}"
        )

        if not es_owner(user_id):
            descontar_credito(user_id)
            restantes = obtener_creditos(user_id)
            mensaje += f"\n\n💳 *Créditos restantes:* {restantes}"

        await update.message.reply_text(mensaje, parse_mode="Markdown")

    except Exception as e:
        await update.message.reply_text(f"❌ Error al renovar usuario: {e}")

async def eliminar(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not autorizado(update):
        await update.message.reply_text("❌ No tienes permisos.")
        return

    if len(context.args) < 1:
        await update.message.reply_text(
            "⚠️ *Uso correcto:*\n"
            "`/eliminar usuario`",
            parse_mode="Markdown"
        )
        return

    usuario = context.args[0]
    user_id = update.effective_user.id

    try:
        subprocess.run(
            [API, "eliminar", usuario, str(user_id), str(ADMIN_ID)],
            check=True
        )
        await update.message.reply_text(
            f"🗑 *Usuario eliminado:* `{usuario}`",
            parse_mode="Markdown"
        )
    except Exception as e:
        await update.message.reply_text(f"❌ Error al eliminar usuario: {e}")

async def usuarios(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not autorizado(update):
        await update.message.reply_text("❌ No tienes permisos.")
        return

    try:
        user_id = update.effective_user.id
        salida = subprocess.check_output(
            [API, "usuarios", str(user_id), str(ADMIN_ID)]
        ).decode().strip()

        await update.message.reply_text(
            salida if salida else "📋 No tienes usuarios registrados."
        )
    except Exception as e:
        await update.message.reply_text(f"❌ Error al consultar usuarios: {e}")

async def online(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not autorizado(update):
        await update.message.reply_text("❌ No tienes permisos.")
        return

    try:
        user_id = update.effective_user.id
        salida = subprocess.check_output(
            [API, "online", str(user_id), str(ADMIN_ID)]
        ).decode().strip()

        await update.message.reply_text(
            salida if salida else "📡 No hay usuarios conectados en este momento."
        )
    except Exception as e:
        await update.message.reply_text(f"❌ Error al consultar online: {e}")

async def creditos(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not es_owner(update.effective_user.id):
        await update.message.reply_text("❌ Solo el dueño del bot puede usar este comando.")
        return

    if len(context.args) < 3:
        await update.message.reply_text(
            "⚠️ *Uso correcto:*\n"
            "`/creditos nombre id cantidad`",
            parse_mode="Markdown"
        )
        return

    nombre = context.args[0]
    admin_id = context.args[1]
    cantidad = context.args[2]

    try:
        subprocess.run(
            [API, "creditos", nombre, admin_id, cantidad],
            check=True
        )

        await update.message.reply_text(
            f"✅ *Créditos agregados*\n\n"
            f"👤 *Nombre:* {nombre}\n"
            f"🆔 *ID:* `{admin_id}`\n"
            f"💳 *Créditos:* {cantidad}",
            parse_mode="Markdown"
        )

        try:
            msg_notificacion = (
                f"🎉 *¡Felicidades {nombre}!*\n\n"
                f"Has sido autorizado como revendedor en el bot.\n"
                f"💳 *Créditos asignados:* `{cantidad}`\n\n"
                f"Escribe `/start` para desplegar tu menú de opciones."
            )
            await context.bot.send_message(
                chat_id=int(admin_id),
                text=msg_notificacion,
                parse_mode="Markdown"
            )
        except Exception:
            await update.message.reply_text(
                "⚠️ *Nota:* Los créditos se asignaron correctamente, pero no se pudo enviar la notificación por privado. "
                "Asegúrate de que el revendedor le haya dado `/start` al bot primero."
            )

    except Exception as e:
        await update.message.reply_text(f"❌ Error al agregar créditos: {e}")

async def admins(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not es_owner(update.effective_user.id):
        await update.message.reply_text("❌ Solo el dueño del bot puede usar este comando.")
        return

    try:
        salida = subprocess.check_output([API, "admins"]).decode().strip()
        await update.message.reply_text(
            salida if salida else "📋 No existen revendedores registrados."
        )
    except Exception as e:
        await update.message.reply_text(f"❌ Error al listar administradores: {e}")

async def eliminaradmin(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not es_owner(update.effective_user.id):
        await update.message.reply_text("❌ Solo el dueño del bot puede usar este comando.")
        return

    if len(context.args) < 1:
        await update.message.reply_text(
            "⚠️ *Uso correcto:*\n"
            "`/eliminaradmin id`",
            parse_mode="Markdown"
        )
        return

    admin_id = context.args[0]

    try:
        subprocess.run([API, "eliminaradmin", admin_id], check=True)
        await update.message.reply_text(
            f"🗑 *Revendedor eliminado:* `{admin_id}`",
            parse_mode="Markdown"
        )
    except Exception as e:
        await update.message.reply_text(f"❌ Error al eliminar revendedor: {e}")

# ==========================================
# INICIO
# ==========================================

def main():
    if not BOT_TOKEN:
        print("ERROR: BOT_TOKEN no definido en variables de entorno.")
        return

    app = Application.builder().token(BOT_TOKEN).build()

    app.add_handler(CommandHandler("start", start))
    app.add_handler(CommandHandler("agregar", agregar))
    app.add_handler(CommandHandler("token", token))
    app.add_handler(CommandHandler("hwid", hwid))
    app.add_handler(CommandHandler("renovar", renovar))
    app.add_handler(CommandHandler("eliminar", eliminar))
    app.add_handler(CommandHandler("usuarios", usuarios))
    app.add_handler(CommandHandler("online", online))
    app.add_handler(CommandHandler("creditos", creditos))
    app.add_handler(CommandHandler("admins", admins))
    app.add_handler(CommandHandler("eliminaradmin", eliminaradmin))

    app.run_polling()

if __name__ == "__main__":
    main()
