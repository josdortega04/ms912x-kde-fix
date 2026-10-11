#!/usr/bin/env bash
# ============================================================================
# ms912x-activate.sh — Activa el monitor USB-HDMI basado en ms912x.
#
# Autodetecta todo: card, salida, modo preferido y posición.
# Es idempotente: si ya está bien configurado, no hace nada.
#
# Uso:
#   ms912x-activate.sh                    → modo preferido del monitor
#   ms912x-activate.sh --mode best        → mejor modo disponible (mayor área)
#   ms912x-activate.sh --mode 1920x1080@60
#   ms912x-activate.sh --mode 720         → atajo: 1280x720@60
#   ms912x-activate.sh --mode 1080        → atajo: 1920x1080@60
#   ms912x-activate.sh --position 1920,0
#   ms912x-activate.sh --damage           → además arranca damage-kde.py
#   ms912x-activate.sh --wait             → espera hasta 30s a que aparezca
#   ms912x-activate.sh --quiet            → sin salida (para systemd)
# ============================================================================

set -uo pipefail

# --- Localizar la librería ---
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SELF_DIR/ms912x-lib.sh" ]; then
    LIB="$SELF_DIR/ms912x-lib.sh"
elif [ -f "$HOME/.local/bin/ms912x-lib.sh" ]; then
    LIB="$HOME/.local/bin/ms912x-lib.sh"
else
    echo "ERROR: no se encuentra ms912x-lib.sh" >&2
    exit 1
fi
# shellcheck disable=SC1090
source "$LIB"

# --- Argumentos ---
MODE_ARG=""
POS_ARG=""
DO_DAMAGE=0
DO_WAIT=0
QUIET=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --mode)     MODE_ARG="$2"; shift 2 ;;
        --position) POS_ARG="$2"; shift 2 ;;
        --damage)   DO_DAMAGE=1; shift ;;
        --wait)     DO_WAIT=1; shift ;;
        --quiet)    QUIET=1; shift ;;
        -h|--help)  grep '^#' "$0" | sed 's/^# \?//'; exit 0 ;;
        *) echo "Opción desconocida: $1" >&2; exit 1 ;;
    esac
done

log() {
    [ "$QUIET" -eq 1 ] && return 0
    ms912x_log "$@"
}

# --- 1. Cargar módulo si hace falta ---
if ! lsmod | grep -q "^ms912x"; then
    log "Cargando módulo ms912x..."
    ms912x_load_module || { log "ERROR: no se pudo cargar ms912x"; exit 1; }
fi

# --- 2. Esperar a que aparezca el card/salida ---
WAIT_MAX=15
[ "$DO_WAIT" -eq 1 ] && WAIT_MAX=30

OUT=""
for ((i=0; i<WAIT_MAX; i++)); do
    OUT=$(ms912x_detect_output 2>/dev/null) && break
    sleep 1
done

if [ -z "$OUT" ]; then
    log "ERROR: no se detectó salida ms912x tras ${WAIT_MAX}s"
    exit 1
fi

log "Salida detectada: $OUT"

# --- 3. Resolver modo ---
resolve_mode() {
    local arg="$1" out="$2"
    case "$arg" in
        "")           ms912x_get_preferred_mode "$out" ;;
        preferred)    ms912x_get_preferred_mode "$out" ;;
        best)         ms912x_get_best_mode "$out" ;;
        720)          echo "1280x720@50" ;;
        1080)         echo "1920x1080@50" ;;
        *)            echo "$arg" ;;
    esac
}

MODE=$(resolve_mode "$MODE_ARG" "$OUT")
if [ -z "$MODE" ]; then
    MODE=$(ms912x_get_best_mode "$OUT")
fi

if [ -z "$MODE" ]; then
    log "ERROR: no se pudo determinar el modo para $OUT"
    exit 1
fi

# --- 4. Resolver posición ---
POS="$POS_ARG"
[ -z "$POS" ] && POS=$(ms912x_get_desired_position "$OUT")

log "Aplicando: $OUT → modo=$MODE  pos=$POS"

# --- 5. Aplicar (idempotente) ---
CURRENT=$(ms912x_get_state "$OUT")
DESIRED="enabled ${MODE} ${POS}"

if [ "$CURRENT" = "$DESIRED" ]; then
    log "Ya está en el estado deseado, no se toca"
else
    ms912x_apply "$OUT" "$MODE" "$POS" || { log "ERROR: falló kscreen-doctor"; exit 1; }
    log "Configuración aplicada"
fi

# --- 6. Damage opcional ---
if [ "$DO_DAMAGE" -eq 1 ]; then
    if [ -f "$HOME/.local/bin/damage-kde.py" ]; then
        if ! pgrep -f damage-kde.py >/dev/null 2>&1; then
            log "Arrancando damage-kde.py"
            nohup python3 "$HOME/.local/bin/damage-kde.py" >/tmp/damage.log 2>&1 &
            sleep 2
        else
            log "damage-kde.py ya está corriendo"
        fi
        if [ -x "$HOME/.local/bin/position-damage.sh" ]; then
            log "Reposicionando ventana de daño"
            "$HOME/.local/bin/position-damage.sh" >/dev/null 2>&1 || \
            "$SELF_DIR/position-damage.sh"    >/dev/null 2>&1 || true
        fi
    else
        log "damage-kde.py no encontrado, se omite"
    fi
fi

log "Listo."
exit 0
