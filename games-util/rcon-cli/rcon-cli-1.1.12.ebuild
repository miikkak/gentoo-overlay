# Copyright 2026 Miikka Karhuluoma
# Distributed under the terms of the MIT License

EAPI=8

inherit go-module

DESCRIPTION="Minecraft RCON command-line client with interactive REPL"
HOMEPAGE="https://github.com/miikkak/rcon-cli"
# ${P}-deps.tar.xz is the `go mod vendor` tree, built and attached to a GitHub
# release of this overlay by scripts/go-bump.sh.
SRC_URI="
	https://github.com/miikkak/rcon-cli/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz
	https://github.com/miikkak/gentoo-overlay/releases/download/${P}/${P}-deps.tar.xz
"

LICENSE="MIT"
# vendored Go modules (MIT, Apache-2.0 and BSD-3-Clause, checked from vendor/)
LICENSE+=" Apache-2.0 BSD"
SLOT="0"
KEYWORDS="amd64 arm64"
RESTRICT="test"

BDEPEND=">=dev-lang/go-1.26.6"

src_compile() {
	ego build -mod=vendor -trimpath -buildmode=pie \
		-ldflags "-X main.version=v${PV}" \
		-o rcon-cli ./cmd/rcon-cli
}

src_install() {
	dobin rcon-cli
	dodoc README.md
}
