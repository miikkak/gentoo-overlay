#!/usr/bin/env bash
# Build the offline distfiles the Beszel ebuilds need, from an upstream tag:
#   beszel-<ver>-deps.tar.xz  go mod vendor tree (agent + hub)
#   beszel-<ver>-web.tar.xz   built UI (internal/site/dist), hub only
#
# Usage: beszel-build-distfiles.sh <version> <output-dir>
set -Eeuo pipefail
trap 'echo "Error on line $LINENO" >&2' ERR

readonly UPSTREAM="https://github.com/henrygd/beszel"
work=""

step() { printf '\n==> %s\n' "$*" >&2; }

# Reproducible tarball: sorted entries, fixed owner and mtime, single-threaded xz.
make_tarball() {
  local out="$1" dir="$2" path="$3"
  tar --sort=name --owner=0 --group=0 --numeric-owner --mtime='@0' \
    -C "${dir}" -cf - "${path}" | xz -9e -T1 >"${out}"
}

main() {
  if (($# != 2)); then
    echo "Usage: ${0##*/} <version> <output-dir>" >&2
    exit 2
  fi
  local version="${1#v}" outdir="$2"
  mkdir -p "${outdir}"
  outdir="$(cd "${outdir}" && pwd)"

  work="$(mktemp -d)"
  trap 'rm -rf "${work}"' EXIT

  step "Cloning ${UPSTREAM} v${version}"
  git clone --quiet --depth 1 --branch "v${version}" "${UPSTREAM}" "${work}/src"

  step "Vendoring Go modules (go mod vendor)"
  (cd "${work}/src" && go mod vendor)
  mkdir -p "${work}/stage/beszel-${version}"
  mv "${work}/src/vendor" "${work}/stage/beszel-${version}/vendor"
  make_tarball "${outdir}/beszel-${version}-deps.tar.xz" "${work}/stage" "beszel-${version}"

  step "Building web UI"
  local site="${work}/src/internal/site"
  if command -v bun >/dev/null 2>&1; then
    (cd "${site}" && bun install --frozen-lockfile && bun run build)
  else
    (cd "${site}" && npm ci && npm run build)
  fi
  [[ -f "${site}/dist/index.html" ]] || {
    echo "UI build produced no dist/index.html" >&2
    exit 1
  }
  make_tarball "${outdir}/beszel-${version}-web.tar.xz" "${site}" dist

  step "Done"
  ls -l "${outdir}/beszel-${version}-deps.tar.xz" "${outdir}/beszel-${version}-web.tar.xz" >&2
}

main "$@"
