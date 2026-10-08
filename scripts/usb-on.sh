#!/bin/bash
# usb-on.sh - Enciende el monitor USB HDMI (ms912x) bajo demanda
# Uso: usb-on.sh [1280|1920]

RES="${1:-1280}"

case "$RES" in
    1280) MODE="1280x720@60" ;;
    1920) MODE="1920x1080@50" ;;
    *)    MODE="1280x720@60" ;;
esac

echo "🎬 Encendiendo monitor USB ($MODE)..."

# 1. Cargar módulo si no está
if ! lsmod | grep -q ms912x; then
    echo "  [1/5] Cargando módulo ms912x..."
    sudo modprobe ms912x
    sleep 3
else
    echo "  [1/5] Módulo ms912x ya cargado"
fi

# 2. Esperar a que aparezca card0-HDMI-A-2
echo "  [2/5] Esperando card0-HDMI-A-2..."
for i in {1..15}; do
    if [ -e /sys/class/drm/card0-HDMI-A-2 ]; then
        break
    fi
    sleep 1
done

if [ ! -e /sys/class/drm/card0-HDMI-A-2 ]; then
    echo "❌ ERROR: card0-HDMI-A-2 no apareció"
    exit 1
fi
echo "       ✅ Detectado"

# 3. Activar el monitor
echo "  [3/5] Activando HDMI-A-2..."
kscreen-doctor output.HDMI-A-2.enable >/dev/null 2>&1
sleep 1
kscreen-doctor output.HDMI-A-2.mode.$MODE >/dev/null 2>&1
sleep 1
kscreen-doctor output.HDMI-A-2.position.3840,0 >/dev/null 2>&1
sleep 1

# 4. Arrancar el daño en background (por si no estaba)
echo "  [4/5] Arrancando damage-kde.py..."
pkill -f damage-kde.py 2>/dev/null
nohup python3 ~/.local/bin/damage-kde.py > /dev/null 2>&1 &
sleep 3

# 5. Posicionar la ventana de daño en la pantalla USB
echo "  [5/5] Posicionando ventana de daño..."
~/.local/bin/position-damage.sh > /dev/null 2>&1

echo ""
echo "✅ Monitor USB encendido ($MODE)"
echo "   Para apagarlo: usb-off"
