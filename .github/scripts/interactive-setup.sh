#!/bin/bash
set -euo pipefail

echo "=== Initial System Setup ==="
read -p "Enter new username: " NEWUSER
read -s -p "Enter password for $NEWUSER: " NEWPASS
echo
read -s -p "Confirm password: " CONFIRM
echo

if [ "$NEWPASS" != "$CONFIRM" ]; then
    echo "Passwords do not match. Reboot and try again."
    exit 1
fi

# Create the user
useradd -m -s /bin/bash "$NEWUSER"
echo "$NEWUSER:$NEWPASS" | chpasswd
usermod -aG sudo "$NEWUSER" || true   # optional: give sudo

echo "User $NEWUSER created successfully!"
sleep 2
