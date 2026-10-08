#!/bin/bash
# usb-off.sh - Apaga el monitor USB HDMI (ms912x)
# Uso: usb-off.sh [--keep-module]

echo "🛑 Apagando monitor USB..."

# 1. Matar el daño
echo "  [1/4] Parando damage-kde.py..."
pkill -f damage-kde.py 2>/dev/null
sleep 1

# 2. Desactivar el monitor
echo "  [2/4] Desactivando HDMI-A-2..."
kscreen-doctor output.HDMI-A-2.disable >/dev/null 2>&1
sleep 1

# 3. Matar la ventana de daño si quedó
pkill -f position-damage.sh 2>/dev/null

# 4. Descargar módulo (opcional)
if [ "$1" != "--keep-module" ]; then
    echo "  [3/4] Descargando módulo ms912x..."
    sudo modprobe -r ms912x 2>/dev/null
    sleep 1
fi

echo "  [4/4] Verificando..."
if pgrep -f damage-kde.py >/dev/null; then
    echo "  ⚠️ Quedó algún proceso de daño, matando..."
    pkill -9 -f damage-kde.py
fi

echo ""
echo "✅ Monitor USB apagado."
echo "   Para encenderlo: usb-on          (1280x720@60)"
echo "   Para 1080p:      usb-on 1920     (1920x1080@50)"
