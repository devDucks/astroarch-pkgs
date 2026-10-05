# CLAUDE.md — astroarch-pkgs

This file provides context for AI assistants working in this repository.

## Project Overview

**astroarch-pkgs** is an Arch Linux PKGBUILD repository that maintains 42+ packages for astrophotography software. It is part of the [AstroArch](https://astroarch.org) project.

- **Maintainer:** Mattia Procopio (astro.matto) `<matto.astro@gmail.com>`
- **License:** MIT (2022)
- **Target architectures:** `x86_64` and `aarch64` (Raspberry Pi / ARM)
- **Purpose:** Provide up-to-date Arch Linux packages for astronomy imaging, telescope control, and related tools

## Repository Structure

```
astroarch-pkgs/
├── CLAUDE.md           # This file
├── LICENSE             # MIT License
├── README.md           # Brief overview and Python rebuild list
├── .gitmodules         # Defines kmsxx-git as a git submodule
└── packages/           # One directory per maintained package
    └── <package-name>/
        ├── PKGBUILD    # Required: Arch Linux build instructions
        ├── *.install   # Optional: pacman install hooks
        └── README.md   # Optional: special build notes
```

## Package Inventory

### Core Astronomy Software
| Package | Description |
|---------|-------------|
| `kstars` | Desktop Planetarium (KDE), stable release |
| `kstars-git` | KStars development (git) version |
| `phd2` | OpenPHDGuiding — autoguider for telescope tracking |
| `siril` | Astrophotography image processing |
| `stellarsolver` | Offline astrometric plate solver (SExtractor + Astrometry.net) |
| `ekosdebugger` | INDI/Ekos debugging tools |

### INDI Ecosystem (Instrument Neutral Distributed Interface)
| Package | Description |
|---------|-------------|
| `libindi` | Core INDI library, stable |
| `libindi-git` | INDI library, development version |
| `indi-3rdparty-libs` | Third-party INDI support libraries |
| `indi-3rdparty-libs-git` | Third-party INDI libraries, git version |
| `indi-3rdparty-drivers` | Third-party INDI hardware drivers |
| `indi-3rdparty-drivers-git` | Third-party drivers, git version |
| `indiserver-ui` | INDI server management UI |
| `indiwebmanager` | Web-based INDI server manager |
| `pylibcamera` | Python INDI driver for Raspberry Pi cameras |

### Raspberry Pi / Camera Support
| Package | Description |
|---------|-------------|
| `libcamera` | Camera framework (RPi and more) |
| `libpisp` | Raspberry Pi ISP processing library |
| `rpicam-apps` | Raspberry Pi camera applications |
| `python-picamera2` | Python Picamera2 library |
| `python-v4l2` | Python V4L2 bindings |
| `python-rpi-gpio` | Raspberry Pi GPIO Python library |
| `lgpio` | GPIO library for local GPIO access |
| `kmsxx-git` | KMS/DRM library (git submodule from AUR) |
| `python-pidng-git` | PIDNG raw image format library |

### Python Packages
| Package | Description |
|---------|-------------|
| `python-av` | PyAV — Python bindings for FFmpeg |
| `simplejpeg` | Fast JPEG encoding/decoding |
| `websockify` | WebSocket to TCP proxy |
| `cmake-python-distributions` | CMake Python package |
| `astropy_iers_data` | Astropy IERS Earth orientation data |

### System Tools and Utilities
| Package | Description |
|---------|-------------|
| `astroarch-onboarding` | AstroArch installer and setup tool |
| `aa-status-notifications` | System status notification service |
| `astrolink4pi` | Astrolink hardware controller |
| `astro_dmx` | DMX lighting control for observatories |
| `astromonitor` | System monitoring tool |
| `collimation-circles` | Telescope collimation aid |
| `fire_capture` | Planetary/solar capture tool |
| `rustdesk-bin` | Remote desktop (aarch64 prebuilt binary) |
| `ckbcomp` | XKB keyboard compiler |
| `fxload` | Firmware loader for USB devices |

### ARM Cross-Compilation
| Package | Description |
|---------|-------------|
| `arm-linux-gnueabihf-binutils` | ARM cross-compilation binutils |
| `libtiff5` | TIFF library (ARM target) |

## PKGBUILD Conventions

### Naming Conventions
- `python-<name>` — Python packages
- `<name>-git` — VCS (git) tracking packages, built from latest commit
- `<name>-bin` — Pre-built binary packages (e.g., from .deb/.rpm)
- `<name>-3rdparty-` — Third-party variants (INDI ecosystem)

### Standard PKGBUILD Fields
```bash
pkgname=<name>
pkgver=<upstream-version>
pkgrel=1                          # Reset to 1 on pkgver bump; increment for rebuild-only
epoch=<n>                         # Only if needed to force upgrade ordering
pkgdesc='Short description'
arch=(x86_64 aarch64)             # Most packages target both
url='https://upstream.example/'
license=(GPL-2.0-or-later)
depends=(...)
makedepends=(...)
source=(https://... or git+https://...)
sha256sums=(...)
```

### Build Patterns

**CMake (most packages: KStars, PHD2, INDI, Siril, etc.):**
```bash
build() {
  cmake -B build -S $pkgname-$pkgver \
    -DBUILD_TESTING=OFF \
    -DCMAKE_C_FLAGS="$CFLAGS -ffat-lto-objects" \
    -DCMAKE_CXX_FLAGS="$CXXFLAGS -ffat-lto-objects"
  cmake --build build
}

package() {
  DESTDIR="$pkgdir" cmake --install build
}
```

**Python packages (python-av, python-picamera2, etc.):**
```bash
build() {
  python -m build --wheel --no-isolation
}

package() {
  python -m installer --destdir="$pkgdir" dist/*.whl
}
```

**Legacy Make:**
```bash
build() { make; }
package() { make DESTDIR="$pkgdir" install; }
```

**Binary repackaging (rustdesk-bin, fire_capture):**
- Download `.deb` or `.rpm`
- Extract and install files into `$pkgdir` manually

### Install Hook Files (`.install`)
Used by: `lgpio`, `indi-3rdparty-drivers`, `aa-status-notifications`, `fire_capture`

Standard hook functions:
```bash
post_install() { ... }
post_upgrade() { ... }
post_remove() { ... }
```

Common uses: `systemctl daemon-reload`, `systemctl enable`, `setcap` for privileged operations.

## Development Workflows

### Building a Package
```bash
cd packages/<package-name>
makepkg -si           # Build and install
makepkg -s            # Build only (no install)
makepkg --nobuild     # Download sources only
```

### Updating a Package

**Version bump (new upstream release):**
1. Update `pkgver` to new version
2. Update `source` URL if needed
3. Reset `pkgrel=1`
4. Update `sha256sums` — run `updpkgsums` in the package dir
5. Test with `makepkg -s`

**Rebuild only (no upstream change, e.g., dependency update):**
1. Increment `pkgrel` (e.g., `pkgrel=2`)
2. Build with `makepkg -s`

### Git VCS Packages (`-git`)
- `pkgver` is updated automatically by `pkgver()` function during build
- `sha256sums=('SKIP')` is used since source is a git clone

### Git Submodule (kmsxx-git)
```bash
git submodule update --init    # Initialize after cloning
git submodule update --remote  # Update to latest upstream
```

## Critical: Python Minor Version Upgrades

When Arch Linux updates Python to a new minor version (e.g., 3.12 → 3.13), these packages **must be rebuilt in this order**:

1. **`cmake-python-distributions`** — rebuild FIRST (other packages depend on it)
2. **`simplejpeg`** — depends on cmake-python-distributions; install step 1 before building this
3. `pylibcamera`
4. `python-av`
5. `python-picamera2`
6. `python-pidng-git`
7. `python-rpi-gpio`
8. `python-v4l2`
9. `websockify`

**Procedure for cmake-python-distributions + simplejpeg:**
```bash
# Step 1: build and install cmake-python-distributions
cd packages/cmake-python-distributions && makepkg -si

# Step 2: now build simplejpeg
cd packages/simplejpeg && makepkg -si
```

## Architecture Notes

- Most packages support both `x86_64` and `aarch64`
- `rustdesk-bin` targets `aarch64` only (ARM binary)
- `arm-linux-gnueabihf-binutils` is a cross-compilation toolchain
- When modifying `cmake` flags, ensure they work on both architectures
- Raspberry Pi-specific packages: `libcamera`, `libpisp`, `rpicam-apps`, `python-picamera2`, `kmsxx-git`, `lgpio`, `python-rpi-gpio`

## Key Dependency Clusters

**KDE/Qt Stack** (KStars): Qt6-base, Qt6-declarative, Qt6-websockets, Qt6-svg, Qt6-datavis3d, KDE Frameworks

**Astronomy Libraries**: cfitsio, wcslib, libraw, stellarsolver, libnova, gsl

**Imaging**: libjpeg-turbo, libtiff5, libxisf, opencv, ffmpeg

**Hardware/Drivers**: libusb, libgphoto2, libftdi, rtl-sdr, gpsd, libv4l

## Conventions for AI Assistants

- **Do not create files** outside `packages/<name>/` without explicit need
- **Version bumps**: always update `pkgver` + reset `pkgrel=1` + update `sha256sums`
- **Rebuild-only changes**: only increment `pkgrel`, do not change `pkgver`
- **Architecture safety**: verify build flags work for both `x86_64` and `aarch64`
- **Adding packages**: follow naming conventions; add to appropriate category above
- **Checksums**: use `updpkgsums` to regenerate rather than computing manually
- **No Makefile**: there is no top-level build orchestration; each package is built independently with `makepkg`
- **Branch naming**: development branches follow `claude/<description>-<id>` pattern
