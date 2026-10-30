#!/usr/bin/env bash
# Source every ebuild in the overlay through Portage and check what a reviewer
# would otherwise have to eyeball:
#
#   - the ebuild loads (syntax errors, unknown eclasses, bad EAPI)
#   - every name in LICENSE exists in a licenses/ directory (::gentoo or this
#     overlay), so a guessed or misspelled name fails here instead of at emerge
#   - KEYWORDS is not empty
#
# Needs a Gentoo host with portageq and a synced ::gentoo tree. Sourcing an
# ebuild runs its global-scope code, so only run this on trusted checkouts.
#
# Usage: check-ebuilds.sh
set -Eeuo pipefail
trap 'echo "Error on line $LINENO" >&2' ERR

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly root
# shellcheck source=scripts/lib/overlay.sh
. "${root}/scripts/lib/overlay.sh"

# license_names <LICENSE value>
# One license name per line: operators, groups and USE conditionals dropped.
license_names() {
  local -a tokens=()
  local token
  read -r -a tokens <<<"$1"
  for token in "${tokens[@]}"; do
    case "${token}" in
      '||' | '(' | ')' | *'?') ;;
      *) printf '%s\n' "${token}" ;;
    esac
  done
}

main() {
  command -v portageq >/dev/null || {
    echo "portageq not found: this check needs a Gentoo host" >&2
    exit 2
  }
  local gentoo
  gentoo="$(portageq get_repo_path / gentoo)" || {
    echo "No ::gentoo tree found; run emerge --sync first" >&2
    exit 2
  }
  local repo_name
  repo_name="$(<"${OVERLAY_ROOT}/profiles/repo_name")"

  # Register this checkout as the overlay without touching /etc/portage
  PORTAGE_REPOSITORIES="$(printf '[DEFAULT]\nmain-repo = gentoo\n\n[gentoo]\nlocation = %s\n\n[%s]\nlocation = %s\nmasters = gentoo\n' \
    "${gentoo}" "${repo_name}" "${OVERLAY_ROOT}")"
  export PORTAGE_REPOSITORIES

  local -i checked=0 failed=0
  local ebuild pf category cpv license keywords name
  for ebuild in "${OVERLAY_ROOT}"/*/*/*.ebuild; do
    [[ -e "${ebuild}" ]] || continue
    pf="$(basename "${ebuild}" .ebuild)"
    category="$(basename "$(dirname "$(dirname "${ebuild}")")")"
    cpv="${category}/${pf}"
    ((++checked))

    if ! license="$(portageq metadata / ebuild "${cpv}" LICENSE 2>&1)"; then
      echo "FAIL ${cpv}: does not load: ${license}" >&2
      ((++failed))
      continue
    fi
    keywords="$(portageq metadata / ebuild "${cpv}" KEYWORDS)"

    # Gentoo's own acct-user and acct-group ebuilds define no LICENSE either
    if [[ -z "${license}" && "${category}" != acct-user && "${category}" != acct-group ]]; then
      echo "FAIL ${cpv}: LICENSE is empty" >&2
      ((++failed))
      continue
    fi
    if [[ -z "${keywords}" ]]; then
      echo "FAIL ${cpv}: KEYWORDS is empty" >&2
      ((++failed))
      continue
    fi

    local bad=0
    while IFS= read -r name; do
      if [[ ! -f "${gentoo}/licenses/${name}" && ! -f "${OVERLAY_ROOT}/licenses/${name}" ]]; then
        echo "FAIL ${cpv}: unknown license ${name}" >&2
        bad=1
      fi
    done < <(license_names "${license}")
    if ((bad)); then
      ((++failed))
      continue
    fi
    echo "ok   ${cpv}: ${license}" >&2
  done

  if ((checked == 0)); then
    echo "No ebuilds found under ${OVERLAY_ROOT}" >&2
    exit 1
  fi
  echo "${checked} ebuilds checked, ${failed} failed" >&2
  ((failed == 0))
}

main "$@"
