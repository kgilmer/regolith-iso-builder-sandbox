#!/bin/bash
set -euo pipefail

SETUP_DONE_MARKER="/var/lib/interactive-setup.done"

cleanup() {
    chvt 1 || true
}

trap cleanup EXIT

normalize_locale_for_gen() {
    local locale_name="$1"
    local normalized="$locale_name"
    if [[ "$normalized" == *.utf8 ]]; then
        normalized="${normalized%.utf8}.UTF-8"
    fi
    echo "$normalized"
}

validate_hostname() {
    local hostname_value="$1"
    [[ ${#hostname_value} -ge 1 && ${#hostname_value} -le 63 ]] || return 1
    [[ "$hostname_value" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$ ]] || return 1
}

validate_username() {
    local username_value="$1"
    [[ "$username_value" =~ ^[a-z_][a-z0-9_-]*$ ]]
}

chvt 8

DRY_RUN=false
if [[ "${1-}" == "--dry-run" ]]; then
    DRY_RUN=true
fi

whiptail --title "One-time Interactive Setup" --msgbox "Welcome to Regolith 3.4!  This system requires a bit of initial setup.\n\nYou will be asked for a language, timezone, username, password, and hostname.\n\nAfter which the system will be configured and ready to use.  You will not see this dialog again." 15 60

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
    HOSTNAME=$(whiptail --inputbox "Provide a (host) name for this system or drive:" 10 50 3>&1 1>&2 2>&3) || true
    NEWUSER=$(whiptail --inputbox "Enter a username (lowercase letters, digits, _ or -):" 10 60 3>&1 1>&2 2>&3) || true
    NEWPASS=$(whiptail --passwordbox "Password for $NEWUSER (minimum 8 chars):" 10 60 3>&1 1>&2 2>&3) || true
    CONFIRM=$(whiptail --passwordbox "Confirm:" 10 60 3>&1 1>&2 2>&3) || true

    if ! validate_hostname "$HOSTNAME"; then
        whiptail --msgbox "Hostname must be 1-63 chars, alphanumeric/hyphen, and cannot start or end with a hyphen." 10 70
        continue
    fi

    if ! validate_username "$NEWUSER"; then
        whiptail --msgbox "Invalid username. Use lowercase letters, digits, '_' or '-', and start with a letter or '_'." 10 70
        continue
    fi

    if [[ ${#NEWPASS} -lt 8 ]]; then
        whiptail --msgbox "Password must be at least 8 characters." 8 45
        continue
    fi

    if [[ "$NEWPASS" != "$CONFIRM" ]]; then
        whiptail --msgbox "Passwords do not match. Please try again." 8 40
        continue
    fi

    break
done

if [ "$DRY_RUN" = true ]; then
    echo "Locale: $LOCALE_SELECTION"
    echo "Timezone: $TIMEZONE_SELECTION"
    echo "Hostname: $HOSTNAME"
    echo "New User: $NEWUSER"
    echo "New Password: [hidden]"
else
    # Set the user's language
    LOCALE_GEN_ENTRY="$(normalize_locale_for_gen "$LOCALE_SELECTION") UTF-8"
    LOCALE_GEN_REGEX="$(printf '%s\n' "$LOCALE_GEN_ENTRY" | sed 's/[][\\.^$*+?(){}|]/\\&/g')"

    if grep -Eq "^[[:space:]]*#?[[:space:]]*${LOCALE_GEN_REGEX}[[:space:]]*$" /etc/locale.gen; then
        sed -ri "s|^[[:space:]]*#?[[:space:]]*${LOCALE_GEN_REGEX}[[:space:]]*$|${LOCALE_GEN_ENTRY}|" /etc/locale.gen
    else
        echo "$LOCALE_GEN_ENTRY" >> /etc/locale.gen
    fi

    locale-gen
    update-locale LANG="$LOCALE_SELECTION"

    # Set the timezone
    timedatectl set-timezone "$TIMEZONE_SELECTION"
    timedatectl set-ntp true

    # Set the hostname in both runtime and persistent config.
    # Avoid depending solely on hostnamectl/dbus timing this early in boot.
    printf '%s\n' "$HOSTNAME" > /etc/hostname
    hostname "$HOSTNAME"
    hostnamectl set-hostname "$HOSTNAME" --static || true
    if grep -qE '^127\.0\.1\.1[[:space:]]+' /etc/hosts; then
        sed -ri "s|^127\\.0\\.1\\.1[[:space:]]+.*$|127.0.1.1\t${HOSTNAME}|" /etc/hosts
    else
        echo -e "127.0.1.1\t${HOSTNAME}" >> /etc/hosts
    fi

    # Create the user
    useradd -m -s /bin/bash "$NEWUSER"
    echo "$NEWUSER:$NEWPASS" | chpasswd
    usermod -aG sudo "$NEWUSER"

    # Disable login by root
    passwd -l root

    mkdir -p "$(dirname "$SETUP_DONE_MARKER")"
    touch "$SETUP_DONE_MARKER"

    whiptail --title "Setup Complete" --msgbox "Initial setup is complete. The system will now continue to the login screen." 10 60
fi
