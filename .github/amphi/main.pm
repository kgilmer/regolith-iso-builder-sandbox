use strict;
use warnings;
use autotest qw(loadtest);

# isotovideo always requires main.pm from PRODUCTDIR even when SCHEDULE is set.
# Guard against double-scheduling: if SCHEDULE is already set, do nothing here.
unless ($bmwqemu::vars{SCHEDULE}) {
    loadtest "tests/first_boot_setup.pm";

    if (($bmwqemu::vars{TEST_SUITE} // '') eq 'x11') {
        loadtest "tests/login_default_session.pm";
        loadtest "tests/verify_desktop_x11.pm";
    } else {
        loadtest "tests/login.pm";
        loadtest "tests/verify_desktop.pm";
    }
}

1;
