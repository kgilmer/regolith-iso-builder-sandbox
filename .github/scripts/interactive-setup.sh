#!/bin/bash
set -u

chvt 8

DRY_RUN=false
if [[ "${1-}" == "--dry-run" ]]; then
    DRY_RUN=true
fi

whiptail --title "One-time Interactive Setup" --msgbox "This system requires initial setup.\n\nYou will be asked for a language, timezone, username, password, and hostname.\n\nAfter which the system will be configured and ready to use." 15 60

if [ "$DRY_RUN" = true ]; then
    whiptail --title "Dry Run Mode" --msgbox "DRY RUN MODE is active.\n\nNo changes will be made to the system." 10 60
fi

# Get the user's language

mapfile -t LOCALES < <(locale -a | sort)
MENU_ITEMS=()
for loc in "${LOCALES[@]}"; do
    MENU_ITEMS+=("$loc" "$loc")
done

while true; do
    LOCALE_SELECTION=$(whiptail --title "Select Default Language" --menu "Choose your system language / locale:" 30 70 20 "${MENU_ITEMS[@]}" 3>&1 1>&2 2>&3) || true
    if [ -n "$LOCALE_SELECTION" ]; then
        break
    fi
    whiptail --msgbox "You must select a language/locale to continue." 8 50
done

# Get the user's timezone

MENU_ITEMS=()
while read -r tz; do
    if [ -f "/usr/share/zoneinfo/$tz" ]; then
        MENU_ITEMS+=("$tz" "$tz")
    fi
done < <(timedatectl list-timezones)

while true; do
    TIMEZONE_SELECTION=$(whiptail --title "Select Timezone" --menu "Choose your timezone:" 30 70 20 "${MENU_ITEMS[@]}" 3>&1 1>&2 2>&3) || true
    if [ -n "$TIMEZONE_SELECTION" ]; then
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
    whiptail --msgbox "Passwords do not match. Please try again." 8 40
done

if [ "$DRY_RUN" = true ]; then
    echo "Locale: $LOCALE_SELECTION"
    echo "Timezone: $TIMEZONE_SELECTION"
    echo "Hostname: $HOSTNAME"
    echo "New User: $NEWUSER"
    echo "New Password: $NEWPASS"
else
    # Set the user's language
    if ! grep -q "^$LOCALE_SELECTION" /etc/locale.gen; then
        echo "$LOCALE_SELECTION UTF-8" >> /etc/locale.gen
    fi

    locale-gen "$LOCALE_SELECTION"
    update-locale LANG="$LOCALE_SELECTION"

    # Set the timezone
    timedatectl set-timezone "$TIMEZONE_SELECTION"

    # Set the hostname
    hostnamectl set-hostname "$HOSTNAME"

    # Create the user
    useradd -m -s /bin/bash "$NEWUSER"
    echo "$NEWUSER:$NEWPASS" | chpasswd
    usermod -aG sudo "$NEWUSER" || true   # optional: give sudo

    # Disable login by root
    passwd -l root

    whiptail --title "Setup Complete" --msgbox "Initial setup is complete. The system will now continue to the login screen." 10 60
fi

chvt 1
