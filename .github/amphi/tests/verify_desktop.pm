use base "basetest";
use strict;
use warnings;
use testapi;

# Post-login verification:
#   1. Confirm the Regolith/Wayland desktop loads (may show keybinding overlay
#      on first login — dismiss it with Escape if present).
#   2. Open a terminal with Super+Enter (Regolith/sway default).
#   3. Run printenv and confirm output appears.

sub run {
    # Wait for desktop — first login shows a keybinding cheatsheet overlay
    assert_screen('regolith-desktop', 90);
    wait_still_screen(3, 30);

    # Dismiss the keybinding overlay if present (Escape closes it)
    if (check_screen('regolith-desktop', 2)) {
        send_key('esc');
        wait_still_screen(2, 10);
    }

    # Confirm clean desktop is visible
    assert_screen('regolith-desktop-clean', 30);

    # ── Open terminal ─────────────────────────────────────────────────────────
    send_key('super-ret');
    assert_screen('terminal-open', 30);
    wait_still_screen(2, 10);

    # ── Run printenv ──────────────────────────────────────────────────────────
    type_string('printenv');
    send_key('ret');
    assert_screen('printenv-output', 30);
}

sub test_flags { return { fatal => 1 }; }

1;
