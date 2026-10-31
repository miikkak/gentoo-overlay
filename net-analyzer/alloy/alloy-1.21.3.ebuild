# Copyright 2026 Miikka Karhuluoma
# Distributed under the terms of the MIT License

EAPI=8

inherit go-module

DESCRIPTION="Grafana Alloy telemetry collector"
HOMEPAGE="https://grafana.com/docs/alloy/"
# ${P}-deps.tar.xz is the `go mod vendor` tree of the collector/ module, built
# and attached to a GitHub release of this overlay by scripts/go-bump.sh.
SRC_URI="
	https://github.com/grafana/alloy/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz
	https://github.com/miikkak/gentoo-overlay/releases/download/${P}/${P}-deps.tar.xz
"

LICENSE="Apache-2.0"
# vendored Go modules, checked from the LICENSE files in vendor/: MIT, BSD, ISC
# and MPL-2.0 (HashiCorp libraries), plus github.com/grafana/loki/v3, whose
# logql, querier and storage packages are AGPL-3 (no LICENSE_APACHE2 there)
LICENSE+=" AGPL-3 BSD ISC MIT MPL-2.0"
SLOT="0"
KEYWORDS="amd64 arm64"
RESTRICT="test"

RDEPEND="
	acct-group/alloy
	acct-user/alloy
"
BDEPEND=">=dev-lang/go-1.27.3"

src_compile() {
	local pkg=github.com/grafana/alloy/internal/build
	# Neither the web UI (embedalloyui) nor the Beyla eBPF binary is embedded:
	# the UI is a debugging aid and Beyla is not used. The binary is the
	# collector/ module, upstream's own entry point for release builds.
	cd collector || die
	ego build -mod=vendor -trimpath -buildmode=pie \
		-tags gore2regex \
		-ldflags "
			-X ${pkg}.Version=v${PV}
			-X github.com/grafana/alloy/syntax/internal/stdlib.Version=v${PV}
		" \
		-o ../alloy .
}

src_install() {
	dosbin alloy
	newinitd "${FILESDIR}/alloy.initd" alloy
	dodoc README.md
}

pkg_pretend() {
	# acct-user.eclass sets the account's groups to exactly ACCT_USER_GROUPS, so
	# supplementary groups an existing alloy user needs (for example adm, to read
	# logs) are removed when the package is installed.
	local groups
	groups="$(id -nG alloy 2>/dev/null | tr ' ' '\n' | grep -v -x alloy | paste -sd ' ' || true)"
	if [[ -n ${groups} ]]; then
		ewarn "The existing alloy user is in these groups beyond alloy: ${groups}"
		ewarn "They are removed on install unless listed in make.conf:"
		ewarn "  ACCT_USER_ALLOY_GROUPS_ADD=\"${groups}\""
	fi
}

pkg_postinst() {
	elog "The config (${EROOT}/etc/alloy/config.alloy) and ${EROOT}/etc/conf.d/alloy"
	elog "are per-host and not installed by the package."
	elog "Start with: rc-service alloy restart"

	if [[ -x ${EROOT}/usr/local/sbin/alloy ]]; then
		ewarn "A manually installed ${EROOT}/usr/local/sbin/alloy exists; remove it once"
		ewarn "the packaged binary is in use. Any ALLOY_BINARY override pointing at"
		ewarn "/usr/local/sbin must go too, or the init script keeps starting the old binary."
	fi
}
