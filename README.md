# ms912x USB HDMI Adapter - KDE Plasma Fix

Solución funcional para adaptador USB-HDMI MSI/MacroSilicon MS912x
(345f:9133) en KDE Plasma 6 Wayland.

## Hardware

- Adaptador: Reborn USB to HDMI Adapter (MSI/MacroSilicon)
- USB ID: 345f:9133
- Driver: ms912x (DKMS desde AUR)
- Sistema: Arch Linux + KDE Plasma 6 Wayland
- GPU: Intel (iGPU del laptop)

## Estado: FUNCIONANDO

- Monitor USB activo en KDE Wayland
- Imagen estable con daño continuo
- PC fluido (load menor a 1.0)
- Sin servicios systemd problemáticos

## Cómo funciona

El driver ms912x es síncrono y no implementa atomic modesetting,
GBM, DMA-BUF ni gamma. Esto causaba:

1. Damage tracking roto: la imagen se congelaba sin interacción.
2. Bucle de KWin: KWin intentaba componer con GPU y fallaba en bucle.

### Solución

1. Cargar módulo manualmente (sin udev, sin systemd).
2. Activar monitor con kscreen-doctor (no automático).
3. Ventana de daño en la pantalla USB que fuerza redibujado a 2 fps.

## Instalación

### 1. Driver DKMS

    yay -S evdi-dkms ms912x
    sudo modprobe ms912x

### 2. Scripts

    mkdir -p ~/.local/bin
    cp scripts/*.py ~/.local/bin/
    cp scripts/*.sh ~/.local/bin/
    chmod +x ~/.local/bin/damage-kde.py
    chmod +x ~/.local/bin/position-damage.sh
    chmod +x ~/.local/bin/usb-on.sh
    chmod +x ~/.local/bin/usb-off.sh

### 3. Alias

    echo 'alias usb-on="~/.local/bin/usb-on.sh"' >> ~/.bashrc
    echo 'alias usb-off="~/.local/bin/usb-off.sh"' >> ~/.bashrc
    echo 'alias usb-1080="~/.local/bin/usb-on.sh 1920"' >> ~/.bashrc
    source ~/.bashrc

### 4. ydotool (opcional)

    yay -S ydotool
    sudo usermod -aG input $USER

## Uso diario

    # Encender (1280x720@60)
    usb-on

    # Encender (1920x1080@50)
    usb-1080

    # Apagar
    usb-off

## Cómo funciona internamente

### usb-on.sh

1. sudo modprobe ms912x - carga el driver
2. Espera a que aparezca /sys/class/drm/card0-HDMI-A-2
3. kscreen-doctor output.HDMI-A-2.enable - activa el monitor
4. kscreen-doctor output.HDMI-A-2.mode.1280x720@60 - fija modo
5. Arranca damage-kde.py en background
6. position-damage.sh mueve la ventana a la pantalla USB

### damage-kde.py

Ventana GTK4 de 64x64 que se redibuja cada 500ms (2 fps).
Al cambiar de color (rojo-amarillo), KWin detecta daño y envía
un frame al ms912x. Esto evita que la imagen se congele.

### position-damage.sh

Usa kdotool para mover la ventana de daño a x=3900 (dentro de
la pantalla USB que empieza en x=3840). Sin esto, la ventana
aparece en el monitor principal y no genera daño en el USB.

## Problemas conocidos

### El chip se cuelga

Síntomas: la pantalla no responde, dmesg muestra
ms912x: [drm] *ERROR* failed to power off display: -71.

Solución:

    usb-off
    sleep 5
    usb-on

### 1920x1080 va lento

El bus USB no da para 1080p@60 con este chip. Usa:

- 1280x720@60 (recomendado, fluido)
- 1920x1080@50 (funciona pero puede dar glitches)

### KWin entra en bucle

Si tras activar el monitor el PC va lento y dmesg muestra
Modeset failed! en bucle, es que KWin está intentando componer
con GPU. Solución: NO usar las variables KWIN_DRM_ en
~/.config/environment.d/.

## Lo que NO funciona

- GNOME/Mutter: límite de CRTCs + damage tracking roto.
- Auto-arranque con systemd: causaba bucles infinitos.
- udev rules: disparaban modprobe en momentos incorrectos.
- KWIN_DRM_NO_AMS=1: rompía KWin Wayland.

## Lo que SÍ funciona

- Carga manual del módulo.
- Activación manual del monitor con kscreen-doctor.
- Daño continuo con ventana pequeña en la pantalla USB.
- Cero automatización en el arranque.

## Créditos

- Driver ms912x - desarrollo en curso en el kernel Linux
- DKMS AUR - https://aur.archlinux.org/packages/ms912x
- Inspiración - hilos de Arch Wiki sobre DisplayLink y ms912x

## Licencia

MIT - Ver archivo LICENSE.
