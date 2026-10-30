# Copyright 2026 Miikka Karhuluoma
# Distributed under the terms of the MIT License

EAPI=8

inherit go-module

DESCRIPTION="Protocol-level Minecraft connectivity poller reporting to Healthchecks.io"
HOMEPAGE="https://github.com/miikkak/mc-conn-poller"
# ${P}-deps.tar.xz is the `go mod vendor` tree, built and attached to a GitHub
# release of this overlay by scripts/go-bump.sh.
SRC_URI="
	https://github.com/miikkak/mc-conn-poller/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz
	https://github.com/miikkak/gentoo-overlay/releases/download/${P}/${P}-deps.tar.xz
"

LICENSE="MIT"
# vendored Go modules (MIT, Apache-2.0 and BSD-3-Clause, checked from vendor/)
LICENSE+=" Apache-2.0 BSD"
SLOT="0"
KEYWORDS="amd64 arm64"
RESTRICT="test"

BDEPEND=">=dev-lang/go-1.26.6"

src_prepare() {
	default
	# upstream's sample init script defaults to the /usr/local install
	sed -i 's|/usr/local/sbin/mc-conn-poller|/usr/sbin/mc-conn-poller|' \
		etc/init.d/mc-conn-poller || die
}

src_compile() {
	ego build -mod=vendor -trimpath -buildmode=pie \
		-ldflags "-X main.version=v${PV}" \
		-o mc-conn-poller ./cmd/mc-conn-poller
}

src_install() {
	dosbin mc-conn-poller
	doinitd etc/init.d/mc-conn-poller

	# The config and /etc/conf.d/mc-conn-poller hold per-host values (the
	# Healthchecks.io ping URL is a secret) and are managed outside the
	# package, so only examples are installed.
	newdoc etc/conf.d/mc-conn-poller conf.d.example
	dodoc README.md etc/mc-conn-poller.yaml.example
	# keep the examples uncompressed: pkg_postinst prints their paths
	docompress -x "/usr/share/doc/${PF}/conf.d.example" \
		"/usr/share/doc/${PF}/mc-conn-poller.yaml.example"
}

pkg_postinst() {
	elog "Create the config from ${EROOT}/usr/share/doc/${PF}/mc-conn-poller.yaml.example,"
	elog "owned by the mc-conn-poller user, and start: rc-service mc-conn-poller start"
	elog "The init script defaults to ${EROOT}/usr/sbin/mc-conn-poller; drop any"
	elog "MCCP_BINARY override pointing at /usr/local/sbin."

	if [[ -x ${EROOT}/usr/local/sbin/mc-conn-poller ]]; then
		ewarn "A manually installed ${EROOT}/usr/local/sbin/mc-conn-poller exists;"
		ewarn "remove it once the packaged binary is in use."
	fi
}
