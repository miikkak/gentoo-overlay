# Copyright 2026 Miikka Karhuluoma
# Distributed under the terms of the MIT License

EAPI=8

inherit go-module optfeature

DESCRIPTION="Static checker for GitHub Actions workflow files"
HOMEPAGE="https://github.com/rhysd/actionlint"
# ${P}-deps.tar.xz is the `go mod vendor` tree, built and attached to a GitHub
# release of this overlay by scripts/go-bump.sh.
SRC_URI="
	https://github.com/rhysd/actionlint/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz
	https://github.com/miikkak/gentoo-overlay/releases/download/${P}/${P}-deps.tar.xz
"

LICENSE="MIT"
# vendored Go modules (MIT, BSD-3-Clause and Apache-2.0, checked from vendor/)
LICENSE+=" Apache-2.0 BSD"
SLOT="0"
KEYWORDS="amd64 arm64"
RESTRICT="test"

BDEPEND=">=dev-lang/go-1.25.0"

src_compile() {
	# CGO_ENABLED=0 as in upstream's release builds. version and installedFrom
	# are what `actionlint -version` prints.
	CGO_ENABLED=0 ego build -mod=vendor -trimpath -buildmode=pie \
		-ldflags "
			-X github.com/rhysd/actionlint.version=${PV}
			-X 'github.com/rhysd/actionlint.installedFrom=installed by Portage'
		" \
		-o actionlint ./cmd/actionlint
}

src_install() {
	dobin actionlint
	dodoc README.md
	dodoc -r docs
}

pkg_postinst() {
	optfeature "checking shell scripts in run: steps" dev-util/shellcheck
	optfeature "checking Python scripts in run: steps" dev-python/pyflakes
}
