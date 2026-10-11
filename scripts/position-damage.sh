#!/usr/bin/env bash
# ============================================================================
# position-damage.sh — Coloca la ventana "damage" sobre la pantalla ms912x
# para forzar redibujado continuo en el chip.
#
# Autodetecta:
#   - El nombre de la salida ms912x (via ms912x-lib.sh)
#   - La posición de esa salida en el escritorio virtual
#
# Uso:
#   position-damage.sh            → reposiciona la ventana existente
#   position-damage.sh --restart  → mata y relanza damage-kde.py + posiciona
# ============================================================================

set -uo pipefail

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

RESTART=0
[ "${1:-}" = "--restart" ] && RESTART=1

# --- 1. Si --restart, matar y relanzar damage-kde.py ---
if [ "$RESTART" -eq 1 ]; then
    pkill -f damage-kde.py 2>/dev/null || true
    sleep 1
    if [ -f "$HOME/.local/bin/damage-kde.py" ]; then
        nohup python3 "$HOME/.local/bin/damage-kde.py" >/tmp/damage.log 2>&1 &
        sleep 2
    fi
fi

# --- 2. Detectar salida y su posición ---
OUT=$(ms912x_detect_output 2>/dev/null) || {
    echo "ERROR: no se detecta salida ms912x"
    exit 1
}

# Posición y tamaño de la salida ms912x (leído de kscreen-doctor)
read -r OUT_X OUT_Y OUT_W OUT_H < <(
    kscreen-doctor -j 2>/dev/null | jq -r --arg out "$OUT" '
        .outputs[] | select(.name == $out)
        | "\(.pos.x) \(.pos.y) \(.size.width) \(.size.height)"
    '
)

if [ -z "$OUT_W" ] || [ "$OUT_W" = "null" ]; then
    echo "ERROR: no se pudo leer geometría de $OUT"
    exit 1
fi

# Coordenada dentro de la pantalla ms912x, esquina superior izquierda
TARGET_X=$(( OUT_X + 20 ))
TARGET_Y=$(( OUT_Y + 20 ))

echo "Salida $OUT: ${OUT_W}x${OUT_H} @ ${OUT_X},${OUT_Y}"
echo "Moviendo ventana damage a ${TARGET_X},${TARGET_Y}"

# --- 3. Esperar a que exista la ventana "damage" ---
ID=""
for ((i=0; i<20; i++)); do
    ID=$(kdotool search --name "^damage$" 2>/dev/null | head -1)
    [ -n "$ID" ] && break
    sleep 1
done

if [ -z "$ID" ]; then
    echo "ERROR: no se encontró ventana 'damage' tras 20s"
    exit 1
fi

# --- 4. Mover, redimensionar y marcar la ventana ---
kdotool windowsize  "$ID" 16 16                >/dev/null 2>&1 || true
kdotool windowmove  "$ID" "$TARGET_X" "$TARGET_Y" >/dev/null 2>&1 || true
kdotool windowstate --add NO_BORDER --add SKIP_TASKBAR --add SKIP_PAGER --add ABOVE "$ID" >/dev/null 2>&1 || true

# --- 5. Verificar que quedó dentro de la pantalla USB ---
NEW_POS=$(kdotool getwindowgeometry "$ID" 2>/dev/null | grep Position | awk '{print $2}')
echo "Ventana posicionada en: $NEW_POS"
echo "Listo."
