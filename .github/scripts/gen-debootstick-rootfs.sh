#!/bin/bash
set -e
set -o errexit

# Base dependencies

DEBIAN_FRONTEND=noninteractive apt-get install -y --upgrade \
    firefox-esr \
    firmware-ath9k-htc \
    firmware-iwlwifi \
    firmware-linux \
    firmware-linux-nonfree \
    firmware-realtek \
    gnome-terminal \
    htop \
    iw \
    less \
    lightdm \
    lightdm-gtk-greeter \
    locales \
    network-manager \
    rsyslog \
    sudo \
    vim \
    wireless-tools \
    wpasupplicant

# Brand GRUB menu entries in the installed target system.
# This changes entries like "Debian GNU/Linux" to "Regolith Linux".
if [ -f /etc/default/grub ] && grep -q '^GRUB_DISTRIBUTOR=' /etc/default/grub; then
    sed -i 's/^GRUB_DISTRIBUTOR=.*/GRUB_DISTRIBUTOR="Regolith Linux"/' /etc/default/grub
else
    echo 'GRUB_DISTRIBUTOR="Regolith Linux"' >> /etc/default/grub
fi

# Enable first-boot system configuration

chmod +x /usr/bin/interactive-setup.sh
systemctl enable interactive-setup.service
systemctl enable NetworkManager
systemctl enable lightdm

# Locale generation

echo "en_US.UTF-8 UTF-8" > /etc/locale.gen

# Regolith Deb Repo 

wget -qO - https://archive.regolith-desktop.com/regolith.key | gpg --dearmor | tee /usr/share/keyrings/regolith-archive-keyring.gpg > /dev/null

echo "deb [arch=amd64 signed-by=/usr/share/keyrings/regolith-archive-keyring.gpg] https://archive.regolith-desktop.com/debian/stable trixie main" > /etc/apt/sources.list.d/regolith.list
 
apt update

DEBIAN_FRONTEND=noninteractive apt-get install -y \
    regolith-desktop \
    regolith-lightdm-config \
    regolith-look-blackhole \
    regolith-look-dracula \
    regolith-look-gruvbox \
    regolith-look-lascaille \
    regolith-look-nord \
    regolith-look-solarized-dark \
    regolith-session-flashback \
    regolith-session-sway
