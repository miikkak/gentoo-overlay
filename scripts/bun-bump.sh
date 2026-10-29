#!/usr/bin/env bash
# Bump dev-lang/bun-bin to an upstream oven-sh/bun release.
#
#   - downloads the linux x64 and aarch64 zips and checks each against the
#     release's SHASUMS256.txt (same origin as the zips, so this catches
#     corruption and wrong files, not a compromised release; the .asc
#     signature is not verified)
#   - renames the ebuild and regenerates the thin Manifest
#
# Usage: bun-bump.sh [version]
# Without a version, the latest upstream release is used. Prints "bumped=<ver>"
# on stdout when something changed, "bumped=" otherwise.
set -Eeuo pipefail
trap 'echo "Error on line $LINENO" >&2' ERR

dist=""
readonly UPSTREAM_REPO="oven-sh/bun"
readonly PKGDIR="dev-lang/bun-bin"

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly root
# shellcheck source=scripts/lib/overlay.sh
. "${root}/scripts/lib/overlay.sh"

current_version() {
  local f
  for f in "${root}/${PKGDIR}"/bun-bin-*.ebuild; do
    f="${f##*/bun-bin-}"
    printf '%s\n' "${f%.ebuild}"
    return
  done
}

# expected_sha256 <SHASUMS256.txt> <asset-file-name>
expected_sha256() {
  awk -v want="$2" '{ n = $2; sub(/^\*/, "", n); sub(/^.*\//, "", n); if (n == want) print $1 }' "$1"
}

main() {
  local version="${1:-}"
  version="${version#bun-v}"
  version="${version#v}"

  if [[ -z "${version}" ]]; then
    step "Querying latest upstream release"
    version="$(gh api "repos/${UPSTREAM_REPO}/releases/latest" --jq .tag_name)"
    version="${version#bun-v}"
  fi
  require_version "${version}"

  local current
  current="$(current_version)"
  echo "current=${current} upstream=${version}" >&2
  if ! is_newer "${current}" "${version}"; then
    echo "Nothing to do: ${version} is not newer than ${current}" >&2
    echo "bumped="
    return
  fi

  dist="$(mktemp -d)"
  trap 'rm -rf "${dist}"' EXIT
  local base="https://github.com/${UPSTREAM_REPO}/releases/download/bun-v${version}"

  step "Fetching SHASUMS256.txt for bun-v${version}"
  curl -fsSL --retry 3 -o "${dist}/SHASUMS256.txt" "${base}/SHASUMS256.txt"

  local -a files=()
  local pair arch asset local_file want got
  for pair in amd64:bun-linux-x64 arm64:bun-linux-aarch64; do
    arch="${pair%%:*}"
    asset="${pair#*:}.zip"
    local_file="${dist}/bun-bin-${version}-${arch}.zip"

    step "Downloading ${asset}"
    curl -fsSL --retry 3 -o "${local_file}" "${base}/${asset}"

    want="$(expected_sha256 "${dist}/SHASUMS256.txt" "${asset}")"
    [[ -n "${want}" ]] || {
      echo "SHASUMS256.txt has no entry for ${asset}" >&2
      exit 1
    }
    got="$(sha256sum "${local_file}" | cut -d' ' -f1)"
    [[ "${got}" == "${want}" ]] || {
      echo "SHA256 mismatch for ${asset}: expected ${want}, got ${got}" >&2
      exit 1
    }
    echo "sha256 ok: ${asset}" >&2
    files+=("${local_file}")
  done

  step "Updating ebuild and Manifest"
  git -C "${root}" mv \
    "${PKGDIR}/bun-bin-${current}.ebuild" "${PKGDIR}/bun-bin-${version}.ebuild"
  write_manifest "${PKGDIR}" "${files[@]}"

  echo "bumped=${version}"
}

main "$@"
