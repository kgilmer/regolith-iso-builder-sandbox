use base "basetest";
use strict;
use warnings;
use testapi;

# Automates LightDM slick-greeter login using the default session (Regolith/X11):
#   1. Wait for greeter with username field focused
#   2. Type username -> Enter
#   3. Wait for password prompt -> type password -> Enter
#
# Unlike login.pm, this skips session picker navigation because
# Regolith/X11 is already the default session.

sub run {
    assert_screen('lightdm-greeter', 60);
    wait_still_screen(2, 10);

    type_string('regolith');
    send_key('ret');

    assert_screen('lightdm-password-prompt', 15);
    type_string('test1234');
    send_key('ret');
}

sub test_flags { return { fatal => 1 }; }

1;
