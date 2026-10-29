# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="Fast all-in-one JavaScript runtime, bundler, transpiler, and package manager"
HOMEPAGE="https://bun.sh/ https://github.com/oven-sh/bun/"

SRC_URI="
	amd64? ( https://github.com/oven-sh/bun/releases/download/bun-v${PV}/bun-linux-x64.zip -> ${P}-amd64.zip )
	arm64? ( https://github.com/oven-sh/bun/releases/download/bun-v${PV}/bun-linux-aarch64.zip -> ${P}-arm64.zip )
"

S="${WORKDIR}"

# Bun is MIT but the binary statically links JavaScriptCore/WebKit (LGPL-2),
# tinycc (LGPL-2.1) and many others; see upstream LICENSE.md. Dual-licensed
# parts (zstd BSD/GPL-2, picohttp Perl/MIT) are covered by their permissive option.
LICENSE="MIT LGPL-2 LGPL-2.1 BSD BSD-2 Apache-2.0 ZLIB ISC openssl icu IJG"
SLOT="0"
KEYWORDS="amd64 arm64"
# The x64 binary targets Nehalem (SSE4.2); upstream does not support older CPUs
IUSE="cpu_flags_x86_sse4_2"
REQUIRED_USE="amd64? ( cpu_flags_x86_sse4_2 )"
RESTRICT="strip test"

BDEPEND="app-arch/unzip"

QA_PREBUILT="usr/bin/bun"

src_install() {
	local bun_dir
	if use amd64; then
		bun_dir="bun-linux-x64"
	elif use arm64; then
		bun_dir="bun-linux-aarch64"
	else
		die "Unsupported architecture"
	fi

	cd "${bun_dir}" || die "Directory ${bun_dir} not found in extracted zip"

	dobin bun
}
