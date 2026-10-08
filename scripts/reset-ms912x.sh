#!/bin/bash
echo "Reseteando ms912x..."
echo -n "4-2:1.3" | sudo tee /sys/bus/usb/drivers/ms912x/unbind 2>/dev/null
sudo modprobe -r ms912x
sleep 1
sudo modprobe ms912x
sleep 2
echo "--- DRM devices ---"
ls /dev/dri/
echo "--- Kernel log ---"
sudo dmesg | tail -10
echo "--- Monitores GNOME ---"
gnome-randr | grep -A3 "HDMI"
