#!/bin/bash
set -euo pipefail

set -x

printf "=== Initial System Setup ==="
while :; do
    read -p "Enter a username: " NEWUSER
    printf '\n'
    read -s -p "Enter a password for $NEWUSER: " NEWPASS
    printf '\n'
    read -s -p "Confirm the password: " CONFIRM
    printf '\n'
    [ "$NEWPASS" == "$CONFIRM" ] && break
    echo "Passwords do not match. Please try again."
done

# Create the user
useradd -m -s /bin/bash "$NEWUSER"
echo "$NEWUSER:$NEWPASS" | chpasswd
usermod -aG sudo "$NEWUSER" || true   # optional: give sudo

echo "User $NEWUSER created successfully!"
sleep 2
