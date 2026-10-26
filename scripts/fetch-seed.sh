#!/bin/bash
# Downloads the fibber compiler named by the file SEED, verifies its sha256 and unpacks it. Prints the path of its bin/fibc on standard output
# (everything else goes to standard error). Adapted from fibber's scripts/fetch-seed.sh (fibber ce3d8314); unlike fibber's, it keeps the
# library the release ships: lair is compiled with that library, and this repository has no fibber lib/ to put in its place.
# usage: scripts/fetch-seed.sh DIR [SEEDFILE]        SEEDFILE defaults to the SEED at the repository root
# SEED is a table with one url and one sha256 per platform (PLATFORM is OS-ARCH as `uname` says, lower case: linux-x86_64, darwin-arm64):
#   url.PLATFORM=...      a release tarball (any curl URL)
#   sha256.PLATFORM=...   64 hex digits
# The unqualified `url=` and `sha256=` lines are linux-x86_64's (read when `url.linux-x86_64=` is absent). The platform is this machine's, or
# FIB_PLATFORM. A platform with no row is an error that says so. A cache (FIB_SEED_CACHE, DIR/SHA256/seed.tar.gz) is tried first, and a
# download is stored there when the directory is writable.
set -eu
root=$(cd "$(dirname "$0")/.." && pwd)
dir=${1:?usage: fetch-seed.sh DIR [SEEDFILE]}
seed=${2:-$root/SEED}
plat=${FIB_PLATFORM:-$(echo "$(uname -s)-$(uname -m)" | tr 'A-Z' 'a-z')}
case $plat in linux-amd64) plat=linux-x86_64 ;; darwin-aarch64) plat=darwin-arm64 ;; esac
url=$(sed -n "s/^url\.$plat=//p" "$seed")
want=$(sed -n "s/^sha256\.$plat=//p" "$seed")
if [ -z "$url" ] && [ "$plat" = linux-x86_64 ]; then url=$(sed -n 's/^url=//p' "$seed"); want=$(sed -n 's/^sha256=//p' "$seed"); fi
if [ -z "$url" ]; then echo "fetch-seed: no seed for $plat in $seed" >&2; exit 2; fi
case $want in
  *[!0-9a-f]*|'') echo "fetch-seed: $seed has no sha256 of 64 hex digits for $plat ([$want])" >&2; exit 2 ;;
esac
if [ "${#want}" -ne 64 ]; then echo "fetch-seed: sha256 in $seed is not 64 hex digits" >&2; exit 2; fi
mkdir -p "$dir"
tarball=$dir/seed.tar.gz
cached=
if [ -n "${FIB_SEED_CACHE:-}" ] && [ -f "$FIB_SEED_CACHE/$want/seed.tar.gz" ]; then
  cp "$FIB_SEED_CACHE/$want/seed.tar.gz" "$tarball" && cached=1
fi
if [ -z "$cached" ]; then
  curl -fsSL --retry 3 -o "$tarball" "$url" >&2
fi
if command -v sha256sum >/dev/null 2>&1; then got=$(sha256sum "$tarball" | cut -d' ' -f1); else got=$(shasum -a 256 "$tarball" | cut -d' ' -f1); fi
if [ "$got" != "$want" ]; then
  echo "fetch-seed: sha256 mismatch for $url: got $got, SEED says $want" >&2
  rm -f "$tarball"
  exit 1
fi
if [ -z "$cached" ] && [ -n "${FIB_SEED_CACHE:-}" ] && mkdir -p "$FIB_SEED_CACHE/$want" 2>/dev/null; then
  cp "$tarball" "$FIB_SEED_CACHE/$want/seed.tar.gz" 2>/dev/null || true
fi
tar -xzf "$tarball" -C "$dir"
fibc=$(find "$dir" -path '*/bin/fibc' -type f | head -n 1)
if [ -z "$fibc" ]; then echo "fetch-seed: no bin/fibc in the tarball" >&2; exit 1; fi
cd "$(dirname "$fibc")" && echo "$PWD/fibc"
