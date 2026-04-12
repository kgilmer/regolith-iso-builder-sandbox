use strict;
use warnings;
use autotest qw(loadtest);

# isotovideo always requires main.pm from PRODUCTDIR even when SCHEDULE is set.
# Guard against double-scheduling: if SCHEDULE is already set, do nothing here.
unless ($bmwqemu::vars{SCHEDULE}) {
    loadtest "tests/first_boot_setup.pm";
    loadtest "tests/login.pm";
    loadtest "tests/verify_desktop.pm";
}

1;
