#!/bin/bash
set -euo pipefail

whiptail --title "One-time Interactive Setup" --msgbox "This system requires initial setup.\n\nYou will be asked for a language, timezone, username, password, and hostname.\n\nAfter which the system will be configured and ready to use." 15 60

# Get the user's language

LOCALES=$(locale -a | sort)
MENU=""
while read -r loc; do
    MENU="$MENU \"$loc\" \"$loc\""
done <<< "$LOCALES"

while true; do
    SELECTION=$(eval whiptail --title "Select Default Language" --menu "Choose your system language / locale:" 20 60 15 $MENU 3>&1 1>&2 2>&3) || true
    if [ -n "$SELECTION" ]; then
        break
    fi
    whiptail --msgbox "You must select a language/locale to continue." 8 50
done

# Get the user's timezone

MENU=""
while read -r tz; do
    MENU="$MENU \"$tz\" \"$tz\""
done < <(timedatectl list-timezones)

while true; do
    SELECTION=$(eval whiptail --title "Select Timezone" --menu "Choose your timezone:" 20 60 15 $MENU 3>&1 1>&2 2>&3) || true
    if [ -n "$SELECTION" ]; then
        break
    fi
    whiptail --msgbox "You must select a timezone to continue." 8 50
done

# Get the hostname and user info

while :; do
    HOSTNAME=$(whiptail --inputbox "Enter a short, memorable name for this system:" 10 50 3>&1 1>&2 2>&3) || true
    NEWUSER=$(whiptail --inputbox "Enter new username:" 10 50 3>&1 1>&2 2>&3) || true
    NEWPASS=$(whiptail --passwordbox "Enter a password for $NEWUSER:" 10 50 3>&1 1>&2 2>&3) || true
    CONFIRM=$(whiptail --passwordbox "Confirm your password:" 10 50 3>&1 1>&2 2>&3) || true

    [ "$NEWPASS" == "$CONFIRM" ] && break
    whiptail --msgbox "Passwords do not match. Please reboot and try again." 8 40
done

# Set the user's language
if ! grep -q "^$SELECTION" /etc/locale.gen; then
    echo "$SELECTION UTF-8" >> /etc/locale.gen
fi

locale-gen "$SELECTION"
update-locale LANG="$SELECTION"

# Set the timezone
timedatectl set-timezone "$SELECTION"

# Set the hostname
hostnamectl set-hostname $HOSTNAME

# Create the user
useradd -m -s /bin/bash "$NEWUSER"
echo "$NEWUSER:$NEWPASS" | chpasswd
usermod -aG sudo "$NEWUSER" || true   # optional: give sudo

# Disable login by root
passwd -l root
