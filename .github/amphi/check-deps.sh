#!/usr/bin/env bash
# check-deps.sh — Verify that os-autoinst's Perl dependencies load cleanly in
# an Ubuntu 24.04 container matching the GitHub Actions runner environment.
#
# Runs `perl -c` on isotovideo and every .pm under tests/ and main.pm. This
# surfaces *all* missing modules in seconds instead of discovering them one
# at a time over successive CI runs.
#
# Usage: ./.github/amphi/check-deps.sh
#
# Requires: docker (or podman aliased as docker)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Keep this in sync with the `Install test dependencies` step in
# .github/workflows/{pr-verify,release}.yml
PACKAGES=(
    os-autoinst ovmf qemu-system-x86
    libtime-moment-perl
    libmojolicious-perl
    libmojo-ioloop-readwriteprocess-perl
    libyaml-pp-perl
    libipc-run-perl
    libxml-libxml-perl
    libfile-which-perl
    libdata-dump-perl
    libcarp-always-perl
    libnet-dbus-perl
    libnet-ssh2-perl
    libcryptx-perl
    libclass-accessor-perl
    libjson-validator-perl
    liblist-moreutils-perl
    libfile-chdir-perl
    libio-stringy-perl
)

docker run --rm -v "${SCRIPT_DIR}:/amphi" -w /amphi ubuntu:24.04 bash -c "
    set -e
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq >/dev/null
    apt-get install -y --install-recommends --no-install-suggests ${PACKAGES[*]} >/dev/null

    echo '==> perl -c /usr/bin/isotovideo'
    perl -c /usr/bin/isotovideo

    echo '==> perl -c main.pm'
    perl -I/usr/lib/os-autoinst -c main.pm

    for f in tests/*.pm; do
        echo \"==> perl -c \$f\"
        perl -I/usr/lib/os-autoinst -c \"\$f\"
    done

    # Also compile-check every os-autoinst module. This catches modules that
    # are only loaded via runtime 'require' inside backends/consoles, which a
    # simple check of isotovideo+tests would miss.
    echo '==> perl -c on every os-autoinst .pm file'
    find /usr/lib/os-autoinst -name '*.pm' -print0 | while IFS= read -r -d '' f; do
        perl -I/usr/lib/os-autoinst -c \"\$f\" 2>&1 | grep -v 'syntax OK\$' || true
    done

    echo '==> All Perl imports resolve.'
"
