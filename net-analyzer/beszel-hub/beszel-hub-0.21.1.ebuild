# Copyright 2026 Miikka Karhuluoma
# Distributed under the terms of the MIT License

EAPI=8

inherit go-module

DESCRIPTION="Beszel server monitoring hub (web UI and API)"
HOMEPAGE="https://beszel.dev https://github.com/henrygd/beszel"
# deps: the `go mod vendor` tree. web: the built, architecture-independent
# internal/site/dist UI that upstream embeds with go:embed. Both are produced
# by scripts/beszel-build-distfiles.sh and attached to a GitHub release of this
# overlay, because building the UI needs the network (npm/bun).
SRC_URI="
	https://github.com/henrygd/beszel/archive/refs/tags/v${PV}.tar.gz -> beszel-${PV}.tar.gz
	https://github.com/miikkak/gentoo-overlay/releases/download/beszel-${PV}/beszel-${PV}-deps.tar.xz
	https://github.com/miikkak/gentoo-overlay/releases/download/beszel-${PV}/beszel-${PV}-web.tar.xz
"
S="${WORKDIR}/beszel-${PV}"

LICENSE="MIT"
# vendored Go modules and bundled UI dependencies
LICENSE+=" Apache-2.0 BSD BSD-2 ISC MPL-2.0"
SLOT="0"
KEYWORDS="~amd64 ~arm64"
# Upstream tests need network and a running environment
RESTRICT="test"

RDEPEND="
	acct-group/beszel
	acct-user/beszel
"
BDEPEND=">=dev-lang/go-1.27.2"

src_prepare() {
	default
	# the web tarball unpacks to ${WORKDIR}/dist
	mv "${WORKDIR}/dist" internal/site/dist || die
}

src_compile() {
	ego build -mod=vendor -trimpath -buildmode=pie \
		-o beszel ./internal/cmd/hub
}

src_install() {
	dobin beszel
	newinitd "${FILESDIR}/beszel.initd" beszel
	newconfd "${FILESDIR}/beszel.confd" beszel
	dodoc readme.md
}

pkg_postinst() {
	elog "Set BESZEL_APP_URL in ${EROOT}/etc/conf.d/beszel, then start:"
	elog "  rc-service beszel start"

	if [[ -x ${EROOT}/usr/local/sbin/beszel ]]; then
		ewarn "A manually installed ${EROOT}/usr/local/sbin/beszel exists."
		ewarn "The init script now defaults to ${EROOT}/usr/bin/beszel;"
		ewarn "remove the old binary and any BESZEL_BINARY override."
	fi
}
