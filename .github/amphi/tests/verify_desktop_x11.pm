use base "basetest";
use strict;
use warnings;
use testapi;

# Post-login verification for Regolith/X11 session:
#   1. Confirm the Regolith/X11 desktop loads (may show keybinding overlay
#      on first login — dismiss it with Escape if present).
#   2. Open a terminal with Super+Enter.

sub run {
    # Wait for desktop — first login shows a keybinding cheatsheet overlay
    assert_screen('x11-regolith-desktop', 90);
    wait_still_screen(3, 30);

    # Dismiss the keybinding overlay if present (Escape closes it)
    if (check_screen('x11-regolith-desktop', 2)) {
        send_key('esc');
        wait_still_screen(2, 10);
    }

    # Confirm clean desktop is visible
    assert_screen('x11-regolith-desktop-clean', 30);

    # ── Open terminal ─────────────────────────────────────────────────────────
    # First super-ret after overlay dismiss is sometimes dropped by i3; retry.
    send_key_until_needlematch('x11-terminal-open', 'super-ret', 3, 5);
}

sub test_flags { return { fatal => 1 }; }

1;
