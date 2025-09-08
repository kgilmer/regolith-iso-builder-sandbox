#!/bin/bash
set -e
set -o errexit

# Base dependencies

DEBIAN_FRONTEND=noninteractive apt-get install -y --upgrade \
    firefox-esr \
    firmware-ath9k-htc \
    firmware-iwlwifi \
    firmware-linux \
    gnome-terminal \
    htop \
    iw \
    less \
    lightdm \
    lightdm-gtk-greeter \
    network-manager \
    rsyslog \
    sudo \
    vim \
    wireless-tools \
    wpasupplicant

# Enable first-boot system configuration

chmod +x /usr/bin/interactive-setup.sh
systemctl enable interactive-setup.service

# Locale generation

echo "en_US.UTF-8 UTF-8" > /etc/locale.gen

# Regolith Deb Repo 

wget -qO - https://archive.regolith-desktop.com/regolith.key | gpg --dearmor | tee /usr/share/keyrings/regolith-archive-keyring.gpg > /dev/null

echo "deb [arch=amd64 signed-by=/usr/share/keyrings/regolith-archive-keyring.gpg] https://archive.regolith-desktop.com/debian/unstable trixie main" > /etc/apt/sources.list.d/regolith.list

apt update

DEBIAN_FRONTEND=noninteractive apt-get install -y \
    regolith-desktop \
    regolith-lightdm-config \
    regolith-look-lascaille \
    regolith-session-flashback \
    regolith-session-sway