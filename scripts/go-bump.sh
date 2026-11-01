#!/usr/bin/env bash
# Bump an ebuild for a pure-Go program whose only offline input is the
# `go mod vendor` tree.
#
#   - builds <name>-<ver>-deps.tar.xz from the upstream tag (or reuses the
#     overlay release if it exists, so published hashes never change)
#   - uploads it to the overlay release "<name>-<ver>" (unless --no-upload)
#   - renames the ebuild and regenerates the thin Manifest
#
# Usage: go-bump.sh [--no-upload --out DIR] <package> [version]
# --out DIR keeps a copy of the generated distfile; --no-upload requires it.
# Without a version, the latest upstream release is used. Prints "bumped=<ver>"
# on stdout when something changed, "bumped=" otherwise.
set -Eeuo pipefail
trap 'echo "Error on line $LINENO" >&2' ERR

dist=""
readonly OVERLAY_REPO="miikkak/gentoo-overlay"

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly root
# shellcheck source=scripts/lib/overlay.sh
. "${root}/scripts/lib/overlay.sh"

# Packages handled by this script: name -> category/package and upstream repo.
pkg_dir() {
  case "$1" in
    actionlint) echo "dev-util/actionlint" ;;
    alloy) echo "net-analyzer/alloy" ;;
    chroma) echo "app-text/chroma" ;;
    falco) echo "dev-util/falco" ;;
    rcon-cli) echo "games-util/rcon-cli" ;;
    mc-conn-poller) echo "net-analyzer/mc-conn-poller" ;;
    *) return 1 ;;
  esac
}

pkg_repo() {
  case "$1" in
    actionlint) echo "rhysd/actionlint" ;;
    alloy) echo "grafana/alloy" ;;
    chroma) echo "alecthomas/chroma" ;;
    falco) echo "ysugimoto/falco" ;;
    rcon-cli) echo "miikkak/rcon-cli" ;;
    mc-conn-poller) echo "miikkak/mc-conn-poller" ;;
    *) return 1 ;;
  esac
}

# Directory of the Go module that is built, relative to the repository root.
# The vendor tree has to sit next to its go.mod, so the ebuild finds it at
# ${S}/<dir>/vendor.
pkg_module_dir() {
  case "$1" in
    alloy) echo "collector" ;;
    chroma) echo "cmd/chroma" ;;
    *) echo "." ;;
  esac
}

# Release tags that are considered, as an extended regular expression. Empty
# means the repository's latest release. Chroma's latest release is a v3 alpha
# that is not flagged as a prerelease, and only the stable v2 line is packaged.
pkg_tag_filter() {
  case "$1" in
    chroma) echo '^v2\.[0-9]+\.[0-9]+$' ;;
    *) echo "" ;;
  esac
}

# latest_tag <repo> <filter>
# Newest non-prerelease tag matching the filter, or the latest release's tag.
latest_tag() {
  local repo="$1" filter="$2"
  if [[ -z "${filter}" ]]; then
    gh api "repos/${repo}/releases/latest" --jq .tag_name
    return
  fi
  gh api "repos/${repo}/releases" --paginate \
    --jq '.[] | select(.prerelease | not) | select(.draft | not) | .tag_name' |
    { grep -E "${filter}" || true; } | sort -V | tail -n1
}

# prepare_source <name> <source dir>
# `go mod vendor` ignores build tags, so it also resolves go:embed patterns of
# files that are never compiled. Alloy's embedalloyui file embeds the built web
# UI, which is deliberately not part of the package: stub the directory.
prepare_source() {
  case "$1" in
    alloy)
      mkdir -p "$2/internal/web/ui/dist"
      echo "stub for go mod vendor; the web UI is not built" >"$2/internal/web/ui/dist/placeholder"
      ;;
  esac
}

# build_deps <name> <repo> <version> <out.tar.xz>
build_deps() {
  local name="$1" repo="$2" version="$3" out="$4" work moddir
  moddir="$(pkg_module_dir "${name}")"
  # Inside ${dist}, so the script's EXIT trap removes it even when a step fails
  work="$(mktemp -d -p "${dist}")"

  step "Cloning ${repo} v${version}"
  git clone --quiet --depth 1 --branch "v${version}" "https://github.com/${repo}" "${work}/src"

  step "Vendoring Go modules (go mod vendor)"
  prepare_source "${name}" "${work}/src"
  (cd "${work}/src/${moddir}" && go mod vendor)
  mkdir -p "${work}/stage/${name}-${version}/${moddir}"
  mv "${work}/src/${moddir}/vendor" "${work}/stage/${name}-${version}/${moddir}/vendor"
  make_tarball "${out}" "${work}/stage" "${name}-${version}"
  rm -rf "${work}"
}

main() {
  local upload=true name="" version="" out=""
  while (($#)); do
    case "$1" in
      --no-upload) upload=false ;;
      --out)
        [[ -n "${2:-}" && "${2:-}" != -* ]] || {
          echo "--out needs a directory" >&2
          exit 2
        }
        out="$2"
        shift
        ;;
      -*)
        echo "Unknown option: $1" >&2
        exit 2
        ;;
      *)
        if [[ -z "${name}" ]]; then name="$1"; else version="${1#v}"; fi
        ;;
    esac
    shift
  done
  [[ -n "${name}" ]] || {
    echo "Usage: ${0##*/} [--no-upload --out DIR] <package> [version]" >&2
    exit 2
  }
  # Without an upload the distfile would only exist in the temporary directory
  if [[ "${upload}" == false && -z "${out}" ]]; then
    echo "--no-upload needs --out DIR to keep the generated distfile" >&2
    exit 2
  fi

  local pkgdir repo
  pkgdir="$(pkg_dir "${name}")" || {
    echo "Unknown package: ${name}" >&2
    exit 2
  }
  repo="$(pkg_repo "${name}")"

  if [[ -z "${version}" ]]; then
    step "Querying latest upstream release of ${repo}"
    version="$(latest_tag "${repo}" "$(pkg_tag_filter "${name}")")"
    [[ -n "${version}" ]] || {
      echo "No matching release found for ${repo}" >&2
      exit 1
    }
    version="${version#v}"
  fi
  require_version "${version}"
  # An explicit version has to pass the same filter, so a manual bump cannot
  # move a package off its supported release line.
  local tag_filter
  tag_filter="$(pkg_tag_filter "${name}")"
  if [[ -n "${tag_filter}" && ! "v${version}" =~ ${tag_filter} ]]; then
    echo "Version ${version} does not match the release line of ${name} (${tag_filter})" >&2
    exit 2
  fi

  local current
  current="$(ebuild_version "${pkgdir}" "${name}")"
  echo "current=${current} upstream=${version}" >&2
  if ! is_newer "${current}" "${version}"; then
    echo "Nothing to do: ${version} is not newer than ${current}" >&2
    echo "bumped="
    return
  fi

  dist="$(mktemp -d)"
  trap 'rm -rf "${dist}"' EXIT
  local tag="${name}-${version}"
  local deps="${dist}/${name}-${version}-deps.tar.xz"

  if gh release view "${tag}" --repo "${OVERLAY_REPO}" >/dev/null 2>&1; then
    step "Reusing distfile from existing release ${tag}"
    gh release download "${tag}" --repo "${OVERLAY_REPO}" --dir "${dist}" \
      --pattern "${name}-${version}-deps.tar.xz"
    [[ -s "${deps}" ]] || {
      echo "Release ${tag} is missing ${deps##*/}" >&2
      exit 1
    }
  else
    build_deps "${name}" "${repo}" "${version}" "${deps}"
    if [[ "${upload}" == true ]]; then
      step "Publishing release ${tag}"
      gh release create "${tag}" --repo "${OVERLAY_REPO}" \
        --title "${name} ${version} distfiles" \
        --notes "Offline build input for ${pkgdir}-${version} (go mod vendor tree). Generated by scripts/go-bump.sh." \
        "${deps}"
    fi
  fi

  [[ -z "${out}" ]] || save_artifacts "${out}" "${deps}"

  step "Fetching upstream source archive"
  curl -fsSL --retry 3 -o "${dist}/${name}-${version}.tar.gz" \
    "https://github.com/${repo}/archive/refs/tags/v${version}.tar.gz"

  step "Updating ebuild and Manifest"
  git -C "${root}" mv \
    "${pkgdir}/${name}-${current}.ebuild" "${pkgdir}/${name}-${version}.ebuild"
  write_manifest "${pkgdir}" "${dist}/${name}-${version}.tar.gz" "${deps}"

  echo "bumped=${version}"
}

main "$@"
