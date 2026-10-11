# MS912x KDE Fix — Solución estable para adaptador MacroSilicon MS912x en KDE Plasma/Wayland

> **Estado**: ✅ **ESTABLE** — Probado en login (SDDM→KWin) y suspend/resume

---

## Problema

Adaptador USB-HDMI basado en chip **MacroSilicon MS912x** en KDE Plasma (Wayland):

| Síntoma | Causa |
|---------|-------|
| Pantalla se apaga al cambiar modo o aplicar config | Chip necesita actividad continua |
| Solo revive moviendo ratón encima (o cambio resolución + vuelta) | Necesita "damage" continuo |
| Funciona perfecto en SDDM, se apaga al loguear (KWin arranca) | KWin reaplica config sin damage |
| Igual tras suspend/resume | Chip queda en estado malo sin damage |

**Hallazgo clave**: La inestabilidad **no es por el refresh rate en sí**, sino por **falta de damage (redibujado continuo)**.

| Condición | @60Hz | @50Hz |
|-----------|-------|-------|
| **Sin damage window** | Inestable (se apaga) | Estable |
| **Con damage window** | **Estable** | Estable |

> El @50Hz era un "fallback seguro" por si el damage fallaba. **Con damage corriendo, @60Hz (preferido) funciona perfecto.**

---

## Hardware / Entorno

- **Host**: KALAHARI (Fedora/Arch-like, KDE Plasma Wayland)
- **Usuario**: `davidu14`
- **GPU**: 3 salidas — `eDP-1`, `HDMI-A-1`, `HDMI-A-2` (MS912x)
- **Escala fraccional**: `HDMI-A-2` en `0.9`
- **Driver**: `ms912x` en `/sys/class/drm/card0-HDMI-A-2`
- **Herramientas**: `ydotool` + `ydotoold`, `kdotool` (coordenadas literales, sin factor de escala)

---

## Solución: "Danza de despertar" automatizada

La secuencia que **siempre** revive el chip y lo deja estable:

```bash
# 1. Reset total del chip
kscreen-doctor output.HDMI-A-2.disable
sleep 1

# 2. Handshake @60 (fuerza renegociación HDMI, modo preferido)
kscreen-doctor output.HDMI-A-2.enable output.HDMI-A-2.mode.1
sleep 2

# 3. Modo estable @50 (fallback por si damage falla)
kscreen-doctor output.HDMI-A-2.mode.4
sleep 1.5

# 4. Ventana damage (16x16, 12% opacidad, redibuja cada 500ms) — CLAVE
position-damage.sh --restart
```

**Modos clave HDMI-A-2:**
- **Modo 1**: `1920x1080@60.00` (preferred, **estable CON damage**)
- **Modo 4**: `1920x1080@50.00` (fallback, estable SIN damage)

---

## Instalación

```bash
# 1. Clonar
git clone https://github.com/josdortega04/ms912x-kde-fix.git
cd ms912x-kde-fix

# 2. Instalar scripts en ~/.local/bin
cp scripts/ms912x-wake.sh ~/.local/bin/
chmod +x ~/.local/bin/ms912x-wake.sh

# 3. Autostart KDE (login Wayland)
mkdir -p ~/.config/autostart
cp ms912x-wake.desktop ~/.config/autostart/  # incluido en repo

# 4. Hook systemd (resume suspensión) — requiere sudo
sudo cp ms912x-wake-systemd /usr/lib/systemd/system-sleep/ms912x-wake
sudo chmod +x /usr/lib/systemd/system-sleep/ms912x-wake
```

---

## Archivos del proyecto

```
ms912x-kde-fix/
├── scripts/
│   ├── ms912x-lib.sh          # Librería compartida (detección, modos, logging)
│   ├── ms912x-activate.sh     # Activa salida + opcional damage (con --mode seguro)
│   ├── ms912x-wake.sh         # **Danza completa** (disable → @60 → @50 → damage)
│   └── position-damage.sh     # Autodetecta posición HDMI-A-2 y mueve ventana damage
├── ms912x-wake.desktop        # Autostart KDE (phase=1, early startup)
├── ms912x-wake-systemd        # Hook systemd sleep (post-suspend/hibernate)
└── README.md
```

**En `~/.local/bin/` (aliases de usuario):**
- `usb-on` → `usb-on.sh` (1920x1080@50 explícito, funciona standalone)
- `usb-off` → `usb-off.sh`
- `damage-kde.py` — Ventana GTK4 8x8, 12% opacidad, redibuja cada 500ms
- `ms912x-wake.sh` — Copia del script principal

---

## Automatización: qué se ejecuta cuándo

| Evento | Qué corre | Cómo |
|--------|-----------|------|
| **Login Wayland** (KWin arranca) | `ms912x-wake.sh` | `~/.config/autostart/ms912x-wake.desktop` (phase=1) |
| **Resume suspensión/hibernación** | `ms912x-wake.sh` | `/usr/lib/systemd/system-sleep/ms912x-wake` (runuser davidu14) |

> **Por qué phase=1 en autostart**: KWin aplica su config en phase=0; phase=1 corre *después*, sobreescribiendo lo que KWin puso y arrancando damage.

---

## Lo que NO funcionó (para no repetir)

| Intento | Por qué falló |
|---------|---------------|
| Una sola llamada `kscreen-doctor` con 3 args | Apagón inmediato |
| `ydotool mousemove --relative` | Sintaxis inexistente |
| Jiggle dentro de `ms912x_apply` | Apagaba sin recuperar |
| Confiar en `ms912x-activate.sh` sin `--mode` | Caía a preferred=@60 **sin damage** |
| Cualquier solución que ignore que **KWin reaplica config al login** | Se sobrescribe sin damage |

---

## Reglas de oro

1. **Una acción, un test, una confirmación** antes de la siguiente
2. **Nunca tocar** `ms912x-lib.sh` ni `ms912x-activate.sh` sin datos que lo justifiquen
3. **Nunca asumir** que KWin no reaplica config — siempre verificar `kwinoutputconfig.json`
4. **Damage window es el factor clave** — @50Hz es fallback, no requisito
5. `kdotool` usa **coordenadas literales** — sin factor de escala

---

## Verificación rápida

```bash
# Estado actual
kscreen-doctor -j | jq '.outputs[] | select(.name=="HDMI-A-2") | {enabled, currentModeId}'

# Debe salir: "enabled": true, "currentModeId": "1" (o "4") + damage corriendo

# Verificar damage
pgrep -f damage-kde.py

# Logs de wake
journalctl -t ms912x-wake -f
```

---

## Créditos / Referencias

- Driver kernel: `ms912x` (staging)
- `kscreen-doctor` / `libkscreen` — control de modos KDE
- `kdotool` — automatización Wayland nativa (coordenadas literales)
- GTK4 + Python — ventana damage ligera

---

**Última validación**: Octubre 2026 — Versión v1.2.6. Estable en login + suspend/resume múltiples ciclos.
**Modo actual**: 1920x1080@60Hz (preferido) + damage window → **estable**.