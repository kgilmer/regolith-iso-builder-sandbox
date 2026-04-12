# Contributing to Amphi

Technical internals, architecture, and development guide for contributors.

## Architecture Overview

```
                         ┌──────────────┐
                         │  vars.json   │  (generated from vars-{test,capture}-<suite>.json)
                         └──────┬───────┘
                                │
                         ┌──────▼───────┐
                         │  isotovideo  │  (os-autoinst test runner)
                         └──────┬───────┘
                                │
              ┌─────────────────┼─────────────────┐
              │                 │                  │
       ┌──────▼──────┐  ┌──────▼──────┐  ┌───────▼───────┐
       │   main.pm   │  │    QEMU     │  │  testresults/  │
       │ (scheduler) │  │ (via VNC)   │  │  (output)      │
       └──────┬──────┘  └──────┬──────┘  └───────────────-┘
              │                │
       ┌──────▼──────┐  ┌─────▼──────┐
       │   tests/*.pm │  │  needles/  │
       │ (test logic) │  │  (PNG+JSON)│
       └─────────────┘  └────────────┘
```

### How isotovideo Works

**isotovideo** is the test runner from the [os-autoinst](https://github.com/os-autoinst/os-autoinst) project. It:

1. Reads `vars.json` from the current working directory
2. Launches QEMU with the specified disk image and hardware config
3. Loads `main.pm` from `CASEDIR` (`.github/amphi/`)
4. Executes test modules registered via `loadtest` in order
5. For each `assert_screen` call, captures the VNC framebuffer and compares it against needles in `NEEDLES_DIR`
6. Writes results (screenshots, pass/fail status, video) to `testresults/`

The VM is driven entirely through the VNC connection -- keyboard input goes in, screen captures come out. There is no SSH, serial console, or agent inside the VM.

### Two Operating Modes

| Mode | Entry point | vars file pattern | Purpose |
|------|-------------|-------------------|---------|
| **Test** | `run-tests.sh <suite>` | `vars-test-<suite>.json` | Run the test suite, assert needle matches |
| **Capture** | `capture-screenshots.sh <suite>` | `vars-capture-<suite>.json` | Drive the same flow but save 1fps deduplicated screenshots |

Available suites: `wayland`, `x11`. The scripts resolve the suite name to the matching vars file automatically.

The key difference: `vars-capture-<suite>.json` sets `SCHEDULE` which makes isotovideo run the capture script directly instead of the normal test modules. `vars-test-<suite>.json` has no `SCHEDULE` key, so isotovideo falls through to `main.pm`'s `loadtest` calls.

### The SCHEDULE Guard and Suite Selection in main.pm

```perl
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
```

When `SCHEDULE` is set (capture mode), isotovideo handles scheduling directly and `main.pm` becomes a no-op. When `SCHEDULE` is absent (test mode), `main.pm` checks the `TEST_SUITE` variable to determine which login and desktop verification modules to load. The `TEST_SUITE` variable is set in the suite-specific vars file (e.g., `vars-test-x11.json` sets `"TEST_SUITE": "x11"`).

## Key Technical Details

### loadtest Path Requirements

The `autotest::loadtest` function requires paths matching the regex `(\w+)/([^/]+)\.p[my]` -- there **must** be a directory component and a `.pm` extension:

- `loadtest "tests/first_boot_setup.pm"` -- correct
- `loadtest "first_boot_setup.pm"` -- **fails** (no directory component)
- `loadtest "first_boot_setup"` -- **fails** (no extension)

Paths are resolved relative to `CASEDIR`.

### UEFI Boot Chain

The VM boots via OVMF (UEFI firmware for QEMU):

- `UEFI_PFLASH_CODE` -- Read-only firmware code (shared system file, never modified)
- `UEFI_PFLASH_VARS` -- Writable UEFI variable store (fresh copy made each run)

The run scripts copy `/usr/share/OVMF/OVMF_VARS_4M.fd` to `ovmf_vars.fd` before each run so UEFI state is always clean.

### Disk Image Handling

os-autoinst creates a qcow2 overlay on top of `HDD_1` in `raid/`. The baseline `.img` file is **never modified**. This means:

- Every test run starts from the same disk state
- The first-boot wizard runs every time (the image has never been booted)
- No cleanup or reset is needed between runs

### Needle Matching Internals

When `assert_screen('tag', timeout)` is called:

1. isotovideo captures the current VNC framebuffer
2. It searches `NEEDLES_DIR` for all needle JSONs containing the requested tag
3. For each candidate needle, it compares the defined `match` regions of the PNG against the corresponding regions of the live screenshot
4. Similarity is scored 0.0 to 1.0. The `match` field in the JSON (e.g., 90) sets the threshold as a percentage
5. If any candidate scores above threshold, the match succeeds
6. `assert_screen` retries every ~0.5s until timeout

**Multiple match regions** are ANDed -- all must pass. **Exclude regions** are masked out before comparison (useful for dynamic content like clocks or usernames).

### Capture Script Deduplication

`tests/capture_screenshots.pm` captures at 1fps but deduplicates by MD5 hash:

```perl
sub _snap {
    save_screenshot;
    # ... read the newest PNG, compute MD5 ...
    if ($hash eq $last_hash) {
        unlink $file;    # identical frame, discard
    } else {
        $last_hash = $hash;
    }
}
```

This typically reduces ~600 raw frames to ~300 unique frames, making it practical to browse and identify the right frame for each needle.

### Needle Markers

The capture script emits `diag("NEEDLE: <tag>")` immediately before the interaction that leaves each UI state. This means the most recent SNAP at the time of the marker is the correct frame for that needle. `update-needles.sh` exploits this by scanning the log for SNAP/NEEDLE pairs.

### Needle Tooling

Three tools automate the needle lifecycle:

- **`update-needles.sh`** -- Parses `autoinst-log.txt` for `SNAP:` / `NEEDLE:` pairs, copies the right frame to `needles/<tag>.png`, and generates a default JSON (center match region, status bar exclude) for any needle that doesn't have one yet. Existing hand-tuned JSONs are preserved unless `--force-json` is passed.

- **`needle-editor.py`** -- Tkinter GUI for drawing match/exclude regions on a needle PNG. Left-drag draws match regions, right-drag draws exclude regions. Supports undo (Ctrl+Z), threshold adjustment (+/-), and saves directly to the needle JSON (Ctrl+S). Requires `Pillow`.

- **`check-needle.py`** -- Offline needle validator. Computes normalized cross-correlation between a needle's match regions and a target screenshot, reporting per-region similarity scores and pass/fail. Useful for iterating on match regions without running the full test suite. Requires `Pillow` and `numpy`.

## Development Workflow

### Adding a Test

1. Write the `.pm` file in `tests/` following the basetest pattern
2. Add `diag("NEEDLE: <tag>")` markers in the appropriate `capture_screenshots*.pm` for each new UI state
3. Run `./capture-screenshots.sh <suite>` then `./update-needles.sh` to auto-generate needle PNG+JSON pairs
4. Fine-tune with `./needle-editor.py` if needed; validate with `./check-needle.py`
5. Register the module in `main.pm` via `loadtest` under the appropriate suite branch

### Modifying the Boot Flow

If the system-under-test changes its boot sequence:

1. Update the relevant `tests/capture_screenshots*.pm` to drive through the new flow (add `NEEDLE:` markers for new screens)
2. Run `./capture-screenshots.sh <suite>` then `./update-needles.sh`
3. Update the corresponding test modules to match
4. Fine-tune any needles that need custom match/exclude regions

### Testing Your Changes

```bash
# Quick check: run a test suite
./run-tests.sh wayland /path/to/regolith.img
./run-tests.sh x11 /path/to/regolith.img

# Debug: watch the VM via VNC while tests run
vncviewer :91 &
./run-tests.sh x11 /path/to/regolith.img
```

### Common testapi Functions

```perl
assert_screen('tag', $timeout);        # Wait for match, fail on timeout
check_screen('tag', $timeout);         # Wait for match, return bool
send_key('ret');                       # Single keystroke
send_key('super-ret');                 # Modifier + key
send_key('shift-tab');                 # Modifier + key
type_string('hello');                  # Type a string
wait_still_screen($stilltime, $timeout); # Wait for screen to stabilize
save_screenshot;                       # Save current frame to results
sleep $seconds;                        # Raw delay (use sparingly)
```

Key names: `ret`, `tab`, `esc`, `up`, `down`, `left`, `right`, `super`, `shift`, `ctrl`, `alt`, `backspace`, `delete`, `f1`-`f12`.

Modifiers are joined with `-`: `super-ret`, `ctrl-alt-delete`, `shift-tab`.

## File Reference

| File | Purpose |
|------|---------|
| `main.pm` | Test scheduler. Loaded by isotovideo. Routes to suite-specific modules via `TEST_SUITE`. Must end with `1;`. |
| `run-tests.sh` | Shell wrapper: accepts suite name and disk image path, resolves template vars, runs isotovideo |
| `capture-screenshots.sh` | Shell wrapper for capture mode. Accepts suite name and disk image path. Kills stale processes first. |
| `vars-test-wayland.json` | isotovideo config template for Wayland test runs. No `SCHEDULE` key. |
| `vars-test-x11.json` | isotovideo config template for X11 test runs. Sets `TEST_SUITE: "x11"`. No `SCHEDULE` key. |
| `vars-capture-wayland.json` | isotovideo config template for Wayland capture runs. Sets `SCHEDULE`. |
| `vars-capture-x11.json` | isotovideo config template for X11 capture runs. Sets `SCHEDULE`. |
| `update-needles.sh` | Parses capture log, auto-copies frames to `needles/`, generates default JSONs |
| `needle-editor.py` | Visual GUI for drawing match/exclude regions on needle PNGs |
| `check-needle.py` | Offline needle validator: compares needle vs screenshot, reports similarity |
| `tests/first_boot_setup.pm` | Drives the whiptail first-boot wizard (shared across suites) |
| `tests/login.pm` | Drives LightDM login with session picker (Wayland suite) |
| `tests/login_default_session.pm` | Drives LightDM login using default session (X11 suite) |
| `tests/verify_desktop.pm` | Verifies desktop loaded, opens terminal, runs printenv (Wayland suite) |
| `tests/verify_desktop_x11.pm` | Verifies desktop loaded, opens terminal (X11 suite) |
| `tests/capture_screenshots.pm` | 1fps capture with MD5 deduplication (Wayland suite) |
| `tests/capture_screenshots_x11.pm` | 1fps capture with MD5 deduplication (X11 suite) |
| `needles/*.png` | Reference screenshots for visual matching |
| `needles/*.json` | Match region definitions (coordinates, thresholds, tags) |
| `.gitignore` | Excludes disk images, OVMF vars, runtime artifacts |

## Gotchas and Lessons Learned

- **`main.pm` must end with `1;`** -- Perl requires modules to return a true value.
- **`CASEDIR` must be the amphi directory** (`.github/amphi/`), not `tests/`. The `loadtest` regex needs a directory component in the path.
- **`SCHEDULE` in a vars-test file will skip your tests.** The guard in `main.pm` checks for `SCHEDULE` -- if set, no `loadtest` calls execute. Only `vars-capture-*.json` files should have `SCHEDULE`.
- **Needle match regions containing dynamic text will cause flaky tests.** Use `exclude` regions to mask usernames, timestamps, or other variable content (see the `setup-password` needle).
- **VNC display number must not conflict** with other VNC servers. Default is `:91` (port 5991). Change the `VNC` key in vars JSON if needed.
- **The disk image is never modified.** os-autoinst uses qcow2 overlays. But the image must exist and be a valid bootable disk.
