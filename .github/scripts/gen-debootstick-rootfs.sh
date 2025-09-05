#!/bin/bash
set -e
set -o errexit

# Base dependencies

echo "deb https://deb.debian.org/debian trixie main contrib non-free non-free-firmware" > /etc/apt/sources.list

apt update

DEBIAN_FRONTEND=noninteractive apt-get install -y --upgrade --no-install-recommends \
    locales \
    pgp \
    systemd \
    wget

# Configure System

echo "seed" > /etc/hostname
chmod +x /usr/bin/interactive-setup.sh
systemctl enable interactive-setup.service

# Regolith Deb Repo 

wget -qO - https://archive.regolith-desktop.com/regolith.key | gpg --dearmor | tee /usr/share/keyrings/regolith-archive-keyring.gpg > /dev/null

echo "deb [arch=amd64 signed-by=/usr/share/keyrings/regolith-archive-keyring.gpg] https://archive.regolith-desktop.com/debian/unstable trixie main" > /etc/apt/sources.list.d/regolith.list

apt update

# Locale generation

echo "en_US.UTF-8 UTF-8" > /etc/locale.gen

# Complete dependency set

DEBIAN_FRONTEND=noninteractive apt-get install -y --upgrade \
    firefox-esr \
    firmware-ath9k-htc \
    firmware-iwlwifi \
    firmware-linux \
    gnome-terminal \
    htop \
    less \
    lightdm \
    lightdm-gtk-greeter \
    network-manager \
    regolith-desktop \
    regolith-lightdm-config \
    regolith-look-lascaille \
    regolith-session-flashback \
    regolith-session-sway \
    sudo \
    vim \
    zenity
