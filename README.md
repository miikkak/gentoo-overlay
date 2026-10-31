# gentoo-overlay

Personal Gentoo overlay (`miikkak`), OpenRC-oriented.

| Package                                                 | Description                                                                                          |
| ------------------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| `dev-util/actionlint`                                   | [actionlint](https://github.com/rhysd/actionlint) GitHub Actions workflow linter                     |
| `app-misc/rtk`                                          | [rtk](https://www.rtk-ai.app) CLI proxy that cuts LLM token use (`engine` USE flag: BUSL-1.1 engine) |
| `app-misc/lolcrab`                                      | [lolcrab](https://github.com/mazznoer/lolcrab) rainbow text, like lolcat but with noise              |
| `net-analyzer/alloy`                                    | [Grafana Alloy](https://grafana.com/docs/alloy/) telemetry collector                                 |
| `acct-user/alloy`, `acct-group/alloy`                   | Service user and group for Alloy                                                                     |
| `net-analyzer/beszel-agent`                             | [Beszel](https://beszel.dev) monitoring agent                                                        |
| `net-analyzer/beszel-hub`                               | Beszel hub (web UI and API)                                                                          |
| `acct-user/beszel`, `acct-group/beszel`                 | Service user and group for the hub                                                                   |
| `dev-lang/bun-bin`                                      | Prebuilt [Bun](https://bun.sh) runtime                                                               |
| `games-util/rcon-cli`                                   | Minecraft RCON command-line client                                                                   |
| `net-analyzer/mc-conn-poller`                           | Minecraft connectivity poller for Healthchecks                                                       |
| `acct-user/mc-conn-poller`, `acct-group/mc-conn-poller` | Service user and group for the poller                                                                |

## Usage

`/etc/portage/repos.conf/miikkak.conf`:

```ini
[miikkak]
location = /var/db/repos/miikkak
sync-type = git
sync-uri = https://github.com/miikkak/gentoo-overlay.git
auto-sync = yes
```

The packages are keyworded `amd64`/`arm64` (not `~arch`): this is a personal overlay, upstream releases are followed
through reviewed bump PRs, and only packages that are meant to be installed live here. No `package.accept_keywords`
entries are needed.

Then `emerge --sync miikkak` and `emerge -av net-analyzer/beszel-agent`.

The init scripts keep the service names `beszel` (hub) and `beszel-agent`. The Go binaries are compiled by Portage on
your machine, so `GOAMD64`, `GOARM64` and similar variables from `make.conf` apply.

## How the Beszel packages are built

Upstream ships no source-form assets that Portage can use offline, so each release has two extra distfiles, built by
[`scripts/beszel-build-distfiles.sh`](scripts/beszel-build-distfiles.sh) and attached to the overlay release
`beszel-<version>`:

- `beszel-<version>-deps.tar.xz`: the `go mod vendor` tree (agent and hub).
- `beszel-<version>-web.tar.xz`: the built web UI (`internal/site/dist`), which is architecture-independent text that
  upstream embeds in the hub binary. Hub only.

Only the Go compile is done by Portage; nothing else is prebuilt. The `Manifest` pins the hashes of both tarballs.

## `dev-lang/bun-bin`

Bun is Zig plus JavaScriptCore, so it is not built from source. The ebuild started as the GURU one and installs
upstream's release zip. [`scripts/bun-bump.sh`](scripts/bun-bump.sh) checks each zip against the release's
`SHASUMS256.txt` before writing the Manifest. That file comes from the same release as the zips, so it catches corrupt or
wrong downloads, not a compromised release.

## `rcon-cli` and `mc-conn-poller`

Both are pure-Go programs from the owner's own repositories, so the only offline input is the `go mod vendor` tree,
published as `<name>-<version>-deps.tar.xz` on the overlay release `<name>-<version>`. Portage compiles them with
`-trimpath -buildmode=pie` and sets `main.version`, so `--version` matches the upstream release tag.

`mc-conn-poller` installs its init script from the upstream repository. Its configuration (`/etc/conf.d/mc-conn-poller`
and the YAML with the Healthchecks.io ping URL, which is a secret) is per-host and managed outside the package; only
examples are installed under `/usr/share/doc`.

## `net-analyzer/alloy`

Alloy is built from the `collector/` module, upstream's entry point for release builds, so
[`scripts/go-bump.sh`](scripts/go-bump.sh) vendors that module and the distfile unpacks to `collector/vendor`. Two things
upstream embeds are deliberately left out: the web UI (the `embedalloyui` tag, which would need a Node build) and the
Beyla eBPF binary (a downloaded artifact). Metric scraping and remote write do not use either. `go mod vendor` ignores
build tags and would fail on the missing UI `dist` directory, so the bump script stubs it for the vendoring step only.

The package installs `/usr/sbin/alloy` and an OpenRC init script, and creates the `alloy` user and group. The config
(`/etc/alloy/config.alloy`, which holds the Grafana Cloud credentials) and `/etc/conf.d/alloy` are per-host and stay
outside the package. `LICENSE` includes AGPL-3 because the vendored `grafana/loki/v3` packages `logql`, `querier` and
`storage` carry it, although upstream calls Alloy itself Apache-2.0.

## Rust packages (`app-misc/lolcrab`, `app-misc/rtk`)

The offline input is the `cargo vendor --locked` tree of upstream's `Cargo.lock`, published as
`<name>-<version>-deps.tar.xz` on the overlay release `<name>-<version>` by
[`scripts/cargo-bump.sh`](scripts/cargo-bump.sh). It unpacks to `${P}/vendor`; the ebuild points `ECARGO_VENDOR` there,
so `cargo.eclass` writes a cargo config that replaces crates.io with it and builds offline. The `LICENSE` of a Rust
package is checked from the `license` fields in `vendor/*/Cargo.toml`. A bump does not update `RUST_MIN_VER` (the highest
`rust-version` among the crates) or the license list: review both on each bump PR, as new crates can raise them. The bump
job needs `cargo` on the runner.

lolcrab's `build.rs` reads `OUT_DIR` with `option_env!`, so it only writes the shell completions when the variable is
set while the build script is compiled (upstream's release workflow sets `OUT_DIR=target`). The ebuild does the same and
installs the bash, zsh and fish completions.

`app-misc/rtk` has two editions, selected by the `engine` USE flag (enabled by default, as upstream's default build). With
it the binary links `rtk-engine`, which is BUSL-1.1: free for production use as part of the `rtk` binary, but not to be
offered to third parties as a paid or hosted service (`engine/LICENSE`). BUSL-1.1 is not in `@FREE`, so a host that keeps
`ACCEPT_LICENSE="@FREE"` needs `app-misc/rtk BUSL-1.1` in `/etc/portage/package.license`. With `-engine` only the
Apache-2.0 hook and filter core is built, with the same binary name. Upstream's `proxy/` daemon (`rtk-proxy`) is a
separate program and is not packaged.

## Checks

[`scripts/check-ebuilds.sh`](scripts/check-ebuilds.sh) sources every ebuild through Portage (`portageq`, with this
checkout registered as the overlay) and fails when an ebuild does not load, has an empty `KEYWORDS`, or lists a
`LICENSE` name that does not exist in `::gentoo/licenses`. It needs a Gentoo host, so the `Ebuild Check` workflow runs it
on the self-hosted runners, for pull requests from this repository only. A check of the names cannot tell whether the
list is complete: when a bump pulls in new dependencies, compare the licenses of the compiled modules by hand.

## Version bumps

`.github/workflows/bump.yml` runs daily and on demand (`workflow_dispatch` takes a package and optionally a version). It
runs one bump script per package: `scripts/beszel-bump.sh`, `scripts/bun-bump.sh`, or `scripts/go-bump.sh <package>` for
the Go programs, or `scripts/cargo-bump.sh <package>` for the Rust ones. When upstream has a newer release, the script
regenerates the ebuild and Manifest and the workflow opens a draft PR. For Beszel, the Go and the Rust programs it also
builds the distfiles and uploads them to the overlay release first.
Locally:

```bash
scripts/beszel-bump.sh [--no-upload --out DIR] [version]
scripts/bun-bump.sh [version]
scripts/go-bump.sh [--no-upload --out DIR] actionlint|alloy|chroma|rcon-cli|mc-conn-poller [version]
scripts/cargo-bump.sh [--no-upload --out DIR] lolcrab|rtk [version]
```

`--out DIR` keeps a copy of the generated distfiles, and `--no-upload` requires it: without an upload they would
otherwise be deleted with the temporary directory while the ebuild and Manifest already point at them. An existing
`<name>-<version>` release is reused rather than rebuilt, so published hashes never change. Shared helpers live in
[`scripts/lib/overlay.sh`](scripts/lib/overlay.sh).
