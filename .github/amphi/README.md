# Amphi - Automated UI Testing for Regolith Linux

Amphi is an automated visual test suite for [Regolith Linux](https://regolith-linux.org/) disk images, built on [os-autoinst](https://github.com/os-autoinst/os-autoinst) / isotovideo. It boots a UEFI disk image in QEMU, drives the full first-boot wizard, logs in via LightDM, and verifies the desktop environment is functional -- all without human interaction.

Amphi lives inside the ISO builder repository at `.github/amphi/` and is integrated into the CI pipeline via GitHub Actions. Both X11 and Wayland test suites run automatically on every PR and must pass before a release can be published.

## Test Suites

| Suite | Session | Login | Desktop verification |
|-------|---------|-------|---------------------|
| `wayland` | Regolith/Wayland | Session picker → select Wayland | Desktop, terminal, `printenv` |
| `x11` | Regolith/X11 (default) | Default session, no picker | Desktop, terminal |

## Prerequisites

- Debian/Ubuntu host with:
  - `os-autoinst` (`sudo apt-get install os-autoinst`)
  - `ovmf` (`sudo apt-get install ovmf`)
  - `qemu-system-x86` (`sudo apt-get install qemu-system-x86`)
- A Regolith Linux disk image (`.img`)

## Quick Start

```bash
# 1. From the repository root, navigate to the amphi directory
cd .github/amphi

# 2. Run a test suite (wayland or x11) against a disk image
./run-tests.sh wayland /path/to/regolith-3_4-debian-13-automation-test-1.img
./run-tests.sh x11 /path/to/regolith-3_4-debian-13-automation-test-1.img
```

Results appear in `testresults/`. Exit code 0 means all tests passed.

## Updating Needles After UI Changes

When the system-under-test UI changes, needle images must be regenerated:

```bash
# From .github/amphi/:

# 1. Run the capture script to get fresh screenshots
./capture-screenshots.sh wayland /path/to/regolith.img

# 2. Auto-copy frames to needles/ and generate default JSONs
./update-needles.sh

# 3. Fine-tune match regions visually (if needed)
./needle-editor.py needles/setup-welcome

# 4. Quick-check a needle against a screenshot (without running the full suite)
./check-needle.py needles/setup-welcome testresults/some-screenshot.png
```

See [MANUAL.md](MANUAL.md) for the full needle update workflow.

## Project Structure

```
.github/amphi/
  main.pm                        # Test scheduler (loads test modules by suite)
  run-tests.sh                   # Run a test suite
  capture-screenshots.sh         # Capture mode for generating needle images
  update-needles.sh              # Auto-copy captured frames to needles/ + generate JSON
  needle-editor.py               # Visual editor for needle match/exclude regions
  check-needle.py                # Quick single-needle similarity check
  vars-test-wayland.json         # isotovideo config for Wayland test runs
  vars-test-x11.json             # isotovideo config for X11 test runs
  vars-capture-wayland.json      # isotovideo config for Wayland capture runs
  vars-capture-x11.json          # isotovideo config for X11 capture runs
  tests/
    first_boot_setup.pm          # First-boot wizard automation (shared)
    login.pm                     # LightDM login with session selection (Wayland)
    login_default_session.pm     # LightDM login using default session (X11)
    verify_desktop.pm            # Desktop + terminal verification (Wayland)
    verify_desktop_x11.pm        # Desktop + terminal verification (X11)
    capture_screenshots.pm       # Screenshot capture (Wayland)
    capture_screenshots_x11.pm   # Screenshot capture (X11)
  needles/
    setup-*.png/json             # First-boot wizard needles (shared)
    lightdm-*.png/json           # LightDM login needles (shared)
    regolith-*.png/json          # Wayland desktop needles
    terminal-open.png/json       # Wayland terminal needle
    printenv-output.png/json     # Wayland printenv needle
    x11-*.png/json               # X11 desktop/terminal needles
```

## Documentation

- **[MANUAL.md](MANUAL.md)** -- Detailed user guide: needle management, adding tests, CI setup
- **[CONTRIBUTING.md](CONTRIBUTING.md)** -- Technical internals, architecture, development guide
