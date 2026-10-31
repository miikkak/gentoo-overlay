# Copyright 2026 Miikka Karhuluoma
# Distributed under the terms of the MIT License

EAPI=8

inherit go-module

DESCRIPTION="General purpose syntax highlighter (command-line tool)"
HOMEPAGE="https://github.com/alecthomas/chroma"
# ${P}-deps.tar.xz is the `go mod vendor` tree of the cmd/chroma module, built
# and attached to a GitHub release of this overlay by scripts/go-bump.sh.
SRC_URI="
	https://github.com/alecthomas/chroma/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz
	https://github.com/miikkak/gentoo-overlay/releases/download/${P}/${P}-deps.tar.xz
"

LICENSE="MIT"
# vendored Go modules (MIT and BSD-3-Clause, checked from vendor/), plus the
# Liberation Mono font that the SVG formatter embeds (OFL-1.1, see COPYING)
LICENSE+=" BSD OFL-1.1"
SLOT="0"
KEYWORDS="amd64 arm64"
RESTRICT="test"

BDEPEND=">=dev-lang/go-1.25"

src_unpack() {
	# go-module_src_unpack runs `go mod verify` (which needs the network) unless
	# ${S}/vendor exists. The vendor tree is shipped in ${S}/cmd/chroma/vendor,
	# so unpack without it.
	default
	go-env_set_compile_environment
}

src_compile() {
	# The command is its own module (cmd/chroma, replace => ../../). The version
	# is what `chroma --version` prints, as <version>-<commit>-<date>.
	cd cmd/chroma || die
	ego build -mod=vendor -trimpath -buildmode=pie \
		-ldflags "
			-X main.version=${PV}
			-X main.commit=portage
		" \
		-o ../../chroma .
}

src_install() {
	dobin chroma
	dodoc README.md COPYING
}
