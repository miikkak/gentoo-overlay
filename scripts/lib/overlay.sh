# shellcheck shell=bash
# Helpers shared by the scripts/*-bump.sh version bump scripts.

OVERLAY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly OVERLAY_ROOT

step() { printf '\n==> %s\n' "$*" >&2; }

# make_tarball <out.tar.xz> <dir> <path-in-dir>
# Reproducible: sorted entries, fixed owner and mtime, single-threaded xz, so a
# rebuild of the same input has the same hash as the published distfile.
make_tarball() {
  local out="$1" dir="$2" path="$3"
  tar --sort=name --owner=0 --group=0 --numeric-owner --mtime='@0' \
    -C "${dir}" -cf - "${path}" | xz -9e -T1 >"${out}"
}

# True (exit 0) when $2 is a strictly newer version than $1.
is_newer() {
  [[ "$1" != "$2" && "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -n1)" == "$2" ]]
}

# Exit 1 unless $1 looks like a plain dotted version.
require_version() {
  [[ "$1" =~ ^[0-9]+(\.[0-9]+)*$ ]] || {
    echo "Refusing odd version string: $1" >&2
    exit 1
  }
}

# "DIST <name> <size> BLAKE2B <hash> SHA512 <hash>"
manifest_line() {
  local file="$1"
  printf 'DIST %s %s BLAKE2B %s SHA512 %s\n' \
    "${file##*/}" "$(stat -c %s "${file}")" \
    "$(b2sum "${file}" | cut -d' ' -f1)" "$(sha512sum "${file}" | cut -d' ' -f1)"
}

# write_manifest <category/package> <distfile>...
# Distfiles are listed under the name Portage will use (SRC_URI "->" name), so
# the local file name has to match it.
write_manifest() {
  local pkgdir="$1"
  shift
  local f
  for f in "$@"; do manifest_line "${f}"; done | sort >"${OVERLAY_ROOT}/${pkgdir}/Manifest"
}
