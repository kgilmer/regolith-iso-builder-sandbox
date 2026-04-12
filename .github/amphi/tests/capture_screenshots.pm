use base "basetest";
use strict;
use warnings;
use testapi;
use Digest::MD5 qw(md5_hex);
use File::Glob qw(bsd_glob);

# Screenshot capture mode — snapshots the VNC framebuffer at 1fps and
# deduplicates by MD5 hash, keeping only frames where the screen changed.
#
# NEEDLE: markers are emitted via diag() at each UI state so that
# update-needles.sh can automatically map frames to needle names.
#
# MODE is controlled by the CAPTURE_MODE var in vars-capture.json:
#   "full"     — full flow: wizard + login + desktop (default)
#   "desktop"  — start from already-booted desktop (for terminal/printenv needles)

my $last_hash = '';

sub _snap {
    save_screenshot;
    my @pngs = reverse sort bsd_glob(bmwqemu::result_dir() . '/*.png');
    return unless @pngs;
    my $file = $pngs[0];
    open my $fh, '<', $file or return;
    binmode $fh;
    my $hash = md5_hex(do { local $/; <$fh> });
    close $fh;
    if ($hash eq $last_hash) {
        unlink $file;
    } else {
        $last_hash = $hash;
        diag("SNAP: $file");
    }
}

sub _watch {
    my ($secs) = @_;
    for (1 .. $secs) { _snap(); sleep 1; }
}

sub run {
    my $mode = $bmwqemu::vars{CAPTURE_MODE} // 'full';
    diag("=== CAPTURE MODE: $mode ===");

    if ($mode eq 'full') {
        # Boot → wizard welcome screen
        _watch(120);
        diag("NEEDLE: setup-welcome");
        send_key('ret');        # dismiss welcome

        _watch(5);
        diag("NEEDLE: setup-locale-menu");
        send_key('down');       # locale: C → C.utf8
        send_key('ret');

        _watch(5);
        diag("NEEDLE: setup-timezone-menu");
        for (1..148) { send_key('down'); }   # timezone → America/Los_Angeles
        send_key('ret');

        _watch(5);
        diag("NEEDLE: setup-hostname");
        type_string('regolith-test'); send_key('ret');  # hostname

        _watch(3);
        diag("NEEDLE: setup-username");
        type_string('regolith'); send_key('ret');        # username

        _watch(3);
        diag("NEEDLE: setup-password");
        type_string('test1234'); send_key('ret');        # password

        _watch(3);
        diag("NEEDLE: setup-confirm-password");
        type_string('test1234'); send_key('ret');        # confirm

        _watch(10);
        diag("NEEDLE: setup-complete");
        send_key('ret');        # setup complete

        # LightDM
        _watch(30);
        diag("NEEDLE: lightdm-greeter");
        send_key('tab'); sleep 1;
        send_key('ret'); _watch(5);
        send_key('shift-tab'); sleep 1;
        send_key('ret'); sleep 1;
        _watch(3);
        type_string('regolith'); send_key('ret');

        _watch(5);
        diag("NEEDLE: lightdm-password-prompt");
        type_string('test1234'); send_key('ret');
        _watch(60);    # wait for desktop
    }

    # Desktop phase — capture keybinding overlay and clean state
    _watch(10);
    diag("NEEDLE: regolith-desktop");
    send_key('esc');            # dismiss keybinding overlay
    _watch(10);

    diag("NEEDLE: regolith-desktop-clean");
    # Open terminal
    send_key('super-ret');
    _watch(15);

    diag("NEEDLE: terminal-open");
    # Run printenv
    type_string('printenv');
    send_key('ret');
    _watch(10);

    diag("NEEDLE: printenv-output");

    diag("=== CAPTURE COMPLETE ===");
}

sub test_flags { return { fatal => 0 }; }

1;
