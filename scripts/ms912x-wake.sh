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

log "Despertar completado"