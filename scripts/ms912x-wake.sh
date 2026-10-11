#!/usr/bin/env bash
# ============================================================================
# ms912x-wake.sh — "Danza de despertar" para adaptador MacroSilicon MS912x
#
# Fuerza renegociación HDMI: disable → @60 (handshake) → @50 (estable)
# y posiciona la ventana damage para mantener el chip activo.
#
# Se ejecuta en:
#   - KDE Autostart (login en Wayland)
#   - systemd sleep hook (resume de suspensión)
# ============================================================================

set -uo pipefail

LOG_TAG="ms912x-wake"
log() { logger -t "$LOG_TAG" "$*"; echo "[$(date '+%H:%M:%S')] $*"; }

# --- Esperar a que la sesión Wayland esté lista (solo en resume) ---
# En autostart KDE ya está lista; en systemd sleep hook puede no estarlo.
if [ "${MS912X_WAIT_WAYLAND:-0}" = "1" ]; then
    log "Esperando sesión Wayland (XDG_RUNTIME_DIR)..."
    for ((i=0; i<30; i++)); do
        [ -d "/run/user/$(id -u davidu14)" ] && break
        sleep 1
    done
    # Dar tiempo extra a KWin para inicializar
    sleep 3
fi

# --- 1. Detectar salida ms912x ---
OUT=$(kscreen-doctor -j 2>/dev/null | jq -r '.outputs[] | select(.name == "HDMI-A-2") | .name' 2>/dev/null | head -1)
[ -z "$OUT" ] && { log "ERROR: no se detecta HDMI-A-2"; exit 1; }
log "Salida detectada: $OUT"

# --- 2. DANZA COMPLETA: disable → @60 (handshake) → @50 (estable) ---
log "Paso 1/4: Deshabilitando salida (reset chip)..."
kscreen-doctor "output.$OUT.disable" >/dev/null 2>&1
sleep 1

log "Paso 2/4: Habilitando en modo @60 (handshake)..."
kscreen-doctor "output.$OUT.enable" "output.$OUT.mode.1" >/dev/null 2>&1
sleep 2  # crítico: dar tiempo al handshake HDMI

log "Paso 3/4: Cambiando a modo @50 (estable)..."
kscreen-doctor "output.$OUT.mode.4" >/dev/null 2>&1
sleep 1.5

# --- 3. Verificar que quedó en @50 ---
CURRENT=$(kscreen-doctor -j 2>/dev/null | jq -r --arg out "$OUT" '.outputs[] | select(.name == $out) | .currentModeId' 2>/dev/null)
log "Modo actual tras danza: $CURRENT (esperado: 4)"

# --- 4. Damage window: lanzar si no existe, posicionar siempre ---
SCRIPTS_DIR="$HOME/ms912x-kde-fix/scripts"
if [ -f "$SCRIPTS_DIR/position-damage.sh" ]; then
    log "Paso 4/4: Posicionando ventana damage..."
    "$SCRIPTS_DIR/position-damage.sh" --restart
else
    log "WARN: position-damage.sh no encontrado en $SCRIPTS_DIR"
fi

# --- 5. Verificación final: que KWin no lo vuelva a poner en @60 sin damage ---
# Esperar un poco y forzar @60+damage si KWin lo cambió (modo preferido con damage ES estable)
sleep 3
FINAL_MODE=$(kscreen-doctor -j 2>/dev/null | jq -r --arg out "$OUT" '.outputs[] | select(.name == $out) | .currentModeId' 2>/dev/null)
if [ "$FINAL_MODE" = "1" ]; then
    log "KWin reaplicó modo 1 (@60 preferred). Damage corriendo → estable. OK."
elif [ "$FINAL_MODE" = "4" ]; then
    log "Modo 4 (@50) mantenido. OK."
else
    log "WARN: modo inesperado $FINAL_MODE, forzando @60 + damage..."
    kscreen-doctor "output.$OUT.mode.1" >/dev/null 2>&1
    sleep 1
    "$SCRIPTS_DIR/position-damage.sh" --restart
fi

log "Despertar completado"