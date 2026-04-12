use base "basetest";
use strict;
use warnings;
use testapi;

# Automates LightDM slick-greeter login:
#   1. Wait for greeter with username field focused
#   2. Tab to session picker → Enter to open → Shift-Tab to Regolith/Wayland → Enter
#   3. Type username → Enter
#   4. Wait for password prompt → type password → Enter

sub run {
    assert_screen('lightdm-greeter', 60);
    wait_still_screen(2, 10);

    # Open session picker and select Regolith/Wayland
    send_key('tab');
    sleep 1;
    send_key('ret');
    _watch(5) if 0;    # not used here — just sleep
    sleep 5;
    send_key('shift-tab');
    sleep 1;
    send_key('ret');
    sleep 1;

    assert_screen('lightdm-greeter', 10);
    type_string('regolith');
    send_key('ret');

    assert_screen('lightdm-password-prompt', 15);
    type_string('test1234');
    send_key('ret');
}

sub test_flags { return { fatal => 1 }; }

1;
