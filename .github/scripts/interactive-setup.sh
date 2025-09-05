#!/bin/bash
set -euo pipefail

set -x


while :; do
    RESULT=$(zenity --forms \
    --title="Initial Setup" \
    --text="Create your first user" \
    --add-entry="Username" \
    --add-password="Password" \
    --add-password="Confirm Password")

    if [ $? -ne 0 ]; then
        # User pressed Cancel
        exit 1
    fi

    # Split results (zenity returns fields separated by '|')
    NEWUSER=$(echo "$RESULT" | cut -d'|' -f1)
    NEWPASS=$(echo "$RESULT" | cut -d'|' -f2)
    CONFIRM=$(echo "$RESULT" | cut -d'|' -f3)

    [ "$NEWPASS" == "$CONFIRM" ] && break
    zenity --error --title="Setup Error" --text="Passwords do not match. Please try again."
done

# printf "=== Initial System Setup ==="
# while :; do
#     read -p "Enter a username: " NEWUSER
#     printf '\n'
#     read -s -p "Enter a password for $NEWUSER: " NEWPASS
#     printf '\n'
#     read -s -p "Confirm the password: " CONFIRM
#     printf '\n'
#     [ "$NEWPASS" == "$CONFIRM" ] && break
#     echo "Passwords do not match. Please try again."
# done

# Create the user
useradd -m -s /bin/bash "$NEWUSER"
echo "$NEWUSER:$NEWPASS" | chpasswd
usermod -aG sudo "$NEWUSER" || true   # optional: give sudo

echo "User $NEWUSER created successfully!"
sleep 2
