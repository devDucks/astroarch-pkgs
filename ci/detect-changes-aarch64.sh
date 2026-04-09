#!/usr/bin/env bash
# ci/detect-changes-aarch64.sh
#
# Detects which packages changed since the last commit and classifies them
# for the CI build order. Emits GitHub Actions outputs to $GITHUB_OUTPUT.
#
# Usage: detect-changes-aarch64.sh [package-name-override]
#   package-name-override: if provided, skip git diff and build only this package.

set -euo pipefail

# ── Packages that are x86_64-only — skip on aarch64 CI ───────────────────────
X86_64_ONLY=(
  # none currently
)

# ── cmake-python-distributions must be built before simplejpeg ───────────────
CMAKE_DEP_DIR="cmake-python-distributions"
NEEDS_CMAKE_DIRS=(simplejpeg)

is_x86_64_only() {
  local pkg="$1"
  for skip in "${X86_64_ONLY[@]}"; do
    [[ "$skip" == "$pkg" ]] && return 0
  done
  return 1
}

is_needs_cmake() {
  local pkg="$1"
  for dep in "${NEEDS_CMAKE_DIRS[@]}"; do
    [[ "$dep" == "$pkg" ]] && return 0
  done
  return 1
}

to_json_array() {
  # Converts bash array arguments to a JSON array string, e.g. ["a","b","c"]
  local arr=("$@")
  if [[ ${#arr[@]} -eq 0 ]]; then
    echo "[]"
    return
  fi
  local json="["
  for i in "${!arr[@]}"; do
    [[ $i -gt 0 ]] && json+=","
    json+="\"${arr[$i]}\""
  done
  json+="]"
  echo "$json"
}

# ── Determine list of packages to consider ───────────────────────────────────
OVERRIDE="${1:-}"
CHANGED_PKGS=()

if [[ -n "$OVERRIDE" ]]; then
  CHANGED_PKGS=("$OVERRIDE")
else
    # Determine base commit for the diff.
    # 1. Use BEFORE_SHA (from github.event.before on push events) if it's a real SHA and was fetched.
    # 2. Fall back to HEAD~1 if it exists (fetch-depth: 2 covers the common case).
    # 3. If neither is available (e.g. initial push to a brand-new branch), emit no packages.
    BASE_REF=""
    if [[ -n "${BEFORE_SHA:-}" && "$BEFORE_SHA" != "0000000000000000000000000000000000000000" ]]; then
        if git cat-file -e "${BEFORE_SHA}" 2>/dev/null; then
            BASE_REF="$BEFORE_SHA"
	else
            echo "BEFORE_SHA ($BEFORE_SHA) not in local history (shallow clone?), trying HEAD~1" >&2
        fi
    fi
    if [[ -z "$BASE_REF" ]]; then
        if git rev-parse --verify HEAD~1 &>/dev/null; then
            BASE_REF="HEAD~1"
        else
            echo "HEAD~1 not accessible and no usable BEFORE_SHA — cannot detect changes." >&2
            echo "Tip: re-run with an explicit package name via workflow_dispatch." >&2
        fi
    fi
    CHANGED_FILES=()
    if [[ -n "$BASE_REF" ]]; then
	mapfile -t CHANGED_FILES < <(git diff --name-only "$BASE_REF" HEAD)
    fi
    declare -A seen
    for f in "${CHANGED_FILES[@]}"; do
	if [[ "$f" =~ ^packages/([^/]+)/ ]]; then
	    pkg="${BASH_REMATCH[1]}"
	    if [[ -z "${seen[$pkg]+x}" ]]; then
		seen["$pkg"]=1
		CHANGED_PKGS+=("$pkg")
	    fi
	fi
    done
fi

if [[ ${#CHANGED_PKGS[@]} -eq 0 ]]; then
  echo "No changed packages detected." >&2
fi

# ── Classify packages into buckets ───────────────────────────────────────────
pkgs_no_dep=()
has_cmake_dep=false
has_needs_cmake=false

for pkg in "${CHANGED_PKGS[@]}"; do
  if is_x86_64_only "$pkg"; then
    echo "Skipping x86_64-only package: $pkg" >&2
    continue
  fi

  if [[ "$pkg" == "$CMAKE_DEP_DIR" ]]; then
    has_cmake_dep=true
  elif is_needs_cmake "$pkg"; then
    has_needs_cmake=true
  else
    # Verify the package directory actually exists before adding it
    if [[ -f "packages/$pkg/PKGBUILD" ]]; then
      pkgs_no_dep+=("$pkg")
    else
      echo "WARNING: packages/$pkg/PKGBUILD not found, skipping" >&2
    fi
  fi
done

PKG_NO_DEP_JSON=$(to_json_array "${pkgs_no_dep[@]+"${pkgs_no_dep[@]}"}")

# ── Debug summary ─────────────────────────────────────────────────────────────
echo "=== CI package classification (aarch64) ==="
echo "  Regular packages (matrix):        ${PKG_NO_DEP_JSON}"
echo "  cmake-python-distributions:       ${has_cmake_dep}"
echo "  simplejpeg (needs cmake first):   ${has_needs_cmake}"

# ── Emit outputs ──────────────────────────────────────────────────────────────
{
  echo "pkgs_no_dep=${PKG_NO_DEP_JSON}"
  echo "has_cmake_dep=${has_cmake_dep}"
  echo "has_needs_cmake=${has_needs_cmake}"
} >> "$GITHUB_OUTPUT"
