# Amphi User Manual

## Table of Contents

- [Overview](#overview)
- [Prerequisites and Setup](#prerequisites-and-setup)
- [Running Tests](#running-tests)
- [Understanding Test Results](#understanding-test-results)
- [Needle Management](#needle-management)
  - [What Are Needles?](#what-are-needles)
  - [Regenerating Needles After UI Changes](#regenerating-needles-after-ui-changes)
  - [Needle JSON Format](#needle-json-format)
  - [Tuning Match Regions](#tuning-match-regions)
- [Adding and Modifying Tests](#adding-and-modifying-tests)
  - [Adding a New First-Boot Setup Screen](#adding-a-new-first-boot-setup-screen)
  - [Adding Post-Login Tests](#adding-post-login-tests)
  - [Creating a New Test Module](#creating-a-new-test-module)
- [Continuous Integration](#continuous-integration)
- [Troubleshooting](#troubleshooting)

---

## Overview

Amphi uses **os-autoinst/isotovideo** to boot a Regolith Linux disk image in QEMU, then drives the UI via simulated keyboard input while verifying screen state through visual needle matching. The test flow is:

1. UEFI boot from disk image
2. First-boot setup wizard (welcome, locale, timezone, hostname, user, password)
3. LightDM login (session selection, username, password)
4. Desktop verification (Regolith loads, terminal opens, `printenv` runs)

## Prerequisites and Setup

### System Packages

```bash
sudo apt-get install os-autoinst ovmf qemu-system-x86
```

### Disk Image

Place a Regolith Linux `.img` file somewhere accessible on disk. Pass its path as the second argument to `run-tests.sh`.

### Configuration

The vars JSON files (`vars-test-<suite>.json`, `vars-capture-<suite>.json`) use `@PLACEHOLDER@` tokens for paths that vary between environments. The run scripts substitute these automatically:

| Placeholder | Resolved to |
|-------------|-------------|
| `@CASEDIR@` | Project root (derived from script location) |
| `@NEEDLES_DIR@` | Needles directory (CLI argument or `./needles`) |
| `@HDD_1@` | Disk image path (CLI argument) |
| `@UEFI_PFLASH_VARS@` | Fresh OVMF vars copy in amphi directory |

Other settings (RAM, CPUs, VNC display, etc.) can be edited directly in the vars JSON files.

## Running Tests

### Test Suites

Amphi provides multiple test suites for different Regolith sessions:

| Suite | Session | Login | Desktop verification |
|-------|---------|-------|---------------------|
| `wayland` | Regolith/Wayland | Session picker → select Wayland | Desktop, terminal, `printenv` |
| `x11` | Regolith/X11 (default) | Default session, no picker | Desktop, terminal |

### Running a Test Suite

```bash
./run-tests.sh <suite> <disk-image> [needles-dir]
```

Arguments:
- **`suite`** (required) -- Test suite to run: `wayland`, `x11`
- **`disk-image`** (required) -- Path to the Regolith Linux `.img` file to test
- **`needles-dir`** (optional) -- Path to needle directory; defaults to `./needles`

Examples:

```bash
./run-tests.sh wayland /path/to/regolith.img
./run-tests.sh x11 /path/to/regolith.img
```

This script:
1. Copies a fresh OVMF vars file (clean UEFI state)
2. Resolves the suite name to `vars-test-<suite>.json`, substitutes paths, and writes `vars.json`
3. Runs `isotovideo`

Exit code 0 means all tests passed. Non-zero means a test failed.

### Capture Mode (Screenshot Collection)

```bash
./capture-screenshots.sh <suite> <disk-image> [needles-dir]
```

Arguments:
- **`suite`** (required) -- Capture suite to run: `wayland`, `x11`
- **`disk-image`** (required) -- Path to the Regolith Linux `.img` file
- **`needles-dir`** (optional) -- Path to needle directory; defaults to `./needles`

This boots the VM and captures deduplicated screenshots at 1fps through the entire flow. Use these screenshots to create or update needle images. Output goes to `testresults/`.

### Watching the VM

During either mode, you can connect to the VNC display:

```bash
vncviewer :91
```

The VNC display number is set by the `VNC` key in the vars JSON files.

## Understanding Test Results

After a run, check:

- **`testresults/`** -- Per-test result directories containing screenshots taken at each `assert_screen` / `check_screen` call
- **`autoinst-status.json`** -- Overall pass/fail status
- **`video.webm`** -- Screen recording of the entire run
- **Exit code** -- 0 = all tests passed, non-zero = failure

When a needle match fails, the test result directory contains the actual screenshot that was captured. Compare it against the expected needle to see what changed.

## Needle Management

### What Are Needles?

A needle is a PNG + JSON pair in the `needles/` directory. The PNG is a reference screenshot. The JSON defines which rectangular regions of the PNG to match against, and with what confidence threshold.

Each needle is identified by its **tag** (defined in the JSON). Test code references needles by tag:

```perl
assert_screen('setup-welcome', 180);  # waits up to 180s for a match
```

### Current Needles

**Shared needles** (used by all suites):

| Tag | Description |
|-----|-------------|
| `setup-welcome` | First-boot wizard welcome screen |
| `setup-locale-menu` | Locale selection menu |
| `setup-timezone-menu` | Timezone selection menu |
| `setup-hostname` | Hostname input prompt |
| `setup-username` | Username input prompt |
| `setup-password` | Password input prompt |
| `setup-confirm-password` | Password confirmation prompt |
| `setup-complete` | Setup complete / reboot screen |
| `lightdm-greeter` | LightDM login screen with username field |
| `lightdm-password-prompt` | LightDM password entry |

**Wayland suite needles:**

| Tag | Description |
|-----|-------------|
| `regolith-desktop` | Desktop with keybinding overlay visible |
| `regolith-desktop-clean` | Clean desktop (overlay dismissed) |
| `terminal-open` | Terminal emulator window open |
| `printenv-output` | Terminal showing printenv output |

**X11 suite needles** (`x11-` prefix):

| Tag | Description |
|-----|-------------|
| `x11-regolith-desktop` | Desktop with keybinding overlay visible |
| `x11-regolith-desktop-clean` | Clean desktop (overlay dismissed) |
| `x11-terminal-open` | Terminal emulator window open |

### Regenerating Needles After UI Changes

When the Regolith UI changes (new theme, different widget layout, updated wizard screens), needles must be regenerated. The automated workflow handles most of the tedious work:

**Step 1: Run the capture script**

```bash
./capture-screenshots.sh wayland /path/to/regolith.img
```

Wait for it to complete. This drives through the full flow, saving deduplicated 1fps screenshots to `testresults/`. The capture script emits `NEEDLE: <tag>` markers in the log at each UI state.

**Step 2: Auto-update needles**

```bash
./update-needles.sh
```

This parses the capture log, finds the correct frame for each needle tag, and:
- Copies the frame PNG to `needles/<tag>.png` (always overwrites)
- Generates a default JSON with sensible match regions if no JSON exists yet

Existing hand-tuned JSON files are preserved. Use `--force-json` to overwrite them.

**Step 3: Fine-tune match regions (if needed)**

If a needle needs custom match/exclude regions (e.g., to mask dynamic content), use the visual editor:

```bash
./needle-editor.py needles/setup-password
```

Controls:
- **Left-drag** -- Draw a match region (green)
- **Right-drag** -- Draw an exclude region (red)
- **Click** -- Select a region
- **Delete** -- Remove selected region
- **+/-** -- Adjust match threshold (+/- 5%)
- **Ctrl+S** -- Save JSON
- **Ctrl+Z** -- Undo

**Step 4: Quick-check individual needles**

Before running the full test suite, validate specific needles against captured frames:

```bash
./check-needle.py needles/setup-welcome testresults/capture_screenshots-42.png
```

This reports per-region similarity scores and pass/fail status. Much faster than a full test run for iterating on match regions.

**Step 5: Verify with full suite**

```bash
./run-tests.sh wayland /path/to/regolith.img
```

### Manual Needle Creation

If you need to create a needle without the automated workflow (e.g., for a frame the capture script doesn't cover), you can still do it manually:

```bash
# Copy a frame
cp testresults/capture_screenshots-NNN.png needles/my-needle.png

# Either generate a default JSON:
# (run update-needles.sh, which skips existing PNGs but generates missing JSONs)

# Or use the visual editor to create regions from scratch:
./needle-editor.py needles/my-needle
```

### Needle JSON Format

Each needle JSON file has this structure:

```json
{
  "area": [
    {
      "type": "match",
      "xpos": 278,
      "ypos": 255,
      "width": 470,
      "height": 250,
      "match": 90
    },
    {
      "type": "exclude",
      "xpos": 0,
      "ypos": 740,
      "width": 1024,
      "height": 28
    }
  ],
  "tags": ["setup-welcome"],
  "properties": []
}
```

**Fields:**

- **`area`** -- Array of rectangular regions:
  - `type`: `"match"` (must match) or `"exclude"` (ignored during comparison)
  - `xpos`, `ypos`: Top-left corner (pixels, 0-indexed from top-left)
  - `width`, `height`: Region size in pixels
  - `match`: Minimum similarity percentage (0-100). Higher = stricter. 80-90 is typical.
- **`tags`** -- Array of tag strings. Test code references needles by these tags.
- **`properties`** -- Usually empty. Can contain os-autoinst-specific metadata.

### Tuning Match Regions

**General principles:**

- Match only the stable, distinctive parts of the screen. Avoid matching areas with dynamic content (clocks, timestamps, usernames).
- Use `exclude` regions to mask out dynamic content within a match area.
- Lower the `match` threshold (e.g., 75-80) for screens with minor variations. Raise it (90+) for screens that must match precisely.
- Multiple `match` regions are ANDed -- all must pass.

**Example: The `setup-password` needle** uses exclude regions to mask the title text that contains the username (which varies between runs):

```json
{
  "area": [
    {"type": "match", "xpos": 315, "ypos": 300, "width": 410, "height": 150, "match": 80},
    {"type": "exclude", "xpos": 315, "ypos": 310, "width": 410, "height": 40},
    {"type": "exclude", "xpos": 315, "ypos": 345, "width": 410, "height": 40}
  ],
  "tags": ["setup-password"],
  "properties": []
}
```

This matches the password dialog area but excludes the lines containing "Enter a password for &lt;username&gt;:" so the needle works regardless of the username entered earlier in the wizard.

## Adding and Modifying Tests

### Adding a New First-Boot Setup Screen

If the Regolith first-boot wizard adds a new screen (e.g., a "select desktop layout" step):

**1. Update the capture script first:**

Edit `tests/capture_screenshots.pm` to drive through the new screen and emit a marker:

```perl
# ... after timezone in the capture flow ...
_watch(5);
diag("NEEDLE: setup-layout");
send_key('down');      # layout selection
send_key('ret');
```

**2. Run capture and auto-generate the needle:**

```bash
./capture-screenshots.sh wayland /path/to/regolith.img
./update-needles.sh
```

This automatically creates `needles/setup-layout.png` and a default `needles/setup-layout.json`.

**3. Fine-tune the needle (if needed):**

```bash
./needle-editor.py needles/setup-layout
```

**3. Update the test module:**

Edit `tests/first_boot_setup.pm` and insert the new screen interaction at the right point in the sequence:

```perl
# ... after timezone selection ...
assert_screen('setup-layout', 30);
send_key('down');      # select desired layout option
send_key('ret');
# ... continue to hostname ...
```

**4. Update the capture script:**

Edit `tests/capture_screenshots.pm` to drive through the new screen during capture:

```perl
# ... after timezone in the capture flow ...
_watch(5);
send_key('down');      # layout selection
send_key('ret');
```

**5. Register in main.pm (if adding a new test module):**

If you created a new `.pm` file instead of editing an existing one, add it to `main.pm`:

```perl
loadtest "tests/first_boot_setup.pm";
loadtest "tests/new_module.pm";       # add here
loadtest "tests/login.pm";
```

The `loadtest` path must be relative to `CASEDIR` and include the `tests/` prefix.

### Adding Post-Login Tests

To add verification steps after login (e.g., checking that a specific application launches):

**1. Edit `tests/verify_desktop.pm`** to add steps, or create a new test module:

```perl
# tests/verify_apps.pm
use base "basetest";
use strict;
use warnings;
use testapi;

sub run {
    # Launch an application (example: file manager)
    send_key('super-e');           # or whatever keybinding
    assert_screen('file-manager-open', 30);
    wait_still_screen(2, 10);

    # Verify something in the app
    assert_screen('file-manager-home', 15);

    # Close it
    send_key('super-shift-q');     # Regolith close window
    wait_still_screen(2, 10);
}

sub test_flags { return { fatal => 1 }; }

1;
```

**2. Create needles** for each new `assert_screen` tag. Add `NEEDLE:` markers to the appropriate `capture_screenshots*.pm`, run `./capture-screenshots.sh <suite>`, then `./update-needles.sh`. Fine-tune with `./needle-editor.py` if needed.

**3. Register in `main.pm`:**

```perl
loadtest "tests/first_boot_setup.pm";
loadtest "tests/login.pm";
loadtest "tests/verify_desktop.pm";
loadtest "tests/verify_apps.pm";      # new module
```

### Creating a New Test Module

Every test module follows this pattern:

```perl
use base "basetest";
use strict;
use warnings;
use testapi;

sub run {
    # Your test logic here
    # Use: assert_screen, check_screen, send_key, type_string, wait_still_screen
}

sub test_flags { return { fatal => 1 }; }

1;
```

**Key testapi functions:**

| Function | Description |
|----------|-------------|
| `assert_screen('tag', timeout)` | Wait for needle match; fail test if timeout |
| `check_screen('tag', timeout)` | Like assert_screen but returns true/false instead of failing |
| `send_key('key')` | Send a single keystroke (e.g., `'ret'`, `'tab'`, `'super-ret'`, `'shift-tab'`) |
| `type_string('text')` | Type a string character by character |
| `wait_still_screen(stilltime, timeout)` | Wait until the screen stops changing |
| `save_screenshot` | Save current screen to results |

**test_flags options:**

- `fatal => 1` -- Abort the entire suite if this test fails
- `fatal => 0` -- Continue to next test even if this one fails

## Continuous Integration

Amphi is integrated into the ISO builder's GitHub Actions CI pipeline. Two workflows in `.github/workflows/` use amphi to verify built images:

### PR Verification (`pr-verify.yml`)

Runs on every pull request. The workflow:

1. **`build`** -- Builds the ISO image using debootstrap/debootstick
2. **`test-x11`** -- Downloads the built image and runs `./run-tests.sh x11` from `.github/amphi/`
3. **`test-wayland`** -- Downloads the built image and runs `./run-tests.sh wayland` from `.github/amphi/`

X11 and Wayland tests run in parallel after the build completes. Both must pass for the PR checks to go green.

### Gated Release (`release.yml`)

Runs on tag pushes matching `v*`. The workflow:

1. **`build`** -- Builds the ISO image tagged with the release version
2. **`test-x11`** -- Runs X11 verification against the built image
3. **`test-wayland`** -- Runs Wayland verification against the built image
4. **`release`** -- Creates a GitHub Release with the zipped image. **Only runs if both test jobs pass.**

### CI Requirements

- **KVM access is required.** The test jobs run `sudo chmod 666 /dev/kvm` to enable it on GitHub-hosted `ubuntu-24.04` runners. Without hardware virtualization, QEMU falls back to software emulation which is far too slow for real-time UI interaction.
- **Path configuration.** The vars JSON files use `@PLACEHOLDER@` tokens that the run scripts resolve automatically from CLI arguments. No manual `sed` or path fixup is needed.
- **Timeout.** Each test job has a 30-minute timeout. The full boot + wizard + login + verification takes 5-15 minutes depending on hardware.
- **Artifacts.** Test results (`testresults/`, `video.webm`, `autoinst-status.json`) are always uploaded as artifacts, even on failure, for debugging.

## Troubleshooting

### Needle match fails with low similarity score

- Run `capture-screenshots.sh <suite>` and compare the new capture against the existing needle PNG
- If the UI changed: replace the needle PNG with the new frame
- If the UI is the same but minor rendering differences cause low scores: lower the `match` threshold in the needle JSON, or narrow the match region to a more stable area

### `isotovideo` exits immediately

- Check that `vars.json` exists in the amphi directory (the run scripts create it from `vars-test-<suite>.json`)
- Verify all paths in vars JSON are absolute and point to existing files
- Ensure `os-autoinst` is installed: `which isotovideo`

### QEMU fails to start

- Verify OVMF firmware exists: `ls /usr/share/OVMF/OVMF_CODE_4M.fd`
- Check that the disk image exists at the path specified in `HDD_1`
- Ensure you have KVM access: `ls /dev/kvm`

### `loadtest` path errors

- `loadtest` paths must match the pattern `\w+/[^/]+\.p[my]` -- they need a directory component and `.pm` extension
- Paths are relative to `CASEDIR` (the amphi directory)
- Correct: `loadtest "tests/first_boot_setup.pm"`
- Wrong: `loadtest "first_boot_setup"` or `loadtest "first_boot_setup.pm"`

### Test hangs waiting for a screen

- Connect via VNC (`vncviewer :91`) to see the current VM state
- The VM may be at a different screen than expected -- check if the flow changed
- Increase the timeout in `assert_screen` if the VM is slow
