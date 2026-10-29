# Copyright 2026 Miikka Karhuluoma
# Distributed under the terms of the MIT License

EAPI=8

inherit go-module

DESCRIPTION="Lightweight monitoring agent for the Beszel hub"
HOMEPAGE="https://beszel.dev https://github.com/henrygd/beszel"
# beszel-${PV}-deps.tar.xz is the `go mod vendor` tree, built and attached to
# a GitHub release of this overlay by scripts/beszel-build-distfiles.sh.
SRC_URI="
	https://github.com/henrygd/beszel/archive/refs/tags/v${PV}.tar.gz -> beszel-${PV}.tar.gz
	https://github.com/miikkak/gentoo-overlay/releases/download/beszel-${PV}/beszel-${PV}-deps.tar.xz
"
S="${WORKDIR}/beszel-${PV}"

LICENSE="MIT"
# vendored Go modules
LICENSE+=" Apache-2.0 BSD BSD-2 ISC MPL-2.0"
SLOT="0"
KEYWORDS="amd64 arm64"
IUSE="+nvml +smart"
# Upstream tests need network and a running environment
RESTRICT="test"

RDEPEND="smart? ( sys-apps/smartmontools )"
BDEPEND=">=dev-lang/go-1.27.2"

src_compile() {
	local tags=""
	# NVML (NVIDIA GPU stats) is dlopen()ed at runtime; upstream only
	# supports it on linux/amd64 glibc
	if use nvml && use amd64 && use elibc_glibc; then
		tags="glibc"
	fi

	ego build -mod=vendor -trimpath -buildmode=pie -tags "${tags}" \
		-o beszel-agent ./internal/cmd/agent
}

src_install() {
	dobin beszel-agent
	newinitd "${FILESDIR}/beszel-agent.initd" beszel-agent
	newconfd "${FILESDIR}/beszel-agent.confd" beszel-agent
	dodoc readme.md
}

pkg_postinst() {
	elog "Create ${EROOT}/etc/beszel-agent/{key,token} (mode 0600, directory 0700)"
	elog "with the hub public key and registration token, then edit"
	elog "${EROOT}/etc/conf.d/beszel-agent and start: rc-service beszel-agent start"

	if [[ -x ${EROOT}/usr/local/sbin/beszel-agent ]]; then
		ewarn "A manually installed ${EROOT}/usr/local/sbin/beszel-agent exists."
		ewarn "The init script now defaults to ${EROOT}/usr/bin/beszel-agent;"
		ewarn "remove the old binary and any BESZEL_BINARY override."
	fi
}
