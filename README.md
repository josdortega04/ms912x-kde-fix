# ms912x driver for Linux

Linux kernel driver for MacroSilicon USB to VGA/HDMI adapter.

There are three variants:
- VID/PID is 534d:6021. Device is USB 2
- VID/PID is 534d:0821. Device is USB 2
- VID/PID is 345f:9132. Device is USB 3
- VID/PID is 345f:9133. Device is USB 3

## Supported kernels

Use the branch matching the target kernel:

- Linux 5.10 LTS: `kernel-5.10`
- Linux 5.15 LTS: `kernel-5.15`
- Linux 6.1 LTS: `kernel-6.1`
- Linux 6.6 LTS: `kernel-6.6`
- Linux 6.12 LTS: `kernel-6.12`
- Linux 6.18 LTS: `kernel-6.18`
- Linux 7.2: `kernel-7.2`

`main` tracks current development.

TODOs:

- Detect connector type (VGA, HDMI, etc...)
- More resolutions
- Error handling
- Is RGB to YUV conversion needed?

## Development 

Driver is written by analyzing wireshark captures of the device.

## DKMS

Run `sudo dkms install .`


## KDE Plasma Wayland: MS912x display refresh workaround

A small GTK4 window can be used as a workaround to trigger periodic screen
updates when using the MS912x USB display adapter under KDE Plasma Wayland.

### Helper scripts

- `scripts/damage-kde.py`: creates an undecorated 8 × 8 pixel GTK4 window
  with 12% opacity. Its drawing area is refreshed every 500 ms.
- `scripts/position-damage.sh`: locates the window named `damage`, resizes it,
  positions it at coordinates `3900,100`, and sets window-management flags
  using `kdotool`.

### Requirements

- Python 3
- GTK 4 and PyGObject
- KDE Plasma Wayland
- `kdotool`

### Usage

Run the scripts from the repository directory in separate terminals:

```bash
python scripts/damage-kde.py
```

```bash
bash scripts/position-damage.sh
```

The positioning coordinates may need to be adjusted to match the desktop's
monitor layout. This is a desktop-specific workaround and is not part of the
kernel driver's core functionality.
