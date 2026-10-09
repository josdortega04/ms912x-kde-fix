#!/bin/bash
# Esperar a que la ventana "damage" exista
for i in {1..30}; do
    ID=$(kdotool search --name "^damage$" 2>/dev/null | head -1)
    if [ -n "$ID" ]; then
        break
    fi
    sleep 1
done

if [ -z "$ID" ]; then
    echo "No se encontró la ventana 'damage'"
    exit 1
fi

echo "Moviendo ventana $ID a la pantalla USB..."
kdotool windowsize "$ID" 8 8
kdotool windowmove "$ID" 3900 100
kdotool windowstate --add NO_BORDER --add SKIP_TASKBAR --add SKIP_PAGER --add ABOVE "$ID"
echo "Listo."
