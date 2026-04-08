#!/usr/bin/env bash
# ci/build-package.sh
#
# Builds a single Arch Linux package using makepkg inside an archlinux container.
# Must be run as root (the container default).
# Creates a non-root 'builder' user internally since makepkg refuses to run as root.
#
# Usage: build-package.sh <package-name>
#
# Environment variables:
#   LOCAL_PKG_DIR  Optional path to a directory containing .pkg.tar.zst files
#                  to install via pacman -U before running makepkg. Used for
#                  building simplejpeg after a freshly-built cmake-python-distributions.

set -euo pipefail

PKGNAME="${1:?Package name required}"
REPO_ROOT="$(pwd)"
PKG_DIR="${REPO_ROOT}/packages/${PKGNAME}"
LOCAL_PKG_DIR="${LOCAL_PKG_DIR:-}"

# ── Validate ──────────────────────────────────────────────────────────────────
if [[ ! -f "${PKG_DIR}/PKGBUILD" ]]; then
  echo "ERROR: ${PKG_DIR}/PKGBUILD not found" >&2
  exit 1
fi

# ── Initialize pacman keyring ─────────────────────────────────────────────────
echo "==> Initializing pacman keyring"
pacman-key --init
pacman-key --populate archlinux

# ── Full system upgrade + base-devel ─────────────────────────────────────────
echo "==> Upgrading system and installing base-devel"
pacman -Syu --noconfirm --noprogressbar
pacman -S --noconfirm --noprogressbar --needed \
  base-devel \
  git \
  sudo

# ── Install any locally-built prerequisite packages ───────────────────────────
# Used when simplejpeg is built right after cmake-python-distributions.
if [[ -n "$LOCAL_PKG_DIR" && -d "$LOCAL_PKG_DIR" ]]; then
  shopt -s nullglob
  local_pkgs=("${LOCAL_PKG_DIR}"/*.pkg.tar.zst)
  shopt -u nullglob
  if [[ ${#local_pkgs[@]} -gt 0 ]]; then
    echo "==> Installing local prerequisite packages from ${LOCAL_PKG_DIR}"
    pacman -U --noconfirm --noprogressbar "${local_pkgs[@]}"
  fi
fi

# ── Create non-root builder user ──────────────────────────────────────────────
echo "==> Creating builder user"
useradd -m builder
# Passwordless sudo for pacman only (makepkg -s calls pacman to install deps)
echo "builder ALL=(ALL) NOPASSWD: /usr/bin/pacman" > /etc/sudoers.d/builder-pacman
chmod 0440 /etc/sudoers.d/builder-pacman

# ── Copy the entire package directory to the builder's home ──────────────────
# makepkg writes src/ and pkg/ subdirectories here, and expects all source
# files (patches, .install, etc.) to be co-located with the PKGBUILD.
cp -r "${PKG_DIR}" /home/builder/pkgbuild
chown -R builder:builder /home/builder/pkgbuild

# ── Handle rustup makedepends ─────────────────────────────────────────────────
# rustup is in Arch's 'extra' repo (since 2024). Packages that list rustup as
# a makedep need an active Rust toolchain before makepkg runs.
if grep -q 'makedepends.*rustup\|rustup.*makedepends' "${PKG_DIR}/PKGBUILD" 2>/dev/null; then
  echo "==> rustup detected in makedepends — installing and activating stable toolchain"
  pacman -S --noconfirm --noprogressbar --needed rustup
  # Install the toolchain as builder so it lands in ~builder/.rustup
  su - builder -c "rustup default stable"
fi

# ── Add astromatto repo to pull already compiled packages ─────────────────────
sed -i 's|\[core\]|\[astromatto\]\nSigLevel = Optional TrustAll\nServer = http://astroarch.astromatto.com:9000/$arch\n\n\[core\]|' /etc/pacman.conf
pacman -Sy

# ── Build ─────────────────────────────────────────────────────────────────────
echo "==> Building package: ${PKGNAME}"
su - builder -c "
  set -euo pipefail
  cd /home/builder/pkgbuild
  makepkg -s --noconfirm --noprogressbar --log
"

# ── Collect artifacts ─────────────────────────────────────────────────────────
echo "==> Copying built packages back to workspace"
find /home/builder/pkgbuild -maxdepth 1 -name '*.pkg.tar.zst' \
  -exec cp {} "${PKG_DIR}/" \;

echo "==> Built artifacts:"
ls -lh "${PKG_DIR}"/*.pkg.tar.zst
