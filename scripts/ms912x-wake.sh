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

# --- 4. Damage window: lanzar y posicionar SEMPRE (crítico para estabilidad) ---
# Esto debe suceder DESPUÉS de los cambios de modo para evitar que KWin
# revoque el modo antes de que el damage window tome efecto.
SCRIPTS_DIR="$HOME/ms912x-kde-fix/scripts"
if [ -f "$SCRIPTS_DIR/position-damage.sh" ]; then
    log "Paso 4/5: Posicionando ventana damage (CRÍTICO para estabilidad del chip)..."
    "$SCRIPTS_DIR/position-damage.sh" --restart
else
    log "WARN: position-damage.sh no encontrado en $SCRIPTS_DIR - chip puede inestabilizarse"
fi

# --- 5. Loop de verificación continua: evitar que KWin revoque el modo ---
# KWin tiende a reapply config ~3s después de nuestro script. Este loop
# verifica cada 5s durante 45s y fuerza @50+damage si KWin cambia el modo.
LOG_INTERVAL=5
MAX_ITER=9  # 9 × 5s = 45s de protección
for ((iter=1; iter<=MAX_ITER; iter++)); do
    sleep $LOG_INTERVAL
    CURRENT=$(kscreen-doctor -j 2>/dev/null | jq -r --arg out "$OUT" '.outputs[] | select(.name == $out) | .currentModeId' 2>/dev/null)
    if [ "$CURRENT" = "1" ]; then
        # KWin volvió a @60 preferred - verificar si damage window está activo
        DAMAGE_RUNNING=$(pgrep -f "damage-kde.py" 2>/dev/null || true)
        if [ -n "$DAMAGE_RUNNING" ]; then
            log "Iteración $iter: KWin cambió a @60 pero damage está running → estable. OK."
        else
            log "Iteración $iter: KWin cambió a @60 SIN damage → FORZANDO @50 + damage..."
            kscreen-doctor "output.$OUT.mode.4" >/dev/null 2>&1
            sleep 1
            "$SCRIPTS_DIR/position-damage.sh" --restart
        fi
    elif [ "$CURRENT" = "4" ]; then
        log "Iteración $iter: Modo 4 (@50) mantenido. OK."
    else
        log "Iteración $iter: Modo inesperado $CURRENT, forzando @50 + damage..."
        kscreen-doctor "output.$OUT.mode.4" >/dev/null 2>&1
        sleep 1
        "$SCRIPTS_DIR/position-damage.sh" --restart
    fi
done
log "Loop de verificación completado - modo MS912x asegurado"

log "Despertar completado"