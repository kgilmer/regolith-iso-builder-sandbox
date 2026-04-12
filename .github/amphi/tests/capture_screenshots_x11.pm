use base "basetest";
use strict;
use warnings;
use testapi;
use Digest::MD5 qw(md5_hex);
use File::Glob qw(bsd_glob);

# Screenshot capture mode for Regolith/X11 session.
#
# Drives the full flow (wizard → default-session login → desktop) but only
# emits NEEDLE: markers for the X11-specific desktop needles (x11- prefix).
# Shared needles (setup-*, lightdm-*) are not re-captured here — they are
# identical across sessions and managed by capture_screenshots.pm.

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
    diag("=== CAPTURE MODE: x11 ===");

    # ── First-boot wizard (no NEEDLE markers — shared needles) ────────────
    _watch(120);
    send_key('ret');        # dismiss welcome

    _watch(5);
    send_key('down');       # locale: C → C.utf8
    send_key('ret');

    _watch(5);
    for (1..148) { send_key('down'); }   # timezone → America/Los_Angeles
    send_key('ret');

    _watch(5);
    type_string('regolith-test'); send_key('ret');  # hostname

    _watch(3);
    type_string('regolith'); send_key('ret');        # username

    _watch(3);
    type_string('test1234'); send_key('ret');        # password

    _watch(3);
    type_string('test1234'); send_key('ret');        # confirm

    _watch(10);
    send_key('ret');        # setup complete

    # ── LightDM — default session, no session picker ─────────────────────
    _watch(30);
    type_string('regolith'); send_key('ret');

    _watch(5);
    type_string('test1234'); send_key('ret');
    _watch(60);    # wait for desktop

    # ── Desktop phase — X11-specific needles ─────────────────────────────
    _watch(10);
    diag("NEEDLE: x11-regolith-desktop");
    send_key('esc');            # dismiss keybinding overlay
    _watch(10);

    diag("NEEDLE: x11-regolith-desktop-clean");
    # Open terminal
    send_key('super-ret');
    _watch(15);

    diag("NEEDLE: x11-terminal-open");

    diag("=== CAPTURE COMPLETE ===");
}

sub test_flags { return { fatal => 0 }; }

1;
