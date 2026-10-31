# Copyright 2026 Miikka Karhuluoma
# Distributed under the terms of the MIT License

EAPI=8

RUST_MIN_VER="1.91.0"

inherit cargo

DESCRIPTION="Rust Token Killer: CLI proxy that minimizes LLM token consumption"
HOMEPAGE="https://www.rtk-ai.app https://github.com/rtk-ai/rtk"
# ${P}-deps.tar.xz is the `cargo vendor` tree of the workspace (from upstream's
# Cargo.lock), built and attached to a GitHub release of this overlay by
# scripts/cargo-bump.sh.
SRC_URI="
	https://github.com/rtk-ai/rtk/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz
	https://github.com/miikkak/gentoo-overlay/releases/download/${P}/${P}-deps.tar.xz
"

# rtk and rtk-text are Apache-2.0. rtk-engine, linked by the default build, is
# BUSL-1.1 with an Additional Use Grant that allows production use as part of
# the rtk binary (engine/LICENSE).
LICENSE="Apache-2.0 engine? ( BUSL-1.1 )"
# vendored crates, checked from the license fields of vendor/*/Cargo.toml: all
# are available under MIT or Apache-2.0 except colored and option-ext (MPL-2.0),
# webpki-roots (CDLA-Permissive-2.0), ring and rustls (ISC), the icu_* crates
# and unicode-ident (Unicode-3.0), encoding_rs and subtle (BSD-3-Clause) and
# foldhash (Zlib)
LICENSE+=" BSD CDLA-Permissive-2.0 ISC MIT MPL-2.0 Unicode-3.0 ZLIB"
SLOT="0"
KEYWORDS="amd64 arm64"
IUSE="+engine"
RESTRICT="test"

# The deps tarball unpacks the vendored crates to ${P}/vendor.
ECARGO_VENDOR="${WORKDIR}/${P}/vendor"

src_configure() {
	# The engine feature is upstream's default. Without it the binary is the
	# Apache-2.0 edition: same name and hooks, no BUSL-1.1 code.
	local args=()
	use engine || args+=( --no-default-features )
	cargo_src_configure "${args[@]}"
}

src_install() {
	cargo_src_install
	dodoc README.md LICENSE
	use engine && newdoc engine/LICENSE LICENSE-ENGINE
}
