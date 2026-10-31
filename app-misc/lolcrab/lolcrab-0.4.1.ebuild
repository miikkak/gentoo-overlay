# Copyright 2026 Miikka Karhuluoma
# Distributed under the terms of the MIT License

EAPI=8

# highest rust-version among lolcrab and the vendored crates
RUST_MIN_VER="1.74.0"

inherit bash-completion-r1 cargo

DESCRIPTION="Like lolcat but with noise and more colorful"
HOMEPAGE="https://github.com/mazznoer/lolcrab"
# ${P}-deps.tar.xz is the `cargo vendor` tree (from upstream's Cargo.lock),
# built and attached to a GitHub release of this overlay by
# scripts/cargo-bump.sh.
SRC_URI="
	https://github.com/mazznoer/lolcrab/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz
	https://github.com/miikkak/gentoo-overlay/releases/download/${P}/${P}-deps.tar.xz
"

LICENSE="|| ( MIT Apache-2.0 )"
# vendored crates, checked from the license fields of vendor/*/Cargo.toml: all
# of them are available under MIT or Apache-2.0; unicode-ident adds
# Unicode-3.0 for its data tables
LICENSE+=" Unicode-3.0"
SLOT="0"
KEYWORDS="amd64 arm64"
RESTRICT="test"

# The deps tarball unpacks the vendored crates to ${P}/vendor. cargo.eclass
# generates a cargo config that replaces crates.io with this directory.
ECARGO_VENDOR="${WORKDIR}/${P}/vendor"

# build.rs reads OUT_DIR with option_env!, which is evaluated when the build
# script is compiled, and writes the completions of every shell to
# $OUT_DIR/completions only when it is set. Upstream's release workflow sets
# OUT_DIR=target; both phases need the same value, as cargo install rebuilds.
src_compile() {
	local -x OUT_DIR="${S}/target"
	cargo_src_compile
}

src_install() {
	local -x OUT_DIR="${S}/target"
	cargo_src_install

	local comp_dir="${OUT_DIR}/completions"
	[[ -f ${comp_dir}/lolcrab.bash ]] || die "no completions in ${comp_dir}"

	newbashcomp "${comp_dir}/lolcrab.bash" lolcrab
	insinto /usr/share/zsh/site-functions
	doins "${comp_dir}/_lolcrab"
	insinto /usr/share/fish/vendor_completions.d
	doins "${comp_dir}/lolcrab.fish"

	dodoc README.md
}
