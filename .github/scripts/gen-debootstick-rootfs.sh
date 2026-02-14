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

# Locale generation - moving to regolith-debootstick-setup

# echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
# sed -i 's/^# *\(en_US.UTF-8 UTF-8\)/\1/' /etc/locale.gen
# locale-gen

# Regolith Deb Repo 

wget -qO - https://archive.regolith-desktop.com/regolith.key | gpg --dearmor | tee /usr/share/keyrings/regolith-archive-keyring.gpg > /dev/null

# Use the "rolling" release URL to always get the latest release
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/regolith-archive-keyring.gpg] https://archive.regolith-desktop.com/debian/stable trixie main" > /etc/apt/sources.list.d/regolith.list
 
# Add experimental repo for special ISO only package regolith-debootstick-setup
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/regolith-archive-keyring.gpg] https://archive.regolith-desktop.com/debian/experimental trixie main" > /etc/apt/sources.list.d/regolith-exp.list

apt update
 
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    regolith-debootstick-setup \
    regolith-desktop \
    regolith-lightdm-config \
    regolith-look-lascaille \
    regolith-session-flashback \
    regolith-session-sway
