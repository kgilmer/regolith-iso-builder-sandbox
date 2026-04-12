use base "basetest";
use strict;
use warnings;
use testapi;

# Automates the first-boot whiptail wizard:
#   welcome → locale (C.utf8) → timezone (America/Los_Angeles, 148 downs)
#   → hostname → username → password → confirm → complete

sub run {
    assert_screen('setup-welcome', 180);
    send_key('ret');

    assert_screen('setup-locale-menu', 30);
    send_key('down');    # C → C.utf8
    send_key('ret');

    assert_screen('setup-timezone-menu', 30);
    for (1 .. 148) { send_key('down'); }    # Africa/Abidjan(0) → America/Los_Angeles(148)
    send_key('ret');

    assert_screen('setup-hostname', 30);
    type_string('regolith-test');
    send_key('ret');

    assert_screen('setup-username', 30);
    type_string('regolith');
    send_key('ret');

    assert_screen('setup-password', 30);
    type_string('test1234');
    send_key('ret');

    assert_screen('setup-confirm-password', 30);
    type_string('test1234');
    send_key('ret');

    assert_screen('setup-complete', 120);
    send_key('ret');
}

sub test_flags { return { fatal => 1 }; }

1;
